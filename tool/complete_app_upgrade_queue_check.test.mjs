import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  readAndValidateUpgradeQueue,
  validateUpgradeQueue,
} from './complete_app_upgrade_queue_check.mjs';

function requiredItem(queue, id) {
  const item = queue.items.find((candidate) => candidate.id === id);
  assert.ok(item, `missing queue item ${id}`);
  return item;
}

test('Encounter preview localization remains a draft pending review', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'settings_full_locale_translation');
  assert.equal(item.status, 'external_dependency');
  assert.match(item.currentGap, /FHIR R4 Encounter diagnostics preview/i);
  assert.match(item.currentGap, /draft UI copy for all 13 shipped language families/i);
  assert.match(item.currentGap, /native-speaker semantic review.*rendered-script checks remain open/i);
  assert.match(item.currentGap, /does not claim translation completion/i);
});

test('committed complete-app queue passes its contract', () => {
  const { queue, failures } = readAndValidateUpgradeQueue();
  assert.deepEqual(failures, []);
  assert.equal(queue.items.length, 175);
  const statusCounts = Object.groupBy(queue.items, (item) => item.status);
  assert.equal(statusCounts.shipped?.length, 45);
  assert.equal(statusCounts.in_progress?.length, 3);
  assert.equal(statusCounts.queued?.length, 55);
  assert.equal(statusCounts.research_required?.length, 66);
  assert.equal(statusCounts.external_dependency?.length, 6);
  assert.ok(queue.items.some((item) => item.status === 'research_required'));
  assert.ok(queue.items.some((item) => item.status === 'external_dependency'));
});

test('medication self-check stays owner-reported and non-clinical', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'medication_list_category_self_check');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P2');
  assert.match(item.currentGap, /time-stamped self-check marks/i);
  assert.match(item.currentGap, /completeness and clinical reconciliation are unknown/i);
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /four owner-selected review categories/i);
  assert.match(acceptance, /schema-v1 through v4 documents load read-only/i);
  assert.match(acceptance, /future marks among excluded future records/i);
  assert.match(acceptance, /do not prove a complete or accurate list or clinician reconciliation/i);
});

test('visit observation selection is report-scoped and non-clinical', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'visit_report_owner_selected_observations');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P2');
  assert.match(item.currentGap, /defaults to all recent records/i);
  assert.match(item.currentGap, /unselected records remain stored locally/i);
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /latest 128 owner observations/i);
  assert.match(acceptance, /Selection is transient to one report/i);
  assert.match(acceptance, /disclose the number omitted by selection/i);
  assert.match(acceptance, /Future-dated .* before selection omissions/i);
  assert.match(acceptance, /no rule, algorithm, or recommendation consumes the selection/i);
});

test('catalog version diff progress preserves the open reconciliation boundary', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'catalog_change_reconciliation_center');
  assert.equal(item.status, 'research_required');
  assert.match(item.currentGap, /offline schema-v1 comparator/i);
  assert.match(item.currentGap, /content-addressed diff/i);
  assert.match(item.currentGap, /never maps by name similarity/i);
  assert.match(item.currentGap, /SHA-256 is a content identity, not a signature/i);
  assert.match(item.currentGap, /Data Integrity page now accepts local snapshot\/evidence JSON/i);
  assert.match(item.currentGap, /separate explicit in-memory scan counts potential references across selected active medications and recorded intakes/i);
  assert.match(item.currentGap, /active selections and intake rows do not bind a source catalog release/i);
  assert.match(item.currentGap, /relevant account, active-selection, intake, or catalog identities change/i);
  assert.match(item.currentGap, /potential references, not confirmed affected records/i);
  assert.match(item.currentGap, /separate food-catalog scan counts exact old source-code matches in current FoodItem rows and meal lines/i);
  assert.match(item.currentGap, /FoodItem and meal rows do not bind a catalog release, so these are potential references/i);
  assert.match(item.currentGap, /no saved record changes and no network request/i);
  assert.match(item.currentGap, /no owner-bound confirmation\/rollback transaction/i);
  assert.match(item.currentGap, /no production algorithm abstention wiring/i);
  assert.match(
    item.acceptanceCriteria.join(' '),
    /food-reference scan counts only exact old source-code matches across FoodItem entries and saved meal lines when source system and jurisdiction match.*aggregate counts without IDs, names, or serving quantities.*labels hits potential because meal rows do not bind catalog releases/i,
  );
});

test('RxNorm history preview preserves unresolved medication identity boundaries', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'structured_medication_dose_semantics_ucum_rxnorm_fhir_profile',
  );
  assert.equal(item.status, 'research_required');
  assert.match(item.currentGap, /RxNav history\/status preview/i);
  assert.match(item.currentGap, /remapped RxCUIs stay unselected candidates/i);
  assert.match(item.currentGap, /no auto-follow, medication substitution/i);
  assert.ok(
    item.acceptanceCriteria.some((criterion) =>
      /replacement RxCUIs remain unselected candidates/.test(criterion),
    ),
  );
});


test('synthetic CDS Hooks v2 contract remains bounded to information-only engineering evidence', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_cds_hooks_information_card_contract',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 28);
  assert.deepEqual(item.dependencies, ['open_source_pattern_license_firewall']);
  assert.match(item.currentGap, /fixed service-discovery validators/i);
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /exactly one patient-view service with the fixed ID/i);
  assert.match(acceptance, /prefetch templates, and network endpoint fields fail closed/i);
  assert.match(acceptance, /no service endpoint is resolved or invoked and no network request is made/i);
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    criterion.includes('never implies clinical validity'),
  ));
});

test('synthetic multi-service CDS Hooks dispatch planning stays offline and hook-scoped', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_cds_hooks_multi_service_dispatch_plan');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P2');
  assert.deepEqual(item.dependencies, ['synthetic_cds_hooks_information_card_contract']);
  assert.ok(item.evidenceUrls.includes('https://cds-hooks.hl7.org/STU2/'));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /four synthetic service definitions.*patient-view and order-select/i);
  assert.match(contract, /prefetch templates are fixed metadata.*separate service-scoped prefetch contract/i);
  assert.match(contract, /requested supported hook returns only exact-matching service IDs in registry order/i);
  assert.match(contract, /diagnostics sandbox previews the immutable registry through a hook selector/i);
  assert.match(contract, /bilingual, hook-scoped preview.*switching hooks removes non-matching services/i);
  assert.match(contract, /zero endpoint invocations.*zero network requests/i);
  assert.match(contract, /does not establish CDS Hooks conformance.*clinical validity/i);
});

test('synthetic CDS Hooks prefetch groups preserve per-service key scope', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_cds_hooks_prefetch_scope_plan');
  assert.equal(item.status, 'shipped');
  assert.deepEqual(item.dependencies, ['synthetic_cds_hooks_multi_service_dispatch_plan']);
  assert.ok(item.evidenceUrls.includes('https://cds-hooks.hl7.org/STU2/'));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /groups only byte-identical templates from services registered to that hook/i);
  assert.match(contract, /records every service's own prefetch key without cross-hook grouping/i);
  assert.match(contract, /zero FHIR queries.*zero network requests.*zero endpoint invocations/i);
  assert.match(contract, /does not establish general FHIR search validity.*CDS Hooks conformance/i);
});

test('synthetic CDS Hooks context preview binds only the fixed FHIR R4 id', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_cds_hooks_prefetch_fixed_context_preview',
  );
  assert.equal(item.status, 'shipped');
  assert.deepEqual(item.dependencies, ['synthetic_cds_hooks_prefetch_scope_plan']);
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/datatypes.html'));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /fixed code-owned synthetic-patient-001 value/i);
  assert.match(contract, /ASCII letters, digits, dot, and hyphen.*length 1 through 64/i);
  assert.match(contract, /no caller-supplied or saved-record identifier/i);
  assert.match(contract, /relative paths for both supported hooks/i);
  assert.match(contract, /zero endpoint invocations, zero FHIR queries, zero network requests/i);
  assert.match(contract, /does not establish arbitrary FHIR query validity.*CDS Hooks conformance/i);
});

test('synthetic CDS Hooks key-path bindings remain service-scoped', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_cds_hooks_prefetch_service_key_binding',
  );
  assert.equal(item.status, 'shipped');
  assert.deepEqual(item.dependencies, [
    'synthetic_cds_hooks_prefetch_fixed_context_preview',
  ]);
  assert.ok(item.evidenceUrls.includes('https://cds-hooks.hl7.org/STU2/'));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /each matching service's own prefetch keys to the approved relative paths/i);
  assert.match(contract, /without transferring keys between services/i);
  assert.match(contract, /two service plans and four key bindings per hook/i);
  assert.match(contract, /no FHIR resource value, request payload, authorization token/i);
  assert.match(contract, /does not establish runtime data isolation, authorization.*CDS Hooks conformance/i);
});

test('synthetic CDS Hooks prefetch payload preview stays minimal and fixture-only', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_cds_hooks_prefetch_payload_fixture_preview',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 21);
  assert.deepEqual(item.dependencies, [
    'synthetic_cds_hooks_prefetch_service_key_binding',
  ]);
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/patient.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/bundle.html'));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /minimal fixed-id Patient.*empty Condition searchset Bundle/i);
  assert.match(contract, /only resourceType and id/i);
  assert.match(contract, /only the requesting service's declared keys/i);
  assert.match(contract, /zero network requests, zero FHIR queries, zero endpoint calls/i);
  assert.match(contract, /empty Condition result is explicitly not a clinical conclusion/i);
});

test('synthetic CDS Hooks request envelope preview preserves hook context and service scope', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_cds_hooks_request_envelope_preview',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 21);
  assert.deepEqual(item.dependencies, [
    'synthetic_cds_hooks_prefetch_payload_fixture_preview',
  ]);
  assert.ok(item.evidenceUrls.includes('https://cds-hooks.hl7.org/STU2/'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/servicerequest.html'));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /exactly hook, hookInstance, context, and prefetch/i);
  assert.match(contract, /patient-view context contains required userId.*order-select additionally contains required selections and draftOrders/i);
  assert.match(contract, /code-free synthetic FHIR R4 ServiceRequest placeholder/i);
  assert.match(contract, /fixed display placeholders, not fresh runtime identifiers/i);
  assert.match(contract, /no fhirServer, authorization, endpoint call, FHIR query/i);
  assert.match(contract, /does not claim full CDS Hooks or FHIR conformance/i);
});

test('synthetic CDS Hooks prefetch outcome semantics keep missingness states distinct', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_cds_hooks_prefetch_missingness_semantics',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 21);
  assert.deepEqual(item.dependencies, [
    'synthetic_cds_hooks_request_envelope_preview',
  ]);
  assert.ok(item.evidenceUrls.includes('https://cds-hooks.hl7.org/STU2/'));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /populated resource, known-empty searchset, explicit null, and omitted key/i);
  assert.match(contract, /null is present in the prefetch map while an omitted key is absent/i);
  assert.match(contract, /empty searchset means a satisfied query with zero matches/i);
  assert.match(contract, /issues no network or FHIR query, reads no patient data/i);
});

test('synthetic rule-suite checkpoints replay and verify before resuming', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_rule_suite_portable_pause_resume_checkpoint',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 21);
  assert.deepEqual(item.dependencies, []);
  assert.ok(item.evidenceUrls.includes('https://medal-suite.com/'));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /exact suite digest.*selected rule-pack identity.*execution mode/i);
  assert.match(contract, /replays and verifies that prefix before continuing/i);
  assert.match(contract, /pauses only after a case completes/i);
  assert.match(contract, /no case inputs or full reports/i);
  assert.match(contract, /no automatic durable storage.*patient-record read.*rule activation/i);
  assert.match(contract, /no medAL code, rule content, or case data is copied/i);
});

test('synthetic CDS Hooks response previews remain service-scoped', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_cds_hooks_multi_service_response_preview',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 21);
  assert.deepEqual(item.dependencies, [
    'synthetic_cds_hooks_information_card_contract',
    'synthetic_cds_hooks_multi_service_dispatch_plan',
  ]);
  assert.ok(item.evidenceUrls.includes('https://cds-hooks.hl7.org/STU2/'));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /exactly one response for every registered fixed service/i);
  assert.match(contract, /information_only response contains exactly one fixed.*indicator=info card/i);
  assert.match(contract, /no_guidance contains exactly cards: \[\]/i);
  assert.match(contract, /filters previews by selected hook.*does not aggregate cards across services/i);
  assert.match(contract, /zero endpoint calls, network requests, and patient-data reads/i);
  assert.match(contract, /no patient data, clinical conclusion.*rule activation/i);
});

test('synthetic CDS Hooks protocol replay keeps definitions, instances, and event prefixes separate', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_cds_hooks_protocol_enactment_replay',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P2');
  assert.equal(item.score, 21);
  assert.deepEqual(item.dependencies, [
    'synthetic_cds_hooks_multi_service_response_preview',
    'synthetic_cds_hooks_request_envelope_preview',
  ]);
  assert.ok(item.evidenceUrls.includes(
    'https://gitlab.com/openclinical/proformajs/-/tree/642e8559ab67cfdc11ef156b96f4af13bbc62548',
  ));
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  assert.match(contract, /versioned protocol definition.*separate.*enactment/i);
  assert.match(contract, /event sequence is deterministic.*service matched.*response previewed/i);
  assert.match(contract, /rebuilds an immutable event prefix.*next event/i);
  assert.match(contract, /no network request.*reads no patient data.*writes no persistent state/i);
});

test('local evidence-source BM25 search stays metadata-only and non-authoritative', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'local_evidence_source_metadata_bm25_search');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P2');
  assert.equal(item.score, 20);
  assert.ok(
    item.evidenceUrls.includes(
      'https://github.com/ClinicDx/ClinicDx/tree/1e329e903f297942160184dbf484874c33bd5e52',
    ),
  );
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  for (const pattern of [
    /fielded BM25F-style ranker/i,
    /title, organization, source family, document type, jurisdiction, language, and license note/i,
    /excludes raw payloads, external URLs, checksums, and user or Patient records/i,
    /query text is neither persisted, logged, nor sent/i,
    /lexical ordering is not evidence quality or applicability/i,
    /no metadata match does not mean evidence is absent/i,
    /do not alter clinical rules, algorithm inputs, ranking, or recommendation outputs/i,
  ]) {
    assert.match(contract, pattern);
  }
});

test('evidence search links only exact claim-currency identities', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'evidence_source_claim_currency_status_lookup');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P2');
  assert.equal(item.score, 20);
  assert.ok(
    item.dependencies.includes('evidence_currency_retraction_and_sunset_gate'),
  );
  assert.ok(
    item.dependencies.includes('local_evidence_source_metadata_bm25_search'),
  );
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  for (const pattern of [
    /only exact source IDs/i,
    /claim ID, exact source revision, effective status/i,
    /shown as unassessed/i,
    /observed after the requested as-of time resolves to unknown/i,
    /offline and recorded/i,
    /does not alter search ordering, rules, recommendations, or ranking/i,
    /no live refresh or clinical conclusion/i,
  ]) {
    assert.match(contract, pattern);
  }
});

test('local follow-up views filter owner workflow states without clinical ranking', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'local_followup_status_filters');
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 15);
  assert.match(item.title, /categorized feedback/i);
  assert.deepEqual(item.dependencies, ['open_source_pattern_license_firewall']);
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /open, unread\/review-needed, snoozed, and all-prompt views/i);
  assert.match(acceptance, /newest-first chronology/i);
  assert.match(acceptance, /do not represent clinical priority or urgency/i);
  assert.match(acceptance, /no patient alert.*assignment.*notification.*clinician queue/i);
  assert.match(acceptance, /not-applicable and declined are separate owner-selected closed workflow states/i);
  assert.match(acceptance, /does not establish clinical correctness or applicability/i);
  assert.match(acceptance, /dismissed, not-applicable, and declined responses require an owner-selected category/i);
  assert.match(acceptance, /legacy v1\/v2 feedback remains explicitly unclassified/i);
  assert.match(acceptance, /schemas v1 and v2 load and serialize as v3/i);
});

test('personal observation sequence and combined FHIR export are bounded, owner-controlled, and terminology-limited', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'symptom_motor_observation_sequence_and_fhir_r4_export',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 21);
  assert.match(item.title, /combined FHIR R4 collection export/i);
  assert.deepEqual(item.dependencies, []);
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/observation.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/bundle.html'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /at most 12.*stable occurrence-time, recording-time/i);
  assert.match(acceptance, /unknown, and not-measured.*separately/i);
  assert.match(acceptance, /explicitly supplied Patient reference.*UUID fullUrls independent of local record IDs/i);
  assert.match(acceptance, /omits recorder IDs and user-entered free-text notes/i);
  assert.match(acceptance, /do not claim LOINC or SNOMED CT mappings/i);
  assert.match(acceptance, /distinct FHIR dataAbsentReason codes and emit no value/i);
  assert.match(acceptance, /account-owner eligibility.*local preview.*separate explicit user action/i);
  assert.match(acceptance, /six manufactured.*one collection Bundle.*terminology-network lookup disabled/i);
  assert.match(acceptance, /one chronologically ordered Bundle\.collection.*up to 12 blood-pressure and 12 symptom\/motor observations/i);
  assert.match(acceptance, /generated resource IDs align with unique random UUID fullUrls/i);
  assert.match(acceptance, /combined synthetic collection among eleven FHIR R4 core resources/i);
  assert.match(acceptance, /No remote transfer.*clinical-validity claim/i);
});

test('owner-entered medication discussion export stays bounded and report-only', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'owner_reported_medication_statement_fhir_r4_export',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 21);
  assert.deepEqual(item.dependencies, []);
  assert.ok(item.evidenceUrls.includes(
    'https://hl7.org/fhir/R4/medicationstatement.html',
  ));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/bundle.html'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /up to 128 account-owned entries.*FHIR R4 Bundle.type=collection/i);
  assert.match(acceptance, /current.*stopped.*uncertain.*active.*stopped.*unknown/i);
  assert.match(acceptance, /no medication coding, informationSource, or effective-use period/i);
  assert.match(acceptance, /Local item IDs, recorder IDs.*ingredient labels, questions/i);
  assert.match(acceptance, /local JSON preview.*separate explicit clipboard-copy action.*no FHIR persistence/i);
  assert.match(acceptance, /copy-on-request, account-switch and record-change expiry, and no persistence/i);
  assert.match(acceptance, /eleven FHIR R4 core resources.*terminology lookup disabled/i);
  assert.match(acceptance, /may be treated downstream as a Patient medication-use statement/i);
});

test('timeline medication intake export keeps its FHIR R4 report-only boundary', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'timeline_intake_fhir_r4_medication_statement_export',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 24);
  assert.deepEqual(item.dependencies, []);
  assert.ok(item.evidenceUrls.includes(
    'https://hl7.org/fhir/R4/medicationstatement.html',
  ));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /one selected account-scoped timeline intake.*status=unknown/i);
  assert.match(acceptance, /exact UTC only when the stored DateTime retains UTC.*calendar date/i);
  assert.match(acceptance, /original dosageNote text.*structured amount\/unit fields are excluded/i);
  assert.match(acceptance, /copies only after a separate user action.*no FHIR persistence/i);
});

test('timeline meal FHIR R5 preview remains owner-scoped and non-authoritative', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'timeline_meal_fhir_r5_nutrition_intake_preview');
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 24);
  assert.deepEqual(item.dependencies, []);
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/nutritionintake.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/datatypes.html'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /one current-account meal.*status=unknown.*exact manually entered Patient reference/i);
  assert.match(acceptance, /text-only concepts.*positive recorded amount in grams/i);
  assert.match(acceptance, /local times without a retained UTC offset are date-only/i);
  assert.match(acceptance, /copies only after a separate user action.*no persistence, upload, network request, or algorithm use/i);
  assert.match(acceptance, /no official validator or profile conformance is claimed/i);
});

test('synthetic SMART standalone launch preflight stays offline, read-only, and minimum-scope', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'synthetic_smart_standalone_launch_preflight',
  );
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 24);
  assert.deepEqual(item.dependencies, []);
  assert.ok(item.evidenceUrls.includes(
    'https://hl7.org/fhir/smart-app-launch/STU2.2/app-launch.html',
  ));
  assert.ok(item.evidenceUrls.includes('https://www.rfc-editor.org/rfc/rfc6749.html'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /schema-v3 code-owned synthetic fixture.*only example\.org HTTPS endpoints.*FHIR 4\.0\.1/i);
  assert.match(acceptance, /exactly appends \/\.well-known\/smart-configuration.*full FHIR base URL.*without fetching/i);
  assert.match(acceptance, /modeled HTTP 200 application\/json response.*without fetching/i);
  assert.match(acceptance, /Discovery validation requires token_endpoint.*S256 with plain excluded.*when sso-openid-connect/i);
  assert.match(acceptance, /unknown metadata extensions are ignored.*unknown fields in the pinned fixture fail closed/i);
  assert.match(acceptance, /exactly launch\/patient plus patient\/Observation\.rs/i);
  assert.match(acceptance, /authorization_code.*code.*launch-standalone.*client-public.*context-standalone-patient.*permission-patient.*permission-v2.*PKCE S256/i);
  assert.match(acceptance, /fresh 32-byte random values.*omitted from reports.*not persisted/i);
  assert.match(acceptance, /schema-v4 report passes seven in-memory synthetic authorization-response checks.*valid code and denial shapes.*exact callback and state binding/i);
  assert.match(acceptance, /synthetic authorization code, and OAuth error details are omitted/i);
  assert.match(acceptance, /duplicated or mismatched response parameters/i);
  assert.match(acceptance, /zero network requests.*FHIR reads.*FHIR writes/i);
  assert.match(acceptance, /does not establish actual SMART launch interoperability/i);
});

test('real SMART sandbox interoperability remains open after the synthetic preflight', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'fhir_interoperability_sandbox');
  assert.equal(item.status, 'research_required');
  assert.match(item.currentGap, /debug-only diagnostics action.*one explicit, bounded HTTPS GET.*fixed SMART Health IT R4 discovery document/i);
  assert.match(item.currentGap, /no account, Patient, FHIR resource or authorization token/i);
  assert.match(item.currentGap, /offline MedicationStatement preview.*MedicationRequest preview.*Both require declared release, jurisdiction and exact Patient context.*no persistence, network request, dose parse or algorithm call/i);
  assert.match(item.currentGap, /local in-memory FHIR R4 BP Observation preview mapper/i);
  assert.match(item.currentGap, /separate offline FHIR R4 Encounter preview accepts one Encounter or a collection Bundle up to 32 entries and 128 KiB.*source status, Encounter\.class coding fields, and lexical period endpoints.*no terminology lookup, persistence, network request.*or CDSS algorithm call/i);
  assert.match(item.currentGap, /development-only FHIR R4 Encounter status CQL differential.*all nine Encounter\.status values.*absent and foreign-Patient cases.*JavaScript translator\/execution and CQF\/JVM.*case-level Boolean outcomes.*makes no care-setting inference.*never feeds app algorithms/i);
  assert.match(item.currentGap, /EHR launch, consent, patient-context handling, token lifecycle, network FHIR reads/i);
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    /debug-only, explicit user action.*exact SMART Health IT R4.*no query, credentials or redirects/i.test(criterion),
  ));
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    /64 KiB.*application\/json.*validates the token endpoint and any required authorization endpoint on the fixed sandbox host.*without retaining raw URLs/i.test(criterion),
  ));
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    /requires the SMART App Launch 2\.2 grant_types_supported, capabilities and code_challenge_methods_supported arrays.*reports authorization_code grant support and response_types_supported\.code when that recommended array is present.*checks for S256 without plain/i.test(criterion),
  ));
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    /sandbox-only SMART launch uses authorization code with PKCE/i.test(criterion),
  ));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/medicationstatement.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/medicationrequest.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/medicationdispense.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/encounter.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-encounter-status.html'));
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    /offline MedicationStatement preview.*FHIR R4 statement or a collection Bundle.*exact release, jurisdiction, and Patient context.*source-claimed status and lexical time precision.*no persistence, network access, dose parsing, or algorithm use/i.test(criterion),
  ));
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    /separate offline MedicationRequest preview.*request status and intent separately from MedicationStatement.*lexical authoredOn precision.*holds entered-in-error, doNotPerform, unknown and unprojected fields.*no persistence.*does not imply dispensing, administration, use, adherence or prescription validity/i.test(criterion),
  ));
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    /offline FHIR R4 Encounter preview accepts one Encounter or a collection Bundle up to 32 entries and 128 KiB.*preserves source status, class Coding values and lexical period precision.*holds entered-in-error, Patient mismatches.*performs no terminology lookup.*CDSS algorithm call/i.test(criterion),
  ));
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    /development-only FHIR R4 Encounter status retrieval differential covers all nine Encounter\.status values.*absence and foreign-Patient cases.*pinned JavaScript and CQF\/JVM.*case-level Boolean outcomes.*never infers admission or care setting or feeds app algorithms/i.test(criterion),
  ));
  assert.match(
    item.currentGap,
    /separate offline FHIR R4 AllergyIntolerance preview.*keeps clinicalStatus and verificationStatus distinct.*holds entered-in-error, unknown or unprojected fields.*outside all CDSS algorithms/i,
  );
  assert.ok(
    item.evidenceUrls.includes(
      'https://hl7.org/fhir/R4/allergyintolerance.html',
    ),
  );
  assert.ok(
    item.evidenceUrls.includes(
      'https://hl7.org/fhir/R4/valueset-allergyintolerance-clinical.html',
    ),
  );
  assert.ok(
    item.evidenceUrls.includes(
      'https://hl7.org/fhir/R4/valueset-allergyintolerance-verification.html',
    ),
  );
  assert.ok(
    item.acceptanceCriteria.some((criterion) =>
      /offline FHIR R4 AllergyIntolerance preview.*32 entries and 128 KiB.*exact Patient reference.*preserves clinicalStatus separately from verificationStatus.*lexical date precision.*holds entered-in-error.*no terminology lookup.*does not claim.*allergy conclusion/i.test(
        criterion,
      ),
    ),
  );
  assert.match(
    item.currentGap,
    /development-only FHIR R4 AllergyIntolerance CQL differential.*three clinicalStatus and four verificationStatus codes.*entered-in-error invariant.*foreign-Patient filtering.*does not feed app algorithms/i,
  );
  assert.ok(item.acceptanceCriteria.some((criterion) =>
    /development-only FHIR R4 AllergyIntolerance CQL retrieval check.*all three clinicalStatus and four verificationStatus codes.*entered-in-error clinicalStatus constraint.*Google CQL Go and CQF-family JavaScript\/JVM paths/i.test(criterion),
  ));
  assert.match(
    item.currentGap,
    /separate offline FHIR R4 Condition preview.*exact Patient reference.*preserves clinicalStatus separately from verificationStatus.*holds Patient mismatches, invalid constraints and unknown or known-but-unprojected fields.*outside all CDSS algorithms/i,
  );
  assert.match(
    item.currentGap,
    /offline FHIR R4 MedicationAdministration preview accepts one resource or a collection Bundle.*source status, medication coding and lexical effective time.*does not prove an administration/i,
  );
  assert.ok(
    item.evidenceUrls.includes('https://hl7.org/fhir/R4/condition.html'),
  );
  assert.ok(
    item.evidenceUrls.includes(
      'https://hl7.org/fhir/R4/medicationadministration.html',
    ),
  );
  assert.ok(
    item.acceptanceCriteria.some((criterion) =>
      /offline FHIR R4 Condition preview.*32 entries and 128 KiB.*exact Patient reference.*keeps clinicalStatus, verificationStatus and condition codings separate.*preserves lexical dateTime precision.*no persistence, network request.*CDSS algorithm call/i.test(
        criterion,
      ),
    ),
  );
  assert.ok(
    item.acceptanceCriteria.some((criterion) =>
      /offline FHIR R4 MedicationAdministration preview.*32 entries and 128 KiB.*exact Patient reference.*statusReason and lexical effective.*holds entered-in-error.*including dosage.*no terminology lookup, persistence, network request.*CDSS algorithm call/i.test(
        criterion,
      ),
    ),
  );
  assert.match(
    item.currentGap,
    /offline FHIR R4 MedicationDispense preview accepts one resource or a collection Bundle.*quantity, daysSupply.*does not prove pickup, medication use or adherence/i,
  );
  assert.ok(
    item.evidenceUrls.includes(
      'https://hl7.org/fhir/R4/medicationdispense.html',
    ),
  );
  assert.ok(
    item.acceptanceCriteria.some((criterion) =>
      /offline FHIR R4 MedicationDispense preview.*32 entries and 128 KiB.*exact Patient reference.*quantity and daysSupply without conversion.*impossible handover chronology.*including dosageInstruction and medicationReference.*no terminology lookup, persistence, network request.*pickup\/use\/adherence inference.*CDSS algorithm call/i.test(
        criterion,
      ),
    ),
  );
});

test('synthetic CDS Hooks rule projection preserves trace state and provenance', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const contract = requiredItem(
    queue,
    'synthetic_cds_hooks_information_card_contract',
  );
  const projection = requiredItem(
    queue,
    'synthetic_cds_hooks_rule_explanation_projection',
  );
  assert.equal(projection.status, 'shipped');
  assert.deepEqual(projection.dependencies, [contract.id]);
  assert.equal(projection.effort, 2);
  assert.equal(projection.score, 28);
  const acceptance = projection.acceptanceCriteria.join(' ');
  assert.match(acceptance, /rule-pack version.*input digest.*source references/i);
  assert.match(acceptance, /not_matched.*resultState unknown/i);
  assert.match(acceptance, /unrecognized states fail closed/i);
  assert.match(acceptance, /stable unsalted input digest.*not anonymous/i);
  assert.match(acceptance, /diagnostic-only page.*three fixed scenarios/i);
  assert.match(acceptance, /no account or saved health record.*network.*EHR/i);
  assert.match(acceptance, /without network.*production clinical-runtime calls/i);
});

test('synthetic CQL differential card projection preserves three-valued outcomes', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const projection = requiredItem(
    queue,
    'synthetic_cql_differential_information_card_projection',
  );
  assert.equal(projection.status, 'shipped');
  assert.equal(projection.score, 28);
  assert.deepEqual(projection.dependencies, [
    'synthetic_cds_hooks_rule_explanation_projection',
  ]);
  const acceptance = projection.acceptanceCriteria.join(' ');
  assert.match(acceptance, /all nine fixed manufactured cases.*Errors.*Warnings/i);
  assert.match(acceptance, /three information-only cards.*empty cards arrays.*response-level diagnostics/i);
  assert.match(acceptance, /true, false, and unknown.*distinct/i);
  assert.match(acceptance, /unit_unsupported.*CQL unknown/i);
  assert.match(acceptance, /indicator info.*no raw input values/i);
  assert.match(acceptance, /pseudonymous.*only synthetic values/i);
  assert.match(acceptance, /no application-runtime.*remote data access/i);
  assert.match(acceptance, /does not establish clinical correctness/i);
});

test('independent synthetic CQL runtime cross-check stays bounded and attributed', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_independent_cql_runtime_crosscheck');
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 28);
  assert.deepEqual(item.dependencies, [
    'synthetic_cql_differential_information_card_projection',
  ]);
  assert.ok(item.evidenceUrls.includes(
    'https://github.com/cqframework/cql-execution/releases/tag/v3.3.2',
  ));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /cql-execution 3\.3\.2.*all nine/i);
  assert.match(acceptance, /all nine outcomes/i);
  assert.match(acceptance, /partial CQL subset.*JavaScript Number precision/i);
  assert.match(acceptance, /does not independently validate CQL-to-ELM translation/i);
  assert.match(acceptance, /development-only.*no application-runtime path/i);
  assert.match(acceptance, /not general CQL conformance.*clinical correctness/i);
});

test('Google CQL parses authored source as an independent development-only differential path', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_google_cql_runtime_crosscheck');
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 28);
  assert.deepEqual(item.dependencies, ['synthetic_independent_cql_runtime_crosscheck']);
  assert.ok(item.evidenceUrls.includes(
    'https://github.com/google/cql/commit/b9169ccd54a3a8b0ac928aff338b9f7d6a4b163a',
  ));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /all nine.*three-valued Result.*Errors.*Warnings/i);
  assert.match(acceptance, /parses and evaluates the authored CQL source directly/i);
  assert.match(item.currentGap, /four execution paths/i);
  assert.match(item.currentGap, /share one upstream implementation family.*not another independent engine/i);
  assert.match(acceptance, /development-only.*no application-runtime path/i);
  assert.match(acceptance, /experimental partial CQL.*no ELM import\/export/i);
  assert.match(acceptance, /nine-case literal comparison.*separate three-case FHIR probe.*scopes retrieved Conditions to the declared Patient ID/i);
  assert.match(acceptance, /does not establish general CQL conformance.*clinical correctness/i);
});

test('CQF JVM platform parity is pinned, diagnostic-complete, and development-only', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_cqf_cql_jvm_platform_parity_probe');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P1');
  assert.equal(item.score, 28);
  assert.deepEqual(item.dependencies, ['synthetic_google_cql_runtime_crosscheck']);
  assert.ok(item.evidenceUrls.includes(
    'https://central.sonatype.com/artifact/org.cqframework/engine/5.3.0',
  ));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /org\.cqframework:engine 5\.3\.0.*JVM engine.*JVM CQL-to-ELM translator/i);
  assert.match(acceptance, /all nine.*true, false, or unknown outcomes.*Errors\/Warnings/i);
  assert.match(acceptance, /schema-v20 differential report.*per-case JVM outcomes/i);
  assert.match(acceptance, /literal-platform check is development-only.*uses no FHIR model.*application-runtime path/i);
  assert.match(acceptance, /same upstream implementation family.*platform parity only/i);
  assert.match(acceptance, /does not establish.*general CQL conformance.*clinical correctness/i);
});

test('Google CQL FHIR R4 retrieval probe stays synthetic, local, and fixed-scope', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_google_cql_fhir_r4_retrieval_probe');
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 28);
  assert.deepEqual(item.dependencies, ['synthetic_google_cql_runtime_crosscheck']);
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/bundle.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/medicationstatement.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/medicationdispense.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/medicationadministration.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/allergyintolerance.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/condition.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-condition-clinical.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-condition-ver-status.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-allergyintolerance-clinical.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-allergyintolerance-verification.html'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /exactly three FHIR R4\.0\.1 collection Bundles.*Patient context/i);
  assert.match(acceptance, /exists\(\[Condition\]\).*matching synthetic Condition yields true.*foreign-subject Condition cases yield false/i);
  assert.match(acceptance, /fixed three-case Condition corpus.*pinned CQF JavaScript.*Google CQL Go, CQF JavaScript, and CQF JVM.*every expected outcome/i);
  assert.match(acceptance, /Strict validation rejects unknown JSON fields.*non-test Condition terminology/i);
  assert.match(acceptance, /local Bundle retriever with no network.*no real patient data/i);
  assert.match(acceptance, /three-case Condition retrieval probe.*six-case Observation terminology differential.*nine-case literal multi-path comparison/i);
  assert.match(acceptance, /schema-v2 corpus.*six fixed FHIR R4\.0\.1 Patient-context Observation Bundles.*pinned Google CQL Go parser\/interpreter.*in-memory ValueSet.*all six cases/i);
  assert.match(acceptance, /ten-case FHIR R4\.0\.1 MedicationStatement corpus.*all eight status codes.*absent and foreign-subject.*Google CQL Go and CQF-family JavaScript\/JVM paths/i);
  assert.match(acceptance, /separate fixed schema-v1 FHIR R4\.0\.1 Patient-context MedicationRequest corpus.*eight status codes.*eight distinct intent codes.*all expected Boolean outcomes/i);
  assert.match(acceptance, /separate fixed schema-v1 FHIR R4\.0\.1 Patient-context MedicationDispense corpus.*exactly 11 synthetic collection Bundles.*nine status codes.*foreign-subject dispense/i);
  assert.match(acceptance, /MedicationDispense retrieval check compares Google CQL Go, the pinned CQF JavaScript translator\/executor path, and CQF JVM.*drop the foreign-subject resource.*omit resource contents and synthetic identifiers/i);
  assert.match(acceptance, /MedicationAdministration corpus has exactly nine synthetic collection Bundles.*seven status codes.*foreign-subject administration/i);
  assert.match(acceptance, /six-case FHIR R4\.0\.1 Patient-context AllergyIntolerance corpus.*all three clinicalStatus codes.*all four verificationStatus codes.*entered-in-error without clinicalStatus.*all eight Boolean predicates/i);
  assert.match(acceptance, /separate fixed schema-v1 FHIR R4\.0\.1 Patient-context Condition status corpus.*exactly nine collection Bundles.*all six clinicalStatus and six verificationStatus codes.*all thirteen Boolean outcomes/i);
  assert.match(acceptance, /latest integrated report contract is Google CQL Go schema-v13 and composite schema-v20.*Condition status cases cover all six clinicalStatus and six verificationStatus codes.*match every expected Boolean outcome/i);
  assert.match(acceptance, /latest complete cql:diff run \(2026-09-26\).*Google CQL(?: Go)? schema-v13 and composite schema-v20.*status=passed.*nine-case Condition status.*official Gradle task launcher remains unverified/i);
  assert.match(acceptance, /does not establish general CQL or FHIR conformance/i);
});

test('CQF JVM synthetic FHIR retrieval remains pinned to three fixed Patient-context cases', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_cqf_cql_jvm_fhir_r4_retrieval_probe');
  assert.equal(item.status, 'shipped');
  assert.equal(item.score, 28);
  assert.deepEqual(item.dependencies, [
    'synthetic_google_cql_fhir_r4_retrieval_probe',
    'synthetic_cqf_cql_jvm_platform_parity_probe',
  ]);
  assert.ok(item.evidenceUrls.includes(
    'https://central.sonatype.com/artifact/org.cqframework/engine-fhir/5.3.0',
  ));
  assert.ok(item.evidenceUrls.includes(
    'https://central.sonatype.com/artifact/org.cqframework/quick/5.3.0',
  ));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/medicationdispense.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/medicationadministration.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/allergyintolerance.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/condition.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-condition-clinical.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-condition-ver-status.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-allergyintolerance-clinical.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-allergyintolerance-verification.html'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /three exact local synthetic Patient\/Condition fixtures.*Patient-context subject filter/i);
  assert.match(acceptance, /Google CQL and CQF JVM.*all three Condition cases/i);
  assert.match(acceptance, /schema-v20 report.*per-case results and fixture digests only.*all nine expected MedicationAdministration outcomes and all six AllergyIntolerance cases/i);
  assert.match(acceptance, /CQF JVM MedicationDispense task validates the 11 fixed local fixtures.*evaluates each R4 status, absence, and foreign-subject filtering/i);
  assert.match(acceptance, /CQF JVM MedicationAdministration task validates the nine fixed local fixtures.*all seven R4 status values.*foreign-subject filtering/i);
  assert.match(acceptance, /CQF JVM AllergyIntolerance task validates six fixed local FHIR R4 cases.*all three clinicalStatus and four verificationStatus predicates.*entered-in-error.*filters the foreign-Patient resource/i);
  assert.match(acceptance, /CQF JVM task validates nine fixed local FHIR R4 Condition status cases.*all six clinicalStatus and six verificationStatus predicates.*all thirteen expected outcomes/i);
  assert.match(acceptance, /ten exact local synthetic MedicationStatement fixtures.*Patient-context subject filter/i);
  assert.match(acceptance, /rejects changed case identities.*placeholder terminology/i);
  assert.match(acceptance, /does not establish general CQL\/FHIR conformance.*clinical correctness/i);
});

test('FHIR CQL retrieval projects only fixed, parity-checked results to CDS Hooks information cards', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_fhir_cql_retrieval_cds_hooks_projection');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P1');
  assert.equal(item.score, 28);
  assert.deepEqual(item.dependencies, [
    'synthetic_cds_hooks_information_card_contract',
    'synthetic_google_cql_fhir_r4_retrieval_probe',
    'synthetic_cqf_cql_jvm_fhir_r4_retrieval_probe',
    'synthetic_fhir_r4_cql_artifact_binding_probe',
  ]);
  assert.ok(item.evidenceUrls.includes('https://cds-hooks.hl7.org/STU2/'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /exactly the fixed three-case FHIR R4\.0\.1.*only after pinned Google CQL and CQF JVM result and diagnostic parity/i);
  assert.match(acceptance, /one indicator-info card.*foreign-subject cases yield empty cards/i);
  assert.match(acceptance, /Patient IDs, resource IDs, Bundle content.*omitted or rejected/i);
  assert.match(acceptance, /complete schema-v20 report.*MedicationStatement, MedicationRequest, and three-path MedicationDispense, MedicationAdministration, and AllergyIntolerance comparisons/i);
  assert.match(acceptance, /separate schema-v1 six-case FHIR R4 Observation membership projection.*one information-only card.*engine_disagreement/i);
  assert.match(acceptance, /ships only after the complete pinned JavaScript, Google CQL Go, CQF JVM, and integrated schema-v20 CQL report pass together/i);
  assert.match(acceptance, /Condition status outcomes are recorded in a separate fixed synthetic retrieval differential.*not projected into information cards or application algorithms/i);
  assert.match(item.currentGap, /complete pinned cql:diff run passed on 2026-09-26.*Google CQL Go schema-v13 and composite schema-v20.*direct Dart VM execution.*official Gradle task launcher remains unverified/i);
  assert.match(acceptance, /no network.*real patient data.*no clinical recommendation/i);
});

test('FHIR R4 Questionnaire CQL dependencies, output parameters, and data requirements remain versioned and synthetic', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_fhir_r4_cql_artifact_binding_probe');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P1');
  assert.equal(item.score, 28);
  assert.deepEqual(item.dependencies, ['synthetic_google_cql_fhir_r4_retrieval_probe']);
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/us/cql/2.0.0/en/authoring.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/uv/cql/conformance.html'));
  assert.ok(item.evidenceUrls.includes('https://github.com/cqframework/cql-exec-vsac/tree/v2.2.0'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/uv/sdc/STU4/en/OperationDefinition-Questionnaire-populate.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/uv/cpg/StructureDefinition-cpg-computableplandefinition.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/valueset-expression-language.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R4/plandefinition-definitions.html'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /exactly one fixed synthetic PlanDefinition.*one Questionnaire.*one primary Library.*one included Library/i);
  assert.match(acceptance, /PlanDefinition pins the exact primary Library canonical.*two applicability conditions.*text\/cql.*resolve to Boolean top-level definitions/i);
  assert.match(acceptance, /cqf-library canonical.*primary Library.url.*relatedArtifact.*CQL include.*FHIR ModelInfo/i);
  assert.match(acceptance, /primary CQL include name and exact version resolve.*Google CQL evaluates.*include alias.*two fixed Patient-context Boolean existence definitions for Condition and Observation/i);
  assert.match(acceptance, /SDC launchContext identifies Patient.*initialExpression title resolves/i);
  assert.match(acceptance, /each Library's FHIR parameter declares every top-level CQL definition exactly once.*use=out, min=0, max=1 and type=boolean.*parsed evaluation results must be Boolean/i);
  assert.match(acceptance, /each Library's dataRequirement set exactly matches resource type, profile, and Patient subject.*parsed CQL/i);
  assert.match(acceptance, /schema-v8 artifact report.*both resolved PlanDefinition-to-Library conditions.*six resolved output parameters.*four resolved data requirements.*six generated single-condition scenarios.*all nine paired Condition\/Observation states.*conjunction of both Boolean applicability results.*FHIR R4 same-kind AND semantics.*fixture digest/i);
  assert.match(acceptance, /separate pinned JavaScript FHIR R4\.0\.1 retrieval and terminology check.*exactly six fixed synthetic Bundles.*in-memory synthetic CodeService/i);
  assert.match(acceptance, /non-member code.*wrong code system.*Coding\.version mismatch.*version-insensitive code matching/i);
  assert.match(acceptance, /same six strict fixture Bundles.*CQF CQL Code-in-ValueSet.*local version-aware TerminologyProvider.*one intentional JavaScript\/JVM result difference/i);
  assert.match(acceptance, /separate pinned Google CQL Go check.*same six fixed Observation Bundles.*all six cases.*version-aware JVM expectation for five/i);
  assert.match(acceptance, /upstream PatientSource returns a foreign-subject Observation when passed an unscoped Bundle/i);
  assert.match(acceptance, /schema-v3 local SDC populate-operation subset accepts one FHIR Parameters request.*exact versioned Questionnaire by canonical URI, exact Reference, or identical pinned Questionnaire resource.*evaluates exactly its two Boolean initialExpression bindings.*FHIR R4 Parameters response containing an in-progress QuestionnaireResponse.*requires human review/i);
  assert.match(acceptance, /rejects extra parameters, Patient\/subject, context, data.*unresolved or modified Questionnaires.*empty Boolean results stay unanswered/i);
  assert.match(acceptance, /Boolean initialExpression evaluates to an empty result.*remains unanswered.*explicit false remains valueBoolean=false/i);
  assert.match(item.currentGap, /in six synthetic cases.*in-memory synthetic ValueSet membership.*upstream PatientSource does not filter Observation\.subject/i);
  assert.match(item.currentGap, /same six fixed Observation Bundles now run through JavaScript, Google CQL Go, and CQF JVM.*version-aware JVM provider differs only on Coding\.version v2/i);
  assert.match(item.currentGap, /JavaScript cql-execution matcher and pinned Go interpreter both omit Coding\.version.*provider-specific behavior/i);
  assert.match(acceptance, /does not contact a FHIR endpoint.*establish SDC\/FHIR or CQL\/terminology conformance.*clinical correctness.*no application-runtime or release dependency/i);
});

test('FHIR R5 PlanDefinition apply result stays isolated, versioned, and structure-only', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_fhir_r5_cpg_apply_result_contract');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P2');
  assert.equal(item.score, 24);
  assert.deepEqual(item.dependencies, []);
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/plandefinition-operation-apply.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/operations.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/requestorchestration.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/bundle.html'));
  assert.ok(item.evidenceUrls.includes('https://github.com/hapifhir/org.hl7.fhir.core/releases/tag/6.10.4'));
  assert.ok(item.evidenceUrls.includes('https://github.com/reason-healthcare/reason-framework/blob/2e8d91daf360f184e6c98f700031414829c64921/README.md'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /schema-v1.*FHIR R5 5\.0\.0.*one synthetic subject/i);
  assert.match(acceptance, /Parameters resource with exactly one return parameter containing one collection Bundle.*RequestOrchestration.*exact versioned PlanDefinition canonical.*matching subject/i);
  assert.match(acceptance, /fixed unique synthetic fullUrl/i);
  assert.match(acceptance, /zero proposed actions.*zero created or updated resources/i);
  assert.match(acceptance, /mutation tests reject altered schema\/FHIR versions.*canonical.*subject.*transaction metadata/i);
  assert.match(acceptance, /no network.*real patient data.*do not establish general FHIR conformance.*clinical validation/i);
  assert.match(acceptance, /optional .*validator_cli.*6\.10\.4.*pinned SHA.*-version 5\.0\.0.*-tx n\/a/i);
  assert.match(acceptance, /full PlanDefinition Parameters response.*ActivityDefinition direct RequestOrchestration result.*PlanDefinition\/\$data-requirements direct Library/i);
  assert.match(acceptance, /validator CLI itself is not run by the app or default verify gate.*no R5 validator result is claimed until the optional command runs with the pinned JAR and a compatible Java runtime/i);
});

test('FHIR R5 ActivityDefinition apply result is a direct synthetic request resource', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_fhir_r5_activitydefinition_apply_result_contract');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P2');
  assert.equal(item.score, 24);
  assert.deepEqual(item.dependencies, []);
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/activitydefinition-operation-apply.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/valueset-request-resource-types.html'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /one synthetic ActivityDefinition resource parameter.*one fixed synthetic subject Reference/i);
  assert.match(acceptance, /kind=RequestOrchestration from the R5 Request Resource Types value set/i);
  assert.match(acceptance, /one direct RequestOrchestration resource.*exact versioned ActivityDefinition canonical/i);
  assert.match(acceptance, /zero actions and zero created or updated resources/i);
  assert.match(acceptance, /optional checksum-pinned validator command validates this direct result with the complete PlanDefinition Parameters response and PlanDefinition\/\$data-requirements direct Library/i);
  assert.match(acceptance, /no network request, real patient data, CPG engine, or clinical activity/i);
});

test('FHIR R5 PlanDefinition data-requirements result is a direct synthetic module-definition Library', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'synthetic_fhir_r5_plandefinition_data_requirements_contract');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P2');
  assert.equal(item.score, 24);
  assert.deepEqual(item.dependencies, []);
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/operation-plandefinition-data-requirements.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/operations.html'));
  assert.ok(item.evidenceUrls.includes('https://hl7.org/fhir/R5/valueset-library-type.html'));
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /one return Library.*serialized directly.*rejects a Parameters or Bundle wrapper/i);
  assert.match(acceptance, /type Coding.*code=module-definition/i);
  assert.match(acceptance, /versioned source Library.*Boolean output ParameterDefinition.*Observation DataRequirement/i);
  assert.match(acceptance, /no network or real patient data.*PlanDefinition\/\$data-requirements and dependency aggregation were not executed/i);
});

test('local dose-unit mapping slice stays exact, versioned, and bounded', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(queue, 'versioned_local_dose_unit_mapping_contract');
  assert.equal(item.status, 'shipped');
  assert.equal(item.priority, 'P1');
  assert.equal(item.effort, 2);
  assert.equal(item.score, 40);
  assert.deepEqual(item.dependencies, ['algorithm_configuration_identity_digest']);
  const acceptance = item.acceptanceCriteria.join(' ');
  assert.match(acceptance, /source and canonical system URIs.*codes.*displays.*versions/i);
  assert.match(acceptance, /exact, same-dimension conversions.*rational factors/i);
  assert.match(acceptance, /confirmation receipt and portable export/i);
  assert.match(acceptance, /no UCUM.*RxNorm.*INFOODS.*FHIR/i);

  const broader = requiredItem(
    queue,
    'versioned_clinical_nutrition_terminology_firewall',
  );
  assert.equal(broader.status, 'research_required');
  assert.match(broader.currentGap, /one bounded versioned mapping contract/i);
  assert.match(broader.currentGap, /no governed RxCUI/i);
  assert.match(broader.currentGap, /INFOODS release/i);
  assert.match(broader.currentGap, /source-currency identity.*metadata only/i);
  assert.match(broader.currentGap, /2022-10-20 update/i);
  assert.match(broader.currentGap, /no remote page archive, tagname rows, or mappings/i);
});

test('transitive result dependency closure remains conservative and fail closed', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'algorithm_transitive_result_dependency_closure',
  );
  const identity = requiredItem(queue, 'algorithm_configuration_identity_digest');
  assert.equal(item.status, 'research_required');
  assert.equal(item.priority, 'P0');
  assert.equal(item.effort, 5);
  assert.equal(item.score, 10);
  assert.deepEqual(item.dependencies, ['algorithm_atlas_visual_contract']);
  assert.match(
    item.currentGap,
    /schema-v14 Analyzer preview: two consecutive declared full-library runs produced the same canonical report SHA-256/i,
  );
  assert.match(item.currentGap, /3fed4b14668a854a32d61da35efdd76099e80ce0b692a38df4420c2e05488ff2/);
  assert.match(item.currentGap, /1,025 reachable source-unit visits and 2,926 reachable namespace-branch visits/);
  assert.match(item.currentGap, /211 accepted source URIs and 1,025 algorithm-source pairs/);
  assert.match(item.currentGap, /Historical local schema-v13 Analyzer preview/i);
  assert.match(item.currentGap, /Historical local schema-v12 Analyzer preview/i);
  assert.match(item.currentGap, /459\/459 discovered regular Dart source units under lib/);
  assert.match(item.currentGap, /0 part units and 0 part-ownership rows/);
  assert.match(item.currentGap, /rootCallsPart → partCaller → PartLeaf/);
  assert.match(item.currentGap, /749 reachable source-unit visits/);
  assert.match(item.currentGap, /459\/459 discovered regular Dart units under lib/);
  assert.match(item.currentGap, /23,602 algorithm-owned root edges, 128,477 source-local declaration edges and 2,277 AST-preserved namespace branches/);
  assert.match(item.currentGap, /113,908 reachable edges and 24,649 reached declarations summed across roots/);
  assert.match(item.currentGap, /121 components \(139 declaration occurrences\)/);
  assert.match(item.currentGap, /9,104 declaration identities and 24,649 algorithm-declaration pairs/);
  assert.match(item.currentGap, /7,053 reachability-HOLD groups \/ 161,473 occurrences/);
  assert.match(item.currentGap, /closure_complete remains false/);
  assert.match(item.currentGap, /augment ownership and complete namespace semantics remain open/);
  assert.match(item.currentGap, /bounded previews only and do not satisfy complete SCC\/reverse closure/);
  assert.match(
    item.currentGap,
    /schema-v11 baseline recorded stable caller declaration identities/i,
  );
  assert.match(
    item.currentGap,
    /23,501 algorithm-owned root edges and 124,018 source-local declaration edges/,
  );
  assert.match(item.currentGap, /2,228 AST-preserved import\/export branches/);
  assert.match(item.currentGap, /444\/444 discovered regular Dart files under lib/);
  assert.match(item.currentGap, /unique package-URI inventory reconciles/);
  assert.match(item.currentGap, /property reads and writes for resolved fields and accessors/i);
  assert.match(item.currentGap, /resolved binary, compound-assignment, prefix and postfix operator targets/i);
  assert.match(item.currentGap, /indexed reads and writes/i);
  assert.match(item.currentGap, /function, method and constructor tear-off references/i);
  assert.match(item.currentGap, /declared extends, mixin, implements, extension-on and extension-type representation relations/i);
  assert.match(item.currentGap, /runtime type-test, cast and literal references/i);
  assert.match(item.currentGap, /generic type arguments and generic, nested, function and record type-alias shapes retain HOLDs/i);
  assert.match(item.currentGap, /resolved non-generic named aliases emit target edges \(none occur in the production snapshot\)/i);
  assert.match(item.currentGap, /runtime `is`, `as` and type-literal references/i);
  assert.match(item.currentGap, /field initializers, initializing formals, resolved super-constructor targets and constructor redirects/i);
  assert.match(item.currentGap, /implicit or generated constructor bodies retain HOLDs/i);
  assert.match(item.currentGap, /644 root and 6,751 source field-initialization edges/);
  assert.match(item.currentGap, /180 root and 1,240 source super-constructor edges/);
  assert.match(item.currentGap, /21 root plus 132 source implicit\/generated-constructor HOLDs/);
  assert.match(item.currentGap, /unresolved callback invocation HOLDs/i);
  assert.match(item.currentGap, /Dynamic operator targets.*explicit HOLD records/i);
  assert.match(item.currentGap, /63\/63 per-root supported-call reachability summaries/);
  assert.match(item.currentGap, /112,344 reachable edges and 24,471 reached declarations summed across roots/);
  assert.match(item.currentGap, /maximum depth 11/);
  assert.match(item.currentGap, /6,974 blocker groups across 158,798 occurrences/);
  assert.match(item.currentGap, /107,268 possible-polymorphic-target occurrences/);
  assert.match(item.currentGap, /47,923 external-target occurrences/);
  assert.match(item.currentGap, /no deterministic per-root node, edge or depth cap was reached/);
  assert.match(item.currentGap, /391 root unresolved groups \(15,546 occurrences:/);
  assert.match(item.currentGap, /54 generic type-argument holds/i);
  assert.match(item.currentGap, /2,150 source-unresolved groups \(63,351 occurrences, including 25 type-alias-target-shape occurrences\)/);
  assert.match(item.currentGap, /37 source caller identity gaps/);
  assert.match(
    item.currentGap,
    /show\/hide, conditional branches, prefixes, deferred imports and part-of directives/i,
  );
  assert.match(
    item.currentGap,
    /Schema-v13 joins only Analyzer-validated declared part ownership/i,
  );
  assert.match(
    item.currentGap,
    /Schema-v14 recursively visits every accepted in-lib import\/export candidate target/i,
  );
  assert.match(item.currentGap, /augment ownership and complete namespace semantics remain open/i);
  assert.match(item.currentGap, /closure_complete remains false/i);
  assert.match(item.currentGap, /whole primary library rather than an exact callable result sink/i);
  assert.match(item.currentGap, /external-target occurrences that are not traversed/i);
  assert.match(
    item.currentGap,
    /package\.json, generator, runner and focused test-source digests/i,
  );
  assert.ok(fs.existsSync('tool/algorithm_direct_edge_probe.dart'));
  assert.ok(fs.existsSync('tool/run_algorithm_direct_edge_probe.dart'));
  assert.ok(fs.existsSync('test/algorithm_direct_edge_probe_test.dart'));
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /function_value_flow_and_callback_target_closure/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /namespace_edges/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /libSourceSnapshotSha256/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /sourceInventoryReconciled/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /supported_call_reachability/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /supported_call_reverse_ownership/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /cyclic_components/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /reachability_holds/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /budget_exceeded/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /property_read/,
  );
  assert.match(
    fs.readFileSync('tool/algorithm_direct_edge_probe.dart', 'utf8'),
    /property_write/,
  );
  const probeFixture = fs.readFileSync(
    'test/algorithm_direct_edge_probe_test.dart',
    'utf8',
  );
  assert.match(probeFixture, /Holder\.staticValue/);
  assert.match(probeFixture, /topLevelValue/);
  assert.match(probeFixture, /property_read/);
  assert.match(probeFixture, /property_write/);
  assert.match(probeFixture, /class OperatorBox/);
  assert.match(probeFixture, /class CompoundIndexBox/);
  assert.match(probeFixture, /dynamicOperatorRoot/);
  assert.match(probeFixture, /functionValueRoot/);
  assert.match(probeFixture, /CallbackHost/);
  assert.match(probeFixture, /DefaultLeaf\.new/);
  assert.match(probeFixture, /dynamic_operator_target_/);
  assert.equal(
    JSON.parse(fs.readFileSync('package.json', 'utf8')).scripts[
      'algorithm:direct-edge-probe'
    ],
    'dart --packages=.dart_tool/package_config.json tool/run_algorithm_direct_edge_probe.dart',
  );
  assert.deepEqual(identity.dependencies, [
    'mechanistic_model_invariant_and_unit_gate',
    item.id,
  ]);
  assert.ok(item.evidenceUrls.includes('https://pub.dev/packages/analyzer'));
  assert.ok(
    item.evidenceUrls.includes('https://dart.dev/resources/language/spec'),
  );
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  for (const pattern of [
    /result-root manifest/i,
    /logical stable/i,
    /compatibility spike/i,
    /exact-lock pinned/i,
    /each AnalysisContext.*own consistent AnalysisSession/i,
    /ParkinSUM-owned edge and dispatch generator/i,
    /callbacks and tear-offs/i,
    /polymorphic/i,
    /unsupported syntax.*open-world dispatch.*held/i,
    /unresolved edge blocks/i,
    /complete_for_declared_local_scope/i,
    /strongly connected components/i,
    /reverse closure/i,
    /only affected registered algorithm IDs.*canonical graph digest/i,
    /deterministic node, edge and depth budgets/i,
    /wall-clock cancellation.*held operational failure/i,
    /traversal-order/i,
    /tracked HEAD.*dirty diff.*untracked.*Gitignore-classified/i,
    /package_config/i,
    /analysis_options/i,
    /conservative engineering traceability/i,
  ]) {
    assert.match(contract, pattern);
  }

  const research = fs.readFileSync(
    'docs/ALGORITHM_TRANSITIVE_RESULT_DEPENDENCY_CLOSURE_RESEARCH_2026-09-02.md',
    'utf8',
  );
  for (const pattern of [
    /complete_for_declared_local_scope/,
    /schema-v3\s+source-universe probe/i,
    /schema-v4 supported-call reachability preview/i,
    /27,585 reachable call edges.*6,062 (?:reached|reachable)\s+declarations/s,
    /1,587 reachability-hold groups.*45,085 occurrences/s,
    /independent traversal recomputed all 63 per-root reachability summaries\s+with no mismatches/i,
    /schema-v5 property read\/write reachability preview/i,
    /schema-v6 operator and indexed-access reachability preview/i,
    /97,460 reachable edges.*22,199 (?:reached|reachable)\s+declarations/s,
    /5,599 reachability-hold groups.*152,491\s+occurrences/s,
    /schema-v7 function, method, and constructor reference reachability preview/i,
    /schema-v8 declared type-relation reachability preview/i,
    /100,601 reachable\s+edges.*22,301 (?:reached|reachable)\s+declarations/s,
    /6,035 reachability\s+HOLD groups.*155,186\s+occurrences/is,
    /22,348 root edges,\s+114,033 source declaration edges/s,
    /100,681 reachable\s+edges.*22,399 reached declarations/s,
    /6,072 reachability HOLD groups.*155,324 occurrences/s,
    /generic relation arguments produce a HOLD.*type aliases keep an edge to the alias/is,
    /schema-v9 runtime type-test, cast, and type-literal reachability preview/i,
    /102,293 reachable\s+edges.*22,570 reached\s+declarations/s,
    /6,439 reachability\s+HOLD groups.*157,449 occurrences/s,
    /type_test.*type_cast.*type_literal/s,
    /schema-v10 constructor-initializer reachability preview/i,
    /23,501 root edges.*124,018 source\s+declaration edges/s,
    /112,344 reachable\s+edges.*24,471 (?:reached\s+)?declarations/s,
    /6,952\s+reachability\s+HOLD groups.*158,765 occurrences/s,
    /constructor_field_initialization.*super_constructor_call.*constructor_redirection/s,
    /schema-v11 type-alias target preview/i,
    /non-generic alias.*direct named\s+interface target.*type_alias_target/is,
    /3 root and 25\s+source occurrences held for unsupported alias shapes/s,
    /6,974 groups across 158,798 occurrences/s,
    /391 root unresolved groups \(15,546 occurrences\).*2,150\s+source-unresolved groups \(63,351 occurrences\)/s,
    /independent\s+traversal matched all 63 per-root summaries and graph digests/i,
    /closure_complete.{0,5}false/i,
    /444 discovered regular Dart files under `lib\//i,
    /research-discovery links only/,
    /application-owned logical stable root/,
    /ParkinSUM-owned edge and dispatch generator/,
    /unsupported syntax.*open-world dispatch.*held/is,
    /tracked HEAD.*dirty diff.*untracked.*Gitignore-classified/s,
    /Reverse closure exports only the affected registered algorithm IDs.*canonical graph digest/s,
    /wall-clock cancellation is a held\s+operational failure/,
  ]) {
    assert.match(research, pattern);
  }
});

test('legacy heuristic ranker has a bounded retirement and prospective utility contract', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'legacy_heuristic_ranker_retirement_and_prospective_utility_validation',
  );
  assert.equal(item.status, 'research_required');
  assert.equal(item.priority, 'P0');
  assert.equal(item.impact, 5);
  assert.equal(item.risk, 5);
  assert.equal(item.effort, 3);
  assert.equal(item.score, 30);
  assert.deepEqual(item.dependencies, [
    'mechanistic_model_invariant_and_unit_gate',
    'context_of_use_change_requalification_ledger',
    'prospective_clinical_calibration',
    'food_composition_candidate_set_snapshot_and_rank_uncertainty_gate',
  ]);
  assert.ok(
    item.evidenceUrls.includes(
      'https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions',
    ),
  );
  assert.ok(
    item.evidenceUrls.includes('https://pubmed.ncbi.nlm.nih.gov/1736847/'),
  );
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  for (const pattern of [
    /arbitrary weights or thresholds/i,
    /visible bounded ranking points/i,
    /cannot be overridden|non-overridable/i,
    /prespecified external and prospective protocol/i,
    /null and negative findings/i,
    /heterogeneous/i,
    /retirement/i,
    /feature flag/i,
    /rollback/i,
    /heuristic ranking points/i,
    /not a probability/i,
    /medical advice/i,
  ]) {
    assert.match(contract, pattern);
  }
});

test('food composition and candidate-set drift remain a separate rank-uncertainty gate', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'food_composition_candidate_set_snapshot_and_rank_uncertainty_gate',
  );
  assert.equal(item.status, 'research_required');
  assert.equal(item.priority, 'P0');
  assert.equal(item.score, 30);
  assert.match(item.currentGap, /candidate snapshot schema/i);
  assert.match(item.currentGap, /all six local queryTable reads/i);
  assert.match(item.currentGap, /no-WHERE\/no-ORDER-BY/i);
  assert.match(item.currentGap, /sequential rather than transaction-scoped/i);
  assert.match(item.currentGap, /caller API does not expose its original query or filters/i);
  assert.match(item.currentGap, /does not freeze an upstream catalog query or release/i);
  assert.match(item.currentGap, /labels the observation selected for the current legacy point-value projection/i);
  assert.match(item.currentGap, /labels other rows as evidence only/i);
  assert.match(item.currentGap, /without claiming that a nutrient changes rank/i);
  assert.match(item.currentGap, /FDC importer now preserves each supplied exact nutrient amount/i);
  assert.match(item.currentGap, /separate unselected range evidence from finite USDA min\/max/i);
  assert.match(item.currentGap, /data_points=0 does not produce a range/i);
  assert.match(item.currentGap, /standard_error is retained but not converted into a probability interval/i);
  assert.match(item.currentGap, /no live USDA Foundation Foods catalog was imported/i);
  assert.match(item.currentGap, /or establish rank stability/i);
  assert.match(item.currentGap, /baseline recommendation cards now label candidates whose pair order reverses/i);
  assert.match(item.currentGap, /assessment digest equals the candidate snapshot digest/i);
  assert.match(item.currentGap, /do not change the score order or safety gates/i);
  assert.match(item.currentGap, /complete rank stability remains unassessed/i);
  assert.deepEqual(item.dependencies, [
    'algorithm_configuration_identity_digest',
    'versioned_clinical_nutrition_terminology_firewall',
    'unit_aware_mechanistic_event_ledger',
  ]);
  for (const url of [
    'https://www.fda.gov/media/101469/download',
    'https://www.fda.gov/media/154985/download',
    'https://fdc.nal.usda.gov/Foundation_Foods_Documentation/',
    'https://fdc.nal.usda.gov/help/',
    'https://fdc.nal.usda.gov/portal-data/external/dataDictionary',
    'https://www.fao.org/docrep/017/ap805e/ap805e.pdf',
    'https://pubmed.ncbi.nlm.nih.gov/2738591/',
    'https://pubmed.ncbi.nlm.nih.gov/2049250/',
  ]) {
    assert.ok(item.evidenceUrls.includes(url), `missing evidence URL ${url}`);
  }
  const contract = [item.currentGap, ...item.acceptanceCriteria].join(' ');
  for (const pattern of [
    /content-addressed catalog snapshot/i,
    /preparation/i,
    /edible portion/i,
    /true zero/i,
    /below quantification/i,
    /candidate-set digest/i,
    /rank stability/i,
    /candidate swaps/i,
    /held or visibly unordered/i,
    /never invents a probability distribution/i,
    /cannot override applicability, medication, abstention or safety gates/i,
  ]) {
    assert.match(contract, pattern);
  }
});

test('structural uncertainty is observable-matched and identifiability-gated', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'mechanistic_structural_uncertainty_shadow_models',
  );
  const contract = [item.currentGap, ...item.acceptanceCriteria]
    .join(' ')
    .toLowerCase();
  for (const term of [
    'elashoff power-exponential',
    'modified power-exponential',
    'linear-exponential',
    'explicit-lag',
    'double-weibull',
    'observable',
    'identifi',
    'profile-likelihood',
    'held-out',
  ]) {
    assert.ok(contract.includes(term), `missing structural gate: ${term}`);
  }
  assert.deepEqual(item.dependencies, ['unit_aware_mechanistic_event_ledger']);
});

test('gastric information design keeps direct and indirect observables separate', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const schedule = requiredItem(
    queue,
    'gastric_acquisition_schedule_information_design_benchmark',
  );
  const breath = requiredItem(
    queue,
    'gastric_breath_test_measurement_model_identifiability_lane',
  );
  const scheduleContract = [
    schedule.currentGap,
    ...schedule.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'structural identifiability',
    'profile-likelihood',
    'sampling timeline',
    'negative results',
    'two independent implementations',
  ]) {
    assert.match(scheduleContract, new RegExp(term, 'i'));
  }
  assert.ok(
    schedule.dependencies.includes(
      'gastric_modality_specific_calibration_identifiability_benchmark',
    ),
  );
  const breathContract = [breath.currentGap, ...breath.acceptanceCriteria].join(
    ' ',
  );
  for (const term of [
    'direct normalized retention',
    'intestinal absorption',
    'metabolism',
    'breath-excretion',
    'typed held state',
    'cannot affect score, rank, copy',
  ]) {
    assert.match(breathContract, new RegExp(term, 'i'));
  }
  assert.ok(
    breath.dependencies.includes(
      'gastric_acquisition_schedule_information_design_benchmark',
    ),
  );
});

test('complete-model queue preserves provenance, event, and dataset lineage', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const config = requiredItem(queue, 'algorithm_configuration_identity_digest');
  const changeImpact = requiredItem(
    queue,
    'algorithm_configuration_change_impact_and_requalification_matrix',
  );
  const ledger = requiredItem(queue, 'unit_aware_mechanistic_event_ledger');
  const losslessReplay = requiredItem(
    queue,
    'lossless_mechanistic_replay_schema_and_cross_platform_conformance',
  );
  const replayMigration = requiredItem(
    queue,
    'mechanistic_replay_schema_migration_and_differential_fuzz_corpus',
  );
  const governance = requiredItem(queue, 'calibration_dataset_governance');
  const calibration = requiredItem(queue, 'prospective_clinical_calibration');

  const configContract = config.acceptanceCriteria.join(' ').toLowerCase();
  for (const term of [
    'structure/formula id',
    'canonical unit',
    'literature-derived',
    'calibration-dataset',
    'configuration digest',
  ]) {
    assert.ok(configContract.includes(term), `missing provenance gate: ${term}`);
  }
  assert.match(config.currentGap, /algorithm-configuration schema v6/i);
  assert.match(config.currentGap, /119 deterministic parameter\/provenance records/i);
  assert.match(config.currentGap, /sixteen algorithms have at least one explicit field\/provider record/i);
  assert.match(config.currentGap, /47 truthfully remain source-bundle-only/i);
  assert.match(config.currentGap, /dose-expression parser has one explicit prototype-heuristic record/i);
  assert.match(config.currentGap, /protein_trend provider.*aggregation contract/i);
  assert.match(
    config.currentGap,
    /Gastric emptying and levodopa absorption opportunity each have a fail-closed declared-scope completeness witness/i,
  );
  assert.match(config.currentGap, /61 algorithms lack a reviewed complete-per-field witness/i);
  assert.equal(changeImpact.status, 'shipped');
  assert.equal(changeImpact.priority, 'P0');
  assert.ok(changeImpact.dependencies.includes(config.id));
  assert.ok(
    changeImpact.dependencies.includes(
      'context_of_use_change_requalification_ledger',
    ),
  );
  const impactContract = [
    changeImpact.currentGap,
    ...changeImpact.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'field-to-algorithm',
    'before-and-after',
    'unchanged',
    'calculation-verification',
    'context-of-use requalification',
    'false closure',
  ]) {
    assert.match(impactContract, new RegExp(term, 'i'));
  }
  const baselineRegistry = requiredItem(
    queue,
    'configuration_baseline_registry_and_reviewed_promotion_receipt',
  );
  assert.equal(baselineRegistry.status, 'shipped');
  assert.ok(baselineRegistry.dependencies.includes(changeImpact.id));
  assert.match(
    [baselineRegistry.currentGap, ...baselineRegistry.acceptanceCriteria].join(' '),
    /append-only|atomic|rollback|independent reviewer/i,
  );
  const durableBaselineRegistry = requiredItem(
    queue,
    'configuration_baseline_durable_store_and_transparency_witness',
  );
  assert.equal(durableBaselineRegistry.status, 'research_required');
  assert.ok(durableBaselineRegistry.dependencies.includes(baselineRegistry.id));
  assert.match(
    [
      durableBaselineRegistry.currentGap,
      ...durableBaselineRegistry.acceptanceCriteria,
    ].join(' '),
    /multi-writer|crash-atomic|merkle|consistency proof|witness|split view/i,
  );

  assert.ok(
    ledger.dependencies.includes('algorithm_configuration_identity_digest'),
  );
  assert.ok(
    ledger.dependencies.includes('mechanistic_model_invariant_and_unit_gate'),
  );
  assert.equal(ledger.status, 'queued');
  assert.match(
    ledger.currentGap,
    /explicit Observatory save action.*fixed synthetic replay capsules.*SQLite v11.*Web preferences.*owner-scoped Firestore/i,
  );
  assert.match(
    ledger.currentGap,
    /laboratory\/FHIR and below-quantification\/censored observations are not imported.*optional per-event IANA\/tzdb\/fold evidence is supported only for explicitly resolved owner observations/i,
  );
  assert.match(
    ledger.currentGap,
    /MechanisticObservationEventImporter.*supplemental audit\/replay rows.*hashed event IDs and source-projection digest/i,
  );
  assert.match(
    ledger.currentGap,
    /do not extend the engine-input binding or enter conflict, ranking, or recommendation calculations/i,
  );
  assert.match(ledger.acceptanceCriteria.join(' '), /dose, meal, observation/);
  assert.match(ledger.acceptanceCriteria.join(' '), /canonical ledger digest/);
  assert.equal(losslessReplay.status, 'research_required');
  assert.equal(losslessReplay.score, 20);
  assert.ok(losslessReplay.dependencies.includes(ledger.id));
  assert.match(
    [losslessReplay.currentGap, ...losslessReplay.acceptanceCriteria].join(' '),
    /lossless|cross-runtime|no lossy migration/i,
  );
  assert.equal(replayMigration.status, 'research_required');
  assert.equal(replayMigration.priority, 'P1');
  assert.equal(replayMigration.score, 16);
  assert.ok(replayMigration.dependencies.includes(losslessReplay.id));
  assert.ok(
    replayMigration.dependencies.includes(
      'portable_schema_migration_fixture_registry',
    ),
  );
  assert.match(replayMigration.currentGap, /not claimed as complete RFC 8785/i);
  assert.match(
    replayMigration.acceptanceCriteria.join(' '),
    /duplicate object members/i,
  );
  assert.match(
    replayMigration.acceptanceCriteria.join(' '),
    /byte, depth, collection, string and execution-time limits/i,
  );
  assert.match(
    replayMigration.acceptanceCriteria.join(' '),
    /engineering replay evidence only/i,
  );

  assert.ok(governance.dependencies.includes('unit_aware_mechanistic_event_ledger'));
  assert.ok(governance.dependencies.includes('server_authoritative_provenance'));
  assert.match(
    governance.acceptanceCriteria.join(' '),
    /subject, site, and time/i,
  );
  assert.match(governance.acceptanceCriteria.join(' '), /raw participant data/);
  assert.ok(calibration.dependencies.includes('calibration_dataset_governance'));
  assert.ok(
    calibration.dependencies.includes(
      'mechanistic_structural_uncertainty_shadow_models',
    ),
  );
  assert.match(calibration.acceptanceCriteria.join(' '), /separate claimed layers/);
});

test('prospective credibility planning and execution independence stay separate', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const plan = requiredItem(
    queue,
    'prospective_model_credibility_plan_and_post_study_adequacy_gate',
  );
  const split = requiredItem(
    queue,
    'credibility_evidence_split_attestation_and_leakage_mutation_gate',
  );
  const protocolHistory = requiredItem(
    queue,
    'credibility_protocol_amendment_deviation_and_result_transparency_ledger',
  );
  const replication = requiredItem(
    queue,
    'credibility_blinded_external_replication_capsule_and_discrepancy_adjudication',
  );

  assert.equal(plan.status, 'queued');
  assert.match(plan.currentGap, /2026\.09\.21-v36/);
  assert.match(plan.currentGap, /historical 2026-09-21 checkpoint/);
  assert.match(plan.currentGap, /2026-09-29 mechanical rebind.*2026\.09\.29-v37/);
  assert.match(plan.currentGap, /preserves the original synthetic timestamps, all seven held evidence lanes/);
  assert.match(
    plan.currentGap,
    /918baef0e5864928bcd20b8e8e855280f8fc1a306b956110498f9d7b06997940 at 2026\.09\.21-v41/,
  );
  assert.match(plan.currentGap, /prospective decision is separately blocked/i);
  assert.match(plan.currentGap, /post-study decision is notAssessed/i);
  assert.match(plan.currentGap, /workflow\/provenance\/observation-timeline/);
  assert.match(plan.currentGap, /do not attest review or evidence coverage/);
  assert.ok(split.dependencies.includes('calibration_dataset_governance'));
  assert.equal(split.status, 'queued');
  assert.match(split.currentGap, /2026\.09\.21-v35/);
  assert.match(split.currentGap, /historical 2026-09-21 checkpoint/);
  assert.match(split.currentGap, /2026-09-29 mechanical rebind.*2026\.09\.29-v36/);
  assert.match(split.currentGap, /preserves all original synthetic data, evidence bodies and timestamps/);
  for (const item of [plan, split]) {
    assert.match(item.currentGap, /2026\.09\.29-v52 configuration SHA-256 e75f4fbe20af2cecb6da8e88034ca7a0da4958571a0cecdd8613a3236ceffe05/);
    assert.match(item.currentGap, /promotion remains blocked/);
  }
  assert.match(
    split.currentGap,
    /918baef0e5864928bcd20b8e8e855280f8fc1a306b956110498f9d7b06997940 at 2026\.09\.21-v41/,
  );
  assert.match(
    split.currentGap,
    /be016fe821c47d2ebe55b5d6fd69162bd0272483e8cc761e41fdecae43747da8/,
  );
  assert.ok(
    split.dependencies.includes(
      'prospective_model_credibility_plan_and_post_study_adequacy_gate',
    ),
  );
  const contract = split.acceptanceCriteria.join(' ');
  for (const term of [
    'subject',
    'site',
    'acquisition',
    'time leakage',
    'locked holdout',
    'selective endpoint omission',
  ]) {
    assert.match(contract, new RegExp(term, 'i'));
  }
  assert.ok(
    protocolHistory.dependencies.includes(
      'credibility_evidence_split_attestation_and_leakage_mutation_gate',
    ),
  );
  assert.equal(protocolHistory.status, 'queued');
  assert.match(protocolHistory.currentGap, /schema-v1/);
  assert.match(protocolHistory.currentGap, /eight mutation families/i);
  const historyContract = protocolHistory.acceptanceCriteria.join(' ');
  for (const term of [
    'append-only',
    'predecessor digest',
    'post-result',
    'superseded value',
    'reviewer disagreement',
    'result-visibility timelines',
  ]) {
    assert.match(historyContract, new RegExp(term, 'i'));
  }
  assert.equal(replication.status, 'queued');
  assert.equal(replication.score, 10);
  assert.match(replication.currentGap, /schema-v1/);
  assert.match(replication.currentGap, /eleven mutation families/i);
  assert.ok(
    replication.dependencies.includes(
      'credibility_protocol_amendment_deviation_and_result_transparency_ledger',
    ),
  );
  const replicationContract = replication.acceptanceCriteria.join(' ');
  for (const term of [
    'content-addressed capsule',
    'expected results remain blinded',
    'classifies every discrepancy',
    'same-actor self-replication',
    'separate lanes',
  ]) {
    assert.match(replicationContract, new RegExp(term, 'i'));
  }

  const statistics = requiredItem(
    queue,
    'credibility_statistical_analysis_error_control_and_uncertainty_reporting_gate',
  );
  assert.equal(statistics.status, 'queued');
  assert.equal(statistics.score, 20);
  assert.match(statistics.currentGap, /schema-v1/);
  assert.match(statistics.currentGap, /Twelve mutation families/i);
  assert.ok(
    statistics.dependencies.includes(
      'credibility_blinded_external_replication_capsule_and_discrepancy_adjudication',
    ),
  );
  const statisticsContract = statistics.acceptanceCriteria.join(' ');
  for (const term of [
    'estimand',
    'intercurrent event',
    'multiplicity',
    'confidence interval',
    'sample-size',
    'sensitivity analyses',
    'alpha inflation',
    'selective subgroup',
    'separate lanes',
  ]) {
    assert.match(statisticsContract, new RegExp(term, 'i'));
  }

  const randomization = requiredItem(
    queue,
    'credibility_randomization_allocation_concealment_and_interim_firewall_gate',
  );
  assert.equal(randomization.status, 'queued');
  assert.equal(randomization.score, 10);
  assert.match(randomization.currentGap, /schema-v1/);
  assert.match(randomization.currentGap, /Thirteen mutation families/);
  assert.ok(
    randomization.dependencies.includes(
      'credibility_statistical_analysis_error_control_and_uncertainty_reporting_gate',
    ),
  );
  const randomizationContract = [
    randomization.currentGap,
    ...randomization.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'randomization',
    'allocation concealment',
    'emergency unblinding',
    'interim-review firewall',
    'alpha-spending',
    'separate lanes',
  ]) {
    assert.match(randomizationContract, new RegExp(term, 'i'));
  }

  const adaptiveDesign = requiredItem(
    queue,
    'credibility_adaptive_design_operating_characteristics_simulation_and_decision_rule_calibration_gate',
  );
  assert.equal(adaptiveDesign.status, 'queued');
  assert.equal(adaptiveDesign.score, 10);
  assert.match(adaptiveDesign.currentGap, /schema-v1/);
  assert.match(adaptiveDesign.currentGap, /700,000/);
  assert.match(adaptiveDesign.currentGap, /17 executable adversarial mutation packages/i);
  assert.ok(
    adaptiveDesign.dependencies.includes(
      'credibility_randomization_allocation_concealment_and_interim_firewall_gate',
    ),
  );
  const adaptiveContract = [
    adaptiveDesign.currentGap,
    ...adaptiveDesign.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'operating-characteristics',
    'type-I error',
    'Monte Carlo',
    'misspecification',
    'second implementation',
    'draft',
    'separate lanes',
  ]) {
    assert.match(adaptiveContract, new RegExp(term, 'i'));
  }

  const bayesianDesign = requiredItem(
    queue,
    'credibility_bayesian_prior_borrowing_conflict_robustness_and_posterior_decision_calibration_gate',
  );
  assert.equal(bayesianDesign.status, 'queued');
  assert.equal(bayesianDesign.score, 10);
  assert.ok(
    bayesianDesign.dependencies.includes(
      'credibility_adaptive_design_operating_characteristics_simulation_and_decision_rule_calibration_gate',
    ),
  );
  const bayesianContract = [
    bayesianDesign.currentGap,
    ...bayesianDesign.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'prior provenance',
    'borrowing',
    'prior-data conflict',
    'posterior',
    'frequentist',
    'draft',
    'separate lanes',
  ]) {
    assert.match(bayesianContract, new RegExp(term, 'i'));
  }
  for (const term of ['schema-v1', '400,000', '18 adversarial', 'eight Algorithm Observatory lanes']) {
    assert.match(bayesianDesign.currentGap, new RegExp(term, 'i'));
  }

  const multisourceBayesian = requiredItem(
    queue,
    'bayesian_multisource_transportability_exchangeability_and_prior_predictive_model_criticism_gate',
  );
  assert.equal(multisourceBayesian.status, 'queued');
  assert.equal(multisourceBayesian.score, 10);
  const multisourceContract = [
    multisourceBayesian.currentGap,
    ...multisourceBayesian.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'transportability',
    'exchangeability',
    'prior predictive',
    'negative controls',
    'leave-one-source-out',
    'independently written implementation',
  ]) {
    assert.match(multisourceContract, new RegExp(term, 'i'));
  }

  const causalTransport = requiredItem(
    queue,
    'target_population_causal_transportability_positivity_and_doubly_robust_estimation_gate',
  );
  const transportSensitivity = requiredItem(
    queue,
    'target_transportability_bias_function_global_sensitivity_and_partial_identification_gate',
  );
  const adherenceTransport = requiredItem(
    queue,
    'transportability_trial_participation_adherence_and_treatment_version_sensitivity_gate',
  );
  const relativeEffectTransport = requiredItem(
    queue,
    'relative_effect_measure_transportability_and_multi_treatment_target_gate',
  );
  const clusterTransport = requiredItem(
    queue,
    'cluster_randomized_target_transportability_and_informative_cluster_size_gate',
  );
  const complexSurvey = requiredItem(
    queue,
    'complex_survey_design_calibration_weighted_target_transportability_gate',
  );
  const multiTrial = requiredItem(
    queue,
    'multi_trial_target_transportability_heterogeneity_and_dependency_gate',
  );
  const negativeControls = requiredItem(
    queue,
    'validated_negative_control_and_proximal_bias_diagnostics_gate',
  );
  const crossEngine = requiredItem(
    queue,
    'probabilistic_programming_cross_engine_reproducibility_and_sampler_diagnostics_gate',
  );
  assert.equal(causalTransport.status, 'queued');
  assert.equal(causalTransport.score, 10);
  for (const term of [
    'schema-v1',
    '260 randomized trial',
    '360 outcome-free target',
    '70,000',
    '26 executable mutations',
    'nine separate lanes',
  ]) {
    assert.match(causalTransport.currentGap, new RegExp(term, 'i'));
  }
  for (const item of [
    adherenceTransport,
    relativeEffectTransport,
    clusterTransport,
    complexSurvey,
    multiTrial,
    negativeControls,
    crossEngine,
  ]) {
    assert.equal(item.status, 'research_required');
    assert.equal(item.score, 10);
  }
  assert.equal(transportSensitivity.status, 'queued');
  assert.equal(transportSensitivity.score, 10);
  for (const term of [
    'schema-v1',
    '2,625-point',
    '2,375 admissible',
    '250 explicitly excluded',
    '80,000',
    '30 executable mutations',
    'ten separate lanes',
  ]) {
    assert.match(transportSensitivity.currentGap, new RegExp(term, 'i'));
  }
  assert.match(causalTransport.acceptanceCriteria.join(' '), /positivity/i);
  assert.match(causalTransport.acceptanceCriteria.join(' '), /doubly robust/i);
  assert.match(transportSensitivity.acceptanceCriteria.join(' '), /partial-identification/i);
  assert.match(adherenceTransport.acceptanceCriteria.join(' '), /target adherence/i);
  assert.match(adherenceTransport.acceptanceCriteria.join(' '), /treatment versions/i);
  assert.match(relativeEffectTransport.currentGap, /risk difference/i);
  assert.match(relativeEffectTransport.acceptanceCriteria.join(' '), /risk-ratio/i);
  assert.match(clusterTransport.currentGap, /informative cluster size/i);
  assert.match(clusterTransport.acceptanceCriteria.join(' '), /within-cluster/i);
  assert.match(complexSurvey.acceptanceCriteria.join(' '), /replicate-weight/i);
  assert.match(multiTrial.acceptanceCriteria.join(' '), /leave-one-trial-out/i);
  assert.match(negativeControls.currentGap, /software invariant/i);
  assert.match(negativeControls.acceptanceCriteria.join(' '), /proximal/i);
  assert.match(crossEngine.currentGap, /Stan, PyMC or R/i);
  assert.match(crossEngine.acceptanceCriteria.join(' '), /per chain/i);
});

test('open-source, backend, and device gates retain their hard boundaries', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const license = requiredItem(queue, 'open_source_pattern_license_firewall');
  assert.equal(license.status, 'queued');
  assert.match(
    license.currentGap,
    /schema-v7 inventory adds 14 individually pinned file-level records/i,
  );
  assert.match(
    license.currentGap,
    /do not establish upstream byte equivalence/i,
  );
  assert.match(
    license.currentGap,
    /reserved-font-name resolution.*remain open/i,
  );
  assert.match(
    license.currentGap,
    /opt-in label workbench also literal-matches returned openFDA drug-interaction, contraindication, boxed-warning, and warning fields/i,
  );
  assert.match(license.currentGap, /listing exact fields with a literal match/i);
  assert.ok(
    license.evidenceUrls.includes(
      'https://open.fda.gov/apis/drug/label/searchable-fields/',
    ),
  );
  assert.ok(
    license.evidenceUrls.includes(
      'https://open.fda.gov/apis/drug/label/understanding-the-api-results/',
    ),
  );
  for (const sourceUrl of [
    'https://github.com/rdiazrincon/two-stage_conformal_pd/commit/4f9fbcd537b9bb0592638e843d9ca018fc34e681',
    'https://github.com/rdiazrincon/two-stage_conformal_pd/blob/4f9fbcd537b9bb0592638e843d9ca018fc34e681/README.md',
    'https://github.com/rdiazrincon/two-stage_conformal_pd/blob/4f9fbcd537b9bb0592638e843d9ca018fc34e681/LICENSE.md',
    'https://proceedings.mlr.press/v298/diaz-rincon25a.html',
  ]) {
    assert.ok(license.evidenceUrls.includes(sourceUrl), `missing evidence URL: ${sourceUrl}`);
  }
  for (const sourceUrl of [
    'https://github.com/rdiazrincon/cascade_conformal_pd/commit/840ae293ac05dadb0d13d08c032c7db4bcf4ab21',
    'https://github.com/rdiazrincon/cascade_conformal_pd/blob/840ae293ac05dadb0d13d08c032c7db4bcf4ab21/README.md',
    'https://github.com/rdiazrincon/cascade_conformal_pd/blob/840ae293ac05dadb0d13d08c032c7db4bcf4ab21/LICENSE',
    'https://arxiv.org/abs/2605.20468',
    'https://neuroscience.ufl.edu/2026/07/08/ricardo-diaz-rincon-presents-ai-research-on-parkinsons-care-at-icml-2026/',
  ]) {
    assert.ok(license.evidenceUrls.includes(sourceUrl), `missing evidence URL: ${sourceUrl}`);
  }
  for (const sourceUrl of [
    'https://github.com/AHRQ-CDS/CQL-Testing-Framework/commit/60aae55fbab5cb7ad5aea8039e33148e42653954',
    'https://github.com/AHRQ-CDS/CQL-Testing-Framework/blob/60aae55fbab5cb7ad5aea8039e33148e42653954/README.md',
    'https://github.com/AHRQ-CDS/CQL-Testing-Framework/blob/60aae55fbab5cb7ad5aea8039e33148e42653954/LICENSE',
    'https://github.com/AHRQ-CDS/CQL-Testing-Framework/blob/60aae55fbab5cb7ad5aea8039e33148e42653954/package.json',
  ]) {
    assert.ok(license.evidenceUrls.includes(sourceUrl));
  }
  for (const sourceUrl of [
    'https://github.com/hodanesthtmcvns-stack/jk/commit/11fd6cd52d561c428682866b70b187bcb18e7c40',
    'https://github.com/hodanesthtmcvns-stack/jk/blob/11fd6cd52d561c428682866b70b187bcb18e7c40/README.md',
    'https://github.com/hodanesthtmcvns-stack/jk/blob/11fd6cd52d561c428682866b70b187bcb18e7c40/LICENSE',
  ]) {
    assert.ok(license.evidenceUrls.includes(sourceUrl));
  }
  for (const sourceUrl of [
    'https://github.com/Chesterguan/cliniclaw/commit/fe1378817c730f4de4fa6b4d92f95ed7fc49ce2e',
    'https://github.com/Chesterguan/cliniclaw/blob/fe1378817c730f4de4fa6b4d92f95ed7fc49ce2e/README.md',
    'https://github.com/Chesterguan/cliniclaw/blob/fe1378817c730f4de4fa6b4d92f95ed7fc49ce2e/LICENSE',
    'https://github.com/hungdothanh/Con-GaIT/commit/3101558fa527cc3092cb2f7970a4d3ba78808b2d',
    'https://github.com/hungdothanh/Con-GaIT/blob/3101558fa527cc3092cb2f7970a4d3ba78808b2d/README.md',
    'https://github.com/hungdothanh/Con-GaIT/blob/3101558fa527cc3092cb2f7970a4d3ba78808b2d/LICENSE',
  ]) {
    assert.ok(license.evidenceUrls.includes(sourceUrl));
  }
  for (const sourceUrl of [
    'https://github.com/yuyuan871111/fast_eval_Parkinsonism/commit/5e7b08ecc8495f9c9a69bba7d224fad69f6fbd16',
    'https://github.com/yuyuan871111/fast_eval_Parkinsonism/blob/5e7b08ecc8495f9c9a69bba7d224fad69f6fbd16/README.md',
    'https://github.com/yuyuan871111/fast_eval_Parkinsonism/tree/5e7b08ecc8495f9c9a69bba7d224fad69f6fbd16/src/lib/hand_predictor/utils/saved_models',
    'https://www.nature.com/articles/s41746-024-01022-x',
  ]) {
    assert.ok(license.evidenceUrls.includes(sourceUrl));
  }
  for (const sourceUrl of [
    'https://github.com/pacharanero/clincalc/commit/6ed6201b7321cca179053907aaa7baacb2659355',
    'https://github.com/pacharanero/clincalc/blob/6ed6201b7321cca179053907aaa7baacb2659355/README.md',
    'https://github.com/pacharanero/clincalc/blob/6ed6201b7321cca179053907aaa7baacb2659355/Cargo.toml',
    'https://github.com/pacharanero/clincalc/blob/6ed6201b7321cca179053907aaa7baacb2659355/LICENSE',
    'https://github.com/pacharanero/clincalc/tree/6ed6201b7321cca179053907aaa7baacb2659355/src/calculators',
  ]) {
    assert.ok(license.evidenceUrls.includes(sourceUrl));
  }
  for (const sourceUrl of [
    'https://github.com/EPFLiGHT/FullyOpenMeditron/commit/65d23a58df15cffdc151fd366083cbe4e49615be',
    'https://github.com/EPFLiGHT/FullyOpenMeditron/blob/65d23a58df15cffdc151fd366083cbe4e49615be/readme.md',
    'https://github.com/EPFLiGHT/FullyOpenMeditron/blob/65d23a58df15cffdc151fd366083cbe4e49615be/LICENSE',
    'https://github.com/EPFLiGHT/FullyOpenMeditron/tree/65d23a58df15cffdc151fd366083cbe4e49615be/data/decontaminated_synthetic_moove',
    'https://github.com/EPFLiGHT/FullyOpenMeditron/blob/65d23a58df15cffdc151fd366083cbe4e49615be/readme.md#models',
  ]) {
    assert.ok(license.evidenceUrls.includes(sourceUrl));
  }
  for (const sourceUrl of [
    'https://github.com/dromlakhani/MD2SKILL/commit/1e539eba7bff01b3a0a9abd3bd314398b42d2b89',
    'https://github.com/dromlakhani/MD2SKILL/blob/1e539eba7bff01b3a0a9abd3bd314398b42d2b89/README.md',
    'https://github.com/dromlakhani/MD2SKILL/tree/1e539eba7bff01b3a0a9abd3bd314398b42d2b89/skills',
  ]) {
    assert.ok(license.evidenceUrls.includes(sourceUrl));
  }
  const licenseContract = [license.currentGap, ...license.acceptanceCriteria].join(
    ' ',
  );
  for (const term of ['GPL-2.0', 'GPL-3.0', 'MIT', 'SPDX', 'SBOM']) {
    assert.ok(licenseContract.includes(term), `missing license gate: ${term}`);
  }
  assert.equal(license.status, 'queued');
  assert.match(license.currentGap, /99 pinned repositories \(96 GitHub, two Bitbucket, and one GitLab\)/);
  assert.match(license.currentGap, /Microsoft Azure Healthcare Digital Quality CQL SDK is pinned at c2f1335543d0e385104a42e028fc10141b729a9f as an MIT concept-only execution-engine reference/i);
  assert.match(license.currentGap, /schema-v7 offline multi-host/);
  assert.match(license.currentGap, /Sixty asset-category records across 38 repositories.*font.*OFL-1\.1.*reserved-font-name resolution remains open/i);
  assert.match(license.acceptanceCriteria[0], /clinical-rule, model, data, font, report, and terminology assets/i);
  assert.match(license.currentGap, /89 entries are concept-only/);
  assert.match(license.currentGap, /15 unresolved repository licenses remain NOASSERTION/);
  assert.match(license.currentGap, /58 clinical-rule, data, model, report, and terminology holds across 36 repositories/i);
  assert.match(license.currentGap, /FastEval Parkinsonism.*video finger-tapping motor-assessment\/workflow reference.*not a validated CDSS/i);
  assert.match(license.currentGap, /saved hand-predictor model assets remain a separate unresolved NOASSERTION hold/i);
  assert.match(license.currentGap, /original videos are not public.*institutional approval.*proposal/i);
  assert.match(license.currentGap, /Fully Open Meditron is pinned at 65d23a58df15cffdc151fd366083cbe4e49615be as an Apache-2\.0.*LLM-CDSS training\/evaluation pipeline reference/i);
  assert.match(license.currentGap, /corpus has a research-use license.*models\/data are not approved for clinical deployment/i);
  assert.match(license.currentGap, /data and model categories remain separate unresolved NOASSERTION holds/i);
  assert.match(license.currentGap, /ClinCalc is pinned at 6ed6201b7321cca179053907aaa7baacb2659355 as a concept-only clinical-calculator-engine architecture reference/i);
  assert.match(license.currentGap, /Cargo\.toml declares AGPL-3\.0-or-later AND LGPL-3\.0-or-later/i);
  assert.match(license.currentGap, /not a finished medical device.*mixed SPDX terms remain NOASSERTION.*calculator assets stay a separate unresolved hold/i);
  assert.match(license.acceptanceCriteria[0], /exactly one separately pinned and reviewed asset-license record/);
  for (const sourcePhrase of [
    'PharmExpert',
    'DDInter data declared CC BY-NC-SA 4.0',
    'OpenMRS DDI knowledge base',
    'Parkinson Helper',
    'DrugInteract',
    'OpenClinical PROformajs',
    'DIKB Evidence Analytics',
    '9ffd629db30c41ced224ff2afdf132ce9276ae3f',
    'GREvaluator',
    '769ad73ae6e715d989c652fed9f8bd9b66206cf4',
    'CAREPATH CDS Specifications',
    '82839d8ef5f3d23306beaf072790cb08a379e4fa',
    '65 service JSON definitions, 13 Excel specifications, and 349 Mustache cards',
    'guideline-derived clinical assets remain a separate unresolved NOASSERTION hold',
    '2025 two-stage conformal Parkinson medication paper',
    '4f9fbcd537b9bb0592638e843d9ca018fc34e681',
    'MLHC/PMLR',
    'CASCADE Conformal Prediction',
    '840ae293ac05dadb0d13d08c032c7db4bcf4ab21',
    'BSD-3-Clause-Clear',
    'AHRQ CQL Testing Framework',
    'PRANA acute-care and anesthesia tool suite',
    '11fd6cd52d561c428682866b70b187bcb18e7c40',
    'Embedded score and clinical-rule content remains a separate unresolved NOASSERTION asset hold',
    '60aae55fbab5cb7ad5aea8039e33148e42653954',
    'three separate unresolved NOASSERTION asset holds',
    'five lookup states',
    'preserving each source field name',
    'no root LICENSE',
    'Da Vinci br-provider and br-payer',
    'LangCare MCP FHIR',
    'd3651b3c8cb940be47c5f376255dded4035a14b8',
    'skills remain a separate unresolved NOASSERTION clinical-rule asset hold',
    'MD2SKILL is pinned at',
    '1e539eba7bff01b3a0a9abd3bd314398b42d2b89',
    'README advertises 888 skills across 11 specialties and claims MIT',
    'pinned public root listing has no separate LICENSE file',
    'not confirmed open-source software',
    'unresolved clinical-rule asset hold',
    'ClinicDx',
    'SPICE 2.0 server',
    'ClinicClaw',
    'fe1378817c730f4de4fa6b4d92f95ed7fc49ce2e',
    'README labels v0.1.0 a research/demo',
    'auth is dev-mode passthrough',
    'not to deploy with real patient data',
    'self-reported benchmark metrics that were not independently verified',
    'Clinical-policy and Synthea FHIR data assets remain separate unresolved NOASSERTION holds',
    'ConGaIT',
    '3101558fa527cc3092cb2f7970a4d3ba78808b2d',
    'proof-of-concept Parkinson gait contestability reference',
    'clinical-decision logic, dataset, model weights, and figures remain separate unresolved NOASSERTION holds',
    'FastEval Parkinsonism is pinned at',
    '5e7b08ecc8495f9c9a69bba7d224fad69f6fbd16',
    'video finger-tapping motor-assessment/workflow reference, not a validated CDSS',
    'saved hand-predictor model assets remain a separate unresolved NOASSERTION hold',
    'README says tests are not implemented',
    'original videos are not public',
    'Fully Open Meditron is pinned at',
    '65d23a58df15cffdc151fd366083cbe4e49615be',
    'ClinCalc is pinned at',
    '6ed6201b7321cca179053907aaa7baacb2659355',
    'not a finished medical device',
    'AGPL-3.0-or-later AND LGPL-3.0-or-later',
    'mixed SPDX terms remain NOASSERTION',
    'No code, score, test vector, or clinical content was copied or executed',
    'LLM-CDSS training/evaluation pipeline reference',
    'corpus has a research-use license',
    'models/data are not approved for clinical deployment',
    'data and model categories remain separate unresolved NOASSERTION holds',
    'citation section is TODO',
    '1e329e903f297942160184dbf484874c33bd5e52',
    'bdc06bbdd855aa65f0692df9218eeb0102bf74b5',
    'parameterized PostgreSQL SQL over FHIR R4 JSONB',
    'measure examples, test fixtures, and terminology retained as three unresolved NOASSERTION asset holds',
    'no local installation or execution',
  ]) {
    assert.ok(
      license.currentGap.includes(sourcePhrase),
      `missing reviewed CDSS source: ${sourcePhrase}`,
    );
  }
  assert.match(license.currentGap, /share_plus 13\.3\.0/);
  assert.match(license.currentGap, /file sharing on Linux/);
  assert.match(license.currentGap, /CQF CQL JVM, cql-execution, cql-exec-fhir, Google CQL, and Google FhirProto Go are five development-linked dependencies/i);
  assert.match(license.currentGap, /CQF cql-exec-vsac v2\.2\.0 is not installed or called.*UMLS API key and network access/i);
  assert.match(license.currentGap, /CQF CQL JVM, cql-execution, cql-exec-fhir, Google CQL, and FhirProto Go are linked only as pinned development test dependencies/i);
  assert.match(license.currentGap, /9c69a12b021ecd97363b14960354fe793a42fe6671648546600fd800168152b0/);
  assert.match(license.currentGap, /280 distinct Android components.*partial\/incomplete/i);
  assert.match(license.currentGap, /Schema v2's.*text-presence scan are superseded.*Schema v3 verifies the CI-pinned Flutter 3\.47\.0 source revision/i);
  assert.match(license.currentGap, /Flutter Web release build into \/private\/tmp\/parkinsum_cdss102_web.*exactly matching the pinned collector reconstruction/i);
  assert.match(license.currentGap, /existing build\/web NOTICE SHA-256 1cbbcbf3cc9a21ad0b9d1dd29552ef1b536bea8703203f4d42a3745d60b94c46 was stale/i);
  assert.match(license.currentGap, /125 runtime Pub packages, 122 with selected collector inputs, and six roots without a selected input/i);
  assert.match(license.currentGap, /Schema v2 of the Android graph exporter records direct and nested license\/notice members.*nested scanning is bounded to depth two/i);
  assert.match(license.currentGap, /synthetic Gradle regression.*direct NOTICE.*nested JAR LICENSE.*depth-two ZIP COPYING.*verifies all three member paths and digests/i);
  assert.match(license.currentGap, /10 direct-member documents in 9 archives; that historical direct-member count did not include nested JAR contents/i);
  assert.match(license.currentGap, /still cannot complete offline because the local cache lacks org\.jetbrains\.kotlin:kotlin-gradle-plugin:2\.2\.0 required by :share_plus/i);
  assert.match(license.currentGap, /release distribution explicitly unauthorized/i);
  assert.match(license.currentGap, /Arden2ByteCode/);
  assert.match(license.currentGap, /openEHR\/gdl-tools/);
  assert.match(license.currentGap, /OpenCDS Core/);
  assert.match(license.currentGap, /OpenTriage/);
  assert.match(license.currentGap, /SRDC SMART CDS example.*concept-only reference for CDS Hooks discovery/i);
  assert.match(license.currentGap, /distinct terms for bundled QRISK3, ADVANCE, ACC\/AHA and SCORE2/i);
  assert.match(license.currentGap, /CDS4CPM/);
  assert.match(license.currentGap, /SNOMED-CT FHIR CDS service/);
  assert.match(license.currentGap, /TRICC/);
  assert.match(license.currentGap, /GenPRES .*Arcwell .*NutriKen .*one-commit food-drug detector/s);
  assert.ok(license.evidenceUrls.includes(
    'https://github.com/fluttercommunity/plus_plugins',
  ));
  assert.match(
    license.acceptanceCriteria.join(' '),
    /development-only dependency.*exact source identity and license review.*explicit denial of release distribution/i,
  );
  assert.ok(license.evidenceUrls.includes(
    'https://github.com/cqframework/cds4cpm/commit/e73c2d2953aaad08f09428a6e70d5a07c5c7db31',
  ));
  assert.ok(license.evidenceUrls.includes(
    'https://github.com/DBCG/cds4cpm-sandbox/commit/9266b4137e47d7a84553b3040dfc2c12e9e6d3f9',
  ));
  assert.ok(license.evidenceUrls.includes(
    'https://github.com/IHTSDO/snomed-fhir-cds-service/commit/be6b5e6a8d636636cdef55310073857c92880574',
  ));
  assert.ok(license.evidenceUrls.includes(
    'https://github.com/SwissTPH/tricc/commit/b8ee6dc4a9f0e89372f59beb6d076684bc070f81',
  ));
  for (const url of [
    'https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/commit/c2f1335543d0e385104a42e028fc10141b729a9f',
    'https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/blob/c2f1335543d0e385104a42e028fc10141b729a9f/LICENSE',
    'https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/blob/c2f1335543d0e385104a42e028fc10141b729a9f/README.md',
    'https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/tree/c2f1335543d0e385104a42e028fc10141b729a9f/measures',
    'https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/tree/c2f1335543d0e385104a42e028fc10141b729a9f/tests/fixtures',
    'https://github.com/microsoft/azure-healthcare-digital-quality-cql-sdk/tree/c2f1335543d0e385104a42e028fc10141b729a9f/src/cql_sdk/postgres',
    'https://github.com/informedica/GenPRES/commit/9ab8234577075808c7a79475058790cbf37f43de',
    'https://github.com/arcweb/arcwell/commit/4be1ed002249b397698e1c588b1bbc81a0c28346',
    'https://github.com/abrangel/Nutriken/commit/5eb45263b5478192f5452c474336f463829ef1ea',
    'https://github.com/nexorin9/food-drug-interaction-detector/commit/c2147d44ae774681042530310a3fdb247ff176fb',
  ]) {
    assert.ok(license.evidenceUrls.includes(url), `missing pinned CDSS evidence URL: ${url}`);
  }
  assert.match(license.currentGap, /Bitbucket provides no detected SPDX result/);
  assert.match(license.currentGap, /NOASSERTION/);
  const upstreamDrift = requiredItem(
    queue,
    'upstream_semantic_license_drift_revalidation',
  );
  assert.ok(
    upstreamDrift.dependencies.includes('open_source_pattern_license_firewall'),
  );
  assert.match(upstreamDrift.acceptanceCriteria.join(' '), /without mutating/);
  assert.match(upstreamDrift.acceptanceCriteria.join(' '), /NOASSERTION/);
  assert.match(upstreamDrift.currentGap, /metadata-only proposal collector/);
  assert.match(upstreamDrift.currentGap, /never requests commit diffs/);
  assert.match(upstreamDrift.currentGap, /schema-v1 review-decision tool/);
  assert.match(upstreamDrift.currentGap, /hash-chained append-only ledger/);
  assert.match(upstreamDrift.currentGap, /every exact influence is accepted/);
  assert.match(upstreamDrift.currentGap, /Hashes do not authenticate reviewers/);
  assert.match(upstreamDrift.currentGap, /no baseline or decision ledger has been committed/);
  assert.equal(upstreamDrift.status, 'research_required');

  const backend = requiredItem(queue, 'registered_first_day_backend_conformance');
  assert.match(backend.acceptanceCriteria.join(' '), /production Auth/);
  assert.match(backend.acceptanceCriteria.join(' '), /without test-only repository/);
  assert.match(backend.acceptanceCriteria.join(' '), /cold new service graph/);

  const notification = requiredItem(
    queue,
    'notification_platform_truth_and_delivery_gate',
  );
  const notificationContract = notification.acceptanceCriteria.join(' ');
  assert.match(notificationContract, /physical-device evidence/);
  assert.match(notificationContract, /pending-request counts alone never/);
  assert.match(notificationContract, /exact-alarm eligibility/);
  assert.match(notificationContract, /daylight-saving transitions/);

  const notificationLocale = requiredItem(
    queue,
    'notification_locale_snapshot_reconciliation',
  );
  assert.ok(
    notificationLocale.dependencies.includes(
      'notification_privacy_content_controls',
    ),
  );
  assert.match(notificationLocale.currentGap, /schema-v4/);
  assert.match(notificationLocale.currentGap, /payload v3/);
  assert.match(notificationLocale.currentGap, /old-language replacement/);
  assert.match(notificationLocale.acceptanceCriteria.join(' '), /copy digest/);
  assert.match(
    notificationLocale.acceptanceCriteria.join(' '),
    /running, backgrounded, and terminated/,
  );

  const notificationPortable = requiredItem(
    queue,
    'notification_presentation_portable_round_trip',
  );
  assert.equal(notificationPortable.status, 'queued');
  assert.ok(
    notificationPortable.dependencies.includes(
      'notification_locale_snapshot_reconciliation',
    ),
  );
  assert.match(notificationPortable.currentGap, /schedules nothing/);
  assert.match(
    notificationPortable.acceptanceCriteria.join(' '),
    /new target-bound activation capability/,
  );
  assert.match(
    notificationPortable.acceptanceCriteria.join(' '),
    /right-to-left text/,
  );
  const portableMigrations = requiredItem(
    queue,
    'portable_schema_migration_fixture_registry',
  );
  assert.equal(portableMigrations.status, 'shipped');
  assert.equal(portableMigrations.score, 24);
  assert.ok(
    portableMigrations.dependencies.includes(
      'notification_presentation_portable_round_trip',
    ),
  );
  assert.match(portableMigrations.currentGap, /immutable URN schema identities/);
  assert.match(portableMigrations.currentGap, /finite and synthetic/);
  assert.match(
    portableMigrations.acceptanceCriteria.join(' '),
    /migration receipt/,
  );
  assert.match(
    portableMigrations.acceptanceCriteria.join(' '),
    /RFC 8785\/JCS/,
  );
  const portableFuzz = requiredItem(
    queue,
    'portable_schema_continuous_differential_fuzz_and_corpus_promotion',
  );
  assert.equal(portableFuzz.status, 'queued');
  assert.equal(portableFuzz.score, 16);
  assert.ok(
    portableFuzz.dependencies.includes(
      'portable_schema_migration_fixture_registry',
    ),
  );
  assert.match(portableFuzz.currentGap, /Dart production-preview and independent Node/);
  assert.match(
    portableFuzz.acceptanceCriteria.join(' '),
    /deterministically minimized/,
  );
  assert.match(
    portableFuzz.acceptanceCriteria.join(' '),
    /user-derived payloads are never uploaded/,
  );
  assert.match(portableFuzz.currentGap, /Forty-seven cases total/);
  assert.match(portableFuzz.currentGap, /not a claim of full-package ready\/corrupt parity/);
  assert.match(portableFuzz.currentGap, /cannot terminate a hung parser/);
  assert.match(portableFuzz.currentGap, /cross-runtime reduction\/promotion remains blocked/);
  assert.match(portableFuzz.currentGap, /release-artifact parsers/);
  const portableMutationAdequacy = requiredItem(
    queue,
    'portable_schema_equivalence_class_coverage_and_semantic_mutation_adequacy',
  );
  assert.equal(portableMutationAdequacy.status, 'research_required');
  assert.equal(portableMutationAdequacy.score, 18);
  assert.ok(portableMutationAdequacy.dependencies.includes(portableFuzz.id));
  assert.match(
    portableMutationAdequacy.acceptanceCriteria.join(' '),
    /equivalent mutants/,
  );
  assert.match(
    portableMutationAdequacy.acceptanceCriteria.join(' '),
    /release-artifact identities/,
  );

  const attestation = requiredItem(
    queue,
    'notification_pending_identity_attestation',
  );
  const scheduleManifest = requiredItem(
    queue,
    'notification_schedule_manifest_preflight',
  );
  assert.equal(scheduleManifest.status, 'queued');
  assert.match(scheduleManifest.currentGap, /same-process install fingerprint/);
  assert.match(scheduleManifest.currentGap, /complete pending identity set still matches/);
  assert.match(scheduleManifest.currentGap, /DST property tests/);
  assert.match(scheduleManifest.currentGap, /target-device partial-failure evidence/);
  assert.equal(attestation.status, 'queued');
  assert.match(attestation.currentGap, /SHA-256 payload digest/);
  assert.match(attestation.currentGap, /platform evidence has not met acceptance/);
  assert.match(attestation.currentGap, /plugin registry rather than independent/);
  assert.match(attestation.currentGap, /visible delivery remain open/);
});

test('next-wave applicability, oracle, terminology, privacy, and durability gates stay linked', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const applicability = requiredItem(
    queue,
    'runtime_model_applicability_abstention_gate',
  );
  const requalification = requiredItem(
    queue,
    'context_of_use_change_requalification_ledger',
  );
  const oracle = requiredItem(queue, 'independent_numerical_verification_oracle');
  const evidenceCurrency = requiredItem(
    queue,
    'evidence_currency_retraction_and_sunset_gate',
  );
  const evidenceSynthesis = requiredItem(
    queue,
    'claim_evidence_contradiction_and_synthesis_adjudication',
  );
  const terminology = requiredItem(
    queue,
    'versioned_clinical_nutrition_terminology_firewall',
  );
  const invariant = requiredItem(
    queue,
    'mechanistic_model_invariant_and_unit_gate',
  );
  const doseGrammar = requiredItem(
    queue,
    'medication_dose_expression_grammar_and_differential_conformance',
  );
  const doseConfirmation = requiredItem(
    queue,
    'administration_dose_confirmation_receipt_and_reconciliation',
  );
  const assertionReconciliation = requiredItem(
    queue,
    'medication_assertion_source_temporal_reconciliation',
  );
  const doseSemantics = requiredItem(
    queue,
    'structured_medication_dose_semantics_ucum_rxnorm_fhir_profile',
  );
  const privacy = requiredItem(queue, 'store_privacy_declaration_drift_gate');
  const durability = requiredItem(
    queue,
    'cross_backend_durable_mutation_protocol',
  );
  const ledger = requiredItem(queue, 'unit_aware_mechanistic_event_ledger');
  const fhir = requiredItem(queue, 'fhir_interoperability_sandbox');
  const offline = requiredItem(queue, 'offline_conflict_awareness');

  assert.match(applicability.acceptanceCriteria.join(' '), /notApplicable/);
  assert.ok(requalification.dependencies.includes(applicability.id));
  assert.equal(requalification.status, 'queued');
  assert.match(requalification.currentGap, /2026-09-29 rebind.*2026\.09\.29-v39/);
  assert.match(requalification.currentGap, /2026\.09\.29-v52/);
  assert.match(
    requalification.currentGap,
    /e75f4fbe20af2cecb6da8e88034ca7a0da4958571a0cecdd8613a3236ceffe05/,
  );
  assert.match(
    requalification.currentGap,
    /8f05e6ff6ad02ace71b621ea840cb795831d63562ebd91b54ae8139ab999dcc2/,
  );
  assert.match(
    requalification.currentGap,
    /Current identity and structural integrity are verified/,
  );
  assert.match(
    requalification.currentGap,
    /four historical identity mismatch findings no longer describe the current ledger/,
  );
  assert.match(
    requalification.currentGap,
    /All five evidence lanes remain held/,
  );
  assert.match(
    requalification.currentGap,
    /3c64c10bc76d1307bf7bdaf16abf8e33b21028929c369cf660cb6296f3f9292c/,
  );
  assert.match(requalification.currentGap, /No append-only transition record/);
  assert.match(
    requalification.currentGap,
    /2026\.09\.21-v41 configuration pin 918baef0e5864928bcd20b8e8e855280f8fc1a306b956110498f9d7b06997940/,
  );
  assert.match(
    requalification.currentGap,
    /be016fe821c47d2ebe55b5d6fd69162bd0272483e8cc761e41fdecae43747da8/,
  );
  assert.match(requalification.currentGap, /blockedPendingEvidence/);
  assert.match(requalification.currentGap, /five required lanes/);
  assert.match(
    requalification.currentGap,
    /does not change a clinical formula or algorithm output/,
  );
  assert.match(requalification.currentGap, /promotion remains blocked/);
  assert.ok(
    requalification.dependencies.includes(
      'algorithm_configuration_identity_digest',
    ),
  );
  assert.ok(
    requalification.dependencies.includes(
      'independent_numerical_verification_oracle',
    ),
  );
  assert.match(
    requalification.acceptanceCriteria.join(' '),
    /calculation verification/,
  );
  assert.match(
    requalification.acceptanceCriteria.join(' '),
    /matching hash/,
  );
  assert.ok(
    evidenceCurrency.dependencies.includes(
      'context_of_use_change_requalification_ledger',
    ),
  );
  assert.equal(evidenceCurrency.status, 'queued');
  assert.match(evidenceCurrency.currentGap, /five reviewed claims/);
  assert.match(evidenceCurrency.currentGap, /all six live mechanistic providers/);
  assert.match(evidenceCurrency.currentGap, /adverse status opens/);
  assert.match(evidenceCurrency.currentGap, /before numerical output/);
  assert.match(
    evidenceCurrency.currentGap,
    /candidate samples share one assessment time/,
  );
  assert.match(
    evidenceCurrency.currentGap,
    /successful results now carry a schema-v1 content-addressed receipt/,
  );
  assert.match(evidenceCurrency.currentGap, /receipt is unsigned/);
  assert.match(
    evidenceCurrency.acceptanceCriteria.join(' '),
    /expression-of-concern/,
  );
  assert.match(
    evidenceCurrency.acceptanceCriteria.join(' '),
    /absence of a notice as scientific validation/,
  );
  assert.equal(evidenceSynthesis.status, 'queued');
  assert.ok(evidenceSynthesis.dependencies.includes(evidenceCurrency.id));
  assert.ok(evidenceSynthesis.dependencies.includes(requalification.id));
  assert.match(evidenceSynthesis.currentGap, /schema-v2 immutable/);
  assert.match(
    evidenceSynthesis.currentGap,
    /all five initial bodies remain held pending independent dual review/,
  );
  assert.match(
    evidenceSynthesis.currentGap,
    /source-referenced synthetic study-dependency edges.*coalesces connected findings into independent families/,
  );
  assert.match(
    evidenceSynthesis.currentGap,
    /independent extraction and dual adjudication/,
  );
  assert.match(
    evidenceSynthesis.acceptanceCriteria.join(' '),
    /citation count or silent averaging/,
  );
  assert.match(
    evidenceSynthesis.acceptanceCriteria.join(' '),
    /null and negative findings/,
  );
  assert.ok(oracle.dependencies.includes(applicability.id));
  assert.match(oracle.acceptanceCriteria.join(' '), /import no production/);
  assert.ok(ledger.dependencies.includes(terminology.id));
  assert.equal(ledger.status, 'queued');
  assert.match(
    ledger.currentGap,
    /explicit Observatory save action.*fixed synthetic replay capsules.*SQLite v11.*Web preferences.*owner-scoped Firestore/i,
  );
  assert.match(
    ledger.currentGap,
    /laboratory\/FHIR and below-quantification\/censored observations are not imported.*optional per-event IANA\/tzdb\/fold evidence is supported only for explicitly resolved owner observations/i,
  );
  assert.ok(fhir.dependencies.includes(terminology.id));
  assert.match(terminology.acceptanceCriteria.join(' '), /UCUM/);
  assert.equal(invariant.status, 'shipped');
  assert.equal(invariant.priority, 'P0');
  assert.equal(invariant.score, 40);
  assert.equal(invariant.acceptanceCriteria.length, 9);
  for (const url of [
    'https://www.bipm.org/en/publications/si-brochure/',
    'https://fdc.nal.usda.gov/Foundation_Foods_Documentation/',
    'https://fdc.nal.usda.gov/GBFPD_Documentation/',
    'https://fdc.nal.usda.gov/api-spec/fdc_api.html',
  ]) {
    assert.ok(invariant.evidenceUrls.includes(url));
  }
  assert.match(invariant.currentGap, /Shipped locally for the declared bounded gate/i);
  assert.match(invariant.currentGap, /23 digest-bound checks/i);
  assert.match(invariant.currentGap, /schema-v2/i);
  assert.match(invariant.currentGap, /relabelled probe cannot manufacture coverage/i);
  assert.match(invariant.currentGap, /22-of-63/i);
  assert.match(invariant.currentGap, /41 not covered/i);
  assert.match(invariant.currentGap, /30-of-63/i);
  assert.match(invariant.currentGap, /33 uncovered/i);
  assert.match(invariant.currentGap, /FDC amino-acid extraction probe/i);
  assert.match(invariant.currentGap, /absent or unknown units/i);
  assert.match(invariant.currentGap, /catalog-candidate projection/i);
  assert.match(invariant.currentGap, /All nine acceptance criteria are satisfied/i);
  assert.match(invariant.currentGap, /implementation and calculation consistency only/i);
  assert.match(
    invariant.acceptanceCriteria.join(' '),
    /only competing-LNAA observation/i,
  );
  assert.match(invariant.currentGap, /14\.999\/15/);
  assert.match(invariant.currentGap, /101\.09-to-100 bound/i);
  assert.match(invariant.currentGap, /stable food-id tie breaking/i);
  assert.equal(doseGrammar.status, 'research_required');
  assert.equal(doseGrammar.score, 30);
  assert.match(doseGrammar.currentGap, /parse-result schema v2 and grammar v4/);
  assert.match(
    doseGrammar.currentGap,
    /34-vector corpus plus 3,584 deterministic adversarial mutations from seed 0x5eedc0de across 28 families/,
  );
  assert.match(
    doseGrammar.currentGap,
    /Unicode Other-category character/,
  );
  assert.match(
    doseGrammar.currentGap,
    /letterlike confusable prefix and suffix/,
  );
  assert.match(
    doseGrammar.currentGap,
    /grammar-v3 confirmation receipt now evaluates as grammar drift/,
  );
  assert.match(
    doseGrammar.currentGap,
    /locale comma and whitespace grouping, Arabic and fullwidth decimal separators/,
  );
  assert.ok(doseGrammar.dependencies.includes(terminology.id));
  assert.ok(
    doseGrammar.dependencies.includes(
      'dimensionally_typed_algorithm_quantity_kernel',
    ),
  );
  assert.ok(doseGrammar.dependencies.includes(applicability.id));
  const doseGrammarContract = [
    doseGrammar.currentGap,
    ...doseGrammar.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'typed AST',
    'product strength',
    'dose range',
    'rate',
    'system',
    'version',
    'UCUM',
    'FDA SPL',
    'differential',
    'Unicode',
    'strength-as-dose',
  ]) {
    assert.match(doseGrammarContract, new RegExp(term, 'i'));
  }
  assert.equal(doseConfirmation.status, 'research_required');
  assert.equal(doseConfirmation.score, 20);
  assert.ok(doseConfirmation.dependencies.includes(doseGrammar.id));
  assert.ok(
    doseConfirmation.dependencies.includes('recoverable_user_event_history'),
  );
  const doseConfirmationContract = [
    doseConfirmation.currentGap,
    ...doseConfirmation.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'raw/structured mismatch',
    'grammar digest',
    'informationSource',
    'Provenance',
    'expected-revision',
    'strength-as-dose',
    'FHIR-conformance',
    'use-error',
  ]) {
    assert.match(doseConfirmationContract, new RegExp(term, 'i'));
  }
  assert.equal(assertionReconciliation.status, 'research_required');
  assert.equal(assertionReconciliation.score, 20);
  assert.ok(assertionReconciliation.dependencies.includes(doseConfirmation.id));
  assert.match(
    assertionReconciliation.currentGap,
    /exposes UTC valid-time and knowledge-time cutoffs.*does not alter the current result gate/i,
  );
  assert.match(
    assertionReconciliation.currentGap,
    /schema-v3 evidence projection.*Schema-v3 binds a conflict graph rebuilt only from cutoff-visible assertions and decisions/i,
  );
  assert.match(
    assertionReconciliation.currentGap,
    /aggregate integrity markers with no independent knowledge timestamp.*marked unresolved at the cutoff.*excluded from the historical graph/i,
  );
  assert.doesNotMatch(
    assertionReconciliation.currentGap,
    /gaps include UI query controls/i,
  );
  assert.doesNotMatch(
    assertionReconciliation.currentGap,
    /full conflict-graph reconstruction at historical cutoffs/i,
  );
  const assertionContract = [
    assertionReconciliation.currentGap,
    ...assertionReconciliation.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'informationSource',
    'effective interval',
    'time precision',
    'not taken',
    'conflict graph',
    'clock skew',
    'retraction',
    'never infers adherence',
    'FHIR conformance',
  ]) {
    assert.match(assertionContract, new RegExp(term, 'i'));
  }
  assert.equal(doseSemantics.status, 'research_required');
  assert.equal(doseSemantics.priority, 'P0');
  assert.equal(doseSemantics.score, 20);
  assert.match(doseSemantics.currentGap, /parkinsum\.fhir-r5-dose-quantity-preview\/2/);
  assert.match(doseSemantics.currentGap, /parkinsum\.fhir-r5-medication-product-preview\/3/);
  assert.match(doseSemantics.currentGap, /exact, confirmed local administration quantity/i);
  assert.match(doseSemantics.currentGap, /four UCUM code identifiers/i);
  assert.match(doseSemantics.currentGap, /resource_or_exchange_eligible=false/);
  assert.match(doseSemantics.currentGap, /creates no Medication resource/i);
  assert.match(
    doseSemantics.currentGap,
    /does not perform independent FHIR R5 validation/i,
  );
  assert.match(doseSemantics.currentGap, /schema-v2 path ledger/i);
  assert.match(
    doseSemantics.currentGap,
    /other forms, concentration denominators, explicit denominator units.*remain local evidence/i,
  );
  assert.match(doseSemantics.currentGap, /dosage form is exactly tablet/i);
  assert.match(doseSemantics.currentGap, /unique exact match to the content-addressed bundled source manifest/i);
  assert.match(
    doseSemantics.currentGap,
    /product ID, SPL ID, ingredient index\/name, parser-result SHA-256 and source-row SHA-256/i,
  );
  assert.match(doseSemantics.currentGap, /does not verify FDA data truth or currentness/i);
  assert.match(doseSemantics.currentGap, /UCUM 2\.2\/license 1\.1/i);
  assert.match(doseSemantics.currentGap, /does not redistribute UCUM tables or parser code/i);
  assert.match(doseSemantics.currentGap, /field dispositions/i);
  assert.match(doseSemantics.currentGap, /not a full SIG/i);
  assert.match(
    doseSemantics.currentGap,
    /parkinsum\.openfda-strength-expression-parse-result\/1/,
  );
  assert.match(
    doseSemantics.currentGap,
    /parkinsum\.openfda-strength-expression-source-manifest\/1/,
  );
  assert.match(
    doseSemantics.currentGap,
    /product NDC, product ID, SPL ID, ingredient index\/name/i,
  );
  assert.match(doseSemantics.currentGap, /213 ingredient rows across 157 records/);
  assert.match(doseSemantics.currentGap, /every result is held/i);
  assert.match(
    doseSemantics.currentGap,
    /CDSS-117 adds a local schema-v1 MedicationPackageDoseDerivation snapshot/i,
  );
  assert.match(
    doseSemantics.currentGap,
    /source system, source URL, retrieval time, exact strength text/i,
  );
  assert.match(
    doseSemantics.currentGap,
    /liquid, volume-denominator, unsupported-form and mismatched-unit cases/i,
  );
  assert.match(
    doseSemantics.currentGap,
    /does not verify the source record or its currentness/i,
  );
  assert.ok(
    doseSemantics.evidenceUrls.includes(
      'https://www.fda.gov/drugs/development-approval-process-drugs/national-drug-code-database-background-information',
    ),
  );
  assert.ok(
    doseSemantics.evidenceUrls.includes(
      'https://www.fda.gov/drugs/electronic-drug-registration-and-listing-system-edrls/strength-conversion-drug-listing',
    ),
  );
  for (const dependency of [
    doseGrammar.id,
    doseConfirmation.id,
    assertionReconciliation.id,
    'dimensionally_typed_algorithm_quantity_kernel',
    terminology.id,
  ]) {
    assert.ok(doseSemantics.dependencies.includes(dependency));
  }
  const semanticContract = [
    doseSemantics.currentGap,
    ...doseSemantics.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'hl7.fhir.core#5.0.0',
    'Dosage.doseAndRate.dose',
    'Medication ingredient.strength',
    'package count',
    'unit',
    'system',
    'code',
    'UCUM',
    'RXCUI',
    'term type',
    'release',
    'concentration',
    'mass-volume',
    'loss',
    'clinical correctness',
  ]) {
    assert.match(semanticContract, new RegExp(term, 'i'));
  }
  assert.match(privacy.acceptanceCriteria.join(' '), /human approval/);
  assert.ok(offline.dependencies.includes(durability.id));
  assert.match(durability.acceptanceCriteria.join(' '), /two-tab/);
});

test('complete-app user ownership queue keeps recovery, handoff, consent, support, and catalog boundaries distinct', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const history = requiredItem(queue, 'recoverable_user_event_history');
  const restoreImpact = requiredItem(
    queue,
    'relationship_aware_restore_impact_preview',
  );
  const historyCheckpoints = requiredItem(
    queue,
    'tamper_evident_user_event_history_checkpoints',
  );
  const handoff = requiredItem(queue, 'personal_log_handoff_summary');
  const portable = requiredItem(queue, 'user_owned_portable_data_package');
  const portableIdentityProjection = requiredItem(
    queue,
    'portable_dose_evidence_privacy_projection',
  );
  const consent = requiredItem(queue, 'purpose_bound_consent_receipts');
  const consentComprehension = requiredItem(
    queue,
    'consent_notice_comprehension_and_localization_gate',
  );
  const support = requiredItem(queue, 'privacy_safe_support_bundle');
  const supportCase = requiredItem(
    queue,
    'user_controlled_support_case_workflow',
  );
  const catalog = requiredItem(queue, 'catalog_change_reconciliation_center');
  const accessibleDocument = requiredItem(
    queue,
    'accessible_searchable_multiscript_document_export',
  );

  assert.ok(
    history.dependencies.includes('cross_backend_durable_mutation_protocol'),
  );
  assert.match(history.acceptanceCriteria.join(' '), /tombstoned records/);
  assert.match(history.currentGap, /never silently overwritten/);
  assert.ok(restoreImpact.dependencies.includes(history.id));
  assert.match(restoreImpact.acceptanceCriteria.join(' '), /recomputed/);
  assert.match(restoreImpact.acceptanceCriteria.join(' '), /stale preview/);
  assert.ok(historyCheckpoints.dependencies.includes(history.id));
  assert.match(historyCheckpoints.acceptanceCriteria.join(' '), /split-view/);
  assert.match(
    historyCheckpoints.acceptanceCriteria.join(' '),
    /do not establish Certificate Transparency conformance/,
  );
  assert.match(handoff.currentGap, /machine-oriented JSON snapshot/);
  assert.match(handoff.currentGap, /PDF is still a raster image/);
  assert.match(handoff.currentGap, /semantic-document schema v1/);
  assert.match(handoff.currentGap, /HTML file sharing through share_plus 13\.3\.0/);
  assert.match(handoff.currentGap, /personal-observations section is off by default/);
  assert.match(handoff.currentGap, /diagnostic thresholds/);
  assert.match(
    handoff.acceptanceCriteria.join(' '),
    /personal observations are a separate opt-in section that is off by default/i,
  );
  assert.match(handoff.acceptanceCriteria.join(' '), /not a medical record/);
  assert.equal(portable.status, 'queued');
  assert.equal(portable.priority, 'P1');
  const portableContract = [
    portable.currentGap,
    ...portable.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'schema-v2',
    'raw and parseable',
    'combined result gate',
    'canonical quantity',
    'medication reconciliation',
    'dose-owner',
    'as-of',
    'unsigned',
    'self-consistency',
    'RFC 8785',
    'never labelled a FHIR Bundle',
    'no-write',
    'v1 migration',
    'last-known-good rollback',
  ]) {
    assert.match(portableContract, new RegExp(term, 'i'));
  }
  assert.ok(portable.dependencies.includes('encrypted_backup_restore_drill'));
  assert.ok(portable.dependencies.includes('offline_conflict_awareness'));
  assert.match(portable.currentGap, /separate package-scoped privacy projection/);
  assert.equal(portableIdentityProjection.status, 'research_required');
  assert.equal(portableIdentityProjection.priority, 'P1');
  assert.equal(portableIdentityProjection.score, 20);
  const projectionContract = [
    portableIdentityProjection.currentGap,
    ...portableIdentityProjection.acceptanceCriteria,
  ].join(' ');
  for (const term of [
    'stable unsalted',
    'low-entropy',
    'dictionary',
    'linked across packages',
    'package-local',
    'keyed',
    'without presenting projected',
    'block durable import or synchronization',
  ]) {
    assert.match(projectionContract, new RegExp(term, 'i'));
  }
  assert.ok(
    portableIdentityProjection.dependencies.includes(
      'administration_dose_confirmation_receipt_and_reconciliation',
    ),
  );
  assert.ok(accessibleDocument.dependencies.includes(handoff.id));
  assert.match(
    accessibleDocument.acceptanceCriteria.join(' '),
    /tagged PDF structure tree/,
  );
  assert.match(
    accessibleDocument.acceptanceCriteria.join(' '),
    /validator pass is never described as clinical/,
  );
  assert.equal(consent.status, 'queued');
  assert.match(consent.acceptanceCriteria.join(' '), /defaults to denied/);
  assert.match(consent.currentGap, /schema-v1 append-style receipt ledger/);
  assert.equal(consentComprehension.status, 'research_required');
  assert.ok(consentComprehension.dependencies.includes(consent.id));
  assert.match(
    consentComprehension.acceptanceCriteria.join(' '),
    /defaults to denied/,
  );
  assert.match(support.acceptanceCriteria.join(' '), /raw exceptions/);
  assert.match(support.currentGap, /Unknown counts remain null/);
  assert.match(support.currentGap, /without an upload path/);
  assert.equal(supportCase.status, 'research_required');
  assert.ok(supportCase.dependencies.includes(support.id));
  assert.ok(supportCase.dependencies.includes(consent.id));
  assert.match(supportCase.acceptanceCriteria.join(' '), /explicitly start and stop/);
  assert.match(supportCase.acceptanceCriteria.join(' '), /never reclassified as machine-safe/);
  assert.match(supportCase.acceptanceCriteria.join(' '), /No destination opens/);
  assert.ok(
    catalog.dependencies.includes(
      'versioned_clinical_nutrition_terminology_firewall',
    ),
  );
  assert.match(catalog.acceptanceCriteria.join(' '), /force affected algorithms to abstain/);
});

test('operations, performance, rollout, and supply-chain gates retain complete-app boundaries', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const observability = requiredItem(
    queue,
    'privacy_preserving_operational_observability',
  );
  const aggregatePrivacy = requiredItem(
    queue,
    'aggregate_privacy_budget_and_small_cohort_suppression',
  );
  const performance = requiredItem(
    queue,
    'cross_platform_performance_energy_budget',
  );
  const rollout = requiredItem(queue, 'signed_capability_rollout_kill_switch');
  const signingRecovery = requiredItem(
    queue,
    'capability_signing_key_transparency_and_compromise_recovery',
  );
  const fleetConsistency = requiredItem(
    queue,
    'capability_fleet_convergence_and_consistency_proof',
  );
  const cacheConformance = requiredItem(
    queue,
    'capability_http_cache_intermediary_conformance_matrix',
  );
  const attestation = requiredItem(
    queue,
    'reproducible_release_sbom_attestation',
  );

  const observabilityContract = observability.acceptanceCriteria.join(' ');
  assert.equal(observability.status, 'queued');
  assert.match(observabilityContract, /defaults to disabled/);
  assert.match(observabilityContract, /stable account hash/);
  assert.match(observability.currentGap, /schema-v1, process-memory-only/);
  assert.match(observability.currentGap, /off-device telemetry remains disabled/);
  assert.match(observability.currentGap, /persisted purpose-specific consent/);
  assert.ok(
    observability.dependencies.includes('purpose_bound_consent_receipts'),
  );
  assert.equal(aggregatePrivacy.status, 'research_required');
  assert.ok(aggregatePrivacy.dependencies.includes(observability.id));
  assert.match(aggregatePrivacy.currentGap, /do not provide statistical privacy/);
  assert.match(aggregatePrivacy.currentGap, /differentially private/);
  assert.match(aggregatePrivacy.acceptanceCriteria.join(' '), /neighboring datasets/);
  assert.match(aggregatePrivacy.acceptanceCriteria.join(' '), /epsilon/);
  assert.match(aggregatePrivacy.acceptanceCriteria.join(' '), /budget-race/);
  assert.match(aggregatePrivacy.acceptanceCriteria.join(' '), /never called differential privacy/);

  const performanceContract = performance.acceptanceCriteria.join(' ');
  assert.match(performanceContract, /physical Android and iOS devices/);
  assert.match(performanceContract, /emulator numbers cannot satisfy/);
  assert.ok(
    performance.dependencies.includes('artifact_level_black_box_journeys'),
  );

  const rolloutContract = rollout.acceptanceCriteria.join(' ');
  assert.equal(rollout.status, 'queued');
  assert.match(rollout.currentGap, /strict schema-v1 global-boolean manifest/);
  assert.match(rollout.currentGap, /no production signer/);
  assert.match(rollout.currentGap, /dedicated cross-origin HTTPS endpoint/);
  assert.match(rollout.currentGap, /schema-v2 activation state/);
  assert.match(rollout.currentGap, /cannot poison conditional requests/);
  assert.match(rollout.currentGap, /cookie-free target audit/);
  assert.match(rollout.currentGap, /existing locally governed Local AI behavior remains outside rollout control/);
  assert.match(rolloutContract, /conservative local default/);
  assert.match(rolloutContract, /cannot remotely alter clinical-algorithm/);
  assert.ok(
    rollout.dependencies.includes('algorithm_configuration_identity_digest'),
  );

  const signingRecoveryContract = signingRecovery.acceptanceCriteria.join(' ');
  assert.equal(signingRecovery.status, 'research_required');
  assert.ok(signingRecovery.dependencies.includes(rollout.id));
  assert.ok(
    signingRecovery.dependencies.includes('reproducible_release_sbom_attestation'),
  );
  assert.match(signingRecovery.currentGap, /split-view detection/);
  assert.match(signingRecoveryContract, /offline recovery root/);
  assert.match(signingRecoveryContract, /compromised-signer drill/);
  assert.match(signingRecoveryContract, /scientific validity/);

  const fleetConsistencyContract = fleetConsistency.acceptanceCriteria.join(' ');
  assert.equal(fleetConsistency.status, 'research_required');
  assert.ok(fleetConsistency.dependencies.includes(rollout.id));
  assert.ok(fleetConsistency.dependencies.includes(signingRecovery.id));
  assert.match(fleetConsistency.currentGap, /multi-region and mirror consistency/);
  assert.match(fleetConsistencyContract, /content-addressed/);
  assert.match(fleetConsistencyContract, /Privacy-safe convergence evidence/);
  assert.match(fleetConsistencyContract, /stale CDN cache/);

  const cacheConformanceContract = cacheConformance.acceptanceCriteria.join(' ');
  assert.equal(cacheConformance.status, 'research_required');
  assert.equal(cacheConformance.score, 27);
  assert.ok(cacheConformance.dependencies.includes(rollout.id));
  assert.ok(cacheConformance.dependencies.includes(fleetConsistency.id));
  assert.match(cacheConformance.currentGap, /service workers/);
  assert.match(cacheConformanceContract, /mutable latest pointer/);
  assert.match(cacheConformanceContract, /matching and mismatching 304/);
  assert.match(cacheConformanceContract, /last verified active manifest unchanged/);

  const attestationContract = attestation.acceptanceCriteria.join(' ');
  assert.match(attestationContract, /CycloneDX or SPDX SBOM/);
  assert.match(attestationContract, /offline verification bundle/);
  assert.match(attestationContract, /never presented as scientific/);
});

test('secret storage, implicit backup, and backend residency remain separate fail-closed contracts', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const secrets = requiredItem(
    queue,
    'device_bound_secret_storage_and_rotation',
  );
  const backup = requiredItem(
    queue,
    'platform_data_protection_and_backup_attestation',
  );
  const encryptedRecords = requiredItem(
    queue,
    'encrypted_critical_record_envelopes',
  );
  const cryptographicAgility = requiredItem(
    queue,
    'cryptographic_agility_and_deprecation_gate',
  );
  const residency = requiredItem(
    queue,
    'backend_location_retention_residency_contract',
  );

  const secretContract = secrets.acceptanceCriteria.join(' ');
  assert.match(secretContract, /attested security level/);
  assert.match(secretContract, /physical-device tests/);
  assert.ok(secrets.dependencies.includes('account_lifecycle'));
  assert.match(secrets.currentGap, /schema-v1 protected envelope/);
  assert.match(secrets.currentGap, /No platform is labeled hardware-backed/);

  const encryptedRecordContract = encryptedRecords.acceptanceCriteria.join(' ');
  assert.match(encryptedRecords.currentGap, /does not by itself provide record confidentiality/);
  assert.match(encryptedRecordContract, /unique nonces/);
  assert.match(encryptedRecordContract, /atomic old-or-new protocol/);
  assert.ok(
    encryptedRecords.dependencies.includes(
      'device_bound_secret_storage_and_rotation',
    ),
  );

  const agilityContract = cryptographicAgility.acceptanceCriteria.join(' ');
  assert.match(cryptographicAgility.currentGap, /no generated inventory/);
  assert.match(agilityContract, /allowed, transitional, deprecated, and prohibited/);
  assert.match(agilityContract, /does not claim present quantum resistance/);
  assert.ok(
    cryptographicAgility.dependencies.includes(
      'encrypted_critical_record_envelopes',
    ),
  );

  const backupContract = backup.acceptanceCriteria.join(' ');
  assert.match(backup.currentGap, /implicit platform channel/);
  assert.match(backupContract, /explicit user-owned export/);
  assert.ok(
    backup.dependencies.includes('device_bound_secret_storage_and_rotation'),
  );

  const residencyContract = residency.acceptanceCriteria.join(' ');
  assert.match(residency.currentGap, /cannot later be changed/);
  assert.match(residencyContract, /actual service state/);
  assert.match(residencyContract, /legal residency or regulatory conclusions/);
  assert.ok(
    residency.dependencies.includes('store_privacy_declaration_drift_gate'),
  );
});

test('web zoom and rendered contrast remain artifact-bound accessibility gates', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const wcag = requiredItem(queue, 'wcag_22_aa_conformance');
  const browserZoom = requiredItem(
    queue,
    'browser_zoom_reflow_release_artifact_matrix',
  );
  const contrast = requiredItem(
    queue,
    'forced_colors_non_text_contrast_state_matrix',
  );
  const wasmHosting = requiredItem(
    queue,
    'wasm_cross_origin_isolation_hosting_attestation',
  );
  const wasmSymbolication = requiredItem(
    queue,
    'wasm_private_symbolication_and_public_source_map_leak_gate',
  );

  assert.equal(wcag.status, 'queued');
  assert.match(wcag.currentGap, /320-logical-pixel reflow surrogate/);
  assert.match(wcag.currentGap, /two-chart contract/);
  assert.match(wcag.currentGap, /remain unproven/);

  const zoomContract = browserZoom.acceptanceCriteria.join(' ');
  assert.equal(browserZoom.status, 'research_required');
  assert.equal(browserZoom.score, 24);
  assert.ok(browserZoom.dependencies.includes(wcag.id));
  assert.ok(browserZoom.dependencies.includes('cross_platform_integration_harness'));
  assert.match(zoomContract, /measured 320 CSS-pixel-equivalent viewport/);
  assert.match(zoomContract, /independently served release artifact/);
  assert.match(zoomContract, /widget-test surrogate cannot satisfy/);
  assert.match(browserZoom.currentGap, /passes one Chromium matrix/);
  assert.match(browserZoom.currentGap, /visible zoom control/);

  const wasmContract = [
    wasmHosting.currentGap,
    ...wasmHosting.acceptanceCriteria,
  ].join(' ');
  assert.equal(wasmHosting.status, 'research_required');
  assert.equal(wasmHosting.score, 24);
  assert.ok(wasmHosting.dependencies.includes(browserZoom.id));
  assert.ok(
    wasmHosting.dependencies.includes('reproducible_release_sbom_attestation'),
  );
  assert.match(wasmHosting.currentGap, /single-threaded Skwasm mode/);
  assert.match(wasmHosting.currentGap, /dart\.library\.js_interop\/package:web/);
  assert.match(wasmHosting.currentGap, /public and local Firebase Hosting configuration still lacks COEP/);
  for (const term of [
    'Cross-Origin-Embedder-Policy',
    'Cross-Origin-Opener-Policy',
    'crossOriginIsolated',
    'service-worker',
    'compilation success',
  ]) {
    assert.match(wasmContract, new RegExp(term, 'i'));
  }

  const symbolicationContract = [
    wasmSymbolication.currentGap,
    ...wasmSymbolication.acceptanceCriteria,
  ].join(' ');
  assert.equal(wasmSymbolication.status, 'research_required');
  assert.equal(wasmSymbolication.score, 24);
  assert.ok(wasmSymbolication.dependencies.includes(wasmHosting.id));
  assert.ok(
    wasmSymbolication.dependencies.includes(
      'reproducible_release_sbom_attestation',
    ),
  );
  for (const term of [
    '--no-strip-wasm',
    '--source-maps',
    'private symbolication',
    'public Hosting bundle',
    'synthetic Wasm failure',
  ]) {
    assert.match(symbolicationContract, new RegExp(term, 'i'));
  }

  const contrastContract = contrast.acceptanceCriteria.join(' ');
  assert.equal(contrast.status, 'research_required');
  assert.equal(contrast.score, 18);
  assert.ok(contrast.dependencies.includes(wcag.id));
  assert.match(contrast.currentGap, /effective pixels/);
  assert.match(contrastContract, /without color alone/);
  assert.match(contrastContract, /low-vision human review/);
});

test('next-wave algorithm, notification, time, egress, and response research stays explicit', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const executable = requiredItem(
    queue,
    'algorithm_executable_contract_metamorphic_gate',
  );
  const notification = requiredItem(
    queue,
    'notification_capability_truth_matrix_and_readiness_ui',
  );
  const attestationPublication = requiredItem(
    queue,
    'android_attestation_crash_consistent_publication_and_recovery',
  );
  const egress = requiredItem(
    queue,
    'runtime_network_egress_policy_and_artifact_attestation',
  );
  assert.equal(egress.status, 'research_required');
  assert.match(egress.currentGap, /versioned application-layer policy/i);
  assert.match(egress.currentGap, /DNS\/socket destinations.*release-artifact connections/i);
  const trustedTime = requiredItem(
    queue,
    'trusted_time_discontinuity_and_freshness_gate',
  );
  const vulnerabilityResponse = requiredItem(
    queue,
    'vulnerability_response_vex_and_emergency_patch_drill',
  );
  const liveCoverage = requiredItem(
    queue,
    'algorithm_executable_trace_coverage',
  );
  assert.equal(liveCoverage.status, 'queued');
  assert.match(liveCoverage.currentGap, /fourteen IDs.*live/i);
  assert.match(liveCoverage.currentGap, /input_quality_gate/);
  assert.match(liveCoverage.currentGap, /medication_entry_validator/);
  assert.match(liveCoverage.currentGap, /time_axis_builder/);
  assert.match(liveCoverage.currentGap, /protein_trend/);
  assert.match(liveCoverage.currentGap, /dosage_note_parser/);
  assert.match(liveCoverage.currentGap, /protein_distribution/);
  assert.match(liveCoverage.currentGap, /49 static-only contracts/i);
  const independentContracts = requiredItem(
    queue,
    'algorithm_contract_relation_independence_and_cross_runtime_oracle',
  );
  const relationSampling = requiredItem(
    queue,
    'algorithm_relation_domain_sampling_and_false_alarm_calibration',
  );
  const relationCoverage = requiredItem(
    queue,
    'algorithm_metamorphic_execution_coverage_and_generator_drift',
  );
  const samplingAdequacy = requiredItem(
    queue,
    'algorithm_sampling_operational_profile_and_budget_adequacy',
  );
  assert.equal(executable.status, 'shipped');
  assert.equal(executable.score, 30);
  assert.match(executable.currentGap, /30-of-63/);
  assert.match(executable.currentGap, /33 explicit gaps/);
  assert.match(executable.currentGap, /catalog-candidate projection/);
  assert.match(executable.currentGap, /order-dependent fact-conflict defect/);
  assert.match(executable.acceptanceCriteria.join(' '), /30-of-63/);
  assert.ok(liveCoverage.dependencies.includes(executable.id));
  assert.equal(independentContracts.status, 'shipped');
  assert.equal(independentContracts.priority, 'P0');
  assert.equal(independentContracts.score, 18);
  assert.ok(independentContracts.dependencies.includes(executable.id));
  assert.match(independentContracts.currentGap, /16-of-16/);
  assert.match(independentContracts.currentGap, /6-of-6/);
  assert.match(independentContracts.currentGap, /imports no production Dart/);
  assert.match(
    independentContracts.acceptanceCriteria.join(' '),
    /second runtime.*byte-stable|byte-stable.*second runtime/i,
  );
  assert.match(
    independentContracts.acceptanceCriteria.join(' '),
    /mutation score is never presented as correctness/i,
  );
  assert.equal(relationSampling.status, 'research_required');
  assert.equal(relationSampling.priority, 'P0');
  assert.equal(relationSampling.score, 18);
  assert.ok(relationSampling.dependencies.includes(independentContracts.id));
  assert.match(relationSampling.currentGap, /diagnostic exposures/i);
  assert.match(relationSampling.currentGap, /96-of-96 production cases/i);
  assert.match(relationSampling.currentGap, /624 production API invocations/i);
  assert.match(relationSampling.currentGap, /held before production execution/i);
  assert.match(relationSampling.currentGap, /schema-v2 producer\/consumer split/i);
  assert.match(relationSampling.currentGap, /96 diagnostic exposures among 128/i);
  assert.match(relationSampling.currentGap, /not a production false-positive/i);
  assert.equal(relationCoverage.status, 'research_required');
  assert.equal(relationCoverage.score, 16);
  assert.ok(relationCoverage.dependencies.includes(relationSampling.id));
  assert.match(relationCoverage.currentGap, /generator changes/i);
  assert.match(
    relationCoverage.acceptanceCriteria.join(' '),
    /locked regression corpus.*rotating exploratory seed schedule/i,
  );
  assert.match(
    relationSampling.acceptanceCriteria.join(' '),
    /seed.*generator-version|generator-version.*seed/i,
  );
  assert.match(
    relationSampling.acceptanceCriteria.join(' '),
    /equivalent, unreachable, invalid and surviving mutants/i,
  );
  assert.equal(samplingAdequacy.status, 'research_required');
  assert.equal(samplingAdequacy.priority, 'P1');
  assert.equal(samplingAdequacy.score, 16);
  assert.ok(samplingAdequacy.dependencies.includes(relationSampling.id));
  assert.ok(samplingAdequacy.dependencies.includes(relationCoverage.id));
  assert.match(samplingAdequacy.currentGap, /not evidence.*represents/i);
  assert.match(
    samplingAdequacy.acceptanceCriteria.join(' '),
    /stopping rules.*locked before evaluation/i,
  );
  assert.match(
    samplingAdequacy.acceptanceCriteria.join(' '),
    /sampling proportions do not estimate.*prevalence/i,
  );

  assert.equal(notification.status, 'in_progress');
  assert.equal(notification.score, 36);
  assert.match(notification.currentGap, /visible delivery/);
  assert.match(notification.currentGap, /release failure or signal/);
  assert.match(notification.acceptanceCriteria.join(' '), /plan-only/);

  assert.equal(attestationPublication.status, 'research_required');
  assert.equal(attestationPublication.priority, 'P1');
  assert.equal(attestationPublication.score, 18);
  assert.ok(attestationPublication.dependencies.includes(notification.id));
  assert.match(attestationPublication.currentGap, /not make.*crash durable/i);
  assert.match(
    attestationPublication.acceptanceCriteria.join(' '),
    /post-release lease-evidence digest/i,
  );
  assert.match(
    attestationPublication.acceptanceCriteria.join(' '),
    /file sync, rename, directory sync/i,
  );
  assert.match(
    attestationPublication.acceptanceCriteria.join(' '),
    /previous complete pointer/i,
  );

  for (const item of [egress, trustedTime, vulnerabilityResponse]) {
    assert.equal(item.status, 'research_required');
    assert.equal(item.priority, 'P0');
    assert.equal(item.score, 20);
  }
  assert.match(egress.acceptanceCriteria.join(' '), /unknown destination is denied/);
  assert.match(trustedTime.acceptanceCriteria.join(' '), /time_unverified/);
  assert.match(
    vulnerabilityResponse.acceptanceCriteria.join(' '),
    /known_not_affected/,
  );
});

test('timezone evidence binds owner-observation supplements while broader replay gates stay open', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'versioned_timezone_rule_provenance_and_dst_replay',
  );

  assert.equal(item.status, 'research_required');
  assert.match(item.currentGap, /schema-v1 local-time resolution preview/i);
  assert.match(item.currentGap, /schema-v2 owner-observation projection can bind this evidence/i);
  assert.match(item.currentGap, /older rows are never backfilled/i);
  assert.match(
    item.currentGap,
    /caller-supplied tzdb\/provider labels are not independently attested/i,
  );
  assert.match(item.currentGap, /RFC 9557 parsing/i);
  assert.match(item.currentGap, /older than IANA 2026d/i);
  assert.match(item.currentGap, /No reconciliation creates or reschedules/i);
  assert.ok(item.acceptanceCriteria.some((criterion) => /earlier\/later\/reject/i.test(criterion)));
  assert.ok(item.acceptanceCriteria.some((criterion) => /multi-release|versioned drift report/i.test(criterion)));
});

test('configuration-completeness review authority stays exact, distinct, and fail closed', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const item = requiredItem(
    queue,
    'algorithm_configuration_completeness_witness_review_authority_lifecycle',
  );

  assert.equal(
    item.title,
    'Signed reviewer authority, expiry and revocation lifecycle for configuration-completeness witnesses',
  );
  assert.equal(item.area, 'algorithm_quality');
  assert.equal(item.status, 'research_required');
  assert.equal(item.priority, 'P0');
  assert.equal(item.impact, 5);
  assert.equal(item.risk, 5);
  assert.equal(item.effort, 4);
  assert.equal(item.score, 20);
  assert.deepEqual(item.dependencies, [
    'algorithm_configuration_identity_digest',
    'configuration_baseline_registry_and_reviewed_promotion_receipt',
    'capability_signing_key_transparency_and_compromise_recovery',
    'algorithm_transitive_result_dependency_closure',
  ]);
  assert.deepEqual(item.evidenceUrls, [
    'https://github.com/secure-systems-lab/dsse/blob/v1.0.2/protocol.md',
    'https://theupdateframework.github.io/specification/v1.0.32/',
    'https://github.com/in-toto/attestation/blob/v1.2.0/spec/v1/statement.md',
    'https://github.com/in-toto/attestation/blob/v1.2.0/spec/v1/envelope.md',
    'https://slsa.dev/spec/v1.2/verification_summary',
    'https://www.rfc-editor.org/rfc/rfc9162.html',
    'https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-218.pdf',
  ]);
  assert.equal(item.acceptanceCriteria.length, 5);

  assert.match(item.currentGap, /reviewedAt is unsigned metadata/);
  assert.match(item.currentGap, /distinct-reviewer and distinct-key/);
  const contract = item.acceptanceCriteria.join(' ');
  for (const pattern of [
    /three-layer contract/i,
    /DSSE exact-bytes authorization/i,
    /Production private keys never enter/i,
    /different reviewer identities and different trusted public-key bytes/i,
    /keyid is only an unauthenticated lookup hint/i,
    /issuedAt, notBefore and expiresAt/i,
    /append-only witness and key revocation/i,
    /never silently renews or transfers/i,
    /old-root threshold and the proposed new-root threshold/i,
    /stale configuration or source/i,
    /rollback against retained high-water marks/i,
    /valid_for_declared_configuration_scope/i,
    /neither scientific correctness nor clinical validity/i,
  ]) {
    assert.match(contract, pattern);
  }

  const research = fs.readFileSync(
    'docs/ALGORITHM_CONFIGURATION_COMPLETENESS_WITNESS_REVIEW_AUTHORITY_LIFECYCLE_RESEARCH_2026-09-02.md',
    'utf8',
  );
  for (const pattern of [
    /Layer 1: deterministic completeness witness/,
    /Layer 2: DSSE exact-bytes authorization/,
    /Layer 3: versioned trust and status ledger/,
    /same verified serialized bytes to the parser and application layer/,
    /keyid.*only a lookup hint/is,
    /different reviewer identity and a different trusted public key/,
    /threshold of the currently trusted old root and the threshold of the proposed new root/,
    /Witness and key revocations are append-only/,
    /clock_unverified/,
    /stale_configuration/,
    /rollback_detected/,
    /does not establish physiological fidelity, population calibration, clinical utility/,
  ]) {
    assert.match(research, pattern);
  }
});

test('score drift and unknown dependencies fail closed', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const mutated = structuredClone(queue);
  mutated.items[0].score += 1;
  mutated.items[0].dependencies.push('does_not_exist');
  const failures = validateUpgradeQueue(mutated);
  assert.ok(failures.some((failure) => failure.includes('does not match')));
  assert.ok(failures.some((failure) => failure.includes('unknown dependency')));
});

test('dependency cycles fail closed', () => {
  const { queue } = readAndValidateUpgradeQueue();
  const mutated = structuredClone(queue);
  mutated.items[0].dependencies.push(mutated.items[1].id);
  mutated.items[1].dependencies.push(mutated.items[0].id);
  assert.ok(
    validateUpgradeQueue(mutated).some((failure) =>
      failure.includes('dependency cycle'),
    ),
  );
});
