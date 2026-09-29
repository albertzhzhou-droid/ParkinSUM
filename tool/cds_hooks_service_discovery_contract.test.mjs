import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  buildSyntheticDiscoveryReport,
  validateSyntheticServiceDiscovery,
} from './cds_hooks_service_discovery_contract.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixturePath = path.join(root, 'test/fixtures/cds_hooks_service_discovery.synthetic.json');
const fixtureBytes = fs.readFileSync(fixturePath);
const fixture = JSON.parse(fixtureBytes.toString('utf8'));

test('fixed synthetic CDS Hooks v2 discovery metadata passes without prefetch', () => {
  assert.deepEqual(validateSyntheticServiceDiscovery(fixture), { valid: true, findings: [] });
  const report = buildSyntheticDiscoveryReport({ discovery: fixture, fixtureBytes });
  assert.equal(report.specification, 'CDS Hooks v2.0.1');
  assert.equal(report.serviceCount, 1);
  assert.equal(report.serviceId, 'parkinsum-synthetic-patient-view');
  assert.equal(report.hook, 'patient-view');
  assert.equal(report.prefetchTemplateCount, 0);
  assert.equal(report.networkRequestMade, false);
  assert.match(report.fixtureSha256, /^[0-9a-f]{64}$/);
});

test('discovery payload rejects additional services and unknown fields', () => {
  assert.ok(validateSyntheticServiceDiscovery({ services: [...fixture.services, fixture.services[0]] })
    .findings.some(({ code }) => code === 'one_fixed_service_required'));

  const extraRootField = structuredClone(fixture);
  extraRootField.endpoint = 'https://example.org/cds-services';
  assert.ok(validateSyntheticServiceDiscovery(extraRootField)
    .findings.some(({ code }) => code === 'unsupported_discovery_field'));

  const extraServiceField = structuredClone(fixture);
  extraServiceField.services[0].prefetch = { observation: 'Observation?patient={{context.patientId}}' };
  assert.ok(validateSyntheticServiceDiscovery(extraServiceField)
    .findings.some(({ code }) => code === 'unsupported_service_field'));
});

test('service identity and required discovery text remain fixed and bounded', () => {
  for (const [field, value, expectedCode] of [
    ['id', 'other-service', 'fixed_service_id_required'],
    ['hook', 'order-sign', 'fixed_patient_view_hook_required'],
    ['description', '   ', 'non_empty_bounded_service_text_required'],
    ['title', 'x'.repeat(101), 'non_empty_bounded_service_text_required'],
  ]) {
    const changed = structuredClone(fixture);
    changed.services[0][field] = value;
    assert.ok(validateSyntheticServiceDiscovery(changed)
      .findings.some(({ code }) => code === expectedCode), `${field} should fail closed`);
  }
});

test('invalid discovery envelopes fail closed and cannot produce reports', () => {
  for (const value of [null, {}, { services: null }, { services: [] }, { services: [null] }]) {
    assert.equal(validateSyntheticServiceDiscovery(value).valid, false);
  }
  assert.throws(() => buildSyntheticDiscoveryReport({ discovery: {}, fixtureBytes }), /contract failed/);
});
