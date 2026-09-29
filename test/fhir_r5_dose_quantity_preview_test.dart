import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/domain/entities/fhir_r5_dose_quantity_preview.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r5_dose_quantity_preview_service.dart';

void main() {
  final coordinator = AdministrationDoseConfirmationCoordinator();
  final service = FhirR5DoseQuantityPreviewService(coordinator: coordinator);
  final observedAt = DateTime.utc(2026, 9, 23, 15);
  final product = MedicationProductSelection(
    packId: 'fixture_pack',
    identifierSystem: 'local-fixture',
    identifierValue: 'fixture-001',
    displayName: 'Synthetic medication product',
    labelerName: 'Synthetic labeler',
    strengthDisplay: 'levodopa 100 mg per tablet',
    packageDescription: 'Synthetic fixture only',
  );

  Intake draft({
    String note = '100 mg',
    String? route = 'oral',
    String? dosageForm = 'tablet',
    String? releaseType = 'immediate',
    MedicationProductSelection? selectedProduct,
  }) => Intake(
    id: 'dose_preview_fixture',
    drugId: 'synthetic_medication',
    takenAt: DateTime.utc(2026, 9, 23, 14),
    dosageNote: note,
    route: route,
    dosageForm: dosageForm,
    releaseType: releaseType,
    productSelection: selectedProduct,
  );

  AdministrationDosePreparationResult prepare(
    Intake intake, {
    String owner = 'owner_fixture',
  }) => coordinator.prepare(
    draft: intake,
    current: null,
    expectedRecordRevisionDigest:
        administrationDoseConfirmationAbsentRevisionDigest,
    ownerScope: owner,
    operationId: 'dose_preview_operation_fixture',
    confirmationRequested: true,
    assertionSource: AdministrationDoseAssertionSource.typed,
    confirmationAction: 'timeline.explicit_checkbox',
    uiContractVersion: 'dose-preview-test:1',
    confirmedAt: DateTime.utc(2026, 9, 23, 14, 1),
  );

  Intake confirm(Intake intake, {String owner = 'owner_fixture'}) {
    final prepared = prepare(intake, owner: owner);
    expect(prepared.status, AdministrationDosePreparationStatus.confirmed);
    return prepared.intake!;
  }

  Map<String, Object?> quantityOf(FhirR5DoseQuantityPreview preview) {
    final dosage = preview.dosageFragment!;
    final doseAndRate = dosage['doseAndRate'] as List;
    return Map<String, Object?>.from(
      (doseAndRate.single as Map)['doseQuantity'] as Map,
    );
  }

  test('exact confirmed local quantities map to the bounded UCUM codes', () {
    for (final fixture
        in <({String input, num value, String code, String unit})>[
          (input: '100 mg', value: 100, code: 'mg', unit: 'milligram'),
          (input: '1 g', value: 1, code: 'g', unit: 'gram'),
          (input: '500 mcg', value: 500, code: 'ug', unit: 'microgram'),
          (input: '2 mL', value: 2, code: 'mL', unit: 'milliliter'),
        ]) {
      final preview = service.project(
        confirm(draft(note: fixture.input)),
        ownerScope: 'owner_fixture',
        observedAt: observedAt,
      );
      final quantity = quantityOf(preview);

      expect(preview.status, FhirR5DoseQuantityPreviewStatus.projected);
      expect(quantity['value'], fixture.value);
      expect(quantity['unit'], fixture.unit);
      expect(quantity['system'], 'http://unitsofmeasure.org');
      expect(quantity['code'], fixture.code);
      expect(preview.sourceUnitMapping!['mappingType'], isNotNull);
      expect(preview.toJson()['resource_or_exchange_eligible'], isFalse);
    }
  });

  test('profile manifest and preview digest are content-addressed', () {
    final confirmed = confirm(draft(note: '100 mg'));
    final first = service.project(
      confirmed,
      ownerScope: 'owner_fixture',
      observedAt: observedAt,
    );
    final second = service.project(
      confirmed,
      ownerScope: 'owner_fixture',
      observedAt: observedAt,
    );
    final manifestDigest = first.toJson()['profile_manifest_sha256'] as String;
    final previewDigest = first.toJson()['preview_sha256'] as String;

    expect(manifestDigest, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(previewDigest, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(second.toJson()['preview_sha256'], previewDigest);
    expect(
      first.toJson()['schema'],
      'parkinsum.fhir-r5-dose-quantity-preview/2',
    );
    expect(first.toJson()['fhir_core_version'], '5.0.0');
    final manifest = FhirR5DoseQuantityPreview.profileManifest;
    expect(
      manifest['manifest_schema'],
      'parkinsum.fhir-r5-dose-quantity-preview-profile/2',
    );
    expect(manifest['target_path'], 'Dosage.doseAndRate.dose[x]');
    expect(manifest['wire_json_path'], 'Dosage.doseAndRate[0].doseQuantity');
    expect(
      manifest['fhir_dosage_definition'],
      'https://hl7.org/fhir/R5/dosage-definitions.html',
    );
    expect(
      manifest['path_ledger_scope'],
      contains('not a complete FHIR resource/profile'),
    );
    expect(manifest['ucum_source_id'], 'src.ucum.specification');
    expect(
      (manifest['unit_code_bindings'] as List).every(
        (entry) => (entry as Map).keys.toSet().length == 2,
      ),
      isTrue,
    );
  });

  test('FHIR R5 Dosage path coverage classifies mapped and omitted fields', () {
    final coverage = FhirR5DoseQuantityPreview.serializedFhirDosagePathCoverage;
    final paths = coverage.map((entry) => entry['path']!).toList();
    final dispositions = <String, String>{
      for (final entry in coverage) entry['path']!: entry['disposition']!,
    };
    final projected = service.project(
      confirm(draft(note: '100 mg')),
      ownerScope: 'owner_fixture',
      observedAt: observedAt,
    );
    final json = projected.toJson();

    expect(paths.toSet().length, paths.length);
    expect(paths, orderedEquals(paths.toList()..sort()));
    expect(
      dispositions.keys,
      containsAll(<String>[
        'Dosage.sequence',
        'Dosage.asNeededFor',
        'Dosage.timing',
        'Dosage.route',
        'Dosage.doseAndRate[0].type',
        'Dosage.doseAndRate[0].doseRange',
        'Dosage.doseAndRate[0].rateRatio',
        'Dosage.doseAndRate[0].rateRange',
        'Dosage.doseAndRate[0].rateQuantity',
        'Dosage.maxDosePerPeriod',
        'Dosage.maxDosePerAdministration',
        'Dosage.maxDosePerLifetime',
        'Dosage.extension',
        'Dosage.modifierExtension',
      ]),
    );
    expect(dispositions['Dosage.text'], 'partial_dose_token_not_full_sig');
    expect(dispositions['Dosage.doseAndRate'], 'partial_single_entry_only');
    expect(
      dispositions['Dosage.doseAndRate[0].doseQuantity.comparator'],
      'unsupported',
    );
    expect((json['fhir_dosage_path_coverage'] as List).length, coverage.length);
    expect(
      json['mapped_paths'],
      containsAll(<String>[
        'Dosage.doseAndRate[0].doseQuantity.value',
        'Dosage.doseAndRate[0].doseQuantity.unit',
        'Dosage.doseAndRate[0].doseQuantity.system',
        'Dosage.doseAndRate[0].doseQuantity.code',
      ]),
    );
    expect(
      json['partially_projected_paths'],
      containsAll(<String>[
        'Dosage.text',
        'Dosage.doseAndRate',
        'Dosage.doseAndRate[0].doseQuantity',
      ]),
    );
    expect(
      json['not_projected_fhir_paths'],
      containsAll(<String>[
        'Dosage.doseAndRate[0].doseRange',
        'Dosage.doseAndRate[0].rateRatio',
        'Dosage.timing',
        'Dosage.maxDosePerPeriod',
        'Dosage.route',
        'Medication.ingredient.strength[x]',
      ]),
    );
    expect(json['resource_or_exchange_eligible'], isFalse);
  });

  test('unconfirmed, owner-mismatched, and held expressions emit no dose', () {
    final unconfirmed = service.project(
      draft(note: '100 mg'),
      ownerScope: 'owner_fixture',
      observedAt: observedAt,
    );
    final ownerMismatch = service.project(
      confirm(draft(note: '100 mg')),
      ownerScope: 'different_owner',
      observedAt: observedAt,
    );
    final rangeDraft = draft(note: '50–100 mg');
    final rangePreparation = prepare(rangeDraft);
    expect(
      rangePreparation.status,
      AdministrationDosePreparationStatus.heldExpression,
    );
    final range = service.project(
      rangeDraft,
      ownerScope: 'owner_fixture',
      observedAt: observedAt,
    );

    for (final preview in <FhirR5DoseQuantityPreview>[
      unconfirmed,
      ownerMismatch,
      range,
    ]) {
      expect(preview.status, FhirR5DoseQuantityPreviewStatus.held);
      expect(preview.dosageFragment, isNull);
      expect(preview.toJson()['resource_or_exchange_eligible'], isFalse);
    }
  });

  test(
    'unmapped product and administration fields are named without values',
    () {
      final preview = service.project(
        confirm(draft(note: '50 mg', selectedProduct: product)),
        ownerScope: 'owner_fixture',
        observedAt: observedAt,
      );
      final encoded = jsonEncode(preview.toJson());

      expect(quantityOf(preview)['value'], 50);
      expect(
        preview.unmappedLocalFields,
        containsAll(<String>[
          'Intake.dosageForm',
          'Intake.productSelection',
          'Intake.releaseType',
          'Intake.route',
        ]),
      );
      expect(encoded, isNot(contains('Synthetic medication product')));
      expect(encoded, isNot(contains('levodopa 100 mg per tablet')));
      expect(encoded, isNot(contains('owner_fixture')));
      expect(
        (preview.toJson()['not_projected_fhir_paths'] as List),
        contains('Medication.ingredient.strength[x]'),
      );
      expect(
        FhirR5DoseQuantityPreview.profileManifestSha256,
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    },
  );
}
