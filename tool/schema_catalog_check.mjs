#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const modulePath = fileURLToPath(import.meta.url);
const defaultRepoRoot = path.dirname(path.dirname(modulePath));
const defaultCatalogPath = 'config/schema_catalog.json';
const supportedCatalogVersion = 2;

const schemaIdPattern = /^parkinsum\.[a-z0-9.-]+$/;
const safeDartIdentifierPattern = /^[A-Za-z_][A-Za-z0-9_]*$/;
const supportedVersionStatuses = new Set([
  'versioned',
  'semantic-versioned',
  'unversioned',
]);
const supportedSurfaceKinds = new Set([
  'public-envelope',
  'nested-public-contract',
  'persisted-envelope',
  'database-schema',
  'persisted-boundary',
  'runtime-contract',
  'governance-artifact',
]);
const supportedEvidenceKinds = new Set([
  'schema-uri',
  'dart-int-constant',
  'dart-json-int-field',
  'dart-json-int-guard',
  'dart-named-int-argument',
  'versioned-string',
  'dart-named-string-argument',
]);

// This registry is deliberately independent of the JSON catalog and contains
// no version numbers. It is the minimum production/public surface set that the
// central catalog must continue to acknowledge. Versions are extracted from
// Dart source below, so this registry cannot silently become a second version
// authority.
export const requiredSchemaSurfaces = Object.freeze([
  ['parkinsum.algorithm-evaluation', 'lib/algorithm_sdk/parkinsum_algorithm_sdk.dart'],
  ['parkinsum.algorithm-configuration', 'lib/algorithm_sdk/algorithm_configuration_identity.dart'],
  ['parkinsum.mechanistic-numerical-oracle', 'lib/domain/usecases/algorithm_numerical_verification_oracle.dart'],
  ['parkinsum.mechanistic-event-ledger', 'lib/domain/entities/mechanistic_event_ledger.dart'],
  ['parkinsum.algorithm-fitted-parameter-identity', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.algorithm-parameter-provenance', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.algorithm-parameter-manifest', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.cdss-rule-logic', 'lib/algorithm_sdk/algorithm_parameter_provenance.dart'],
  ['parkinsum.gastric-parameter-set', 'lib/domain/entities/gastric_emptying_parameters.dart'],
  ['parkinsum.algorithm-trace-node', 'lib/domain/entities/algorithm_trace_node.dart'],
  ['parkinsum.personal-log-handoff', 'lib/domain/usecases/personal_log_handoff_summary_service.dart'],
  ['parkinsum.privacy-safe-support-bundle', 'lib/domain/usecases/privacy_safe_support_bundle_service.dart'],
  ['parkinsum.purpose-bound-consent-receipt', 'lib/core/models/purpose_bound_consent.dart'],
  ['parkinsum.recoverable-user-event-history', 'lib/core/models/recoverable_user_event.dart'],
  ['parkinsum.recoverable-event-restore-impact', 'lib/domain/usecases/recoverable_event_restore_impact_service.dart'],
  ['parkinsum.restore-relationship-graph', 'lib/domain/usecases/recoverable_event_restore_impact_service.dart'],
  ['parkinsum.restore-impact-account', 'lib/domain/usecases/recoverable_event_restore_impact_service.dart'],
  ['parkinsum.user-portable-data-package', 'lib/domain/usecases/user_portable_data_package_service.dart'],
  ['parkinsum.portable-owner-token', 'lib/core/services/portable_data_owner_scope_service.dart'],
  ['parkinsum.portable-owner-secret-envelope', 'lib/core/services/portable_data_owner_scope_service.dart'],
  ['parkinsum.protected-secret-store', 'lib/core/security/protected_secret_store.dart'],
  ['parkinsum.atomic-onboarding-commit', 'lib/core/models/atomic_onboarding_commit.dart'],
  ['parkinsum.intake-record', 'lib/core/models/intake.dart'],
  ['parkinsum.reminder-activation-inbox', 'lib/core/services/reminder_activation_inbox.dart'],
  ['parkinsum.reminder-plan', 'lib/domain/entities/user_logging_reminder.dart'],
  ['parkinsum.reminder-notification-payload', 'lib/core/services/user_logging_reminder_service.dart'],
  ['parkinsum.reminder-schedule-manifest', 'lib/core/services/reminder_schedule_manifest.dart'],
  ['parkinsum.app-database-native', 'lib/core/db/app_database_native.dart'],
  ['parkinsum.app-database-web-user-state', 'lib/core/db/app_database_web.dart'],
  ['parkinsum.app-database-web-record-sets', 'lib/core/db/app_database_web.dart'],
  ['parkinsum.app-database-firestore', 'lib/core/db/app_database_firestore.dart'],
  ['parkinsum.cdss-database-native', 'lib/core/db/cdss_database_native.dart'],
  ['parkinsum.cdss-database-web', 'lib/core/db/cdss_database_web.dart'],
  ['parkinsum.cdss-database-firestore', 'lib/core/db/cdss_database_firestore.dart'],
  ['parkinsum.engine-snapshot-record', 'lib/domain/entities/cdss_records.dart'],
  ['parkinsum.complete-app-upgrade-queue', 'lib/domain/entities/product_upgrade_queue.dart'],
  ['parkinsum.open-source-influence-inventory', 'lib/domain/entities/product_upgrade_queue.dart'],
].map(([id, source]) => Object.freeze({ id, source })));

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function isSafeRelativeDartPath(value) {
  if (typeof value !== 'string' || value.length === 0) return false;
  if (path.isAbsolute(value) || value.includes('\\')) return false;
  const normalized = path.posix.normalize(value);
  return (
    normalized === value &&
    !normalized.startsWith('../') &&
    normalized.startsWith('lib/') &&
    normalized.endsWith('.dart')
  );
}

function listDartFiles(root) {
  const libRoot = path.join(root, 'lib');
  if (!fs.existsSync(libRoot)) return [];
  const found = [];
  const visit = (directory) => {
    const entries = fs.readdirSync(directory, { withFileTypes: true });
    entries.sort((left, right) => left.name.localeCompare(right.name));
    for (const entry of entries) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(absolute);
      if (entry.isFile() && entry.name.endsWith('.dart')) {
        found.push(path.relative(root, absolute).split(path.sep).join('/'));
      }
    }
  };
  visit(libRoot);
  return found;
}

function sourceText(repoRoot, source, failures, label) {
  if (!isSafeRelativeDartPath(source)) {
    failures.push(`${label} source must be a normalized relative lib/*.dart path: ${source}`);
    return null;
  }
  const absolute = path.join(repoRoot, source);
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
    failures.push(`${label} source does not exist: ${source}`);
    return null;
  }
  return fs.readFileSync(absolute, 'utf8');
}

function boundedSlice(text, evidence, label, failures) {
  if (evidence.anchor === undefined) return text;
  if (typeof evidence.anchor !== 'string' || evidence.anchor.length === 0) {
    failures.push(`${label} evidence anchor must be a non-empty literal string`);
    return null;
  }
  const start = text.indexOf(evidence.anchor);
  if (start < 0) {
    failures.push(`${label} evidence anchor was not found: ${evidence.anchor}`);
    return null;
  }
  if (evidence.endAnchor === undefined) return text.slice(start);
  if (typeof evidence.endAnchor !== 'string' || evidence.endAnchor.length === 0) {
    failures.push(`${label} evidence endAnchor must be a non-empty literal string`);
    return null;
  }
  const end = text.indexOf(evidence.endAnchor, start + evidence.anchor.length);
  if (end < 0) {
    failures.push(`${label} evidence endAnchor was not found: ${evidence.endAnchor}`);
    return null;
  }
  return text.slice(start, end);
}

function uniqueMatch(matches, label, failures) {
  const values = [...new Set(matches)];
  if (values.length !== 1) {
    failures.push(
      `${label} must resolve exactly one source version; found ${values.length}`,
    );
    return null;
  }
  return values[0];
}

function extractEvidenceVersion({ schema, evidence, text, failures, label }) {
  if (!evidence || typeof evidence !== 'object' || Array.isArray(evidence)) {
    failures.push(`${label} must be an object`);
    return null;
  }
  if (!supportedEvidenceKinds.has(evidence.kind)) {
    failures.push(`${label} has unsupported kind: ${evidence.kind}`);
    return null;
  }
  const bounded = boundedSlice(text, evidence, label, failures);
  if (bounded === null) return null;

  if (evidence.kind === 'schema-uri') {
    const expression = new RegExp(
      `['\"]${escapeRegex(schema.id)}\\/([1-9][0-9]*)['\"]`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-int-constant') {
    if (!safeDartIdentifierPattern.test(evidence.symbol ?? '')) {
      failures.push(`${label} symbol is not a safe Dart identifier`);
      return null;
    }
    const expression = new RegExp(
      `(?:static\\s+)?const\\s+(?:int\\s+)?${escapeRegex(evidence.symbol)}\\s*=\\s*([1-9][0-9]*)\\s*;`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-json-int-field') {
    if (typeof evidence.field !== 'string' || evidence.field.length === 0) {
      failures.push(`${label} field must be a non-empty string`);
      return null;
    }
    const expression = new RegExp(
      `['\"]${escapeRegex(evidence.field)}['\"]\\s*:\\s*([1-9][0-9]*)`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-json-int-guard') {
    if (typeof evidence.field !== 'string' || evidence.field.length === 0) {
      failures.push(`${label} field must be a non-empty string`);
      return null;
    }
    const expression = new RegExp(
      `\\[['\"]${escapeRegex(evidence.field)}['\"]\\]\\s*!=\\s*([1-9][0-9]*)`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-named-int-argument') {
    if (!safeDartIdentifierPattern.test(evidence.argument ?? '')) {
      failures.push(`${label} argument is not a safe Dart identifier`);
      return null;
    }
    const expression = new RegExp(
      `${escapeRegex(evidence.argument)}\\s*:\\s*([1-9][0-9]*)`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'versioned-string') {
    if (typeof evidence.prefix !== 'string' || evidence.prefix.length === 0) {
      failures.push(`${label} prefix must be a non-empty literal string`);
      return null;
    }
    const expression = new RegExp(`${escapeRegex(evidence.prefix)}([1-9][0-9]*)`, 'g');
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => Number(match[1])),
      label,
      failures,
    );
  }

  if (evidence.kind === 'dart-named-string-argument') {
    if (!safeDartIdentifierPattern.test(evidence.argument ?? '')) {
      failures.push(`${label} argument is not a safe Dart identifier`);
      return null;
    }
    const expression = new RegExp(
      `${escapeRegex(evidence.argument)}\\s*:\\s*['\"]([^'\"\\r\\n]+)['\"]`,
      'g',
    );
    return uniqueMatch(
      [...bounded.matchAll(expression)].map((match) => match[1]),
      label,
      failures,
    );
  }

  return null;
}

function discoverSchemaUris(repoRoot, dartFiles) {
  const discovered = [];
  const expression = /['\"](parkinsum\.[a-z0-9.-]+)\/([1-9][0-9]*)['\"]/g;
  for (const source of dartFiles) {
    const text = fs.readFileSync(path.join(repoRoot, source), 'utf8');
    for (const match of text.matchAll(expression)) {
      discovered.push({ source, id: match[1], version: Number(match[2]) });
    }
  }
  return discovered;
}

function discoverNamedSchemaVersionConstants(repoRoot, dartFiles) {
  const discovered = [];
  const expression =
    /(?:static\s+)?const\s+(?:int\s+)?([A-Za-z_][A-Za-z0-9_]*(?:SchemaVersion|schemaVersion)|_schemaVersion)\s*=\s*([1-9][0-9]*)\s*;/g;
  for (const source of dartFiles) {
    const text = fs.readFileSync(path.join(repoRoot, source), 'utf8');
    for (const match of text.matchAll(expression)) {
      discovered.push({ source, symbol: match[1], version: Number(match[2]) });
    }
  }
  return discovered;
}

export function validateSchemaCatalog(catalog, { repoRoot = defaultRepoRoot } = {}) {
  const failures = [];
  if (!catalog || typeof catalog !== 'object' || Array.isArray(catalog)) {
    return ['catalog root must be an object'];
  }
  if (catalog.catalogVersion !== supportedCatalogVersion) {
    failures.push(`catalogVersion must be ${supportedCatalogVersion}`);
  }
  if (typeof catalog.boundary !== 'string' || catalog.boundary.trim().length < 40) {
    failures.push('catalog boundary must state the catalog limits');
  } else {
    const boundary = catalog.boundary.toLowerCase();
    for (const term of ['migration', 'compatibility', 'deployed']) {
      if (!boundary.includes(term)) {
        failures.push(`catalog boundary must explicitly limit ${term} claims`);
      }
    }
  }
  const schemas = Array.isArray(catalog.schemas) ? catalog.schemas : [];
  if (schemas.length === 0) {
    failures.push('schemas must be a non-empty array');
  }

  const ids = new Set();
  const entriesById = new Map();
  const claimedConstants = new Map();
  for (const [index, schema] of schemas.entries()) {
    const label = `schemas[${index}]`;
    if (!schema || typeof schema !== 'object' || Array.isArray(schema)) {
      failures.push(`${label} must be an object`);
      continue;
    }
    if (!schemaIdPattern.test(schema.id ?? '')) {
      failures.push(`${label} has invalid schema id: ${schema.id}`);
    }
    if (ids.has(schema.id)) failures.push(`duplicate schema id: ${schema.id}`);
    ids.add(schema.id);
    entriesById.set(schema.id, schema);
    if (!supportedSurfaceKinds.has(schema.surfaceKind)) {
      failures.push(`${schema.id} has unsupported surfaceKind: ${schema.surfaceKind}`);
    }
    if (!supportedVersionStatuses.has(schema.versionStatus)) {
      failures.push(`${schema.id} has unsupported versionStatus: ${schema.versionStatus}`);
    }
    if (!String(schema.compatibility ?? '').trim()) {
      failures.push(`${schema.id} compatibility policy is missing`);
    }
    const primaryText = sourceText(repoRoot, schema.source, failures, schema.id);
    if (schema.versionStatus === 'versioned') {
      if (!Number.isInteger(schema.currentVersion) || schema.currentVersion < 1) {
        failures.push(`${schema.id} currentVersion must be a positive integer`);
      }
    } else if (schema.versionStatus === 'semantic-versioned') {
      if (
        typeof schema.currentVersion !== 'string' ||
        !/^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/.test(schema.currentVersion)
      ) {
        failures.push(`${schema.id} currentVersion must be a safe semantic identifier`);
      }
    } else if (schema.versionStatus === 'unversioned' && schema.currentVersion !== null) {
      failures.push(`${schema.id} unversioned surfaces must use currentVersion null`);
    }

    if (schema.versionStatus === 'unversioned') {
      if (!Array.isArray(schema.versionEvidence) || schema.versionEvidence.length !== 0) {
        failures.push(`${schema.id} unversioned surfaces cannot claim versionEvidence`);
      }
      if (typeof schema.surfaceMarker !== 'string' || schema.surfaceMarker.length === 0) {
        failures.push(`${schema.id} unversioned surfaceMarker is missing`);
      } else if (primaryText !== null && !primaryText.includes(schema.surfaceMarker)) {
        failures.push(`${schema.id} surfaceMarker was not found in ${schema.source}`);
      }
      continue;
    }

    if (!Array.isArray(schema.versionEvidence) || schema.versionEvidence.length === 0) {
      failures.push(`${schema.id} versionEvidence must be a non-empty array`);
      continue;
    }
    for (const [evidenceIndex, evidence] of schema.versionEvidence.entries()) {
      const evidenceLabel = `${schema.id} versionEvidence[${evidenceIndex}]`;
      const evidenceSource = evidence?.source ?? schema.source;
      const text =
        evidenceSource === schema.source
          ? primaryText
          : sourceText(repoRoot, evidenceSource, failures, evidenceLabel);
      if (text === null) continue;
      const extracted = extractEvidenceVersion({
        schema,
        evidence,
        text,
        failures,
        label: evidenceLabel,
      });
      if (extracted !== null && extracted !== schema.currentVersion) {
        failures.push(
          `${evidenceLabel} source version ${JSON.stringify(extracted)} ` +
            `does not match catalog ${JSON.stringify(schema.currentVersion)}`,
        );
      }
      if (evidence.kind === 'dart-int-constant') {
        const key = `${evidenceSource}:${evidence.symbol}`;
        const owners = claimedConstants.get(key) ?? [];
        owners.push(schema.id);
        claimedConstants.set(key, owners);
      }
    }
  }

  for (const required of requiredSchemaSurfaces) {
    const entry = entriesById.get(required.id);
    if (!entry) {
      failures.push(`required schema surface is missing: ${required.id}`);
    } else if (entry.source !== required.source) {
      failures.push(
        `${required.id} required source is ${required.source}, catalog has ${entry.source}`,
      );
    }
  }

  const dartFiles = listDartFiles(repoRoot);
  const discoveredUris = discoverSchemaUris(repoRoot, dartFiles);
  for (const discovered of discoveredUris) {
    const entry = entriesById.get(discovered.id);
    if (!entry) {
      failures.push(
        `discovered schema URI is not cataloged: ${discovered.id}/${discovered.version} in ${discovered.source}`,
      );
      continue;
    }
    if (entry.versionStatus !== 'versioned' || entry.currentVersion !== discovered.version) {
      failures.push(
        `discovered schema URI ${discovered.id}/${discovered.version} disagrees with catalog`,
      );
    }
  }

  const discoveredConstants = discoverNamedSchemaVersionConstants(repoRoot, dartFiles);
  for (const discovered of discoveredConstants) {
    const key = `${discovered.source}:${discovered.symbol}`;
    const owners = claimedConstants.get(key) ?? [];
    if (owners.length === 0) {
      failures.push(
        `discovered schema-version constant is not cataloged: ${key}=${discovered.version}`,
      );
    } else if (owners.length > 1) {
      failures.push(
        `schema-version constant is claimed by multiple catalog entries: ${key} (${owners.join(', ')})`,
      );
    }
  }

  return failures;
}

export function readAndValidateSchemaCatalog({
  repoRoot = defaultRepoRoot,
  catalogPath = defaultCatalogPath,
} = {}) {
  const absoluteCatalogPath = path.join(repoRoot, catalogPath);
  let catalog;
  try {
    catalog = JSON.parse(fs.readFileSync(absoluteCatalogPath, 'utf8'));
  } catch (error) {
    return {
      catalog: null,
      failures: [`catalog cannot be read as JSON: ${error.message}`],
    };
  }
  return { catalog, failures: validateSchemaCatalog(catalog, { repoRoot }) };
}

function main() {
  const { catalog, failures } = readAndValidateSchemaCatalog();
  if (failures.length > 0) {
    for (const failure of failures) process.stderr.write(`FAIL ${failure}\n`);
    process.exitCode = 1;
    return;
  }
  const versioned = catalog.schemas.filter(
    (schema) => schema.versionStatus !== 'unversioned',
  ).length;
  const unversioned = catalog.schemas.length - versioned;
  process.stdout.write(
    `Schema catalog passed: ${catalog.schemas.length} required surfaces ` +
      `(${versioned} versioned, ${unversioned} explicitly unversioned)\n`,
  );
}

if (process.argv[1] && path.resolve(process.argv[1]) === modulePath) main();
