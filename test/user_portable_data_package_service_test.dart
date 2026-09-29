import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/entities/medication_assertion_reconciliation.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/domain/usecases/portable_schema_migration_registry.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';

void main() {
  const service = UserPortableDataPackageService();
  final generatedAt = DateTime.utc(2026, 8, 17, 14, 30);

  test('build is deterministic under input reordering and self-verifies', () {
    final first = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final second = service.create(
      snapshot: _snapshot(reverse: true),
      generatedAt: generatedAt,
    );

    expect(second.canonicalJson, first.canonicalJson);
    expect(second.packageId, first.packageId);
    expect(second.contentSha256, first.contentSha256);
    expect(first.files.map((file) => file.path), userPortableDataFilePaths);
    final exportedObservations =
        _files(first.prettyJson)['observations.json'] as Map;
    final observationRows = exportedObservations['records'] as List;
    expect(
      exportedObservations['availability'],
      'captured_current_local_snapshot',
    );
    expect(observationRows, hasLength(4));
    expect(first.prettyJson, isNot(contains('recorder_private_id')));
    final symptom = observationRows.cast<Map>().singleWhere(
      (row) => row['kind'] == 'symptom',
    );
    expect(symptom, isNot(contains('recorderId')));
    expect(symptom['recorderRole'], 'package_owner');
    expect(symptom['notes'], 'Owner-entered note retained in local export.');
    final unknown = observationRows.cast<Map>().singleWhere(
      (row) => row['kind'] == 'selfReportedMotorState',
    );
    expect(unknown['status'], 'unknown');
    expect(unknown['motorState'], isNull);

    final preview = service.inspect(
      packageJson: first.prettyJson,
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.ready);
    expect(preview.mayProceedToFutureImport, isTrue);
    expect(preview.findings.last, contains('no record'));
  });

  test(
    'self-resigned observations preserve strict missingness and identity boundaries',
    () {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );
      final root = _root(artifact.prettyJson);
      final files = Map<String, Object?>.from(root['files'] as Map);
      final observations = Map<String, Object?>.from(
        files['observations.json'] as Map,
      );
      final records = List<Object?>.from(observations['records'] as List);
      final unknownMotor = Map<String, Object?>.from(
        records.singleWhere(
              (row) => (row as Map)['id'] == 'observation_motor_unknown',
            )
            as Map,
      )..['motorState'] = 'off';
      records[2] = unknownMotor;
      observations['records'] = records;
      files['observations.json'] = observations;
      root['files'] = files;

      final preview = service.inspect(
        packageJson: _resign(root),
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(preview.status, UserPortableDataPreviewStatus.corrupt);
      expect(preview.findings.join(' '), contains('semantically invalid'));
    },
  );

  test(
    'async inspection preserves the synchronous validation result',
    () async {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );

      final preview = await service.inspectAsync(
        packageJson: artifact.prettyJson,
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );

      expect(preview.status, UserPortableDataPreviewStatus.ready);
      expect(preview.packageId, artifact.packageId);
      expect(preview.recordCounts.keys, userPortableDataFilePaths);
    },
  );

  test(
    'round-trip preserves null versus zero, timestamp, unit, provenance, and audit links',
    () {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );
      final files = _files(artifact.prettyJson);
      final intakes = (files['intakes.json'] as List).cast<Map>();
      final nullDose = intakes.singleWhere((row) => row['id'] == 'intake_null');
      final zeroDose = intakes.singleWhere((row) => row['id'] == 'intake_zero');

      expect((nullDose['dose'] as Map)['amount'], isNull);
      expect((zeroDose['dose'] as Map)['amount'], 0.0);
      expect((zeroDose['dose'] as Map)['unit'], 'mg');
      expect(zeroDose['takenAt'], '2026-08-17T12:00:00.000Z');
      expect(
        (zeroDose['medicationCatalogProvenance'] as Map)['sourceSystem'],
        'TEST_LABEL',
      );

      final meals = (files['meals.json'] as List).cast<Map>();
      final items = (meals.single['items'] as List).cast<Map>();
      final missing = items.singleWhere(
        (row) => row['foodId'] == 'food_missing',
      );
      final trueZero = items.singleWhere((row) => row['foodId'] == 'food_zero');
      final missingProtein =
          ((missing['nutrientsPer100g'] as Map)['protein'] as Map);
      final zeroProtein =
          ((trueZero['nutrientsPer100g'] as Map)['protein'] as Map);
      expect(missingProtein['value'], isNull);
      expect(missingProtein['rawCompatibilityValue'], 0.0);
      expect(missingProtein['missing'], isTrue);
      expect(missingProtein['status'], 'source_missing_not_zero');
      expect(zeroProtein['value'], 0.0);
      expect(zeroProtein['missing'], isFalse);
      expect(
        (missing['catalogProvenance'] as Map)['qualifierKind'],
        'analytical',
      );

      final audit = files['audit_links.json'] as Map;
      expect(audit['clinicalAuditRecordsIncluded'], isFalse);
      expect(
        (audit['links'] as List).where(
          (row) => (row as Map)['relationship'] == 'contains_food',
        ),
        hasLength(2),
      );
    },
  );

  test('portable package preserves and validates a local dose receipt', () {
    final prepared = AdministrationDoseConfirmationCoordinator().prepare(
      draft: Intake(
        id: 'intake_confirmed',
        drugId: 'drug_test',
        takenAt: DateTime.utc(2026, 8, 17, 10),
        dosageNote: '0.25 g',
      ),
      current: null,
      expectedRecordRevisionDigest:
          administrationDoseConfirmationAbsentRevisionDigest,
      ownerScope: _scope,
      operationId: 'portable_dose_fixture',
      confirmationRequested: true,
      assertionSource: AdministrationDoseAssertionSource.typed,
      confirmationAction: 'timeline.explicit_checkbox',
      uiContractVersion: 'timeline-dose-confirmation:1',
      confirmedAt: DateTime.utc(2026, 8, 17, 10, 1),
    );
    final confirmed = prepared.intake!;
    final artifact = service.create(
      snapshot: _snapshot(intakes: <Intake>[confirmed]),
      generatedAt: generatedAt,
    );
    final row =
        ((_files(artifact.prettyJson)['intakes.json'] as List).single as Map);
    final envelope = row['doseConfirmation'] as Map;
    final receipt = envelope['receipt'] as Map;

    expect(envelope['evidenceStatus'], 'receipt_present_unverified');
    expect(envelope['invalidEvidenceDigest'], isNull);
    expect(envelope['meaningBoundary'], contains('not FHIR conformance'));
    final reconciliation = row['medicationReconciliation'] as Map;
    final reconciliationEnvelope = reconciliation['envelope'] as Map;
    expect(reconciliation['evidenceStatus'], 'envelope_present');
    expect(reconciliationEnvelope['assertions'], hasLength(1));
    expect(reconciliationEnvelope['decisions'], isEmpty);
    final truth = row['doseTruth'] as Map;
    expect((truth['parseability'] as Map)['status'], 'accepted');
    expect((truth['confirmationVerification'] as Map)['status'], 'confirmed');
    expect((truth['resultUse'] as Map)['eligible'], isTrue);
    expect((truth['canonicalQuantity'] as Map)['value'], 250.0);
    expect((truth['canonicalQuantity'] as Map)['unit'], 'mg');
    final parseability = truth['parseability'] as Map;
    final parseExpression = parseability['expression'] as Map;
    final parsedUnit = parseExpression['unit'] as Map;
    final parsedMapping = parsedUnit['mappingEvidence'] as Map;
    final canonicalMapping =
        (truth['canonicalQuantity'] as Map)['unitMappingEvidence'] as Map;
    expect(parsedMapping['conversionNumerator'], 1000);
    expect(parsedMapping['conversionDenominator'], 1);
    expect(parsedMapping['sourceRevision'], parseability['grammar_digest']);
    expect(canonicalMapping, parsedMapping);
    expect(
      receipt['receipt_digest'],
      confirmed.doseConfirmation!.receiptDigest,
    );
    expect(receipt['owner_scope_digest'], isNot(_scope));
    expect(artifact.prettyJson, isNot(contains(_scope)));
    expect(
      service
          .inspect(
            packageJson: artifact.prettyJson,
            currentUserScope: _scope,
            currentDoseOwnerScope: _scope,
            currentScopeKind: _scopeKind,
          )
          .status,
      UserPortableDataPreviewStatus.ready,
    );
  });

  test(
    'portable package preserves labeled v2 and accepts unnamed v1 assertions',
    () {
      MedicationAssertionNode sourceAssertion(
        Intake intake, {
        String? sourceDisplayLabel,
      }) => MedicationAssertionNode.create(
        ownerScope: _scope,
        intakeId: intake.id,
        medicationId: intake.drugId,
        productIdentityDigest: medicationAssertionSnapshotDigest(null),
        doseValue: null,
        doseUnit: null,
        route: null,
        dosageForm: null,
        releaseType: null,
        evidenceClass: MedicationAssertionEvidenceClass.importedStatement,
        sourceDisplayLabel: sourceDisplayLabel,
        sourceArtifactId: 'source_portal',
        sourceArtifactDigest: medicationAssertionSnapshotDigest('portal'),
        sourceRevisionDigest: medicationAssertionSnapshotDigest('portal:1'),
        actorIdentity: 'importer',
        actorRole: MedicationAssertionActorRole.importer,
        effectiveStart: intake.takenAt,
        effectiveEnd: intake.takenAt,
        timePrecision: MedicationAssertionTimePrecision.exact,
        timeUncertaintyMinutes: 0,
        timezoneOffsetMinutes: 0,
        timezoneSource: MedicationAssertionTimezoneSource.sourceDeclared,
        assertedAt: intake.takenAt,
        importedAt: intake.takenAt,
        recordedAt: intake.takenAt,
        status: MedicationAssertionStatus.unknown,
      );

      final base = _intakes.first;
      final labeledIntake = base.copyWith(
        medicationAssertions: <MedicationAssertionNode>[
          sourceAssertion(base, sourceDisplayLabel: 'Patient portal record'),
        ],
      );
      final labeledArtifact = service.create(
        snapshot: _snapshot(intakes: <Intake>[labeledIntake]),
        generatedAt: generatedAt,
      );
      final labeledRow =
          ((_files(labeledArtifact.prettyJson)['intakes.json'] as List).single
              as Map);
      final labeledEnvelope =
          ((labeledRow['medicationReconciliation'] as Map)['envelope'] as Map);
      final labeledAssertion =
          ((labeledEnvelope['assertions'] as List).single as Map);
      expect(labeledAssertion['schema_version'], 2);
      expect(labeledAssertion['source_display_label'], 'Patient portal record');
      expect(
        service
            .inspect(
              packageJson: labeledArtifact.prettyJson,
              currentUserScope: _scope,
              currentDoseOwnerScope: _scope,
              currentScopeKind: _scopeKind,
            )
            .status,
        UserPortableDataPreviewStatus.ready,
      );

      final legacyIntake = base.copyWith(
        medicationAssertions: <MedicationAssertionNode>[sourceAssertion(base)],
      );
      final legacyArtifact = service.create(
        snapshot: _snapshot(intakes: <Intake>[legacyIntake]),
        generatedAt: generatedAt,
      );
      final legacyRoot = _root(legacyArtifact.prettyJson);
      final files = Map<String, Object?>.from(legacyRoot['files'] as Map);
      final rows = List<Object?>.from(files['intakes.json'] as List);
      final row = Map<String, Object?>.from(rows.single as Map);
      final reconciliation = Map<String, Object?>.from(
        row['medicationReconciliation'] as Map,
      );
      final envelope = Map<String, Object?>.from(
        reconciliation['envelope'] as Map,
      );
      final assertions = List<Object?>.from(envelope['assertions'] as List);
      final legacyJson = Map<String, Object?>.from(assertions.single as Map)
        ..remove('identity_schema_version')
        ..remove('source_display_label')
        ..['schema'] = 'parkinsum.medication-assertion/1'
        ..['schema_version'] = 1;
      envelope['assertions'] = <Object?>[legacyJson];
      reconciliation['envelope'] = envelope;
      row['medicationReconciliation'] = reconciliation;
      rows[0] = row;
      files['intakes.json'] = rows;
      legacyRoot['files'] = files;

      final legacyPreview = service.inspect(
        packageJson: _resign(legacyRoot),
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(
        legacyPreview.status,
        UserPortableDataPreviewStatus.ready,
        reason: legacyPreview.findings.join('; '),
      );
    },
  );

  test(
    'self-consistent rehash cannot authorize a changed dose-unit factor',
    () {
      final confirmed = _confirmedDose(
        id: 'intake_mapping_tamper',
        dose: '0.25 g',
        ownerScope: _scope,
        confirmedAt: DateTime.utc(2026, 8, 17, 10, 1),
      );
      final artifact = service.create(
        snapshot: _snapshot(intakes: <Intake>[confirmed]),
        generatedAt: generatedAt,
      );
      final root = _root(artifact.prettyJson);
      final files = Map<String, Object?>.from(root['files'] as Map);
      final rows = List<Object?>.from(files['intakes.json'] as List);
      final row = Map<String, Object?>.from(rows.single as Map);
      final doseTruth = Map<String, Object?>.from(row['doseTruth'] as Map);
      final parseability = Map<String, Object?>.from(
        doseTruth['parseability'] as Map,
      );
      final expression = Map<String, Object?>.from(
        parseability['expression'] as Map,
      );
      final unit = Map<String, Object?>.from(expression['unit'] as Map);
      final parsedMapping = Map<String, Object?>.from(
        unit['mappingEvidence'] as Map,
      )..['conversionNumerator'] = 1;
      unit['mappingEvidence'] = parsedMapping;
      expression['unit'] = unit;
      parseability['expression'] = expression;
      doseTruth['parseability'] = parseability;
      final canonical = Map<String, Object?>.from(
        doseTruth['canonicalQuantity'] as Map,
      );
      final canonicalMapping = Map<String, Object?>.from(
        canonical['unitMappingEvidence'] as Map,
      )..['conversionNumerator'] = 1;
      canonical['unitMappingEvidence'] = canonicalMapping;
      doseTruth['canonicalQuantity'] = canonical;
      row['doseTruth'] = doseTruth;
      rows[0] = row;
      files['intakes.json'] = rows;
      root['files'] = files;

      final preview = service.inspect(
        packageJson: _resign(root),
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(preview.status, UserPortableDataPreviewStatus.corrupt);
      expect(preview.findings.join(' '), contains('unitMappingEvidence'));
      expect(preview.mayProceedToFutureImport, isFalse);
    },
  );

  test(
    'schema v4 keeps package owner and raw dose owner separate and private',
    () {
      final confirmed = _confirmedDose(
        id: 'intake_dual_scope',
        dose: '100 mg',
        ownerScope: _scope,
        confirmedAt: DateTime.utc(2026, 8, 17, 10, 1),
      );
      final artifact = service.create(
        snapshot: _snapshot(
          userScope: _packageScope,
          doseOwnerScope: _scope,
          intakes: <Intake>[confirmed],
        ),
        generatedAt: generatedAt,
      );

      expect(artifact.prettyJson, isNot(contains(_packageScope)));
      expect(artifact.prettyJson, isNot(contains(_scope)));
      expect(
        service
            .inspect(
              packageJson: artifact.prettyJson,
              currentUserScope: _packageScope,
              currentDoseOwnerScope: _scope,
              currentScopeKind: _scopeKind,
            )
            .status,
        UserPortableDataPreviewStatus.ready,
      );
      expect(
        service
            .inspect(
              packageJson: artifact.prettyJson,
              currentUserScope: _scope,
              currentDoseOwnerScope: _scope,
              currentScopeKind: _scopeKind,
            )
            .status,
        UserPortableDataPreviewStatus.wrongOwner,
      );
      final wrongDoseOwner = service.inspect(
        packageJson: artifact.prettyJson,
        currentUserScope: _packageScope,
        currentDoseOwnerScope: 'different_raw_dose_owner',
        currentScopeKind: _scopeKind,
      );
      expect(wrongDoseOwner.status, UserPortableDataPreviewStatus.corrupt);
      expect(wrongDoseOwner.findings.join(' '), contains('doseTruth.binding'));
    },
  );

  test(
    'low-entropy raw dose owner is excluded while stable digest linkability is disclosed',
    () {
      const localEmailScope = 'local_user@example.test';
      final confirmed = _confirmedDose(
        id: 'intake_low_entropy_owner',
        dose: '100 mg',
        ownerScope: localEmailScope,
        confirmedAt: DateTime.utc(2026, 8, 17, 10, 1),
      );
      final first = service.create(
        snapshot: _snapshot(
          userScope: _packageScope,
          doseOwnerScope: localEmailScope,
          intakes: <Intake>[confirmed],
        ),
        generatedAt: generatedAt,
      );
      final second = service.create(
        snapshot: _snapshot(
          userScope: _packageScope,
          doseOwnerScope: localEmailScope,
          intakes: <Intake>[confirmed],
        ),
        generatedAt: generatedAt.add(const Duration(minutes: 1)),
      );
      Map receipt(String source) =>
          (((_files(source)['intakes.json'] as List).single
                      as Map)['doseConfirmation']
                  as Map)['receipt']
              as Map;
      final privacy =
          (_root(first.prettyJson)['manifest'] as Map)['privacyBoundary']
              as Map;

      expect(first.prettyJson, isNot(contains(localEmailScope)));
      expect(second.prettyJson, isNot(contains(localEmailScope)));
      expect(
        receipt(first.prettyJson)['owner_scope_digest'],
        receipt(second.prettyJson)['owner_scope_digest'],
      );
      expect(privacy['excluded'], contains('raw_dose_owner_scope'));
      expect(privacy['identityLinkability'], contains('link artifacts'));
      expect(privacy['identityLinkability'], contains('dictionary-matched'));
      expect(privacy['notAClaim'], contains('anonymous or unlinkable'));
    },
  );

  test('combined result gate holds stale raw dose despite a valid receipt', () {
    final confirmed = _confirmedDose(
      id: 'intake_stale_raw',
      dose: '100 mg',
      ownerScope: _scope,
      confirmedAt: DateTime.utc(2026, 8, 17, 10, 1),
    );
    final staleRaw = confirmed.copyWith(dosageNote: '200 mg');
    final artifact = service.create(
      snapshot: _snapshot(intakes: <Intake>[staleRaw]),
      generatedAt: generatedAt,
    );
    final row =
        (_files(artifact.prettyJson)['intakes.json'] as List).single as Map;
    final truth = row['doseTruth'] as Map;
    final resultUse = truth['resultUse'] as Map;

    expect(
      (row['doseConfirmation'] as Map)['evidenceStatus'],
      'receipt_present_unverified',
    );
    expect(resultUse['eligible'], isFalse);
    expect(
      resultUse['reasonCodes'],
      contains('dose_confirmation.raw_expression_mismatch'),
    );
    expect(truth['canonicalQuantity'], isNull);
    expect(
      service
          .inspect(
            packageJson: artifact.prettyJson,
            currentUserScope: _scope,
            currentDoseOwnerScope: _scope,
            currentScopeKind: _scopeKind,
          )
          .status,
      UserPortableDataPreviewStatus.ready,
    );
  });

  test('manifest createdAt is the dose-truth as-of boundary', () {
    final futureConfirmed = _confirmedDose(
      id: 'intake_future_confirmation',
      dose: '100 mg',
      ownerScope: _scope,
      confirmedAt: generatedAt.add(const Duration(minutes: 1)),
    );
    final artifact = service.create(
      snapshot: _snapshot(intakes: <Intake>[futureConfirmed]),
      generatedAt: generatedAt,
    );
    final root = _root(artifact.prettyJson);
    final row = ((root['files'] as Map)['intakes.json'] as List).single as Map;
    final truth = row['doseTruth'] as Map;
    final reasons = ((truth['resultUse'] as Map)['reasonCodes'] as List);

    expect(
      (root['manifest'] as Map)['createdAt'],
      generatedAt.toIso8601String(),
    );
    expect(truth['observedAtUtc'], generatedAt.toIso8601String());
    expect(reasons, contains('dose_confirmation.confirmed_after_observation'));
    expect(reasons, contains('assertion_graph.evidence_after_observation'));
    expect(truth['canonicalQuantity'], isNull);
    expect(
      service
          .inspect(
            packageJson: artifact.prettyJson,
            currentUserScope: _scope,
            currentDoseOwnerScope: _scope,
            currentScopeKind: _scopeKind,
          )
          .status,
      UserPortableDataPreviewStatus.ready,
    );
  });

  test(
    'canonical quantity normalizes mass to mg and preserves volume as mL',
    () {
      final volume = _confirmedDose(
        id: 'intake_volume',
        dose: '2.5 mL',
        ownerScope: _scope,
        confirmedAt: DateTime.utc(2026, 8, 17, 10, 1),
      );
      final artifact = service.create(
        snapshot: _snapshot(intakes: <Intake>[volume]),
        generatedAt: generatedAt,
      );
      final row =
          (_files(artifact.prettyJson)['intakes.json'] as List).single as Map;
      final canonical = (row['doseTruth'] as Map)['canonicalQuantity'] as Map;

      expect(canonical['value'], 2.5);
      expect(canonical['unit'], 'mL');
      expect(canonical['milligrams'], isNull);
      expect(canonical['dimension'], 'volume');
      final mapping = canonical['unitMappingEvidence'] as Map;
      expect(mapping['baseUnitCode'], 'mL');
      expect(mapping['sourceDimension'], 'volume');
      expect(mapping['targetDimension'], 'volume');
    },
  );

  test(
    'historical intake medication remains a truthful inactive selection target',
    () {
      final historical = Intake(
        id: 'intake_historical',
        drugId: 'drug_deselected',
        takenAt: generatedAt,
        dosageNote: '',
      );
      final artifact = service.create(
        snapshot: _snapshot(intakes: <Intake>[..._intakes, historical]),
        generatedAt: generatedAt,
      );
      final files = _files(artifact.prettyJson);
      final selections = (files['medication_selections.json'] as List)
          .cast<Map>();
      final historicalSelection = selections.singleWhere(
        (row) => row['id'] == 'drug_deselected',
      );
      expect(historicalSelection['activeAtExport'], isFalse);
      expect(historicalSelection['catalogStatus'], 'unresolved');
      final links = ((files['audit_links.json'] as Map)['links'] as List)
          .cast<Map>();
      expect(
        links.any(
          (row) =>
              row['recordType'] == 'intake' &&
              row['recordId'] == 'intake_historical' &&
              row['relationship'] == 'references_medication_selection' &&
              row['targetType'] == 'medication_selection' &&
              row['targetId'] == 'drug_deselected',
        ),
        isTrue,
      );
      expect(
        service
            .inspect(
              packageJson: artifact.prettyJson,
              currentUserScope: _scope,
              currentDoseOwnerScope: _scope,
              currentScopeKind: _scopeKind,
            )
            .status,
        UserPortableDataPreviewStatus.ready,
      );
    },
  );

  test('mechanical secret scan excludes raw account and capability values', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    const forbiddenValues = <String>[
      _scope,
      _patientId,
      _email,
      _activationToken,
      _ollamaEndpoint,
      _openAiEndpoint,
    ];
    for (final value in forbiddenValues) {
      expect(
        artifact.prettyJson,
        isNot(contains(value)),
        reason: 'portable JSON leaked "$value"',
      );
    }
    final profile = _files(artifact.prettyJson)['profile.json'] as Map;
    expect(profile, isNot(contains('email')));
    expect(profile['identityFieldStatus'], {
      'patientId': 'excluded_from_portable_package',
    });
    final reminder =
        (_files(artifact.prettyJson)['reminders.json'] as List).single as Map;
    expect(reminder, isNot(contains('activationToken')));
    expect(reminder['activationTokenStatus'], 'excluded_from_portable_package');
    expect(reminder['notificationPrivacyMode'], 'generic');
    expect(reminder['notificationLocaleCode'], 'ar');
    expect(reminder['notificationLocaleDecisionCode'], 'en');
    expect(
      reminder['sourcePresentationSha256'],
      matches(RegExp(r'^[a-f0-9]{64}$')),
    );
    expect(
      reminder['presentationIdentityStatus'],
      'source_digest_only_recompute_on_target',
    );
    expect(
      reminder['targetSchedulingConsentStatus'],
      'required_before_target_permission_or_scheduling',
    );
  });

  test('schema v2 migrates to v4 preview and marks absent observations', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final preview = service.inspect(
      packageJson: _legacyV2(artifact.prettyJson),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );

    expect(preview.status, UserPortableDataPreviewStatus.ready);
    expect(preview.schemaVersion, 2);
    expect(preview.schemaMigrationReceipt, isNotNull);
    expect(preview.schemaMigrationReceipt?.sourceVersion, 2);
    expect(preview.schemaMigrationReceipt?.targetVersion, 4);
    expect(preview.schemaMigrationReceipt?.decision, 'preview_only_no_write');
    expect(preview.proposedMigrations, hasLength(2));
    expect(preview.proposedMigrations.first, contains('minimal English'));
    expect(
      preview.proposedMigrations.last,
      contains('does not contain personal observations'),
    );
    expect(preview.reminderPresentation.totalCount, 1);
    expect(preview.reminderPresentation.enabledIntentCount, 1);
    expect(preview.reminderPresentation.targetConsentRequiredCount, 1);
    expect(preview.reminderPresentation.legacyDefaultCount, 1);
    expect(preview.reminderPresentation.privacyModes, ['minimal']);
    expect(preview.reminderPresentation.scheduledLanguageCodes, ['en']);
    expect(
      (preview.schemaMigrationReceipt?.warnings ?? const <String>[]).last,
      contains('marks them unavailable'),
    );
    expect(
      preview.findings.join(' '),
      contains('no record, preference, reminder, or account state was changed'),
    );
  });

  test(
    'schema v3 migration marks observations unavailable without inference',
    () {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );
      final preview = service.inspect(
        packageJson: _legacyV3(artifact.prettyJson),
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );

      expect(preview.status, UserPortableDataPreviewStatus.ready);
      expect(preview.schemaVersion, 3);
      expect(preview.schemaMigrationReceipt?.targetVersion, 4);
      expect(
        preview.schemaMigrationReceipt?.warnings.single,
        contains('marks them unavailable'),
      );
      expect(
        preview.proposedMigrations.single,
        contains('does not contain personal observations'),
      );
    },
  );

  test(
    'presentation intent validates shape while source policy drift stays visible',
    () {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );
      final invalid = _root(artifact.prettyJson);
      final invalidFiles = Map<String, Object?>.from(invalid['files'] as Map);
      final invalidRows = List<Object?>.from(
        invalidFiles['reminders.json'] as List,
      );
      final invalidReminder = Map<String, Object?>.from(
        invalidRows.single as Map,
      )..['notificationPrivacyMode'] = 'public_details';
      invalidRows[0] = invalidReminder;
      invalidFiles['reminders.json'] = invalidRows;
      invalid['files'] = invalidFiles;
      final invalidPreview = service.inspect(
        packageJson: _resign(invalid),
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(invalidPreview.status, UserPortableDataPreviewStatus.corrupt);
      expect(
        invalidPreview.findings.join(' '),
        contains('notificationPrivacyMode'),
      );

      final unsupportedLocale = _root(artifact.prettyJson);
      final unsupportedFiles = Map<String, Object?>.from(
        unsupportedLocale['files'] as Map,
      );
      final unsupportedRows = List<Object?>.from(
        unsupportedFiles['reminders.json'] as List,
      );
      final unsupportedReminder = Map<String, Object?>.from(
        unsupportedRows.single as Map,
      )..['notificationLocaleCode'] = 'de';
      unsupportedRows[0] = unsupportedReminder;
      unsupportedFiles['reminders.json'] = unsupportedRows;
      unsupportedLocale['files'] = unsupportedFiles;
      final unsupportedPreview = service.inspect(
        packageJson: _resign(unsupportedLocale),
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(unsupportedPreview.status, UserPortableDataPreviewStatus.corrupt);
      expect(
        unsupportedPreview.findings.join(' '),
        contains('notificationLocaleCode'),
      );

      final drift = _root(artifact.prettyJson);
      final driftFiles = Map<String, Object?>.from(drift['files'] as Map);
      final driftRows = List<Object?>.from(
        driftFiles['reminders.json'] as List,
      );
      final driftReminder = Map<String, Object?>.from(driftRows.single as Map)
        ..['sourcePresentationSha256'] =
            '0000000000000000000000000000000000000000000000000000000000000000';
      driftRows[0] = driftReminder;
      driftFiles['reminders.json'] = driftRows;
      drift['files'] = driftFiles;
      final driftPreview = service.inspect(
        packageJson: _resign(drift),
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(driftPreview.status, UserPortableDataPreviewStatus.ready);
      expect(driftPreview.reminderPresentation.currentPolicyMatchCount, 0);
      expect(driftPreview.reminderPresentation.currentPolicyDriftCount, 1);
      expect(driftPreview.reminderPresentation.localeDecisionMismatchCount, 1);
    },
  );

  test('owner mismatch and checksum tampering fail closed', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final wrongOwner = service.inspect(
      packageJson: artifact.prettyJson,
      currentUserScope: 'different_scope',
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(wrongOwner.status, UserPortableDataPreviewStatus.wrongOwner);
    expect(wrongOwner.mayProceedToFutureImport, isFalse);

    final tampered = _root(artifact.prettyJson);
    final files = Map<String, Object?>.from(tampered['files'] as Map);
    final intakes = List<Object?>.from(files['intakes.json'] as List);
    intakes.add(<String, Object?>{'id': 'intake_tampered'});
    files['intakes.json'] = intakes;
    tampered['files'] = files;
    final corrupt = service.inspect(
      packageJson: jsonEncode(tampered),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(corrupt.status, UserPortableDataPreviewStatus.corrupt);
    expect(corrupt.findings.join(' '), contains('checksum'));
  });

  test('new schema and unsupported fields never become import-ready', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final newer = _root(artifact.prettyJson)..['schemaVersion'] = 5;
    final newerPreview = service.inspect(
      packageJson: jsonEncode(newer),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(
      newerPreview.status,
      UserPortableDataPreviewStatus.unsupportedSchema,
    );
    expect(newerPreview.mayProceedToFutureImport, isFalse);
    expect(newerPreview.proposedMigrations, isEmpty);

    final legacyV1 = _root(artifact.prettyJson)..['schemaVersion'] = 1;
    final legacyPreview = service.inspect(
      packageJson: jsonEncode(legacyV1),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(
      legacyPreview.status,
      UserPortableDataPreviewStatus.unsupportedSchema,
    );
    expect(legacyPreview.proposedMigrations.single, contains('schema 1 to 4'));
    expect(legacyPreview.mayProceedToFutureImport, isFalse);

    final fractional = _root(artifact.prettyJson)..['schemaVersion'] = 1.5;
    final fractionalPreview = service.inspect(
      packageJson: jsonEncode(fractional),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(
      fractionalPreview.status,
      UserPortableDataPreviewStatus.unsupportedSchema,
    );

    final unknown = _root(artifact.prettyJson)..['futureField'] = true;
    final unknownPreview = service.inspect(
      packageJson: jsonEncode(unknown),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(
      unknownPreview.status,
      UserPortableDataPreviewStatus.unsupportedSchema,
    );
    expect(unknownPreview.unsupportedFields, contains(r'$.futureField'));
    expect(unknownPreview.mayProceedToFutureImport, isFalse);
  });

  test('manifest privacy and owner semantics fail closed', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final root = _root(artifact.prettyJson);
    final manifest = Map<String, Object?>.from(root['manifest'] as Map);
    final privacy = Map<String, Object?>.from(
      manifest['privacyBoundary'] as Map,
    )..['encryption'] = 'misleading-encrypted-claim';
    manifest['privacyBoundary'] = privacy;
    root['manifest'] = manifest;

    final preview = service.inspect(
      packageJson: jsonEncode(root),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.mayProceedToFutureImport, isFalse);

    expect(
      () => service.create(
        snapshot: UserPortableDataSnapshot(
          userScope: _scope,
          doseOwnerScope: _scope,
          scopeKind: 'unreviewed_scope',
          profile: UserProfile.defaults(),
          activeDrugIds: const <String>[],
          intakes: const <Intake>[],
          meals: const <Meal>[],
          medicationCatalog: const <DrugDefinition>[],
          foodCatalog: const <FoodItem>[],
          reminders: const <UserLoggingReminder>[],
        ),
        generatedAt: generatedAt,
      ),
      throwsArgumentError,
    );
  });

  test('deep unknown field is reported after a self-consistent rehash', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    final root = _root(artifact.prettyJson);
    final files = Map<String, Object?>.from(root['files'] as Map);
    final intakes = List<Object?>.from(files['intakes.json'] as List);
    final first = Map<String, Object?>.from(intakes.first as Map);
    final dose = Map<String, Object?>.from(first['dose'] as Map)
      ..['futureDoseSemantics'] = 'must_not_be_ignored';
    first['dose'] = dose;
    intakes[0] = first;
    files['intakes.json'] = intakes;
    root['files'] = files;

    final preview = service.inspect(
      packageJson: _resign(root),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.unsupportedSchema);
    expect(
      preview.unsupportedFields,
      contains(r'$.files.intakes.json[0].dose.futureDoseSemantics'),
    );
  });

  test('self-resigned scalar and domain violations never become ready', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );

    final mutations = <String, void Function(Map<String, Object?> root)>{
      'non-string intake timestamp': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['intakes.json'] as List);
        rows[0] = Map<String, Object?>.from(rows[0] as Map)..['takenAt'] = 123;
        files['intakes.json'] = rows;
        root['files'] = files;
      },
      'non-numeric dose': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['intakes.json'] as List);
        final row = Map<String, Object?>.from(rows[0] as Map);
        row['dose'] = Map<String, Object?>.from(row['dose'] as Map)
          ..['amount'] = 'x';
        rows[0] = row;
        files['intakes.json'] = rows;
        root['files'] = files;
      },
      'missing required dose key': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['intakes.json'] as List);
        final row = Map<String, Object?>.from(rows[0] as Map);
        row['dose'] = Map<String, Object?>.from(row['dose'] as Map)
          ..remove('unit');
        rows[0] = row;
        files['intakes.json'] = rows;
        root['files'] = files;
      },
      'invalid reminder weekdays': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['reminders.json'] as List);
        rows[0] = Map<String, Object?>.from(rows[0] as Map)
          ..['weekdays'] = <int>[0, 8];
        files['reminders.json'] = rows;
        root['files'] = files;
      },
      'invalid reminder minute': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final rows = List<Object?>.from(files['reminders.json'] as List);
        rows[0] = Map<String, Object?>.from(rows[0] as Map)
          ..['minuteOfDay'] = 1440;
        files['reminders.json'] = rows;
        root['files'] = files;
      },
      'nutrient null-zero contradiction': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final meals = List<Object?>.from(files['meals.json'] as List);
        final meal = Map<String, Object?>.from(meals[0] as Map);
        final items = List<Object?>.from(meal['items'] as List);
        final item = Map<String, Object?>.from(items[0] as Map);
        final nutrients = Map<String, Object?>.from(
          item['nutrientsPer100g'] as Map,
        );
        nutrients['protein'] =
            Map<String, Object?>.from(nutrients['protein'] as Map)
              ..['missing'] = false
              ..['value'] = 0.0;
        item['nutrientsPer100g'] = nutrients;
        items[0] = item;
        meal['items'] = items;
        meals[0] = meal;
        files['meals.json'] = meals;
        root['files'] = files;
      },
      'quantity cross-field mismatch': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final meals = List<Object?>.from(files['meals.json'] as List);
        final meal = Map<String, Object?>.from(meals[0] as Map);
        final items = List<Object?>.from(meal['items'] as List);
        final item = Map<String, Object?>.from(items[0] as Map);
        item['quantity'] = Map<String, Object?>.from(item['quantity'] as Map)
          ..['grams'] = -1.0;
        items[0] = item;
        meal['items'] = items;
        meals[0] = meal;
        files['meals.json'] = meals;
        root['files'] = files;
      },
      'audit relationship mismatch': (root) {
        final files = Map<String, Object?>.from(root['files'] as Map);
        final audit = Map<String, Object?>.from(
          files['audit_links.json'] as Map,
        );
        final links = List<Object?>.from(audit['links'] as List);
        links.removeLast();
        audit['links'] = links;
        files['audit_links.json'] = audit;
        root['files'] = files;
      },
    };

    for (final mutation in mutations.entries) {
      final root = _root(artifact.prettyJson);
      mutation.value(root);
      final preview = service.inspect(
        packageJson: _resign(root),
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(
        preview.status,
        isNot(UserPortableDataPreviewStatus.ready),
        reason: mutation.key,
      );
      expect(preview.mayProceedToFutureImport, isFalse, reason: mutation.key);
    }
  });

  test('manifest hash/count types and owner kind fail closed', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );

    final countRoot = _root(artifact.prettyJson);
    final countManifest = Map<String, Object?>.from(
      countRoot['manifest'] as Map,
    );
    final manifestFiles = List<Object?>.from(countManifest['files'] as List);
    manifestFiles[0] = Map<String, Object?>.from(manifestFiles[0] as Map)
      ..['recordCount'] = 1.0;
    countManifest['files'] = manifestFiles;
    countRoot['manifest'] = countManifest;
    final countPreview = service.inspect(
      packageJson: jsonEncode(countRoot),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(countPreview.status, UserPortableDataPreviewStatus.corrupt);

    final kindRoot = _root(artifact.prettyJson);
    final kindManifest = Map<String, Object?>.from(kindRoot['manifest'] as Map);
    kindManifest['ownerScope'] = Map<String, Object?>.from(
      kindManifest['ownerScope'] as Map,
    )..['kind'] = 'local_device_account';
    kindRoot['manifest'] = kindManifest;
    final kindPreview = service.inspect(
      packageJson: jsonEncode(kindRoot),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(kindPreview.status, isNot(UserPortableDataPreviewStatus.ready));
  });

  test('unexpected structural exceptions never echo private input', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      generatedAt: generatedAt,
    );
    const privateSentinel = '/private/account/path/secret-value';
    final root = _root(artifact.prettyJson);
    final manifest = Map<String, Object?>.from(root['manifest'] as Map)
      ..['packageId'] = <String, Object?>{'private': privateSentinel};
    root['manifest'] = manifest;

    final preview = service.inspect(
      packageJson: jsonEncode(root),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.findings, isNotEmpty);
    expect(preview.findings.join(' '), isNot(contains(privateSentinel)));
  });

  test('malformed JSON errors do not reflect private source text', () {
    const privateSentinel = 'private-email@example.test';
    final preview = service.inspect(
      packageJson: '{"private":"$privateSentinel","invalid":tru}',
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(
      preview.findings.single,
      'The package is not valid JSON or exceeds a structural safety budget.',
    );
    expect(preview.findings.single, isNot(contains(privateSentinel)));
  });

  test('duplicate JSON keys are rejected before document decoding', () {
    var decodeCalls = 0;
    final guarded = UserPortableDataPackageService(
      decodeJson: (source) {
        decodeCalls += 1;
        return jsonDecode(source);
      },
    );
    final preview = guarded.inspect(
      packageJson: '{"format":"a","\\u0066ormat":"b"}',
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.findings.single, contains('Duplicate JSON object keys'));
    expect(decodeCalls, 0);
  });

  test('non-interoperable Unicode is rejected before document decoding', () {
    for (final source in <String>[
      r'{"value":"\ud800"}',
      r'{"value":"\udc00"}',
      r'{"value":"\ufdd0"}',
      r'{"value":"\ud83f\udffe"}',
      '{"value":"${String.fromCharCode(0xd800)}"}',
    ]) {
      var decodeCalls = 0;
      final guarded = UserPortableDataPackageService(
        decodeJson: (value) {
          decodeCalls += 1;
          return jsonDecode(value);
        },
      );
      final preview = guarded.inspect(
        packageJson: source,
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(preview.status, UserPortableDataPreviewStatus.corrupt);
      expect(preview.findings.single, contains('Unicode'));
      expect(decodeCalls, 0);
    }
  });

  test('a valid escaped non-BMP scalar reaches the full decoder', () {
    var decodeCalls = 0;
    final guarded = UserPortableDataPackageService(
      decodeJson: (source) {
        decodeCalls += 1;
        return jsonDecode(source);
      },
    );
    final preview = guarded.inspect(
      packageJson: r'{"value":"\ud83d\ude80"}',
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(decodeCalls, 1);
  });

  test('oversize numeric token is rejected before document decoding', () {
    var decodeCalls = 0;
    final decoderSpy = UserPortableDataPackageService(
      decodeJson: (source) {
        decodeCalls += 1;
        return jsonDecode(source);
      },
    );
    final preview = decoderSpy.inspect(
      packageJson:
          '{"value":${List<String>.filled(userPortableDataMaxNumberTokenChars + 1, '1').join()}}',
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.findings.single, contains('number'));
    expect(decodeCalls, 0);
  });

  test('shallow over-node input is rejected before document decoding', () {
    var decodeCalls = 0;
    final guarded = UserPortableDataPackageService(
      decodeJson: (source) {
        decodeCalls += 1;
        throw StateError('full decoder must not run');
      },
    );
    final source =
        '[${List<String>.filled(userPortableDataMaxJsonNodes, '0').join(',')}]';
    final stopwatch = Stopwatch()..start();
    final preview = guarded.inspect(
      packageJson: source,
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    stopwatch.stop();
    expect(preview.status, UserPortableDataPreviewStatus.corrupt);
    expect(preview.findings.single, contains('node JSON budget'));
    expect(decodeCalls, 0);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  }, timeout: const Timeout(Duration(seconds: 10)));

  test(
    'preview reports conflicts while remaining a pure no-write operation',
    () {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );
      final before = artifact.canonicalJson;
      final preview = service.inspect(
        packageJson: artifact.canonicalJson,
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
        existingRecordIds: const <String, Set<String>>{
          'intakes.json': <String>{'intake_zero'},
          'meals.json': <String>{'meal_1'},
        },
      );
      expect(preview.status, UserPortableDataPreviewStatus.ready);
      expect(preview.conflictCount, 2);
      expect(preview.conflicts['intakes.json'], ['intake_zero']);
      expect(artifact.canonicalJson, before);
      expect(preview.findings.last, contains('no record'));
    },
  );

  test('generation rejects duplicate and unsafe stable ids', () {
    expect(
      () => service.create(
        snapshot: _snapshot(activeDrugIds: const ['drug_test', 'drug_test']),
        generatedAt: generatedAt,
      ),
      throwsFormatException,
    );
    expect(
      () => service.create(
        snapshot: _snapshot(
          intakes: <Intake>[
            ..._intakes,
            Intake(
              id: '../unsafe',
              drugId: 'drug_test',
              takenAt: generatedAt,
              dosageNote: '',
            ),
          ],
        ),
        generatedAt: generatedAt,
      ),
      throwsFormatException,
    );
  });

  test(
    'self-consistent unsafe input id is rejected after integrity checks',
    () {
      final artifact = service.create(
        snapshot: _snapshot(),
        generatedAt: generatedAt,
      );
      final root = _root(artifact.prettyJson);
      final files = Map<String, Object?>.from(root['files'] as Map);
      final rows = List<Object?>.from(files['intakes.json'] as List);
      final first = Map<String, Object?>.from(rows.first as Map)
        ..['id'] = '../unsafe';
      rows[0] = first;
      files['intakes.json'] = rows;
      root['files'] = files;
      final resigned = _resign(root);

      final preview = service.inspect(
        packageJson: resigned,
        currentUserScope: _scope,
        currentDoseOwnerScope: _scope,
        currentScopeKind: _scopeKind,
      );
      expect(preview.status, UserPortableDataPreviewStatus.corrupt);
      expect(preview.findings.join(' '), contains('unsafe id'));
    },
  );

  test('input byte, depth, string, map, and record budgets fail closed', () {
    const tiny = UserPortableDataPackageService(maxPackageBytes: 64);
    final bytes = tiny.inspect(
      packageJson: '{"padding":"${List.filled(80, 'x').join()}"}',
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(bytes.status, UserPortableDataPreviewStatus.corrupt);
    expect(bytes.findings.single, contains('byte input budget'));

    var decodedOversizeSource = false;
    final decoderSpy = UserPortableDataPackageService(
      maxPackageBytes: 64,
      decodeJson: (source) {
        decodedOversizeSource = true;
        return jsonDecode(source);
      },
    );
    final obviousOversize = decoderSpy.inspect(
      packageJson: List<String>.filled(65, 'x').join(),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(obviousOversize.status, UserPortableDataPreviewStatus.corrupt);
    expect(decodedOversizeSource, isFalse);

    final deep = service.inspect(
      packageJson:
          '${List.filled(userPortableDataMaxJsonDepth + 1, '[').join()}'
          '${List.filled(userPortableDataMaxJsonDepth + 1, ']').join()}',
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(deep.status, UserPortableDataPreviewStatus.corrupt);
    expect(deep.findings.single, contains('nesting depth'));

    final longString = service.inspect(
      packageJson: jsonEncode(<String, Object?>{
        'value': List.filled(userPortableDataMaxStringBytes + 1, 'x').join(),
      }),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(longString.status, UserPortableDataPreviewStatus.corrupt);
    expect(longString.findings.single, contains('string limit'));

    final wideMap = service.inspect(
      packageJson: jsonEncode(<String, Object?>{
        for (var i = 0; i <= userPortableDataMaxMapFields; i++) 'f$i': i,
      }),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(wideMap.status, UserPortableDataPreviewStatus.corrupt);
    expect(wideMap.findings.single, contains('fields'));

    final overRecords = <String, Object?>{
      'format': userPortableDataPackageFormat,
      'schemaVersion': userPortableDataPackageSchemaVersion,
      'manifest': <String, Object?>{},
      'files': <String, Object?>{
        'profile.json': <String, Object?>{},
        'preferences.json': <String, Object?>{},
        'medication_selections.json': <Object?>[
          for (
            var i = 0;
            i <= userPortableDataRecordLimits['medication_selections.json']!;
            i++
          )
            <String, Object?>{'id': 'drug_$i'},
        ],
        'intakes.json': <Object?>[],
        'meals.json': <Object?>[],
        'reminders.json': <Object?>[],
        'audit_links.json': <String, Object?>{'links': <Object?>[]},
      },
    };
    final records = service.inspect(
      packageJson: jsonEncode(overRecords),
      currentUserScope: _scope,
      currentDoseOwnerScope: _scope,
      currentScopeKind: _scopeKind,
    );
    expect(records.status, UserPortableDataPreviewStatus.corrupt);
    expect(records.findings.join(' '), contains('limit is'));
  });
}

const _scope = 'firebase_uid_Q7yN8Zx5X2';
const _packageScope = 'opaque_export_capability_R4m2V9k8P6';
const _scopeKind = 'firebase_authenticated_account';
const _patientId = 'patient-id-that-must-not-export';
const _email = 'sensitive@example.test';
const _activationToken = '0123456789abcdef0123456789abcdef';
const _ollamaEndpoint = 'http://127.0.0.1:11434/private-test';
const _openAiEndpoint = 'http://127.0.0.1:8080/private-test';

final _intakes = <Intake>[
  Intake(
    id: 'intake_null',
    drugId: 'drug_test',
    takenAt: DateTime.utc(2026, 8, 17, 11),
    dosageNote: 'unknown amount',
  ),
  Intake(
    id: 'intake_zero',
    drugId: 'drug_test',
    takenAt: DateTime.utc(2026, 8, 17, 12),
    dosageNote: 'explicit zero fixture',
    doseAmount: 0,
    doseUnit: 'mg',
    dosageForm: 'tablet',
    route: 'oral',
    releaseType: 'immediate_release',
  ),
];

UserPortableDataSnapshot _snapshot({
  bool reverse = false,
  Iterable<String>? activeDrugIds,
  Iterable<Intake>? intakes,
  String userScope = _scope,
  String doseOwnerScope = _scope,
}) {
  var values = intakes?.toList() ?? List<Intake>.from(_intakes);
  if (reverse) values = values.reversed.toList();
  final foods = <FoodItem>[
    FoodItem(
      id: 'food_missing',
      name: 'Missing protein fixture',
      category: FoodCategory.other,
      proteinG: 0,
      carbsG: 2,
      fatG: 1,
      fiberG: 0,
      sodiumMg: 0,
      missingNutrientFields: const {'proteinG'},
      sourceSystem: 'TEST_FOOD',
      sourceFoodCode: 'MISSING-1',
      jurisdiction: 'CA',
      basisType: 'per_100g',
      preparationState: 'cooked',
      qualifierKind: 'analytical',
    ),
    FoodItem(
      id: 'food_zero',
      name: 'True zero fixture',
      category: FoodCategory.other,
      proteinG: 0,
      carbsG: 3,
      fatG: 0,
      fiberG: 0,
      sodiumMg: 0,
      missingNutrientFields: const {},
      sourceSystem: 'TEST_FOOD',
      sourceFoodCode: 'ZERO-1',
      jurisdiction: 'CA',
      basisType: 'per_100g',
      preparationState: 'raw',
      qualifierKind: 'analytical',
    ),
  ];
  final meal = Meal(
    id: 'meal_1',
    eatenAt: DateTime.utc(2026, 8, 17, 13),
    recordedAt: DateTime.utc(2026, 8, 17, 13, 5),
    occurredAt: DateTime.utc(2026, 8, 17, 12, 55),
    timeSource: 'user_entered',
    timePrecision: 'exact',
    title: 'Fixture meal',
    items: <MealItem>[
      MealItem.fromFood(food: foods[0], quantityFactor: 1),
      MealItem.fromFood(food: foods[1], quantityFactor: 0.5),
    ],
  );
  final reminders = <UserLoggingReminder>[
    const UserLoggingReminder(
      id: 'reminder_1',
      kind: UserLoggingReminderKind.intakeLog,
      label: 'User-authored label',
      minuteOfDay: 540,
      weekdays: {1, 3, 5},
      enabled: true,
      activationToken: _activationToken,
      notificationPrivacyMode: ReminderNotificationPrivacyMode.generic,
      notificationLocaleCode: 'ar',
      notificationLocaleDecisionCode: 'en',
    ),
  ];
  var observations = <PersonalObservation>[
    PersonalObservation.create(
      id: 'observation_symptom',
      kind: PersonalObservationKind.symptom,
      occurredAt: DateTime.utc(2026, 8, 17, 9),
      recordedAt: DateTime.utc(2026, 8, 17, 9, 5),
      originalTimezone: 'America/Toronto',
      source: PersonalObservationSource.selfReported,
      recorderId: 'recorder_private_id',
      status: PersonalObservationStatus.recorded,
      symptomLabel: 'Tremor',
      severity: 4,
      notes: 'Owner-entered note retained in local export.',
    ),
    PersonalObservation.create(
      id: 'observation_bp',
      kind: PersonalObservationKind.bloodPressure,
      occurredAt: DateTime.utc(2026, 8, 17, 10),
      recordedAt: DateTime.utc(2026, 8, 17, 10, 2),
      originalTimezone: 'America/Toronto',
      source: PersonalObservationSource.deviceManual,
      recorderId: 'recorder_private_id',
      status: PersonalObservationStatus.recorded,
      systolic: 122.5,
      diastolic: 81,
      unit: PersonalObservation.bloodPressureUnit,
      posture: BloodPressurePosture.sitting,
    ),
    PersonalObservation.create(
      id: 'observation_motor_unknown',
      kind: PersonalObservationKind.selfReportedMotorState,
      occurredAt: DateTime.utc(2026, 8, 17, 11),
      recordedAt: DateTime.utc(2026, 8, 17, 11, 1),
      originalTimezone: 'America/Toronto',
      source: PersonalObservationSource.selfReported,
      recorderId: 'recorder_private_id',
      status: PersonalObservationStatus.unknown,
    ),
    PersonalObservation.create(
      id: 'observation_bp_unmeasured',
      kind: PersonalObservationKind.bloodPressure,
      occurredAt: DateTime.utc(2026, 8, 17, 12),
      recordedAt: DateTime.utc(2026, 8, 17, 12, 2),
      originalTimezone: 'America/Toronto',
      source: PersonalObservationSource.caregiverReported,
      recorderId: 'recorder_private_id',
      status: PersonalObservationStatus.notMeasured,
      unit: PersonalObservation.bloodPressureUnit,
      posture: BloodPressurePosture.unknown,
    ),
  ];
  final drugs = <DrugDefinition>[
    DrugDefinition(
      id: 'drug_test',
      genericName: 'Test medicine',
      brandNames: const ['Fixture'],
      tags: const [DrugTag.unknown],
      notes: 'Fixture only',
      sourceSystem: 'TEST_LABEL',
      sourceProductCode: 'LABEL-1',
      jurisdiction: 'CA',
      route: 'oral',
      dosageForm: 'tablet',
      releaseType: 'immediate_release',
    ),
  ];
  if (reverse) {
    foods.setAll(0, foods.reversed.toList());
    drugs.setAll(0, drugs.reversed.toList());
    reminders.setAll(0, reminders.reversed.toList());
    observations = observations.reversed.toList();
  }
  return UserPortableDataSnapshot(
    userScope: userScope,
    doseOwnerScope: doseOwnerScope,
    scopeKind: _scopeKind,
    profile: UserProfile.defaults()
        .copyWith(
          patientId: _patientId,
          displayLocale: 'en-US',
          contentJurisdictionOverride: const ['US', 'CA'],
          localAiOllamaEndpoint: _ollamaEndpoint,
          localAiOpenAiCompatEndpoint: _openAiEndpoint,
        )
        .withLocalAiConsentDecision(
          enabled: true,
          recordedAt: DateTime.utc(2026, 8, 18),
          source: 'test_fixture',
        ),
    activeDrugIds: activeDrugIds ?? const ['drug_test'],
    intakes: values,
    meals: <Meal>[meal],
    medicationCatalog: drugs,
    foodCatalog: foods,
    reminders: reminders,
    observations: observations,
  );
}

Intake _confirmedDose({
  required String id,
  required String dose,
  required String ownerScope,
  required DateTime confirmedAt,
}) {
  final prepared = AdministrationDoseConfirmationCoordinator().prepare(
    draft: Intake(
      id: id,
      drugId: 'drug_test',
      takenAt: DateTime.utc(2026, 8, 17, 10),
      dosageNote: dose,
    ),
    current: null,
    expectedRecordRevisionDigest:
        administrationDoseConfirmationAbsentRevisionDigest,
    ownerScope: ownerScope,
    operationId: 'portable_$id',
    confirmationRequested: true,
    assertionSource: AdministrationDoseAssertionSource.typed,
    confirmationAction: 'timeline.explicit_checkbox',
    uiContractVersion: 'timeline-dose-confirmation:1',
    confirmedAt: confirmedAt,
  );
  return prepared.intake!;
}

Map<String, Object?> _root(String json) =>
    Map<String, Object?>.from(jsonDecode(json) as Map);

Map<String, Object?> _files(String json) =>
    Map<String, Object?>.from(_root(json)['files'] as Map);

String _legacyV2(String source) {
  final root = _root(source)..['schemaVersion'] = 2;
  final files = Map<String, Object?>.from(root['files'] as Map);
  files.remove('observations.json');
  final rows = List<Object?>.from(files['reminders.json'] as List);
  for (var index = 0; index < rows.length; index++) {
    final row = Map<String, Object?>.from(rows[index] as Map)
      ..remove('notificationPrivacyMode')
      ..remove('notificationLocaleCode')
      ..remove('notificationLocaleDecisionCode')
      ..remove('sourcePresentationSchema')
      ..remove('sourcePresentationSha256')
      ..remove('presentationIdentityStatus')
      ..remove('targetSchedulingConsentStatus');
    rows[index] = row;
  }
  files['reminders.json'] = rows;
  root['files'] = files;
  final manifest = Map<String, Object?>.from(root['manifest'] as Map);
  final privacy = Map<String, Object?>.from(manifest['privacyBoundary'] as Map)
    ..['scope'] =
        'Current loaded profile, selections, intakes, meals, this-device reminders, and relationship audit links.'
    ..['excluded'] = PortableSchemaMigrationRegistry.excludedValuesForVersion(
      2,
    );
  manifest['privacyBoundary'] = privacy;
  root['manifest'] = manifest;
  return _resign(root);
}

String _legacyV3(String source) {
  final root = _root(source)..['schemaVersion'] = 3;
  final files = Map<String, Object?>.from(root['files'] as Map)
    ..remove('observations.json');
  root['files'] = files;
  final manifest = Map<String, Object?>.from(root['manifest'] as Map);
  final privacy = Map<String, Object?>.from(manifest['privacyBoundary'] as Map)
    ..['scope'] =
        'Current loaded profile, selections, intakes, meals, this-device reminders, and relationship audit links.'
    ..['excluded'] = PortableSchemaMigrationRegistry.excludedValuesForVersion(
      3,
    );
  manifest['privacyBoundary'] = privacy;
  root['manifest'] = manifest;
  return _resign(root);
}

String _resign(Map<String, Object?> root) {
  final files = Map<String, Object?>.from(root['files'] as Map);
  final manifest = Map<String, Object?>.from(root['manifest'] as Map);
  final owner = Map<String, Object?>.from(manifest['ownerScope'] as Map);
  final integrity = Map<String, Object?>.from(manifest['integrity'] as Map);
  final contentSha = _digest(_canonical(files));
  integrity['contentSha256'] = contentSha;
  final packageId = _digest(
    'parkinsum-portable-package-v${root['schemaVersion']}|'
    '${owner['bindingSha256']}|$contentSha',
  );
  manifest['packageId'] = packageId;
  manifest['integrity'] = integrity;
  manifest['files'] = <Object?>[
    for (final path in PortableSchemaMigrationRegistry.filePathsForVersion(
      root['schemaVersion'] as int,
    ))
      <String, Object?>{
        'path': path,
        'sha256': _digest(_canonical(files[path])),
        'recordCount': _count(files[path]),
      },
  ];
  root['manifest'] = manifest;
  return _canonical(root);
}

int _count(Object? value) {
  if (value is List) return value.length;
  if (value is Map && value['records'] is List) {
    return (value['records'] as List).length;
  }
  if (value is Map && value['records'] is List) {
    return (value['records'] as List).length;
  }
  if (value is Map && value['links'] is List) {
    return (value['links'] as List).length;
  }
  return value is Map ? 1 : 0;
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();

String _canonical(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{for (final key in keys) key: _sorted(value[key])};
  }
  if (value is Iterable) return value.map(_sorted).toList();
  return value;
}
