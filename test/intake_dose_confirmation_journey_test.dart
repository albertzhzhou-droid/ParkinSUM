import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';

void main() {
  Future<AppState> state() async {
    final services = Services.createEphemeral();
    await services.ready;
    final value = AppState(services: services);
    await value.bootstrap();
    return value;
  }

  Future<void> pumpEditor(
    WidgetTester tester,
    AppState state, {
    Intake? initial,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(home: IntakeEditorPage(initialIntake: initial)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Intake asGrammarV3(AppState state, Intake intake) {
    const legacyGrammarDigest =
        '9cdda65781594df1239522c274a84f0e318560e94c3cd8f75d8f5aec265d5dca';
    final currentReceipt = intake.doseConfirmation!;
    final parsedExpression = Map<String, Object?>.from(
      currentReceipt.parsedExpression,
    );
    final unit = Map<String, Object?>.from(parsedExpression['unit'] as Map);
    final mapping = Map<String, Object?>.from(unit['mappingEvidence'] as Map)
      ..['sourceRevision'] = legacyGrammarDigest;
    unit['mappingEvidence'] = mapping;
    parsedExpression['unit'] = unit;
    final legacyReceipt = AdministrationDoseConfirmationReceipt.create(
      operationId: currentReceipt.operationId,
      ownerScope: state.currentUserId ?? state.userProfile.patientId,
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
    final json = Map<String, dynamic>.from(intake.toJson())
      ..['doseConfirmation'] = legacyReceipt.toJson();
    return Intake.fromJson(json);
  }

  testWidgets('user explicitly confirms and atomically saves a dose receipt', (
    tester,
  ) async {
    final appState = await state();
    addTearDown(appState.dispose);
    addTearDown(tester.view.reset);
    await pumpEditor(tester, appState);

    await tester.enterText(
      find.byKey(const ValueKey<String>('intake-dose-note')),
      '100 mg',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('dose-confirmation-checkbox')),
    );
    await tester.tap(find.byKey(const Key('dose-confirmation-checkbox')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('intake-save')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('intake-save')));
    await tester.pumpAndSettle();

    expect(appState.intakes, hasLength(1));
    final intake = appState.intakes.single;
    expect(intake.doseConfirmation, isNotNull);
    expect(appState.evaluateDoseConfirmation(intake).confirmed, isTrue);
    expect(intake.doseAmount, 100);
    expect(intake.doseUnit, 'mg');
  });

  testWidgets(
    'grammar-drift receipt is not preselected and needs fresh confirmation',
    (tester) async {
      final appState = await state();
      addTearDown(appState.dispose);
      addTearDown(tester.view.reset);
      final original = Intake(
        id: 'intake_legacy_grammar_receipt',
        drugId: appState.medRepo.allDrugs.first.id,
        takenAt: DateTime.utc(2026, 8, 27, 12),
        dosageNote: '100 mg',
      );
      await appState.saveIntakeWithDoseConfirmation(
        draft: original,
        isUpdate: false,
        expectedRecordRevisionDigest:
            administrationDoseConfirmationAbsentRevisionDigest,
        confirmationRequested: true,
        assertionSource: AdministrationDoseAssertionSource.typed,
        confirmationAction: 'test.explicit_confirmation',
        uiContractVersion: 'timeline-dose-preview-test:1',
      );
      final legacy = asGrammarV3(appState, appState.intakes.single);
      await appState.updateIntake(legacy);
      expect(
        appState.evaluateDoseConfirmation(appState.intakes.single).reasonCode,
        'dose_confirmation.grammar_drift',
      );

      await pumpEditor(tester, appState, initial: appState.intakes.single);
      final checkboxFinder = find.byKey(
        const Key('dose-confirmation-checkbox'),
      );
      expect(tester.widget<CheckboxListTile>(checkboxFinder).value, isFalse);
      expect(
        find.byKey(const Key('dose-confirmation-current-status')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('intake-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('intake-save')));
      await tester.pumpAndSettle();
      expect(appState.intakes.single.doseConfirmation, isNull);
      expect(appState.intakes.single.doseAmount, isNull);
      expect(
        appState.evaluateDoseConfirmation(appState.intakes.single).confirmed,
        isFalse,
      );
    },
  );

  testWidgets('timeline shows only the current confirmed dose preview', (
    tester,
  ) async {
    final appState = await state();
    addTearDown(appState.dispose);
    addTearDown(tester.view.reset);
    final intake = Intake(
      id: 'intake_fhir_r5_preview',
      drugId: appState.medRepo.allDrugs.first.id,
      takenAt: DateTime.utc(2026, 8, 27, 12),
      dosageNote: '100 mg',
    );
    await appState.saveIntakeWithDoseConfirmation(
      draft: intake,
      isUpdate: false,
      expectedRecordRevisionDigest:
          administrationDoseConfirmationAbsentRevisionDigest,
      confirmationRequested: true,
      assertionSource: AdministrationDoseAssertionSource.typed,
      confirmationAction: 'test.explicit_confirmation',
      uiContractVersion: 'timeline-dose-preview-test:1',
    );

    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(home: TimelinePage()),
      ),
    );
    await tester.pumpAndSettle();
    final previewButton = find.byKey(
      const ValueKey<String>('fhir-r5-dose-preview-intake_fhir_r5_preview'),
    );
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    final dialog = find.byKey(
      const ValueKey<String>('fhir-r5-dose-preview-dialog'),
    );
    expect(dialog, findsOneWidget);
    expect(find.text('FHIR R5 dose preview'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('fhir-r5-dose-preview-projected')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('fhir-r5-dose-preview-quantity')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('fhir-r5-dose-preview-quantity')),
        matching: find.textContaining('100'),
      ),
      findsOneWidget,
    );
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Send'), findsNothing);
    expect(tester.takeException(), isNull);

    await appState.updateIntake(
      appState.intakes.single.copyWith(dosageNote: '75 mg'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Medication record changed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('fhir-r5-dose-preview-quantity')),
      findsNothing,
    );
  });

  testWidgets('timeline holds the FHIR R5 preview for an unconfirmed note', (
    tester,
  ) async {
    final appState = await state();
    addTearDown(appState.dispose);
    addTearDown(tester.view.reset);
    final intake = Intake(
      id: 'intake_fhir_r5_unconfirmed_preview',
      drugId: appState.medRepo.allDrugs.first.id,
      takenAt: DateTime.utc(2026, 8, 27, 12),
      dosageNote: '100 mg',
    );
    await appState.saveIntakeWithDoseConfirmation(
      draft: intake,
      isUpdate: false,
      expectedRecordRevisionDigest:
          administrationDoseConfirmationAbsentRevisionDigest,
      confirmationRequested: false,
      assertionSource: AdministrationDoseAssertionSource.typed,
      confirmationAction: 'test.no_confirmation',
      uiContractVersion: 'timeline-dose-preview-test:1',
    );

    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(home: TimelinePage()),
      ),
    );
    await tester.pumpAndSettle();
    final previewButton = find.byKey(
      const ValueKey<String>(
        'fhir-r5-dose-preview-intake_fhir_r5_unconfirmed_preview',
      ),
    );
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    final dialog = find.byKey(
      const ValueKey<String>('fhir-r5-dose-preview-dialog'),
    );
    expect(dialog, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('fhir-r5-dose-preview-held')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('fhir-r5-dose-preview-quantity')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('100')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows derivation and clears it when the dose note is edited', (
    tester,
  ) async {
    final appState = await state();
    addTearDown(appState.dispose);
    addTearDown(tester.view.reset);
    const selection = MedicationProductSelection(
      packId: 'fixture_pack',
      identifierSystem: 'ndcPackage',
      identifierValue: '12345-678-90',
      displayName: 'Synthetic tablet',
      labelerName: 'Fixture labeler',
      strengthDisplay: 'LEVODOPA 100 mg',
      packageDescription: 'Fixture only',
      doseBasisIngredient: 'LEVODOPA',
      unitQuantity: 0.5,
      unitLabel: 'TABLET',
      sourceSystem: 'FIXTURE_SOURCE',
      sourceUrl: 'https://example.invalid/fixture',
      sourceRetrievedAtUtc: '2026-08-17T00:00:00.000Z',
      doseDerivation: MedicationPackageDoseDerivation(
        ingredientName: 'LEVODOPA',
        sourceRawStrength: '100 mg',
        numeratorValue: 100,
        numeratorUnit: 'mg',
        denominatorValue: null,
        denominatorUnit: null,
        denominatorDisposition: 'assumed_one_discrete_dosage_unit',
        packageUnitQuantity: 0.5,
        packageUnitLabel: 'TABLET',
        resultValue: 50,
        resultUnit: 'mg',
      ),
    );
    final intake = Intake(
      id: 'intake_derivation_preview',
      drugId: appState.medRepo.allDrugs.first.id,
      takenAt: DateTime.utc(2026, 8, 27, 12),
      dosageNote: '50 mg',
      productSelection: selection,
    );
    await pumpEditor(tester, appState, initial: intake);

    expect(
      find.textContaining('Calculation: 100 mg × 0.5 TABLET = 50 mg'),
      findsOneWidget,
    );
    expect(find.textContaining('did not report a denominator'), findsOneWidget);
    expect(find.textContaining('FIXTURE_SOURCE'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('intake-dose-note')),
      '60 mg',
    );
    await tester.pump();

    expect(
      find.textContaining('Calculation: 100 mg × 0.5 TABLET = 50 mg'),
      findsNothing,
    );
    expect(find.textContaining('did not report a denominator'), findsNothing);
  });

  testWidgets('concurrent edit invalidates an open dose confirmation preview', (
    tester,
  ) async {
    final appState = await state();
    addTearDown(appState.dispose);
    addTearDown(tester.view.reset);
    final drug = appState.medRepo.allDrugs.first;
    final originalDraft = Intake(
      id: 'intake_concurrent_receipt',
      drugId: drug.id,
      takenAt: DateTime.utc(2026, 8, 27, 12),
      dosageNote: '100 mg',
    );
    await appState.saveIntakeWithDoseConfirmation(
      draft: originalDraft,
      isUpdate: false,
      expectedRecordRevisionDigest:
          administrationDoseConfirmationAbsentRevisionDigest,
      confirmationRequested: true,
      assertionSource: AdministrationDoseAssertionSource.typed,
      confirmationAction: 'test.explicit_confirmation',
      uiContractVersion: 'test-dose-confirmation:1',
    );
    final opened = appState.intakes.single;
    await pumpEditor(tester, appState, initial: opened);

    await appState.updateIntake(opened.copyWith(dosageNote: '75 mg'));
    await tester.enterText(
      find.byKey(const ValueKey<String>('intake-dose-note')),
      '50 mg',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('dose-confirmation-checkbox')),
    );
    await tester.tap(find.byKey(const Key('dose-confirmation-checkbox')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('intake-save')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('intake-save')));
    await tester.pumpAndSettle();

    expect(appState.intakes.single.dosageNote, '75 mg');
    expect(find.textContaining('current record changed'), findsOneWidget);
  });
}
