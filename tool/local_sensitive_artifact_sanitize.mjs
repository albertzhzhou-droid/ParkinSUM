#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const args = parseArgs(process.argv.slice(2));
const root = path.resolve(required(args.root, '--root'));
const dryRun = Boolean(args['dry-run']);
const allowedNames = new Set(['operator_tokens', 'operator_audit', 'user_exports']);

if (!fs.existsSync(root)) {
  throw new Error(`Artifact root does not exist: ${root}`);
}

const files = [];
for (const name of allowedNames) {
  const dir = path.join(root, name);
  if (!fs.existsSync(dir)) continue;
  for (const filePath of walk(dir)) {
    if (/\.(json|jsonl)$/i.test(filePath)) {
      files.push(filePath);
    }
  }
}

const changed = [];
for (const filePath of files) {
  const original = fs.readFileSync(filePath, 'utf8');
  const sanitized = filePath.endsWith('.jsonl')
    ? sanitizeJsonl(original)
    : sanitizeJson(original);
  if (sanitized !== original) {
    changed.push(path.relative(root, filePath));
    if (!dryRun) {
      fs.writeFileSync(filePath, sanitized, { mode: 0o600 });
    }
  }
  if (!dryRun) {
    try {
      fs.chmodSync(filePath, 0o600);
    } catch (_) {
      // Best-effort on filesystems that do not preserve POSIX modes.
    }
  }
}

console.log(JSON.stringify({
  command: 'local-sensitive-artifact-sanitize',
  root,
  dryRun,
  scanned: files.length,
  changed,
}, null, 2));

function sanitizeJson(text) {
  try {
    return `${JSON.stringify(sanitizeValue(JSON.parse(text)), null, 2)}\n`;
  } catch (_) {
    return `${redactText(text)}\n`;
  }
}

function sanitizeJsonl(text) {
  return text
    .split(/\r?\n/)
    .filter((line) => line.length > 0)
    .map((line) => {
      try {
        return JSON.stringify(sanitizeValue(JSON.parse(line)));
      } catch (_) {
        return redactText(line);
      }
    })
    .join('\n') + '\n';
}

function sanitizeValue(value, key = '') {
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeValue(item, key));
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([entryKey, entryValue]) => [
        entryKey,
        sanitizeValue(entryValue, entryKey),
      ]),
    );
  }
  if (typeof value !== 'string') return value;
  if (/^(idToken|refreshToken|password|authorization|credential|secret)$/i.test(key)) {
    return '[REDACTED]';
  }
  if (/uid$/i.test(key)) {
    return hashValue(value);
  }
  if (/email$/i.test(key)) {
    return redactEmail(value);
  }
  if (key === 'path' || key === 'scope' || key === 'firestoreScope') {
    return redactFirestorePath(value);
  }
  return redactText(value);
}

function redactText(value) {
  return String(value)
    .replace(/users\/([^/\s"'\\]+)/g, (_match, uid) => {
      return `users/${hashValue(decodeURIComponentSafe(uid))}`;
    })
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)?/g, '[JWT_REDACTED]')
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, redactEmail);
}

function redactFirestorePath(value) {
  return String(value).replace(/users\/([^/\s]+)/g, (_match, uid) => {
    return `users/${hashValue(decodeURIComponentSafe(uid))}`;
  });
}

function redactEmail(email) {
  const [local, domain] = String(email).split('@');
  if (!domain) return '[EMAIL_REDACTED]';
  return `${local.slice(0, 2)}***@${domain}`;
}

function hashValue(value) {
  return `sha256:${crypto.createHash('sha256').update(String(value)).digest('hex').slice(0, 12)}`;
}

function decodeURIComponentSafe(value) {
  try {
    return decodeURIComponent(value);
  } catch (_) {
    return value;
  }
}

function* walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walk(fullPath);
    } else if (entry.isFile()) {
      yield fullPath;
    }
  }
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

function required(value, flag) {
  if (value == null || value === true || String(value).trim() === '') {
    throw new Error(`${flag} is required`);
  }
  return String(value).trim();
}
