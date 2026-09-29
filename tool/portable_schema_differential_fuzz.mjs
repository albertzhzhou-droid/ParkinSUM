#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  canonicalDigest,
  cloneJsonPreservingNumberTokens,
  copyNumberTokenMetadata,
  digest,
  isDartInt,
  migrateV2ToV4,
  migrateV3ToV4,
  parseJsonRejectingDuplicates,
  runConformance,
  validateEnvelope,
} from './portable_schema_migration_conformance.mjs';

const modulePath = fileURLToPath(import.meta.url);
const repoRoot = path.dirname(path.dirname(modulePath));
const dartReportPath = path.join(
  repoRoot,
  'build/portable_schema_fuzz/dart_campaign.json',
);
const migrationVectorsPath = path.join(
  repoRoot,
  'build/portable_schema_migration/dart_vectors.json',
);
const outputPath = path.join(
  repoRoot,
  'build/portable_schema_fuzz/node_conformance.json',
);

const defaultBudgets = Object.freeze({
  packageBytes: 33554432,
  jsonNodes: 500000,
  jsonDepth: 24,
  objectFields: 128,
  stringTokenBytes: 65536,
  decodedStringUtf8Bytes: 65536,
  keyUtf8Bytes: 256,
  numberTokenCharacters: 128,
  caseObservationMilliseconds: 2000,
});
const rootFields = ['files', 'format', 'manifest', 'schemaVersion'];
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

function parserOptions(budgets) {
  return {
    maxNodes: budgets.jsonNodes,
    maxDepth: budgets.jsonDepth,
    maxObjectFields: budgets.objectFields,
    maxStringTokenBytes: budgets.stringTokenBytes,
    maxDecodedStringUtf8Bytes: budgets.decodedStringUtf8Bytes,
    maxKeyUtf8Bytes: budgets.keyUtf8Bytes,
    maxNumberTokenCharacters: budgets.numberTokenCharacters,
  };
}

function parserFailureReason(error) {
  const message = error instanceof Error ? error.message : '';
  if (message.startsWith('duplicate_object_member:')) return 'duplicate_member';
  if (message === 'non_interoperable_unicode_scalar') {
    return 'non_interoperable_unicode';
  }
  if (message === 'depth_budget') return 'depth_budget';
  if (message === 'node_budget') return 'node_budget';
  if (message === 'width_budget') return 'object_width_budget';
  if (message === 'string_budget') return 'string_budget';
  if (message === 'key_utf8_budget') return 'key_utf8_budget';
  if (message === 'number_token_budget') return 'number_token_budget';
  return 'malformed_or_structural_budget';
}

function fieldRelation(value, expected) {
  if (!value || Array.isArray(value) || typeof value !== 'object') {
    return { missing: [...expected], extra: [] };
  }
  const actual = new Set(Object.keys(value));
  const expectedSet = new Set(expected);
  return {
    missing: expected.filter((field) => !actual.has(field)),
    extra: [...actual].filter((field) => !expectedSet.has(field)),
  };
}

function schemaFieldRelation(document, version) {
  const paths = version >= 4 ? v4FilePaths : filePaths;
  const relations = [
    fieldRelation(document, rootFields),
    fieldRelation(document?.files, paths),
    fieldRelation(document?.manifest, manifestFields),
    fieldRelation(document?.manifest?.ownerScope, ownerFields),
    fieldRelation(document?.manifest?.integrity, integrityFields),
    fieldRelation(document?.manifest?.privacyBoundary, privacyFields),
  ];
  const manifestRows = document?.manifest?.files;
  if (Array.isArray(manifestRows)) {
    for (const row of manifestRows) {
      relations.push(fieldRelation(row, manifestFileFields));
    }
  }
  const reminders = document?.files?.['reminders.json'];
  if (Array.isArray(reminders)) {
    const expected = version === 2 ? v2ReminderFields : v3ReminderFields;
    for (const reminder of reminders) {
      relations.push(fieldRelation(reminder, expected));
    }
  }
  if (version >= 4) {
    const observations = document?.files?.['observations.json'];
    relations.push(fieldRelation(observations, ['availability', 'records']));
    if (Array.isArray(observations?.records)) {
      const observationFields = [
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
      for (const observation of observations.records) {
        relations.push(fieldRelation(observation, observationFields));
      }
    }
  }
  return {
    missing: relations.flatMap((relation) => relation.missing),
    extra: relations.flatMap((relation) => relation.extra),
  };
}

function registryDigest(registry) {
  return canonicalDigest({
    schema: registry.schema,
    validators: registry.validators,
    migrations: registry.migrations,
  });
}

function recordCount(value) {
  if (Array.isArray(value)) return value.length;
  if (value && typeof value === 'object') {
    if (Array.isArray(value.records)) return value.records.length;
    if (Array.isArray(value.links)) return value.links.length;
  }
  return value && typeof value === 'object' ? 1 : 0;
}

function validateOriginalIntegrity(document, version) {
  const paths = version >= 4 ? v4FilePaths : filePaths;
  const files = document.files;
  const manifest = document.manifest;
  if (!files || !manifest || !Array.isArray(manifest.files)) {
    throw new Error('integrity_shape');
  }
  const byPath = new Map(manifest.files.map((row) => [row?.path, row]));
  if (
    manifest.files.length !== paths.length ||
    byPath.size !== paths.length ||
    [...byPath.keys()].some((filePath) => !paths.includes(filePath))
  ) {
    throw new Error('manifest_inventory');
  }
  for (const filePath of paths) {
    const row = byPath.get(filePath);
    if (
      !row ||
      row.sha256 !== canonicalDigest(files[filePath]) ||
      row.recordCount !== recordCount(files[filePath])
    ) {
      throw new Error('manifest_file_integrity');
    }
  }
  const contentSha256 = canonicalDigest(files);
  if (manifest.integrity?.contentSha256 !== contentSha256) {
    throw new Error('content_integrity');
  }
  const expectedPackageId = digest(
    `parkinsum-portable-package-v${version}|` +
      `${manifest.ownerScope?.bindingSha256}|${contentSha256}`,
  );
  if (manifest.packageId !== expectedPackageId) {
    throw new Error('package_integrity');
  }
}

function pickFields(value, fields) {
  return copyNumberTokenMetadata(
    value,
    Object.fromEntries(fields.map((field) => [field, value[field]])),
    fields,
  );
}

function sanitizedEnvelope(document, version) {
  const clean = pickFields(
    cloneJsonPreservingNumberTokens(document),
    rootFields,
  );
  const paths = version >= 4 ? v4FilePaths : filePaths;
  clean.files = pickFields(clean.files, paths);
  clean.manifest = pickFields(clean.manifest, manifestFields);
  clean.manifest.ownerScope = pickFields(clean.manifest.ownerScope, ownerFields);
  clean.manifest.integrity = pickFields(clean.manifest.integrity, integrityFields);
  clean.manifest.privacyBoundary = pickFields(
    clean.manifest.privacyBoundary,
    privacyFields,
  );
  clean.manifest.files = clean.manifest.files.map((row) =>
    pickFields(row, manifestFileFields),
  );
  const reminderFields = version === 2 ? v2ReminderFields : v3ReminderFields;
  clean.files['reminders.json'] = clean.files['reminders.json'].map((row) =>
    pickFields(row, reminderFields),
  );
  if (version >= 4) {
    clean.files['observations.json'] = pickFields(
      clean.files['observations.json'],
      ['availability', 'records'],
    );
    clean.files['observations.json'].records =
      clean.files['observations.json'].records.map((row) =>
        pickFields(row, [
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
        ]),
      );
  }
  const contentSha256 = canonicalDigest(clean.files);
  clean.manifest.integrity.contentSha256 = contentSha256;
  clean.manifest.files = paths.map((filePath) => ({
    path: filePath,
    sha256: canonicalDigest(clean.files[filePath]),
    recordCount: recordCount(clean.files[filePath]),
  }));
  clean.manifest.packageId = digest(
    `parkinsum-portable-package-v${version}|` +
      `${clean.manifest.ownerScope.bindingSha256}|${contentSha256}`,
  );
  return clean;
}

function readyEvidence(source, document, registry) {
  if (!registry) {
    return { outputCanonicalSha256: null, receiptSha256: null };
  }
  const sourceValidator = registry.validators.find(
    (entry) => entry.version === document.schemaVersion,
  );
  const targetValidator = registry.validators.find(
    (entry) => entry.version === registry.currentVersion,
  );
  if (!sourceValidator || !targetValidator) throw new Error('validator_missing');

  const migrating = document.schemaVersion < registry.currentVersion;
  const migration = migrating
    ? registry.migrations.find(
        (entry) =>
          entry.sourceVersion === document.schemaVersion &&
          entry.targetVersion === registry.currentVersion,
      )
    : null;
  if (migrating && !migration) throw new Error('migration_missing');
  const output = document.schemaVersion === 2
    ? migrateV2ToV4(document)
    : document.schemaVersion === 3
    ? migrateV3ToV4(document)
    : cloneJsonPreservingNumberTokens(document);
  validateEnvelope(output, registry.currentVersion);
  const reminderCount = document.files['reminders.json'].length;
  const warnings = migrating
    ? [
        ...(document.schemaVersion === 2 && reminderCount > 0
          ? [
              `${reminderCount} legacy reminder presentation intent row(s) received frozen minimal English defaults.`,
            ]
          : []),
        `Source schema ${document.schemaVersion} did not contain personal observations; the migrated preview marks them unavailable instead of inferring an empty history.`,
      ]
    : [];
  const body = {
    schema: 'parkinsum.portable-schema-migration-receipt/1',
    sourceVersion: document.schemaVersion,
    targetVersion: registry.currentVersion,
    sourceBytesSha256: digest(source),
    sourceCanonicalSha256: canonicalDigest(document),
    outputCanonicalSha256: canonicalDigest(output),
    sourceValidatorIdentity: sourceValidator.validatorIdentity,
    targetValidatorIdentity: targetValidator.validatorIdentity,
    migrationIdentity: migrating
      ? migration.migrationIdentity
      : digest('parkinsum-portable-no-migration-required-v1'),
    semanticDiffSha256: migrating
      ? migration.semanticDiffSha256
      : canonicalDigest([]),
    decision: migrating ? 'preview_only_no_write' : 'not_required_current_schema',
    warnings,
    heldFields: migrating
      ? [
          '$.files.reminders.json[*].targetSchedulingConsentStatus',
          '$.files.observations.json.records',
          'durable_import',
        ]
      : ['durable_import'],
  };
  return {
    outputCanonicalSha256: body.outputCanonicalSha256,
    receiptSha256: canonicalDigest(body),
  };
}

/// Independent finite-campaign classifier. Its semantic projection mirrors
/// the frozen envelope, manifest and reminder subset exercised by this gate;
/// it is not a replacement for the full Dart production package validator.
export function classifyPortableJsonDetailed(
  source,
  { registry = null, budgets = defaultBudgets } = {},
) {
  const sourceSha256 = digest(source);
  const result = (disposition, reasonCode, evidence = {}) => ({
    disposition,
    reasonCode,
    sourceSha256,
    outputCanonicalSha256: evidence.outputCanonicalSha256 ?? null,
    receiptSha256: evidence.receiptSha256 ?? null,
  });
  if (Buffer.byteLength(source, 'utf8') > budgets.packageBytes) {
    return result('corrupt', 'package_bytes_budget');
  }
  let document;
  try {
    document = parseJsonRejectingDuplicates(source, parserOptions(budgets));
  } catch (error) {
    return result('corrupt', parserFailureReason(error));
  }
  if (!document || Array.isArray(document) || typeof document !== 'object') {
    return result('corrupt', 'contract_or_integrity_invalid');
  }
  if (document.format !== 'parkinsum_user_portable_data_package') {
    return result('corrupt', 'contract_or_integrity_invalid');
  }
  if (
    !isDartInt(document, 'schemaVersion', document.schemaVersion) ||
    ![2, 3, 4].includes(document.schemaVersion)
  ) {
    return result('unsupportedSchema', 'unsupported_schema_version');
  }
  const relation = schemaFieldRelation(document, document.schemaVersion);
  if (relation.missing.length > 0) {
    return result('corrupt', 'contract_or_integrity_invalid');
  }
  try {
    validateOriginalIntegrity(document, document.schemaVersion);
    validateEnvelope(
      relation.extra.length > 0
        ? sanitizedEnvelope(document, document.schemaVersion)
        : document,
      document.schemaVersion,
    );
    if (relation.extra.length > 0) {
      return result('unsupportedSchema', 'unsupported_fields');
    }
    const evidence = readyEvidence(source, document, registry);
    return result(
      'ready',
      document.schemaVersion < 4
        ? 'ready_migrated_preview'
        : 'ready_current',
      evidence,
    );
  } catch {
    return result('corrupt', 'contract_or_integrity_invalid');
  }
}

export function classifyPortableJson(source) {
  return classifyPortableJsonDetailed(source).disposition;
}

/// Generic deterministic reducer primitive. The campaign deliberately does
/// not call it on cross-runtime disagreements until both runtimes can be
/// replayed for every candidate.
export function minimizeSyntheticFailure(source, predicate) {
  let current = source;
  let chunk = Math.max(1, Math.floor(current.length / 2));
  while (chunk >= 1 && current.length > 1) {
    let reduced = false;
    for (let start = 0; start < current.length; start += chunk) {
      const candidate = current.slice(0, start) + current.slice(start + chunk);
      if (candidate.length > 0 && predicate(candidate)) {
        current = candidate;
        reduced = true;
        break;
      }
    }
    if (!reduced) chunk = Math.floor(chunk / 2);
  }
  return current;
}

function reportDigest(report) {
  const body = structuredClone(report);
  delete body.reportSha256;
  return canonicalDigest(body);
}

function validatedBudgets(plan, failures) {
  const budgets = plan?.resourceBudgets;
  for (const key of Object.keys(defaultBudgets)) {
    if (!Number.isInteger(budgets?.[key]) || budgets[key] <= 0) {
      failures.push(`invalid_resource_budget:${key}`);
    }
  }
  return failures.some((failure) => failure.startsWith('invalid_resource_budget:'))
    ? defaultBudgets
    : budgets;
}

export function runDifferentialCampaign(
  dartReport,
  plan,
  corpus,
  migrationVectors,
) {
  const failures = [];
  if (dartReport.schema !== 'parkinsum.portable-schema-differential-fuzz-report/1') {
    failures.push('unsupported_dart_report_schema');
  }
  if (reportDigest(dartReport) !== dartReport.reportSha256) {
    failures.push('dart_report_digest_drift');
  }
  if (dartReport.pass !== true || (dartReport.failures ?? []).length > 0) {
    failures.push('dart_campaign_failed');
  }
  if (
    plan?.$schema !== 'parkinsum.portable-schema-differential-fuzz-plan/1' ||
    canonicalDigest(plan) !== dartReport.planSha256
  ) {
    failures.push('plan_identity_drift');
  }
  if (
    corpus?.$schema !== 'parkinsum.portable-schema-fuzz-regression-corpus/1' ||
    canonicalDigest(corpus) !== dartReport.corpusSha256 ||
    corpus?.privacy?.syntheticOnly !== true ||
    corpus?.privacy?.privacyReviewed !== true ||
    corpus?.privacy?.userDerived !== false
  ) {
    failures.push('corpus_identity_or_privacy_drift');
  }
  if (
    JSON.stringify(plan?.fixedRegressionSeeds) !==
    JSON.stringify(dartReport.fixedSeeds)
  ) {
    failures.push('fixed_seed_drift');
  }
  const migrationConformance = migrationVectors
    ? runConformance(migrationVectors)
    : { pass: false, failures: ['migration_vectors_missing'] };
  if (!migrationConformance.pass) {
    failures.push('migration_vectors_not_conformant');
  }
  const registry = migrationVectors?.registry;
  if (
    !registry ||
    registryDigest(registry) !== registry.registryDigest ||
    dartReport.registryIdentity !== registry.registryDigest
  ) {
    failures.push('registry_identity_drift');
  }
  const budgets = validatedBudgets(plan, failures);

  const reportById = new Map(
    (dartReport.cases ?? []).map((entry) => [entry.id, entry]),
  );
  for (const retained of corpus?.cases ?? []) {
    const executed = reportById.get(retained.id);
    if (!executed) {
      failures.push(`retained_case_not_executed:${retained.id}`);
      continue;
    }
    if (
      executed.partition !== retained.partition ||
      executed.expectedDisposition !== retained.expectedDisposition ||
      executed.expectedReasonCode !== retained.expectedReasonCode ||
      executed.origin !== 'retained_synthetic_regression_corpus'
    ) {
      failures.push(`retained_case_contract_drift:${retained.id}`);
    }
  }

  const caseResults = [];
  for (const testCase of dartReport.cases ?? []) {
    const startedAt = performance.now();
    const node = classifyPortableJsonDetailed(testCase.rawJson, {
      registry,
      budgets,
    });
    const nodeElapsedMilliseconds = performance.now() - startedAt;
    const nodeObservationExceeded =
      nodeElapsedMilliseconds > budgets.caseObservationMilliseconds;
    const dispositionAgrees =
      node.disposition === testCase.dartDisposition &&
      node.disposition === testCase.expectedDisposition;
    const reasonAgrees =
      node.reasonCode === testCase.dartReasonCode &&
      node.reasonCode === testCase.expectedReasonCode;
    const sourceIdentityAgrees = node.sourceSha256 === testCase.sourceSha256;
    const outputIdentityAgrees =
      node.outputCanonicalSha256 === (testCase.outputCanonicalSha256 ?? null);
    const receiptIdentityAgrees =
      node.receiptSha256 === (testCase.receiptSha256 ?? null);

    if (!dispositionAgrees) failures.push(`${testCase.id}:disposition_drift`);
    if (!reasonAgrees) failures.push(`${testCase.id}:reason_code_drift`);
    if (!sourceIdentityAgrees) failures.push(`${testCase.id}:source_identity_drift`);
    if (!outputIdentityAgrees) failures.push(`${testCase.id}:output_identity_drift`);
    if (!receiptIdentityAgrees) failures.push(`${testCase.id}:receipt_identity_drift`);
    if (nodeObservationExceeded) {
      failures.push(`${testCase.id}:case_observation_overrun`);
    }
    if (testCase.partition === 'property_order_and_json_whitespace') {
      let keyOrderChanged = false;
      try {
        const keys = Object.keys(
          parseJsonRejectingDuplicates(testCase.rawJson, parserOptions(budgets)),
        );
        keyOrderChanged = keys.join('|') !== [...keys].sort().join('|');
      } catch {
        keyOrderChanged = false;
      }
      if (!testCase.mutationWitness || !keyOrderChanged) {
        failures.push(`${testCase.id}:property_order_not_mutated`);
      }
    }

    const agrees =
      dispositionAgrees &&
      reasonAgrees &&
      sourceIdentityAgrees &&
      outputIdentityAgrees &&
      receiptIdentityAgrees &&
      !nodeObservationExceeded;
    caseResults.push({
      id: testCase.id,
      partition: testCase.partition,
      sourceSha256: node.sourceSha256,
      expectedDisposition: testCase.expectedDisposition,
      expectedReasonCode: testCase.expectedReasonCode,
      dartDisposition: testCase.dartDisposition,
      dartReasonCode: testCase.dartReasonCode,
      nodeDisposition: node.disposition,
      nodeReasonCode: node.reasonCode,
      outputCanonicalSha256: node.outputCanonicalSha256,
      receiptSha256: node.receiptSha256,
      nodeObservationExceeded,
      agrees,
      quarantineSourceSha256: agrees ? null : node.sourceSha256,
      minimizationStatus: agrees
        ? 'not_needed'
        : 'blocked_cross_runtime_replay_required',
    });
  }
  return {
    schema: 'parkinsum.portable-schema-differential-fuzz-conformance/1',
    schemaVersion: 1,
    pass: failures.length === 0,
    failures,
    generatorVersion: dartReport.generatorVersion,
    planSha256: dartReport.planSha256,
    corpusSha256: dartReport.corpusSha256,
    registryIdentity: registry?.registryDigest ?? null,
    fixedSeeds: dartReport.fixedSeeds,
    caseCount: caseResults.length,
    coveredPartitions: dartReport.coveredPartitions,
    caseResults,
    independentRuntime: `node-${process.versions.node}`,
    boundary:
      'Fixed synthetic Dart/Node status, reason-code and identity evidence only. The Node semantic projection covers the frozen envelope, manifest, reminder and v4 observation contract, not every other nested-file validator, identifier/reference graph or record budget. Elapsed thresholds are observed after return and cannot terminate a hung synchronous parser. Cross-runtime replay minimization, automatic corpus promotion, continuous coverage guidance, every release artifact, exhaustive parser correctness, issuer authenticity, clinical validity and safe durable import remain unverified.',
  };
}

function main() {
  const dartReport = JSON.parse(fs.readFileSync(dartReportPath, 'utf8'));
  const plan = JSON.parse(
    fs.readFileSync(path.join(repoRoot, 'config/portable_schema_fuzz_plan.json')),
  );
  const corpus = JSON.parse(
    fs.readFileSync(
      path.join(repoRoot, 'test/fixtures/portable_schema_regression_corpus.json'),
    ),
  );
  const migrationVectors = parseJsonRejectingDuplicates(
    fs.readFileSync(migrationVectorsPath, 'utf8'),
  );
  const report = runDifferentialCampaign(
    dartReport,
    plan,
    corpus,
    migrationVectors,
  );
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(
    `Portable schema Node differential campaign: ${report.pass ? 'pass' : 'FAIL'}; ` +
      `${report.caseCount} cases; ${report.coveredPartitions.length} partitions; ` +
      `artifact=${path.relative(repoRoot, outputPath)}`,
  );
  if (!report.pass) {
    for (const failure of report.failures) console.error(`- ${failure}`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === modulePath) main();
