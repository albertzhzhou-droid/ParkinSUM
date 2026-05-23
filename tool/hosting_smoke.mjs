#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const releaseId = args['release-id'] ?? `hosting_smoke_${timestamp()}`;
const output =
  args.output ??
  path.join('build', 'browser_smoke', `${releaseId}_hosting_smoke.json`);
const markdownOutput = output.replace(/\.json$/, '.md');

const targets = parseTargets(args);
const results = [];
for (const target of targets) {
  results.push(await smoke(target));
}

const failed = results.filter((result) => !result.pass);
const report = {
  reportType: 'hosting_smoke',
  generatedAt: new Date().toISOString(),
  releaseId,
  targets: results,
  pass: failed.length === 0,
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, pass: report.pass }, null, 2));
if (!report.pass) process.exit(1);

async function smoke(target) {
  const checks = [];
  let headHeaders = {};
  let getHeaders = {};
  let body = '';
  try {
    const head = await fetch(target.url, { method: 'HEAD', redirect: 'follow' });
    headHeaders = Object.fromEntries(head.headers.entries());
    checks.push(check('HEAD returns 200', head.status === 200, head.status));
    checks.push(check('index cache is no-store', /no-store/i.test(headHeaders['cache-control'] ?? ''), headHeaders['cache-control'] ?? null));
    checks.push(check('TLS/HSTS header present', Boolean(headHeaders['strict-transport-security']), headHeaders['strict-transport-security'] ?? null));

    const get = await fetch(target.url, { method: 'GET', redirect: 'follow' });
    getHeaders = Object.fromEntries(get.headers.entries());
    body = await get.text();
    checks.push(check('GET returns 200', get.status === 200, get.status));
    checks.push(check('HTML payload non-empty', body.length > 0, body.length));
    checks.push(check('Flutter bootstrap artifact referenced', /flutter_bootstrap\.js|main\.dart\.js|flutter\.js/.test(body), body.slice(0, 160)));
  } catch (error) {
    checks.push(check('request completed', false, error.message));
  }
  return {
    environment: target.environment,
    url: target.url,
    checkedAt: new Date().toISOString(),
    cacheControl: headHeaders['cache-control'] ?? getHeaders['cache-control'] ?? null,
    contentType: headHeaders['content-type'] ?? getHeaders['content-type'] ?? null,
    hsts: headHeaders['strict-transport-security'] ?? getHeaders['strict-transport-security'] ?? null,
    htmlLength: body.length,
    checks,
    pass: checks.every((item) => item.pass),
  };
}

function check(name, pass, observed) {
  return { name, pass, observed };
}

function parseTargets(parsed) {
  if (parsed.url) {
    return [{ environment: parsed.env ?? 'custom', url: parsed.url }];
  }
  return [
    { environment: 'stage', url: 'https://parkinsum-companion-stage.web.app/' },
    { environment: 'prod', url: 'https://parkinsum-companion.web.app/' },
  ];
}

function renderMarkdown(report) {
  return `# Hosting Smoke Report

Generated at: ${report.generatedAt}
Release id: ${report.releaseId}
Result: ${report.pass ? 'PASS' : 'FAIL'}

${report.targets.map(renderTarget).join('\n\n')}

Browser console bootstrap evidence is recorded separately when Browser is used.
This script verifies public Hosting reachability, TLS/HSTS, cache policy, and
Flutter bootstrap HTML without registering or signing in.
`;
}

function renderTarget(target) {
  return `## ${target.environment}

- URL: ${target.url}
- Cache-Control: ${target.cacheControl ?? 'none'}
- Content-Type: ${target.contentType ?? 'none'}
- HSTS: ${target.hsts ?? 'none'}
- HTML length: ${target.htmlLength}
- Result: ${target.pass ? 'PASS' : 'FAIL'}

| Check | Result | Observed |
| --- | --- | --- |
${target.checks.map((item) => `| ${item.name} | ${item.pass ? 'PASS' : 'FAIL'} | ${String(item.observed).replace(/\|/g, '/') } |`).join('\n')}`;
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (next == null || next.startsWith('--')) {
      parsed[key] = true;
    } else {
      parsed[key] = next;
      i += 1;
    }
  }
  return parsed;
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '').slice(0, 15);
}
