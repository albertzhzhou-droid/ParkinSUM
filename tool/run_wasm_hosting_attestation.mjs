#!/usr/bin/env node

import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { promises as fs } from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { promisify } from 'node:util';
import { pathToFileURL } from 'node:url';

const execFileAsync = promisify(execFile);
const root = process.cwd();
const buildDir = path.resolve(
  root,
  process.env.PARKINSUM_WEB_BUILD_DIR ?? 'build/web',
);
const reportDir = path.resolve(root, 'build/wasm_hosting_attestation');
const cli = path.resolve(root, 'node_modules/.bin/playwright-cli');

export const hostingProfiles = [
  {
    id: 'plain_no_isolation',
    coop: null,
    coep: null,
    expectedIsolation: false,
  },
  {
    id: 'isolated_credentialless',
    coop: 'same-origin',
    coep: 'credentialless',
    expectedIsolation: true,
  },
  {
    id: 'isolated_require_corp',
    coop: 'same-origin',
    coep: 'require-corp',
    expectedIsolation: true,
  },
];

const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.mjs', 'text/javascript; charset=utf-8'],
  ['.otf', 'font/otf'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.ttf', 'font/ttf'],
  ['.wasm', 'application/wasm'],
  ['.woff', 'font/woff'],
  ['.woff2', 'font/woff2'],
]);

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

async function walk(directory) {
  const out = [];
  for (const entry of await fs.readdir(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) out.push(...(await walk(entryPath)));
    if (entry.isFile()) out.push(entryPath);
  }
  return out.sort();
}

async function digestDirectory(directory) {
  const digest = createHash('sha256');
  for (const file of await walk(directory)) {
    const relative = path.relative(directory, file).split(path.sep).join('/');
    const bytes = await fs.readFile(file);
    digest.update(relative);
    digest.update('\0');
    digest.update(sha256(bytes));
    digest.update('\n');
  }
  return digest.digest('hex');
}

async function commandText(command, args) {
  const { stdout } = await execFileAsync(command, args, {
    cwd: root,
    maxBuffer: 4 * 1024 * 1024,
    timeout: 15_000,
  });
  return stdout.trim();
}

export function responseHeaders(profile, requestPath) {
  const extension = path.extname(requestPath);
  const isEntry = requestPath === '/' || requestPath === '/index.html';
  const isServiceWorker = requestPath === '/flutter_service_worker.js';
  const headers = {
    'cache-control': isEntry
      ? 'no-store, max-age=0'
      : isServiceWorker
        ? 'no-cache, max-age=0, must-revalidate'
        : 'public, max-age=31536000, immutable',
    'content-type': contentTypes.get(extension) ??
      (isEntry ? 'text/html; charset=utf-8' : 'application/octet-stream'),
    'x-content-type-options': 'nosniff',
  };
  if (profile.coop) headers['cross-origin-opener-policy'] = profile.coop;
  if (profile.coep) headers['cross-origin-embedder-policy'] = profile.coep;
  return headers;
}

async function readFlutterBuildConfig(directory) {
  const bootstrap = await fs.readFile(
    path.join(directory, 'flutter_bootstrap.js'),
    'utf8',
  );
  const match = bootstrap.match(/_flutter\.buildConfig\s*=\s*(\{.*?\});/s);
  if (!match) return { builds: [] };
  return JSON.parse(match[1]);
}

async function startServer(directory, profile) {
  const requests = [];
  const server = http.createServer(async (request, response) => {
    try {
      const url = new URL(request.url ?? '/', 'http://127.0.0.1');
      const decodedPath = decodeURIComponent(url.pathname);
      const relative = decodedPath === '/'
        ? 'index.html'
        : decodedPath.replace(/^\/+/, '');
      let target = path.resolve(directory, relative);
      if (!target.startsWith(`${directory}${path.sep}`) && target !== directory) {
        response.writeHead(400).end('invalid path');
        return;
      }
      try {
        if (!(await fs.stat(target)).isFile()) throw new Error('not a file');
      } catch {
        target = path.join(directory, 'index.html');
      }
      const body = await fs.readFile(target);
      const headers = responseHeaders(profile, decodedPath);
      requests.push({
        method: request.method,
        path: decodedPath,
        status: 200,
        responseHeaders: headers,
        bodySha256: sha256(body),
        bodyBytes: body.length,
      });
      response.writeHead(200, headers);
      response.end(request.method === 'HEAD' ? undefined : body);
    } catch (error) {
      requests.push({
        method: request.method,
        path: request.url,
        status: 500,
        error: String(error),
      });
      response.writeHead(500).end(String(error));
    }
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return { server, requests };
}

async function runCli(session, args, { json = false } = {}) {
  const cliArgs = [...(json ? ['--json'] : []), '--session', session, ...args];
  const { stdout, stderr } = await execFileAsync(cli, cliArgs, {
    cwd: root,
    maxBuffer: 16 * 1024 * 1024,
    timeout: 75_000,
  });
  if (stderr.trim()) process.stderr.write(stderr);
  if (!json) return stdout.trim();
  const envelope = JSON.parse(stdout);
  return typeof envelope.result === 'string'
    ? JSON.parse(envelope.result)
    : envelope.result;
}

async function attestCriticalResources(baseUrl, flutterBuilds) {
  const wasmBuild = flutterBuilds.find(
    (build) => build.compileTarget === 'dart2wasm',
  );
  const paths = [
    '/',
    '/index.html',
    '/flutter_bootstrap.js',
    '/flutter_service_worker.js',
    `/${wasmBuild?.jsSupportRuntimePath ?? 'main.dart.mjs'}`,
    `/${wasmBuild?.mainWasmPath ?? 'main.dart.wasm'}`,
    '/canvaskit/skwasm.wasm',
  ];
  const out = [];
  for (const resourcePath of paths) {
    const response = await fetch(`${baseUrl}${resourcePath}`, {
      cache: 'no-store',
      redirect: 'error',
    });
    const bytes = new Uint8Array(await response.arrayBuffer());
    out.push({
      path: resourcePath,
      status: response.status,
      headers: Object.fromEntries(response.headers.entries()),
      bodySha256: sha256(bytes),
      bodyBytes: bytes.length,
    });
  }
  return out;
}

const runtimeProbeSource = `async () => {
  const deadline = Date.now() + 45000;
  let accessibilityClicked = false;
  while (Date.now() < deadline) {
    const placeholder = document.querySelector(
      'flt-semantics-placeholder[aria-label="Enable accessibility"]',
    );
    if (placeholder) {
      placeholder.click();
      accessibilityClicked = true;
    }
    if (document.querySelectorAll('flt-semantics').length > 1) break;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  await new Promise((resolve) => setTimeout(resolve, 250));
  const resourceUrls = performance.getEntriesByType('resource')
    .map((entry) => new URL(entry.name))
    .filter((url) => /main\.dart|skwasm|canvaskit|flutter_service_worker/.test(url.pathname));
  const registrations = 'serviceWorker' in navigator
    ? await navigator.serviceWorker.getRegistrations()
    : [];
  const semanticsCount = document.querySelectorAll('flt-semantics').length;
  const visibleText = document.body.innerText.replace(/\\s+/g, ' ').trim().slice(0, 800);
  const semanticText = [...document.querySelectorAll('flt-semantics')]
    .map((element) => element.getAttribute('aria-label') || element.textContent || '')
    .join(' ')
    .replace(/\\s+/g, ' ')
    .trim()
    .slice(0, 1600);
  const errorSurface = /(^|\\s)(error|retry)(\\s|$)/i.test(
    visibleText + ' ' + semanticText,
  );
  const resourcePaths = resourceUrls.map((url) => url.pathname);
  const crossOriginEngineResources = resourceUrls
    .filter((url) => url.origin !== location.origin)
    .map((url) => url.href);
  return {
    title: document.title,
    visibleText,
    accessibilityClicked,
    semanticsCount,
    semanticText,
    errorSurface,
    appReady:
      semanticsCount >= 10 &&
      /Initial setup/i.test(semanticText) &&
      /Next/i.test(semanticText) &&
      !errorSurface,
    crossOriginIsolated: window.crossOriginIsolated,
    sharedArrayBufferAvailable: typeof SharedArrayBuffer === 'function',
    userAgent: navigator.userAgent,
    platform: navigator.platform,
    devicePixelRatio: window.devicePixelRatio,
    resources: [...new Set(resourcePaths)].sort(),
    crossOriginEngineResources: [...new Set(crossOriginEngineResources)].sort(),
    mainWasmRequested: resourcePaths.some((name) => name.endsWith('/main.dart.wasm')),
    skwasmRequested: resourcePaths.some((name) => /skwasm.*\.wasm$/.test(name)),
    jsFallbackRequested: resourcePaths.some((name) => name.endsWith('/main.dart.js')),
    serviceWorker: {
      supported: 'serviceWorker' in navigator,
      controlled: Boolean(navigator.serviceWorker?.controller),
      registrations: registrations.map((registration) => ({
        scope: registration.scope,
        active: registration.active?.scriptURL ?? null,
        waiting: registration.waiting?.scriptURL ?? null,
        installing: registration.installing?.scriptURL ?? null,
      })),
    },
  };
}`;

async function runProfile(profile, flutterBuilds) {
  const { server, requests } = await startServer(buildDir, profile);
  const address = server.address();
  const port = typeof address === 'object' && address ? address.port : null;
  const baseUrl = `http://127.0.0.1:${port}`;
  const session = `parkinsum-wasm-${profile.id}-${process.pid}`;
  try {
    const resourceAttestations = await attestCriticalResources(
      baseUrl,
      flutterBuilds,
    );
    await runCli(session, ['open', `${baseUrl}/?attestation=${profile.id}`]);
    await runCli(session, ['snapshot']);
    const runtime = await runCli(
      session,
      ['eval', runtimeProbeSource],
      { json: true },
    );
    const consoleMessages = await runCli(session, ['console'])
      .catch((error) => `console capture failed: ${error.message}`);
    const consoleErrorMatch = consoleMessages.match(/Errors:\s*(\d+)/i);
    runtime.consoleErrorCount = consoleErrorMatch
      ? Number.parseInt(consoleErrorMatch[1], 10)
      : null;
    return {
      id: profile.id,
      expected: {
        coop: profile.coop,
        coep: profile.coep,
        crossOriginIsolated: profile.expectedIsolation,
      },
      baseUrl,
      resourceAttestations,
      runtime,
      consoleMessages,
      observedRequestPaths: [...new Set(requests.map((item) => item.path))].sort(),
    };
  } finally {
    await runCli(session, ['close']).catch(() => {});
    await new Promise((resolve) => server.close(resolve));
  }
}

export function evaluateAttestation(report) {
  const failures = [];
  const builds = report.flutterBuilds ?? [];
  if (!builds.some(
    (build) => build.compileTarget === 'dart2wasm' && build.renderer === 'skwasm',
  )) {
    failures.push('artifact: dart2wasm/skwasm build candidate is missing');
  }
  if (!builds.some(
    (build) => build.compileTarget === 'dart2js' && build.renderer === 'canvaskit',
  )) {
    failures.push('artifact: dart2js/CanvasKit fallback candidate is missing');
  }
  if (report.flutterBuildConfig?.useLocalCanvasKit !== true) {
    failures.push('artifact: Flutter engine resources are not configured for same-origin hosting');
  }
  for (const result of report.results ?? []) {
    const prefix = `${result.id}:`;
    if (!result.runtime?.appReady) failures.push(`${prefix} application did not become ready`);
    if (result.runtime?.errorSurface) failures.push(`${prefix} Error/Retry surface is visible`);
    if ((result.runtime?.consoleErrorCount ?? 1) > 0) {
      failures.push(`${prefix} browser console contains errors or was not auditable`);
    }
    if (
      result.runtime?.crossOriginIsolated !==
      result.expected?.crossOriginIsolated
    ) {
      failures.push(`${prefix} crossOriginIsolated did not match expectation`);
    }
    if (
      result.expected?.crossOriginIsolated &&
      !result.runtime?.sharedArrayBufferAvailable
    ) {
      failures.push(`${prefix} SharedArrayBuffer is unavailable while isolation is required`);
    }
    if (!result.runtime?.mainWasmRequested || !result.runtime?.skwasmRequested) {
      failures.push(`${prefix} browser did not request the dart2wasm/skwasm path`);
    }
    if (result.expected?.crossOriginIsolated && result.runtime?.jsFallbackRequested) {
      failures.push(`${prefix} isolated browser unexpectedly requested dart2js fallback`);
    }
    if ((result.runtime?.crossOriginEngineResources ?? []).length > 0) {
      failures.push(`${prefix} Flutter engine resources were fetched cross-origin`);
    }
    for (const resource of result.resourceAttestations ?? []) {
      if (resource.status !== 200) {
        failures.push(`${prefix} ${resource.path} returned ${resource.status}`);
      }
      if (
        resource.path.endsWith('.wasm') &&
        resource.headers?.['content-type'] !== 'application/wasm'
      ) {
        failures.push(`${prefix} ${resource.path} has invalid Wasm content type`);
      }
      const coop = resource.headers?.['cross-origin-opener-policy'] ?? null;
      const coep = resource.headers?.['cross-origin-embedder-policy'] ?? null;
      if (coop !== result.expected?.coop || coep !== result.expected?.coep) {
        failures.push(`${prefix} ${resource.path} isolation headers drifted`);
      }
    }
  }
  const ids = new Set((report.results ?? []).map((result) => result.id));
  for (const profile of hostingProfiles) {
    if (!ids.has(profile.id)) failures.push(`matrix: missing profile ${profile.id}`);
  }
  return [...new Set(failures)];
}

function markdown(report) {
  const rows = report.results.map((result) =>
    `| ${result.id} | ${result.expected.coop ?? 'absent'} | ${result.expected.coep ?? 'absent'} | ${result.runtime.crossOriginIsolated} | ${result.runtime.sharedArrayBufferAvailable} | ${result.runtime.mainWasmRequested && result.runtime.skwasmRequested ? 'Wasm/Skwasm' : 'FAILED'} | ${result.runtime.jsFallbackRequested ? 'requested' : 'not requested'} | ${result.runtime.appReady ? 'ready' : 'FAILED'} |`,
  );
  return `# Wasm hosting attestation\n\n` +
    `**Result:** ${report.pass ? 'PASS' : 'FAILED'}\n\n` +
    `**Artifact SHA-256:** \`${report.artifactSha256}\`\n\n` +
    `| Profile | COOP | COEP | Isolated | SharedArrayBuffer | Selected resources | JS fallback | App |\n` +
    `| --- | --- | --- | --- | --- | --- | --- | --- |\n${rows.join('\n')}\n\n` +
    `## Boundary\n\n` +
    `This is a loopback Chromium comparison of one local Wasm-capable release artifact. It does not attest Firebase Hosting, CDN or proxy behavior, production TLS, Firefox or WebKit compatibility, external Firebase/reCAPTCHA resources, offline upgrade recovery, clinical validity, or regulatory readiness.\n` +
    (report.failures.length
      ? `\n## Failures\n\n${report.failures.map((item) => `- ${item}`).join('\n')}\n`
      : '');
}

async function main() {
  await fs.access(path.join(buildDir, 'index.html'));
  await fs.access(cli);
  await fs.mkdir(reportDir, { recursive: true });
  const flutterBuildConfig = await readFlutterBuildConfig(buildDir);
  const flutterBuilds = flutterBuildConfig.builds ?? [];
  const results = [];
  for (const profile of hostingProfiles) {
    console.log(`Running Wasm hosting profile: ${profile.id}`);
    results.push(await runProfile(profile, flutterBuilds));
  }
  const report = {
    schema: 'parkinsum.wasm-hosting-attestation/1',
    generatedAtUtc: new Date().toISOString(),
    artifactSha256: await digestDirectory(buildDir),
    sourceRevision: {
      head: await commandText('git', ['rev-parse', 'HEAD']),
      dirty: (await commandText('git', ['status', '--porcelain=v1'])).length > 0,
    },
    environment: {
      hostPlatform: process.platform,
      hostArchitecture: process.arch,
      node: process.version,
      playwrightCli: await commandText(cli, ['--version']),
    },
    flutterBuildConfig,
    flutterBuilds,
    results,
    failures: [],
    pass: false,
    limitations: [
      'Loopback Chromium does not attest Firebase Hosting, CDN, proxy, or TLS behavior.',
      'Firefox and WebKit Flutter/Wasm compatibility remains outside this executable slice.',
      'Cross-origin Firebase, App Check, reCAPTCHA, and service-worker upgrade behavior is not proven.',
    ],
  };
  report.failures = evaluateAttestation(report);
  report.pass = report.failures.length === 0;
  await fs.writeFile(
    path.join(reportDir, 'latest.json'),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  await fs.writeFile(path.join(reportDir, 'latest.md'), markdown(report));
  console.log(
    `Wasm hosting attestation: ${report.pass ? 'PASS' : 'FAILED'}; ` +
      `artifact=${report.artifactSha256.slice(0, 12)}; ` +
      `failures=${report.failures.length}.`,
  );
  console.log('Report: build/wasm_hosting_attestation/latest.json');
  console.log('Report: build/wasm_hosting_attestation/latest.md');
  if (!report.pass) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
