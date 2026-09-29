import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/services/care_workspace_service.dart';
import 'package:parkinsum_companion/core/services/care_workspace_store.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_entry.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_outcome.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_list_review.dart';
import 'package:parkinsum_companion/domain/entities/decision_support_followup.dart';
import 'package:parkinsum_companion/domain/entities/medication_assertion_reconciliation.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'medication list review marks persist and appear in visit preparation',
    () async {
      final store = MemoryCareWorkspaceStore();
      final state = await _state(store);
      expect(
        await state.setMedicationListReviewSection(
          CareMedicationListReviewSection.vitaminsAndSupplements,
          reviewed: true,
        ),
        isTrue,
      );
      expect(state.medicationListReviews, hasLength(1));
      expect(
        state.medicationListReviews.single.recorderId,
        state.currentUserId,
      );

      final report = state.prepareVisit(
        now: DateTime.now().toUtc().add(const Duration(seconds: 1)),
      );
      expect(
        report.medicationListReviewStatuses
            .singleWhere(
              (status) =>
                  status.section ==
                  CareMedicationListReviewSection.vitaminsAndSupplements,
            )
            .wasMarkedReviewed,
        isTrue,
      );
      expect(
        report.plainText,
        contains('Account-holder medication-list self-check'),
      );

      expect(
        await state.setMedicationListReviewSection(
          CareMedicationListReviewSection.vitaminsAndSupplements,
          reviewed: false,
        ),
        isTrue,
      );
      expect(state.medicationListReviews, isEmpty);
    },
  );

  test(
    'visit export preserves blood pressure posture and both timestamps',
    () async {
      final state = await _state(MemoryCareWorkspaceStore());
      final occurred = DateTime.utc(2026, 9, 19, 14);
      final recorded = DateTime.utc(2026, 9, 20, 17);
      for (final posture in [
        BloodPressurePosture.sitting,
        BloodPressurePosture.standing,
      ]) {
        expect(
          await state.saveObservation(
            PersonalObservation.create(
              id: 'bp-${posture.name}',
              kind: PersonalObservationKind.bloodPressure,
              occurredAt: occurred,
              recordedAt: recorded,
              originalTimezone: 'UTC-04:00',
              source: PersonalObservationSource.deviceManual,
              recorderId: 'local_user',
              status: PersonalObservationStatus.recorded,
              systolic: 120,
              diastolic: 80,
              unit: 'mm[Hg]',
              posture: posture,
            ),
          ),
          isTrue,
        );
      }
      final report = state.prepareVisit(now: DateTime.utc(2026, 9, 22));
      expect(
        report.observations.map((item) => item.occurredAt),
        everyElement(occurred),
      );
      expect(
        report.observations.map((item) => item.recordedAt),
        everyElement(recorded),
      );
      expect(report.plainText, contains('Sitting'));
      expect(report.plainText, contains('Standing'));
      expect(report.plainText, contains('Device reading entered manually'));
    },
  );

  test(
    'visit observation selection affects only the prepared report',
    () async {
      final state = await _state(MemoryCareWorkspaceStore());
      for (final (id, note) in [
        ('visit-observation-kept', 'Keep this synthetic note'),
        ('visit-observation-omitted', 'Omit this synthetic note'),
      ]) {
        expect(
          await state.saveObservation(
            PersonalObservation.create(
              id: id,
              kind: PersonalObservationKind.symptom,
              occurredAt: DateTime.utc(2026, 9, 20, 10),
              recordedAt: DateTime.utc(2026, 9, 20, 11),
              originalTimezone: 'UTC',
              source: PersonalObservationSource.selfReported,
              recorderId: state.currentUserId!,
              status: PersonalObservationStatus.recorded,
              symptomLabel: 'Synthetic symptom',
              severity: 2,
              notes: note,
            ),
          ),
          isTrue,
        );
      }

      final selected = state.prepareVisit(
        now: DateTime.utc(2026, 9, 22),
        includedObservationIds: {'visit-observation-kept', 'stale-id'},
      );
      expect(
        selected.observations.single.sourceRecordId,
        'visit-observation-kept',
      );
      expect(selected.omittedObservationCount, 1);
      expect(selected.plainText, contains('Keep this synthetic note'));
      expect(selected.plainText, isNot(contains('Omit this synthetic note')));

      final defaultReport = state.prepareVisit(now: DateTime.utc(2026, 9, 22));
      expect(defaultReport.observations, hasLength(2));
      expect(defaultReport.omittedObservationCount, 0);
      expect(state.observations, hasLength(2));
    },
  );

  test(
    'visit export carries unresolved medication source conflicts and owner review',
    () async {
      final state = await _state(
        MemoryCareWorkspaceStore(),
        withMedication: true,
      );
      final eventTime = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      final intake = Intake(
        id: 'visit-assertion-intake',
        drugId: 'drug_levodopa_carbidopa',
        takenAt: eventTime,
        dosageNote: '100 mg',
        doseAmount: 100,
        doseUnit: 'mg',
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: 'immediate',
      );
      final saved = await state.saveIntakeWithDoseConfirmation(
        draft: intake,
        isUpdate: false,
        expectedRecordRevisionDigest:
            administrationDoseConfirmationAbsentRevisionDigest,
        confirmationRequested: true,
        assertionSource: AdministrationDoseAssertionSource.typed,
        confirmationAction: 'test.explicit_confirmation',
        uiContractVersion: 'visit-assertion-review:1',
      );
      expect(saved.mutation, isNotNull);

      final confirmedIntake = state.intakes.single;
      final expectedGraph = state
          .medicationAssertionGraphFor(confirmedIntake)
          .graphDigest;
      expect(
        await state.appendMedicationAssertion(
          intakeId: confirmedIntake.id,
          expectedGraphDigest: expectedGraph,
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
        isNotNull,
      );

      final conflictIntake = state.intakes.single;
      final conflictGraph = state.medicationAssertionGraphFor(conflictIntake);
      expect(
        conflictGraph.blockingEdges.map((edge) => edge.relationship.name),
        contains('doseConflict'),
      );
      expect(
        await state.appendMedicationReconciliationDecision(
          intakeId: conflictIntake.id,
          expectedGraphDigest: conflictGraph.graphDigest,
          resolution: MedicationReconciliationResolution.confirmedNoConflict,
        ),
        isNotNull,
      );

      final report = state.prepareVisit(
        now: DateTime.now().toUtc().add(const Duration(seconds: 2)),
      );
      expect(report.medicationAssertionReviews, hasLength(1));
      expect(
        report.medicationAssertionReviews.single.blockingConflicts.map(
          (item) => item.relationship,
        ),
        contains('doseConflict'),
      );
      expect(report.plainText, contains('Imported care portal'));
      expect(report.plainText, contains('50 mg'));
      expect(
        report.plainText,
        contains('Owner recorded no conflict; source relationships remain'),
      );
      expect(
        report.plainText,
        contains('A user acknowledgement does not clear a conflict'),
      );
    },
  );

  test('bootstrap loads only the authenticated local care workspace', () async {
    final store = MemoryCareWorkspaceStore();
    for (final owner in ['local_user', 'local_other@example.test']) {
      store.documents[careWorkspaceStorageKey(owner)] = jsonEncode(
        CareWorkspaceSnapshot.empty(owner)
            .copyWith(
              observations: [_observation(owner, 'observation-$owner')],
              notes: [_note(owner, 'note-$owner')],
            )
            .toJson(),
      );
    }
    final state = await _state(store);
    expect(state.currentUserId, 'local_user');
    expect(state.observations.single.id, 'observation-local_user');
    expect(state.discussionNotes.single.id, 'note-local_user');
    expect(state.careWorkspaceError, isNull);
    expect(
      state.timeline.where((entry) => entry.recordId.contains('observation')),
      isNotEmpty,
    );
  });

  test(
    'manual medication discussion entries persist and remain outside intakes',
    () async {
      final store = MemoryCareWorkspaceStore();
      final state = await _state(store);
      final entry = CareMedicationDiscussionEntry(
        id: 'otc-discussion-1',
        name: 'Synthetic OTC product',
        category: CareMedicationDiscussionCategory.overTheCounter,
        reportedUse: CareMedicationReportedUse.uncertain,
        doseAndScheduleText: 'unknown',
        question: 'Check the package at the next visit.',
        recordedAt: DateTime.utc(2026, 9, 22, 12),
        recorderId: 'local_user',
      );

      expect(await state.saveMedicationDiscussionEntry(entry), isTrue);
      expect(state.medicationDiscussionEntries.single.toJson(), entry.toJson());
      expect(
        await state.recordMedicationDiscussionOutcome(
          CareMedicationDiscussionOutcome(
            id: 'outcome-1',
            entryId: entry.id,
            status: CareMedicationDiscussionOutcomeStatus.discussed,
            note: 'Owner reports the question was discussed.',
            recordedAt: DateTime.utc(2026, 9, 22, 12, 30),
            recorderId: 'local_user',
          ),
        ),
        isTrue,
      );
      expect(
        await state.recordMedicationDiscussionOutcome(
          CareMedicationDiscussionOutcome(
            id: 'outcome-2',
            entryId: entry.id,
            status: CareMedicationDiscussionOutcomeStatus.followUpNeeded,
            note: 'Owner reports a further question remains.',
            recordedAt: DateTime.utc(2026, 9, 22, 12, 45),
            recorderId: 'local_user',
          ),
        ),
        isTrue,
      );
      expect(state.medicationDiscussionOutcomes, hasLength(2));
      expect(state.intakes, isEmpty);
      final report = state.prepareVisit(now: DateTime.utc(2026, 9, 22, 13));
      expect(report.medicationDiscussionEntries.single.id, entry.id);
      expect(report.latestMedicationDiscussionOutcomes, hasLength(1));
      expect(
        report.latestMedicationDiscussionOutcomes.single.status,
        CareMedicationDiscussionOutcomeStatus.followUpNeeded,
      );
      expect(
        report.plainText,
        anyOf(
          contains('Owner reported: follow-up needed'),
          contains('本人记录：需要跟进'),
        ),
      );
      expect(
        report.plainText,
        anyOf(contains('not clinician-verified'), contains('未经临床人员核实')),
      );
      await state.reloadCareWorkspace();
      expect(state.medicationDiscussionEntries.single.id, entry.id);
      expect(state.medicationDiscussionOutcomes, hasLength(2));
      expect(await state.deleteMedicationDiscussionEntry(entry.id), isTrue);
      expect(state.medicationDiscussionEntries, isEmpty);
      expect(state.medicationDiscussionOutcomes, isEmpty);
      expect(
        (jsonDecode(store.documents[careWorkspaceStorageKey('local_user')]!)
            as Map<String, dynamic>)['medicationDiscussionEntries'],
        isEmpty,
      );
      expect(
        (jsonDecode(store.documents[careWorkspaceStorageKey('local_user')]!)
            as Map<String, dynamic>)['medicationDiscussionOutcomes'],
        isEmpty,
      );
    },
  );

  test(
    'observation and note edits survive reload and delete durably',
    () async {
      final store = MemoryCareWorkspaceStore();
      final state = await _state(store);
      final observation = _observation('local_user', 'observation-one');
      expect(await state.saveObservation(observation), isTrue);
      expect(
        await state.addDiscussionNote('  Please review my supplement list.  '),
        isTrue,
      );
      expect(
        state.discussionNotes.single.text,
        'Please review my supplement list.',
      );
      final noteId = state.discussionNotes.single.id;
      await state.reloadCareWorkspace();
      expect(state.observations.single.toJson(), observation.toJson());
      expect(state.discussionNotes.single.id, noteId);
      expect(
        await state.saveObservation(
          _observation('local_user', 'observation-one', severity: 4),
        ),
        isTrue,
      );
      expect(state.observations, hasLength(1));
      expect(state.observations.single.severity, 4);
      expect(await state.deleteObservation(observation.id), isTrue);
      expect(await state.deleteDiscussionNote(noteId), isTrue);
      await state.reloadCareWorkspace();
      expect(state.observations, isEmpty);
      expect(state.discussionNotes, isEmpty);
      final saved = await state.services.careWorkspaceService.load(
        'local_user',
      );
      expect(saved.observations, isEmpty);
      expect(saved.notes, isEmpty);
    },
  );

  test(
    'write failure leaves visible and durable data unchanged and reports error',
    () async {
      final store = _FailingStore();
      final state = await _state(store);
      expect(
        await state.saveObservation(_observation('local_user', 'kept')),
        isTrue,
      );
      expect(await state.addDiscussionNote('Keep this note.'), isTrue);
      final before = store.documents['local_user'];
      final oldObservation = state.observations.single;
      final oldNote = state.discussionNotes.single;
      store.failWrites = true;
      expect(
        await state.saveObservation(_observation('local_user', 'new')),
        isFalse,
      );
      expect(state.observations.single, same(oldObservation));
      expect(await state.deleteDiscussionNote(oldNote.id), isFalse);
      expect(state.discussionNotes.single, same(oldNote));
      expect(state.careWorkspaceError, 'save_failed');
      expect(store.documents['local_user'], before);
      store.failWrites = false;
      expect(await state.addDiscussionNote('Retry succeeded.'), isTrue);
      expect(state.careWorkspaceError, isNull);
      expect(state.discussionNotes, hasLength(2));
    },
  );

  test(
    'account changes clear visible data and preserve separate local records',
    () async {
      final store = MemoryCareWorkspaceStore();
      final state = await _state(store);
      expect(
        await state.saveObservation(_observation('local_user', 'owner-a')),
        isTrue,
      );
      expect(await state.addDiscussionNote('Owner A note'), isTrue);
      await state.signInWithEmail(
        email: 'b@example.test',
        password: 'local-test',
      );
      expect(state.currentUserId, 'local_b@example.test');
      expect(state.observations, isEmpty);
      expect(state.discussionNotes, isEmpty);
      expect(
        await state.saveObservation(_observation('local_user', 'wrong-owner')),
        isFalse,
      );
      expect(await state.addDiscussionNote('Owner B note'), isTrue);
      await state.signOut();
      expect(state.observations, isEmpty);
      expect(state.discussionNotes, isEmpty);
      expect(await state.addDiscussionNote('Signed out'), isFalse);
      await state.bootstrap();
      expect(state.currentUserId, 'local_user');
      expect(state.observations.single.id, 'owner-a');
      expect(state.discussionNotes.single.text, 'Owner A note');
      final ownerB = await state.services.careWorkspaceService.load(
        'local_b@example.test',
      );
      expect(ownerB.notes.single.text, 'Owner B note');
      expect(ownerB.observations, isEmpty);
    },
  );

  test(
    'saved meal registers prompts while a new meal draft stays transient',
    () async {
      final store = MemoryCareWorkspaceStore();
      final state = await _state(store, withMedication: true);
      final draft = _meal(state, 'new-meal');
      final initialDocument =
          store.documents[careWorkspaceStorageKey('local_user')];
      final checked = await state.checkMeal(draft);
      expect(
        checked.followupPrompts,
        isNotEmpty,
        reason: 'Fixture must exercise actual deterministic rule output.',
      );
      expect(state.meals, isEmpty);
      expect(state.followups(includeHistory: true), isEmpty);
      expect(
        store.documents[careWorkspaceStorageKey('local_user')],
        initialDocument,
      );
      final saved = await state.addMeal(draft);
      expect(saved.wasCommitted, isTrue);
      expect(state.followups(includeHistory: true), isNotEmpty);
      final persisted = await state.services.careWorkspaceService.load(
        'local_user',
      );
      expect(persisted.followups.prompts, isNotEmpty);
      expect(
        persisted.followups.prompts.every(
          (prompt) => prompt.sourceRecordId == draft.id,
        ),
        isTrue,
      );
    },
  );

  test('visit preparation omits a not-applicable follow-up choice', () async {
    final state = await _state(
      MemoryCareWorkspaceStore(),
      withMedication: true,
    );
    final meal = _meal(state, 'visit-followup-meal');
    expect((await state.addMeal(meal)).wasCommitted, isTrue);
    final closed = state.followups(includeHistory: true).first;
    expect(
      await state.recordFollowup(
        promptId: closed.prompt.id,
        status: DecisionSupportFollowupStatus.notApplicable,
        reason: 'Recorded as my workflow choice.',
        reasonCategory: DecisionSupportFeedbackReasonCategory.contextMismatch,
      ),
      isTrue,
    );

    final report = state.prepareVisit(now: DateTime.utc(2026, 9, 22));
    expect(
      report.discussionItems.map((item) => item.sourceIds.first),
      isNot(contains('prompt:${closed.prompt.id}')),
    );
  });

  test(
    'rechecking a saved meal preserves explicit feedback and original prompt',
    () async {
      final store = MemoryCareWorkspaceStore();
      final state = await _state(store, withMedication: true);
      final meal = _meal(state, 'saved-meal');
      expect((await state.addMeal(meal)).wasCommitted, isTrue);
      final original = state.followups(includeHistory: true).first;
      expect(
        await state.recordFollowup(
          promptId: original.prompt.id,
          status: DecisionSupportFollowupStatus.needsReview,
          reason: 'Discuss at the next visit.',
        ),
        isTrue,
      );
      final afterFeedback =
          store.documents[careWorkspaceStorageKey('local_user')];
      await state.checkMeal(meal);
      final repeated = state
          .followups(includeHistory: true)
          .singleWhere((item) => item.prompt.id == original.prompt.id);
      expect(repeated.status, DecisionSupportFollowupStatus.needsReview);
      expect(repeated.prompt.createdAt, original.prompt.createdAt);
      expect(
        store.documents[careWorkspaceStorageKey('local_user')],
        afterFeedback,
      );
      await state.reloadCareWorkspace();
      expect(
        state
            .followups(includeHistory: true)
            .singleWhere((item) => item.prompt.id == original.prompt.id)
            .status,
        DecisionSupportFollowupStatus.needsReview,
      );
    },
  );

  test(
    'an unsaved edit with an existing meal ID cannot register new prompts',
    () async {
      final store = MemoryCareWorkspaceStore();
      final state = await _state(store, withMedication: true);
      final savedMeal = _meal(state, 'existing-meal');
      expect((await state.addMeal(savedMeal)).wasCommitted, isTrue);
      final persisted = store.documents[careWorkspaceStorageKey('local_user')];
      final visiblePromptIds = state
          .followups()
          .map((item) => item.prompt.id)
          .toSet();
      final draft = savedMeal.copyWith(
        items: savedMeal.items
            .map((item) => item.copyWith(quantityFactor: 4))
            .toList(),
      );
      await state.checkMeal(draft);
      expect(state.meals.single.items.single.quantityFactor, 1);
      expect(store.documents[careWorkspaceStorageKey('local_user')], persisted);
      expect(
        state.followups().map((item) => item.prompt.id).toSet(),
        visiblePromptIds,
      );
    },
  );
}

Future<AppState> _state(
  CareWorkspaceStore store, {
  bool withMedication = false,
}) async {
  final services = Services.createEphemeral(careWorkspaceStore: store);
  await services.ready;
  if (withMedication) {
    await services.userDataService.saveActiveDrugIds([
      'drug_levodopa_carbidopa',
    ]);
  }
  final state = AppState(services: services);
  addTearDown(state.dispose);
  await state.bootstrap();
  return state;
}

PersonalObservation _observation(String owner, String id, {int severity = 2}) =>
    PersonalObservation.create(
      id: id,
      kind: PersonalObservationKind.symptom,
      occurredAt: DateTime.utc(2026, 9, 20, 10),
      recordedAt: DateTime.utc(2026, 9, 20, 11),
      originalTimezone: 'UTC',
      source: PersonalObservationSource.selfReported,
      recorderId: owner,
      status: PersonalObservationStatus.recorded,
      symptomLabel: 'User-recorded stiffness',
      severity: severity,
    );

CareDiscussionNote _note(String owner, String id) => CareDiscussionNote(
  id: id,
  text: 'Stored note for $owner',
  recordedAt: DateTime.utc(2026, 9, 20, 11),
  recorderId: owner,
);

Meal _meal(AppState state, String id) => Meal(
  id: id,
  title: 'Meal for source-capture test',
  eatenAt: DateTime.utc(2026, 9, 20, 12),
  items: [
    MealItem.fromFood(food: state.foodRepo.allFoods.first, quantityFactor: 1),
  ],
);

class _FailingStore implements CareWorkspaceStore {
  final documents = <String, String>{};
  bool failWrites = false;

  @override
  Future<String?> read(String ownerScope) async => documents[ownerScope];

  @override
  Future<void> write(
    String ownerScope,
    String document, {
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('care_workspace_session_changed');
    if (failWrites) throw StateError('test-write-failure');
    if (!authorize()) throw StateError('care_workspace_session_changed');
    documents[ownerScope] = document;
    if (!authorize()) throw StateError('care_workspace_session_changed');
  }
}
