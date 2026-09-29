#!/usr/bin/env node

// Fixed, per-service synthetic CDS Hooks response previews. No service is called.
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { validateSyntheticMultiServiceDiscovery } from './cds_hooks_multi_service_dispatch_contract.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const discoveryPath = path.join(root, 'test/fixtures/cds_hooks_multi_service.synthetic.json');
const responsePath = path.join(root, 'test/fixtures/cds_hooks_multi_service_responses.synthetic.json');
const hooks = ['patient-view', 'order-select'];
const supportedStates = new Set(['information_only', 'no_guidance']);
const fixedSummary = 'Synthetic information-only response preview.';
const fixedSourceLabel = 'Synthetic service fixture';

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function exactKeys(value, keys) {
  return isRecord(value)
    && Object.keys(value).sort().join('\0') === [...keys].sort().join('\0');
}

function finding(findings, code, pathName) {
  findings.push({ code, path: pathName });
}

export function validateSyntheticServiceResponseFixture(value, discovery) {
  const findings = [];
  if (!exactKeys(value, ['schemaVersion', 'responses'])) {
    finding(findings, 'invalid_response_fixture_shape', '$');
    return { valid: false, findings };
  }
  if (value.schemaVersion !== 1) {
    finding(findings, 'unsupported_response_fixture_schema', '$.schemaVersion');
  }
  const discoveryValidation = validateSyntheticMultiServiceDiscovery(discovery);
  if (!discoveryValidation.valid) {
    finding(findings, 'valid_discovery_required', '$.responses');
    return { valid: false, findings };
  }
  if (!Array.isArray(value.responses) || value.responses.length !== discovery.services.length) {
    finding(findings, 'one_response_per_registered_service_required', '$.responses');
    return { valid: false, findings };
  }

  const servicesById = new Map(discovery.services.map((service) => [service.id, service]));
  const seen = new Set();
  value.responses.forEach((entry, index) => {
    const entryPath = `$.responses[${index}]`;
    if (!exactKeys(entry, ['hook', 'serviceId', 'expectedState', 'response'])) {
      finding(findings, 'invalid_service_response_entry', entryPath);
      return;
    }
    const registeredService = servicesById.get(entry.serviceId);
    if (!registeredService || registeredService.hook !== entry.hook || !hooks.includes(entry.hook)) {
      finding(findings, 'response_must_match_registered_hook_service', entryPath);
      return;
    }
    if (seen.has(entry.serviceId)) {
      finding(findings, 'duplicate_service_response', entryPath);
      return;
    }
    seen.add(entry.serviceId);
    if (!supportedStates.has(entry.expectedState)) {
      finding(findings, 'unsupported_synthetic_response_state', `${entryPath}.expectedState`);
      return;
    }
    if (!exactKeys(entry.response, ['cards']) || !Array.isArray(entry.response.cards)) {
      finding(findings, 'cards_response_required', `${entryPath}.response`);
      return;
    }
    if (entry.expectedState === 'no_guidance') {
      if (entry.response.cards.length !== 0) {
        finding(findings, 'no_guidance_requires_empty_cards', `${entryPath}.response.cards`);
      }
      return;
    }
    if (entry.response.cards.length !== 1) {
      finding(findings, 'one_information_card_required', `${entryPath}.response.cards`);
      return;
    }
    const card = entry.response.cards[0];
    if (!exactKeys(card, ['summary', 'indicator', 'source'])
      || card.summary !== fixedSummary
      || card.indicator !== 'info'
      || !exactKeys(card.source, ['label'])
      || card.source.label !== fixedSourceLabel) {
      finding(findings, 'fixed_nonclinical_information_card_required', `${entryPath}.response.cards[0]`);
    }
  });

  for (const service of discovery.services) {
    if (!seen.has(service.id)) {
      finding(findings, 'registered_service_response_missing', '$.responses');
    }
  }
  return { valid: findings.length === 0, findings };
}

export function buildSyntheticServiceResponsePreview({
  discovery,
  responseFixture,
  responseFixtureBytes,
}) {
  const validation = validateSyntheticServiceResponseFixture(responseFixture, discovery);
  if (!validation.valid) {
    throw new Error(`Synthetic service response contract failed: ${validation.findings.map(({ code }) => code).join(', ')}`);
  }
  return {
    schemaVersion: 1,
    scope: 'fixed-synthetic-per-service-response-preview',
    hooks: hooks.map((hook) => {
      const serviceResponses = responseFixture.responses
        .filter((entry) => entry.hook === hook)
        .map((entry) => ({
          serviceId: entry.serviceId,
          expectedState: entry.expectedState,
          response: entry.response,
          cardCount: entry.response.cards.length,
        }));
      return {
        hook,
        serviceResponses,
        serviceResponseCount: serviceResponses.length,
        informationOnlyCardCount: serviceResponses.filter((entry) => entry.expectedState === 'information_only').length,
        noGuidanceCount: serviceResponses.filter((entry) => entry.expectedState === 'no_guidance').length,
        responsesRemainServiceScoped: true,
      };
    }),
    responseAggregationPerformed: false,
    endpointInvocations: 0,
    networkRequests: 0,
    patientDataRead: false,
    fixtureSha256: createHash('sha256').update(responseFixtureBytes).digest('hex'),
  };
}

function run() {
  const discovery = JSON.parse(fs.readFileSync(discoveryPath, 'utf8'));
  const responseFixtureBytes = fs.readFileSync(responsePath);
  const responseFixture = JSON.parse(responseFixtureBytes.toString('utf8'));
  const report = buildSyntheticServiceResponsePreview({
    discovery,
    responseFixture,
    responseFixtureBytes,
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
