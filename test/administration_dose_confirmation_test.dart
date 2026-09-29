import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/medication_assertion_reconciliation.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';

void main() {
  final coordinator = AdministrationDoseConfirmationCoordinator();
  final product = MedicationProductSelection(
    packId: 'pack_a',
    identifierSystem: 'din',
    identifierValue: '12345678',
    displayName: 'Synthetic pack',
    labelerName: 'Synthetic labeler',
    strengthDisplay: 'levodopa 100 mg',
    packageDescription: 'fixture only',
  );

  Intake draft({
    String note = '100 mg',
    DateTime? takenAt,
    MedicationProductSelection? selectedProduct,
  }) => Intake(
    id: 'intake_a',
    drugId: 'levodopa',
    takenAt: takenAt ?? DateTime.utc(2026, 8, 27, 12),
    dosageNote: note,
    productSelection: selectedProduct,
  );

  AdministrationDosePreparationResult confirm(
    Intake value, {
    Intake? current,
    String owner = 'account_a',
    String? expectedRevision,
  }) => coordinator.prepare(
    draft: value,
    current: current,
    expectedRecordRevisionDigest:
        expectedRevision ??
        AdministrationDoseConfirmationCoordinator.revisionDigest(current),
    ownerScope: owner,
    operationId: 'event_op_20260827_fixture',
    confirmationRequested: true,
    assertionSource: AdministrationDoseAssertionSource.typed,
    confirmationAction: 'timeline.explicit_checkbox',
    uiContractVersion: 'timeline-dose-confirmation:1',
    confirmedAt: DateTime.utc(2026, 8, 27, 12, 1),
  );

  test('confirmed receipt round-trips and gates the exact dose', () {
    final prepared = confirm(draft(selectedProduct: product));
    expect(prepared.status, AdministrationDosePreparationStatus.confirmed);
    final intake = prepared.intake!;
    final receipt = intake.doseConfirmation!;
    expect(receipt.operationId, 'event_op_20260827_fixture');
    expect(
      receipt.expectedRecordRevisionDigest,
      administrationDoseConfirmationAbsentRevisionDigest,
    );
    expect(receipt.rawExpression, '100 mg');
    expect(receipt.structuredValue, 100);
    expect(receipt.structuredUnit, 'mg');
    expect(receipt.parsedExpression['role'], 'administrationDose');
    final unit = receipt.parsedExpression['unit'] as Map;
    final mapping = unit['mappingEvidence'] as Map;
    expect(mapping['sourceRevision'], receipt.grammarDigest);
    expect(mapping['mappingType'], 'exactIdentity');
    expect(receipt.toJson(), isNot(containsValue('account_a')));

    final restored = Intake.fromJson(intake.toJson());
    expect(
      restored.doseConfirmationIntegrity,
      IntakeDoseConfirmationIntegrity.valid,
    );
    expect(restored.toJson(), intake.toJson());
    final evaluation = coordinator.evaluate(restored, ownerScope: 'account_a');
    expect(evaluation.status, AdministrationDoseEvaluationStatus.confirmed);
    expect(evaluation.value, 100);
    expect(evaluation.unit, 'mg');
  });

  test('grammar-v3 confirmation cannot authorize a grammar-v4 result', () {
    const legacyGrammarDigest =
        '9cdda65781594df1239522c274a84f0e318560e94c3cd8f75d8f5aec265d5dca';
    final confirmed = confirm(draft()).intake!;
    final currentReceipt = confirmed.doseConfirmation!;
    final parsedExpression = Map<String, Object?>.from(
      currentReceipt.parsedExpression,
    );
    final unit = Map<String, Object?>.from(parsedExpression['unit'] as Map)
      ..['mappingEvidence'] = Map<String, Object?>.from(
        (parsedExpression['unit'] as Map)['mappingEvidence'] as Map,
      );
    final mapping = Map<String, Object?>.from(unit['mappingEvidence'] as Map)
      ..['sourceRevision'] = legacyGrammarDigest;
    unit['mappingEvidence'] = mapping;
    parsedExpression['unit'] = unit;

    final legacyReceipt = AdministrationDoseConfirmationReceipt.create(
      operationId: currentReceipt.operationId,
      ownerScope: 'account_a',
      intakeId: currentReceipt.intakeId,
      expectedRecordRevisionDigest: currentReceipt.expectedRecordRevisionDigest,
      recordBindingDigest: currentReceipt.recordBindingDigest,
      medicationId: currentReceipt.medicationId,
      productSnapshotDigest: currentReceipt.productSnapshotDigest,
      rawExpression: currentReceipt.rawExpression,
      parsedExpression: parsedExpression,
      grammarId: currentReceipt.grammarId,
      grammarVersion: 3,
      grammarDigest: legacyGrammarDigest,
      unitSystem: currentReceipt.unitSystem,
      unitSystemVersion: currentReceipt.unitSystemVersion,
      structuredValue: currentReceipt.structuredValue,
      structuredUnit: currentReceipt.structuredUnit,
      administrationAt: currentReceipt.administrationAtUtc,
      confirmedAt: currentReceipt.confirmedAtUtc,
      assertionSource: currentReceipt.assertionSource,
      confirmationAction: currentReceipt.confirmationAction,
      uiContractVersion: currentReceipt.uiContractVersion,
    );
    final legacyJson = Map<String, dynamic>.from(confirmed.toJson())
      ..['doseConfirmation'] = legacyReceipt.toJson();
    final restored = Intake.fromJson(legacyJson);

    expect(
      restored.doseConfirmationIntegrity,
      IntakeDoseConfirmationIntegrity.valid,
    );
    expect(
      coordinator.evaluate(restored, ownerScope: 'account_a').status,
      AdministrationDoseEvaluationStatus.grammarDrift,
    );
  });

  test(
    'result-use gate requires confirmation and a conflict-free assertion graph',
    () {
      final confirmed = confirm(draft(selectedProduct: product)).intake!;
      final observedAt = DateTime.utc(2026, 8, 27, 13);
      final eligible = coordinator.evaluateForResultUse(
        confirmed,
        ownerScope: 'account_a',
        observedAt: observedAt,
      );
      expect(eligible.eligible, isTrue);
      expect(eligible.value, 100);
      expect(eligible.unit, 'mg');
      expect(eligible.milligrams, 100);
      expect(eligible.reasonCodes, isEmpty);

      final unconfirmed = coordinator.evaluateForResultUse(
        draft(selectedProduct: product),
        ownerScope: 'account_a',
        observedAt: observedAt,
      );
      expect(unconfirmed.eligible, isFalse);
      expect(unconfirmed.value, isNull);
      expect(unconfirmed.unit, isNull);
      expect(unconfirmed.milligrams, isNull);
      expect(
        unconfirmed.reasonCodes,
        containsAll(<String>[
          'dose_confirmation.absent',
          'assertion_graph.local_receipt_absent',
          'assertion_graph.local_confirmation_not_unique',
        ]),
      );

      final conflictingAssertion = MedicationAssertionNode.create(
        ownerScope: 'account_a',
        intakeId: confirmed.id,
        medicationId: confirmed.drugId,
        productIdentityDigest:
            confirmed.medicationAssertions.single.productIdentityDigest,
        doseValue: 50,
        doseUnit: 'mg',
        route: confirmed.route,
        dosageForm: confirmed.dosageForm,
        releaseType: confirmed.releaseType,
        evidenceClass: MedicationAssertionEvidenceClass.importedStatement,
        sourceArtifactId: 'synthetic_external_assertion',
        sourceArtifactDigest: medicationAssertionSnapshotDigest(
          'synthetic_external_assertion',
        ),
        sourceRevisionDigest: medicationAssertionSnapshotDigest(
          'synthetic_external_revision',
        ),
        actorIdentity: 'synthetic_importer',
        actorRole: MedicationAssertionActorRole.importer,
        effectiveStart: confirmed.takenAt,
        effectiveEnd: confirmed.takenAt,
        timePrecision: MedicationAssertionTimePrecision.exact,
        timeUncertaintyMinutes: 0,
        timezoneOffsetMinutes: 0,
        timezoneSource: MedicationAssertionTimezoneSource.sourceDeclared,
        assertedAt: confirmed.takenAt.add(const Duration(minutes: 2)),
        importedAt: confirmed.takenAt.add(const Duration(minutes: 3)),
        recordedAt: confirmed.takenAt.add(const Duration(minutes: 4)),
        status: MedicationAssertionStatus.taken,
      );
      final conflicted = coordinator.evaluateForResultUse(
        confirmed.copyWith(
          medicationAssertions: <MedicationAssertionNode>[
            ...confirmed.medicationAssertions,
            conflictingAssertion,
          ],
        ),
        ownerScope: 'account_a',
        observedAt: observedAt,
      );
      expect(conflicted.eligible, isFalse);
      expect(conflicted.value, isNull);
      expect(conflicted.unit, isNull);
      expect(conflicted.milligrams, isNull);
      expect(
        conflicted.reasonCodes,
        contains('assertion_graph.unresolved_conflict'),
      );
    },
  );

  test('result-use mass conversion is typed and volume is not mass', () {
    final observedAt = DateTime.utc(2026, 8, 27, 13);
    final grams = coordinator.evaluateForResultUse(
      confirm(draft(note: '0.5 g')).intake!,
      ownerScope: 'account_a',
      observedAt: observedAt,
    );
    expect(grams.eligible, isTrue);
    expect(grams.value, 0.5);
    expect(grams.unit, 'g');
    expect(grams.milligrams, 500);

    final volume = coordinator.evaluateForResultUse(
      confirm(draft(note: '5 mL')).intake!,
      ownerScope: 'account_a',
      observedAt: observedAt,
    );
    expect(volume.eligible, isTrue);
    expect(volume.value, 5);
    expect(volume.unit, 'mL');
    expect(volume.milligrams, isNull);
    expect(volume.reasonCodes, isEmpty);
  });

  test('historical result use cannot consume confirmation from the future', () {
    final administrationAt = DateTime.utc(2026, 8, 27, 8);
    final prepared = coordinator.prepare(
      draft: draft(note: '100 mg', takenAt: administrationAt),
      current: null,
      expectedRecordRevisionDigest:
          administrationDoseConfirmationAbsentRevisionDigest,
      ownerScope: 'account_a',
      operationId: 'future_confirmation_fixture',
      confirmationRequested: true,
      assertionSource: AdministrationDoseAssertionSource.typed,
      confirmationAction: 'test.explicit_confirmation',
      uiContractVersion: 'test-dose-confirmation:1',
      confirmedAt: DateTime.utc(2026, 8, 27, 10),
    );
    final historical = coordinator.evaluateForResultUse(
      prepared.intake!,
      ownerScope: 'account_a',
      observedAt: DateTime.utc(2026, 8, 27, 9),
    );

    expect(historical.eligible, isFalse);
    expect(historical.value, isNull);
    expect(historical.milligrams, isNull);
    expect(
      historical.reasonCodes,
      containsAll(<String>[
        'dose_confirmation.confirmed_after_observation',
        'assertion_graph.evidence_after_observation',
      ]),
    );
  });

  test('stale revision and held expression cannot publish a receipt', () {
    final current = draft();
    final stale = confirm(
      current.copyWith(dosageNote: '50 mg'),
      current: current,
      expectedRevision: administrationDoseConfirmationAbsentRevisionDigest,
    );
    expect(stale.status, AdministrationDosePreparationStatus.staleRevision);
    expect(stale.intake, isNull);

    final held = confirm(draft(note: '100 mg then 50 mg'));
    expect(held.status, AdministrationDosePreparationStatus.heldExpression);
    expect(held.intake, isNull);
    expect(held.reasonCode, 'dose.multiple_numeric_tokens');
  });

  test(
    'saving without confirmation preserves note but clears numeric dose',
    () {
      final prepared = coordinator.prepare(
        draft: Intake(
          id: 'intake_a',
          drugId: 'levodopa',
          takenAt: DateTime.utc(2026, 8, 27, 12),
          dosageNote: '100 mg',
          doseAmount: 100,
          doseUnit: 'mg',
        ),
        current: null,
        expectedRecordRevisionDigest:
            administrationDoseConfirmationAbsentRevisionDigest,
        ownerScope: 'account_a',
        operationId: 'event_op_unconfirmed',
        confirmationRequested: false,
        assertionSource: AdministrationDoseAssertionSource.typed,
        confirmationAction: 'timeline.explicit_checkbox',
        uiContractVersion: 'timeline-dose-confirmation:1',
        confirmedAt: DateTime.utc(2026, 8, 27, 12, 1),
      );
      expect(prepared.status, AdministrationDosePreparationStatus.unconfirmed);
      expect(prepared.intake!.dosageNote, '100 mg');
      expect(prepared.intake!.doseAmount, isNull);
      expect(prepared.intake!.doseUnit, isNull);
      expect(prepared.intake!.doseConfirmation, isNull);
    },
  );

  test('every identity-bearing drift fails closed', () {
    final confirmed = confirm(draft(selectedProduct: product)).intake!;
    final receipt = confirmed.doseConfirmation!;

    expect(
      coordinator.evaluate(confirmed, ownerScope: 'account_b').status,
      AdministrationDoseEvaluationStatus.ownerMismatch,
    );
    expect(
      coordinator
          .evaluate(
            confirmed.copyWith(dosageNote: '50 mg'),
            ownerScope: 'account_a',
          )
          .status,
      AdministrationDoseEvaluationStatus.rawExpressionMismatch,
    );
    expect(
      coordinator
          .evaluate(
            confirmed.copyWith(takenAt: DateTime.utc(2026, 8, 27, 13)),
            ownerScope: 'account_a',
          )
          .status,
      AdministrationDoseEvaluationStatus.administrationTimeMismatch,
    );
    expect(
      coordinator
          .evaluate(
            confirmed.copyWith(
              productSelection: MedicationProductSelection(
                packId: 'pack_b',
                identifierSystem: 'din',
                identifierValue: '87654321',
                displayName: 'Different pack',
                labelerName: null,
                strengthDisplay: 'levodopa 100 mg',
                packageDescription: 'different fixture',
              ),
            ),
            ownerScope: 'account_a',
          )
          .status,
      AdministrationDoseEvaluationStatus.productMismatch,
    );
    final structuredDrift = Intake(
      id: confirmed.id,
      drugId: confirmed.drugId,
      takenAt: confirmed.takenAt,
      dosageNote: confirmed.dosageNote,
      doseAmount: 50,
      doseUnit: 'mg',
      productSelection: confirmed.productSelection,
      doseConfirmation: receipt,
    );
    expect(
      coordinator.evaluate(structuredDrift, ownerScope: 'account_a').status,
      AdministrationDoseEvaluationStatus.structuredDoseMismatch,
    );
  });

  test('receipt binds the medication strength derivation and source chain', () {
    const derivation = MedicationPackageDoseDerivation(
      ingredientName: 'LEVODOPA',
      sourceRawStrength: '100 mg/1',
      numeratorValue: 100,
      numeratorUnit: 'mg',
      denominatorValue: 1,
      denominatorUnit: null,
      denominatorDisposition: 'source_numeric_one',
      packageUnitQuantity: 0.5,
      packageUnitLabel: 'TABLET',
      resultValue: 50,
      resultUnit: 'mg',
    );
    final tracedSelection = MedicationProductSelection(
      packId: 'openfda_ndc_72865_362_01',
      identifierSystem: 'ndcPackage',
      identifierValue: '72865-362-01',
      displayName: 'Synthetic pack',
      labelerName: 'Synthetic labeler',
      strengthDisplay: 'LEVODOPA 100 mg',
      packageDescription: 'fixture only',
      doseBasisIngredient: 'LEVODOPA',
      unitQuantity: 0.5,
      unitLabel: 'TABLET',
      sourceSystem: 'OPENFDA_NDC',
      sourceUrl: 'https://api.fda.gov/drug/ndc.json',
      sourceRetrievedAtUtc: '2026-08-17T00:00:00.000Z',
      doseDerivation: derivation,
    );
    final confirmed = confirm(
      draft(note: '50 mg', selectedProduct: tracedSelection),
    ).intake!;
    expect(
      coordinator.evaluate(confirmed, ownerScope: 'account_a').confirmed,
      isTrue,
    );
    final restored = Intake.fromJson(confirmed.toJson());
    expect(restored.toJson(), confirmed.toJson());
    expect(
      coordinator.evaluate(restored, ownerScope: 'account_a').confirmed,
      isTrue,
    );

    final changedProductJson = tracedSelection.toJson()
      ..['sourceUrl'] = 'https://example.invalid/changed';
    final changedSelection = MedicationProductSelection.fromJson(
      changedProductJson,
    )!;
    final changed = confirmed.copyWith(productSelection: changedSelection);
    expect(
      coordinator.evaluate(changed, ownerScope: 'account_a').status,
      AdministrationDoseEvaluationStatus.productMismatch,
    );

    final malformedJson = Map<String, dynamic>.from(confirmed.toJson());
    final malformedSelection = Map<String, dynamic>.from(
      malformedJson['productSelection'] as Map,
    );
    final malformedDerivation = Map<String, dynamic>.from(
      malformedSelection['doseDerivation'] as Map,
    )..['formula_version'] = 2;
    malformedSelection['doseDerivation'] = malformedDerivation;
    malformedJson['productSelection'] = malformedSelection;
    final malformed = Intake.fromJson(malformedJson);
    expect(
      coordinator.evaluate(malformed, ownerScope: 'account_a').status,
      AdministrationDoseEvaluationStatus.productMismatch,
    );
  });

  test('malformed receipt evidence is retained but never trusted', () {
    final confirmed = confirm(draft()).intake!;
    final json = Map<String, dynamic>.from(confirmed.toJson());
    final receipt = Map<String, dynamic>.from(json['doseConfirmation'] as Map)
      ..['receipt_digest'] = List<String>.filled(64, '0').join();
    json['doseConfirmation'] = receipt;
    final restored = Intake.fromJson(json);
    expect(
      restored.doseConfirmationIntegrity,
      IntakeDoseConfirmationIntegrity.invalid,
    );
    expect(restored.invalidDoseConfirmationEvidence, isNotNull);
    expect(restored.toJson()['doseConfirmation'], receipt);
    expect(
      coordinator.evaluate(restored, ownerScope: 'account_a').status,
      AdministrationDoseEvaluationStatus.invalidEvidence,
    );
  });

  test('a changed unit conversion invalidates the confirmation receipt', () {
    final confirmed = confirm(draft(note: '0.5 g')).intake!;
    final intakeJson = Map<String, dynamic>.from(confirmed.toJson());
    final receiptEnvelope = Map<String, dynamic>.from(
      intakeJson['doseConfirmation'] as Map,
    );
    final parsedExpression = Map<String, dynamic>.from(
      receiptEnvelope['parsed_expression'] as Map,
    );
    final unit = Map<String, dynamic>.from(parsedExpression['unit'] as Map);
    final mapping = Map<String, dynamic>.from(unit['mappingEvidence'] as Map)
      ..['conversionNumerator'] = 1;
    unit['mappingEvidence'] = mapping;
    parsedExpression['unit'] = unit;
    receiptEnvelope['parsed_expression'] = parsedExpression;
    intakeJson['doseConfirmation'] = receiptEnvelope;

    final restored = Intake.fromJson(intakeJson);
    expect(
      restored.doseConfirmationIntegrity,
      IntakeDoseConfirmationIntegrity.invalid,
    );
    expect(
      coordinator.evaluate(restored, ownerScope: 'account_a').status,
      AdministrationDoseEvaluationStatus.invalidEvidence,
    );
  });

  test(
    'AppState atomically binds receipt to history and rejects stale edit',
    () async {
      final services = Services.createEphemeral();
      await services.ready;
      final state = AppState(services: services);
      addTearDown(state.dispose);
      await state.bootstrap();
      final original = draft();
      final created = await state.saveIntakeWithDoseConfirmation(
        draft: original,
        isUpdate: false,
        expectedRecordRevisionDigest:
            administrationDoseConfirmationAbsentRevisionDigest,
        confirmationRequested: true,
        assertionSource: AdministrationDoseAssertionSource.typed,
        confirmationAction: 'timeline.explicit_checkbox',
        uiContractVersion: 'timeline-dose-confirmation:1',
      );
      expect(created.mutation?.wasCommitted, isTrue);
      final persisted = state.intakes.single;
      final revision = state.latestRecoverableRevisionFor(
        eventType: RecoverableUserEventType.intake,
        recordId: persisted.id,
      )!;
      expect(persisted.doseConfirmation?.operationId, revision.operationId);
      expect(state.evaluateDoseConfirmation(persisted).confirmed, isTrue);

      final openedRevision = state.doseConfirmationRevisionDigest(persisted);
      await state.updateIntake(persisted.copyWith(dosageNote: '75 mg'));
      final stale = await state.saveIntakeWithDoseConfirmation(
        draft: persisted.copyWith(dosageNote: '50 mg'),
        isUpdate: true,
        expectedRecordRevisionDigest: openedRevision,
        confirmationRequested: true,
        assertionSource: AdministrationDoseAssertionSource.typed,
        confirmationAction: 'timeline.explicit_checkbox',
        uiContractVersion: 'timeline-dose-confirmation:1',
      );
      expect(
        stale.preparation.status,
        AdministrationDosePreparationStatus.staleRevision,
      );
      expect(stale.mutation, isNull);
      expect(state.intakes.single.dosageNote, '75 mg');
    },
  );

  test('undo restores the exact prior confirmed receipt', () async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = AppState(services: services);
    addTearDown(state.dispose);
    await state.bootstrap();

    final created = await state.saveIntakeWithDoseConfirmation(
      draft: draft(),
      isUpdate: false,
      expectedRecordRevisionDigest:
          administrationDoseConfirmationAbsentRevisionDigest,
      confirmationRequested: true,
      assertionSource: AdministrationDoseAssertionSource.typed,
      confirmationAction: 'timeline.explicit_checkbox',
      uiContractVersion: 'timeline-dose-confirmation:1',
    );
    expect(created.mutation?.wasCommitted, isTrue);
    final original = state.intakes.single;
    final originalReceiptDigest = original.doseConfirmation!.receiptDigest;

    final updated = await state.saveIntakeWithDoseConfirmation(
      draft: original.copyWith(dosageNote: '50 mg'),
      isUpdate: true,
      expectedRecordRevisionDigest: state.doseConfirmationRevisionDigest(
        original,
      ),
      confirmationRequested: true,
      assertionSource: AdministrationDoseAssertionSource.typed,
      confirmationAction: 'timeline.explicit_checkbox',
      uiContractVersion: 'timeline-dose-confirmation:1',
    );
    expect(updated.mutation?.wasCommitted, isTrue);
    expect(state.intakes.single.doseAmount, 50);
    expect(
      state.intakes.single.doseConfirmation!.receiptDigest,
      isNot(originalReceiptDigest),
    );
    final updateRevision = state.latestRecoverableRevisionFor(
      eventType: RecoverableUserEventType.intake,
      recordId: original.id,
    )!;
    expect(
      updateRevision.mutationType,
      RecoverableUserEventMutationType.update,
    );

    expect(
      await state.restoreRecoverableEvent(updateRevision.historyId),
      isTrue,
    );
    final restored = state.intakes.single;
    expect(restored.dosageNote, '100 mg');
    expect(restored.doseAmount, 100);
    expect(restored.doseUnit, 'mg');
    expect(restored.doseConfirmation!.receiptDigest, originalReceiptDigest);
    expect(state.evaluateDoseConfirmation(restored).confirmed, isTrue);
    final restoreRevision = state.latestRecoverableRevisionFor(
      eventType: RecoverableUserEventType.intake,
      recordId: original.id,
    )!;
    expect(
      restoreRevision.mutationType,
      RecoverableUserEventMutationType.restore,
    );
    expect(restoreRevision.restoresHistoryId, updateRevision.historyId);
  });
}
