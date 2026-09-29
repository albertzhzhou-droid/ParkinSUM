import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  canonicalDigest,
  canonicalize,
  cloneJsonPreservingNumberTokens,
  digest,
  parseJsonRejectingDuplicates,
} from './portable_schema_migration_conformance.mjs';
import {
  classifyPortableJson,
  classifyPortableJsonDetailed,
  minimizeSyntheticFailure,
  runDifferentialCampaign,
} from './portable_schema_differential_fuzz.mjs';

test('independent parser rejects non-interoperable Unicode scalars', () => {
  for (const source of [
    '{"value":"\\ud800"}',
    '{"value":"\\udc00"}',
    '{"value":"\\ufdd0"}',
    '{"value":"\\ud83f\\udffe"}',
  ]) {
    assert.throws(() => parseJsonRejectingDuplicates(source));
  }
  assert.deepEqual(parseJsonRejectingDuplicates('{"value":"\\ud83d\\ude80"}'), {
    value: '🚀',
  });
  assert.throws(
    () => parseJsonRejectingDuplicates(`{"value":${'7'.repeat(129)}}`),
    /number_token_budget/u,
  );
  assert.throws(
    () =>
      parseJsonRejectingDuplicates(
        `{"value":"${'\\u0061'.repeat(10923)}"}`,
      ),
    /string_budget/u,
  );
  assert.throws(
    () => parseJsonRejectingDuplicates(`{"${'k'.repeat(257)}":0}`),
    /key_utf8_budget/u,
  );
  assert.equal(
    classifyPortableJsonDetailed(
      `{"value":"${'a'.repeat(65535)}\\x"}`,
    ).reasonCode,
    'malformed_or_structural_budget',
  );
  assert.equal(
    classifyPortableJsonDetailed(
      `{"value":"\\ud800${'a'.repeat(65537)}"}`,
    ).reasonCode,
    'non_interoperable_unicode',
  );
  assert.equal(
    classifyPortableJsonDetailed(
      JSON.stringify({
        ...Object.fromEntries(
          Array.from({ length: 128 }, (_, index) => [`field_${index}`, index]),
        ),
        ['k'.repeat(257)]: 129,
      }),
    ).reasonCode,
    'object_width_budget',
  );
  assert.equal(
    classifyPortableJsonDetailed(
      `\u00a0${'['.repeat(25)}null${']'.repeat(25)}`,
    ).reasonCode,
    'malformed_or_structural_budget',
  );
});

test('synthetic failure minimizer is deterministic and preserves predicate', () => {
  const source = 'prefix::MISMATCH::suffix';
  const predicate = (candidate) => candidate.includes('MISMATCH');
  const first = minimizeSyntheticFailure(source, predicate);
  const second = minimizeSyntheticFailure(source, predicate);
  assert.equal(first, second);
  assert.equal(predicate(first), true);
  assert.ok(first.length < source.length);
});

test('tracked plan and retained corpus are fixed, synthetic, and private', () => {
  const plan = JSON.parse(fs.readFileSync('config/portable_schema_fuzz_plan.json'));
  const corpus = JSON.parse(
    fs.readFileSync('test/fixtures/portable_schema_regression_corpus.json'),
  );
  assert.equal(plan.$schema, 'parkinsum.portable-schema-differential-fuzz-plan/1');
  assert.equal(plan.generatorVersion, 1);
  assert.equal(plan.fixedRegressionSeeds.length, 3);
  assert.equal(plan.partitions.length, 14);
  assert.equal(plan.promotion.userDerivedAllowedByDefault, false);
  assert.equal(plan.promotion.rawFailureJsonRetentionByDefault, false);
  assert.equal(corpus.$schema, 'parkinsum.portable-schema-fuzz-regression-corpus/1');
  assert.equal(corpus.cases.length, 31);
  assert.deepEqual(corpus.privacy, {
    syntheticOnly: true,
    privacyReviewed: true,
    userDerived: false,
  });
  for (const entry of corpus.cases) {
    assert.equal(typeof entry.expectedReasonCode, 'string');
    if (entry.rawJson) assert.equal(classifyPortableJson(entry.rawJson), 'corrupt');
  }
});

test('independent reason taxonomy distinguishes the guarded failure', () => {
  assert.deepEqual(
    classifyPortableJsonDetailed('{"schemaVersion":2,"schemaVersion":2}'),
    {
      disposition: 'corrupt',
      reasonCode: 'duplicate_member',
      sourceSha256: digest('{"schemaVersion":2,"schemaVersion":2}'),
      outputCanonicalSha256: null,
      receiptSha256: null,
    },
  );
  assert.equal(
    classifyPortableJsonDetailed('{"value":"\\ud800"}').reasonCode,
    'non_interoperable_unicode',
  );
  assert.equal(
    classifyPortableJsonDetailed(`{"value":${'7'.repeat(129)}}`).reasonCode,
    'number_token_budget',
  );
  assert.equal(
    classifyPortableJsonDetailed(
      `{"value":"${'\\u0061'.repeat(10923)}"}`,
    ).reasonCode,
    'string_budget',
  );
  assert.equal(
    classifyPortableJsonDetailed(`{"${'k'.repeat(257)}":0}`).reasonCode,
    'key_utf8_budget',
  );
});

test('independent taxonomy preserves production precedence', () => {
  const vectors = parseJsonRejectingDuplicates(
    fs.readFileSync('build/portable_schema_migration/dart_vectors.json', 'utf8'),
  );
  const plan = JSON.parse(fs.readFileSync('config/portable_schema_fuzz_plan.json'));
  const fixture = vectors.fixtures.find(
    (entry) => entry.sourceDocument.schemaVersion === 3,
  );
  const base = parseJsonRejectingDuplicates(fixture.sourceJson);
  const duplicateManifest = cloneJsonPreservingNumberTokens(base);
  duplicateManifest.manifest.files.push(
    cloneJsonPreservingNumberTokens(duplicateManifest.manifest.files[0]),
  );
  assert.equal(
    classifyPortableJsonDetailed(canonicalize(duplicateManifest), {
      registry: vectors.registry,
      budgets: plan.resourceBudgets,
    }).reasonCode,
    'contract_or_integrity_invalid',
  );

  const unsupportedIntegrity = cloneJsonPreservingNumberTokens(base);
  unsupportedIntegrity.manifest.integrity.algorithm = 'MD5';
  assert.equal(
    classifyPortableJsonDetailed(canonicalize(unsupportedIntegrity), {
      registry: vectors.registry,
      budgets: plan.resourceBudgets,
    }).reasonCode,
    'contract_or_integrity_invalid',
  );

  const currentFixture = vectors.fixtures.find(
    (entry) => entry.sourceDocument.schemaVersion === 4,
  );
  const current = cloneJsonPreservingNumberTokens(
    parseJsonRejectingDuplicates(currentFixture.sourceJson),
  );
  current.syntheticFutureField = true;

  assert.equal(
    classifyPortableJsonDetailed(canonicalize(current), {
      registry: vectors.registry,
      budgets: plan.resourceBudgets,
    }).reasonCode,
    'unsupported_fields',
  );

  current.manifest.integrity.contentSha256 = '0'.repeat(64);
  const corruptCurrentSource = canonicalize(current);
  assert.deepEqual(
    classifyPortableJsonDetailed(corruptCurrentSource, {
      registry: vectors.registry,
      budgets: plan.resourceBudgets,
    }),
    {
      disposition: 'corrupt',
      reasonCode: 'contract_or_integrity_invalid',
      sourceSha256: digest(corruptCurrentSource),
      outputCanonicalSha256: null,
      receiptSha256: null,
    },
  );

  current.schemaVersion = 5;
  assert.equal(
    classifyPortableJsonDetailed(canonicalize(current), {
      registry: vectors.registry,
      budgets: plan.resourceBudgets,
    }).reasonCode,
    'unsupported_schema_version',
  );
});

test('independent campaign binds exact plan, corpus, and retained membership', () => {
  const report = JSON.parse(
    fs.readFileSync('build/portable_schema_fuzz/dart_campaign.json'),
  );
  const plan = JSON.parse(fs.readFileSync('config/portable_schema_fuzz_plan.json'));
  const corpus = JSON.parse(
    fs.readFileSync('test/fixtures/portable_schema_regression_corpus.json'),
  );
  const migrationVectors = parseJsonRejectingDuplicates(
    fs.readFileSync('build/portable_schema_migration/dart_vectors.json', 'utf8'),
  );
  assert.equal(
    runDifferentialCampaign(report, plan, corpus, migrationVectors).pass,
    true,
  );

  const driftedPlan = structuredClone(plan);
  driftedPlan.fixedRegressionSeeds[0] += 1;
  const drifted = runDifferentialCampaign(
    report,
    driftedPlan,
    corpus,
    migrationVectors,
  );
  assert.equal(drifted.pass, false);
  assert.ok(drifted.failures.includes('plan_identity_drift'));
  assert.ok(drifted.failures.includes('fixed_seed_drift'));

  const missing = structuredClone(report);
  missing.cases = missing.cases.filter(
    (entry) => entry.id !== corpus.cases[0].id,
  );
  const missingRetained = runDifferentialCampaign(
    missing,
    plan,
    corpus,
    migrationVectors,
  );
  assert.equal(missingRetained.pass, false);
  assert.ok(
    missingRetained.failures.includes(
      `retained_case_not_executed:${corpus.cases[0].id}`,
    ),
  );
});

test('independent campaign rejects source, output, and receipt identity drift', () => {
  const report = JSON.parse(
    fs.readFileSync('build/portable_schema_fuzz/dart_campaign.json'),
  );
  const plan = JSON.parse(fs.readFileSync('config/portable_schema_fuzz_plan.json'));
  const corpus = JSON.parse(
    fs.readFileSync('test/fixtures/portable_schema_regression_corpus.json'),
  );
  const migrationVectors = parseJsonRejectingDuplicates(
    fs.readFileSync('build/portable_schema_migration/dart_vectors.json', 'utf8'),
  );
  const drifted = structuredClone(report);
  const ready = drifted.cases.find(
    (entry) => entry.expectedDisposition === 'ready',
  );
  ready.sourceSha256 = '0'.repeat(64);
  ready.outputCanonicalSha256 = '1'.repeat(64);
  ready.receiptSha256 = '2'.repeat(64);
  const body = structuredClone(drifted);
  delete body.reportSha256;
  drifted.reportSha256 = canonicalDigest(body);

  const result = runDifferentialCampaign(
    drifted,
    plan,
    corpus,
    migrationVectors,
  );
  assert.equal(result.pass, false);
  assert.ok(result.failures.includes(`${ready.id}:source_identity_drift`));
  assert.ok(result.failures.includes(`${ready.id}:output_identity_drift`));
  assert.ok(result.failures.includes(`${ready.id}:receipt_identity_drift`));
  const failedCase = result.caseResults.find((entry) => entry.id === ready.id);
  assert.equal(failedCase.minimizationStatus, 'blocked_cross_runtime_replay_required');
  assert.equal(failedCase.quarantineSourceSha256.length, 64);
  assert.equal('minimizedSyntheticFailure' in failedCase, false);
});
