import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  buildObservedInventory,
  normalizeSourceRepository,
  validateInfluenceInventory,
} from './open_source_influence_check.mjs';

const committed = JSON.parse(
  readFileSync('config/open_source_influence_inventory.json', 'utf8'),
);

function fixture() {
  const inventory = structuredClone(committed);
  return { inventory, observed: buildObservedInventory(inventory) };
}

function codes(inventory, observed) {
  return validateInfluenceInventory(inventory, observed).map(
    (item) => item.code,
  );
}

function sfntNameValues(relativePath, nameId = 5) {
  const bytes = readFileSync(relativePath);
  const tableCount = bytes.readUInt16BE(4);
  let nameTable = null;
  for (let index = 0; index < tableCount; index += 1) {
    const record = 12 + index * 16;
    if (bytes.toString('ascii', record, record + 4) === 'name') {
      nameTable = {
        offset: bytes.readUInt32BE(record + 8),
        length: bytes.readUInt32BE(record + 12),
      };
      break;
    }
  }
  assert.ok(nameTable, `${relativePath} must have a name table`);
  const { offset, length } = nameTable;
  assert.ok(offset + length <= bytes.length, `${relativePath} name table must be in bounds`);
  const storageOffset = offset + bytes.readUInt16BE(offset + 4);
  const recordCount = bytes.readUInt16BE(offset + 2);
  const versions = [];
  for (let index = 0; index < recordCount; index += 1) {
    const record = offset + 6 + index * 12;
    if (bytes.readUInt16BE(record + 6) !== nameId) continue;
    const platform = bytes.readUInt16BE(record);
    const size = bytes.readUInt16BE(record + 8);
    const start = storageOffset + bytes.readUInt16BE(record + 10);
    const raw = bytes.subarray(start, start + size);
    const isUnicode = platform === 0 || platform === 3;
    const value = isUnicode
      ? Array.from(
          { length: Math.floor(raw.length / 2) },
          (_, offset) => String.fromCharCode(raw.readUInt16BE(offset * 2)),
        ).join('')
      : raw.toString('latin1');
    versions.push(value.replace(/\0/g, '').trim());
  }
  return versions;
}

test('committed inventory covers every documented influence and release path', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  assert.equal(inventory.$schema, 'https://parkinsum.app/schemas/open-source-influence-inventory/v7');
  assert.equal(inventory.schemaVersion, 7);
  assert.equal(inventory.influences.length, 99);
  assert.equal(inventory.influences.filter((entry) => entry.transferStatus === 'concept_only').length, 89);
  assert.equal(inventory.releaseBoundary.developmentToolInfluenceIds.length, 5);
  assert.ok(inventory.influences.every((entry) => Array.isArray(entry.artifactLicenseEvidence)));
  assert.equal(
    inventory.influences.filter((entry) => entry.licenseStatus === 'unresolved').length,
    15,
  );
  assert.equal(inventory.review.legalApproval, 'not_requested_no_release_distribution');
  assert.ok(!inventory.discovery.excludedRepositories.includes(
    'github.com/microsoft/azure-healthcare-digital-quality-cql-sdk',
  ));
  for (const unpinnedLead of [
    'github.com/AHRQ-CDS/AHRQ-CDS-Connect-Authoring-Tool',
  ]) {
    assert.ok(inventory.discovery.excludedRepositories.includes(unpinnedLead));
  }
  const assetLicenseHolds = inventory.influences.flatMap((entry) =>
    entry.artifactLicenseEvidence.map((evidence) => ({ entry, evidence })),
  );
  assert.equal(assetLicenseHolds.length, 60);
  assert.equal(new Set(assetLicenseHolds.map(({ entry }) => entry.id)).size, 38);
  assert.equal(assetLicenseHolds.filter(({ evidence }) => evidence.licenseStatus === 'unresolved').length, 58);
  assert.ok(assetLicenseHolds.filter(({ evidence }) => evidence.licenseStatus === 'unresolved').every(({ evidence }) =>
    evidence.licenseStatus === 'unresolved' &&
    evidence.reviewStatus === 'not_reviewed' &&
    evidence.declaredSpdx === 'NOASSERTION' &&
    evidence.detectedSpdx === 'NOASSERTION',
  ));
  assert.ok(assetLicenseHolds.filter(({ evidence }) => evidence.artifactType === 'font_asset').every(({ evidence }) =>
    evidence.licenseStatus === 'machine_detected' &&
    evidence.reviewStatus === 'reviewed' &&
    evidence.declaredSpdx === 'OFL-1.1' &&
    evidence.detectedSpdx === 'OFL-1.1',
  ));
  assert.equal(
    observed.sourceRepositories.filter((repository) =>
      repository.startsWith('github.com/'),
    ).length,
    96,
  );
  assert.equal(
    observed.sourceRepositories.filter((repository) =>
      repository.startsWith('bitbucket.org/'),
    ).length,
    2,
  );
  assert.equal(
    observed.sourceRepositories.filter((repository) =>
      repository.startsWith('gitlab.com/'),
    ).length,
    1,
  );
  const newCdssInfluences = inventory.influences.filter((entry) =>
    [
      'ahrq_cds_cql_services',
      'two_stage_conformal_pd_reference',
      'cascade_conformal_pd_reference',
      'ahrq_cql_testing_framework',
      'arden2bytecode',
      'cds_hooks_sandbox',
      'cds4cpm_guide_reference',
      'cds4cpm_sandbox_reference',
      'cqf_ruler_reference',
      'cqframework_clinical_reasoning_reference',
      'reason_framework_cpg_execution_reference',
      'cqframework_cql_exec_fhir_reference',
      'cqframework_cql_execution_reference',
      'cqframework_cql_exec_vsac_reference',
      'cqframework_cql_studio_reference',
      'dikb_evidence_analytics_reference',
      'arcwell_research_platform_reference',
      'carepath_cds_specifications_reference',
      'food_drug_interaction_detector_reference',
      'grevaluator_guideline_recommendation_evaluator',
      'genpres_medication_order_entry_reference',
      'aria_polypharmacy_reference',
      'google_cql_engine_reference',
      'google_fhir_go_reference',
      'nutriken_clinical_nutrition_reference',
      'openmrs_module_drools_reference',
      'openmrs_ddi_knowledge_base_reference',
      'openemr_cdr_reference',
      'openehr_gdl_guideline_models',
      'openehr_gdl_tools',
      'opencds_core_reference',
      'opencds_example_reference',
      'openclinical_proformajs_reference',
      'open_triage_reference',
      'parkinson_progression_cdss_candidate',
      'prana_acute_care_cdss_reference',
      'pharmexpert_ddi_reference',
      'snomed_fhir_cds_service_reference',
      'srdc_smart_on_fhir_cds_reference',
      'tricc_reference',
      'neurolink_parkinson_screening_candidate',
      'drug_interact_fda_label_reference',
      'hl7_davinci_br_payer_reference',
      'hl7_davinci_br_provider_reference',
      'clinicdx_rag_cdss_reference',
      'clinicclaw_policy_gated_fhir_workflow_reference',
      'clincalc_clinical_calculator_reference',
      'con_gait_contestable_parkinson_cdss_reference',
      'fasteval_parkinsonism_motor_assessment_reference',
      'fully_open_meditron_llm_cdss_pipeline_reference',
      'langcare_mcp_fhir_cdss_reference',
      'md2skill_guideline_skill_library_reference',
      'microsoft_azure_healthcare_digital_quality_cql_sdk',
      'spice_2_server_reference',
    ].includes(entry.id),
  );
  assert.equal(newCdssInfluences.length, 54);
  const openEmr = inventory.influences.find(
    (entry) => entry.id === 'openemr_cdr_reference',
  );
  assert.equal(openEmr.pinnedCommit, 'e01d65b33858e82c11892471001dd3d9963a27bf');
  assert.equal(openEmr.declaredSpdx, 'GPL-3.0');
  assert.equal(openEmr.repositoryDetectedSpdx, 'GPL-3.0');
  assert.equal(openEmr.licenseStatus, 'machine_detected');
  assert.equal(openEmr.transferStatus, 'concept_only');
  assert.equal(openEmr.copyingAuthorized, false);
  assert.equal(openEmr.distributionAuthorized, false);
  assert.deepEqual(openEmr.localPaths, []);
  const twoStage = inventory.influences.find(
    (entry) => entry.id === 'two_stage_conformal_pd_reference',
  );
  assert.equal(twoStage.pinnedCommit, '4f9fbcd537b9bb0592638e843d9ca018fc34e681');
  assert.equal(twoStage.declaredSpdx, 'BSD-3-Clause-Clear');
  assert.equal(twoStage.repositoryDetectedSpdx, 'BSD-3-Clause-Clear');
  assert.equal(twoStage.transferStatus, 'concept_only');
  assert.deepEqual(twoStage.localPaths, []);
  assert.deepEqual(twoStage.artifactLicenseEvidence.map((evidence) => evidence.artifactType), ['report_asset']);
  assert.equal(twoStage.artifactLicenseEvidence[0].licenseStatus, 'unresolved');
  assert.equal(twoStage.artifactLicenseEvidence[0].reviewStatus, 'not_reviewed');
  assert.equal(twoStage.artifactLicenseEvidence[0].declaredSpdx, 'NOASSERTION');
  assert.equal(twoStage.artifactLicenseEvidence[0].detectedSpdx, 'NOASSERTION');
  assert.match(twoStage.reviewedConcepts.join(' '), /MLHC 2025\/PMLR.*631 UF Health inpatient admissions/i);
  assert.match(twoStage.reviewedConcepts.join(' '), /baseline\.json.*conformal_metrics\.json.*no patient-row source file/i);
  const prana = inventory.influences.find(
    (entry) => entry.id === 'prana_acute_care_cdss_reference',
  );
  assert.equal(prana.pinnedCommit, '11fd6cd52d561c428682866b70b187bcb18e7c40');
  assert.equal(prana.declaredSpdx, 'GPL-3.0');
  assert.equal(prana.repositoryDetectedSpdx, 'GPL-3.0');
  assert.equal(prana.transferStatus, 'concept_only');
  assert.deepEqual(prana.localPaths, []);
  assert.deepEqual(prana.artifactLicenseEvidence.map((evidence) => evidence.artifactType), ['clinical_rule_asset']);
  assert.equal(prana.artifactLicenseEvidence[0].licenseStatus, 'unresolved');
  assert.equal(prana.artifactLicenseEvidence[0].reviewStatus, 'not_reviewed');
  assert.equal(prana.artifactLicenseEvidence[0].declaredSpdx, 'NOASSERTION');
  assert.equal(prana.artifactLicenseEvidence[0].detectedSpdx, 'NOASSERTION');
  assert.match(prana.reviewedConcepts.join(' '), /NEWS2.*sepsis.*insulin/i);
  const cascade = inventory.influences.find(
    (entry) => entry.id === 'cascade_conformal_pd_reference',
  );
  assert.equal(cascade.pinnedCommit, '840ae293ac05dadb0d13d08c032c7db4bcf4ab21');
  assert.equal(cascade.declaredSpdx, 'BSD-3-Clause-Clear');
  assert.equal(cascade.repositoryDetectedSpdx, 'BSD-3-Clause-Clear');
  assert.equal(cascade.transferStatus, 'concept_only');
  assert.deepEqual(cascade.localPaths, []);
  assert.deepEqual(
    cascade.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['data_asset', 'report_asset'],
  );
  assert.ok(cascade.artifactLicenseEvidence.every((evidence) =>
    evidence.licenseStatus === 'unresolved' &&
    evidence.reviewStatus === 'not_reviewed' &&
    evidence.declaredSpdx === 'NOASSERTION' &&
    evidence.detectedSpdx === 'NOASSERTION',
  ));
  assert.match(cascade.reviewedConcepts.join(' '), /Venn-Abers.*conformal intervals.*levodopa-equivalent daily-dose/i);
  assert.match(cascade.reviewedConcepts.join(' '), /no data_1Y\.csv.*real Parkinson EHR dataset cannot be shared/i);
  assert.match(cascade.reviewedConcepts.join(' '), /\[2026\] \[XYZ\].*without authorizing reuse/i);
  const ahrqCqlTesting = inventory.influences.find(
    (entry) => entry.id === 'ahrq_cql_testing_framework',
  );
  assert.equal(ahrqCqlTesting.pinnedCommit, '60aae55fbab5cb7ad5aea8039e33148e42653954');
  assert.equal(ahrqCqlTesting.defaultBranch, 'master');
  assert.equal(ahrqCqlTesting.declaredSpdx, 'Apache-2.0');
  assert.equal(ahrqCqlTesting.repositoryDetectedSpdx, 'Apache-2.0');
  assert.equal(ahrqCqlTesting.transferStatus, 'concept_only');
  assert.deepEqual(ahrqCqlTesting.localPaths, []);
  assert.ok(!inventory.discovery.excludedRepositories.includes(
    'github.com/ahrq-cds/cql-testing-framework',
  ));
  assert.deepEqual(
    ahrqCqlTesting.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['clinical_rule_asset', 'data_asset', 'terminology_asset'],
  );
  assert.deepEqual(
    ahrqCqlTesting.artifactLicenseEvidence.map((evidence) => evidence.sourceLocator),
    [
      'https://github.com/AHRQ-CDS/CQL-Testing-Framework/tree/60aae55fbab5cb7ad5aea8039e33148e42653954/test/yaml/pain_r401/cql',
      'https://github.com/AHRQ-CDS/CQL-Testing-Framework/tree/60aae55fbab5cb7ad5aea8039e33148e42653954/test/yaml/pain_r401/tests',
      'https://github.com/AHRQ-CDS/CQL-Testing-Framework/tree/60aae55fbab5cb7ad5aea8039e33148e42653954/test/yaml/pain_r401/.vscache',
    ],
  );
  for (const evidence of ahrqCqlTesting.artifactLicenseEvidence) {
    assert.equal(evidence.licenseStatus, 'unresolved');
    assert.equal(evidence.reviewStatus, 'not_reviewed');
    assert.equal(evidence.declaredSpdx, 'NOASSERTION');
    assert.equal(evidence.detectedSpdx, 'NOASSERTION');
    assert.match(evidence.sourceLocator, /tree\/60aae55fbab5cb7ad5aea8039e33148e42653954\/test\/yaml\/pain_r401\//);
  }
  assert.match(ahrqCqlTesting.reviewedConcepts.join(' '), /version 2\.6\.1.*DSTU2.*STU3.*R4/i);
  const srdc = inventory.influences.find(
    (entry) => entry.id === 'srdc_smart_on_fhir_cds_reference',
  );
  assert.equal(srdc.pinnedCommit, '89ddcfb7347c5b51aa55de8296e472d571addf65');
  assert.equal(srdc.declaredSpdx, 'GPL-3.0');
  assert.equal(srdc.repositoryDetectedSpdx, 'GPL-3.0');
  assert.equal(srdc.licenseStatus, 'machine_detected');
  assert.equal(srdc.transferStatus, 'concept_only');
  assert.equal(srdc.copyingAuthorized, false);
  assert.equal(srdc.distributionAuthorized, false);
  assert.deepEqual(srdc.localPaths, []);
  assert.match(srdc.reviewedConcepts.join(' '), /CDS Hooks service discovery.*prefetch.*suggestions\/actions/i);
  assert.match(srdc.reviewedConcepts.join(' '), /LGPL-3\.0-or-later.*CC BY-NC-ND 3\.0/);
  assert.match(srdc.reviewedConcepts.join(' '), /not intended for real-world clinical decision-making/i);
  assert.deepEqual(
    srdc.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['clinical_rule_asset', 'model_asset'],
  );
  const snomed = inventory.influences.find(
    (entry) => entry.id === 'snomed_fhir_cds_service_reference',
  );
  assert.equal(snomed.declaredSpdx, 'Apache-2.0');
  assert.equal(snomed.repositoryDetectedSpdx, 'NOASSERTION');
  assert.deepEqual(
    snomed.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['clinical_rule_asset', 'terminology_asset'],
  );
  const additionalCdss = new Map(newCdssInfluences.map((entry) => [entry.id, entry]));
  const expectedAdditional = new Map([
    ['ahrq_cql_testing_framework', ['60aae55fbab5cb7ad5aea8039e33148e42653954', 'Apache-2.0', 'machine_detected']],
    ['arcwell_research_platform_reference', ['4be1ed002249b397698e1c588b1bbc81a0c28346', 'Apache-2.0', 'machine_detected']],
    ['dikb_evidence_analytics_reference', ['9ffd629db30c41ced224ff2afdf132ce9276ae3f', 'NOASSERTION', 'unresolved']],
    ['carepath_cds_specifications_reference', ['82839d8ef5f3d23306beaf072790cb08a379e4fa', 'Apache-2.0', 'machine_detected']],
    ['cascade_conformal_pd_reference', ['840ae293ac05dadb0d13d08c032c7db4bcf4ab21', 'BSD-3-Clause-Clear', 'machine_detected']],
    ['two_stage_conformal_pd_reference', ['4f9fbcd537b9bb0592638e843d9ca018fc34e681', 'BSD-3-Clause-Clear', 'machine_detected']],
    ['prana_acute_care_cdss_reference', ['11fd6cd52d561c428682866b70b187bcb18e7c40', 'GPL-3.0', 'machine_detected']],
    ['clinicclaw_policy_gated_fhir_workflow_reference', ['fe1378817c730f4de4fa6b4d92f95ed7fc49ce2e', 'Apache-2.0', 'machine_detected']],
    ['con_gait_contestable_parkinson_cdss_reference', ['3101558fa527cc3092cb2f7970a4d3ba78808b2d', 'MIT', 'machine_detected']],
    ['food_drug_interaction_detector_reference', ['c2147d44ae774681042530310a3fdb247ff176fb', 'NOASSERTION', 'unresolved']],
    ['grevaluator_guideline_recommendation_evaluator', ['769ad73ae6e715d989c652fed9f8bd9b66206cf4', 'AGPL-3.0', 'machine_detected']],
    ['aria_polypharmacy_reference', ['719693b93f9b9b32c1da8169caa1073e5bd816c3', 'MIT', 'machine_detected']],
    ['genpres_medication_order_entry_reference', ['9ab8234577075808c7a79475058790cbf37f43de', 'GPL-3.0', 'machine_detected']],
    ['nutriken_clinical_nutrition_reference', ['5eb45263b5478192f5452c474336f463829ef1ea', 'MIT', 'machine_detected']],
    ['parkinson_progression_cdss_candidate', ['bfe2c677ea5a9a42322a14f466564e56f8f8b9ad', 'NOASSERTION', 'unresolved']],
    ['pharmexpert_ddi_reference', ['facf0f5ad4404482a3163915699ad9fa45869692', 'MIT', 'machine_detected']],
    ['neurolink_parkinson_screening_candidate', ['9f12bbedcc3fac5bbde118ecfc9097ecc6227490', 'NOASSERTION', 'unresolved']],
    ['drug_interact_fda_label_reference', ['1d1f4129c623c49add57e3634fcea2a00771fbe6', 'MIT', 'machine_detected']],
    ['hl7_davinci_br_payer_reference', ['5afe15b8afa4450c8f28fe1df2fcf4834accce24', 'Apache-2.0', 'machine_detected']],
    ['hl7_davinci_br_provider_reference', ['9a3215241308467496a98efc020d89b621c1ac35', 'MIT', 'machine_detected']],
    ['langcare_mcp_fhir_cdss_reference', ['d3651b3c8cb940be47c5f376255dded4035a14b8', 'MIT', 'machine_detected']],
    ['md2skill_guideline_skill_library_reference', ['1e539eba7bff01b3a0a9abd3bd314398b42d2b89', 'NOASSERTION', 'unresolved']],
    ['microsoft_azure_healthcare_digital_quality_cql_sdk', ['c2f1335543d0e385104a42e028fc10141b729a9f', 'MIT', 'machine_detected']],
    ['fasteval_parkinsonism_motor_assessment_reference', ['5e7b08ecc8495f9c9a69bba7d224fad69f6fbd16', 'Apache-2.0', 'machine_detected']],
    ['fully_open_meditron_llm_cdss_pipeline_reference', ['65d23a58df15cffdc151fd366083cbe4e49615be', 'Apache-2.0', 'machine_detected']],
    ['clincalc_clinical_calculator_reference', ['6ed6201b7321cca179053907aaa7baacb2659355', 'NOASSERTION', 'unresolved']],
  ]);
  for (const [id, [commit, spdx, licenseStatus]] of expectedAdditional) {
    const entry = additionalCdss.get(id);
    assert.ok(entry, `missing additional CDSS influence: ${id}`);
    assert.equal(entry.pinnedCommit, commit);
    assert.equal(entry.declaredSpdx, spdx);
    assert.equal(entry.repositoryDetectedSpdx, spdx);
    assert.equal(entry.licenseStatus, licenseStatus);
    assert.equal(entry.transferStatus, 'concept_only');
    assert.equal(entry.copyingAuthorized, false);
    assert.equal(entry.distributionAuthorized, false);
    assert.deepEqual(entry.localPaths, []);
  }
  const clincalc = additionalCdss.get('clincalc_clinical_calculator_reference');
  assert.deepEqual(
    clincalc.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['clinical_rule_asset'],
  );
  assert.equal(clincalc.artifactLicenseEvidence[0].licenseStatus, 'unresolved');
  assert.equal(
    clincalc.artifactLicenseEvidence[0].sourceLocator,
    'https://github.com/pacharanero/clincalc/tree/6ed6201b7321cca179053907aaa7baacb2659355/src/calculators',
  );
  assert.match(clincalc.reviewedConcepts.join(' '), /compound expression AGPL-3\.0-or-later AND LGPL-3\.0-or-later/);
  assert.match(clincalc.reviewedConcepts.join(' '), /not a finished medical device/);

  const microsoftCqlSdk = additionalCdss.get(
    'microsoft_azure_healthcare_digital_quality_cql_sdk',
  );
  assert.deepEqual(
    microsoftCqlSdk.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['clinical_rule_asset', 'data_asset', 'terminology_asset'],
  );
  assert.ok(microsoftCqlSdk.artifactLicenseEvidence.every((evidence) =>
    evidence.licenseStatus === 'unresolved' &&
    evidence.reviewStatus === 'not_reviewed' &&
    evidence.declaredSpdx === 'NOASSERTION' &&
    evidence.detectedSpdx === 'NOASSERTION' &&
    evidence.localPaths.length === 0 &&
    evidence.sourceLocator.includes(microsoftCqlSdk.pinnedCommit),
  ));
  assert.match(microsoftCqlSdk.reviewedConcepts.join(' '), /parameterized PostgreSQL SQL.*FHIR R4 JSONB/i);
  assert.match(microsoftCqlSdk.reviewedConcepts.join(' '), /not a standalone point-of-care PlanDefinition service/i);
  assert.match(microsoftCqlSdk.reviewedConcepts.join(' '), /no source code, CQL, measure specification, terminology, fixture, or patient data was copied/i);
  const fastEval = additionalCdss.get('fasteval_parkinsonism_motor_assessment_reference');
  assert.deepEqual(fastEval.artifactTypesReviewed, [
    'api_contract',
    'documentation',
    'model_asset',
    'source_code',
    'ui_pattern',
  ]);
  assert.deepEqual(
    fastEval.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['model_asset'],
  );
  assert.ok(fastEval.artifactLicenseEvidence.every((evidence) =>
    evidence.licenseStatus === 'unresolved' &&
    evidence.reviewStatus === 'not_reviewed' &&
    evidence.declaredSpdx === 'NOASSERTION' &&
    evidence.detectedSpdx === 'NOASSERTION' &&
    evidence.localPaths.length === 0 &&
    evidence.sourceLocator.includes(fastEval.pinnedCommit),
  ));
  assert.match(fastEval.reviewedConcepts.join(' '), /video-based finger-tapping motor-assessment workflow.*not a validated CDSS/i);
  assert.match(fastEval.reviewedConcepts.join(' '), /original videos are not public.*institutional approval/i);
  assert.match(fastEval.reviewedConcepts.join(' '), /tests are not implemented/i);
  const openMeditron = additionalCdss.get('fully_open_meditron_llm_cdss_pipeline_reference');
  assert.deepEqual(openMeditron.artifactTypesReviewed, [
    'data_asset',
    'documentation',
    'model_asset',
    'source_code',
  ]);
  assert.deepEqual(
    openMeditron.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['data_asset', 'model_asset'],
  );
  assert.ok(openMeditron.artifactLicenseEvidence.every((evidence) =>
    evidence.licenseStatus === 'unresolved' &&
    evidence.reviewStatus === 'not_reviewed' &&
    evidence.declaredSpdx === 'NOASSERTION' &&
    evidence.detectedSpdx === 'NOASSERTION' &&
    evidence.localPaths.length === 0 &&
    evidence.sourceLocator.includes(openMeditron.pinnedCommit),
  ));
  assert.match(openMeditron.reviewedConcepts.join(' '), /LLM-based CDSS training and evaluation.*citation field is TODO/i);
  assert.match(openMeditron.reviewedConcepts.join(' '), /corpus has a research-use license.*not approved for clinical deployment/i);
  assert.match(openMeditron.reviewedConcepts.join(' '), /no source, data, model, or result was copied or executed/i);
  const clinicClaw = additionalCdss.get('clinicclaw_policy_gated_fhir_workflow_reference');
  assert.deepEqual(clinicClaw.artifactTypesReviewed, [
    'clinical_rule_asset',
    'data_asset',
    'documentation',
  ]);
  assert.deepEqual(
    clinicClaw.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['clinical_rule_asset', 'data_asset'],
  );
  assert.ok(clinicClaw.artifactLicenseEvidence.every((evidence) =>
    evidence.licenseStatus === 'unresolved' &&
    evidence.reviewStatus === 'not_reviewed' &&
    evidence.declaredSpdx === 'NOASSERTION' &&
    evidence.detectedSpdx === 'NOASSERTION' &&
    evidence.localPaths.length === 0,
  ));
  assert.match(
    clinicClaw.reviewedConcepts.join(' '),
    /research\/demo v0\.1\.0.*dev-mode passthrough.*not to deploy with real patient data.*self-reported and were not independently verified.*no source, policy, patient fixture, benchmark result, or model output was transferred/,
  );
  const conGait = additionalCdss.get('con_gait_contestable_parkinson_cdss_reference');
  assert.deepEqual(conGait.artifactTypesReviewed, [
    'clinical_rule_asset',
    'data_asset',
    'documentation',
    'model_asset',
    'report_asset',
    'source_code',
    'ui_pattern',
  ]);
  assert.deepEqual(
    conGait.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['clinical_rule_asset', 'data_asset', 'model_asset', 'report_asset'],
  );
  assert.ok(conGait.artifactLicenseEvidence.every((evidence) =>
    evidence.licenseStatus === 'unresolved' &&
    evidence.reviewStatus === 'not_reviewed' &&
    evidence.declaredSpdx === 'NOASSERTION' &&
    evidence.detectedSpdx === 'NOASSERTION' &&
    evidence.localPaths.length === 0,
  ));
  assert.match(
    conGait.reviewedConcepts.join(' '),
    /10-second gait windows.*contest-and-justify.*concept-only.*LLM API.*config\.py.*not reviewed or transferred/,
  );
  assert.match(
    additionalCdss
      .get('grevaluator_guideline_recommendation_evaluator')
      .reviewedConcepts.join(' '),
    /Docker-based prototype.*real-time clinical data.*no code, guideline asset, sample data, or clinical recommendation was transferred/,
  );
  const carepath = additionalCdss.get('carepath_cds_specifications_reference');
  assert.deepEqual(carepath.artifactTypesReviewed, [
    'api_contract',
    'clinical_rule_asset',
    'documentation',
  ]);
  assert.deepEqual(
    carepath.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['clinical_rule_asset'],
  );
  assert.equal(carepath.artifactLicenseEvidence[0].licenseStatus, 'unresolved');
  assert.equal(carepath.artifactLicenseEvidence[0].reviewStatus, 'not_reviewed');
  assert.match(
    carepath.reviewedConcepts.join(' '),
    /65 JSON service definitions, 13 Excel specifications, and 349 Mustache card templates.*clinical asset rights, which remain held.*no code, specification, rule, card, terminology, or data was transferred/,
  );
  const vsac = additionalCdss.get('cqframework_cql_exec_vsac_reference');
  assert.equal(vsac.pinnedCommit, 'fe7c19cc3e51095ec050b60486598023afa3ac98');
  assert.equal(vsac.declaredSpdx, 'Apache-2.0');
  assert.equal(vsac.repositoryDetectedSpdx, 'Apache-2.0');
  assert.equal(vsac.licenseStatus, 'machine_detected');
  assert.equal(vsac.transferStatus, 'concept_only');
  assert.equal(vsac.copyingAuthorized, false);
  assert.equal(vsac.distributionAuthorized, false);
  assert.deepEqual(vsac.localPaths, []);
  assert.ok(!inventory.releaseBoundary.developmentToolInfluenceIds.includes(vsac.id));
  assert.match(vsac.reviewedConcepts.join(' '), /UMLS API key and network access.*package is not installed or called/i);
  assert.match(
    additionalCdss.get('nutriken_clinical_nutrition_reference').reviewedConcepts.join(' '),
    /README adds academic\/research-only wording.*scope needs maintainer\/legal resolution/i,
  );
  assert.match(
    additionalCdss.get('food_drug_interaction_detector_reference').reviewedConcepts.join(' '),
    /one commit and no LICENSE.*open-source status unconfirmed/i,
  );
  const parkinsonHelper = inventory.influences.find(
    (entry) => entry.id === 'parkinson_helper_reference',
  );
  assert.equal(parkinsonHelper.pinnedCommit, '540235dcbef2891bdeebc9b05e20c9a0c7c16e34');
  assert.equal(parkinsonHelper.declaredSpdx, 'MIT');
  assert.equal(parkinsonHelper.repositoryDetectedSpdx, 'MIT');
  assert.equal(parkinsonHelper.licenseStatus, 'machine_detected');
  assert.equal(parkinsonHelper.transferStatus, 'concept_only');
  assert.deepEqual(parkinsonHelper.artifactLicenseEvidence, []);
  assert.match(parkinsonHelper.reviewedConcepts.join(' '), /medication schedules.*blood-pressure.*not a clinical interaction or recommendation engine/i);
  const drugInteract = additionalCdss.get('drug_interact_fda_label_reference');
  assert.deepEqual(drugInteract.artifactTypesReviewed, ['api_contract', 'documentation', 'source_code']);
  assert.deepEqual(drugInteract.artifactLicenseEvidence, []);
  assert.match(drugInteract.reviewedConcepts.join(' '), /five distinct lookup states.*does not grade severity.*no clinical recommendations/i);
  assert.match(drugInteract.reviewedConcepts.join(' '), /no interaction dataset is bundled.*not evidence of safety/i);
  const aria = additionalCdss.get('aria_polypharmacy_reference');
  assert.deepEqual(aria.artifactLicenseEvidence.map((evidence) => evidence.artifactType), ['clinical_rule_asset', 'data_asset']);
  assert.match(aria.reviewedConcepts.join(' '), /not independently validated clinical evidence.*beers_stopp\.json and renal_dosing\.json/i);
  const pharmExpert = additionalCdss.get('pharmexpert_ddi_reference');
  assert.deepEqual(pharmExpert.artifactLicenseEvidence.map((evidence) => evidence.artifactType), ['clinical_rule_asset', 'data_asset']);
  assert.match(pharmExpert.reviewedConcepts.join(' '), /MIT application code.*DDInter 2\.0 data declared CC BY-NC-SA 4\.0/i);
  const openMrsDdi = additionalCdss.get('openmrs_ddi_knowledge_base_reference');
  assert.equal(openMrsDdi.pinnedCommit, '7e2bd2c245bd33550ca1b14951d6955767026775');
  assert.equal(openMrsDdi.declaredSpdx, 'MPL-2.0');
  assert.equal(openMrsDdi.repositoryDetectedSpdx, 'NOASSERTION');
  assert.equal(openMrsDdi.licenseStatus, 'declared_not_machine_detected');
  assert.deepEqual(openMrsDdi.artifactLicenseEvidence.map((evidence) => evidence.artifactType), ['clinical_rule_asset', 'data_asset', 'terminology_asset']);
  assert.match(openMrsDdi.reviewedConcepts.join(' '), /CIEL crosswalk permission is for OpenMRS-supporting work.*do not resolve those separate data and terminology terms/i);
  const progression = additionalCdss.get('parkinson_progression_cdss_candidate');
  assert.deepEqual(progression.artifactLicenseEvidence.map((evidence) => evidence.artifactType), ['data_asset']);
  assert.match(progression.reviewedConcepts.join(' '), /no LICENSE.*not confirmed open source.*signed Data Use Agreement/i);
  const neuroLynk = additionalCdss.get('neurolink_parkinson_screening_candidate');
  assert.deepEqual(neuroLynk.artifactLicenseEvidence.map((evidence) => evidence.artifactType), ['data_asset', 'model_asset']);
  assert.match(neuroLynk.reviewedConcepts.join(' '), /no LICENSE.*rights are unconfirmed/i);
  const daVinciPayer = additionalCdss.get('hl7_davinci_br_payer_reference');
  assert.deepEqual(daVinciPayer.artifactLicenseEvidence.map((evidence) => evidence.artifactType), ['clinical_rule_asset']);
  assert.equal(daVinciPayer.artifactLicenseEvidence[0].licenseStatus, 'unresolved');
  assert.match(daVinciPayer.reviewedConcepts.join(' '), /payer-side CRD, DTR, and PAS.*PlanDefinition-derived scenarios.*no clinical rule validation/i);
  const daVinciProvider = additionalCdss.get('hl7_davinci_br_provider_reference');
  assert.deepEqual(daVinciProvider.artifactLicenseEvidence, []);
  assert.match(daVinciProvider.reviewedConcepts.join(' '), /provider-side HAPI FHIR JPA reference server.*not Parkinson nutrition rules/i);
  assert.ok(newCdssInfluences.filter((entry) => ![
    'cqframework_cql_exec_fhir_reference',
    'cqframework_cql_execution_reference',
    'google_cql_engine_reference',
    'google_fhir_go_reference',
  ].includes(entry.id)).every((entry) =>
    entry.transferStatus === 'concept_only' &&
    entry.copyingAuthorized === false &&
    entry.distributionAuthorized === false &&
    entry.localPaths.length === 0,
  ));
  const googleCql = inventory.influences.find(
    (entry) => entry.id === 'google_cql_engine_reference',
  );
  assert.equal(googleCql.transferStatus, 'development_linked');
  assert.equal(googleCql.copyingAuthorized, true);
  assert.equal(googleCql.distributionAuthorized, false);
  assert.deepEqual(googleCql.localPaths, [
    'tool/google_cql_differential/go.mod',
    'tool/google_cql_differential/go.sum',
  ]);
  assert.deepEqual(googleCql.obligations, [
    'dependency_lock',
    'development_only',
    'license_notice',
  ]);
  assert.deepEqual(
    inventory.influences
      .filter((entry) => ['copied', 'derived', 'linked', 'vendored'].includes(entry.transferStatus))
      .map((entry) => entry.id),
    ['adobe_source_serif_font_assets', 'flutter_framework', 'flutter_local_notifications', 'share_plus', 'vercel_geist_font_assets'],
  );
  assert.deepEqual(
    inventory.releaseBoundary.developmentToolInfluenceIds,
    ['cqframework_cql_exec_fhir_reference', 'cqframework_cql_execution_reference', 'cqframework_cql_reference', 'google_cql_engine_reference', 'google_fhir_go_reference'],
  );
  assert.deepEqual(
    Object.keys(inventory.releaseBoundary.linkedVersionEvidence),
    ['flutter_framework', 'flutter_local_notifications', 'share_plus', 'adobe_source_serif_font_assets', 'vercel_geist_font_assets', 'cqframework_cql_exec_fhir_reference', 'cqframework_cql_execution_reference', 'cqframework_cql_reference', 'google_cql_engine_reference', 'google_fhir_go_reference'],
  );
});

test('CQF CQL JVM reference is linked only to locked development tooling', () => {
  const { inventory, observed } = fixture();
  const cqf = inventory.influences.find((entry) => entry.id === 'cqframework_cql_reference');
  assert.equal(cqf.officialUrl, 'https://github.com/cqframework/clinical_quality_language');
  assert.equal(cqf.pinnedCommit, '88693baefa482ec6f189c90113cfe1f3f4ce9d31');
  assert.equal(cqf.declaredSpdx, 'Apache-2.0');
  assert.equal(cqf.repositoryDetectedSpdx, 'Apache-2.0');
  assert.equal(cqf.transferStatus, 'development_linked');
  assert.equal(cqf.copyingAuthorized, true);
  assert.equal(cqf.distributionAuthorized, false);
  assert.deepEqual(cqf.localPaths, [
    'package-lock.json',
    'package.json',
    'tool/cqf_jvm_cql_differential/build.gradle',
    'tool/cqf_jvm_cql_differential/gradle.lockfile',
  ]);
  assert.deepEqual(cqf.obligations, ['dependency_lock', 'development_only', 'license_notice']);
  assert.deepEqual(
    inventory.releaseBoundary.linkedVersionEvidence.cqframework_cql_reference,
    {
      version: '5.3.0',
      versionSource: 'tool/cqf_jvm_cql_differential/build.gradle',
      sourceRevision: '88693baefa482ec6f189c90113cfe1f3f4ce9d31',
    },
  );
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
});

test('CQF JavaScript execution and FHIR data-source packages are pinned development-only dependencies', () => {
  const { inventory, observed } = fixture();
  const expected = [
    {
      id: 'cqframework_cql_execution_reference',
      commit: '1991335e7ad490a8db88a05dd7f03dc3eecbda6d',
      version: '3.3.2',
    },
    {
      id: 'cqframework_cql_exec_fhir_reference',
      commit: 'f3f9a968d597e2f029533a9e5cb1e6a643f2f69a',
      version: '2.1.6',
    },
  ];
  for (const { id, commit, version } of expected) {
    const entry = inventory.influences.find((candidate) => candidate.id === id);
    assert.equal(entry.pinnedCommit, commit);
    assert.equal(entry.licenseStatus, 'machine_detected');
    assert.equal(entry.declaredSpdx, 'Apache-2.0');
    assert.equal(entry.transferStatus, 'development_linked');
    assert.equal(entry.copyingAuthorized, true);
    assert.equal(entry.distributionAuthorized, false);
    assert.deepEqual(entry.localPaths, ['package-lock.json', 'package.json']);
    assert.deepEqual(entry.obligations, ['dependency_lock', 'development_only', 'license_notice']);
    assert.deepEqual(inventory.releaseBoundary.linkedVersionEvidence[id], {
      version,
      versionSource: 'package.json',
      sourceRevision: commit,
    });
  }
  const fhir = inventory.influences.find((candidate) => candidate.id === 'cqframework_cql_exec_fhir_reference');
  assert.match(fhir.reviewedConcepts.join(' '), /does not scope Observation\.subject.*filters foreign subjects/i);
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
});

test('share_plus is release-linked at its pinned version and source commit', () => {
  const { inventory, observed } = fixture();
  const share = inventory.influences.find((entry) => entry.id === 'share_plus');
  assert.equal(share.officialUrl, 'https://github.com/fluttercommunity/plus_plugins');
  assert.equal(share.pinnedCommit, '2c5b4935c85fdbfeffea2bd68c9286c064ed8b7c');
  assert.equal(share.declaredSpdx, 'BSD-3-Clause');
  assert.equal(share.repositoryDetectedSpdx, 'BSD-3-Clause');
  assert.equal(share.licenseStatus, 'machine_detected');
  assert.equal(share.transferStatus, 'linked');
  assert.equal(share.copyingAuthorized, true);
  assert.equal(share.distributionAuthorized, true);
  assert.deepEqual(share.localPaths, ['pubspec.lock', 'pubspec.yaml']);
  assert.deepEqual(share.obligations, [
    'dependency_lock',
    'generated_license_bundle',
    'license_notice',
  ]);
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
});

test('Google CQL development linkage cannot leak into release dependency inventory', () => {
  const { inventory, observed } = fixture();
  const google = inventory.influences.find(
    (entry) => entry.id === 'google_cql_engine_reference',
  );
  assert.equal(google.officialUrl, 'https://github.com/google/cql');
  assert.equal(google.pinnedCommit, 'b9169ccd54a3a8b0ac928aff338b9f7d6a4b163a');
  assert.equal(google.licenseStatus, 'machine_detected');
  assert.equal(google.declaredSpdx, 'Apache-2.0');
  assert.equal(google.repositoryDetectedSpdx, 'Apache-2.0');
  inventory.releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds.push(google.id);
  assert(codes(inventory, observed).includes('development_tool_in_release_boundary'));
});

test('Google FhirProto Go module is pinned and development-only for the local retrieval probe', () => {
  const { inventory, observed } = fixture();
  const fhir = inventory.influences.find(
    (entry) => entry.id === 'google_fhir_go_reference',
  );
  assert.equal(fhir.officialUrl, 'https://github.com/google/fhir');
  assert.equal(fhir.pinnedCommit, '31c3b614b7bf203c9b1d53306688b3bd6984e11d');
  assert.equal(fhir.licenseStatus, 'machine_detected');
  assert.equal(fhir.declaredSpdx, 'Apache-2.0');
  assert.equal(fhir.repositoryDetectedSpdx, 'Apache-2.0');
  assert.equal(fhir.transferStatus, 'development_linked');
  assert.equal(fhir.copyingAuthorized, true);
  assert.equal(fhir.distributionAuthorized, false);
  assert.deepEqual(fhir.localPaths, [
    'tool/google_cql_differential/go.mod',
    'tool/google_cql_differential/go.sum',
  ]);
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
});

test('development-linked tools require no release distribution and all dev obligations', () => {
  const { inventory, observed } = fixture();
  const google = inventory.influences.find(
    (entry) => entry.id === 'google_cql_engine_reference',
  );
  google.distributionAuthorized = true;
  assert(codes(inventory, observed).includes('development_transfer_not_authorized'));

  for (const obligation of ['dependency_lock', 'development_only', 'license_notice']) {
    const next = fixture();
    const entry = next.inventory.influences.find(
      (candidate) => candidate.id === 'google_cql_engine_reference',
    );
    entry.obligations = entry.obligations.filter((value) => value !== obligation);
    assert(codes(next.inventory, next.observed).includes('missing_development_obligation'));
  }

  const boundary = fixture();
  boundary.inventory.releaseBoundary.developmentToolInfluenceIds = [];
  const result = codes(boundary.inventory, boundary.observed);
  assert(result.includes('development_boundary_omission'));
  assert(result.includes('development_boundary_identity_drift'));

  const staleLegalScope = fixture();
  staleLegalScope.inventory.review.legalApproval = 'not_requested_concept_only';
  assert(codes(staleLegalScope.inventory, staleLegalScope.observed).includes('unsupported_legal_approval'));
});

test('pinned Arden and openEHR references preserve exact license evidence and concept-only status', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const expected = {
    arden2bytecode: {
      commit: '9263f86944a5ebab2a8e5b038d534107d735c806',
      declared: 'GPL-3.0-only',
      detected: 'NOASSERTION',
      status: 'declared_not_machine_detected',
    },
    openehr_gdl_guideline_models: {
      commit: 'f11cfd534d6fb4bd5def85b0c96d6ed17a5defe0',
      declared: 'Apache-2.0',
      detected: 'Apache-2.0',
      status: 'machine_detected',
    },
    openehr_gdl_tools: {
      commit: '15911c891dfae363c60f81e47cbbd10b257c038f',
      declared: 'MPL-2.0',
      detected: 'NOASSERTION',
      status: 'declared_not_machine_detected',
    },
  };
  for (const [id, values] of Object.entries(expected)) {
    const entry = inventory.influences.find((candidate) => candidate.id === id);
    assert.ok(entry, `missing pinned influence: ${id}`);
    assert.equal(entry.pinnedCommit, values.commit);
    assert.equal(entry.declaredSpdx, values.declared);
    assert.equal(entry.repositoryDetectedSpdx, values.detected);
    assert.equal(entry.licenseStatus, values.status);
    assert.equal(entry.transferStatus, 'concept_only');
    assert.equal(entry.copyingAuthorized, false);
    assert.equal(entry.distributionAuthorized, false);
    assert.deepEqual(entry.localPaths, []);
  }
});

test('font source pins, internal versions, and transferred paths stay explicit', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  assert.deepEqual(inventory.discovery.roots, [
    'assets',
    'config/complete_app_upgrade_queue.json',
    'docs',
    'lib',
    'pubspec.yaml',
    'tool',
  ]);
  const adobe = inventory.influences.find(
    (entry) => entry.id === 'adobe_source_serif_font_assets',
  );
  const vercel = inventory.influences.find(
    (entry) => entry.id === 'vercel_geist_font_assets',
  );
  const googleFonts = inventory.influences.find(
    (entry) => entry.id === 'google_fonts_collection_reference',
  );
  assert.equal(adobe.pinnedCommit, 'a9eaef81588dddd479f2275d87b3707ed7ae2847');
  assert.equal(adobe.transferStatus, 'derived');
  assert.equal(adobe.artifactLicenseEvidence[0].declaredSpdx, 'OFL-1.1');
  assert.deepEqual(adobe.localPaths, adobe.artifactLicenseEvidence[0].localPaths);
  assert.equal(vercel.pinnedCommit, '91158e012bdc4abd59fa066d0eae9fc11c2c9f24');
  assert.equal(vercel.transferStatus, 'derived');
  assert.equal(vercel.artifactLicenseEvidence[0].declaredSpdx, 'OFL-1.1');
  assert.deepEqual(vercel.localPaths, vercel.artifactLicenseEvidence[0].localPaths);
  assert.ok(vercel.obligations.includes('reserved_font_name_resolution'));
  assert.deepEqual(googleFonts.localPaths, []);
  assert.equal(googleFonts.declaredSpdx, 'NOASSERTION');
  assert.equal(googleFonts.licenseStatus, 'unresolved');
  assert.equal(googleFonts.transferStatus, 'concept_only');

  const pubspec = readFileSync('pubspec.yaml', 'utf8');
  assert.match(pubspec, /Geist 1\.800; Geist Mono 1\.701/);
  assert.match(pubspec, /Source Serif 4 4\.004/);
  for (const relativePath of vercel.localPaths.filter((value) => value.endsWith('.ttf'))) {
    const expectedVersion = relativePath.includes('GeistMono-')
      ? 'Version 1.701'
      : 'Version 1.800';
    assert.ok(
      sfntNameValues(relativePath).some((value) => value.includes(expectedVersion)),
      `${relativePath} must match its reviewed internal font version`,
    );
  }
  for (const relativePath of adobe.localPaths.filter((value) => value.endsWith('.ttf'))) {
    assert.ok(
      sfntNameValues(relativePath).some((value) => value.includes('Version 4.004')),
      `${relativePath} must match the reviewed Source Serif version`,
    );
    assert.ok(sfntNameValues(relativePath, 1).every((value) => value === 'Parkin Serif Display'));
    for (const nameId of [3, 4, 6]) {
      assert.ok(sfntNameValues(relativePath, nameId).every((value) => !value.includes('Source')));
    }
    assert.ok(sfntNameValues(relativePath, 0).some((value) => value.includes('Reserved Font Name')));
  }
  assert.match(readFileSync('assets/fonts/OFL-SourceSerif4.txt', 'utf8'), /with Reserved Font Name 'Source'/);
});

test('every transferred font path is scoped and reserved-name review stays required', () => {
  const missingEntryPath = fixture();
  const geist = missingEntryPath.inventory.influences.find(
    (entry) => entry.id === 'vercel_geist_font_assets',
  );
  geist.localPaths.pop();
  assert(
    codes(missingEntryPath.inventory, missingEntryPath.observed).includes(
      'unscoped_asset_transfer_path',
    ),
  );

  const missingEvidencePath = fixture();
  const adobe = missingEvidencePath.inventory.influences.find(
    (entry) => entry.id === 'adobe_source_serif_font_assets',
  );
  adobe.artifactLicenseEvidence[0].localPaths.pop();
  assert(
    codes(missingEvidencePath.inventory, missingEvidencePath.observed).includes(
      'unscoped_asset_transfer_path',
    ),
  );

  const omittedReview = fixture();
  const sourceSerif = omittedReview.inventory.influences.find(
    (entry) => entry.id === 'adobe_source_serif_font_assets',
  );
  sourceSerif.obligations = ['license_notice'];
  assert(
    codes(omittedReview.inventory, omittedReview.observed).includes(
      'missing_license_obligation',
    ),
  );
});

test('each transferred font and license file has one pinned file-level record', () => {
  const { inventory, observed } = fixture();
  const records = inventory.assetFileLicenseEvidence;
  assert.equal(records.length, 14);
  assert.deepEqual(
    records.map((record) => record.assetPath),
    [...records.map((record) => record.assetPath)].sort((left, right) =>
      left.localeCompare(right),
    ),
  );
  assert.equal(new Set(records.map((record) => record.assetPath)).size, 14);
  assert.ok(records.every((record) => /^[0-9a-f]{64}$/.test(record.assetSha256)));
  assert.ok(records.every((record) => record.artifactType === 'font_asset'));
  assert.ok(records.every((record) => record.pinnedCommit.length === 40));
  assert.ok(records.every((record) => record.licenseStatus === 'machine_detected'));
  assert.ok(records.every((record) => record.reviewStatus === 'reviewed'));
  assert.ok(records.filter((record) => record.assetRole === 'font_binary').every(
    (record) =>
      record.derivationStatus ===
        'derived_static_font_source_equivalence_unverified' &&
      record.noticePaths.length === 1,
  ));
  assert.ok(records.filter((record) => record.assetRole === 'license_text').every(
    (record) =>
      record.derivationStatus ===
        'copied_license_text_source_equivalence_unverified' &&
      record.noticePaths.length === 0,
  ));
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
});

test('file-level asset licensing fails closed on coverage, identity, bytes, and notice drift', () => {
  const missing = fixture();
  missing.inventory.assetFileLicenseEvidence.pop();
  assert(codes(missing.inventory, missing.observed).includes('asset_file_license_coverage_drift'));

  const duplicate = fixture();
  duplicate.inventory.assetFileLicenseEvidence.push(
    structuredClone(duplicate.inventory.assetFileLicenseEvidence[0]),
  );
  assert(codes(duplicate.inventory, duplicate.observed).includes('duplicate_asset_file_license_record'));

  const changedBytes = fixture();
  changedBytes.inventory.assetFileLicenseEvidence[0].assetSha256 = '0'.repeat(64);
  assert(codes(changedBytes.inventory, changedBytes.observed).includes('asset_file_digest_mismatch'));

  const changedPin = fixture();
  changedPin.inventory.assetFileLicenseEvidence[0].pinnedCommit = 'f'.repeat(40);
  assert(codes(changedPin.inventory, changedPin.observed).includes('asset_file_license_source_mismatch'));

  const pathEscape = fixture();
  pathEscape.inventory.assetFileLicenseEvidence[0].assetPath = '../package.json';
  assert(codes(pathEscape.inventory, pathEscape.observed).includes('invalid_asset_file_path'));

  const wrongNotice = fixture();
  wrongNotice.inventory.assetFileLicenseEvidence[0].noticePaths = [
    'assets/fonts/OFL-SourceSerif4.txt',
  ];
  assert(codes(wrongNotice.inventory, wrongNotice.observed).includes('invalid_asset_license_notice_link'));
});

test('supported source URL normalization preserves host and collapses path aliases', () => {
  assert.equal(
    normalizeSourceRepository(
      'https://github.com/FriesI23/mhabit/blob/main/LICENSE',
    ),
    'github.com/friesi23/mhabit',
  );
  assert.equal(
    normalizeSourceRepository('https://github.com/FriesI23/mhabit.git'),
    'github.com/friesi23/mhabit',
  );
  assert.equal(
    normalizeSourceRepository(
      'https://bitbucket.org/OpenCDS/opencds-example/src/master/pom.xml',
    ),
    'bitbucket.org/opencds/opencds-example',
  );
  assert.equal(
    normalizeSourceRepository('https://bitbucket.org/OpenCDS/opencds.git'),
    'bitbucket.org/opencds/opencds',
  );
  assert.equal(
    normalizeSourceRepository(
      'https://gitlab.com/OpenClinical/ProformaJS/-/blob/main/LICENSE.GPL',
    ),
    'gitlab.com/openclinical/proformajs',
  );
});

test('PROformajs stays a pinned GitLab GPL concept-only reference with separate example asset holds', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const entry = inventory.influences.find(
    (candidate) => candidate.id === 'openclinical_proformajs_reference',
  );
  assert.ok(entry);
  assert.equal(entry.officialUrl, 'https://gitlab.com/openclinical/proformajs');
  assert.equal(entry.pinnedCommit, '642e8559ab67cfdc11ef156b96f4af13bbc62548');
  assert.equal(entry.defaultBranch, 'main');
  assert.equal(entry.declaredSpdx, 'GPL-3.0');
  assert.equal(entry.repositoryDetectedSpdx, 'NOASSERTION');
  assert.equal(entry.licenseStatus, 'declared_not_machine_detected');
  assert.equal(entry.transferStatus, 'concept_only');
  assert.equal(entry.copyingAuthorized, false);
  assert.equal(entry.distributionAuthorized, false);
  assert.deepEqual(entry.localPaths, []);
  assert.deepEqual(entry.artifactLicenseEvidence, [
    {
      artifactType: 'clinical_rule_asset',
      assetScope: 'all_assets_of_type_at_pinned_revision',
      declaredSpdx: 'NOASSERTION',
      detectedSpdx: 'NOASSERTION',
      licenseStatus: 'unresolved',
      reviewStatus: 'not_reviewed',
      sourceLocator:
        'https://gitlab.com/openclinical/proformajs/-/tree/642e8559ab67cfdc11ef156b96f4af13bbc62548/etc',
      obligations: [],
      localPaths: [],
    },
  ]);
});

test('OpenCDS repositories retain exact Bitbucket pins and declared-only Apache evidence', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const expected = {
    opencds_core_reference: {
      url: 'https://bitbucket.org/opencds/opencds',
      commit: 'c14c8d8313737c23fe9f4fece56b0322355bce6d',
    },
    opencds_example_reference: {
      url: 'https://bitbucket.org/opencds/opencds-example',
      commit: '322a775f08e11e66206160d828ae417179513528',
    },
  };
  for (const [id, values] of Object.entries(expected)) {
    const entry = inventory.influences.find((candidate) => candidate.id === id);
    assert.ok(entry, `missing pinned influence: ${id}`);
    assert.equal(entry.officialUrl, values.url);
    assert.equal(entry.pinnedCommit, values.commit);
    assert.equal(entry.defaultBranch, 'master');
    assert.equal(entry.declaredSpdx, 'Apache-2.0');
    assert.equal(entry.repositoryDetectedSpdx, 'NOASSERTION');
    assert.equal(entry.licenseStatus, 'declared_not_machine_detected');
    assert.equal(entry.transferStatus, 'concept_only');
    assert.equal(entry.copyingAuthorized, false);
    assert.equal(entry.distributionAuthorized, false);
    assert.deepEqual(entry.localPaths, []);
  }
});

test('openTriage is pinned as GPL-3.0 concept-only with current repository metadata', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const entry = inventory.influences.find(
    (candidate) => candidate.id === 'open_triage_reference',
  );
  assert.ok(entry);
  assert.equal(entry.officialUrl, 'https://github.com/dnspangler/openTriage');
  assert.equal(entry.pinnedCommit, '7644ca32c7c4ee19de57f70173630bde74de3471');
  assert.equal(entry.defaultBranch, 'master');
  assert.equal(entry.declaredSpdx, 'GPL-3.0');
  assert.equal(entry.repositoryDetectedSpdx, 'GPL-3.0');
  assert.equal(entry.licenseStatus, 'machine_detected');
  assert.equal(entry.transferStatus, 'concept_only');
  assert.equal(entry.copyingAuthorized, false);
  assert.equal(entry.distributionAuthorized, false);
  assert.deepEqual(entry.localPaths, []);
});

test('CDS4CPM guide and sandbox are pinned as Apache-2.0 concept-only references', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const expected = {
    cds4cpm_guide_reference: {
      url: 'https://github.com/cqframework/cds4cpm',
      commit: 'e73c2d2953aaad08f09428a6e70d5a07c5c7db31',
    },
    cds4cpm_sandbox_reference: {
      url: 'https://github.com/DBCG/cds4cpm-sandbox',
      commit: '9266b4137e47d7a84553b3040dfc2c12e9e6d3f9',
    },
  };
  for (const [id, values] of Object.entries(expected)) {
    const entry = inventory.influences.find((candidate) => candidate.id === id);
    assert.ok(entry, `missing pinned influence: ${id}`);
    assert.equal(entry.officialUrl, values.url);
    assert.equal(entry.pinnedCommit, values.commit);
    assert.equal(entry.defaultBranch, 'master');
    assert.equal(entry.declaredSpdx, 'Apache-2.0');
    assert.equal(entry.repositoryDetectedSpdx, 'Apache-2.0');
    assert.equal(entry.licenseStatus, 'machine_detected');
    assert.equal(entry.transferStatus, 'concept_only');
    assert.equal(entry.copyingAuthorized, false);
    assert.equal(entry.distributionAuthorized, false);
    assert.deepEqual(entry.localPaths, []);
  }
});

test('Reason Framework stays a pinned FHIR R5 concept-only reference', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const entry = inventory.influences.find(
    (candidate) => candidate.id === 'reason_framework_cpg_execution_reference',
  );
  assert.ok(entry);
  assert.equal(entry.officialUrl, 'https://github.com/reason-healthcare/reason-framework');
  assert.equal(entry.pinnedCommit, '2e8d91daf360f184e6c98f700031414829c64921');
  assert.equal(entry.defaultBranch, 'main');
  assert.equal(entry.declaredSpdx, 'MIT');
  assert.equal(entry.repositoryDetectedSpdx, 'MIT');
  assert.equal(entry.licenseStatus, 'machine_detected');
  assert.deepEqual(entry.artifactTypesReviewed, ['api_contract', 'documentation']);
  assert(entry.reviewedConcepts.some((value) => value.includes('FHIR R5 ActivityDefinition/$apply and PlanDefinition/$apply')));
  assert.equal(entry.transferStatus, 'concept_only');
  assert.equal(entry.copyingAuthorized, false);
  assert.equal(entry.distributionAuthorized, false);
  assert.deepEqual(entry.localPaths, []);
  assert.deepEqual(entry.artifactLicenseEvidence, []);
});

test('LangCare stays a pinned FHIR MCP workflow reference with separate skill-content hold', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const entry = inventory.influences.find(
    (candidate) => candidate.id === 'langcare_mcp_fhir_cdss_reference',
  );
  assert.ok(entry);
  assert.equal(entry.officialUrl, 'https://github.com/langcare/langcare-mcp-fhir');
  assert.equal(entry.pinnedCommit, 'd3651b3c8cb940be47c5f376255dded4035a14b8');
  assert.equal(entry.defaultBranch, 'main');
  assert.equal(entry.declaredSpdx, 'MIT');
  assert.equal(entry.repositoryDetectedSpdx, 'MIT');
  assert.equal(entry.licenseStatus, 'machine_detected');
  assert.equal(entry.transferStatus, 'concept_only');
  assert.equal(entry.copyingAuthorized, false);
  assert.equal(entry.distributionAuthorized, false);
  assert.deepEqual(entry.localPaths, []);
  assert(entry.reviewedConcepts.some((value) => value.includes('search, read, create, and update tools')));
  assert.deepEqual(entry.artifactLicenseEvidence.map((evidence) => evidence.artifactType), [
    'clinical_rule_asset',
  ]);
  const skillEvidence = entry.artifactLicenseEvidence[0];
  assert.equal(skillEvidence.licenseStatus, 'unresolved');
  assert.equal(skillEvidence.reviewStatus, 'not_reviewed');
  assert.equal(skillEvidence.declaredSpdx, 'NOASSERTION');
  assert.equal(skillEvidence.detectedSpdx, 'NOASSERTION');
  assert.equal(
    skillEvidence.sourceLocator,
    'https://github.com/langcare/langcare-mcp-fhir/tree/d3651b3c8cb940be47c5f376255dded4035a14b8/skills',
  );
  assert.deepEqual(skillEvidence.localPaths, []);
});

test('MD2SKILL stays pinned as an unresolved guideline-skill library reference', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const entry = inventory.influences.find(
    (candidate) => candidate.id === 'md2skill_guideline_skill_library_reference',
  );
  assert.ok(entry);
  assert.equal(entry.officialUrl, 'https://github.com/dromlakhani/MD2SKILL');
  assert.equal(entry.pinnedCommit, '1e539eba7bff01b3a0a9abd3bd314398b42d2b89');
  assert.equal(entry.defaultBranch, 'main');
  assert.equal(entry.declaredSpdx, 'NOASSERTION');
  assert.equal(entry.repositoryDetectedSpdx, 'NOASSERTION');
  assert.equal(entry.licenseStatus, 'unresolved');
  assert.equal(entry.transferStatus, 'concept_only');
  assert.equal(entry.copyingAuthorized, false);
  assert.equal(entry.distributionAuthorized, false);
  assert.deepEqual(entry.localPaths, []);
  assert.match(entry.reviewedConcepts.join(' '), /README claims MIT.*no separate license file/i);
  assert.deepEqual(entry.artifactLicenseEvidence.map((evidence) => evidence.artifactType), [
    'clinical_rule_asset',
  ]);
  const skillEvidence = entry.artifactLicenseEvidence[0];
  assert.equal(skillEvidence.licenseStatus, 'unresolved');
  assert.equal(skillEvidence.reviewStatus, 'not_reviewed');
  assert.equal(skillEvidence.declaredSpdx, 'NOASSERTION');
  assert.equal(skillEvidence.detectedSpdx, 'NOASSERTION');
  assert.equal(
    skillEvidence.sourceLocator,
    'https://github.com/dromlakhani/MD2SKILL/tree/1e539eba7bff01b3a0a9abd3bd314398b42d2b89/skills',
  );
  assert.deepEqual(skillEvidence.localPaths, []);
});

test('ClinicDx and SPICE stay pinned concept-only CDSS references with separate asset holds', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const clinicDx = inventory.influences.find(
    (entry) => entry.id === 'clinicdx_rag_cdss_reference',
  );
  assert.ok(clinicDx);
  assert.equal(clinicDx.pinnedCommit, '1e329e903f297942160184dbf484874c33bd5e52');
  assert.equal(clinicDx.defaultBranch, 'main');
  assert.equal(clinicDx.declaredSpdx, 'CC-BY-4.0');
  assert.equal(clinicDx.repositoryDetectedSpdx, 'CC-BY-4.0');
  assert.equal(clinicDx.licenseStatus, 'machine_detected');
  assert.deepEqual(clinicDx.artifactTypesReviewed, [
    'clinical_rule_asset',
    'data_asset',
    'documentation',
    'model_asset',
  ]);
  assert.equal(clinicDx.transferStatus, 'concept_only');
  assert.equal(clinicDx.copyingAuthorized, false);
  assert.equal(clinicDx.distributionAuthorized, false);
  assert.deepEqual(clinicDx.localPaths, []);
  assert.deepEqual(
    clinicDx.artifactLicenseEvidence.map((evidence) => evidence.artifactType),
    ['clinical_rule_asset', 'data_asset', 'model_asset'],
  );
  assert.ok(clinicDx.artifactLicenseEvidence.every((evidence) =>
    evidence.licenseStatus === 'unresolved' &&
    evidence.reviewStatus === 'not_reviewed' &&
    evidence.declaredSpdx === 'NOASSERTION' &&
    evidence.detectedSpdx === 'NOASSERTION',
  ));

  const spice = inventory.influences.find(
    (entry) => entry.id === 'spice_2_server_reference',
  );
  assert.ok(spice);
  assert.equal(spice.pinnedCommit, 'bdc06bbdd855aa65f0692df9218eeb0102bf74b5');
  assert.equal(spice.defaultBranch, 'main');
  assert.equal(spice.declaredSpdx, 'BSD-3-Clause');
  assert.equal(spice.repositoryDetectedSpdx, 'BSD-3-Clause');
  assert.equal(spice.licenseStatus, 'machine_detected');
  assert.equal(spice.transferStatus, 'concept_only');
  assert.equal(spice.copyingAuthorized, false);
  assert.equal(spice.distributionAuthorized, false);
  assert.deepEqual(spice.localPaths, []);
  assert.deepEqual(spice.artifactLicenseEvidence, []);
});

test('SNOMED FHIR CDS and TRICC references retain exact pins and license evidence', () => {
  const { inventory, observed } = fixture();
  assert.deepEqual(validateInfluenceInventory(inventory, observed), []);
  const expected = {
    snomed_fhir_cds_service_reference: {
      url: 'https://github.com/IHTSDO/snomed-fhir-cds-service',
      commit: 'be6b5e6a8d636636cdef55310073857c92880574',
      branch: 'master',
      declared: 'Apache-2.0',
      detected: 'NOASSERTION',
      status: 'declared_not_machine_detected',
    },
    tricc_reference: {
      url: 'https://github.com/SwissTPH/tricc',
      commit: 'b8ee6dc4a9f0e89372f59beb6d076684bc070f81',
      branch: 'develop',
      declared: 'MPL-2.0',
      detected: 'MPL-2.0',
      status: 'machine_detected',
    },
  };
  for (const [id, values] of Object.entries(expected)) {
    const entry = inventory.influences.find((candidate) => candidate.id === id);
    assert.ok(entry, `missing pinned influence: ${id}`);
    assert.equal(entry.officialUrl, values.url);
    assert.equal(entry.pinnedCommit, values.commit);
    assert.equal(entry.defaultBranch, values.branch);
    assert.equal(entry.declaredSpdx, values.declared);
    assert.equal(entry.repositoryDetectedSpdx, values.detected);
    assert.equal(entry.licenseStatus, values.status);
    assert.equal(entry.transferStatus, 'concept_only');
    assert.equal(entry.copyingAuthorized, false);
    assert.equal(entry.distributionAuthorized, false);
    assert.deepEqual(entry.localPaths, []);
  }
});

test('missing or newly documented upstream influence fails closed', () => {
  const { inventory, observed } = fixture();
  inventory.influences.pop();
  assert(codes(inventory, observed).includes('influence_discovery_drift'));

  const next = fixture();
  next.observed.sourceRepositories.push('gitlab.com/example/new-upstream');
  assert(
    codes(next.inventory, next.observed).includes('influence_discovery_drift'),
  );
});

test('concept-only research cannot acquire local or distribution authority', () => {
  const { inventory, observed } = fixture();
  const entry = inventory.influences.find((value) => value.id === 'rxode2');
  entry.localPaths = ['pubspec.yaml'];
  entry.copyingAuthorized = true;
  assert(
    codes(inventory, observed).includes('concept_only_boundary_violation'),
  );
});

test('unresolved license can never cross the release boundary', () => {
  const { inventory, observed } = fixture();
  const entry = inventory.influences.find((value) => value.id === 'healthlog');
  entry.transferStatus = 'linked';
  entry.copyingAuthorized = true;
  entry.distributionAuthorized = true;
  entry.localPaths = ['pubspec.lock'];
  entry.obligations = ['license_notice'];
  inventory.releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds.push(
    'healthlog',
  );
  assert(codes(inventory, observed).includes('unresolved_license_transfer'));
});

test('reciprocal transfer requires legal review, notice, and source disclosure', () => {
  const { inventory, observed } = fixture();
  const entry = inventory.influences.find((value) => value.id === 'rxode2');
  entry.transferStatus = 'derived';
  entry.copyingAuthorized = true;
  entry.distributionAuthorized = true;
  entry.localPaths = ['pubspec.lock'];
  entry.obligations = ['license_notice'];
  inventory.releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds.push(
    'rxode2',
  );
  const result = codes(inventory, observed);
  assert(result.includes('missing_license_obligation'));
  assert.equal(
    validateInfluenceInventory(inventory, observed).filter(
      (item) => item.code === 'missing_license_obligation',
    ).length,
    2,
  );
});

test('permissive copied code still requires a license notice', () => {
  const { inventory, observed } = fixture();
  const entry = inventory.influences.find(
    (value) => value.id === 'ohif_viewers',
  );
  entry.transferStatus = 'copied';
  entry.copyingAuthorized = true;
  entry.distributionAuthorized = true;
  entry.localPaths = ['pubspec.lock'];
  entry.obligations = [];
  inventory.releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds.push(
    'ohif_viewers',
  );
  assert(codes(inventory, observed).includes('missing_license_obligation'));
});

test('duplicate identity, malformed commit, and extra fields are rejected', () => {
  const duplicate = fixture();
  duplicate.inventory.influences[1].id =
    duplicate.inventory.influences[0].id;
  assert(
    codes(duplicate.inventory, duplicate.observed).includes(
      'duplicate_influence_id',
    ),
  );

  const malformed = fixture();
  malformed.inventory.influences[0].pinnedCommit = 'main';
  malformed.inventory.influences[0].unexpected = true;
  const result = codes(malformed.inventory, malformed.observed);
  assert(result.includes('invalid_pinned_commit'));
  assert(result.includes('unsupported_influence_shape'));
});

test('asset license evidence must cover every reviewed clinical and scientific asset category', () => {
  const { inventory, observed } = fixture();
  const osp = inventory.influences.find(
    (value) => value.id === 'osp_pbpk_model_library',
  );
  osp.artifactLicenseEvidence = osp.artifactLicenseEvidence.filter(
    (evidence) => evidence.artifactType !== 'model_asset',
  );
  assert(codes(inventory, observed).includes('artifact_license_type_coverage_drift'));

  const snomed = fixture();
  const cds = snomed.inventory.influences.find(
    (value) => value.id === 'snomed_fhir_cds_service_reference',
  );
  cds.artifactLicenseEvidence = cds.artifactLicenseEvidence.filter(
    (evidence) => evidence.artifactType !== 'terminology_asset',
  );
  assert(codes(snomed.inventory, snomed.observed).includes('artifact_license_type_coverage_drift'));
});

test('unreviewed or unresolved asset licenses block every transfer classification', () => {
  const { inventory, observed } = fixture();
  const osp = inventory.influences.find(
    (value) => value.id === 'osp_pbpk_model_library',
  );
  osp.transferStatus = 'development_linked';
  assert(codes(inventory, observed).includes('unresolved_asset_license_transfer'));

  const snomed = fixture();
  const cds = snomed.inventory.influences.find(
    (value) => value.id === 'snomed_fhir_cds_service_reference',
  );
  cds.transferStatus = 'copied';
  assert(codes(snomed.inventory, snomed.observed).includes('unresolved_asset_license_transfer'));

  const missing = fixture();
  const missingOsp = missing.inventory.influences.find(
    (value) => value.id === 'osp_pbpk_model_library',
  );
  missingOsp.transferStatus = 'copied';
  missingOsp.artifactLicenseEvidence = [];
  assert(codes(missing.inventory, missing.observed).includes('unresolved_asset_license_transfer'));
});

test('an unreviewed artifact category cannot claim a license disposition', () => {
  const { inventory, observed } = fixture();
  const nlmixr = inventory.influences.find((value) => value.id === 'nlmixr2');
  nlmixr.artifactLicenseEvidence[0].licenseStatus = 'declared_not_machine_detected';
  nlmixr.artifactLicenseEvidence[0].declaredSpdx = 'GPL-3.0-only';
  assert(codes(inventory, observed).includes('unreviewed_artifact_claims_license'));
});

test('legacy v4, v5, and v6 inventories cannot satisfy the expanded v7 boundary schema', () => {
  for (const [schema, schemaVersion] of [
    ['https://parkinsum.app/schemas/open-source-influence-inventory/v4', 4],
    ['https://parkinsum.app/schemas/open-source-influence-inventory/v5', 5],
    ['https://parkinsum.app/schemas/open-source-influence-inventory/v6', 6],
  ]) {
    const { inventory, observed } = fixture();
    inventory.$schema = schema;
    inventory.schemaVersion = schemaVersion;
    assert(codes(inventory, observed).includes('unsupported_schema'));
  }
});

test('license status cannot overstate repository or declared evidence', () => {
  const { inventory, observed } = fixture();
  const unresolved = inventory.influences.find(
    (value) => value.id === 'healthlog',
  );
  unresolved.licenseStatus = 'machine_detected';
  assert(codes(inventory, observed).includes('false_machine_detection'));
});

test('unreviewed vendored directory and release-boundary identity drift block', () => {
  const { inventory, observed } = fixture();
  observed.vendoredDirectories.push('lib/vendor');
  assert(codes(inventory, observed).includes('vendored_artifact_drift'));

  const next = fixture();
  next.inventory.releaseBoundary.copiedLinkedVendoredOrDerivedInfluenceIds = [];
  assert(
    codes(next.inventory, next.observed).includes(
      'release_boundary_identity_drift',
    ),
  );
});

test('linked version and pinned source revision must match reviewed files', () => {
  const { inventory, observed } = fixture();
  inventory.releaseBoundary.linkedVersionEvidence.flutter_framework.version =
    '99.0.0';
  inventory.releaseBoundary.linkedVersionEvidence.flutter_local_notifications.sourceRevision =
    'f'.repeat(40);
  const result = codes(inventory, observed);
  assert(result.includes('linked_version_source_mismatch'));
  assert(result.includes('linked_source_revision_mismatch'));

  const development = fixture();
  development.inventory.releaseBoundary.linkedVersionEvidence.google_cql_engine_reference.version =
    'v9.9.9';
  development.inventory.releaseBoundary.linkedVersionEvidence.google_cql_engine_reference.sourceRevision =
    'f'.repeat(40);
  development.inventory.releaseBoundary.linkedVersionEvidence.google_fhir_go_reference.version =
    'v9.9.9';
  development.inventory.releaseBoundary.linkedVersionEvidence.google_fhir_go_reference.sourceRevision =
    'f'.repeat(40);
  const devResult = codes(development.inventory, development.observed);
  assert(devResult.includes('linked_version_source_mismatch'));
  assert(devResult.includes('linked_source_revision_mismatch'));
});
