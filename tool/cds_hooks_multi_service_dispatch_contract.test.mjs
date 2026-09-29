import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  buildSyntheticDispatchReport,
  isValidFhirR4Id,
  planSyntheticServicePrefetchOutcomePreviews,
  planSyntheticServicePrefetchPayloads,
  planSyntheticServiceRequestEnvelopePreviews,
  planSyntheticHookDispatch,
  planSyntheticHookPrefetch,
  planSyntheticServicePrefetchBindings,
  resolveSyntheticHookPrefetch,
  validateSyntheticPrefetchOutcomeFixture,
  validateSyntheticPrefetchResultFixture,
  validateSyntheticMultiServiceDiscovery,
} from './cds_hooks_multi_service_dispatch_contract.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fixturePath = path.join(root, 'test/fixtures/cds_hooks_multi_service.synthetic.json');
const prefetchFixturePath = path.join(
  root,
  'test/fixtures/cds_hooks_multi_service_prefetch.synthetic.json',
);
const prefetchOutcomeFixturePath = path.join(
  root,
  'test/fixtures/cds_hooks_multi_service_prefetch_outcomes.synthetic.json',
);
const fixtureBytes = fs.readFileSync(fixturePath);
const fixture = JSON.parse(fixtureBytes.toString('utf8'));
const prefetchFixtureBytes = fs.readFileSync(prefetchFixturePath);
const prefetchFixture = JSON.parse(prefetchFixtureBytes.toString('utf8'));
const prefetchOutcomeFixtureBytes = fs.readFileSync(prefetchOutcomeFixturePath);
const prefetchOutcomeFixture = JSON.parse(
  prefetchOutcomeFixtureBytes.toString('utf8'),
);

test('fixed multi-service discovery registry passes its bounded synthetic contract', () => {
  assert.deepEqual(validateSyntheticMultiServiceDiscovery(fixture), { valid: true, findings: [] });
  assert.equal(fixture.services.length, 4);
});

test('hook dispatch plan filters only matching service IDs and preserves registry order', () => {
  assert.deepEqual(planSyntheticHookDispatch({ discovery: fixture, hook: 'patient-view' }), [
    'parkinsum-synthetic-patient-review-a',
    'parkinsum-synthetic-patient-review-b',
  ]);
  assert.deepEqual(planSyntheticHookDispatch({ discovery: fixture, hook: 'order-select' }), [
    'parkinsum-synthetic-order-selection-a',
    'parkinsum-synthetic-order-selection-b',
  ]);
});

test('prefetch planning coalesces exact templates within one hook and keeps keys service-scoped', () => {
  const patientPlan = planSyntheticHookPrefetch({ discovery: fixture, hook: 'patient-view' });
  assert.deepEqual(patientPlan, [
    {
      queryTemplate: 'Patient/{{context.patientId}}',
      serviceAssignments: [
        { serviceId: 'parkinsum-synthetic-patient-review-a', prefetchKey: 'patient' },
        { serviceId: 'parkinsum-synthetic-patient-review-b', prefetchKey: 'subject' },
      ],
    },
    {
      queryTemplate: 'Condition?patient={{context.patientId}}&_count=2',
      serviceAssignments: [
        { serviceId: 'parkinsum-synthetic-patient-review-a', prefetchKey: 'conditions' },
        { serviceId: 'parkinsum-synthetic-patient-review-b', prefetchKey: 'problem-list' },
      ],
    },
  ]);

  const orderPlan = planSyntheticHookPrefetch({ discovery: fixture, hook: 'order-select' });
  assert.equal(orderPlan.length, 2);
  assert.deepEqual(orderPlan[0].serviceAssignments, [
    { serviceId: 'parkinsum-synthetic-order-selection-a', prefetchKey: 'patient' },
    { serviceId: 'parkinsum-synthetic-order-selection-b', prefetchKey: 'subject' },
  ]);
  assert.deepEqual(orderPlan[1].serviceAssignments, [
    { serviceId: 'parkinsum-synthetic-order-selection-a', prefetchKey: 'conditions' },
    { serviceId: 'parkinsum-synthetic-order-selection-b', prefetchKey: 'problem-list' },
  ]);
  assert.notStrictEqual(patientPlan[0], orderPlan[0]);
});

test('resolved prefetch previews substitute only a bounded FHIR R4 id', () => {
  const patientPlan = resolveSyntheticHookPrefetch({
    discovery: fixture,
    hook: 'patient-view',
    patientId: 'synthetic-patient-001',
  });
  assert.deepEqual(patientPlan.map(({ relativeFhirRequest }) => relativeFhirRequest), [
    'Patient/synthetic-patient-001',
    'Condition?patient=synthetic-patient-001&_count=2',
  ]);
  assert.deepEqual(patientPlan[0].serviceAssignments, [
    { serviceId: 'parkinsum-synthetic-patient-review-a', prefetchKey: 'patient' },
    { serviceId: 'parkinsum-synthetic-patient-review-b', prefetchKey: 'subject' },
  ]);

  const maximumLengthId = 'a'.repeat(64);
  assert.equal(isValidFhirR4Id(maximumLengthId), true);
  assert.equal(isValidFhirR4Id('a'.repeat(65)), false);
  assert.equal(isValidFhirR4Id('patient/../1'), false);
  assert.equal(isValidFhirR4Id('patient_id'), false);
  assert.equal(isValidFhirR4Id('患者'), false);
  assert.equal(isValidFhirR4Id('patient-1\n'), false);
  assert.equal(isValidFhirR4Id('patient-1\r'), false);
  assert.equal(isValidFhirR4Id('patient-1\u2028'), false);
  assert.equal(isValidFhirR4Id(null), false);
  assert.throws(() => resolveSyntheticHookPrefetch({
    discovery: fixture,
    hook: 'order-select',
    patientId: maximumLengthId,
  }), /fixed synthetic FHIR R4 id/);
  for (const patientId of [
    '',
    'a'.repeat(65),
    'patient/../../Patient/other',
    'patient_id',
    '病人',
  ]) {
    assert.throws(() => resolveSyntheticHookPrefetch({
      discovery: fixture,
      hook: 'patient-view',
      patientId,
    }), /fixed synthetic FHIR R4 id/);
  }
});

test('service-scoped bindings map only each matching service key to its fixed path', () => {
  const patientPlans = planSyntheticServicePrefetchBindings({
    discovery: fixture,
    hook: 'patient-view',
  });
  assert.deepEqual(patientPlans, [
    {
      serviceId: 'parkinsum-synthetic-patient-review-a',
      bindings: [
        {
          prefetchKey: 'patient',
          queryTemplate: 'Patient/{{context.patientId}}',
          relativeFhirRequest: 'Patient/synthetic-patient-001',
        },
        {
          prefetchKey: 'conditions',
          queryTemplate: 'Condition?patient={{context.patientId}}&_count=2',
          relativeFhirRequest: 'Condition?patient=synthetic-patient-001&_count=2',
        },
      ],
    },
    {
      serviceId: 'parkinsum-synthetic-patient-review-b',
      bindings: [
        {
          prefetchKey: 'subject',
          queryTemplate: 'Patient/{{context.patientId}}',
          relativeFhirRequest: 'Patient/synthetic-patient-001',
        },
        {
          prefetchKey: 'problem-list',
          queryTemplate: 'Condition?patient={{context.patientId}}&_count=2',
          relativeFhirRequest: 'Condition?patient=synthetic-patient-001&_count=2',
        },
      ],
    },
  ]);
  assert.deepEqual(
    planSyntheticServicePrefetchBindings({
      discovery: fixture,
      hook: 'order-select',
    }).map(({ serviceId }) => serviceId),
    [
      'parkinsum-synthetic-order-selection-a',
      'parkinsum-synthetic-order-selection-b',
    ],
  );
  assert.ok(patientPlans.every((plan) =>
    plan.bindings.every((binding) =>
      Object.keys(binding).sort().join(',') ===
        'prefetchKey,queryTemplate,relativeFhirRequest',
    ),
  ));
});

test('fixed synthetic prefetch results are copied only to each requesting service keys', () => {
  assert.deepEqual(validateSyntheticPrefetchResultFixture(prefetchFixture), {
    valid: true,
    findings: [],
  });
  const patientPlans = planSyntheticServicePrefetchPayloads({
    discovery: fixture,
    hook: 'patient-view',
    responseFixture: prefetchFixture,
  });
  assert.deepEqual(patientPlans, [
    {
      serviceId: 'parkinsum-synthetic-patient-review-a',
      prefetch: {
        patient: { resourceType: 'Patient', id: 'synthetic-patient-001' },
        conditions: {
          resourceType: 'Bundle',
          type: 'searchset',
          total: 0,
          entry: [],
        },
      },
    },
    {
      serviceId: 'parkinsum-synthetic-patient-review-b',
      prefetch: {
        subject: { resourceType: 'Patient', id: 'synthetic-patient-001' },
        'problem-list': {
          resourceType: 'Bundle',
          type: 'searchset',
          total: 0,
          entry: [],
        },
      },
    },
  ]);
  assert.deepEqual(
    planSyntheticServicePrefetchPayloads({
      discovery: fixture,
      hook: 'order-select',
      responseFixture: prefetchFixture,
    }).map(({ serviceId, prefetch }) => ({
      serviceId,
      keys: Object.keys(prefetch),
    })),
    [
      {
        serviceId: 'parkinsum-synthetic-order-selection-a',
        keys: ['patient', 'conditions'],
      },
      {
        serviceId: 'parkinsum-synthetic-order-selection-b',
        keys: ['subject', 'problem-list'],
      },
    ],
  );
  assert.equal(Object.isFrozen(patientPlans[0].prefetch.patient), true);
  assert.equal(Object.isFrozen(patientPlans[0].prefetch.conditions.entry), true);
  assert.throws(() => {
    patientPlans[0].prefetch.patient.id = 'other';
  }, TypeError);

  const wrongPatientId = structuredClone(prefetchFixture);
  wrongPatientId.patientId = 'patient-123';
  assert.ok(validateSyntheticPrefetchResultFixture(wrongPatientId).findings
    .some(({ code }) => code === 'fixed_synthetic_patient_id_required'));
  const extraPatientData = structuredClone(prefetchFixture);
  extraPatientData.queryResults['Patient/{{context.patientId}}'].name = [
    { text: 'Synthetic Patient' },
  ];
  assert.ok(validateSyntheticPrefetchResultFixture(extraPatientData).findings
    .some(({ code }) => code === 'fixed_synthetic_patient_result_required'));
  const nonEmptySearch = structuredClone(prefetchFixture);
  nonEmptySearch.queryResults[
    'Condition?patient={{context.patientId}}&_count=2'
  ].entry.push({ resource: { resourceType: 'Condition' } });
  assert.ok(validateSyntheticPrefetchResultFixture(nonEmptySearch).findings
    .some(({ code }) => code === 'fixed_empty_condition_searchset_required'));
  assert.throws(() => planSyntheticServicePrefetchPayloads({
    discovery: fixture,
    hook: 'patient-view',
    responseFixture: wrongPatientId,
  }), /prefetch result contract failed/);
});

test('fixed request envelopes carry required hook context and service-owned prefetch only', () => {
  const patientRequests = planSyntheticServiceRequestEnvelopePreviews({
    discovery: fixture,
    hook: 'patient-view',
    responseFixture: prefetchFixture,
  });
  assert.equal(patientRequests.length, 2);
  const hookInstances = new Set();
  for (const { serviceId, request } of patientRequests) {
    assert.deepEqual(Object.keys(request).sort(), [
      'context',
      'hook',
      'hookInstance',
      'prefetch',
    ]);
    assert.equal(request.hook, 'patient-view');
    assert.match(
      request.hookInstance,
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    hookInstances.add(request.hookInstance);
    assert.deepEqual(request.context, {
      userId: 'Practitioner/synthetic-practitioner-001',
      patientId: 'synthetic-patient-001',
    });
    assert.deepEqual(
      Object.keys(request.prefetch).sort(),
      serviceId.endsWith('-a') ? ['conditions', 'patient'] : ['problem-list', 'subject'],
    );
    assert.equal(request.fhirServer, undefined);
    assert.equal(request.fhirAuthorization, undefined);
    assert.equal(Object.isFrozen(request.context), true);
    assert.equal(Object.isFrozen(request.prefetch), true);
  }
  assert.equal(hookInstances.size, 2);

  const orderRequests = planSyntheticServiceRequestEnvelopePreviews({
    discovery: fixture,
    hook: 'order-select',
    responseFixture: prefetchFixture,
  });
  assert.equal(orderRequests.length, 2);
  for (const { request } of orderRequests) {
    assert.equal(request.hook, 'order-select');
    assert.deepEqual(request.context, {
      userId: 'Practitioner/synthetic-practitioner-001',
      patientId: 'synthetic-patient-001',
      selections: ['ServiceRequest/synthetic-order-001'],
      draftOrders: {
        resourceType: 'Bundle',
        type: 'collection',
        entry: [
          {
            fullUrl: 'urn:uuid:5f9f2f8b-76aa-4ed5-aac6-3a98d19e73db',
            resource: {
              resourceType: 'ServiceRequest',
              id: 'synthetic-order-001',
              status: 'draft',
              intent: 'order',
              subject: { reference: 'Patient/synthetic-patient-001' },
            },
          },
        ],
      },
    });
    assert.equal(Object.isFrozen(request.context.selections), true);
    assert.equal(Object.isFrozen(request.context.draftOrders.entry), true);
    assert.equal(Object.isFrozen(request.context.draftOrders.entry[0].resource), true);
  }
  assert.throws(() => {
    orderRequests[0].request.context.draftOrders.entry[0].resource.status = 'active';
  }, TypeError);
  assert.throws(() => planSyntheticServiceRequestEnvelopePreviews({
    discovery: fixture,
    hook: 'patient-discharge',
    responseFixture: prefetchFixture,
  }), /outside the fixed synthetic fixture/);
});

test('prefetch outcome previews distinguish values, empty searches, nulls, and omitted keys', () => {
  assert.deepEqual(
    validateSyntheticPrefetchOutcomeFixture(prefetchOutcomeFixture, fixture),
    { valid: true, findings: [] },
  );
  for (const hook of ['patient-view', 'order-select']) {
    const plans = planSyntheticServicePrefetchOutcomePreviews({
      discovery: fixture,
      hook,
      responseFixture: prefetchFixture,
      outcomeFixture: prefetchOutcomeFixture,
    });
    assert.equal(plans.length, 2);
    assert.deepEqual(plans[0], {
      serviceId: hook === 'patient-view'
        ? 'parkinsum-synthetic-patient-review-a'
        : 'parkinsum-synthetic-order-selection-a',
      keyOutcomes: {
        patient: 'resource',
        conditions: 'empty_searchset',
      },
      prefetch: {
        patient: { resourceType: 'Patient', id: 'synthetic-patient-001' },
        conditions: {
          resourceType: 'Bundle',
          type: 'searchset',
          total: 0,
          entry: [],
        },
      },
    });
    assert.deepEqual(plans[1], {
      serviceId: hook === 'patient-view'
        ? 'parkinsum-synthetic-patient-review-b'
        : 'parkinsum-synthetic-order-selection-b',
      keyOutcomes: {
        subject: 'explicit_null',
        'problem-list': 'not_satisfied',
      },
      prefetch: { subject: null },
    });
    assert.equal(Object.hasOwn(plans[1].prefetch, 'subject'), true);
    assert.equal(plans[1].prefetch.subject, null);
    assert.equal(Object.hasOwn(plans[1].prefetch, 'problem-list'), false);
    assert.equal(Object.isFrozen(plans[0].prefetch.conditions.entry), true);
    assert.throws(() => {
      plans[1].keyOutcomes.subject = 'resource';
    }, TypeError);
  }

  const incomplete = structuredClone(prefetchOutcomeFixture);
  incomplete.outcomes.pop();
  assert.ok(validateSyntheticPrefetchOutcomeFixture(incomplete, fixture).findings
    .some(({ code }) => code === 'complete_bounded_prefetch_outcome_list_required'));
  const duplicate = structuredClone(prefetchOutcomeFixture);
  duplicate.outcomes[1] = structuredClone(duplicate.outcomes[0]);
  assert.ok(validateSyntheticPrefetchOutcomeFixture(duplicate, fixture).findings
    .some(({ code }) => code === 'duplicate_prefetch_outcome_assignment'));
  const wrongState = structuredClone(prefetchOutcomeFixture);
  wrongState.outcomes[2].state = 'empty_searchset';
  assert.ok(validateSyntheticPrefetchOutcomeFixture(wrongState, fixture).findings
    .some(({ code }) => code === 'unsupported_fixed_prefetch_outcome_state'));
  const foreignKey = structuredClone(prefetchOutcomeFixture);
  foreignKey.outcomes[0].prefetchKey = 'problem-list';
  assert.ok(validateSyntheticPrefetchOutcomeFixture(foreignKey, fixture).findings
    .some(({ code }) => code === 'prefetch_outcome_must_match_registered_service_key'));
  const extraField = structuredClone(prefetchOutcomeFixture);
  extraField.outcomes[0].resource = { resourceType: 'Patient' };
  assert.ok(validateSyntheticPrefetchOutcomeFixture(extraField, fixture).findings
    .some(({ code }) => code === 'invalid_prefetch_outcome_entry'));
  assert.throws(() => planSyntheticServicePrefetchOutcomePreviews({
    discovery: fixture,
    hook: 'patient-view',
    responseFixture: prefetchFixture,
    outcomeFixture: wrongState,
  }), /prefetch outcome contract failed/);
});

test('dispatch report contains counts, IDs, hook names, and a fixture digest only', () => {
  const report = buildSyntheticDispatchReport({
    discovery: fixture,
    fixtureBytes,
    prefetchResultFixture: prefetchFixture,
    prefetchResultFixtureBytes: prefetchFixtureBytes,
    prefetchOutcomeFixture,
    prefetchOutcomeFixtureBytes,
  });
  assert.equal(report.specification, 'CDS Hooks v2.0.1');
  assert.equal(report.serviceCount, 4);
  assert.deepEqual(report.hookPlans.map(({ hook, serviceCount }) => ({ hook, serviceCount })), [
    { hook: 'order-select', serviceCount: 2 },
    { hook: 'patient-view', serviceCount: 2 },
  ]);
  assert.deepEqual(report.prefetchPlans.map(({ hook, uniqueQueryTemplateCount, serviceKeyAssignmentCount }) => ({
    hook,
    uniqueQueryTemplateCount,
    serviceKeyAssignmentCount,
  })), [
    { hook: 'order-select', uniqueQueryTemplateCount: 2, serviceKeyAssignmentCount: 4 },
    { hook: 'patient-view', uniqueQueryTemplateCount: 2, serviceKeyAssignmentCount: 4 },
  ]);
  assert.deepEqual(report.resolvedPrefetchPreviews.map(({ hook, requestGroups }) => ({
    hook,
    count: requestGroups.length,
  })), [
    { hook: 'order-select', count: 2 },
    { hook: 'patient-view', count: 2 },
  ]);
  assert.deepEqual(report.serviceScopedPrefetchBindings.map(({ hook, servicePlans }) => ({
    hook,
    serviceCount: servicePlans.length,
    bindingCount: servicePlans.reduce((count, plan) => count + plan.bindings.length, 0),
  })), [
    { hook: 'order-select', serviceCount: 2, bindingCount: 4 },
    { hook: 'patient-view', serviceCount: 2, bindingCount: 4 },
  ]);
  assert.deepEqual(report.prefetchPayloadPreviews.map(({ hook, servicePayloads }) => ({
    hook,
    serviceCount: servicePayloads.length,
    keyCount: servicePayloads.reduce(
      (count, service) => count + Object.keys(service.prefetch).length,
      0,
    ),
  })), [
    { hook: 'order-select', serviceCount: 2, keyCount: 4 },
    { hook: 'patient-view', serviceCount: 2, keyCount: 4 },
  ]);
  assert.deepEqual(report.requestEnvelopePreviews.map(({ hook, serviceRequests }) => ({
    hook,
    serviceCount: serviceRequests.length,
    requestBodyKeys: serviceRequests.map(({ request }) => Object.keys(request).sort()),
  })), [
    {
      hook: 'order-select',
      serviceCount: 2,
      requestBodyKeys: [
        ['context', 'hook', 'hookInstance', 'prefetch'],
        ['context', 'hook', 'hookInstance', 'prefetch'],
      ],
    },
    {
      hook: 'patient-view',
      serviceCount: 2,
      requestBodyKeys: [
        ['context', 'hook', 'hookInstance', 'prefetch'],
        ['context', 'hook', 'hookInstance', 'prefetch'],
      ],
    },
  ]);
  assert.deepEqual(report.prefetchOutcomePreviews.map(({ hook, servicePlans }) => ({
    hook,
    serviceCount: servicePlans.length,
    stateCounts: servicePlans.reduce((counts, plan) => {
      for (const state of Object.values(plan.keyOutcomes)) {
        counts[state] = (counts[state] ?? 0) + 1;
      }
      return counts;
    }, {}),
  })), [
    {
      hook: 'order-select',
      serviceCount: 2,
      stateCounts: {
        resource: 1,
        empty_searchset: 1,
        explicit_null: 1,
        not_satisfied: 1,
      },
    },
    {
      hook: 'patient-view',
      serviceCount: 2,
      stateCounts: {
        resource: 1,
        empty_searchset: 1,
        explicit_null: 1,
        not_satisfied: 1,
      },
    },
  ]);
  assert.equal(report.endpointInvocations, 0);
  assert.equal(report.fhirQueriesIssued, 0);
  assert.equal(report.networkRequests, 0);
  assert.equal(report.patientDataRead, false);
  assert.equal(report.prefetchAssignmentsAreServiceScoped, true);
  assert.equal(report.prefetchPayloadsAreFixedSynthetic, true);
  assert.equal(report.requestEnvelopesAreFixedSynthetic, true);
  assert.equal(report.requestEnvelopesAreNotSent, true);
  assert.equal(report.prefetchOutcomeSemanticsAreDistinct, true);
  assert.equal(report.resolvedContextIsFixedSynthetic, true);
  assert.match(report.fixtureSha256, /^[0-9a-f]{64}$/);
  assert.match(report.prefetchResultFixtureSha256, /^[0-9a-f]{64}$/);
  assert.deepEqual(Object.keys(report), [
    'schemaVersion',
    'status',
    'specification',
    'serviceCount',
    'hookPlans',
    'prefetchPlans',
    'resolvedPrefetchPreviews',
    'serviceScopedPrefetchBindings',
    'prefetchPayloadPreviews',
    'prefetchOutcomePreviews',
    'requestEnvelopePreviews',
    'endpointInvocations',
    'fhirQueriesIssued',
    'networkRequests',
    'patientDataRead',
    'prefetchAssignmentsAreServiceScoped',
    'prefetchPayloadsAreFixedSynthetic',
    'requestEnvelopesAreFixedSynthetic',
    'requestEnvelopesAreNotSent',
    'prefetchOutcomeSemanticsAreDistinct',
    'resolvedContextIsFixedSynthetic',
    'fixtureSha256',
    'prefetchResultFixtureSha256',
    'prefetchOutcomeFixtureSha256',
  ]);
});

test('duplicate IDs, extra fields, unsupported hooks, and unbounded lists fail closed', () => {
  const duplicate = structuredClone(fixture);
  duplicate.services[1].id = duplicate.services[0].id;
  assert.ok(validateSyntheticMultiServiceDiscovery(duplicate).findings
    .some(({ code }) => code === 'duplicate_service_id'));

  const extraField = structuredClone(fixture);
  extraField.services[0].endpoint = 'https://example.invalid/cds';
  assert.ok(validateSyntheticMultiServiceDiscovery(extraField).findings
    .some(({ code }) => code === 'unsupported_service_field'));

  const unboundedPrefetch = structuredClone(fixture);
  unboundedPrefetch.services[0].prefetch.unbounded = 'Patient/{{context.patientId}}';
  unboundedPrefetch.services[0].prefetch.extra = 'Patient/{{context.patientId}}';
  assert.ok(validateSyntheticMultiServiceDiscovery(unboundedPrefetch).findings
    .some(({ code }) => code === 'bounded_prefetch_map_required'));

  const emptyPrefetch = structuredClone(fixture);
  emptyPrefetch.services[0].prefetch = {};
  assert.ok(validateSyntheticMultiServiceDiscovery(emptyPrefetch).findings
    .some(({ code }) => code === 'bounded_prefetch_map_required'));

  for (const queryTemplate of [
    'Patient/synthetic-patient-001',
    'Patient/{{context.patientId}}/{{context.patientId}}',
    'Patient/{{context.patient.id}}',
    'Observation?patient={{context.patientId}}&_count=2',
    'Condition?patient={{context.patientId}}&_sort=date&_count=2',
  ]) {
    const unsupportedPrefetch = structuredClone(fixture);
    unsupportedPrefetch.services[0].prefetch.patient = queryTemplate;
    assert.ok(validateSyntheticMultiServiceDiscovery(unsupportedPrefetch).findings
      .some(({ code }) => code === 'unsupported_synthetic_prefetch_template'));
  }

  const invalidPrefetchKey = structuredClone(fixture);
  invalidPrefetchKey.services[0].prefetch['patient id'] = 'Patient/{{context.patientId}}';
  assert.ok(validateSyntheticMultiServiceDiscovery(invalidPrefetchKey).findings
    .some(({ code }) => code === 'bounded_prefetch_key_required'));

  const unsupportedHook = structuredClone(fixture);
  unsupportedHook.services[0].hook = 'patient-discharge';
  assert.ok(validateSyntheticMultiServiceDiscovery(unsupportedHook).findings
    .some(({ code }) => code === 'unsupported_synthetic_hook'));

  assert.ok(validateSyntheticMultiServiceDiscovery({ services: fixture.services.slice(0, 1) }).findings
    .some(({ code }) => code === 'bounded_multi_service_list_required'));
  assert.throws(() => planSyntheticHookDispatch({ discovery: fixture, hook: 'patient-discharge' }), /outside the fixed synthetic fixture/);
});

test('invalid registries cannot produce a dispatch plan or report', () => {
  const sameHook = structuredClone(fixture);
  sameHook.services.forEach((service) => { service.hook = 'patient-view'; });
  assert.ok(validateSyntheticMultiServiceDiscovery(sameHook).findings
    .some(({ code }) => code === 'multiple_synthetic_hooks_required'));
  assert.throws(() => planSyntheticHookDispatch({ discovery: {}, hook: 'patient-view' }), /contract failed/);
  assert.throws(() => buildSyntheticDispatchReport({
    discovery: {},
    fixtureBytes,
    prefetchResultFixture: prefetchFixture,
    prefetchResultFixtureBytes: prefetchFixtureBytes,
    prefetchOutcomeFixture,
    prefetchOutcomeFixtureBytes,
  }), /contract failed/);
});
