import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/timeline/medication_assertion_reconciliation_page.dart';
import 'package:provider/provider.dart';

void main() {
  Future<AppState> seededState() async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = AppState(services: services);
    await state.bootstrap();
    final draft = Intake(
      id: 'intake_assertion_ui',
      drugId: state.medRepo.allDrugs.first.id,
      takenAt: DateTime.now().subtract(const Duration(hours: 1)),
      dosageNote: '100 mg',
      route: 'oral',
      dosageForm: 'tablet',
      releaseType: 'immediate',
    );
    await state.saveIntakeWithDoseConfirmation(
      draft: draft,
      isUpdate: false,
      expectedRecordRevisionDigest:
          administrationDoseConfirmationAbsentRevisionDigest,
      confirmationRequested: true,
      assertionSource: AdministrationDoseAssertionSource.typed,
      confirmationAction: 'test.explicit_confirmation',
      uiContractVersion: 'test-reconciliation-ui:1',
    );
    return state;
  }

  Future<void> pumpPage(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: MedicationAssertionReconciliationPage(
            intakeId: 'intake_assertion_ui',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders source graph, appends a conflicting source, and keeps acknowledgement fail-closed',
    (tester) async {
      final state = await seededState();
      addTearDown(state.dispose);
      addTearDown(tester.view.reset);
      await pumpPage(tester, state);

      expect(
        find.text('Dose is eligible for algorithm result use'),
        findsOneWidget,
      );
      expect(
        find.text('Assertion subgate: no unresolved conflict'),
        findsOneWidget,
      );
      expect(find.text('Local user confirmation'), findsOneWidget);
      expect(
        tester
            .widgetList<Semantics>(find.byType(Semantics))
            .any(
              (widget) =>
                  widget.properties.label ==
                  'Dose is eligible for algorithm result use',
            ),
        isTrue,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('add-medication-assertion')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('add-medication-assertion')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'initial graph layout');
      await tester.enterText(
        find.byKey(const ValueKey<String>('assertion-source-label')),
        'Imported portal statement',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('assertion-dose')),
        '50 mg',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('save-medication-assertion')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'conflict graph layout');

      expect(find.text('Dose is held from algorithms'), findsOneWidget);
      expect(
        find.text('Assertion subgate: unresolved blocker'),
        findsOneWidget,
      );
      expect(find.text('Dose conflict'), findsOneWidget);
      expect(state.intakes.single.medicationAssertions, hasLength(2));
      expect(
        state.intakes.single.medicationAssertions.last.sourceDisplayLabel,
        'Imported portal statement',
      );
      expect(
        find.text('Source name: Imported portal statement'),
        findsOneWidget,
      );
      expect(find.textContaining('Imported portal statement'), findsWidgets);
      expect(
        state
            .medicationAssertionGraphFor(state.intakes.single)
            .resultAffectingDoseEligible,
        isFalse,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('known-at-current-time')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('known-at-current-time')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('run-bitemporal-projection')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('bitemporal-historical-graph-summary'),
        ),
        findsOneWidget,
      );
      expect(find.text('Dose conflict'), findsNWidgets(2));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('acknowledge-assertion-graph')),
        240,
        scrollable: find.descendant(
          of: find.byKey(
            const ValueKey<String>('medication-reconciliation-list'),
          ),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('acknowledge-assertion-graph')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'decision graph layout');

      final acknowledged = state.medicationAssertionGraphFor(
        state.intakes.single,
      );
      expect(acknowledged.currentDecision, isNotNull);
      expect(acknowledged.resultAffectingDoseEligible, isFalse);
      await tester.drag(
        find.byKey(const ValueKey<String>('medication-reconciliation-list')),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dose is held from algorithms'), findsOneWidget);
      expect(
        find.text('This graph revision has a review decision.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'stale receipt holds result use when the assertion subgate is conflict-free',
    (tester) async {
      final state = await seededState();
      addTearDown(state.dispose);
      addTearDown(tester.view.reset);

      final confirmed = state.intakes.single;
      await state.updateIntake(confirmed.copyWith(dosageNote: '200 mg'));
      final stale = state.intakes.single;
      final graph = state.medicationAssertionGraphFor(stale);
      final resultUse = state.evaluateDoseForResultUse(stale);

      expect(graph.resultAffectingDoseEligible, isTrue);
      expect(resultUse.assertionGraph.resultAffectingDoseEligible, isTrue);
      expect(resultUse.eligible, isFalse);
      expect(
        resultUse.reasonCodes,
        contains('dose_confirmation.raw_expression_mismatch'),
      );

      await pumpPage(tester, state);

      final combinedStatus = find.byKey(
        const ValueKey<String>('dose-combined-result-gate-status'),
      );
      final assertionSubgate = find.byKey(
        const ValueKey<String>('assertion-subgate-status'),
      );
      final resultReasons = find.byKey(
        const ValueKey<String>('dose-result-gate-reasons'),
      );
      expect(combinedStatus, findsOneWidget);
      expect(
        tester.widget<Text>(combinedStatus).data,
        'Dose is held from algorithms',
      );
      expect(assertionSubgate, findsOneWidget);
      expect(
        find.descendant(
          of: assertionSubgate,
          matching: find.text('Assertion subgate: no unresolved conflict'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Local confirmation chain has no unresolved conflict'),
        findsNothing,
      );
      expect(
        tester.widget<Text>(resultReasons).data,
        contains('dose_confirmation.raw_expression_mismatch'),
      );
    },
  );

  testWidgets(
    'historical evidence query separates event and knowledge time without changing dose eligibility',
    (tester) async {
      final state = await seededState();
      addTearDown(state.dispose);
      addTearDown(tester.view.reset);
      await pumpPage(tester, state);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('select-known-at-cutoff')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('select-known-at-cutoff')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final datePickerContext = tester.element(find.byType(DatePickerDialog));
      final okLabel = MaterialLocalizations.of(datePickerContext).okButtonLabel;
      await tester.tap(find.text(okLabel));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('known-at-event-time')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('run-bitemporal-projection')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('bitemporal-projection-panel')),
        findsOneWidget,
      );
      expect(find.text('After knowledge cutoff'), findsOneWidget);
      expect(
        find.text('Source details are hidden at this cutoff.'),
        findsOneWidget,
      );
      expect(
        find.text('Dose is eligible for algorithm result use'),
        findsOneWidget,
      );
      expect(state.intakes.single.medicationAssertions, hasLength(1));
      expect(
        state.evaluateDoseForResultUse(state.intakes.single).eligible,
        isTrue,
      );
    },
  );

  testWidgets(
    'historical view discloses aggregate integrity timing as unresolved',
    (tester) async {
      final state = await seededState();
      addTearDown(state.dispose);
      addTearDown(tester.view.reset);

      final raw = Map<String, dynamic>.from(state.intakes.single.toJson());
      raw['medicationReconciliation'] = <String, Object?>{
        'schema': 'parkinsum.medication-reconciliation-envelope/999',
        'schemaVersion': 999,
        'assertions': <Object?>[],
        'decisions': <Object?>[],
        'meaningBoundary': 'unsupported evidence',
      };
      await state.updateIntake(Intake.fromJson(raw));
      expect(
        state
            .medicationAssertionGraphFor(state.intakes.single)
            .resultAffectingDoseEligible,
        isFalse,
      );

      await pumpPage(tester, state);
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('run-bitemporal-projection')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('run-bitemporal-projection')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('bitemporal-aggregate-integrity-time-unknown'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Whether it existed by this cutoff is unknown'),
        findsOneWidget,
      );
      expect(find.text('Dose is held from algorithms'), findsOneWidget);
    },
  );
}
