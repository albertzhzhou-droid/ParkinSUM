import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  buildSyntheticServiceResponsePreview,
  validateSyntheticServiceResponseFixture,
} from './cds_hooks_multi_service_response_contract.mjs';

const discovery = JSON.parse(
  fs.readFileSync('test/fixtures/cds_hooks_multi_service.synthetic.json', 'utf8'),
);
const fixture = JSON.parse(
  fs.readFileSync('test/fixtures/cds_hooks_multi_service_responses.synthetic.json', 'utf8'),
);

test('fixed response previews remain bound to each registered service', () => {
  const validation = validateSyntheticServiceResponseFixture(fixture, discovery);
  assert.equal(validation.valid, true);
  const bytes = Buffer.from(JSON.stringify(fixture));
  const report = buildSyntheticServiceResponsePreview({
    discovery,
    responseFixture: fixture,
    responseFixtureBytes: bytes,
  });
  assert.deepEqual(report.hooks.map(({ hook }) => hook), ['patient-view', 'order-select']);
  for (const hookReport of report.hooks) {
    assert.equal(hookReport.serviceResponseCount, 2);
    assert.equal(hookReport.informationOnlyCardCount, 1);
    assert.equal(hookReport.noGuidanceCount, 1);
    assert.equal(hookReport.responsesRemainServiceScoped, true);
  }
  assert.equal(report.responseAggregationPerformed, false);
  assert.equal(report.endpointInvocations, 0);
  assert.equal(report.networkRequests, 0);
  assert.equal(report.patientDataRead, false);
});

test('empty cards remains distinct from the fixed information-only response', () => {
  for (const hook of ['patient-view', 'order-select']) {
    const rows = fixture.responses.filter((entry) => entry.hook === hook);
    const informational = rows.find((entry) => entry.expectedState === 'information_only');
    const empty = rows.find((entry) => entry.expectedState === 'no_guidance');
    assert.equal(informational.response.cards.length, 1);
    assert.equal(informational.response.cards[0].indicator, 'info');
    assert.deepEqual(empty.response, { cards: [] });
  }
});

test('foreign, duplicate, missing, and cross-hook service responses fail closed', () => {
  const duplicate = structuredClone(fixture);
  duplicate.responses[1] = structuredClone(duplicate.responses[0]);
  assert.equal(validateSyntheticServiceResponseFixture(duplicate, discovery).valid, false);

  const missing = structuredClone(fixture);
  missing.responses.pop();
  assert.equal(validateSyntheticServiceResponseFixture(missing, discovery).valid, false);

  const foreign = structuredClone(fixture);
  foreign.responses[0].serviceId = 'unregistered-service';
  assert.equal(validateSyntheticServiceResponseFixture(foreign, discovery).valid, false);

  const mismatchedHook = structuredClone(fixture);
  mismatchedHook.responses[0].hook = 'order-select';
  assert.equal(validateSyntheticServiceResponseFixture(mismatchedHook, discovery).valid, false);
});

test('suggestions, clinical prose, unknown fields, and state drift fail closed', () => {
  const suggestion = structuredClone(fixture);
  suggestion.responses[0].response.cards[0].indicator = 'warning';
  assert.equal(validateSyntheticServiceResponseFixture(suggestion, discovery).valid, false);

  const clinicalProse = structuredClone(fixture);
  clinicalProse.responses[0].response.cards[0].summary = 'Take this medication now.';
  assert.equal(validateSyntheticServiceResponseFixture(clinicalProse, discovery).valid, false);

  const unknownField = structuredClone(fixture);
  unknownField.responses[0].response.secret = true;
  assert.equal(validateSyntheticServiceResponseFixture(unknownField, discovery).valid, false);

  const badEmpty = structuredClone(fixture);
  badEmpty.responses[1].response.cards.push({ summary: 'unexpected' });
  assert.equal(validateSyntheticServiceResponseFixture(badEmpty, discovery).valid, false);
});
