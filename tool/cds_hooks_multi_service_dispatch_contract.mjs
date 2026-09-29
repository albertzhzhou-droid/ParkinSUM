#!/usr/bin/env node

// Fixed offline CDS Hooks dispatch, path, prefetch, and request-preview contracts.
// It never resolves or invokes service endpoints or sends a request.
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

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
const discoveryFields = new Set(['services']);
const serviceFields = new Set(['id', 'hook', 'title', 'description', 'prefetch']);
const supportedSyntheticHooks = new Set(['patient-view', 'order-select']);
const serviceIdPattern = /^parkinsum-synthetic-[a-z0-9]+(?:-[a-z0-9]+)*$/;
const minimumServiceCount = 2;
const maximumServiceCount = 6;
const prefetchKeyPattern = /^[A-Za-z][A-Za-z0-9_-]{0,31}$/;
const minimumPrefetchKeyCount = 1;
const maximumPrefetchKeyCount = 3;
const supportedPrefetchTemplates = new Set([
  'Patient/{{context.patientId}}',
  'Condition?patient={{context.patientId}}&_count=2',
]);
const fhirR4IdPattern = /^[A-Za-z0-9.-]{1,64}$/;
const patientIdToken = '{{context.patientId}}';
const fixedSyntheticPatientId = 'synthetic-patient-001';
const fixedPrefetchOutcomeByKey = new Map([
  ['patient', 'resource'],
  ['conditions', 'empty_searchset'],
  ['subject', 'explicit_null'],
  ['problem-list', 'not_satisfied'],
]);
const fixedSyntheticUserId = 'Practitioner/synthetic-practitioner-001';
const fixedSyntheticOrderId = 'synthetic-order-001';
const syntheticHookInstancePreviews = Object.freeze({
  'parkinsum-synthetic-patient-review-a': '83c30ec4-d8ae-4c9a-a7ee-3c845872c1e4',
  'parkinsum-synthetic-patient-review-b': 'e6583b52-6d9f-4301-9ae1-f3f0ad8e1b46',
  'parkinsum-synthetic-order-selection-a': '42f304b0-89c4-42f3-a5b9-7901754ea341',
  'parkinsum-synthetic-order-selection-b': 'c2d82059-9fe8-4c17-8c7c-b39aa3fb4380',
});
const syntheticDraftServiceRequest = Object.freeze({
  resourceType: 'ServiceRequest',
  id: fixedSyntheticOrderId,
  status: 'draft',
  intent: 'order',
  subject: Object.freeze({ reference: 'Patient/synthetic-patient-001' }),
});
const syntheticDraftOrdersBundle = Object.freeze({
  resourceType: 'Bundle',
  type: 'collection',
  entry: Object.freeze([
    Object.freeze({
      fullUrl: 'urn:uuid:5f9f2f8b-76aa-4ed5-aac6-3a98d19e73db',
      resource: syntheticDraftServiceRequest,
    }),
  ]),
});

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function add(findings, code, pathName) {
  findings.push({ code, path: pathName });
}

function hasExactKeys(value, expectedKeys) {
  return isRecord(value)
    && Object.keys(value).sort().join('\0') === [...expectedKeys].sort().join('\0');
}

function freezeJson(value) {
  if (Array.isArray(value)) {
    value.forEach(freezeJson);
  } else if (isRecord(value)) {
    Object.values(value).forEach(freezeJson);
  }
  return Object.freeze(value);
}

function cloneAndFreezeJson(value) {
  return freezeJson(JSON.parse(JSON.stringify(value)));
}

export function validateSyntheticPrefetchResultFixture(value) {
  const findings = [];
  if (!hasExactKeys(value, ['schemaVersion', 'patientId', 'queryResults'])) {
    add(findings, 'invalid_prefetch_fixture_shape', '$');
    return { valid: false, findings };
  }
  if (value.schemaVersion !== 1) {
    add(findings, 'unsupported_prefetch_fixture_schema', '$.schemaVersion');
  }
  if (value.patientId !== fixedSyntheticPatientId) {
    add(findings, 'fixed_synthetic_patient_id_required', '$.patientId');
  }
  if (!hasExactKeys(value.queryResults, supportedPrefetchTemplates)) {
    add(findings, 'fixed_prefetch_results_required', '$.queryResults');
    return { valid: findings.length === 0, findings };
  }

  const patientResult = value.queryResults['Patient/{{context.patientId}}'];
  if (!hasExactKeys(patientResult, ['resourceType', 'id'])
    || patientResult.resourceType !== 'Patient'
    || patientResult.id !== fixedSyntheticPatientId) {
    add(findings, 'fixed_synthetic_patient_result_required', '$.queryResults.Patient');
  }

  const conditionResult = value.queryResults[
    'Condition?patient={{context.patientId}}&_count=2'
  ];
  if (!hasExactKeys(conditionResult, ['resourceType', 'type', 'total', 'entry'])
    || conditionResult.resourceType !== 'Bundle'
    || conditionResult.type !== 'searchset'
    || conditionResult.total !== 0
    || !Array.isArray(conditionResult.entry)
    || conditionResult.entry.length !== 0) {
    add(findings, 'fixed_empty_condition_searchset_required', '$.queryResults.Condition');
  }
  return { valid: findings.length === 0, findings };
}

export function validateSyntheticPrefetchOutcomeFixture(value, discovery) {
  const findings = [];
  if (!hasExactKeys(value, ['schemaVersion', 'outcomes'])) {
    add(findings, 'invalid_prefetch_outcome_fixture_shape', '$');
    return { valid: false, findings };
  }
  if (value.schemaVersion !== 1) {
    add(findings, 'unsupported_prefetch_outcome_fixture_schema', '$.schemaVersion');
  }
  const discoveryValidation = validateSyntheticMultiServiceDiscovery(discovery);
  if (!discoveryValidation.valid) {
    add(findings, 'valid_discovery_required_for_prefetch_outcomes', '$.outcomes');
    return { valid: false, findings };
  }
  const expectedAssignments = new Set(
    discovery.services.flatMap((service) =>
      Object.keys(service.prefetch ?? {}).map((prefetchKey) =>
        service.hook + '\0' + service.id + '\0' + prefetchKey,
      ),
    ),
  );
  if (!Array.isArray(value.outcomes)
    || value.outcomes.length !== expectedAssignments.size) {
    add(findings, 'complete_bounded_prefetch_outcome_list_required', '$.outcomes');
    return { valid: false, findings };
  }
  const seen = new Set();
  value.outcomes.forEach((outcome, index) => {
    const outcomePath = '$.outcomes[' + index + ']';
    if (!hasExactKeys(outcome, ['hook', 'serviceId', 'prefetchKey', 'state'])) {
      add(findings, 'invalid_prefetch_outcome_entry', outcomePath);
      return;
    }
    const service = discovery.services.find(({ id }) => id === outcome.serviceId);
    if (!supportedSyntheticHooks.has(outcome.hook)
      || !service
      || service.hook !== outcome.hook
      || typeof service.prefetch?.[outcome.prefetchKey] !== 'string') {
      add(findings, 'prefetch_outcome_must_match_registered_service_key', outcomePath);
      return;
    }
    const assignmentKey = outcome.hook + '\0' + outcome.serviceId
      + '\0' + outcome.prefetchKey;
    if (seen.has(assignmentKey)) {
      add(findings, 'duplicate_prefetch_outcome_assignment', outcomePath);
      return;
    }
    seen.add(assignmentKey);
    if (outcome.state !== fixedPrefetchOutcomeByKey.get(outcome.prefetchKey)) {
      add(findings, 'unsupported_fixed_prefetch_outcome_state', outcomePath + '.state');
    }
  });
  for (const assignmentKey of expectedAssignments) {
    if (!seen.has(assignmentKey)) {
      add(findings, 'missing_prefetch_outcome_assignment', '$.outcomes');
    }
  }
  return { valid: findings.length === 0, findings };
}

export function validateSyntheticMultiServiceDiscovery(value) {
  const findings = [];
  if (!isRecord(value)) {
    add(findings, 'discovery_object_required', '$');
    return { valid: false, findings };
  }
  for (const field of Object.keys(value)) {
    if (!discoveryFields.has(field)) add(findings, 'unsupported_discovery_field', `$.${field}`);
  }
  if (!Array.isArray(value.services)
    || value.services.length < minimumServiceCount
    || value.services.length > maximumServiceCount) {
    add(findings, 'bounded_multi_service_list_required', '$.services');
    return { valid: false, findings };
  }

  const serviceIds = new Set();
  const hooks = new Set();
  value.services.forEach((service, index) => {
    const servicePath = `$.services[${index}]`;
    if (!isRecord(service)) {
      add(findings, 'service_object_required', servicePath);
      return;
    }
    for (const field of Object.keys(service)) {
      if (!serviceFields.has(field)) add(findings, 'unsupported_service_field', `${servicePath}.${field}`);
    }
    if (typeof service.id !== 'string' || !serviceIdPattern.test(service.id)) {
      add(findings, 'fixed_synthetic_service_id_required', `${servicePath}.id`);
    } else if (serviceIds.has(service.id)) {
      add(findings, 'duplicate_service_id', `${servicePath}.id`);
    } else {
      serviceIds.add(service.id);
    }
    if (typeof service.hook !== 'string' || !supportedSyntheticHooks.has(service.hook)) {
      add(findings, 'unsupported_synthetic_hook', `${servicePath}.hook`);
    } else {
      hooks.add(service.hook);
    }
    for (const [field, maxLength] of [['title', 100], ['description', 240]]) {
      if (typeof service[field] !== 'string' || service[field].trim() === '' || service[field].length > maxLength) {
        add(findings, 'non_empty_bounded_service_text_required', `${servicePath}.${field}`);
      }
    }
    if (Object.hasOwn(service, 'prefetch')) {
      const prefetch = service.prefetch;
      if (!isRecord(prefetch)
        || Object.keys(prefetch).length < minimumPrefetchKeyCount
        || Object.keys(prefetch).length > maximumPrefetchKeyCount) {
        add(findings, 'bounded_prefetch_map_required', `${servicePath}.prefetch`);
      } else {
        for (const [key, queryTemplate] of Object.entries(prefetch)) {
          if (!prefetchKeyPattern.test(key)) {
            add(findings, 'bounded_prefetch_key_required', `${servicePath}.prefetch.${key}`);
          }
          if (typeof queryTemplate !== 'string' || !supportedPrefetchTemplates.has(queryTemplate)) {
            add(findings, 'unsupported_synthetic_prefetch_template', `${servicePath}.prefetch.${key}`);
          }
        }
      }
    }
  });

  if (hooks.size < 2) add(findings, 'multiple_synthetic_hooks_required', '$.services');
  return { valid: findings.length === 0, findings };
}

export function planSyntheticHookDispatch({ discovery, hook }) {
  const validation = validateSyntheticMultiServiceDiscovery(discovery);
  if (!validation.valid) {
    throw new Error(`Synthetic CDS Hooks dispatch contract failed: ${validation.findings.map(({ code }) => code).join(', ')}`);
  }
  if (typeof hook !== 'string' || !supportedSyntheticHooks.has(hook)) {
    throw new Error('Requested hook is outside the fixed synthetic fixture.');
  }
  return discovery.services
    .filter((service) => service.hook === hook)
    .map((service) => service.id);
}

export function planSyntheticHookPrefetch({ discovery, hook }) {
  const validation = validateSyntheticMultiServiceDiscovery(discovery);
  if (!validation.valid) {
    throw new Error(`Synthetic CDS Hooks dispatch contract failed: ${validation.findings.map(({ code }) => code).join(', ')}`);
  }
  if (typeof hook !== 'string' || !supportedSyntheticHooks.has(hook)) {
    throw new Error('Requested hook is outside the fixed synthetic fixture.');
  }

  const queryGroups = new Map();
  for (const service of discovery.services.filter((candidate) => candidate.hook === hook)) {
    for (const [prefetchKey, queryTemplate] of Object.entries(service.prefetch ?? {})) {
      if (!queryGroups.has(queryTemplate)) queryGroups.set(queryTemplate, []);
      queryGroups.get(queryTemplate).push({ serviceId: service.id, prefetchKey });
    }
  }
  return [...queryGroups].map(([queryTemplate, serviceAssignments]) => ({
    queryTemplate,
    serviceAssignments,
  }));
}

export function isValidFhirR4Id(value) {
  if (typeof value !== 'string') return false;
  const match = fhirR4IdPattern.exec(value);
  return match?.[0].length === value.length;
}

export function resolveSyntheticHookPrefetch({ discovery, hook, patientId }) {
  if (!isValidFhirR4Id(patientId) || patientId !== fixedSyntheticPatientId) {
    throw new Error('Synthetic prefetch context requires the fixed synthetic FHIR R4 id.');
  }
  return planSyntheticHookPrefetch({ discovery, hook }).map((group) => {
    if (group.queryTemplate.split(patientIdToken).length !== 2) {
      throw new Error('Fixed prefetch template must contain one patientId token.');
    }
    return {
      ...group,
      relativeFhirRequest: group.queryTemplate.replaceAll(
        patientIdToken,
        encodeURIComponent(patientId),
      ),
    };
  });
}

export function planSyntheticServicePrefetchBindings({ discovery, hook }) {
  const resolvedGroups = resolveSyntheticHookPrefetch({
    discovery,
    hook,
    patientId: fixedSyntheticPatientId,
  });
  const pathByTemplate = new Map(
    resolvedGroups.map(({ queryTemplate, relativeFhirRequest }) => [
      queryTemplate,
      relativeFhirRequest,
    ]),
  );
  return discovery.services
    .filter((service) => service.hook === hook)
    .map((service) => ({
      serviceId: service.id,
      bindings: Object.entries(service.prefetch ?? {}).map(
        ([prefetchKey, queryTemplate]) => {
          const relativeFhirRequest = pathByTemplate.get(queryTemplate);
          if (typeof relativeFhirRequest !== 'string') {
            throw new Error('Service prefetch key has no hook-scoped path.');
          }
          return { prefetchKey, queryTemplate, relativeFhirRequest };
        },
      ),
    }));
}

export function planSyntheticServicePrefetchPayloads({
  discovery,
  hook,
  responseFixture,
}) {
  const validation = validateSyntheticPrefetchResultFixture(responseFixture);
  if (!validation.valid) {
    throw new Error(`Synthetic prefetch result contract failed: ${validation.findings.map(({ code }) => code).join(', ')}`);
  }
  return Object.freeze(
    planSyntheticServicePrefetchBindings({ discovery, hook }).map((servicePlan) => {
      const prefetch = Object.fromEntries(
        servicePlan.bindings.map((binding) => [
          binding.prefetchKey,
          cloneAndFreezeJson(responseFixture.queryResults[binding.queryTemplate]),
        ]),
      );
      return Object.freeze({
        serviceId: servicePlan.serviceId,
        prefetch: Object.freeze(prefetch),
      });
    }),
  );
}

export function planSyntheticServicePrefetchOutcomePreviews({
  discovery,
  hook,
  responseFixture,
  outcomeFixture,
}) {
  const outcomeValidation = validateSyntheticPrefetchOutcomeFixture(
    outcomeFixture,
    discovery,
  );
  if (!outcomeValidation.valid) {
    throw new Error('Synthetic prefetch outcome contract failed: '
      + outcomeValidation.findings.map(({ code }) => code).join(', '));
  }
  const resultValidation = validateSyntheticPrefetchResultFixture(responseFixture);
  if (!resultValidation.valid) {
    throw new Error('Synthetic prefetch result contract failed: '
      + resultValidation.findings.map(({ code }) => code).join(', '));
  }
  if (!supportedSyntheticHooks.has(hook)) {
    throw new Error('Hook is outside the fixed synthetic fixture.');
  }
  const stateByService = new Map();
  for (const outcome of outcomeFixture.outcomes) {
    if (outcome.hook !== hook) continue;
    if (!stateByService.has(outcome.serviceId)) {
      stateByService.set(outcome.serviceId, new Map());
    }
    stateByService
      .get(outcome.serviceId)
      .set(outcome.prefetchKey, outcome.state);
  }
  return Object.freeze(
    planSyntheticServicePrefetchBindings({ discovery, hook }).map((servicePlan) => {
      const stateByKey = stateByService.get(servicePlan.serviceId);
      if (!stateByKey) throw new Error('A service has no fixed outcome plan.');
      const keyOutcomes = {};
      const prefetch = {};
      for (const binding of servicePlan.bindings) {
        const state = stateByKey.get(binding.prefetchKey);
        if (!state) throw new Error('A service key has no fixed outcome.');
        keyOutcomes[binding.prefetchKey] = state;
        switch (state) {
          case 'resource':
          case 'empty_searchset':
            prefetch[binding.prefetchKey] = cloneAndFreezeJson(
              responseFixture.queryResults[binding.queryTemplate],
            );
            break;
          case 'explicit_null':
            prefetch[binding.prefetchKey] = null;
            break;
          case 'not_satisfied':
            break;
          default:
            throw new Error('Unsupported fixed prefetch outcome.');
        }
      }
      return Object.freeze({
        serviceId: servicePlan.serviceId,
        keyOutcomes: Object.freeze(keyOutcomes),
        prefetch: Object.freeze(prefetch),
      });
    }),
  );
}

export function planSyntheticServiceRequestEnvelopePreviews({
  discovery,
  hook,
  responseFixture,
}) {
  if (!supportedSyntheticHooks.has(hook)) {
    throw new Error('Hook is outside the fixed synthetic fixture.');
  }
  return Object.freeze(
    planSyntheticServicePrefetchPayloads({
      discovery,
      hook,
      responseFixture,
    }).map(({ serviceId, prefetch }) => {
      const hookInstance = syntheticHookInstancePreviews[serviceId];
      if (typeof hookInstance !== 'string') {
        throw new Error('Service has no fixed synthetic hook-instance preview.');
      }
      const context = hook === 'patient-view'
        ? {
          userId: fixedSyntheticUserId,
          patientId: fixedSyntheticPatientId,
        }
        : {
          userId: fixedSyntheticUserId,
          patientId: fixedSyntheticPatientId,
          selections: ['ServiceRequest/' + fixedSyntheticOrderId],
          draftOrders: syntheticDraftOrdersBundle,
        };
      return Object.freeze({
        serviceId,
        request: cloneAndFreezeJson({
          hook,
          hookInstance,
          context,
          prefetch,
        }),
      });
    }),
  );
}

export function buildSyntheticDispatchReport({
  discovery,
  fixtureBytes,
  prefetchResultFixture,
  prefetchResultFixtureBytes,
  prefetchOutcomeFixture,
  prefetchOutcomeFixtureBytes,
}) {
  const validation = validateSyntheticMultiServiceDiscovery(discovery);
  if (!validation.valid) {
    throw new Error(`Synthetic CDS Hooks dispatch contract failed: ${validation.findings.map(({ code }) => code).join(', ')}`);
  }
  const prefetchResultValidation =
    validateSyntheticPrefetchResultFixture(prefetchResultFixture);
  if (!prefetchResultValidation.valid) {
    throw new Error(`Synthetic prefetch result contract failed: ${prefetchResultValidation.findings.map(({ code }) => code).join(', ')}`);
  }
  const prefetchOutcomeValidation =
    validateSyntheticPrefetchOutcomeFixture(prefetchOutcomeFixture, discovery);
  if (!prefetchOutcomeValidation.valid) {
    throw new Error('Synthetic prefetch outcome contract failed: '
      + prefetchOutcomeValidation.findings.map(({ code }) => code).join(', '));
  }
  const hooks = [...new Set(discovery.services.map(({ hook }) => hook))].sort();
  return {
    schemaVersion: 1,
    status: 'passed',
    specification: 'CDS Hooks v2.0.1',
    serviceCount: discovery.services.length,
    hookPlans: hooks.map((hook) => {
      const serviceIds = planSyntheticHookDispatch({ discovery, hook });
      return { hook, serviceCount: serviceIds.length, serviceIds };
    }),
    prefetchPlans: hooks.map((hook) => {
      const queryGroups = planSyntheticHookPrefetch({ discovery, hook });
      return {
        hook,
        uniqueQueryTemplateCount: queryGroups.length,
        serviceKeyAssignmentCount: queryGroups.reduce(
          (total, group) => total + group.serviceAssignments.length,
          0,
        ),
        queryGroups,
      };
    }),
    resolvedPrefetchPreviews: hooks.map((hook) => {
      const requestGroups = resolveSyntheticHookPrefetch({
        discovery,
        hook,
        patientId: fixedSyntheticPatientId,
      });
      return { hook, requestGroups };
    }),
    serviceScopedPrefetchBindings: hooks.map((hook) => ({
      hook,
      servicePlans: planSyntheticServicePrefetchBindings({ discovery, hook }),
    })),
    prefetchPayloadPreviews: hooks.map((hook) => ({
      hook,
      servicePayloads: planSyntheticServicePrefetchPayloads({
        discovery,
        hook,
        responseFixture: prefetchResultFixture,
      }),
    })),
    prefetchOutcomePreviews: hooks.map((hook) => ({
      hook,
      servicePlans: planSyntheticServicePrefetchOutcomePreviews({
        discovery,
        hook,
        responseFixture: prefetchResultFixture,
        outcomeFixture: prefetchOutcomeFixture,
      }),
    })),
    requestEnvelopePreviews: hooks.map((hook) => ({
      hook,
      serviceRequests: planSyntheticServiceRequestEnvelopePreviews({
        discovery,
        hook,
        responseFixture: prefetchResultFixture,
      }),
    })),
    endpointInvocations: 0,
    fhirQueriesIssued: 0,
    networkRequests: 0,
    patientDataRead: false,
    prefetchAssignmentsAreServiceScoped: true,
    prefetchPayloadsAreFixedSynthetic: true,
    requestEnvelopesAreFixedSynthetic: true,
    requestEnvelopesAreNotSent: true,
    prefetchOutcomeSemanticsAreDistinct: true,
    resolvedContextIsFixedSynthetic: true,
    fixtureSha256: createHash('sha256').update(fixtureBytes).digest('hex'),
    prefetchResultFixtureSha256: createHash('sha256')
      .update(prefetchResultFixtureBytes)
      .digest('hex'),
    prefetchOutcomeFixtureSha256: createHash('sha256')
      .update(prefetchOutcomeFixtureBytes)
      .digest('hex'),
  };
}

function run() {
  const fixtureBytes = fs.readFileSync(fixturePath);
  const prefetchResultFixtureBytes = fs.readFileSync(prefetchFixturePath);
  const prefetchOutcomeFixtureBytes = fs.readFileSync(prefetchOutcomeFixturePath);
  const discovery = JSON.parse(fixtureBytes.toString('utf8'));
  const prefetchResultFixture = JSON.parse(
    prefetchResultFixtureBytes.toString('utf8'),
  );
  const prefetchOutcomeFixture = JSON.parse(
    prefetchOutcomeFixtureBytes.toString('utf8'),
  );
  const report = buildSyntheticDispatchReport({
    discovery,
    fixtureBytes,
    prefetchResultFixture,
    prefetchResultFixtureBytes,
    prefetchOutcomeFixture,
    prefetchOutcomeFixtureBytes,
  });
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
