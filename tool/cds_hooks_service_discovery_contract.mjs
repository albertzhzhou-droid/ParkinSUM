#!/usr/bin/env node

// A fixed, offline CDS Hooks v2 service-discovery payload contract.
// This validates metadata only; it does not resolve or call the advertised service.
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixturePath = path.join(root, 'test/fixtures/cds_hooks_service_discovery.synthetic.json');
const serviceId = 'parkinsum-synthetic-patient-view';
const serviceHook = 'patient-view';
const discoveryFields = new Set(['services']);
const serviceFields = new Set(['id', 'hook', 'title', 'description']);

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function add(findings, code, pathName) {
  findings.push({ code, path: pathName });
}

export function validateSyntheticServiceDiscovery(value) {
  const findings = [];
  if (!isRecord(value)) {
    add(findings, 'discovery_object_required', '$');
    return { valid: false, findings };
  }
  for (const field of Object.keys(value)) {
    if (!discoveryFields.has(field)) add(findings, 'unsupported_discovery_field', `$.${field}`);
  }
  if (!Array.isArray(value.services) || value.services.length !== 1) {
    add(findings, 'one_fixed_service_required', '$.services');
    return { valid: false, findings };
  }
  const [service] = value.services;
  if (!isRecord(service)) {
    add(findings, 'service_object_required', '$.services[0]');
    return { valid: false, findings };
  }
  for (const field of Object.keys(service)) {
    if (!serviceFields.has(field)) add(findings, 'unsupported_service_field', `$.services[0].${field}`);
  }
  if (service.id !== serviceId) add(findings, 'fixed_service_id_required', '$.services[0].id');
  if (service.hook !== serviceHook) add(findings, 'fixed_patient_view_hook_required', '$.services[0].hook');
  for (const [field, maxLength] of [['title', 100], ['description', 240]]) {
    if (typeof service[field] !== 'string' || service[field].trim() === '' || service[field].length > maxLength) {
      add(findings, 'non_empty_bounded_service_text_required', `$.services[0].${field}`);
    }
  }
  return { valid: findings.length === 0, findings };
}

export function buildSyntheticDiscoveryReport({ discovery, fixtureBytes }) {
  const validation = validateSyntheticServiceDiscovery(discovery);
  if (!validation.valid) {
    throw new Error(`Synthetic CDS Hooks discovery contract failed: ${validation.findings.map(({ code }) => code).join(', ')}`);
  }
  return {
    schemaVersion: 1,
    status: 'passed',
    specification: 'CDS Hooks v2.0.1',
    serviceCount: 1,
    serviceId,
    hook: serviceHook,
    prefetchTemplateCount: 0,
    networkRequestMade: false,
    fixtureSha256: createHash('sha256').update(fixtureBytes).digest('hex'),
  };
}

function run() {
  const fixtureBytes = fs.readFileSync(fixturePath);
  const discovery = JSON.parse(fixtureBytes.toString('utf8'));
  const report = buildSyntheticDiscoveryReport({ discovery, fixtureBytes });
  process.stdout.write(`${JSON.stringify(report)}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    run();
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
