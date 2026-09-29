import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  readAndValidateSchemaCatalog,
  requiredSchemaSurfaces,
  validateSchemaCatalog,
} from './schema_catalog_check.mjs';

function baseline() {
  const result = readAndValidateSchemaCatalog();
  assert.ok(result.catalog, result.failures.join('\n'));
  return result;
}

function schemaById(catalog, id) {
  const schema = catalog.schemas.find((candidate) => candidate.id === id);
  assert.ok(schema, `missing test fixture schema ${id}`);
  return schema;
}

test('committed catalog covers every required and discovered schema surface', () => {
  const { catalog, failures } = baseline();
  assert.deepEqual(failures, []);
  const careWorkspace = schemaById(catalog, 'parkinsum.care-workspace');
  assert.equal(careWorkspace.currentVersion, 5);
  assert.deepEqual(careWorkspace.acceptedLegacyVersions, [1, 2, 3, 4]);
  assert.match(careWorkspace.compatibility, /text matching remains exact\/case\/space-only/);
  assert.match(careWorkspace.compatibility, /not a rule input/);
  assert.match(careWorkspace.compatibility, /append-only owner-reported discussion-outcome history/);
  const followupLedger = schemaById(
    catalog,
    'parkinsum.decision-support-followup-ledger',
  );
  assert.equal(followupLedger.currentVersion, 3);
  assert.deepEqual(followupLedger.acceptedLegacyVersions, [1, 2]);
  assert.match(followupLedger.compatibility, /declined workflow states/);
  assert.match(followupLedger.compatibility, /owner-selected reason categor/);
  assert.match(followupLedger.compatibility, /unclassified/);
  assert.match(followupLedger.compatibility, /migrate to v3/);
  assert.equal(catalog.schemas.length, requiredSchemaSurfaces.length);
  assert.equal(catalog.schemas.length, 166);
  const catalogChangeDiff = schemaById(
    catalog,
    'parkinsum.catalog-version-change-diff',
  );
  assert.equal(catalogChangeDiff.currentVersion, 1);
  assert.match(catalogChangeDiff.compatibility, /name similarity never creates a mapping/);
  assert.match(catalogChangeDiff.compatibility, /not wired to runtime algorithm abstention/);
  assert.equal(
    schemaById(catalog, 'parkinsum.rxnorm-release-identity').currentVersion,
    1,
  );
  assert.match(
    schemaById(catalog, 'parkinsum.rxnorm-release-identity').compatibility,
    /absence from the active subset remains unresolved, not retired/,
  );
  assert.match(
    schemaById(catalog, 'parkinsum.rxnorm-release-identity').compatibility,
    /archive was not downloaded or locally verified/,
  );
  const packageDoseDerivation = schemaById(
    catalog,
    'parkinsum.medication-package-dose-derivation',
  );
  assert.equal(packageDoseDerivation.currentVersion, 1);
  assert.equal(
    packageDoseDerivation.source,
    'lib/core/models/medication_product_pack.dart',
  );
  assert.match(packageDoseDerivation.compatibility, /exact ingredient-strength text/);
  assert.match(packageDoseDerivation.compatibility, /complete product snapshot digest/);
  const infoodsSourceIdentity = schemaById(
    catalog,
    'parkinsum.infoods-tagname-source-identity',
  );
  assert.equal(infoodsSourceIdentity.currentVersion, 1);
  assert.match(infoodsSourceIdentity.compatibility, /2022-10-20 update/);
  assert.match(infoodsSourceIdentity.compatibility, /coming soon/);
  assert.match(infoodsSourceIdentity.compatibility, /mapping remains on hold/);
  assert.equal(
    schemaById(catalog, 'parkinsum.fhir-r4-bp-mapper').currentVersion,
    2,
  );
  assert.match(
    schemaById(catalog, 'parkinsum.fhir-r4-bp-mapper').compatibility,
    /LOINC code-system version \(2\.83\)/,
  );
  assert.match(
    schemaById(catalog, 'parkinsum.fhir-r4-bp-mapper').compatibility,
    /UCUM release is not carried on the wire/,
  );
  const fhirObservationImport = schemaById(
    catalog,
    'parkinsum.fhir-r4-observation-import-preview',
  );
  assert.equal(fhirObservationImport.currentVersion, 1);
  assert.match(fhirObservationImport.compatibility, /in memory/i);
  assert.match(fhirObservationImport.compatibility, /distinct component absent reasons/i);
  assert.match(fhirObservationImport.compatibility, /no data is persisted/i);
  assert.match(fhirObservationImport.compatibility, /no CDSS algorithm consumes the preview/i);
  const fhirMedicationStatementImport = schemaById(
    catalog,
    'parkinsum.fhir-r4-medication-statement-import-preview',
  );
  assert.equal(fhirMedicationStatementImport.currentVersion, 1);
  assert.match(fhirMedicationStatementImport.compatibility, /128 KiB input/);
  assert.match(fhirMedicationStatementImport.compatibility, /holds every known-but-unprojected/);
  assert.match(fhirMedicationStatementImport.compatibility, /no record is persisted, sent or algorithm-eligible/);
  assert.match(fhirMedicationStatementImport.compatibility, /not FHIR validation/);
  const fhirMedicationRequestImport = schemaById(
    catalog,
    'parkinsum.fhir-r4-medication-request-import-preview',
  );
  assert.equal(fhirMedicationRequestImport.currentVersion, 1);
  assert.match(fhirMedicationRequestImport.compatibility, /128 KiB input/);
  assert.match(fhirMedicationRequestImport.compatibility, /status, intent and lexical authoredOn precision separately from MedicationStatement/);
  assert.match(fhirMedicationRequestImport.compatibility, /entered-in-error, modifier, known-but-unprojected and unknown fields/);
  assert.match(fhirMedicationRequestImport.compatibility, /not FHIR validation/);
  const fhirAllergyImport = schemaById(
    catalog,
    'parkinsum.fhir-r4-allergy-intolerance-import-preview',
  );
  assert.equal(fhirAllergyImport.currentVersion, 1);
  assert.match(fhirAllergyImport.compatibility, /32 entries and 128 KiB input/);
  assert.match(fhirAllergyImport.compatibility, /clinicalStatus and verificationStatus as separate source-reported concepts/);
  assert.match(fhirAllergyImport.compatibility, /without terminology lookup/);
  assert.match(fhirAllergyImport.compatibility, /entered-in-error.*unknown or known-but-unprojected fields are held/);
  assert.match(fhirAllergyImport.compatibility, /not an allergy conclusion, FHIR conformance validation/);
  const fhirConditionImport = schemaById(
    catalog,
    'parkinsum.fhir-r4-condition-import-preview',
  );
  assert.equal(fhirConditionImport.currentVersion, 1);
  assert.match(fhirConditionImport.compatibility, /32 entries and 128 KiB input/);
  assert.match(fhirConditionImport.compatibility, /clinicalStatus separately from verificationStatus/);
  assert.match(fhirConditionImport.compatibility, /exact Patient reference/);
  assert.match(fhirConditionImport.compatibility, /entered-in-error and abatement constraints/);
  assert.match(fhirConditionImport.compatibility, /not a diagnosis conclusion, FHIR conformance validation/);
  const fhirEncounterImport = schemaById(
    catalog,
    'parkinsum.fhir-r4-encounter-import-preview',
  );
  assert.equal(fhirEncounterImport.currentVersion, 1);
  assert.match(fhirEncounterImport.compatibility, /32 entries and 128 KiB input/);
  assert.match(fhirEncounterImport.compatibility, /source status, Encounter\.class Coding fields and lexical period endpoints/);
  assert.match(fhirEncounterImport.compatibility, /entered-in-error, Patient mismatches.*unknown or known-but-unprojected fields are held/);
  assert.match(fhirEncounterImport.compatibility, /No record is persisted, sent, resolved, interpreted or algorithm-eligible/);
  const fhirMedicationAdministrationImport = schemaById(
    catalog,
    'parkinsum.fhir-r4-medication-administration-import-preview',
  );
  assert.equal(fhirMedicationAdministrationImport.currentVersion, 1);
  assert.match(fhirMedicationAdministrationImport.compatibility, /32 entries and 128 KiB input/);
  assert.match(fhirMedicationAdministrationImport.compatibility, /exact Patient reference/);
  assert.match(fhirMedicationAdministrationImport.compatibility, /source status, medicationCodeableConcept coding, category, statusReason and lexical effective\[x\] precision/);
  assert.match(fhirMedicationAdministrationImport.compatibility, /entered-in-error.*known-but-unprojected fields.*dosage/);
  assert.match(fhirMedicationAdministrationImport.compatibility, /not proof of administration, FHIR conformance validation/);
  const fhirMedicationDispenseImport = schemaById(
    catalog,
    'parkinsum.fhir-r4-medication-dispense-import-preview',
  );
  assert.equal(fhirMedicationDispenseImport.currentVersion, 1);
  assert.match(fhirMedicationDispenseImport.compatibility, /32 entries and 128 KiB input/);
  assert.match(fhirMedicationDispenseImport.compatibility, /exact Patient reference/);
  assert.match(fhirMedicationDispenseImport.compatibility, /source quantity and daysSupply without conversion/);
  assert.match(fhirMedicationDispenseImport.compatibility, /entered-in-error.*dosageInstruction and medicationReference/);
  assert.match(fhirMedicationDispenseImport.compatibility, /not proof of pickup, medication use, adherence/);
  const dosePreview = schemaById(
    catalog,
    'parkinsum.fhir-r5-dose-quantity-preview',
  );
  assert.equal(dosePreview.currentVersion, 2);
  assert.match(dosePreview.compatibility, /offline FHIR R5 Dosage doseQuantity fragment/);
  assert.match(dosePreview.compatibility, /resource_or_exchange_eligible is always false/);
  assert.match(dosePreview.compatibility, /content-addressed path ledger/);
  assert.match(dosePreview.compatibility, /not a complete FHIR resource\/profile/);
  assert.match(dosePreview.compatibility, /license clearance.*not established/);
  const dosePreviewProfile = schemaById(
    catalog,
    'parkinsum.fhir-r5-dose-quantity-preview-profile',
  );
  assert.equal(dosePreviewProfile.currentVersion, 2);
  assert.match(dosePreviewProfile.compatibility, /per-element FHIR R5 Dosage disposition ledger/);
  assert.match(dosePreviewProfile.compatibility, /not a validator result/);
  const medicationPreview = schemaById(
    catalog,
    'parkinsum.fhir-r5-medication-product-preview',
  );
  assert.equal(medicationPreview.currentVersion, 3);
  assert.match(medicationPreview.compatibility, /development-only FHIR R5 Medication fragment/);
  assert.match(medicationPreview.compatibility, /exact tablet form/);
  assert.match(medicationPreview.compatibility, /unique exact match.*local source manifest/i);
  assert.match(medicationPreview.compatibility, /does not verify source truth or currentness/i);
  assert.match(medicationPreview.compatibility, /all other strengths remain local evidence/i);
  assert.match(medicationPreview.compatibility, /algorithm_eligible are always false/);
  const medicationPreviewProfile = schemaById(
    catalog,
    'parkinsum.fhir-r5-medication-product-preview-profile',
  );
  assert.equal(medicationPreviewProfile.currentVersion, 3);
  assert.match(medicationPreviewProfile.compatibility, /bounded Medication path dispositions/);
  assert.match(medicationPreviewProfile.compatibility, /exact local asset.*ingredient-row binding/i);
  assert.match(medicationPreviewProfile.compatibility, /not a validator result/);
  assert.match(medicationPreviewProfile.compatibility, /UCUM license clearance/);
  const nutritionIntakePreview = schemaById(
    catalog,
    'parkinsum.fhir-r5-nutrition-intake-preview',
  );
  assert.equal(nutritionIntakePreview.currentVersion, 1);
  assert.match(nutritionIntakePreview.compatibility, /single-meal FHIR R5 NutritionIntake-shaped preview/);
  assert.match(nutritionIntakePreview.compatibility, /unknown status.*exact user-supplied Patient reference/);
  assert.match(nutritionIntakePreview.compatibility, /not validated against the official validator or a specific profile/);
  const openFdaStrengthExpression = schemaById(
    catalog,
    'parkinsum.openfda-strength-expression-parse-result',
  );
  assert.equal(openFdaStrengthExpression.currentVersion, 1);
  assert.match(openFdaStrengthExpression.compatibility, /preserves the exact source string/);
  assert.match(openFdaStrengthExpression.compatibility, /lexical tokens only/);
  assert.match(openFdaStrengthExpression.compatibility, /never eligible for FHIR strength/);
  const openFdaStrengthManifest = schemaById(
    catalog,
    'parkinsum.openfda-strength-expression-source-manifest',
  );
  assert.equal(openFdaStrengthManifest.currentVersion, 1);
  assert.match(openFdaStrengthManifest.compatibility, /binds each lexical strength parse to the exact source asset digest/);
  assert.match(openFdaStrengthManifest.compatibility, /does not verify source data/);
  assert.equal(
    schemaById(catalog, 'parkinsum.fhir-r4-bp-collection-mapper').currentVersion,
    3,
  );
  assert.match(
    schemaById(catalog, 'parkinsum.fhir-r4-bp-collection-mapper').compatibility,
    /Generated Bundle fullUrls and Observation IDs are independent of local record IDs/,
  );
  for (const [id, version] of [
    ['parkinsum.fhir-r4-medication-statement-collection', 1],
    ['parkinsum.fhir-r4-personal-collection', 1],
    ['parkinsum.fhir-r4-symptom-motor-collection', 2],
    ['parkinsum.fhir-r4-symptom-motor-mapper', 1],
  ]) {
    assert.equal(schemaById(catalog, id).currentVersion, version);
  }
  const candidateSnapshot = schemaById(
    catalog,
    'parkinsum.food-composition-candidate-set-snapshot',
  );
  assert.equal(candidateSnapshot.currentVersion, 5);
  assert.equal(candidateSnapshot.surfaceKind, 'runtime-contract');
  assert.match(candidateSnapshot.compatibility, /canonical SHA-256/i);
  assert.match(candidateSnapshot.compatibility, /per-nutrient observation IDs/i);
  assert.match(candidateSnapshot.compatibility, /non-exact nutrient rows and portion records are evidence only/i);
  assert.match(candidateSnapshot.compatibility, /local projection query audit/i);
  assert.match(candidateSnapshot.compatibility, /caller query and filters are not captured/i);
  assert.match(candidateSnapshot.compatibility, /not a catalog freeze/i);
  assert.match(candidateSnapshot.compatibility, /is not a persisted record/i);
  const foodProjectionQueryAudit = schemaById(
    catalog,
    'parkinsum.cdss-food-projection-query-audit',
  );
  assert.equal(foodProjectionQueryAudit.currentVersion, 1);
  assert.match(foodProjectionQueryAudit.compatibility, /no-WHERE\/no-ORDER-BY/i);
  assert.match(foodProjectionQueryAudit.compatibility, /not transaction-scoped/i);
  assert.equal(
    catalog.schemas.filter((schema) => schema.versionStatus !== 'unversioned')
      .length,
    160,
  );
  assert.equal(
    catalog.schemas.filter((schema) => schema.versionStatus === 'unversioned')
      .length,
    6,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.synthetic-rule-test-suite').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.synthetic-rule-test-suite-report').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.personal-log-handoff-semantic-document')
      .currentVersion,
    1,
  );
  const openSourceReleaseEvidence = schemaById(
    catalog,
    'parkinsum.open-source-release-evidence',
  );
  assert.equal(openSourceReleaseEvidence.currentVersion, 3);
  assert.match(openSourceReleaseEvidence.compatibility, /pinned Flutter LicenseCollector behavior/);
  assert.match(openSourceReleaseEvidence.compatibility, /exact NOTICE bytes/);
  assert.match(openSourceReleaseEvidence.compatibility, /unsigned/);
  assert.match(openSourceReleaseEvidence.compatibility, /incomplete composition/);
  assert.match(openSourceReleaseEvidence.compatibility, /NOASSERTION/);
  const androidGradleGraph = schemaById(
    catalog,
    'parkinsum.android-gradle-runtime-dependency-graph',
  );
  assert.equal(androidGradleGraph.currentVersion, 2);
  assert.match(androidGradleGraph.compatibility, /debugRuntimeClasspath/);
  assert.match(androidGradleGraph.compatibility, /license\/notice documents embedded/);
  assert.match(androidGradleGraph.compatibility, /fail closed/);
  const bitemporalProjection = schemaById(
    catalog,
    'parkinsum.medication-assertion-bitemporal-projection',
  );
  const medicationAssertion = schemaById(
    catalog,
    'parkinsum.medication-assertion',
  );
  assert.equal(medicationAssertion.currentVersion, 2);
  assert.deepEqual(medicationAssertion.acceptedLegacyVersions, [1]);
  assert.match(medicationAssertion.compatibility, /version 1 identities remain unchanged and unnamed/);
  assert.match(medicationAssertion.compatibility, /not issuer authenticity proof/);
  assert.equal(bitemporalProjection.currentVersion, 3);
  assert.match(bitemporalProjection.compatibility, /withholds later assertion/);
  assert.match(bitemporalProjection.compatibility, /not dose eligible/);
  assert.match(bitemporalProjection.compatibility, /incomplete projection/);
  assert.equal(
    schemaById(catalog, 'parkinsum.algorithm-evaluation').currentVersion,
    4,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.algorithm-configuration').currentVersion,
    6,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.levodopa-absorption-opportunity-parameters',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.levodopa-absorption-generator-structure',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.absorption-opportunity-output-contract',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.gastric-emptying-configuration',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.gastric-emptying-generator-structure',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.gastric-emptying-output-contract',
    ).currentVersion,
    1,
  );
  const gastricParameters = schemaById(
    catalog,
    'parkinsum.gastric-parameter-set',
  );
  assert.equal(gastricParameters.currentVersion, '2026.09.02-v3');
  assert.equal(gastricParameters.schemaUriVersion, 1);
  assert.match(gastricParameters.compatibility, /not a population calibration/);
  assert.equal(
    schemaById(catalog, 'parkinsum.algorithm-parameter-provenance')
      .currentVersion,
    2,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.algorithm-parameter-manifest').currentVersion,
    2,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.algorithm-configuration-coverage')
      .currentVersion,
    2,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.algorithm-configuration-completeness-witness',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.signed-capability-manifest').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.capability-activation-state').currentVersion,
    2,
  );
  assert.deepEqual(
    schemaById(catalog, 'parkinsum.capability-activation-state')
      .acceptedLegacyVersions,
    [1],
  );
  const reminderAttestation = schemaById(
    catalog,
    'parkinsum.android-reminder-run-attestation',
  );
  assert.equal(reminderAttestation.currentVersion, 4);
  assert.equal(reminderAttestation.acceptedLegacyVersions, undefined);
  assert.match(reminderAttestation.compatibility, /hard exact-key replacement/);
  assert.match(reminderAttestation.compatibility, /historical local v1, v2 and v3/);
  const reminderManifest = schemaById(
    catalog,
    'parkinsum.reminder-schedule-manifest',
  );
  assert.equal(reminderManifest.currentVersion, 1);
  assert.match(reminderManifest.compatibility, /in-memory preflight and installation-fingerprint/);
  assert.match(reminderManifest.compatibility, /not a serialized or persisted manifest/);
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.android-reminder-execution-isolation',
    ).currentVersion,
    2,
  );
  assert.match(
    schemaById(
      catalog,
      'parkinsum.android-reminder-execution-isolation',
    ).compatibility,
    /lease-evidence SHA-256/,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.mechanistic-applicability-manifest',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.context-of-use-requalification-ledger',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.operational-observability-envelope',
    ).currentVersion,
    1,
  );
  const evidenceCurrency = schemaById(
    catalog,
    'parkinsum.evidence-currency-registry',
  );
  assert.equal(evidenceCurrency.currentVersion, 1);
  assert.match(
    evidenceCurrency.compatibility,
    /never uses a status observed after the requested time/i,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.credibility-protocol-transparency-ledger',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.credibility-transportability-sensitivity-package',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.claim-evidence-synthesis-registry',
    ).currentVersion,
    2,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.mechanistic-numerical-oracle').currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.algorithm-executable-contract-report',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.algorithm-contract-relation-registry',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.algorithm-contract-independent-oracle-report',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.mechanistic-event-ledger').currentVersion,
    3,
  );
  const observationLedger = schemaById(
    catalog,
    'parkinsum.personal-observation-event-ledger',
  );
  assert.equal(observationLedger.currentVersion, 2);
  assert.match(observationLedger.compatibility, /not the engine-bound mechanistic ledger/i);
  assert.match(observationLedger.compatibility, /not.*algorithm input/i);
  const localTimeResolution = schemaById(
    catalog,
    'parkinsum.local-time-resolution',
  );
  assert.equal(localTimeResolution.currentVersion, 1);
  assert.match(localTimeResolution.compatibility, /earlier or later choice/i);
  assert.match(localTimeResolution.compatibility, /digest of the exact zone rule tables/i);
  assert.match(localTimeResolution.compatibility, /optionally bound.*owner-observation projection/i);
  assert.match(localTimeResolution.compatibility, /never creates or reschedules/i);
  assert.deepEqual(
    schemaById(catalog, 'parkinsum.mechanistic-event-ledger')
      .acceptedLegacyVersions,
    [1, 2],
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.mechanistic-ledger-authorization',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.mechanistic-ledger-input-binding',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.mechanistic-replay-capsule')
      .currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.jcs-safe-lossless-scalars').currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.mechanistic-replay-cross-runtime-vectors',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.mechanistic-replay-cross-runtime-conformance',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.open-source-influence-inventory',
    ).currentVersion,
    7,
  );
  assert.match(
    schemaById(catalog, 'parkinsum.open-source-influence-inventory').compatibility,
    /Schema v7 preserves the v6 influence.*adds one file-level record for every locally transferred asset path.*local SHA-256/i,
  );
  const portablePackage = schemaById(
    catalog,
    'parkinsum.user-portable-data-package',
  );
  assert.equal(portablePackage.currentVersion, 4);
  assert.deepEqual(portablePackage.acceptedLegacyVersions, [2, 3]);
  assert.match(portablePackage.compatibility, /Versions 2 and 3 are readable/);
  assert.match(
    portablePackage.compatibility,
    /schema v1 remains unsupported/i,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.recoverable-event-restore-impact',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.restore-relationship-graph').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.restore-impact-account').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.portable-owner-token').currentVersion,
    2,
  );
  assert.equal(
    schemaById(
      catalog,
      'parkinsum.portable-owner-secret-envelope',
    ).currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.protected-secret-store').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.privacy-safe-support-bundle').currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.purpose-bound-consent-receipt')
      .currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.recoverable-user-event-history')
      .currentVersion,
    1,
  );
  assert.equal(
    schemaById(catalog, 'parkinsum.cdss-database-web').versionStatus,
    'unversioned',
  );
});

test('mechanistic event ledger v3 versions supplemental measurement dimensions', () => {
  const { catalog } = baseline();
  const schema = schemaById(catalog, 'parkinsum.mechanistic-event-ledger');
  assert.equal(schema.currentVersion, 3);
  assert.deepEqual(schema.acceptedLegacyVersions, [1, 2]);
  assert.equal(schema.source, 'lib/domain/entities/mechanistic_event_ledger.dart');
  assert.match(schema.compatibility, /strict pressure and ordinal-severity dimensions/i);
  assert.match(schema.compatibility, /supplemental owner observations/i);
  assert.match(schema.compatibility, /do not extend the engine-input binding/i);
  assert.match(schema.compatibility, /do not extend.*or enter.*calculations/i);
});

test('owner observation audit schema stays supplemental to engine input identity', () => {
  const { catalog } = baseline();
  const schema = schemaById(
    catalog,
    'parkinsum.personal-observation-event-ledger',
  );
  assert.equal(schema.currentVersion, 2);
  assert.equal(catalog.schemas.length, 166);
  assert.equal(catalog.schemas.length, requiredSchemaSurfaces.length);
  assert.equal(
    schema.source,
    'lib/domain/entities/personal_observation_event_ledger.dart',
  );
  assert.match(schema.compatibility, /current-owner.*PersonalObservation records/i);
  assert.match(schema.compatibility, /excludes owner ID, recorder ID, symptom labels and notes/i);
  assert.match(schema.compatibility, /MechanisticObservationEventImporter.*supplemental/i);
  assert.match(schema.compatibility, /caller may supply local-time resolution evidence/i);
  assert.match(schema.compatibility, /older observations are never backfilled/i);
  assert.match(schema.compatibility, /outside the exact engine-input binding/i);
  assert.match(schema.compatibility, /do not enter algorithm calculations/i);
  assert.ok(
    requiredSchemaSurfaces.some(
      (required) =>
        required.id === 'parkinsum.personal-observation-event-ledger',
    ),
  );
});

test('open-source influence inventory schema v7 matches its source and catalog pin', () => {
  const { catalog, failures } = baseline();
  const id = 'parkinsum.open-source-influence-inventory';
  const schema = schemaById(catalog, id);
  const source = readFileSync(
    'lib/domain/entities/product_upgrade_queue.dart',
    'utf8',
  );
  assert.equal(schema.currentVersion, 7);
  assert.match(schema.compatibility, /Schema v7 preserves the v6 influence/);
  assert.match(source, /openSourceInfluenceInventorySchemaVersion = 7/);
  assert.match(source, /parkinsum\.open-source-influence-inventory\/7/);
  assert.ok(!failures.some((failure) => failure.includes(id)), failures.join('\n'));
});

test('open-source drift decision and ledger schemas are versioned governance artifacts', () => {
  const { catalog, failures } = baseline();
  const source = readFileSync('tool/open_source_drift_decision_ledger.mjs', 'utf8');
  assert.equal(catalog.schemas.length, 166);
  assert.equal(
    catalog.schemas.filter((schema) => schema.versionStatus !== 'unversioned').length,
    160,
  );
  assert.equal(
    catalog.schemas.filter((schema) => schema.versionStatus === 'unversioned').length,
    6,
  );
  for (const id of [
    'parkinsum.open-source-drift-review-decision',
    'parkinsum.open-source-drift-review-ledger',
  ]) {
    const schema = schemaById(catalog, id);
    assert.equal(schema.currentVersion, 1);
    assert.equal(schema.surfaceKind, 'governance-artifact');
    assert.equal(schema.source, 'tool/open_source_drift_decision_ledger.mjs');
    assert.match(source, new RegExp(`${id}/1`));
    assert.ok(!failures.some((failure) => failure.includes(id)), failures.join('\n'));
    assert.ok(requiredSchemaSurfaces.some((required) => required.id === id));
  }
});

test('native app database schema v11 catalogs immutable replay persistence', () => {
  const { catalog, failures } = baseline();
  const id = 'parkinsum.app-database-native';
  const schema = schemaById(catalog, id);
  const source = readFileSync('lib/core/db/app_database_native.dart', 'utf8');
  assert.equal(schema.currentVersion, 11);
  assert.match(schema.compatibility, /digest-keyed immutable mechanistic replay capsule table/);
  assert.match(source, /nativeAppDatabaseSchemaVersion = 11/);
  assert.match(source, /if \(oldVersion < 11\)/);
  assert.match(source, /nativeMechanisticReplayCapsulesCreateTableSql/);
  assert.ok(!failures.some((failure) => failure.includes(id)), failures.join('\n'));
});

test('synthetic CDS Hooks challenge schema is versioned and ephemeral', () => {
  const { catalog } = baseline();
  const challenge = schemaById(
    catalog,
    'parkinsum.synthetic-cds-hooks-challenge',
  );
  assert.equal(challenge.currentVersion, 1);
  assert.equal(
    challenge.source,
    'lib/domain/usecases/synthetic_cds_hooks_challenge_service.dart',
  );
  assert.deepEqual(challenge.versionEvidence, [
    {
      kind: 'dart-int-constant',
      symbol: 'syntheticCdsHooksChallengeSchemaVersion',
    },
  ]);
  assert.match(challenge.compatibility, /exactly one fixed synthetic information card/);
  assert.match(challenge.compatibility, /input digest and canonical card SHA-256/);
  assert.match(challenge.compatibility, /not saved or transmitted/);
  assert.match(challenge.compatibility, /does not change the response or rule outcome/);
  assert.match(challenge.compatibility, /no human-factors, clinical-validation/);
});

test('CQL concept-template draft schema is required and versioned', () => {
  const { catalog, failures } = baseline();
  const id = 'parkinsum.cql-concept-template-draft';
  const schema = schemaById(catalog, id);
  const source = readFileSync('tool/cql_concept_template_preview.mjs', 'utf8');
  assert.equal(schema.currentVersion, 2);
  assert.equal(schema.surfaceKind, 'governance-artifact');
  assert.equal(schema.source, 'tool/cql_concept_template_preview.mjs');
  assert.match(source, /parkinsum\.cql-concept-template-draft\/2/);
  assert.ok(requiredSchemaSurfaces.some((required) => required.id === id));
  assert.ok(!failures.some((failure) => failure.includes(id)), failures.join('\n'));
});

test('personal-log handoff v3 records optional observation limits', () => {
  const { catalog } = baseline();
  const schema = schemaById(catalog, 'parkinsum.personal-log-handoff');
  assert.equal(schema.currentVersion, 3);
  assert.match(schema.compatibility, /omitted by default/);
  assert.match(schema.compatibility, /no trend, diagnosis/);
});

test('Encounter preview schema is registered without masking shared findings', () => {
  const { catalog, failures } = readAndValidateSchemaCatalog();
  assert.ok(catalog);
  const schema = schemaById(
    catalog,
    'parkinsum.fhir-r4-encounter-import-preview',
  );
  assert.equal(schema.currentVersion, 1);
  assert.equal(schema.versionStatus, 'versioned');
  assert.equal(
    schema.source,
    'lib/domain/entities/fhir_r4_encounter_import_preview.dart',
  );
  assert.match(schema.compatibility, /32 entries and 128 KiB input/);
  assert.match(
    schema.compatibility,
    /source status, Encounter\.class Coding fields and lexical period endpoints/,
  );
  assert.ok(
    requiredSchemaSurfaces.some(
      (surface) => surface.id === schema.id && surface.source === schema.source,
    ),
  );
  assert.ok(
    failures.every((failure) => !failure.includes(schema.id)),
    `new schema must not add catalog findings: ${failures.join('; ')}`,
  );
});

test('NutritionIntake preview is registered without masking shared findings', () => {
  const { catalog, failures } = readAndValidateSchemaCatalog();
  assert.ok(catalog);
  const schema = schemaById(
    catalog,
    'parkinsum.fhir-r5-nutrition-intake-preview',
  );
  assert.equal(schema.currentVersion, 1);
  assert.equal(
    schema.source,
    'lib/domain/usecases/fhir_r5_nutrition_intake_mapper.dart',
  );
  assert.ok(
    requiredSchemaSurfaces.some(
      (surface) =>
        surface.id === schema.id && surface.source === schema.source,
    ),
  );
  assert.ok(
    failures.every((failure) => !failure.includes(schema.id)),
    `new schema must not add catalog findings: ${failures.join('; ')}`,
  );
});

test('deleting the support-bundle entry fails required and source discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.privacy-safe-support-bundle',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.privacy-safe-support-bundle',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes('privacySafeSupportBundleSchemaVersion'),
    ),
  );
});

test('each gastric configuration surface is required and source-discovered', () => {
  const { catalog } = baseline();
  for (const id of [
    'parkinsum.gastric-emptying-configuration',
    'parkinsum.gastric-emptying-generator-structure',
    'parkinsum.gastric-emptying-output-contract',
  ]) {
    const mutated = structuredClone(catalog);
    mutated.schemas = mutated.schemas.filter((schema) => schema.id !== id);
    const failures = validateSchemaCatalog(mutated);
    assert.ok(
      failures.some((failure) =>
        failure.includes(`required schema surface is missing: ${id}`),
      ),
      `${id} should fail the independent required-surface gate`,
    );
    assert.ok(
      failures.some((failure) =>
        failure.includes(`discovered schema URI is not cataloged: ${id}/1`),
      ),
      `${id} should fail source URI discovery`,
    );
  }
});

test('gastric parameter semantic and schema-URI versions drift independently', () => {
  const { catalog } = baseline();

  const staleSemanticVersion = structuredClone(catalog);
  schemaById(
    staleSemanticVersion,
    'parkinsum.gastric-parameter-set',
  ).currentVersion = '2026.08.17-v2';
  assert.ok(
    validateSchemaCatalog(staleSemanticVersion).some((failure) =>
      failure.includes(
        'source version "2026.09.02-v3" does not match catalog "2026.08.17-v2"',
      ),
    ),
  );

  const wrongSchemaUriVersion = structuredClone(catalog);
  schemaById(
    wrongSchemaUriVersion,
    'parkinsum.gastric-parameter-set',
  ).schemaUriVersion = 2;
  const schemaFailures = validateSchemaCatalog(wrongSchemaUriVersion);
  assert.ok(
    schemaFailures.some((failure) =>
      failure.includes('source version 1 does not match catalog 2'),
    ),
  );
  assert.ok(
    schemaFailures.some((failure) =>
      failure.includes(
        'discovered schema URI parkinsum.gastric-parameter-set/1 disagrees with catalog',
      ),
    ),
  );
});

test('deleting the evidence-currency entry fails required and URI discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.evidence-currency-registry',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.evidence-currency-registry',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'discovered schema URI is not cataloged: parkinsum.evidence-currency-registry/1',
      ),
    ),
  );
});

test('evidence-currency runtime binding schema is versioned and source-pinned', () => {
  const { catalog, failures } = baseline();
  const id = 'parkinsum.evidence-currency-runtime-binding';
  const schema = schemaById(catalog, id);
  const source = readFileSync('lib/domain/entities/evidence_currency.dart', 'utf8');
  assert.equal(schema.currentVersion, 1);
  assert.equal(schema.surfaceKind, 'runtime-contract');
  assert.equal(schema.source, 'lib/domain/entities/evidence_currency.dart');
  assert.match(source, /parkinsum\.evidence-currency-runtime-binding\/1/);
  assert.ok(!failures.some((failure) => failure.includes(id)), failures.join('\n'));
});

test('deleting the evidence-currency runtime binding entry fails required and URI discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.evidence-currency-runtime-binding',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.evidence-currency-runtime-binding',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'discovered schema URI is not cataloged: parkinsum.evidence-currency-runtime-binding/1',
      ),
    ),
  );
});

test('deleting the evidence-synthesis entry fails required and URI discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.claim-evidence-synthesis-registry',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.claim-evidence-synthesis-registry',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'discovered schema URI is not cataloged: parkinsum.claim-evidence-synthesis-registry/2',
      ),
    ),
  );
});

test('deleting the portable package entry fails required and source discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.user-portable-data-package',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.user-portable-data-package',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes('userPortableDataPackageSchemaVersion'),
    ),
  );
});

test('deleting the portable owner token boundary fails required discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.portable-owner-token',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.portable-owner-token',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes('userPortableDataOwnerTokenSchemaVersion'),
    ),
  );
});

test('deleting a public schema-URI entry fails required and URI discovery', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas = mutated.schemas.filter(
    (schema) => schema.id !== 'parkinsum.algorithm-evaluation',
  );
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'required schema surface is missing: parkinsum.algorithm-evaluation',
      ),
    ),
  );
  assert.ok(
    failures.some((failure) =>
      failure.includes(
        'discovered schema URI is not cataloged: parkinsum.algorithm-evaluation/4',
      ),
    ),
  );
});

test('catalog version drift from production source fails closed', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  schemaById(mutated, 'parkinsum.algorithm-evaluation').currentVersion = 3;
  const failures = validateSchemaCatalog(mutated);
  assert.ok(
    failures.some(
      (failure) =>
        failure.includes('source version 4 does not match catalog 3') ||
        failure.includes('algorithm-evaluation/4 disagrees with catalog'),
    ),
  );
});

test('legacy migration versions are explicit, bounded, and source-discovered', () => {
  const { catalog } = baseline();
  const missing = structuredClone(catalog);
  delete schemaById(
    missing,
    'parkinsum.capability-activation-state',
  ).acceptedLegacyVersions;
  assert.ok(
    validateSchemaCatalog(missing).some((failure) =>
      failure.includes(
        'parkinsum.capability-activation-state/1 disagrees with catalog',
      ),
    ),
  );

  const invalid = structuredClone(catalog);
  schemaById(
    invalid,
    'parkinsum.capability-activation-state',
  ).acceptedLegacyVersions = [1, 2];
  assert.ok(
    validateSchemaCatalog(invalid).some((failure) =>
      failure.includes(
        'acceptedLegacyVersions must be unique positive integers below currentVersion',
      ),
    ),
  );
});

test('duplicate schema ids fail closed', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  mutated.schemas.push(
    structuredClone(
      schemaById(mutated, 'parkinsum.atomic-onboarding-commit'),
    ),
  );
  assert.ok(
    validateSchemaCatalog(mutated).some((failure) =>
      failure.includes('duplicate schema id: parkinsum.atomic-onboarding-commit'),
    ),
  );
});

test('missing, escaping, and non-Dart source paths fail closed', () => {
  const { catalog } = baseline();
  for (const badSource of [
    'lib/core/models/does_not_exist.dart',
    '../outside.dart',
    'lib/core/models/intake.json',
  ]) {
    const mutated = structuredClone(catalog);
    schemaById(mutated, 'parkinsum.intake-record').source = badSource;
    const failures = validateSchemaCatalog(mutated);
    assert.ok(
      failures.some(
        (failure) =>
          failure.includes('source does not exist') ||
          failure.includes('normalized relative lib/*.dart path'),
      ),
      `${badSource}: ${failures.join('\n')}`,
    );
  }
});

test('tool source is allowed only for a governance-artifact schema', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  schemaById(mutated, 'parkinsum.rxnorm-release-identity').surfaceKind =
    'public-envelope';
  assert.ok(
    validateSchemaCatalog(mutated).some((failure) =>
      failure.includes('tool/*.mjs is allowed only for governance-artifact'),
    ),
  );
});

test('unversioned boundaries cannot pretend to have a catalog version', () => {
  const { catalog } = baseline();
  const mutated = structuredClone(catalog);
  schemaById(mutated, 'parkinsum.cdss-database-web').currentVersion = 1;
  assert.ok(
    validateSchemaCatalog(mutated).some((failure) =>
      failure.includes('unversioned surfaces must use currentVersion null'),
    ),
  );
});

test('unsupported catalog versions and malformed schema collections fail without crashing', () => {
  const { catalog } = baseline();
  const future = structuredClone(catalog);
  future.catalogVersion = 3;
  assert.ok(
    validateSchemaCatalog(future).some((failure) =>
      failure.includes('catalogVersion must be 2'),
    ),
  );

  const malformed = { ...catalog, schemas: { unexpected: true } };
  assert.doesNotThrow(() => validateSchemaCatalog(malformed));
  assert.ok(
    validateSchemaCatalog(malformed).some((failure) =>
      failure.includes('schemas must be a non-empty array'),
    ),
  );
});
