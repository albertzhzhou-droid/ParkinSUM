import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const sourceScript = fileURLToPath(
  new URL('./public_repo_preflight.mjs', import.meta.url),
);

function runFixture({ trackGeneratedFile, largeGeneratedFile = false, publicDocument }) {
  const fixture = fs.mkdtempSync(
    path.join(os.tmpdir(), 'parkinsum-public-preflight-'),
  );
  try {
    fs.mkdirSync(path.join(fixture, 'tool'), { recursive: true });
    fs.mkdirSync(path.join(fixture, 'build'), { recursive: true });
    fs.copyFileSync(
      sourceScript,
      path.join(fixture, 'tool', 'public_repo_preflight.mjs'),
    );
    fs.writeFileSync(path.join(fixture, '.gitignore'), 'build/\n');
    if (publicDocument !== undefined) {
      fs.mkdirSync(path.join(fixture, 'docs'), { recursive: true });
      fs.writeFileSync(path.join(fixture, 'docs', 'claims.md'), publicDocument);
    }
    const syntheticKey = ['AI', 'za', 'A'.repeat(35)].join('');
    const generatedPath = largeGeneratedFile
      ? 'build/main.dart.js'
      : 'build/client.js';
    const generatedContent = largeGeneratedFile
      ? `${'x'.repeat(4 * 1024 * 1024 + 1)}${syntheticKey}\n`
      : `const clientKey = ${JSON.stringify(syntheticKey)};\n`;
    fs.writeFileSync(
      path.join(fixture, generatedPath),
      generatedContent,
    );

    execFileSync('git', ['init', '--quiet'], { cwd: fixture });
    execFileSync('git', ['add', '.gitignore', 'tool/public_repo_preflight.mjs'], {
      cwd: fixture,
    });
    if (trackGeneratedFile) {
      execFileSync('git', ['add', '--force', generatedPath], {
        cwd: fixture,
      });
    }

    const result = spawnSync(
      process.execPath,
      [path.join(fixture, 'tool', 'public_repo_preflight.mjs')],
      { cwd: fixture, encoding: 'utf8' },
    );
    const report = JSON.parse(
      fs.readFileSync(
        path.join(fixture, 'build', 'public_release_preflight', 'latest.json'),
        'utf8',
      ),
    );
    return { generatedPath, result, report };
  } finally {
    fs.rmSync(fixture, { recursive: true, force: true });
  }
}

test('Git-tracked generated API key is a blocker', () => {
  const { report } = runFixture({ trackGeneratedFile: true });
  const finding = report.findings.find(
    (candidate) =>
      candidate.name === 'tracked_generated_api_key_like_value' &&
      candidate.file === 'build/client.js',
  );

  assert.equal(finding?.severity, 'BLOCKER');
  assert.equal(report.pass, false);
});

test('untracked generated API key remains a local warning', () => {
  const { report } = runFixture({ trackGeneratedFile: false });
  const finding = report.findings.find(
    (candidate) =>
      candidate.name === 'generated_api_key_like_value' &&
      candidate.file === 'build/client.js',
  );

  assert.equal(finding?.severity, 'WARN');
  assert.equal(
    report.findings.some(
      (candidate) =>
        candidate.severity === 'BLOCKER' &&
        candidate.file === 'build/client.js',
    ),
    false,
  );
});

test('Git-tracked generated text above the scan limit is a blocker', () => {
  const { generatedPath, report } = runFixture({
    trackGeneratedFile: true,
    largeGeneratedFile: true,
  });
  const finding = report.findings.find(
    (candidate) =>
      candidate.name === 'tracked_large_file_scan_incomplete' &&
      candidate.file === generatedPath,
  );

  assert.equal(generatedPath, 'build/main.dart.js');
  assert.equal(finding?.severity, 'BLOCKER');
  assert.equal(report.pass, false);
});

test('untracked ignored generated text above the scan limit remains warning-only', () => {
  const { generatedPath, report } = runFixture({
    trackGeneratedFile: false,
    largeGeneratedFile: true,
  });
  const finding = report.findings.find(
    (candidate) =>
      candidate.name === 'large_generated_file_skipped' &&
      candidate.file === generatedPath,
  );

  assert.equal(generatedPath, 'build/main.dart.js');
  assert.equal(finding?.severity, 'WARN');
  assert.equal(
    report.findings.some(
      (candidate) =>
        candidate.severity === 'BLOCKER' &&
        candidate.file === generatedPath,
    ),
    false,
  );
});

test('exact clinical-validation negations remain permitted guardrails', () => {
  const { report } = runFixture({
    trackGeneratedFile: false,
    publicDocument: 'The prototype is not clinically validated. Nothing is clinically validated or approved. It was never clinically validated.',
  });
  assert.equal(report.findings.some((finding) => finding.name === 'high_risk_public_claim'), false);
});

test('a negated clinical claim does not hide a separate affirmative claim', () => {
  const { report } = runFixture({
    trackGeneratedFile: false,
    publicDocument: 'This was not clinically validated; now it is clinically validated.',
  });
  assert.equal(report.findings.some((finding) => finding.name === 'high_risk_public_claim' && finding.severity === 'BLOCKER'), true);
});
