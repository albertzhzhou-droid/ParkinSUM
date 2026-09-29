import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/domain/entities/fhir_inspired_medication_knowledge_view.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r5_dose_quantity_preview.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r5_medication_product_preview.dart';
import 'package:parkinsum_companion/domain/entities/openfda_strength_expression_source_manifest.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r5_dose_quantity_preview_service.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r5_medication_product_preview_service.dart';
import 'package:parkinsum_companion/domain/usecases/openfda_strength_expression_source_manifest_builder.dart';

void main() {
  const service = FhirR5MedicationProductPreviewService();
  final observedAt = DateTime.utc(2026, 9, 24, 16);

  FhirInspiredMedicationKnowledgeView product({
    String? productName = 'Synthetic combination product',
    List<String> ingredients = const ['carbidopa', 'levodopa'],
    List<FhirInspiredMedicationComponentEntry> components = const [
      FhirInspiredMedicationComponentEntry(
        ingredientName: 'levodopa',
        ingredientRole: 'active',
        strengthValue: 100,
        strengthUnit: 'mg',
        sourceRefs: ['synthetic:label-section-1'],
        labelSectionRefs: ['composition'],
        limitationText: null,
      ),
      FhirInspiredMedicationComponentEntry(
        ingredientName: 'carbidopa',
        ingredientRole: 'adjunct',
        strengthValue: null,
        strengthUnit: null,
        sourceRefs: ['synthetic:label-section-1'],
        labelSectionRefs: ['composition'],
        limitationText: 'Strength absent from the synthetic fixture.',
      ),
    ],
    String doseForm = 'tablet',
  }) => FhirInspiredMedicationKnowledgeView(
    demoDrugProductId: 'synthetic-product-id',
    sourceSystem: 'synthetic-fixture',
    jurisdiction: 'not-applicable',
    language: 'en',
    productName: productName,
    genericName: 'synthetic generic name',
    brandName: null,
    activeIngredients: ingredients,
    combinationComponents: components,
    strengths: components
        .where((entry) => entry.strengthValue != null)
        .toList(),
    doseForm: doseForm,
    route: 'oral',
    releaseType: 'immediate',
    releaseTypeSource: 'synthetic_fixture',
    sourceDocument: const FhirInspiredSourceDocument(
      sourceDocId: 'synthetic-label',
      sourceDocVersion: '1',
      effectiveDate: '2026-01-01',
    ),
    labelSectionRefs: const [],
    sourceRefs: const ['synthetic:label-section-1'],
    metadataCompleteness: 'partial',
    sourceAuthorityScore: null,
    provenanceSummary: 'synthetic fixture only',
    limitationText: 'Synthetic test data only.',
    notClinicallyCalibrated: true,
    notAdviceText: 'Not advice.',
    safetyBoundary: 'Synthetic only.',
  );

  MedicationProductPack productPack({
    String dosageForm = 'tablet',
    String sourceSystem = 'OPENFDA_NDC',
    String sourceUrl = 'https://api.fda.gov/drug/ndc.json',
    bool includeRetrievedAt = true,
    MedicationIngredientStrength ingredient =
        const MedicationIngredientStrength(
          ingredientName: 'levodopa',
          numeratorValue: 100,
          numeratorUnit: 'mg',
          denominatorValue: null,
          denominatorUnit: null,
          rawStrength: '100 mg',
        ),
  }) => MedicationProductPack(
    id: 'synthetic-product-pack',
    genericName: 'synthetic generic',
    brandName: 'Synthetic brand',
    labelerName: null,
    jurisdiction: sourceSystem == 'HEALTH_CANADA_DPD' ? 'CA' : 'US',
    identifiers: <MedicationProductIdentifier>[
      MedicationProductIdentifier(
        system: sourceSystem == 'HEALTH_CANADA_DPD'
            ? MedicationIdentifierSystem.din
            : MedicationIdentifierSystem.ndcProduct,
        level: MedicationIdentifierLevel.product,
        value: sourceSystem == 'HEALTH_CANADA_DPD' ? '01234567' : '00000-0000',
      ),
    ],
    ingredients: <MedicationIngredientStrength>[ingredient],
    dosageForm: dosageForm,
    routes: const <String>['oral'],
    packageDescription: 'Synthetic package fixture',
    marketingStartDate: null,
    marketingEndDate: null,
    sourceSystem: sourceSystem,
    sourceUrl: sourceUrl,
    retrievedAt: includeRetrievedAt ? DateTime.utc(2026, 9, 24, 12) : null,
  );

  OpenFdaStrengthExpressionSourceManifest sourceManifestFor(
    MedicationProductPack pack, {
    String? productNdc,
    String? ingredientName,
    String? rawStrength,
    String? productId,
    String? splId,
    bool duplicateMatchingRow = false,
  }) {
    final ndc =
        productNdc ??
        pack.identifiers
            .firstWhere(
              (identifier) =>
                  identifier.system == MedicationIdentifierSystem.ndcProduct,
            )
            .value;
    final ingredient = pack.ingredients.single;
    final bytes = utf8.encode(
      jsonEncode(<String, Object?>{
        'source_system': 'OPENFDA_NDC',
        'source_url': 'https://api.fda.gov/drug/ndc.json',
        'retrieved_at': '2026-09-24T12:00:00Z',
        'limitations': <String>['Synthetic fixture only; not source verified.'],
        'records': <Map<String, Object?>>[
          <String, Object?>{
            'record': <String, Object?>{
              'product_ndc': ndc,
              'product_id': productId ?? 'synthetic-source-product-id',
              'spl_id': splId ?? 'synthetic-source-spl-id',
              'active_ingredients': <Map<String, String>>[
                <String, String>{
                  'name': ingredientName ?? ingredient.ingredientName,
                  'strength': rawStrength ?? ingredient.rawStrength,
                },
              ],
            },
          },
          if (duplicateMatchingRow)
            <String, Object?>{
              'record': <String, Object?>{
                'product_ndc': ndc,
                'product_id': 'second-synthetic-source-product-id',
                'spl_id': 'second-synthetic-source-spl-id',
                'active_ingredients': <Map<String, String>>[
                  <String, String>{
                    'name': ingredientName ?? ingredient.ingredientName,
                    'strength': rawStrength ?? ingredient.rawStrength,
                  },
                ],
              },
            },
        ],
      }),
    );
    return const OpenFdaStrengthExpressionSourceManifestBuilder()
        .buildFromBytes(bytes);
  }

  test(
    'projects product and ingredient text while holding strength outside FHIR',
    () {
      final preview = service.project(product(), observedAt: observedAt);
      final fragment = preview.medicationFragment!;
      final ingredients = fragment['ingredient'] as List;
      final json = preview.toJson();

      expect(preview.status, FhirR5MedicationProductPreviewStatus.projected);
      expect(fragment['resourceType'], 'Medication');
      expect(
        (fragment['code'] as Map)['text'],
        'Synthetic combination product',
      );
      expect((fragment['doseForm'] as Map)['text'], 'tablet');
      expect(ingredients, hasLength(2));
      expect(
        ((ingredients.first as Map)['item'] as Map)['concept'],
        <String, Object?>{'text': 'levodopa'},
      );
      expect(
        ingredients.every((entry) {
          final component = entry as Map;
          return !component.containsKey('strength[x]') &&
              !component.containsKey('strengthRatio') &&
              !component.containsKey('strengthQuantity') &&
              !component.containsKey('strengthCodeableConcept');
        }),
        isTrue,
      );
      expect(fragment.containsKey('doseAndRate'), isFalse);
      expect(fragment.containsKey('route'), isFalse);
      expect(fragment.containsKey('status'), isFalse);
      expect(
        (json['product_strength_evidence'] as List).map(
          (entry) => (entry as Map)['evidence_state'],
        ),
        orderedEquals(<String>['product_metadata_only', 'missing']),
      );
      expect(
        ((json['product_strength_evidence'] as List).first
            as Map)['source_value'],
        100,
      );
      expect(
        ((json['product_strength_evidence'] as List).first
            as Map)['fhir_strength_path_projected'],
        isFalse,
      );
      expect(json['resource_or_exchange_eligible'], isFalse);
      expect(json['algorithm_eligible'], isFalse);
      expect(
        (json['source_provenance'] as Map)['source_refs'],
        contains('synthetic:label-section-1'),
      );
      expect(
        ((json['source_provenance'] as Map)['source_document'] as Map)['id'],
        'synthetic-label',
      );
      expect(fragment.containsKey('source_provenance'), isFalse);
      expect(jsonEncode(fragment), isNot(contains('coding')));
    },
  );

  test(
    'product strength and confirmed administration quantity stay distinct',
    () {
      final medication = service.project(product(), observedAt: observedAt);
      final coordinator = AdministrationDoseConfirmationCoordinator();
      final doseService = FhirR5DoseQuantityPreviewService(
        coordinator: coordinator,
      );
      final draft = Intake(
        id: 'synthetic-dose-fixture',
        drugId: 'synthetic-product',
        takenAt: DateTime.utc(2026, 9, 24, 15),
        dosageNote: '50 mg',
      );
      final confirmation = coordinator.prepare(
        draft: draft,
        current: null,
        expectedRecordRevisionDigest:
            administrationDoseConfirmationAbsentRevisionDigest,
        ownerScope: 'synthetic-owner',
        operationId: 'synthetic-dose-operation',
        confirmationRequested: true,
        assertionSource: AdministrationDoseAssertionSource.typed,
        confirmationAction: 'test.explicit_checkbox',
        uiContractVersion: 'cdss-094:1',
        confirmedAt: DateTime.utc(2026, 9, 24, 15, 1),
      );
      expect(confirmation.intake, isNotNull);
      final dose = doseService.project(
        confirmation.intake!,
        ownerScope: 'synthetic-owner',
        observedAt: observedAt,
      );
      final dosageFragment = dose.dosageFragment!;
      final doseAndRate = dosageFragment['doseAndRate'] as List;
      final quantity = (doseAndRate.single as Map)['doseQuantity'] as Map;
      final strengthEvidence = medication.productStrengthEvidence.first;

      expect(strengthEvidence['source_value'], 100);
      expect(strengthEvidence['source_unit_display'], 'mg');
      expect(strengthEvidence['fhir_strength_path_projected'], isFalse);
      expect(dose.status, FhirR5DoseQuantityPreviewStatus.projected);
      expect(quantity['value'], 50);
      expect(
        medication.medicationFragment!.containsKey('doseAndRate'),
        isFalse,
      );
    },
  );

  test('path ledger and manifest are versioned and content-addressed', () {
    final first = service.project(product(), observedAt: observedAt).toJson();
    final second = service.project(product(), observedAt: observedAt).toJson();
    final manifest = FhirR5MedicationProductPreview.profileManifest;
    final paths =
        FhirR5MedicationProductPreview.serializedFhirMedicationPathCoverage;
    final dispositions = <String, String>{
      for (final entry in paths) entry['path']!: entry['disposition']!,
    };

    expect(first['schema'], 'parkinsum.fhir-r5-medication-product-preview/3');
    expect(first['preview_sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(first['preview_sha256'], second['preview_sha256']);
    expect(
      manifest['manifest_schema'],
      'parkinsum.fhir-r5-medication-product-preview-profile/3',
    );
    expect(manifest['fhir_core_package'], 'hl7.fhir.core#5.0.0');
    expect(
      dispositions['Medication.ingredient[*].strength[x]'],
      'partial_exact_one_unit_quantity_subset',
    );
    expect(
      dispositions['Medication.ingredient[*].strengthRatio'],
      'not_projected_no_denominator_or_unit_system',
    );
    expect(manifest['ucum_version'], '2.2');
    expect(manifest['ucum_license_version'], '1.1');
    expect(
      manifest['ucum_license_disposition'],
      'reference_only_no_full_table_parser_or_redistribution_clearance',
    );
    expect(
      dispositions['Medication.ingredient[*].strengthQuantity'],
      'partial_exact_one_unit_ucum_quantity_subset',
    );
    expect(
      dispositions['Medication.ingredient[*].item.concept.text'],
      'mapped_text_only',
    );
    expect(
      dispositions['Medication.totalVolume'],
      'not_projected_package_amount_unresolved',
    );
    expect(
      FhirR5MedicationProductPreview.profileManifestSha256,
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
    expect(
      (first['fhir_medication_path_coverage'] as List).length,
      paths.length,
    );
  });

  test('projects exact one-tablet strength with UCUM Quantity semantics', () {
    final pack = productPack(
      ingredient: const MedicationIngredientStrength(
        ingredientName: 'levodopa',
        numeratorValue: 100,
        numeratorUnit: 'mg',
        denominatorValue: 1,
        denominatorUnit: null,
        rawStrength: '100 mg/1',
      ),
    );
    final preview = service.projectProductPack(
      pack,
      observedAt: observedAt,
      sourceManifest: sourceManifestFor(pack),
    );
    final json = preview.toJson();
    final ingredient =
        (preview.medicationFragment!['ingredient'] as List).single as Map;
    final quantity = ingredient['strengthQuantity'] as Map;
    final evidence = (json['product_strength_evidence'] as List).single as Map;

    expect(preview.status, FhirR5MedicationProductPreviewStatus.projected);
    expect(quantity, <String, Object?>{
      'value': 100.0,
      'unit': 'mg',
      'system': 'http://unitsofmeasure.org',
      'code': 'mg',
    });
    expect(evidence['source_raw_strength'], '100 mg/1');
    expect(evidence['source_numerator_lexeme'], '100');
    expect(
      evidence['denominator_basis'],
      'source_numeric_one_unitless_assumed_one_tablet',
    );
    expect(evidence['fhir_strength_path_projected'], isTrue);
    expect(evidence['algorithm_eligible'], isFalse);
    expect(json['resource_or_exchange_eligible'], isFalse);
    expect(json['algorithm_eligible'], isFalse);
    expect(
      (json['source_provenance'] as Map)['source_verification_state'],
      'official_host_checked_only_not_independently_verified',
    );
    expect(
      (json['source_provenance'] as Map)['full_source_response_hash_state'],
      'not_supplied_by_importer',
    );
    final localManifest =
        (json['source_provenance'] as Map)['local_source_manifest'] as Map;
    expect(
      localManifest['source_asset_sha256'],
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
    expect(localManifest['fda_data_verified'], isFalse);
    final sourceRow = evidence['source_row_identity'] as Map;
    expect(sourceRow['product_id'], 'synthetic-source-product-id');
    expect(sourceRow['spl_id'], 'synthetic-source-spl-id');
    expect(sourceRow['ingredient_index'], 0);
    expect(sourceRow['row_sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(
      evidence['source_row_binding_state'],
      'exact_unique_local_snapshot_row_match',
    );
    expect(preview.medicationFragment!.containsKey('doseAndRate'), isFalse);

    final healthCanadaPreview = service.projectProductPack(
      productPack(
        sourceSystem: 'HEALTH_CANADA_DPD',
        sourceUrl:
            'https://health-products.canada.ca/api/drug/activeingredient/?lang=en&type=json',
        includeRetrievedAt: false,
      ),
      observedAt: observedAt,
      sourceManifest: sourceManifestFor(productPack()),
    );
    final healthCanadaIngredient =
        (healthCanadaPreview.medicationFragment!['ingredient'] as List).single
            as Map;
    expect(healthCanadaIngredient['strengthQuantity'], isA<Map>());
    expect(
      (healthCanadaPreview.toJson()['source_provenance']
          as Map)['retrieval_timestamp_state'],
      'not_supplied_by_importer',
    );
    expect(
      (healthCanadaPreview.toJson()['source_provenance'] as Map).containsKey(
        'local_source_manifest',
      ),
      isFalse,
    );
  });

  test('holds unsupported source, form, unit, and denominator semantics', () {
    final cases = <MedicationProductPack>[
      productPack(
        dosageForm: 'capsule',
        ingredient: const MedicationIngredientStrength(
          ingredientName: 'levodopa',
          numeratorValue: 100,
          numeratorUnit: 'mg',
          denominatorValue: null,
          denominatorUnit: null,
          rawStrength: '100 mg',
        ),
      ),
      productPack(
        ingredient: const MedicationIngredientStrength(
          ingredientName: 'levodopa',
          numeratorValue: 50,
          numeratorUnit: 'mg',
          denominatorValue: 5,
          denominatorUnit: 'mL',
          rawStrength: '50 mg/5mL',
        ),
      ),
      productPack(
        ingredient: const MedicationIngredientStrength(
          ingredientName: 'levodopa',
          numeratorValue: 100,
          numeratorUnit: 'mcg',
          denominatorValue: null,
          denominatorUnit: null,
          rawStrength: '100 mcg',
        ),
      ),
      productPack(
        sourceUrl: 'https://not-fda.example/drug/ndc.json',
        ingredient: const MedicationIngredientStrength(
          ingredientName: 'levodopa',
          numeratorValue: 100,
          numeratorUnit: 'mg',
          denominatorValue: null,
          denominatorUnit: null,
          rawStrength: '100 mg',
        ),
      ),
      productPack(
        ingredient: const MedicationIngredientStrength(
          ingredientName: 'levodopa',
          numeratorValue: 99,
          numeratorUnit: 'mg',
          denominatorValue: null,
          denominatorUnit: null,
          rawStrength: '100 mg',
        ),
      ),
    ];

    for (final pack in cases) {
      final preview = service.projectProductPack(pack, observedAt: observedAt);
      final ingredient =
          (preview.medicationFragment!['ingredient'] as List).single as Map;
      final evidence =
          (preview.toJson()['product_strength_evidence'] as List).single as Map;

      expect(ingredient.containsKey('strengthQuantity'), isFalse);
      expect(evidence['fhir_strength_path_projected'], isFalse);
      expect(evidence['algorithm_eligible'], isFalse);
      expect(evidence['evidence_state'], 'held_product_metadata_only');
    }
  });

  test('openFDA strength requires a unique exact local source-row binding', () {
    final pack = productPack(
      ingredient: const MedicationIngredientStrength(
        ingredientName: 'levodopa',
        numeratorValue: 100,
        numeratorUnit: 'mg',
        denominatorValue: 1,
        denominatorUnit: null,
        rawStrength: '100 mg/1',
      ),
    );
    final withoutManifest = service.projectProductPack(
      pack,
      observedAt: observedAt,
    );
    final mismatchedManifest = service.projectProductPack(
      pack,
      observedAt: observedAt,
      sourceManifest: sourceManifestFor(pack, rawStrength: '101 mg/1'),
    );
    final mismatchedProduct = service.projectProductPack(
      pack,
      observedAt: observedAt,
      sourceManifest: sourceManifestFor(pack, productNdc: '99999-9999'),
    );
    final ambiguousManifest = service.projectProductPack(
      pack,
      observedAt: observedAt,
      sourceManifest: sourceManifestFor(pack, duplicateMatchingRow: true),
    );

    for (final preview in <FhirR5MedicationProductPreview>[
      withoutManifest,
      mismatchedManifest,
      mismatchedProduct,
      ambiguousManifest,
    ]) {
      final ingredient =
          (preview.medicationFragment!['ingredient'] as List).single as Map;
      final evidence =
          (preview.toJson()['product_strength_evidence'] as List).single as Map;
      expect(ingredient.containsKey('strengthQuantity'), isFalse);
      expect(
        evidence['source_row_binding_state'],
        'missing_ambiguous_or_mismatched',
      );
      expect(evidence['algorithm_eligible'], isFalse);
    }
    expect(
      (withoutManifest.toJson()['product_strength_evidence'] as List)
          .single['reason_code'],
      'medication.fhir_r5.product_source_row_binding_missing_or_ambiguous',
    );
  });

  test('source-row manifest identity changes the preview digest', () {
    final pack = productPack(
      ingredient: const MedicationIngredientStrength(
        ingredientName: 'levodopa',
        numeratorValue: 100,
        numeratorUnit: 'mg',
        denominatorValue: 1,
        denominatorUnit: null,
        rawStrength: '100 mg/1',
      ),
    );
    final original = service.projectProductPack(
      pack,
      observedAt: observedAt,
      sourceManifest: sourceManifestFor(pack),
    );
    final changedSourceIdentity = service.projectProductPack(
      pack,
      observedAt: observedAt,
      sourceManifest: sourceManifestFor(pack, splId: 'different-spl-id'),
    );

    expect(
      original.toJson()['preview_sha256'],
      isNot(changedSourceIdentity.toJson()['preview_sha256']),
    );
    final originalRow =
        (original.productStrengthEvidence.single['source_row_identity'] as Map);
    final changedRow =
        (changedSourceIdentity
                .productStrengthEvidence
                .single['source_row_identity']
            as Map);
    expect(originalRow['row_sha256'], isNot(changedRow['row_sha256']));
  });

  test('product strength changes alter the content-addressed preview', () {
    final first = service.projectProductPack(
      productPack(),
      observedAt: observedAt,
    );
    final changedStrength = service.projectProductPack(
      productPack(
        ingredient: const MedicationIngredientStrength(
          ingredientName: 'levodopa',
          numeratorValue: 200,
          numeratorUnit: 'mg',
          denominatorValue: null,
          denominatorUnit: null,
          rawStrength: '200 mg',
        ),
      ),
      observedAt: observedAt,
    );

    expect(
      first.toJson()['preview_sha256'],
      isNot(changedStrength.toJson()['preview_sha256']),
    );
  });

  test('missing or unsafe product identity stays held', () {
    final noIdentity = service.project(
      product(productName: null, components: const [], ingredients: const []),
      observedAt: observedAt,
    );
    final unsafeName = service.project(
      product(productName: 'Synthetic\nproduct'),
      observedAt: observedAt,
    );

    expect(noIdentity.status, FhirR5MedicationProductPreviewStatus.held);
    expect(noIdentity.medicationFragment, isNull);
    expect(
      noIdentity.reasonCodes,
      contains('medication.fhir_r5.product_identity_missing'),
    );
    expect(unsafeName.status, FhirR5MedicationProductPreviewStatus.held);
    expect(unsafeName.medicationFragment, isNull);
    expect(
      unsafeName.reasonCodes,
      contains('medication.fhir_r5.product_display_invalid'),
    );
  });

  test(
    'unknown form and incomplete strengths remain separate and explicit',
    () {
      final preview = service.project(
        product(
          productName: null,
          doseForm: 'unknown',
          components: const [
            FhirInspiredMedicationComponentEntry(
              ingredientName: 'synthetic ingredient',
              ingredientRole: 'unknown',
              strengthValue: double.nan,
              strengthUnit: 'mg',
              sourceRefs: [],
              labelSectionRefs: [],
              limitationText: null,
            ),
          ],
        ),
        observedAt: observedAt,
      );
      final fragment = preview.medicationFragment!;
      final evidence =
          (preview.toJson()['product_strength_evidence'] as List).single as Map;

      expect(preview.status, FhirR5MedicationProductPreviewStatus.projected);
      expect(fragment.containsKey('doseForm'), isFalse);
      expect(evidence['source_value'], isNull);
      expect(evidence['evidence_state'], 'incomplete_or_invalid');
      expect(evidence['algorithm_eligible'], isFalse);
      expect(jsonEncode(preview.toJson()), isNot(contains('NaN')));
    },
  );
}
