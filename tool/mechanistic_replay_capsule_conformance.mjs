#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseJsonRejectingDuplicates } from './portable_schema_migration_conformance.mjs';

const modulePath = fileURLToPath(import.meta.url);
const repoRoot = path.dirname(path.dirname(modulePath));
const vectorPath = path.join(
  repoRoot,
  'build/mechanistic_replay_capsule/dart_vectors.json',
);
const reportPath = path.join(
  repoRoot,
  'build/mechanistic_replay_capsule/node_conformance.json',
);
const marker = '$parkinsum_number';
export const replayTimezoneContract = Object.freeze({
  timestamp_semantic: 'historical_event_instant',
  engine_time_representation: 'utc_epoch_minute',
  ledger_time_representation: 'offset_timestamp_plus_utc_instant',
  iana_zone_id: null,
  tzdb_version: null,
  future_civil_time_authorized: false,
  boundary: 'The current engine consumes historical UTC minutes. Event-specific ' +
    'offsets survive in the embedded ledger, but no IANA zone, tzdb ' +
    'release, DST fold or future civil-time intent is fabricated.',
});
export const replayMaxJsonBytes = 2 * 1024 * 1024;
export const replayMaxJsonContainerDepth = 32;
const expectedRootKeys = [
  'canonicalization_profile',
  'capsule_id',
  'capsule_sha256',
  'context',
  'generated_at_utc',
  'ledger',
  'meal_compositions',
  'schema',
  'schema_version',
  'timezone_contract',
];

export function canonicalize(value) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error('non_finite_json_number');
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalize).join(',')}]`;
  }
  if (typeof value === 'object') {
    const keys = Object.keys(value).sort();
    return `{${keys
      .map((key) => `${JSON.stringify(key)}:${canonicalize(value[key])}`)
      .join(',')}}`;
  }
  throw new Error(`unsupported_json_type:${typeof value}`);
}

export function bodyDigest(capsule) {
  const body = structuredClone(capsule);
  delete body.capsule_sha256;
  return crypto.createHash('sha256').update(canonicalize(body)).digest('hex');
}

function exactKeys(value, expected, label) {
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    throw new Error(`${label}_not_object`);
  }
  const actual = Object.keys(value).sort();
  if (JSON.stringify(actual) !== JSON.stringify([...expected].sort())) {
    throw new Error(`${label}_key_mismatch`);
  }
}

function validateEncodedPayload(value, pathLabel = 'payload') {
  if (value === null || typeof value === 'string' || typeof value === 'boolean') {
    return;
  }
  if (typeof value === 'number') {
    throw new Error(`${pathLabel}_native_number_forbidden`);
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => validateEncodedPayload(item, `${pathLabel}[${index}]`));
    return;
  }
  if (typeof value !== 'object') throw new Error(`${pathLabel}_invalid_type`);
  if (Object.hasOwn(value, marker)) {
    exactKeys(value, [marker, 'value'], `${pathLabel}_number`);
    if (typeof value.value !== 'string') throw new Error(`${pathLabel}_number_value_not_string`);
    if (value[marker] === 'i64') {
      if (!/^-?(0|[1-9][0-9]*)$/.test(value.value)) {
        throw new Error(`${pathLabel}_noncanonical_i64`);
      }
      const parsed = BigInt(value.value);
      if (parsed < -9007199254740991n || parsed > 9007199254740991n) {
        throw new Error(`${pathLabel}_unsafe_i64`);
      }
      return;
    }
    if (value[marker] === 'f64') {
      if (!/^[0-9a-f]{16}$/.test(value.value)) {
        throw new Error(`${pathLabel}_noncanonical_f64`);
      }
      const bytes = Buffer.from(value.value, 'hex');
      const parsed = bytes.readDoubleBE(0);
      if (!Number.isFinite(parsed)) throw new Error(`${pathLabel}_nonfinite_f64`);
      return;
    }
    throw new Error(`${pathLabel}_unknown_number_kind`);
  }
  for (const [key, child] of Object.entries(value)) {
    validateEncodedPayload(child, `${pathLabel}.${key}`);
  }
}

function validateGeneratedAt(value) {
  if (typeof value !== 'string') throw new Error('invalid_generated_at_utc');
  const m = /^(-[0-9]{4}|[0-9]{4}|[+-][0-9]{6})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})\.([0-9]{3})([0-9]{3})?Z$/.exec(value);
  if (!m) throw new Error('noncanonical_generated_at_utc');
  const [year,month,day,hour,minute,second,millisecond] = m.slice(1,8).map(Number);
  const yearText = Math.abs(year) <= 9999 ?
    `${year < 0 ? '-' : ''}${String(Math.abs(year)).padStart(4,'0')}` :
    `${year < 0 ? '-' : '+'}${String(Math.abs(year)).padStart(6,'0')}`;
  // Dart emits microseconds only when the three extra digits are nonzero.
  if (m[1] !== yearText || m[8] === '000') throw new Error('noncanonical_generated_at_utc');
  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  date.setUTCHours(hour, minute, second, millisecond);
  if (!Number.isFinite(date.getTime()) || date.getUTCFullYear() !== year ||
      date.getUTCMonth() + 1 !== month || date.getUTCDate() !== day ||
      date.getUTCHours() !== hour || date.getUTCMinutes() !== minute ||
      date.getUTCSeconds() !== second || date.getUTCMilliseconds() !== millisecond) {
    throw new Error('invalid_generated_at_utc');
  }
}

export function validateCapsule(capsule) {
  exactKeys(capsule, expectedRootKeys, 'capsule');
  if (capsule.schema !== 'parkinsum.mechanistic-replay-capsule/1' ||
      capsule.schema_version !== 1) {
    throw new Error('unsupported_capsule_schema');
  }
  if (capsule.canonicalization_profile !==
      'parkinsum.jcs-safe-lossless-scalars/1') {
    throw new Error('unsupported_canonicalization_profile');
  }
  if (typeof capsule.capsule_id !== 'string' ||
      !/^[A-Za-z0-9._:-]{1,160}$/.test(capsule.capsule_id)) {
    throw new Error('invalid_capsule_id');
  }
  validateGeneratedAt(capsule.generated_at_utc);
  exactKeys(capsule.timezone_contract, Object.keys(replayTimezoneContract), 'timezone_contract');
  if (canonicalize(capsule.timezone_contract) !== canonicalize(replayTimezoneContract)) {
    throw new Error('timezone_contract_drift');
  }
  for (const key of ['ledger','context']) {
    if (capsule[key] === null || Array.isArray(capsule[key]) || typeof capsule[key] !== 'object') {
      throw new Error(`${key}_not_object`);
    }
  }
  if (!Array.isArray(capsule.meal_compositions)) throw new Error('meal_compositions_not_list');
  if (typeof capsule.capsule_sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(capsule.capsule_sha256)) {
    throw new Error('invalid_capsule_digest_format');
  }
  if (bodyDigest(capsule) !== capsule.capsule_sha256) {
    throw new Error('capsule_digest_mismatch');
  }
  validateEncodedPayload(capsule.ledger, 'ledger');
  validateEncodedPayload(capsule.context, 'context');
  validateEncodedPayload(capsule.meal_compositions, 'meal_compositions');
  return true;
}

export function parseCapsuleJson(source) {
  if (source.length > replayMaxJsonBytes ||
      Buffer.byteLength(source, 'utf8') > replayMaxJsonBytes) {
    throw new Error('replay_json_byte_limit');
  }
  const capsule = parseJsonRejectingDuplicates(source, {
    // The independent parser counts scalar leaves too; Dart counts containers.
    maxDepth: replayMaxJsonContainerDepth + 1,
    maxNodes: replayMaxJsonBytes,
    maxObjectFields: replayMaxJsonBytes,
    maxStringTokenBytes: replayMaxJsonBytes,
    maxDecodedStringUtf8Bytes: replayMaxJsonBytes,
    maxKeyUtf8Bytes: replayMaxJsonBytes,
    maxNumberTokenCharacters: 128,
  });
  validateCapsule(capsule);
  return capsule;
}

function firstWrapper(value, kind = null) {
  if (value && typeof value === 'object') {
    if (!Array.isArray(value) &&
        Object.hasOwn(value, marker) &&
        (kind === null || value[marker] === kind)) return value;
    for (const child of Array.isArray(value) ? value : Object.values(value)) {
      const found = firstWrapper(child, kind);
      if (found) return found;
    }
  }
  return null;
}

export function runConformance(vectorsDocument) {
  const failures = [];
  const vectorResults = [];
  for (const vector of vectorsDocument.vectors ?? []) {
    try {
      const capsule = parseCapsuleJson(vector.canonical_json);
      if (canonicalize(capsule) !== vector.canonical_json) {
        throw new Error('canonical_bytes_mismatch');
      }
      if (capsule.capsule_sha256 !== vector.capsule_sha256) {
        throw new Error('vector_digest_mismatch');
      }
      vectorResults.push({ scenario: vector.scenario, pass: true });
    } catch (error) {
      failures.push(`${vector.scenario}:${error.message}`);
      vectorResults.push({ scenario: vector.scenario, pass: false, error: error.message });
    }
  }
  const reference = JSON.parse(vectorsDocument.vectors[0].canonical_json);
  const reordered = Object.fromEntries(Object.entries(reference).reverse());
  const reorderStable = canonicalize(reordered) === canonicalize(reference) &&
    bodyDigest(reordered) === reference.capsule_sha256;

  const floatingMutation = structuredClone(reference);
  const wrapper = firstWrapper(floatingMutation.context, 'f64');
  wrapper.value = `${wrapper.value.slice(0, -1)}${wrapper.value.endsWith('0') ? '1' : '0'}`;
  const floatingMutationDetected = bodyDigest(floatingMutation) !== reference.capsule_sha256;

  const nativeNumberMutation = structuredClone(reference);
  const nativeParent = firstWrapper(nativeNumberMutation.context);
  delete nativeParent[marker];
  delete nativeParent.value;
  nativeParent.native = 1;
  nativeNumberMutation.capsule_sha256 = bodyDigest(nativeNumberMutation);
  let nativeNumberBlocked = false;
  try {
    validateCapsule(nativeNumberMutation);
  } catch (error) {
    nativeNumberBlocked = /native_number_forbidden/.test(error.message);
  }

  const nullMissingMutation = structuredClone(reference);
  delete nullMissingMutation.timezone_contract.iana_zone_id;
  nullMissingMutation.capsule_sha256 = bodyDigest(nullMissingMutation);
  const nullMissingDistinct = canonicalize(nullMissingMutation) !== canonicalize(reference);

  const unicodeComposed = structuredClone(reference);
  unicodeComposed.capsule_id = 'unicode_é';
  unicodeComposed.capsule_sha256 = bodyDigest(unicodeComposed);
  const unicodeDecomposed = structuredClone(reference);
  unicodeDecomposed.capsule_id = 'unicode_é';
  unicodeDecomposed.capsule_sha256 = bodyDigest(unicodeDecomposed);
  const unicodeDistinct = unicodeComposed.capsule_sha256 !== unicodeDecomposed.capsule_sha256;

  const mutationResults = {
    map_reordering_stable: reorderStable,
    binary64_bit_mutation_detected: floatingMutationDetected,
    native_json_number_blocked: nativeNumberBlocked,
    null_and_missing_distinct: nullMissingDistinct,
    unicode_code_points_distinct: unicodeDistinct,
  };
  const anomalyResults = {};
  for (const anomaly of vectorsDocument.raw_json_anomalies ?? []) {
    try {
      parseCapsuleJson(anomaly.raw_json);
      anomalyResults[anomaly.id] = false;
    } catch (error) {
      const actualReason = /duplicate_object_member/.test(error.message) ? 'duplicate_member' :
        /depth_budget/.test(error.message) ? 'depth_limit' :
        /replay_json_byte_limit/.test(error.message) ? 'byte_limit' :
        /unsupported_capsule_schema/.test(error.message) ? 'schema' :
        /capsule_digest_mismatch/.test(error.message) ? 'digest' : 'invalid_json';
      anomalyResults[anomaly.id] = actualReason === anomaly.expected_reason;
    }
    if (!anomalyResults[anomaly.id]) failures.push(`anomaly:${anomaly.id}`);
  }
  for (const [id, pass] of Object.entries(mutationResults)) {
    if (!pass) failures.push(`mutation:${id}`);
  }
  return {
    schema: 'parkinsum.mechanistic-replay-cross-runtime-conformance/1',
    schema_version: 1,
    pass: failures.length === 0,
    failures,
    dart_vector_count: vectorResults.length,
    vector_results: vectorResults,
    mutation_results: mutationResults,
    raw_json_anomaly_results: anomalyResults,
    independent_runtime: `node-${process.versions.node}`,
    boundary:
      'Independent canonical-byte, digest, scalar-profile and mutation evidence. ' +
      'This is not every release platform, IANA/tzdb replay, biological truth, ' +
      'clinical calibration, benefit, safety, regulatory qualification, or medical advice.',
  };
}

function main() {
  const vectors = JSON.parse(fs.readFileSync(vectorPath, 'utf8'));
  const report = runConformance(vectors);
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(
    `Mechanistic replay capsule Node conformance: ${report.pass ? 'pass' : 'FAIL'}; ` +
      `${report.dart_vector_count} vectors; artifact=${path.relative(repoRoot, reportPath)}`,
  );
  if (!report.pass) {
    for (const failure of report.failures) console.error(`- ${failure}`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === modulePath) main();
