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
const buildDir = path.resolve(root, process.env.PARKINSUM_WEB_BUILD_DIR ?? 'build/web');
const reportDir = path.resolve(root, 'build/web_reflow_matrix');
const cli = path.resolve(root, 'node_modules/.bin/playwright-cli');
const session = `parkinsum-web-reflow-${process.pid}`;

const matrix = [
  { id: 'zoom-equivalent-100', zoomPercent: 100, width: 1280, height: 800 },
  { id: 'zoom-equivalent-200', zoomPercent: 200, width: 640, height: 800 },
  { id: 'zoom-equivalent-400', zoomPercent: 400, width: 320, height: 720 },
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

export function responseContentType(requestPath) {
  return contentTypes.get(path.extname(requestPath)) ?? 'application/octet-stream';
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
    digest.update(createHash('sha256').update(bytes).digest('hex'));
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

async function readFlutterBuilds(directory) {
  const bootstrap = await fs.readFile(path.join(directory, 'flutter_bootstrap.js'), 'utf8');
  const match = bootstrap.match(/_flutter\.buildConfig\s*=\s*(\{.*?\});/s);
  if (!match) return [];
  return JSON.parse(match[1]).builds ?? [];
}

async function startServer(directory) {
  const server = http.createServer(async (request, response) => {
    try {
      const url = new URL(request.url ?? '/', 'http://127.0.0.1');
      const decoded = decodeURIComponent(url.pathname);
      const relative = decoded === '/' ? 'index.html' : decoded.replace(/^\/+/, '');
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
      response.writeHead(200, {
        'cache-control': 'no-store',
        'content-type': responseContentType(target),
      });
      response.end(body);
    } catch (error) {
      response.writeHead(500).end(String(error));
    }
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return server;
}

async function runCli(args, { json = false } = {}) {
  const cliArgs = [...(json ? ['--json'] : []), '--session', session, ...args];
  const { stdout, stderr } = await execFileAsync(cli, cliArgs, {
    cwd: root,
    maxBuffer: 16 * 1024 * 1024,
    timeout: 60_000,
  });
  if (stderr.trim()) process.stderr.write(stderr);
  if (!json) return stdout;
  const envelope = JSON.parse(stdout);
  return typeof envelope.result === 'string'
    ? JSON.parse(envelope.result)
    : envelope.result;
}

const probeSource = `async () => {
  const viewport = { width: innerWidth, height: innerHeight };
  const root = document.documentElement;
  const visible = [...document.querySelectorAll('flt-semantics')]
    .map((element) => {
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      let parent = element.parentElement;
      let localHorizontalScroller =
        (style.overflowX === 'auto' || style.overflowX === 'scroll') &&
        element.scrollWidth > element.clientWidth + 1;
      while (parent && parent !== document.body) {
        const overflow = getComputedStyle(parent).overflowX;
        if ((overflow === 'auto' || overflow === 'scroll') && parent.scrollWidth > parent.clientWidth + 1) {
          localHorizontalScroller = true;
          break;
        }
        parent = parent.parentElement;
      }
      return {
        label: element.getAttribute('aria-label'),
        role: element.getAttribute('role'),
        rect: { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height },
        overflowX: style.overflowX,
        localHorizontalScroller,
      };
    })
    .filter((item) => item.rect.width > 0 && item.rect.height > 0);
  const horizontalViolations = visible.filter((item) =>
    !item.localHorizontalScroller && (item.rect.left < -1 || item.rect.right > innerWidth + 1));
  const scrollPositions = [...document.querySelectorAll('*')]
    .filter((element) => element.scrollTop || element.scrollLeft)
    .map((element) => ({ element, top: element.scrollTop, left: element.scrollLeft }));
  const windowScroll = { x: scrollX, y: scrollY };
  const targetIds = [...document.querySelectorAll('flt-semantics[role="button"]')]
    .map((element) => element.id)
    .filter(Boolean);
  const targetAudits = [];
  const targetAuditFailures = [];
  for (const id of targetIds) {
    const element = document.getElementById(id);
    if (!element) {
      targetAuditFailures.push({ id, reason: 'target disappeared before measurement' });
      continue;
    }
    element.scrollIntoView({ block: 'center', inline: 'center' });
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const current = document.getElementById(id);
    if (!current) {
      targetAuditFailures.push({ id, reason: 'target disappeared after scrolling' });
      continue;
    }
    const rect = current.getBoundingClientRect();
    targetAudits.push({
      id,
      name: current.getAttribute('aria-label') || current.textContent?.replace(/\\s+/g, ' ').trim() || null,
      rect: { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height },
    });
  }
  for (const position of scrollPositions) position.element.scrollTo(position.left, position.top);
  window.scrollTo(windowScroll.x, windowScroll.y);
  await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const undersizedTargets = targetAudits.filter((item) =>
    item.rect.width < 24 || item.rect.height < 24);
  const active = document.activeElement;
  const activeRect = active?.getBoundingClientRect();
  return {
    viewport,
    devicePixelRatio,
    document: {
      clientWidth: root.clientWidth,
      scrollWidth: root.scrollWidth,
      bodyScrollWidth: document.body.scrollWidth,
      horizontalOverflow: Math.max(0, root.scrollWidth - root.clientWidth),
    },
    semanticsEnabled: visible.length > 1,
    semanticNodeCount: visible.length,
    horizontalViolations,
    targetAuditCount: targetAudits.length,
    targetAuditFailures,
    undersizedTargets,
    focus: activeRect ? {
      role: active.getAttribute('role'),
      label: active.getAttribute('aria-label'),
      rect: { left: activeRect.left, top: activeRect.top, right: activeRect.right, bottom: activeRect.bottom, width: activeRect.width, height: activeRect.height },
      atLeastPartiallyVisible: activeRect.right > 0 && activeRect.left < innerWidth && activeRect.bottom > 0 && activeRect.top < innerHeight,
    } : null,
  };
}`;

export function evaluateMatrixReport(report) {
  const failures = [];
  for (const result of report.results) {
    if (result.probe.viewport.width !== result.width) {
      failures.push(`${result.id}: viewport width ${result.probe.viewport.width} != ${result.width}`);
    }
    if (result.probe.document.horizontalOverflow > 1) {
      failures.push(`${result.id}: page horizontal overflow ${result.probe.document.horizontalOverflow}px`);
    }
    if (!result.probe.semanticsEnabled) failures.push(`${result.id}: semantics tree unavailable`);
    if (result.probe.horizontalViolations.length > 0) {
      failures.push(`${result.id}: ${result.probe.horizontalViolations.length} uncontained semantic nodes overflow horizontally`);
    }
    if (result.probe.undersizedTargets.length > 0) {
      failures.push(`${result.id}: ${result.probe.undersizedTargets.length} scrolled-into-view targets are under 24 CSS px`);
    }
    if (result.probe.targetAuditFailures?.length > 0) {
      failures.push(`${result.id}: ${result.probe.targetAuditFailures.length} semantic targets could not be audited`);
    }
    if (!result.probe.focus?.atLeastPartiallyVisible) {
      failures.push(`${result.id}: keyboard focus is not visibly retained`);
    }
  }
  return failures;
}

function markdown(report) {
  const rows = report.results.map((item) =>
    `| ${item.zoomPercent}% equivalent | ${item.width}×${item.height} | ${item.probe.document.horizontalOverflow}px | ${item.probe.horizontalViolations.length} | ${item.probe.undersizedTargets.length} | ${item.probe.focus?.atLeastPartiallyVisible ? 'visible' : 'FAILED'} |`);
  return `# Web release-artifact reflow matrix\n\n` +
    `**Result:** ${report.pass ? 'PASS' : 'FAILED'}\n\n` +
    `**Artifact SHA-256:** \`${report.artifactSha256}\`\n\n` +
    `| Browser zoom equivalence | CSS viewport | Page overflow | Uncontained semantic overflow | Undersized visible targets | Keyboard focus |\n` +
    `| --- | --- | ---: | ---: | ---: | --- |\n${rows.join('\n')}\n\n` +
    `## Boundary\n\n` +
    `This executable matrix serves the built artifact independently and tests the WCAG 320 CSS-pixel equivalence in Chromium. It does not operate the browser's visible zoom UI, test other browsers/renderers, prove screen-reader announcements, or establish WCAG conformance.\n` +
    (report.failures.length ? `\n## Failures\n\n${report.failures.map((item) => `- ${item}`).join('\n')}\n` : '');
}

async function main() {
  await fs.access(path.join(buildDir, 'index.html'));
  await fs.access(cli);
  await fs.mkdir(reportDir, { recursive: true });
  const server = await startServer(buildDir);
  const address = server.address();
  const port = typeof address === 'object' && address ? address.port : null;
  const url = `http://127.0.0.1:${port}`;
  try {
    await runCli(['open', url]);
    await runCli(['snapshot']);
    const semanticsActivation = await runCli(['eval', `async () => {
      const deadline = Date.now() + 45000;
      let clicked = false;
      while (Date.now() < deadline) {
        const placeholder = document.querySelector('flt-semantics-placeholder[aria-label="Enable accessibility"]');
        if (placeholder) {
          placeholder.click();
          clicked = true;
        }
        const count = document.querySelectorAll('flt-semantics').length;
        if (count > 1) return { clicked, count, state: 'ready' };
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
      return {
        clicked,
        count: document.querySelectorAll('flt-semantics').length,
        state: 'timeout',
        title: document.title,
        visibleText: document.body.innerText.slice(0, 500),
      };
    }`], { json: true });
    const browserRuntime = await runCli(['eval', `() => ({
      userAgent: navigator.userAgent,
      platform: navigator.platform,
      language: navigator.language,
      crossOriginIsolated: window.crossOriginIsolated,
      devicePixelRatio: window.devicePixelRatio,
    })`], { json: true });

    const results = [];
    for (const entry of matrix) {
      await runCli(['resize', String(entry.width), String(entry.height)]);
      await runCli(['eval', `async () => { await new Promise((resolve) => setTimeout(resolve, 250)); return true; }`], { json: true });
      await runCli(['eval', `() => { document.activeElement?.blur(); document.body.tabIndex = -1; document.body.focus(); return true; }`], { json: true });
      let focus = null;
      for (let attempt = 0; attempt < 8; attempt += 1) {
        await runCli(['press', 'Tab']);
        focus = await runCli(['eval', `() => { const el = document.activeElement; const rect = el?.getBoundingClientRect(); return rect ? { role: el.getAttribute('role'), visible: rect.right > 0 && rect.left < innerWidth && rect.bottom > 0 && rect.top < innerHeight } : null; }`], { json: true });
        if (focus?.role === 'button' && focus.visible) break;
      }
      const probe = await runCli(['eval', probeSource], { json: true });
      results.push({ ...entry, probe });
    }

    const report = {
      schema: 'parkinsum.web-release-reflow-matrix/2',
      generatedAtUtc: new Date().toISOString(),
      artifactSha256: await digestDirectory(buildDir),
      browser: 'playwright-cli/chromium',
      sourceRevision: {
        head: await commandText('git', ['rev-parse', 'HEAD']),
        dirty: (await commandText('git', ['status', '--porcelain=v1'])).length > 0,
      },
      environment: {
        hostPlatform: process.platform,
        hostArchitecture: process.arch,
        node: process.version,
        playwrightCli: await commandText(cli, ['--version']),
        browserRuntime,
        flutterBuilds: await readFlutterBuilds(buildDir),
      },
      semanticsActivation,
      results,
      failures: [],
      pass: false,
      limitations: [
        'Viewport equivalence is not the browser visible zoom control.',
        'Chromium evidence does not cover Safari, Firefox, or assistive-technology spoken output.',
        'Target checks scroll semantic buttons into view before measurement and do not adjudicate WCAG exceptions.',
      ],
    };
    report.failures = evaluateMatrixReport(report);
    report.pass = report.failures.length === 0;
    await fs.writeFile(path.join(reportDir, 'latest.json'), `${JSON.stringify(report, null, 2)}\n`);
    await fs.writeFile(path.join(reportDir, 'latest.md'), markdown(report));
    console.log(`Web release reflow matrix: ${report.pass ? 'PASS' : 'FAILED'}; artifact=${report.artifactSha256.slice(0, 12)}; failures=${report.failures.length}.`);
    console.log('Report: build/web_reflow_matrix/latest.json');
    console.log('Report: build/web_reflow_matrix/latest.md');
    if (!report.pass) process.exitCode = 1;
  } finally {
    await runCli(['close']).catch(() => {});
    await new Promise((resolve) => server.close(resolve));
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
