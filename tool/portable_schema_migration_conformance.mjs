#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const modulePath = fileURLToPath(import.meta.url);
const repoRoot = path.dirname(path.dirname(modulePath));
const vectorPath = path.join(
  repoRoot,
  'build/portable_schema_migration/dart_vectors.json',
);
const reportPath = path.join(
  repoRoot,
  'build/portable_schema_migration/node_conformance.json',
);

const filePaths = [
  'profile.json',
  'preferences.json',
  'medication_selections.json',
  'intakes.json',
  'meals.json',
  'reminders.json',
  'audit_links.json',
];
const v4FilePaths = [...filePaths, 'observations.json'];
const rootFields = ['files', 'format', 'manifest', 'schemaVersion'];
const v2ReminderFields = [
  'activationTokenStatus',
  'deliveryBoundary',
  'enabled',
  'id',
  'kind',
  'label',
  'minuteOfDay',
  'weekdays',
];
const v3ReminderFields = [
  'activationTokenStatus',
  'deliveryBoundary',
  'enabled',
  'id',
  'kind',
  'label',
  'minuteOfDay',
  'notificationLocaleCode',
  'notificationLocaleDecisionCode',
  'notificationPrivacyMode',
  'presentationIdentityStatus',
  'sourcePresentationSchema',
  'sourcePresentationSha256',
  'targetSchedulingConsentStatus',
  'weekdays',
];
const addedReminderFields = v3ReminderFields.filter(
  (field) => !v2ReminderFields.includes(field),
);
const presentationSha =
  '29b86c90c1d3756bda93cf198c558863283924eb6a073fa278f7db9d6761cf23';
const reminderBoundary =
  'User-authored logging prompt only; not a prescribed medication time and not proof of operating-system delivery.';
const presentationSchema =
  'parkinsum.reminder-notification-presentation/1';
const presentationStatus = 'source_digest_only_recompute_on_target';
const targetConsent = 'required_before_target_permission_or_scheduling';
const reminderKinds = new Set(['mealLog', 'intakeLog']);
const privacyModes = new Set(['minimal', 'generic']);
const reminderLanguages = new Set([
  'en',
  'zh',
  'fr',
  'ja',
  'ko',
  'hi',
  'es',
  'vi',
  'th',
  'id',
  'ru',
  'pl',
  'ar',
]);
const manifestFields = [
  'createdAt',
  'files',
  'integrity',
  'ownerScope',
  'packageId',
  'privacyBoundary',
  'producer',
];
const ownerFields = [
  'bindingAlgorithm',
  'bindingDomain',
  'bindingSha256',
  'kind',
  'rawIdentifierIncluded',
];
const integrityFields = [
  'algorithm',
  'canonicalization',
  'contentSha256',
  'signatureStatus',
];
const privacyFields = [
  'containsSensitiveUserData',
  'encryption',
  'excluded',
  'identityLinkability',
  'notAClaim',
  'scope',
];
const manifestFileFields = ['path', 'recordCount', 'sha256'];
const scopeKinds = new Set([
  'firebase_authenticated_account',
  'local_device_account',
]);
const excludedValues = [
  'raw_account_uid',
  'raw_email',
  'raw_dose_owner_scope',
  'profile.patientId',
  'credentials',
  'reminder.activationToken',
  'local_ai_endpoints',
  'cloud_only_clinical_audit_documents',
];
const v4ExcludedValues = [...excludedValues, 'personalObservation.recorderId'];
const identityLinkabilityBoundary =
  'Raw account identifiers are excluded, but current dose receipts and medication assertions retain stable unsalted owner-scope digests for integrity verification. Those pseudonymous digests can link artifacts from the same scope and can be dictionary-matched when the source scope, such as a local email-derived identifier, has low entropy.';
const scopeDescription =
  'Current loaded profile, selections, intakes, meals, this-device reminders, and relationship audit links.';
const v4ScopeDescription =
  'Current loaded profile, selections, intakes, meals, this-device reminders, owner-entered personal observations, and relationship audit links.';
const notAClaim =
  'Not an encrypted backup, anonymous or unlinkable dataset, account deletion receipt, complete cloud export, clinical record, or legal-compliance certification.';
const numberTokensByContainer = new WeakMap();
const dartIntMinimum = -9223372036854775808n;
const dartIntMaximum = 9223372036854775807n;

function numberRecordFor(parent, key, currentValue) {
  if (!parent || typeof parent !== 'object') return undefined;
  const record = numberTokensByContainer.get(parent)?.get(String(key));
  return record && Object.is(record.parsedValue, currentValue)
    ? record
    : undefined;
}

function numberTokenFor(parent, key, currentValue) {
  return numberRecordFor(parent, key, currentValue)?.token;
}

function dartCanonicalNumber(value, token) {
  if (!Number.isFinite(value)) throw new Error('non_finite_number');
  if (/^-?(?:0|[1-9][0-9]*)$/u.test(token)) {
    const integer = BigInt(token);
    if (integer >= dartIntMinimum && integer <= dartIntMaximum) {
      return integer.toString();
    }
  }
  if (Object.is(value, -0)) return '-0.0';
  const encoded = value.toString();
  return /[.eE]/u.test(encoded) ? encoded : `${encoded}.0`;
}

export function isDartInt(parent, key, value) {
  if (typeof value !== 'number' || !Number.isInteger(value)) return false;
  const record = numberRecordFor(parent, key, value);
  if (!record) return Number.isSafeInteger(value);
  if (!/^-?(?:0|[1-9][0-9]*)$/u.test(record.token)) return false;
  const integer = BigInt(record.token);
  return integer >= dartIntMinimum && integer <= dartIntMaximum;
}

export function copyNumberTokenMetadata(source, target, keys) {
  if (
    !source ||
    typeof source !== 'object' ||
    !target ||
    typeof target !== 'object'
  ) {
    return target;
  }
  const sourceTokens = numberTokensByContainer.get(source);
  if (!sourceTokens) return target;
  const allowed = new Set((keys ?? Object.keys(target)).map(String));
  const copied = new Map(
    [...sourceTokens].filter(([key]) => allowed.has(String(key))),
  );
  if (copied.size > 0) numberTokensByContainer.set(target, copied);
  return target;
}

export function cloneJsonPreservingNumberTokens(value) {
  const clone = structuredClone(value);
  const transfer = (source, target) => {
    if (
      !source ||
      typeof source !== 'object' ||
      !target ||
      typeof target !== 'object'
    ) {
      return;
    }
    copyNumberTokenMetadata(source, target);
    if (Array.isArray(source) && Array.isArray(target)) {
      for (let index = 0; index < source.length; index += 1) {
        transfer(source[index], target[index]);
      }
      return;
    }
    for (const key of Object.keys(source)) transfer(source[key], target[key]);
  };
  transfer(value, clone);
  return clone;
}

function canonicalizeValue(value, parent = null, key = null) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean') {
    return JSON.stringify(value);
  }
  if (typeof value === 'number') {
    const token = numberTokenFor(parent, key, value);
    return token === undefined
      ? dartCanonicalNumber(value, Number.isInteger(value) ? `${value}` : `${value}.0`)
      : dartCanonicalNumber(value, token);
  }
  if (Array.isArray(value)) {
    return `[${value
      .map((item, index) => canonicalizeValue(item, value, index))
      .join(',')}]`;
  }
  if (typeof value === 'object') {
    return `{${Object.keys(value)
      .sort()
      .map(
        (childKey) =>
          `${JSON.stringify(childKey)}:${canonicalizeValue(
            value[childKey],
            value,
            childKey,
          )}`,
      )
      .join(',')}}`;
  }
  throw new Error(`unsupported_json_type:${typeof value}`);
}

export function canonicalize(value) {
  return canonicalizeValue(value);
}

export function digest(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function canonicalDigest(value) {
  return digest(canonicalize(value));
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

function recordCount(value) {
  if (Array.isArray(value)) return value.length;
  if (value && typeof value === 'object') {
    if (Array.isArray(value.records)) return value.records.length;
    if (Array.isArray(value.links)) return value.links.length;
  }
  return value && typeof value === 'object' ? 1 : 0;
}

function isSha256(value) {
  return typeof value === 'string' && /^[a-f0-9]{64}$/u.test(value);
}

function isCanonicalUtcTimestamp(value) {
  if (
    typeof value !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(?:\d{3})?Z$/u.test(
      value,
    )
  ) {
    return false;
  }
  if (value.length === 27 && value.slice(23, 26) === '000') return false;
  const millisecondForm = `${value.slice(0, 23)}Z`;
  return (
    Number.isFinite(Date.parse(millisecondForm)) &&
    new Date(millisecondForm).toISOString() === millisecondForm
  );
}

function reseal(root) {
  const files = root.files;
  const paths = root.schemaVersion >= 4 ? v4FilePaths : filePaths;
  const contentSha = canonicalDigest(files);
  root.manifest.integrity.contentSha256 = contentSha;
  root.manifest.files = paths.map((filePath) => ({
    path: filePath,
    sha256: canonicalDigest(files[filePath]),
    recordCount: recordCount(files[filePath]),
  }));
  root.manifest.packageId = digest(
    `parkinsum-portable-package-v${root.schemaVersion}|` +
      `${root.manifest.ownerScope.bindingSha256}|${contentSha}`,
  );
  return root;
}

export function validateEnvelope(document, version) {
  if (![2, 3, 4].includes(version)) throw new Error('unsupported_schema');
  const paths = version >= 4 ? v4FilePaths : filePaths;
  exactKeys(document, rootFields, 'root');
  if (
    document.format !== 'parkinsum_user_portable_data_package' ||
    !isDartInt(document, 'schemaVersion', document.schemaVersion) ||
    document.schemaVersion !== version
  ) {
    throw new Error('format_or_version_mismatch');
  }
  exactKeys(document.files, paths, 'files');
  exactKeys(document.manifest, manifestFields, 'manifest');
  exactKeys(document.manifest.ownerScope, ownerFields, 'owner_scope');
  exactKeys(document.manifest.integrity, integrityFields, 'integrity');
  exactKeys(document.manifest.privacyBoundary, privacyFields, 'privacy');
  const owner = document.manifest.ownerScope;
  const integrity = document.manifest.integrity;
  const privacy = document.manifest.privacyBoundary;
  if (
    owner.bindingAlgorithm !== 'SHA-256' ||
    owner.bindingDomain !== 'parkinsum-portable-owner-v1' ||
    owner.rawIdentifierIncluded !== false ||
    !scopeKinds.has(owner.kind) ||
    !isSha256(owner.bindingSha256) ||
    integrity.algorithm !== 'SHA-256' ||
    integrity.canonicalization !== 'sorted-key-json-v1' ||
    integrity.signatureStatus !== 'unsigned' ||
    !isSha256(integrity.contentSha256) ||
    !isSha256(document.manifest.packageId) ||
    document.manifest.producer !== 'parkinsum_companion' ||
    !isCanonicalUtcTimestamp(document.manifest.createdAt) ||
    privacy.encryption !== 'none' ||
    privacy.containsSensitiveUserData !== true ||
    JSON.stringify(privacy.excluded) !==
      JSON.stringify(version >= 4 ? v4ExcludedValues : excludedValues) ||
    privacy.identityLinkability !== identityLinkabilityBoundary ||
    privacy.scope !== (version >= 4 ? v4ScopeDescription : scopeDescription) ||
    privacy.notAClaim !== notAClaim
  ) {
    throw new Error('owner_integrity_or_privacy_contract');
  }
  const reminders = document.files['reminders.json'];
  if (!Array.isArray(reminders)) throw new Error('reminders_not_array');
  const reminderIds = new Set();
  reminders.forEach((row, index) => {
    exactKeys(
      row,
      version === 2 ? v2ReminderFields : v3ReminderFields,
      `reminder_${index}`,
    );
    if (
      typeof row.id !== 'string' ||
      !/^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$/u.test(row.id) ||
      Buffer.byteLength(row.id, 'utf8') > 256 ||
      !reminderKinds.has(row.kind) ||
      typeof row.label !== 'string' ||
      row.label.length === 0 ||
      row.label.trim() !== row.label ||
      [...row.label].length > 80 ||
      !isDartInt(row, 'minuteOfDay', row.minuteOfDay) ||
      row.minuteOfDay < 0 ||
      row.minuteOfDay > 1439 ||
      !Array.isArray(row.weekdays) ||
      row.weekdays.length === 0 ||
      row.weekdays.some(
        (day, dayIndex) =>
          !isDartInt(row.weekdays, dayIndex, day) ||
          day < 1 ||
          day > 7 ||
          (dayIndex > 0 && row.weekdays[dayIndex - 1] >= day),
      ) ||
      typeof row.enabled !== 'boolean' ||
      row.activationTokenStatus !== 'excluded_from_portable_package' ||
      row.deliveryBoundary !== reminderBoundary
    ) {
      throw new Error(`reminder_${index}_safety_contract`);
    }
    if (reminderIds.has(row.id)) {
      throw new Error(`reminder_${index}_duplicate_id`);
    }
    reminderIds.add(row.id);
    if (
      version >= 3 &&
      (!privacyModes.has(row.notificationPrivacyMode) ||
        !reminderLanguages.has(row.notificationLocaleCode) ||
        !reminderLanguages.has(row.notificationLocaleDecisionCode) ||
        row.sourcePresentationSchema !== presentationSchema ||
        !isSha256(row.sourcePresentationSha256) ||
        row.presentationIdentityStatus !== presentationStatus ||
        row.targetSchedulingConsentStatus !== targetConsent)
    ) {
      throw new Error(`reminder_${index}_presentation_contract`);
    }
  });
  if (version >= 4) validateObservations(document.files['observations.json']);
  if (
    !Array.isArray(document.manifest.files) ||
    document.manifest.files.length !== paths.length
  ) {
    throw new Error('manifest_inventory_size');
  }
  const manifestByPath = new Map();
  for (const [index, row] of document.manifest.files.entries()) {
    exactKeys(row, manifestFileFields, `manifest_file_${index}`);
    if (
      typeof row.path !== 'string' ||
      !isSha256(row.sha256) ||
      !isDartInt(row, 'recordCount', row.recordCount) ||
      row.recordCount < 0 ||
      manifestByPath.has(row.path)
    ) {
      throw new Error('manifest_inventory_row');
    }
    manifestByPath.set(row.path, row);
  }
  if (manifestByPath.size !== paths.length) {
    throw new Error('manifest_inventory_size');
  }
  for (const filePath of paths) {
    const row = manifestByPath.get(filePath);
    if (
      !row ||
      row.sha256 !== canonicalDigest(document.files[filePath]) ||
      row.recordCount !== recordCount(document.files[filePath])
    ) {
      throw new Error(`manifest_file_drift:${filePath}`);
    }
  }
  const contentSha = canonicalDigest(document.files);
  if (document.manifest.integrity.contentSha256 !== contentSha) {
    throw new Error('content_digest_drift');
  }
  const expectedPackageId = digest(
    `parkinsum-portable-package-v${version}|` +
      `${document.manifest.ownerScope.bindingSha256}|${contentSha}`,
  );
  if (document.manifest.packageId !== expectedPackageId) {
    throw new Error('package_identity_drift');
  }
  return true;
}

export function migrateV2ToV3(source) {
  const output = cloneJsonPreservingNumberTokens(source);
  output.schemaVersion = 3;
  output.files['reminders.json'] = output.files['reminders.json'].map((row) =>
    copyNumberTokenMetadata(row, {
      ...row,
      notificationPrivacyMode: 'minimal',
      notificationLocaleCode: 'en',
      notificationLocaleDecisionCode: 'en',
      sourcePresentationSchema:
        'parkinsum.reminder-notification-presentation/1',
      sourcePresentationSha256: presentationSha,
      presentationIdentityStatus: 'source_digest_only_recompute_on_target',
      targetSchedulingConsentStatus:
        'required_before_target_permission_or_scheduling',
    }),
  );
  return reseal(output);
}

function validateObservations(container) {
  exactKeys(container, ['availability', 'records'], 'observations');
  if (
    !['captured_current_local_snapshot', 'unavailable_in_source_schema'].includes(
      container.availability,
    ) ||
    !Array.isArray(container.records)
  ) {
    throw new Error('observations_container_contract');
  }
  if (
    container.availability === 'unavailable_in_source_schema' &&
    container.records.length !== 0
  ) {
    throw new Error('observations_unavailable_has_records');
  }
  const fields = [
    'schemaVersion',
    'id',
    'kind',
    'occurredAt',
    'recordedAt',
    'originalTimezone',
    'source',
    'recorderRole',
    'status',
    'symptomLabel',
    'severity',
    'notes',
    'motorState',
    'systolic',
    'diastolic',
    'unit',
    'posture',
  ];
  const ids = new Set();
  let previous = null;
  for (const [index, row] of container.records.entries()) {
    exactKeys(row, fields, `observation_${index}`);
    if (
      !isDartInt(row, 'schemaVersion', row.schemaVersion) ||
      row.schemaVersion !== 1 ||
      typeof row.id !== 'string' ||
      !/^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$/u.test(row.id) ||
      Buffer.byteLength(row.id, 'utf8') > 256 ||
      ids.has(row.id) ||
      row.recorderRole !== 'package_owner' ||
      !['symptom', 'selfReportedMotorState', 'bloodPressure'].includes(row.kind) ||
      !['selfReported', 'deviceManual', 'caregiverReported'].includes(row.source) ||
      !['recorded', 'notMeasured', 'unknown'].includes(row.status) ||
      !isCanonicalUtcTimestamp(row.occurredAt) ||
      !isCanonicalUtcTimestamp(row.recordedAt) ||
      !isPortableTimezone(row.originalTimezone) ||
      (row.symptomLabel !== null &&
        (typeof row.symptomLabel !== 'string' ||
          row.symptomLabel.trim() !== row.symptomLabel ||
          row.symptomLabel.length === 0 ||
          row.symptomLabel.length > 200)) ||
      (row.severity !== null &&
        (!isDartInt(row, 'severity', row.severity) ||
          row.severity < 0 ||
          row.severity > 10)) ||
      (row.notes !== null &&
        (typeof row.notes !== 'string' || row.notes.length > 4000)) ||
      (row.motorState !== null &&
        !['on', 'off', 'uncertain'].includes(row.motorState)) ||
      (row.systolic !== null &&
        (typeof row.systolic !== 'number' ||
          !Number.isFinite(row.systolic) ||
          row.systolic <= 0)) ||
      (row.diastolic !== null &&
        (typeof row.diastolic !== 'number' ||
          !Number.isFinite(row.diastolic) ||
          row.diastolic <= 0)) ||
      (row.posture !== null &&
        !['sitting', 'standing', 'lying', 'unknown'].includes(row.posture))
    ) {
      throw new Error(`observation_${index}_scalar_contract`);
    }
    if (
      row.status !== 'recorded' &&
      (row.severity !== null ||
        row.motorState !== null ||
        row.systolic !== null ||
        row.diastolic !== null)
    ) {
      throw new Error(`observation_${index}_missingness_contract`);
    }
    if (
      (row.kind === 'symptom' &&
        (row.symptomLabel === null ||
          row.motorState !== null ||
          row.systolic !== null ||
          row.diastolic !== null ||
          row.unit !== null ||
          row.posture !== null)) ||
      (row.kind === 'selfReportedMotorState' &&
        ((row.status === 'recorded' && row.motorState === null) ||
          row.symptomLabel !== null ||
          row.severity !== null ||
          row.systolic !== null ||
          row.diastolic !== null ||
          row.unit !== null ||
          row.posture !== null)) ||
      (row.kind === 'bloodPressure' &&
        (row.symptomLabel !== null ||
          row.severity !== null ||
          row.motorState !== null ||
          row.unit !== 'mm[Hg]' ||
          row.posture === null ||
          (row.status === 'recorded' &&
            (row.systolic === null || row.diastolic === null))))
    ) {
      throw new Error(`observation_${index}_typed_value_contract`);
    }
    if (previous !== null) {
      const order =
        previous.occurredAt.localeCompare(row.occurredAt) ||
        previous.recordedAt.localeCompare(row.recordedAt) ||
        previous.id.localeCompare(row.id);
      if (order > 0) throw new Error('observations_order_drift');
    }
    ids.add(row.id);
    previous = row;
  }
}

function isPortableTimezone(value) {
  if (value === 'UTC' || value === 'Z') return true;
  if (typeof value !== 'string') return false;
  const offset = value.startsWith('UTC') ? value.slice(3) : value;
  if (/^[+-]\d{2}:\d{2}$/u.test(offset)) {
    const hours = Number(offset.slice(1, 3));
    const minutes = Number(offset.slice(4, 6));
    return hours <= 14 && minutes < 60 && (hours !== 14 || minutes === 0);
  }
  return /^[A-Za-z][A-Za-z0-9_+-]*(?:\/[A-Za-z][A-Za-z0-9_+-]*)+$/u.test(value);
}

export function migrateV3ToV4(source) {
  const output = cloneJsonPreservingNumberTokens(source);
  output.schemaVersion = 4;
  output.files['observations.json'] = {
    availability: 'unavailable_in_source_schema',
    records: [],
  };
  output.manifest.privacyBoundary.scope = v4ScopeDescription;
  output.manifest.privacyBoundary.excluded = v4ExcludedValues;
  return reseal(output);
}

export function migrateV2ToV4(source) {
  return migrateV3ToV4(migrateV2ToV3(source));
}

export function validateReceipt(receipt) {
  const body = structuredClone(receipt);
  delete body.receiptSha256;
  if (canonicalDigest(body) !== receipt.receiptSha256) {
    throw new Error('receipt_digest_drift');
  }
  return true;
}

/// Parses JSON only after a small independent recursive-descent pass has
/// rejected duplicate object members. JSON.parse alone is last-value-wins.
export function parseJsonRejectingDuplicates(source, options = {}) {
  const limits = {
    maxNodes: options.maxNodes ?? 500000,
    maxDepth: options.maxDepth ?? 24,
    maxObjectFields: options.maxObjectFields ?? 128,
    maxStringTokenBytes: options.maxStringTokenBytes ?? 65536,
    maxDecodedStringUtf8Bytes: options.maxDecodedStringUtf8Bytes ?? 65536,
    maxKeyUtf8Bytes: options.maxKeyUtf8Bytes ?? 256,
    maxNumberTokenCharacters: options.maxNumberTokenCharacters ?? 128,
  };
  let index = 0;
  let nodes = 0;
  const numberRecords = [];
  const requireInteroperableUnicode = (value) => {
    for (const character of value) {
      const scalar = character.codePointAt(0);
      if (
        (scalar >= 0xd800 && scalar <= 0xdfff) ||
        (scalar >= 0xfdd0 && scalar <= 0xfdef) ||
        (scalar & 0xffff) === 0xfffe ||
        (scalar & 0xffff) === 0xffff
      ) {
        throw new Error('non_interoperable_unicode_scalar');
      }
    }
  };
  const skipWhitespace = () => {
    while (
      source[index] === ' ' ||
      source[index] === '\t' ||
      source[index] === '\n' ||
      source[index] === '\r'
    ) {
      index += 1;
    }
  };
  const parseString = () => {
    const start = index;
    if (source[index] !== '"') throw new Error('expected_string');
    index += 1;
    let sourceBytes = 0;
    const addSourceBytes = (count) => {
      sourceBytes += count;
    };
    const enforceSourceBudget = () => {
      if (sourceBytes > limits.maxStringTokenBytes) {
        throw new Error('string_budget');
      }
    };
    while (index < source.length) {
      const unit = source.charCodeAt(index);
      if (unit === 0x22) {
        index += 1;
        const decoded = JSON.parse(source.slice(start, index));
        requireInteroperableUnicode(decoded);
        if (
          Buffer.byteLength(decoded, 'utf8') >
          limits.maxDecodedStringUtf8Bytes
        ) {
          throw new Error('string_budget');
        }
        return decoded;
      }
      if (unit < 0x20) throw new Error('control_in_string');
      if (unit === 0x5c) {
        addSourceBytes(2);
        index += 1;
        const escaped = source[index++];
        if (escaped === 'u') {
          const firstHex = source.slice(index, index + 4);
          if (!/^[0-9a-fA-F]{4}$/u.test(firstHex)) {
            throw new Error('invalid_unicode_escape');
          }
          addSourceBytes(4);
          index += 4;
          const first = Number.parseInt(firstHex, 16);
          let scalar = first;
          if (first >= 0xd800 && first <= 0xdbff) {
            if (source.slice(index, index + 2) !== '\\u') {
              throw new Error('non_interoperable_unicode_scalar');
            }
            const secondHex = source.slice(index + 2, index + 6);
            if (!/^[0-9a-fA-F]{4}$/u.test(secondHex)) {
              throw new Error('invalid_unicode_escape');
            }
            const second = Number.parseInt(secondHex, 16);
            if (second < 0xdc00 || second > 0xdfff) {
              throw new Error('non_interoperable_unicode_scalar');
            }
            scalar =
              0x10000 + ((first - 0xd800) << 10) + (second - 0xdc00);
            addSourceBytes(6);
            index += 6;
          } else if (first >= 0xdc00 && first <= 0xdfff) {
            throw new Error('non_interoperable_unicode_scalar');
          }
          if (
            (scalar >= 0xfdd0 && scalar <= 0xfdef) ||
            (scalar & 0xffff) === 0xfffe ||
            (scalar & 0xffff) === 0xffff
          ) {
            throw new Error('non_interoperable_unicode_scalar');
          }
        } else if (!'"\\/bfnrt'.includes(escaped ?? '')) {
          throw new Error('invalid_escape');
        }
      } else if (unit <= 0x7f) {
        addSourceBytes(1);
        index += 1;
      } else if (unit <= 0x7ff) {
        addSourceBytes(2);
        index += 1;
      } else if (
        unit >= 0xd800 &&
        unit <= 0xdbff &&
        index + 1 < source.length &&
        source.charCodeAt(index + 1) >= 0xdc00 &&
        source.charCodeAt(index + 1) <= 0xdfff
      ) {
        const scalar =
          0x10000 +
          ((unit - 0xd800) << 10) +
          (source.charCodeAt(index + 1) - 0xdc00);
        if ((scalar & 0xffff) === 0xfffe || (scalar & 0xffff) === 0xffff) {
          throw new Error('non_interoperable_unicode_scalar');
        }
        addSourceBytes(4);
        index += 2;
      } else {
        if (
          (unit >= 0xd800 && unit <= 0xdfff) ||
          (unit >= 0xfdd0 && unit <= 0xfdef) ||
          unit === 0xfffe ||
          unit === 0xffff
        ) {
          throw new Error('non_interoperable_unicode_scalar');
        }
        addSourceBytes(3);
        index += 1;
      }
      enforceSourceBudget();
    }
    throw new Error('unterminated_string');
  };
  const isDigit = (char) => char >= '0' && char <= '9';
  const parseNumber = (path) => {
    const start = index;
    const advance = () => {
      index += 1;
      if (index - start > limits.maxNumberTokenCharacters) {
        throw new Error('number_token_budget');
      }
    };
    if (source[index] === '-') advance();
    if (source[index] === '0') {
      advance();
      if (isDigit(source[index])) throw new Error('invalid_value');
    } else {
      if (!(source[index] >= '1' && source[index] <= '9')) {
        throw new Error('invalid_value');
      }
      while (isDigit(source[index])) advance();
    }
    if (source[index] === '.') {
      advance();
      if (!isDigit(source[index])) throw new Error('invalid_value');
      while (isDigit(source[index])) advance();
    }
    if (source[index] === 'e' || source[index] === 'E') {
      advance();
      if (source[index] === '+' || source[index] === '-') advance();
      if (!isDigit(source[index])) throw new Error('invalid_value');
      while (isDigit(source[index])) advance();
    }
    const token = source.slice(start, index);
    let retainToken = /[.eE]/u.test(token);
    if (!retainToken && token.replace('-', '').length > 15) {
      try {
        const integer = BigInt(token);
        retainToken =
          integer > BigInt(Number.MAX_SAFE_INTEGER) ||
          integer < BigInt(Number.MIN_SAFE_INTEGER);
      } catch {
        retainToken = true;
      }
    }
    if (retainToken) {
      numberRecords.push({ path: [...path], token });
    }
  };
  const consumeLiteral = (literal) => {
    if (source.slice(index, index + literal.length) !== literal) {
      throw new Error('invalid_value');
    }
    index += literal.length;
  };
  const parseValue = (depth = 1, path = []) => {
    if (depth > limits.maxDepth) throw new Error('depth_budget');
    skipWhitespace();
    if (index >= source.length) throw new Error('invalid_value');
    nodes += 1;
    if (nodes > limits.maxNodes) throw new Error('node_budget');
    const char = source[index];
    if (char === '{') return parseObject(depth, path);
    if (char === '[') return parseArray(depth, path);
    if (char === '"') {
      parseString();
      return;
    }
    if (char === 't') return consumeLiteral('true');
    if (char === 'f') return consumeLiteral('false');
    if (char === 'n') return consumeLiteral('null');
    if (char === '-' || isDigit(char)) return parseNumber(path);
    throw new Error('invalid_value');
  };
  const parseArray = (depth, path) => {
    index += 1;
    skipWhitespace();
    if (source[index] === ']') {
      index += 1;
      return;
    }
    let itemIndex = 0;
    while (true) {
      parseValue(depth + 1, [...path, itemIndex]);
      itemIndex += 1;
      skipWhitespace();
      if (source[index] === ']') {
        index += 1;
        return;
      }
      if (source[index++] !== ',') throw new Error('array_separator');
    }
  };
  const parseObject = (depth, path) => {
    index += 1;
    const keys = new Set();
    let fields = 0;
    skipWhitespace();
    if (source[index] === '}') {
      index += 1;
      return;
    }
    while (true) {
      skipWhitespace();
      const key = parseString();
      fields += 1;
      if (fields > limits.maxObjectFields) throw new Error('width_budget');
      if (Buffer.byteLength(key, 'utf8') > limits.maxKeyUtf8Bytes) {
        throw new Error('key_utf8_budget');
      }
      if (keys.has(key)) throw new Error(`duplicate_object_member:${key}`);
      keys.add(key);
      skipWhitespace();
      if (source[index++] !== ':') throw new Error('object_colon');
      parseValue(depth + 1, [...path, key]);
      skipWhitespace();
      if (source[index] === '}') {
        index += 1;
        return;
      }
      if (source[index++] !== ',') throw new Error('object_separator');
    }
  };
  parseValue();
  skipWhitespace();
  if (index !== source.length) throw new Error('trailing_json_content');
  const parsed = JSON.parse(source);
  for (const record of numberRecords) {
    if (record.path.length === 0) continue;
    let parent = parsed;
    for (const segment of record.path.slice(0, -1)) parent = parent[segment];
    if (!parent || typeof parent !== 'object') continue;
    const key = String(record.path.at(-1));
    const tokens = numberTokensByContainer.get(parent) ?? new Map();
    tokens.set(key, { token: record.token, parsedValue: parent[key] });
    numberTokensByContainer.set(parent, tokens);
  }
  return parsed;
}

function validatorIdentity(descriptor) {
  return digest(
    `parkinsum-portable-validator-v1|${descriptor.version}|` +
      `${descriptor.schemaUri}|${descriptor.validatorVersion}|` +
      `${descriptor.structuralContractSha256}|${descriptor.semanticPolicySha256}`,
  );
}

function registryDigest(registry) {
  return canonicalDigest({
    schema: registry.schema,
    validators: registry.validators,
    migrations: registry.migrations,
  });
}

function reportDigest(report) {
  const body = { ...report };
  delete body.reportSha256;
  return canonicalDigest(body);
}

export function runConformance(vectors) {
  const failures = [];
  const fixtureResults = [];
  const numericCanonicalizationResults = [];
  if (reportDigest(vectors) !== vectors.reportSha256) {
    failures.push('dart_report_digest_drift');
  }
  if (registryDigest(vectors.registry) !== vectors.registry.registryDigest) {
    failures.push('registry_digest_drift');
  }
  for (const descriptor of vectors.registry.validators) {
    if (validatorIdentity(descriptor) !== descriptor.validatorIdentity) {
      failures.push(`validator_identity_drift:v${descriptor.version}`);
    }
  }

  for (const fixture of vectors.fixtures) {
    try {
      const parsed = parseJsonRejectingDuplicates(fixture.sourceJson);
      if (canonicalize(parsed) !== canonicalize(fixture.sourceDocument)) {
        throw new Error('source_document_drift');
      }
      validateEnvelope(parsed, parsed.schemaVersion);
      validateReceipt(fixture.receipt);
      const expectedOutput = parsed.schemaVersion === 2
        ? migrateV2ToV4(parsed)
        : parsed.schemaVersion === 3
        ? migrateV3ToV4(parsed)
        : cloneJsonPreservingNumberTokens(parsed);
      if (canonicalize(expectedOutput) !== canonicalize(fixture.outputDocument)) {
        throw new Error('independent_migration_output_drift');
      }
      if (fixture.receipt.sourceBytesSha256 !== digest(fixture.sourceJson)) {
        throw new Error('source_bytes_digest_drift');
      }
      if (
        fixture.receipt.sourceCanonicalSha256 !== canonicalDigest(parsed) ||
        fixture.receipt.outputCanonicalSha256 !== canonicalDigest(expectedOutput)
      ) {
        throw new Error('receipt_subject_digest_drift');
      }
      fixtureResults.push({ id: fixture.id, pass: true });
    } catch (error) {
      failures.push(`${fixture.id}:${error.message}`);
      fixtureResults.push({ id: fixture.id, pass: false, error: error.message });
    }
  }

  for (const fixture of vectors.numericCanonicalizationFixtures ?? []) {
    try {
      const parsed = parseJsonRejectingDuplicates(fixture.sourceJson);
      if (canonicalize(parsed) !== fixture.canonicalJson) {
        throw new Error('source_json_canonicalization_drift');
      }
      if (canonicalize(fixture.sourceDocument) !== fixture.canonicalJson) {
        throw new Error('source_document_canonicalization_drift');
      }
      numericCanonicalizationResults.push({ id: fixture.id, pass: true });
    } catch (error) {
      failures.push(`${fixture.id}:${error.message}`);
      numericCanonicalizationResults.push({
        id: fixture.id,
        pass: false,
        error: error.message,
      });
    }
  }

  const v2 = vectors.fixtures.find((fixture) => fixture.sourceDocument.schemaVersion === 2);
  const reordered = Object.fromEntries(Object.entries(v2.sourceDocument).reverse());
  const unknown = cloneJsonPreservingNumberTokens(v2.sourceDocument);
  unknown.futureField = true;
  const missing = cloneJsonPreservingNumberTokens(v2.sourceDocument);
  delete missing.files['reminders.json'][0].enabled;
  const mixed = cloneJsonPreservingNumberTokens(v2.sourceDocument);
  mixed.files['reminders.json'][0].notificationPrivacyMode = 'minimal';
  const future = cloneJsonPreservingNumberTokens(v2.sourceDocument);
  future.schemaVersion = 5;
  const duplicate = v2.sourceJson.replace(
    '"schemaVersion":2',
    '"schemaVersion":2,"schemaVersion":2',
  );
  const receiptMutation = structuredClone(v2.receipt);
  receiptMutation.outputCanonicalSha256 = '0'.repeat(64);
  const composed = cloneJsonPreservingNumberTokens(v2.sourceDocument);
  composed.files['reminders.json'][0].label = 'é';
  const decomposed = cloneJsonPreservingNumberTokens(v2.sourceDocument);
  decomposed.files['reminders.json'][0].label = 'é';

  const blocked = (callback) => {
    try {
      callback();
      return false;
    } catch {
      return true;
    }
  };
  const mutationResults = {
    property_reordering_preserves_canonical_output:
      canonicalize(reordered) === canonicalize(v2.sourceDocument) &&
      canonicalize(migrateV2ToV4(reordered)) ===
        canonicalize(v2.outputDocument),
    unknown_root_field_blocked: blocked(() => validateEnvelope(unknown, 2)),
    omitted_required_field_blocked: blocked(() => validateEnvelope(missing, 2)),
    mixed_version_field_blocked: blocked(() => validateEnvelope(mixed, 2)),
    duplicate_object_member_blocked_before_decode: blocked(() =>
      parseJsonRejectingDuplicates(duplicate),
    ),
    future_schema_blocked: blocked(() => validateEnvelope(future, 4)),
    receipt_digest_mutation_blocked: blocked(() =>
      validateReceipt(receiptMutation),
    ),
    null_and_zero_preserved:
      migrateV2ToV4(v2.sourceDocument).files['profile.json'].dietProfileRegion ===
        null &&
      migrateV2ToV4(v2.sourceDocument).files['reminders.json'][0].minuteOfDay === 0 &&
      migrateV2ToV4(v2.sourceDocument).files['observations.json'].availability ===
        'unavailable_in_source_schema',
    unicode_code_points_preserved_without_normalization:
      canonicalDigest(composed) !== canonicalDigest(decomposed),
  };
  for (const [id, pass] of Object.entries(mutationResults)) {
    if (!pass) failures.push(`mutation:${id}`);
  }

  return {
    schema: 'parkinsum.portable-schema-migration-cross-runtime-conformance/1',
    schemaVersion: 1,
    pass: failures.length === 0,
    failures,
    dartFixtureCount: fixtureResults.length,
    fixtureResults,
    numericCanonicalizationFixtureCount:
      numericCanonicalizationResults.length,
    numericCanonicalizationResults,
    mutationResults,
    independentRuntime: `node-${process.versions.node}`,
    boundary:
      'Independent frozen-fixture, Dart VM numeric-canonicalization, canonical-hash, migration and duplicate-member evidence for Dart/Node only. Not Dart web, issuer authenticity, encryption, durable import, every release platform, FHIR conformance, clinical correctness, or medical advice.',
  };
}

function main() {
  const vectors = parseJsonRejectingDuplicates(
    fs.readFileSync(vectorPath, 'utf8'),
  );
  const report = runConformance(vectors);
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(
    `Portable schema migration Node conformance: ${report.pass ? 'pass' : 'FAIL'}; ` +
      `${report.dartFixtureCount} package fixtures; ` +
      `${report.numericCanonicalizationFixtureCount} numeric fixture(s); ` +
      `artifact=${path.relative(repoRoot, reportPath)}`,
  );
  if (!report.pass) {
    for (const failure of report.failures) console.error(`- ${failure}`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === modulePath) main();
