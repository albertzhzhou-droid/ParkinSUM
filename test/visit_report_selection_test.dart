import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/personal_log_handoff_document_service.dart';
import 'package:parkinsum_companion/core/services/personal_log_handoff_text_pdf_renderer.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/services/care_workspace_service.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_entry.dart';
import 'package:parkinsum_companion/domain/entities/personal_log_view.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/entities/visit_report_selection.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_date_window_resolver.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_handoff_summary_service.dart';

final _asOf = DateTime.utc(2026, 10, 1, 23, 59);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  late String selectedQuestion;
  setUp(() async {
    final services = Services.createEphemeral();
    await services.ready;
    await services.userDataService.saveOnboarded(true);
    await services.userDataService.saveUserProfile(
      UserProfile.defaults().copyWith(displayLocale: 'en-US'),
    );
    state = AppState(services: services);
    await state.bootstrap();
    await Future<void>.delayed(Duration.zero);
    final owner = state.currentUserId!;
    await state.setActiveDrugIds(['drug_levodopa_carbidopa']);
    for (final id in ['selected_intake', 'unselected_intake']) {
      expect(
        (await state.addIntake(
          Intake(
            id: id,
            drugId: 'drug_levodopa_carbidopa',
            takenAt: DateTime.utc(
              2026,
              9,
              id == 'selected_intake' ? 29 : 30,
              12,
            ),
            dosageNote: id == 'selected_intake'
                ? 'Selected private dose'
                : 'UNSELECTED_PRIVATE_DOSE',
          ),
        )).wasCommitted,
        isTrue,
      );
    }
    selectedQuestion = 'selected_question';
    await services.careWorkspaceService.mutate(
      owner,
      (current) => current.copyWith(
        notes: [
          CareDiscussionNote(
            id: selectedQuestion,
            text: 'Selected explicit question',
            recordedAt: DateTime.utc(2026, 9, 30, 12),
            recorderId: owner,
          ),
          CareDiscussionNote(
            id: 'unselected_question',
            text: 'UNSELECTED_PRIVATE_QUESTION',
            recordedAt: DateTime.utc(2026, 9, 30, 13),
            recorderId: owner,
          ),
        ],
      ),
      authorize: () => state.currentUserId == owner,
    );
    await state.reloadCareWorkspace();
    for (final selected in [true, false]) {
      expect(
        await state.saveObservation(
          PersonalObservation.create(
            id: selected ? 'selected_observation' : 'unselected_observation',
            kind: PersonalObservationKind.symptom,
            occurredAt: DateTime.utc(2026, 9, 30, 12),
            recordedAt: DateTime.utc(2026, 9, 30, 13),
            originalTimezone: 'UTC',
            source: PersonalObservationSource.selfReported,
            recorderId: owner,
            status: PersonalObservationStatus.recorded,
            symptomLabel: selected
                ? 'Selected symptom'
                : 'UNSELECTED_PRIVATE_SYMPTOM',
            severity: 1,
            notes: selected
                ? 'Selected private observation note'
                : 'UNSELECTED_PRIVATE_NOTE',
          ),
        ),
        isTrue,
      );
      expect(
        await state.saveMedicationDiscussionEntry(
          CareMedicationDiscussionEntry(
            id: selected ? 'selected_item' : 'unselected_item',
            name: selected
                ? 'Selected medicine item'
                : 'UNSELECTED_PRIVATE_MEDICINE',
            category: CareMedicationDiscussionCategory.supplement,
            reportedUse: CareMedicationReportedUse.uncertain,
            ingredientLabel: 'Private ingredient detail',
            doseAndScheduleText: 'Private entered dose detail',
            question: selected
                ? 'Selected medicine question'
                : 'UNSELECTED_MEDICINE_QUESTION',
            recordedAt: DateTime.utc(2026, 9, 30, 12),
            recorderId: owner,
          ),
        ),
        isTrue,
      );
    }
  });
  tearDown(() => state.dispose());

  VisitReportSelection selection({
    bool notes = false,
    Iterable<String>? intakes,
    Iterable<String>? questions,
  }) => VisitReportSelection(
    window: PersonalLogDateWindow(
      start: LogCivilDate(2026, 9, 29),
      endInclusive: LogCivilDate(2026, 10, 1),
      zoneId: state.userProfile.timezone,
    ),
    intakeIds: intakes ?? ['selected_intake'],
    observationIds: ['selected_observation'],
    questionNoteIds: questions ?? [selectedQuestion],
    medicationEntryIds: ['selected_item'],
    followupPromptIds: [],
    includeCurrentMedications: false,
    includeRecordNotes: notes,
    includeDiscussionUpdates: false,
    includeSourceAssertions: false,
  );

  test(
    'explicit selection excludes unchosen records and keeps selected questions',
    () {
      final report = state.prepareVisit(now: _asOf, selection: selection());
      expect(report.currentMedications, isEmpty);
      expect(
        report.plainText,
        contains('Source assertions omitted by selection'),
      );
      expect(
        report.plainText,
        isNot(contains('No blocking source relationship')),
      );
      expect(
        report.agendaText,
        contains('Current selections and self-checks omitted'),
      );
      expect(report.historicalMedications, hasLength(1));
      expect(
        report.historicalMedications.single.latestIntake!.id,
        'selected_intake',
      );
      expect(report.observations.single.sourceRecordId, 'selected_observation');
      expect(report.medicationDiscussionEntries.single.id, 'selected_item');
      expect(report.plainText, contains('Selected explicit question'));
      expect(report.plainText, contains('Selected medicine question'));
      expect(report.plainText, isNot(contains('UNSELECTED')));
      expect(report.plainText, isNot(contains('Selected private dose')));
      expect(
        report.plainText,
        isNot(contains('Selected private observation note')),
      );
      expect(report.plainText, isNot(contains('Private ingredient detail')));
      expect(report.plainText, isNot(contains('Private entered dose detail')));
      expect(state.intakes, hasLength(2));
      expect(state.discussionNotes, hasLength(2));
      expect(state.observations, hasLength(2));
    },
  );

  test('attached notes are included only by their explicit choice', () {
    final report = state.prepareVisit(
      now: _asOf,
      selection: selection(notes: true),
    );
    expect(report.plainText, contains('Selected private dose'));
    expect(report.plainText, contains('Selected private observation note'));
    expect(report.plainText, contains('Private entered dose detail'));
    expect(report.plainText, isNot(contains('UNSELECTED')));
  });

  test('a selected question after the frozen asOf remains rejected', () async {
    final owner = state.currentUserId!;
    await state.services.careWorkspaceService.mutate(
      owner,
      (current) => current.copyWith(
        notes: [
          ...current.notes,
          CareDiscussionNote(
            id: 'future_question',
            text: 'Future synthetic question',
            recordedAt: _asOf.add(const Duration(minutes: 1)),
            recorderId: owner,
          ),
        ],
      ),
      authorize: () => state.currentUserId == owner,
    );
    await state.reloadCareWorkspace();
    expect(
      () => state.prepareVisit(
        now: _asOf,
        selection: selection(questions: ['future_question']),
      ),
      throwsStateError,
    );
    expect(state.discussionNotes, hasLength(3));
  });

  test(
    'HTML exports the frozen report with correct language and no raw owner',
    () {
      final selected = selection();
      final report = state.prepareVisit(now: _asOf, selection: selected);
      final lease = state.captureVisitPreparationLease();
      final artifact = const PersonalLogHandoffSummaryService()
          .createVisitPreparation(
            report: report,
            selection: selected,
            sourceLease: lease,
            localeTag: 'en-US',
          );
      final html = utf8.decode(
        const PersonalLogHandoffHtmlSerializer().render(artifact),
      );
      expect(html, contains('<html lang="en" dir="auto">'));
      expect(html, contains('Selected explicit question'));
      expect(html, contains('Selected medicine question'));
      expect(html, isNot(contains('UNSELECTED')));
      expect(html, isNot(contains(lease.owner)));
      expect(artifact.recordCounts['selectedIntakeEvidence'], 1);
      expect(artifact.semanticDocument['reportKind'], 'visit_preparation');
    },
  );

  test(
    'selected source, session and locale changes expire the lease',
    () async {
      var lease = state.captureVisitPreparationLease();
      expect(state.isVisitPreparationLeaseCurrent(lease), isTrue);
      await state.addDiscussionNote('New source record');
      expect(state.isVisitPreparationLeaseCurrent(lease), isFalse);
      lease = state.captureVisitPreparationLease();
      await state.bootstrap();
      expect(state.currentUserId, lease.owner);
      expect(state.isVisitPreparationLeaseCurrent(lease), isFalse);
      lease = state.captureVisitPreparationLease();
      await state.saveUserProfile(
        state.userProfile.copyWith(displayLocale: 'zh-CN'),
      );
      expect(state.isVisitPreparationLeaseCurrent(lease), isFalse);
    },
  );

  test(
    'deleted, unknown and out-of-window IDs fail instead of silently replacing selection',
    () {
      expect(
        () => state.prepareVisit(
          now: _asOf,
          selection: selection(intakes: ['not_stored']),
        ),
        throwsStateError,
      );
      final outside = VisitReportSelection(
        window: PersonalLogDateWindow(
          start: LogCivilDate(2026, 10, 1),
          endInclusive: LogCivilDate(2026, 10, 1),
          zoneId: state.userProfile.timezone,
        ),
        intakeIds: ['selected_intake'],
        observationIds: [],
        questionNoteIds: [],
        medicationEntryIds: [],
        followupPromptIds: [],
        includeCurrentMedications: false,
        includeRecordNotes: false,
        includeDiscussionUpdates: false,
        includeSourceAssertions: false,
      );
      expect(
        () => state.prepareVisit(now: _asOf, selection: outside),
        throwsStateError,
      );
      expect(
        () => state.prepareVisit(
          now: _asOf,
          selection: selection(),
          includedObservationIds: {},
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'selection keeps defensive sets and rejects duplicate or oversized inputs',
    () {
      final ids = ['selected_intake'];
      final value = selection(intakes: ids);
      ids.clear();
      expect(value.intakeIds, {'selected_intake'});
      expect(() => value.intakeIds.add('unexpected'), throwsUnsupportedError);
      expect(
        () => selection(intakes: ['selected_intake', 'selected_intake']),
        throwsFormatException,
      );
      expect(
        () => selection(questions: List.generate(61, (i) => 'q_$i')),
        throwsFormatException,
      );
    },
  );

  test(
    'calendar window retains 23-hour DST day and rejects skipped midnight',
    () {
      final resolver = PersonalLogDateWindowResolver();
      final day = PersonalLogDateWindow(
        start: LogCivilDate(2026, 3, 8),
        endInclusive: LogCivilDate(2026, 3, 8),
        zoneId: 'America/Toronto',
      );
      final result = resolver.resolve(day, asOf: _asOf);
      expect(result.startUtc, DateTime.utc(2026, 3, 8, 5));
      expect(result.endUtcExclusive, DateTime.utc(2026, 3, 9, 4));
      expect(
        result.endUtcExclusive.difference(result.startUtc),
        const Duration(hours: 23),
      );
      expect(
        () => resolver.resolve(
          PersonalLogDateWindow(
            start: LogCivilDate(2011, 12, 30),
            endInclusive: LogCivilDate(2011, 12, 30),
            zoneId: 'Pacific/Apia',
          ),
          asOf: _asOf,
        ),
        throwsFormatException,
      );
    },
  );

  for (final chinese in [false, true]) {
    testWidgets(
      'actual selected ${chinese ? 'Chinese' : 'English'} report exports every frozen page',
      (tester) async {
        await tester.runAsync(() async {
          if (chinese) {
            await state.saveUserProfile(
              state.userProfile.copyWith(displayLocale: 'zh-CN'),
            );
          }
          final owner = state.currentUserId!;
          await state.services.careWorkspaceService.mutate(
            owner,
            (current) => current.copyWith(
              notes: [
                ...current.notes,
                if (chinese)
                  CareDiscussionNote(
                    id: 'selected_multilingual_question',
                    text: '中文所选问题 · سؤال شخصي',
                    recordedAt: DateTime.utc(2026, 9, 30, 14),
                    recorderId: owner,
                  ),
                for (var i = 0; i < 40; i++)
                  CareDiscussionNote(
                    id: 'selected_long_question_$i',
                    text: 'Selected question ${i.toString().padLeft(2, '0')}',
                    recordedAt: DateTime.utc(2026, 9, 30, 15, i),
                    recorderId: owner,
                  ),
              ],
            ),
            authorize: () => state.currentUserId == owner,
          );
          await state.reloadCareWorkspace();
        });
        final chosen = selection(
          questions: state.discussionNotes
              .where((note) => !note.text.contains('UNSELECTED'))
              .map((note) => note.id),
        );
        final report = state.prepareVisit(now: _asOf, selection: chosen);
        final artifact = const PersonalLogHandoffSummaryService()
            .createVisitPreparation(
              report: report,
              selection: chosen,
              sourceLease: state.captureVisitPreparationLease(),
              localeTag: chinese ? 'zh-CN' : 'en-US',
            );
        expect(artifact.plainText, contains('Selected question 00'));
        expect(artifact.plainText, contains('Selected question 39'));
        expect(artifact.plainText, isNot(contains('UNSELECTED')));
        expect(artifact.pages.length, greaterThan(1));
        final html = utf8.decode(
          const PersonalLogHandoffHtmlSerializer().render(artifact),
        );
        expect(
          html,
          contains(
            chinese
                ? '<html lang="zh-Hans" dir="auto">'
                : '<html lang="en" dir="auto">',
          ),
        );
        late BuildContext renderContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                renderContext = context;
                return const SizedBox();
              },
            ),
          ),
        );
        final bytes = await tester.runAsync(
          () => const SystemPersonalLogHandoffTextPdfRenderer().render(
            context: renderContext,
            artifact: artifact,
          ),
        );
        expect(bytes, isNotNull);
        expect(ascii.decode(bytes!.take(5).toList()), '%PDF-');
        final outputDirectory =
            Platform.environment['PARKINSUM_SELECTED_REPORT_ARTIFACT_DIR'];
        if (outputDirectory != null) {
          final id = chinese ? 'selected_zh' : 'selected_en';
          Directory(outputDirectory).createSync(recursive: true);
          final output = File('$outputDirectory/$id.pdf');
          if (output.existsSync()) {
            throw StateError('Retain earlier selected report execution');
          }
          output.writeAsBytesSync(bytes);
          File('$outputDirectory/${id}_frozen_pages.json').writeAsStringSync(
            jsonEncode({
              'language': chinese ? 'zh-Hans' : 'en',
              'pages': artifact.pages.map((page) => page.lines).toList(),
            }),
          );
          File('$outputDirectory/$id.html').writeAsStringSync(html);
        }
      },
    );
  }
}
