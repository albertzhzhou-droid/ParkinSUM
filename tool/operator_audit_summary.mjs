#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const args = parseArgs(process.argv.slice(2));
const input = args.input ?? 'build/operator_audit/operator_audit.jsonl';
const releaseId = args['release-id'] ?? `audit_${timestamp()}`;
const output =
  args.output ??
  path.join('build', 'operator_reports', `${releaseId}_audit_summary.json`);
const markdownOutput = output.replace(/\.json$/, '.md');

const records = readJsonl(input);
const summary = summarize(records);

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(summary, null, 2)}\n`);
fs.writeFileSync(markdownOutput, renderMarkdown(summary));
console.log(JSON.stringify({ output, markdownOutput, pass: true }, null, 2));

function summarize(records) {
  const byEnvironment = {};
  const byAction = {};
  const byProject = {};
  let firstTimestamp = null;
  let lastTimestamp = null;

  for (const record of records) {
    const timestamp = record.timestamp ?? null;
    if (timestamp && (firstTimestamp == null || timestamp < firstTimestamp)) {
      firstTimestamp = timestamp;
    }
    if (timestamp && (lastTimestamp == null || timestamp > lastTimestamp)) {
      lastTimestamp = timestamp;
    }
    increment(byEnvironment, record.environment ?? 'unknown');
    increment(byProject, record.projectId ?? 'unknown');
    increment(byAction, record.action ?? record.command ?? 'unknown');
  }

  return {
    reportType: 'operator_audit_summary',
    generatedAt: new Date().toISOString(),
    source: input,
    recordCount: records.length,
    firstTimestamp,
    lastTimestamp,
    byEnvironment,
    byProject,
    byAction,
    redactionPolicy: {
      tokens: 'redacted',
      credentialPaths: 'redacted',
      emails: 'redacted',
      uids: 'sha256-prefix',
      userData: 'not included in summary',
    },
    sanitizedSamples: records.slice(-10).map(redact),
  };
}

function redact(value, key = '') {
  if (Array.isArray(value)) return value.map((item) => redact(item, key));
  if (value && typeof value === 'object') {
    const next = {};
    for (const [childKey, childValue] of Object.entries(value)) {
      next[childKey] = redact(childValue, childKey);
    }
    return next;
  }
  if (value == null) return value;
  const text = String(value);
  const normalizedKey = key.toLowerCase();
  if (
    normalizedKey.includes('token') ||
    normalizedKey.includes('credential') ||
    normalizedKey.includes('authorization') ||
    normalizedKey.includes('password')
  ) {
    return '[REDACTED]';
  }
  if (normalizedKey === 'uid' || normalizedKey.endsWith('uid')) {
    return hashId(text);
  }
  if (text.includes('@')) {
    return text.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[EMAIL_REDACTED]');
  }
  return text.replace(/users\/([^/\s"]+)/g, (_, uid) => `users/${hashId(uid)}`);
}

function hashId(value) {
  return `sha256:${crypto.createHash('sha256').update(value).digest('hex').slice(0, 12)}`;
}

function increment(target, key) {
  target[key] = (target[key] ?? 0) + 1;
}

function readJsonl(filePath) {
  if (!fs.existsSync(filePath)) return [];
  return fs
    .readFileSync(filePath, 'utf8')
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line, index) => {
      try {
        return JSON.parse(line);
      } catch (error) {
        return {
          timestamp: null,
          action: 'invalid_jsonl_record',
          line: index + 1,
          error: error.message,
        };
      }
    });
}

function renderMarkdown(summary) {
  return `# Operator Audit Summary

Generated at: ${summary.generatedAt}
Source: ${summary.source}
Records: ${summary.recordCount}
First timestamp: ${summary.firstTimestamp ?? 'none'}
Last timestamp: ${summary.lastTimestamp ?? 'none'}

## By Environment

${table(summary.byEnvironment)}

## By Project

${table(summary.byProject)}

## By Action

${table(summary.byAction)}

## Redaction

- Tokens, credentials, passwords, and authorization values are redacted.
- Emails are replaced with [EMAIL_REDACTED].
- UIDs are represented as sha256 prefixes.
- User-entered clinical details are not included in this summary.
`;
}

function table(counts) {
  const entries = Object.entries(counts).sort(([a], [b]) => a.localeCompare(b));
  if (entries.length === 0) return '| Key | Count |\n| --- | --- |\n| none | 0 |';
  return ['| Key | Count |', '| --- | --- |', ...entries.map(([key, count]) => `| ${key} | ${count} |`)].join('\n');
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
