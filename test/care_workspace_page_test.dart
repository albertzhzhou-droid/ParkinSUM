import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/care_workspace_store.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/i18n/care_workspace_copy.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_entry.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_outcome.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_list_review.dart';
import 'package:parkinsum_companion/domain/entities/decision_support_followup.dart';
import 'package:parkinsum_companion/domain/entities/medication_assertion_reconciliation.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/features/care_workspace/care_workspace_page.dart';
import 'package:parkinsum_companion/features/main_shell/main_shell.dart';
import 'package:parkinsum_companion/features/timeline/medication_assertion_reconciliation_page.dart';
import 'package:provider/provider.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 400, scrollable: scrollable);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(target);
    // The service graph was initialized outside the fake clock; drain its
    // in-memory transaction queue before checking the rendered result.
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

Future<void> _saveMedicationItem(
  WidgetTester tester,
  AppState state, {
  String id = 'fhir-medication-entry',
}) async {
  final saved = await tester.runAsync(
    () => state.saveMedicationDiscussionEntry(
      CareMedicationDiscussionEntry(
        id: id,
        name: 'Synthetic medication item',
        category: CareMedicationDiscussionCategory.supplement,
        reportedUse: CareMedicationReportedUse.reportedCurrent,
        ingredientLabel: 'Private synthetic ingredient label',
        doseAndScheduleText: 'one tablet, timing to verify',
        question: 'Private synthetic question',
        recordedAt: DateTime.utc(2026, 9, 23, 12),
        recorderId: state.currentUserId!,
      ),
    ),
  );
  expect(saved, isTrue);
  await tester.pumpAndSettle();
}

Future<void> _saveMedicationSourceConflict(
  WidgetTester tester,
  AppState state,
) async {
  final eventTime = DateTime.now().toUtc().subtract(const Duration(hours: 1));
  final saved = await tester.runAsync(
    () => state.saveIntakeWithDoseConfirmation(
      draft: Intake(
        id: 'visit-source-review-intake',
        drugId: 'drug_levodopa_carbidopa',
        takenAt: eventTime,
        dosageNote: '100 mg',
        doseAmount: 100,
        doseUnit: 'mg',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate',
      ),
      isUpdate: false,
      expectedRecordRevisionDigest:
          administrationDoseConfirmationAbsentRevisionDigest,
      confirmationRequested: true,
      assertionSource: AdministrationDoseAssertionSource.typed,
      confirmationAction: 'test.explicit_confirmation',
      uiContractVersion: 'visit-source-review:1',
    ),
  );
  expect(saved?.mutation, isNotNull);
  final intake = state.intakes.singleWhere(
    (item) => item.id == 'visit-source-review-intake',
  );
  final graph = state.medicationAssertionGraphFor(intake);
  final appended = await tester.runAsync(
    () => state.appendMedicationAssertion(
      intakeId: intake.id,
      expectedGraphDigest: graph.graphDigest,
      evidenceClass: MedicationAssertionEvidenceClass.importedStatement,
      status: MedicationAssertionStatus.unknown,
      actorRole: MedicationAssertionActorRole.importer,
      sourceLabel: 'Imported care portal',
      sourceRevision: 'revision-1',
      doseValue: 50,
      doseUnit: 'mg',
      effectiveStart: eventTime,
      effectiveEnd: eventTime,
      timePrecision: MedicationAssertionTimePrecision.exact,
      timeUncertaintyMinutes: 0,
      timezoneOffsetMinutes: 0,
      timezoneSource: MedicationAssertionTimezoneSource.sourceDeclared,
    ),
  );
  expect(appended, isNotNull);
  await tester.pumpAndSettle();
}

Future<_Fixture> _pump(
  WidgetTester tester, {
  bool chinese = false,
  String? localeTag,
  bool mainShell = false,
  bool withPrompts = true,
}) async {
  final fixture = await tester.runAsync(() async {
    final store = _ControlledStore();
    final services = Services.createEphemeral(careWorkspaceStore: store);
    await services.ready;
    await services.userDataService.saveOnboarded(true);
    await services.userDataService.saveUserProfile(
      UserProfile.defaults().copyWith(
        displayLocale: localeTag ?? (chinese ? 'zh-CN' : 'en-US'),
      ),
    );
    await services.userDataService.saveActiveDrugIds([
      'drug_levodopa_carbidopa',
    ]);
    final state = AppState(services: services);
    await state.bootstrap();
    if (withPrompts) {
      final meal = Meal(
        id: 'care-test-meal',
        title: 'Synthetic test meal',
        eatenAt: DateTime.utc(2026, 9, 20, 12),
        items: [
          MealItem.fromFood(
            food: state.foodRepo.allFoods.first,
            quantityFactor: 1,
          ),
        ],
      );
      final saved = await state.addMeal(meal);
      expect(saved.wasCommitted, isTrue);
      expect(state.followups(), isNotEmpty);
    }
    return _Fixture(state, store);
  });
  final state = fixture!.state;
  addTearDown(state.dispose);
  await tester.binding.setSurfaceSize(const Size(360, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
        home: mainShell
            ? const MainShell(selectedTabId: 'timeline')
            : const CareWorkspacePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!mainShell) {
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor?.a,
      1,
    );
  }
  return fixture;
}

void main() {
  testWidgets(
    'medication self-check is saved and labelled in the visit report',
    (tester) async {
      final fixture = await _pump(tester, withPrompts: false);
      await _tap(tester, 'care-medication-list-review-currentSelection');
      expect(
        fixture.state.medicationListReviews.single.section,
        CareMedicationListReviewSection.currentSelection,
      );

      await _tap(tester, 'care-prepare-visit');
      expect(find.byType(VisitPreparationPreview), findsOneWidget);
      expect(
        find.textContaining('Medication list self-check (owner-reported)'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Marked reviewed by account holder'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Marked reviewed by account holder'),
        findsWidgets,
      );
      expect(
        find.textContaining('does not prove completeness, accuracy'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner can omit observations from one visit report', (
    tester,
  ) async {
    final fixture = await _pump(tester, withPrompts: false);
    for (final (id, note) in [
      ('visit-include', 'Synthetic included observation note'),
      ('visit-omit', 'Synthetic omitted observation note'),
    ]) {
      final saved = await tester.runAsync(
        () => fixture.state.saveObservation(
          PersonalObservation.create(
            id: id,
            kind: PersonalObservationKind.symptom,
            occurredAt: DateTime.utc(2026, 9, 20, 10),
            recordedAt: DateTime.utc(2026, 9, 20, 11),
            originalTimezone: 'UTC',
            source: PersonalObservationSource.selfReported,
            recorderId: fixture.state.currentUserId!,
            status: PersonalObservationStatus.recorded,
            symptomLabel: 'Synthetic symptom',
            severity: 2,
            notes: note,
          ),
        ),
      );
      expect(saved, isTrue);
    }
    await tester.pumpAndSettle();

    await _tap(tester, 'care-visit-observation-selection');
    await _tap(tester, 'care-visit-observation-visit-omit');
    expect(fixture.state.observations, hasLength(2));
    await _tap(tester, 'care-prepare-visit');

    final report = tester
        .widget<VisitPreparationPreview>(find.byType(VisitPreparationPreview))
        .report;
    expect(report.omittedObservationCount, 1);
    expect(report.plainText, contains('Synthetic included observation note'));
    expect(
      report.plainText,
      isNot(contains('Synthetic omitted observation note')),
    );
    expect(report.plainText, contains('Excluded by this report selection: 1'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('visit preview shell renders in each shipped language family', (
    tester,
  ) async {
    final fixture = await _pump(tester, withPrompts: false);
    final report = fixture.state.prepareVisit();
    final owner = fixture.state.currentUserId!;

    for (final family in AppI18n.translationFamilies) {
      final localeTag = '$family-TEST';
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: fixture.state,
          child: MaterialApp(
            home: VisitPreparationPreview(
              report: report,
              owner: owner,
              localeTag: localeTag,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      final reportLanguage = find.text(
        careWorkspaceVisitCopy('preview.reportLanguage', localeTag: localeTag),
      );
      await tester.ensureVisible(reportLanguage);
      await tester.pumpAndSettle();
      final previewList = find.byType(ListView).first;
      Future<void> reveal(Finder target) async {
        for (
          var attempt = 0;
          attempt < 20 && target.hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(previewList, const Offset(0, -500));
          await tester.pumpAndSettle();
        }
        expect(target.hitTestable(), findsOneWidget, reason: family);
      }

      expect(
        find.text(
          careWorkspaceVisitCopy('preview.title', localeTag: localeTag),
        ),
        findsOneWidget,
        reason: family,
      );
      expect(reportLanguage, findsOneWidget, reason: family);
      expect(
        find.text(
          careWorkspaceVisitCopy('agenda.heading', localeTag: localeTag),
        ),
        findsOneWidget,
        reason: family,
      );
      await reveal(find.byKey(const ValueKey('care-copy-agenda')));
      expect(
        find.text(
          careWorkspaceVisitCopy('action.copyAgenda', localeTag: localeTag),
        ),
        findsOneWidget,
        reason: family,
      );
      await reveal(find.byKey(const ValueKey('care-copy-report')));
      expect(
        find.text(careWorkspaceVisitCopy('action.copy', localeTag: localeTag)),
        findsOneWidget,
        reason: family,
      );
      expect(tester.takeException(), isNull, reason: family);
    }
  });

  testWidgets('follow-up workflow uses the selected native language family', (
    tester,
  ) async {
    final fixture = await _pump(tester, localeTag: 'ko-KR');
    final scrollable = find.byType(Scrollable).first;
    final filter = find.byKey(const ValueKey('care-followup-filter-open'));
    await tester.scrollUntilVisible(filter, 400, scrollable: scrollable);
    expect(find.text('미처리'), findsOneWidget);
    expect(
      find.text('필터는 직접 기록한 작업 상태와 생성 시간을 사용하며 임상적 우선순위나 긴급성을 나타내지 않습니다.'),
      findsOneWidget,
    );

    final promptId = fixture.state.followups().first.prompt.id;
    final prompt = find.byKey(ValueKey('care-prompt-$promptId'));
    await tester.scrollUntilVisible(prompt, 400, scrollable: scrollable);
    expect(find.text('읽지 않음'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opening does not record read; explicit read is found through all prompts',
    (tester) async {
      final fixture = await _pump(tester);
      final prompt = fixture.state.followups().first;
      expect(prompt.status, DecisionSupportFollowupStatus.unread);
      expect(prompt.history, isEmpty);
      final id = prompt.prompt.id;
      await _tap(tester, 'care-feedback-$id-read');
      final read = fixture.item(id);
      expect(read.status, DecisionSupportFollowupStatus.read);
      expect(read.history, hasLength(1));
      expect(find.byKey(ValueKey('care-prompt-$id')), findsNothing);
      await _tap(tester, 'care-followup-filter-needsReview');
      expect(find.byKey(ValueKey('care-prompt-$id')), findsNothing);
      await _tap(tester, 'care-followup-filter-all');
      expect(find.byKey(ValueKey('care-prompt-$id')), findsOneWidget);
      await tester.runAsync(fixture.state.reloadCareWorkspace);
      expect(fixture.item(id).status, DecisionSupportFollowupStatus.read);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'follow-up views filter snoozed prompts without changing status',
    (tester) async {
      final fixture = await _pump(tester);
      final id = fixture.state.followups().first.prompt.id;
      await _tap(tester, 'care-feedback-$id-snoozed');
      expect(fixture.item(id).status, DecisionSupportFollowupStatus.snoozed);
      expect(find.byKey(ValueKey('care-prompt-$id')), findsNothing);
      await _tap(tester, 'care-followup-filter-snoozed');
      expect(find.byKey(ValueKey('care-prompt-$id')), findsOneWidget);
      await _tap(tester, 'care-followup-filter-needsReview');
      expect(find.byKey(ValueKey('care-prompt-$id')), findsNothing);
      await _tap(tester, 'care-followup-filter-all');
      expect(find.byKey(ValueKey('care-prompt-$id')), findsOneWidget);
      expect(fixture.item(id).status, DecisionSupportFollowupStatus.snoozed);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source history keeps source IDs and states the local registry boundary',
    (tester) async {
      final fixture = await _pump(tester);
      final item = fixture.state.followups().first;
      await _tap(tester, 'care-history-${item.prompt.id}');

      expect(find.textContaining('Sources:'), findsOneWidget);
      for (final sourceRef in item.prompt.sourceRefs) {
        expect(
          find.textContaining(sourceRef),
          findsWidgets,
          reason: 'Source reference $sourceRef should remain inspectable.',
        );
      }
      if (item.prompt.sourceRefs.isNotEmpty) {
        expect(
          find.textContaining('Local registry metadata only.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dismiss requires reason; closed prompt exposes only reopen and retains history',
    (tester) async {
      final fixture = await _pump(tester);
      final id = fixture.state.followups().first.prompt.id;
      await _tap(tester, 'care-feedback-$id-dismissed');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('care-save-dismiss-reason')),
            )
            .onPressed,
        isNull,
      );
      expect(fixture.item(id).history, isEmpty);
      await _tap(tester, 'care-reason-category-duplicateOrAlreadyAddressed');
      await tester.enterText(
        find.byKey(const ValueKey('care-dismiss-reason')),
        'Already added to my visit questions.',
      );
      await _tap(tester, 'care-save-dismiss-reason');
      expect(fixture.item(id).status, DecisionSupportFollowupStatus.dismissed);
      expect(
        fixture.item(id).history.single.reason,
        'Already added to my visit questions.',
      );
      expect(
        fixture.item(id).history.single.reasonCategory,
        DecisionSupportFeedbackReasonCategory.duplicateOrAlreadyAddressed,
      );
      await _tap(tester, 'care-followup-filter-all');
      expect(
        find.byKey(ValueKey('care-feedback-$id-needsReview')),
        findsOneWidget,
      );
      for (final action in ['read', 'resolved', 'snoozed', 'dismissed']) {
        expect(find.byKey(ValueKey('care-feedback-$id-$action')), findsNothing);
      }
      await _tap(tester, 'care-history-$id');
      expect(
        find.textContaining('Already added to my visit questions.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Duplicate or already addressed'),
        findsOneWidget,
      );
      await _tap(tester, 'care-feedback-$id-needsReview');
      expect(
        fixture.item(id).status,
        DecisionSupportFollowupStatus.needsReview,
      );
      expect(fixture.item(id).history, hasLength(2));
      await _tap(tester, 'care-feedback-$id-resolved');
      expect(fixture.item(id).status, DecisionSupportFollowupStatus.resolved);
      expect(
        find.byKey(ValueKey('care-feedback-$id-needsReview')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('care-feedback-$id-read')), findsNothing);
      expect(find.byKey(ValueKey('care-feedback-$id-dismissed')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in [
    DecisionSupportFollowupStatus.notApplicable,
    DecisionSupportFollowupStatus.declined,
  ]) {
    testWidgets('${status.name} feedback requires a reason and can reopen', (
      tester,
    ) async {
      final fixture = await _pump(tester);
      final id = fixture.state.followups().first.prompt.id;
      final boundary = find.textContaining(
        'Recording feedback is a workflow choice only.',
      );
      await tester.scrollUntilVisible(
        boundary,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(boundary, findsOneWidget);
      await _tap(tester, 'care-feedback-$id-${status.name}');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('care-save-dismiss-reason')),
            )
            .onPressed,
        isNull,
      );
      final category = status == DecisionSupportFollowupStatus.notApplicable
          ? DecisionSupportFeedbackReasonCategory.contextMismatch
          : DecisionSupportFeedbackReasonCategory.explanationUnclear;
      await _tap(tester, 'care-reason-category-${category.name}');
      await tester.enterText(
        find.byKey(const ValueKey('care-dismiss-reason')),
        'Recorded as my own workflow choice.',
      );
      await _tap(tester, 'care-save-dismiss-reason');
      expect(fixture.item(id).recordedStatus, status);
      expect(
        fixture.item(id).history.single.reason,
        'Recorded as my own workflow choice.',
      );
      expect(fixture.item(id).history.single.reasonCategory, category);

      await _tap(tester, 'care-followup-filter-all');
      await tester.ensureVisible(
        find.byKey(ValueKey('care-feedback-$id-needsReview')),
      );
      expect(find.byKey(ValueKey('care-feedback-$id-read')), findsNothing);
      expect(find.byKey(ValueKey('care-feedback-$id-resolved')), findsNothing);
      expect(find.byKey(ValueKey('care-feedback-$id-dismissed')), findsNothing);
      await _tap(tester, 'care-feedback-$id-needsReview');
      expect(
        fixture.item(id).recordedStatus,
        DecisionSupportFollowupStatus.needsReview,
      );
      expect(fixture.item(id).history, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed note save retains text, retry commits and then clears', (
    tester,
  ) async {
    final fixture = await _pump(tester, withPrompts: false);
    final input = find.byKey(const ValueKey('care-note-input'));
    await tester.scrollUntilVisible(
      input,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(input, 'Please review my supplement list.');
    fixture.store.failWrites = true;
    await _tap(tester, 'care-add-note');
    expect(fixture.state.discussionNotes, isEmpty);
    expect(
      tester.widget<TextField>(input).controller!.text,
      'Please review my supplement list.',
    );
    expect(
      find.text('Could not save. The record was not updated. Please retry.'),
      findsOneWidget,
    );
    fixture.store.failWrites = false;
    await _tap(tester, 'care-add-note');
    expect(
      fixture.state.discussionNotes.single.text,
      'Please review my supplement list.',
    );
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'report preparation and clipboard delivery require separate clicks; account switch expires preview',
    (tester) async {
      final clipboardWrites = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardWrites.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final fixture = await _pump(tester, withPrompts: false);
      expect(
        await tester.runAsync(
          () => fixture.state.addDiscussionNote(
            'Private synthetic visit question.',
          ),
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.byType(VisitPreparationPreview), findsNothing);
      expect(clipboardWrites, isEmpty);
      await _tap(tester, 'care-prepare-visit');
      expect(find.byType(VisitPreparationPreview), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor?.a,
        1,
      );
      expect(
        find.textContaining('Private synthetic visit question.'),
        findsOneWidget,
      );
      expect(clipboardWrites, isEmpty);
      await _tap(tester, 'care-copy-agenda');
      expect(clipboardWrites, hasLength(1));
      expect(
        clipboardWrites.single,
        contains('Private synthetic visit question.'),
      );
      expect(clipboardWrites.single, contains('Visit discussion summary'));
      expect(clipboardWrites.single.length, lessThan(5000));
      expect(find.text('Concise agenda copied.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _tap(tester, 'care-copy-report');
      expect(clipboardWrites, hasLength(2));
      expect(
        clipboardWrites.last,
        contains('Private synthetic visit question.'),
      );
      expect(
        clipboardWrites.last.length,
        greaterThan(clipboardWrites.first.length),
      );
      expect(find.text('Checklist copied.'), findsOneWidget);
      await tester.runAsync(fixture.state.signOut);
      await tester.runAsync(
        () => fixture.state.signInWithEmail(
          email: 'care-b@example.test',
          password: 'test-local-only',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('care-copy-report')), findsNothing);
      expect(find.byKey(const ValueKey('care-copy-agenda')), findsNothing);
      expect(
        find.textContaining('Private synthetic visit question.'),
        findsNothing,
      );
      expect(
        find.text('Account changed. Please generate a new checklist.'),
        findsOneWidget,
      );
      expect(clipboardWrites, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Chinese narrow layout and MainShell entry reach the live workspace',
    (tester) async {
      final fixture = await _pump(
        tester,
        chinese: true,
        mainShell: true,
        withPrompts: false,
      );
      await _tap(tester, 'main-care-workspace');
      expect(find.byType(CareWorkspacePage), findsOneWidget);
      expect(find.text('就诊准备与待核实事项'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('care-note-input')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('care-note-input')),
        '下次就诊讨论这条观察。',
      );
      await _tap(tester, 'care-add-note');
      expect(fixture.state.discussionNotes.single.text, '下次就诊讨论这条观察。');
      await _tap(tester, 'care-prepare-visit');
      expect(find.text('就诊清单预览'), findsOneWidget);
      expect(find.textContaining('下次就诊讨论这条观察。'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('care-copy-report')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('复制清单'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visit source issue opens the current medication reconciliation page',
    (tester) async {
      final fixture = await _pump(tester, withPrompts: false);
      await _saveMedicationSourceConflict(tester, fixture.state);

      await _tap(tester, 'care-prepare-visit');
      expect(find.byType(VisitPreparationPreview), findsOneWidget);
      expect(
        find.textContaining('Medication source records to review'),
        findsOneWidget,
      );
      final reviewButton = find.byKey(
        const ValueKey('visit-review-medication-visit-source-review-intake'),
      );
      expect(reviewButton, findsOneWidget);
      await tester.ensureVisible(reviewButton);
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      expect(
        find.byType(MedicationAssertionReconciliationPage),
        findsOneWidget,
      );
      expect(find.text('Medication source and time review'), findsOneWidget);
      expect(find.textContaining('Imported care portal'), findsWidgets);
      expect(
        find.textContaining('Assertion subgate: unresolved blocker'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'structured OTC entry remains unverified and appears in visit preview',
    (tester) async {
      final fixture = await _pump(tester, withPrompts: false);
      await _tap(tester, 'care-add-medication-discussion');
      await tester.enterText(
        find.byKey(const ValueKey('care-medication-name')),
        'Synthetic supplement',
      );
      await tester.enterText(
        find.byKey(const ValueKey('care-medication-ingredient-label')),
        'Example Ingredient A',
      );
      await tester.tap(find.byKey(const ValueKey('care-medication-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supplement (as entered)').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('care-medication-dose-text')),
        'unknown; bring package',
      );
      await tester.enterText(
        find.byKey(const ValueKey('care-medication-question')),
        'Ask about the ingredient list.',
      );
      await _tap(tester, 'care-save-medication-discussion');

      expect(fixture.state.medicationDiscussionEntries, hasLength(1));
      final entry = fixture.state.medicationDiscussionEntries.single;
      expect(entry.category, CareMedicationDiscussionCategory.supplement);
      expect(entry.reportedUse, CareMedicationReportedUse.uncertain);
      expect(entry.ingredientLabel, 'Example Ingredient A');
      expect(fixture.state.intakes, isEmpty);
      await _tap(tester, 'care-medication-outcome-${entry.id}');
      expect(find.text('Synthetic supplement'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('care-outcome-status-${entry.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owner reported: follow-up needed').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('care-outcome-note-${entry.id}')),
        'Owner recorded one remaining question.',
      );
      await _tap(tester, 'care-save-outcome-${entry.id}');
      expect(fixture.state.medicationDiscussionOutcomes, hasLength(1));
      expect(
        fixture.state.medicationDiscussionOutcomes.single.status,
        CareMedicationDiscussionOutcomeStatus.followUpNeeded,
      );
      await _tap(tester, 'care-prepare-visit');
      expect(find.textContaining('Synthetic supplement'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('not matched to a medication catalog'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.textContaining('Visit preparation checklist'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Synthetic supplement'), findsWidgets);
      expect(find.textContaining('Example Ingredient A'), findsWidgets);
      expect(
        find.textContaining('Owner recorded one remaining question.'),
        findsOneWidget,
      );
      expect(find.textContaining('follow-up needed'), findsWidgets);
      expect(
        find.textContaining('not matched to a medication catalog'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FHIR R4 medication preview is local and copies only after explicit action',
    (tester) async {
      final fixture = await _pump(tester, withPrompts: false);
      await _saveMedicationItem(tester, fixture.state);
      final writesBeforeExport = fixture.store.writeCount;
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _tap(tester, 'care-medication-fhir-export');
      await tester.enterText(
        find.byKey(const ValueKey('care-medication-fhir-patient-reference')),
        'Patient/synthetic-patient',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('care-medication-fhir-export-copy')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('care-medication-fhir-export-preview')),
      );
      await tester.pumpAndSettle();
      final previewText = tester
          .widget<SelectableText>(
            find.byKey(
              const ValueKey('care-medication-fhir-export-preview-json'),
            ),
          )
          .data!;
      final bundle = jsonDecode(previewText) as Map<String, dynamic>;
      final resource =
          (((bundle['entry'] as List).single as Map)['resource']
              as Map<String, dynamic>);
      expect(bundle['type'], 'collection');
      expect(resource['resourceType'], 'MedicationStatement');
      expect(resource['status'], 'active');
      expect(resource['medicationCodeableConcept'], {
        'text': 'Synthetic medication item',
      });
      expect(
        (resource['subject'] as Map)['reference'],
        'Patient/synthetic-patient',
      );
      expect(resource['dosage'], [
        {'text': 'one tablet, timing to verify'},
      ]);
      expect(
        previewText,
        isNot(contains('Private synthetic ingredient label')),
      );
      expect(previewText, isNot(contains('Private synthetic question')));
      expect(previewText, isNot(contains('fhir-medication-entry')));
      expect(previewText, isNot(contains(fixture.state.currentUserId!)));
      expect(
        find.textContaining('may treat them as medication-use statements'),
        findsOneWidget,
      );
      expect(clipboardText, isNull);
      expect(fixture.store.writeCount, writesBeforeExport);

      await _tap(tester, 'care-medication-fhir-export-copy');
      expect(jsonDecode(clipboardText!)['type'], 'collection');
      expect(fixture.store.writeCount, writesBeforeExport);
      expect(
        find.text('FHIR medication statement JSON copied to the clipboard.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FHIR medication preview expires when the account changes', (
    tester,
  ) async {
    final fixture = await _pump(tester, withPrompts: false);
    await _saveMedicationItem(tester, fixture.state);
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _tap(tester, 'care-medication-fhir-export');
    await tester.enterText(
      find.byKey(const ValueKey('care-medication-fhir-patient-reference')),
      'Patient/synthetic-patient',
    );
    await tester.tap(
      find.byKey(const ValueKey('care-medication-fhir-export-preview')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('care-medication-fhir-export-preview-json')),
      findsOneWidget,
    );

    await tester.runAsync(fixture.state.signOut);
    await tester.runAsync(
      () => fixture.state.signInWithEmail(
        email: 'care-b@example.test',
        password: 'test-local-only',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('care-medication-fhir-export-preview-json')),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('care-medication-fhir-export-copy')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('account changed. This export has been cancelled'),
      findsOneWidget,
    );
    expect(clipboardText, isNull);
    await tester.tap(
      find.byKey(const ValueKey('care-medication-fhir-export-cancel')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('FHIR medication preview expires when its records change', (
    tester,
  ) async {
    final fixture = await _pump(tester, withPrompts: false);
    await _saveMedicationItem(tester, fixture.state);
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _tap(tester, 'care-medication-fhir-export');
    await tester.enterText(
      find.byKey(const ValueKey('care-medication-fhir-patient-reference')),
      'Patient/synthetic-patient',
    );
    await tester.tap(
      find.byKey(const ValueKey('care-medication-fhir-export-preview')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('care-medication-fhir-export-preview-json')),
      findsOneWidget,
    );

    await tester.runAsync(
      () => fixture.state.deleteMedicationDiscussionEntry(
        'fhir-medication-entry',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('care-medication-fhir-export-preview-json')),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('care-medication-fhir-export-copy')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('records changed. Close this dialog'),
      findsOneWidget,
    );
    expect(clipboardText, isNull);
    await tester.tap(
      find.byKey(const ValueKey('care-medication-fhir-export-cancel')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching outcome entries clears the unsaved form draft', (
    tester,
  ) async {
    final fixture = await _pump(tester, withPrompts: false);
    final owner = fixture.state.currentUserId!;
    for (final id in ['discussion-one', 'discussion-two']) {
      final saved = await tester.runAsync(
        () => fixture.state.saveMedicationDiscussionEntry(
          CareMedicationDiscussionEntry(
            id: id,
            name: 'Synthetic product $id',
            category: CareMedicationDiscussionCategory.supplement,
            reportedUse: CareMedicationReportedUse.uncertain,
            doseAndScheduleText: null,
            question: null,
            recordedAt: DateTime.utc(2026, 9, 22, 12),
            recorderId: owner,
          ),
        ),
      );
      expect(saved, isTrue);
      await tester.pumpAndSettle();
    }

    await _tap(tester, 'care-medication-outcome-discussion-one');
    await tester.tap(
      find.byKey(const ValueKey('care-outcome-status-discussion-one')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owner reported: follow-up needed').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('care-outcome-note-discussion-one')),
      'Draft for the first entry.',
    );

    await _tap(tester, 'care-medication-outcome-discussion-two');
    final secondStatus = tester
        .widget<DropdownButtonFormField<CareMedicationDiscussionOutcomeStatus>>(
          find.byKey(const ValueKey('care-outcome-status-discussion-two')),
        );
    final secondNote = tester.widget<TextField>(
      find.byKey(const ValueKey('care-outcome-note-discussion-two')),
    );
    expect(
      secondStatus.initialValue,
      CareMedicationDiscussionOutcomeStatus.notDiscussed,
    );
    expect(secondNote.controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'owner can review full outcome history and account change hides it',
    (tester) async {
      final fixture = await _pump(tester, withPrompts: false);
      final owner = fixture.state.currentUserId!;
      final saved = await tester.runAsync(() async {
        final entrySaved = await fixture.state.saveMedicationDiscussionEntry(
          CareMedicationDiscussionEntry(
            id: 'history-entry',
            name: 'Synthetic discussion item',
            category: CareMedicationDiscussionCategory.supplement,
            reportedUse: CareMedicationReportedUse.uncertain,
            doseAndScheduleText: null,
            question: null,
            recordedAt: DateTime.utc(2026, 9, 22, 12),
            recorderId: owner,
          ),
        );
        if (!entrySaved) return false;
        final firstSaved = await fixture.state
            .recordMedicationDiscussionOutcome(
              CareMedicationDiscussionOutcome(
                id: 'history-outcome-1',
                entryId: 'history-entry',
                status: CareMedicationDiscussionOutcomeStatus.discussed,
                note: 'The owner reports this was discussed.',
                recordedAt: DateTime.utc(2026, 9, 22, 13),
                recorderId: owner,
              ),
            );
        final secondSaved = await fixture.state
            .recordMedicationDiscussionOutcome(
              CareMedicationDiscussionOutcome(
                id: 'history-outcome-2',
                entryId: 'history-entry',
                status: CareMedicationDiscussionOutcomeStatus.followUpNeeded,
                note: 'The owner reports one question remains.',
                recordedAt: DateTime.utc(2026, 9, 22, 14),
                recorderId: owner,
              ),
            );
        return firstSaved && secondSaved;
      });
      expect(saved, isTrue);
      await tester.pumpAndSettle();

      await _tap(tester, 'care-medication-outcome-history-history-entry');
      final historyList = find.byKey(
        const ValueKey('care-outcome-history-list-history-entry'),
      );
      final historyScroll = find
          .descendant(of: historyList, matching: find.byType(Scrollable))
          .first;
      final firstHistoryItem = find.byKey(
        const ValueKey('care-outcome-history-item-history-outcome-1'),
      );
      final secondHistoryItem = find.byKey(
        const ValueKey('care-outcome-history-item-history-outcome-2'),
      );
      expect(firstHistoryItem, findsOneWidget);
      expect(
        find.textContaining('The owner reports this was discussed.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        secondHistoryItem,
        180,
        scrollable: historyScroll,
      );
      expect(secondHistoryItem, findsOneWidget);
      expect(
        find.textContaining('The owner reports one question remains.'),
        findsOneWidget,
      );
      expect(find.textContaining('not clinician-verified'), findsOneWidget);

      await tester.runAsync(fixture.state.signOut);
      await tester.runAsync(
        () => fixture.state.signInWithEmail(
          email: 'care-b@example.test',
          password: 'test-local-only',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Account changed. History is hidden.'), findsOneWidget);
      expect(
        find.textContaining('The owner reports this was discussed.'),
        findsNothing,
      );
      expect(
        find.textContaining('The owner reports one question remains.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _Fixture {
  const _Fixture(this.state, this.store);
  final AppState state;
  final _ControlledStore store;
  DecisionSupportFollowupItem item(String id) => state
      .followups(includeHistory: true)
      .singleWhere((item) => item.prompt.id == id);
}

class _ControlledStore implements CareWorkspaceStore {
  final delegate = MemoryCareWorkspaceStore();
  bool failWrites = false;
  int writeCount = 0;
  @override
  Future<String?> read(String ownerScope) => delegate.read(ownerScope);
  @override
  Future<void> write(
    String ownerScope,
    String document, {
    required bool Function() authorize,
  }) async {
    if (failWrites) throw StateError('synthetic_write_failure');
    writeCount++;
    await delegate.write(ownerScope, document, authorize: authorize);
  }
}
