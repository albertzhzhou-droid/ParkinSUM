#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const args = parseArgs(process.argv.slice(2));
const releaseId = args['release-id'] ?? `clinical_engine_${timestamp()}`;
const output =
  args.output ?? path.join('build', 'clinical_review', `${releaseId}_clinical_engine_gate.json`);
const markdownOutput = output.replace(/\.json$/, '.md');
const flutter =
  args.flutter ??
  process.env.FLUTTER_BIN ??
  '/Users/zhouzhenghang/Applications/Flutter SDK/flutter/bin/flutter';

const evidenceFiles = [
  'test/database_backed_meal_check_usecase_test.dart',
  'test/runtime_rule_engine_test.dart',
  'test/recommendation_benchmark_dataset_test.dart',
];
const evidence = evidenceFiles.map((file) => ({
  file,
  exists: fs.existsSync(file),
  cases: fs.existsSync(file) ? extractCaseEvidence(fs.readFileSync(file, 'utf8')) : [],
}));
const testResult = spawnSync(flutter, ['test', ...evidenceFiles, '--concurrency=1'], {
  cwd: process.cwd(),
  encoding: 'utf8',
  maxBuffer: 1024 * 1024 * 8,
});

const requiredCaseLabels = [
  'levodopa',
  'iron',
  'missing',
  'historical',
  'manual review',
];
const sourceBlob = evidence.map((item) => item.cases.join('\n')).join('\n').toLowerCase();
const caseCoverage = requiredCaseLabels.map((label) => ({
  label,
  pass: sourceBlob.includes(label),
}));
const report = {
  reportType: 'clinical_engine_gate',
  generatedAt: new Date().toISOString(),
  releaseId,
  command: `${flutter} test ${evidenceFiles.join(' ')} --concurrency=1`,
  pass: testResult.status === 0 && caseCoverage.every((item) => item.pass),
  testStatus: testResult.status,
  caseCoverage,
  evidence,
  stdoutExcerpt: sanitize(testResult.stdout),
  stderrExcerpt: sanitize(testResult.stderr),
  reviewerStatus: args['reviewer-status'] ?? 'pending clinical/domain review',
  publicReleaseDecision: 'HOLD',
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(report));
console.log(JSON.stringify({ output, markdownOutput, pass: report.pass }, null, 2));
if (!report.pass) process.exit(1);

function extractCaseEvidence(source) {
  const lines = source.split(/\n/);
  return lines
    .filter((line) => /levodopa|protein|iron|mineral|dairy|missing|manual review|historical|no_conflict|no conflict|no_current_risk|no current risk|low-risk|low risk/i.test(line))
    .slice(0, 80)
    .map((line) => line.trim())
    .filter(Boolean);
}

function renderMarkdown(report) {
  return `# Clinical Engine Gate

Release id: ${report.releaseId}
Generated at: ${report.generatedAt}
Result: ${report.pass ? 'PASS' : 'FAIL'}
Reviewer status: ${report.reviewerStatus}
Public release decision: ${report.publicReleaseDecision}

| Coverage | Result |
| --- | --- |
${report.caseCoverage.map((item) => `| ${item.label} | ${item.pass ? 'PASS' : 'FAIL'} |`).join('\n')}
`;
}

function sanitize(value) {
  return String(value ?? '').replace(/\r/g, '').slice(-4000);
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
