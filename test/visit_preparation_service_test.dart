import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_entry.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_outcome.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_list_review.dart';
import 'package:parkinsum_companion/domain/entities/medication_assertion_reconciliation.dart';
import 'package:parkinsum_companion/domain/entities/visit_preparation.dart';
import 'package:parkinsum_companion/domain/usecases/visit_preparation_service.dart';

void main() {
  const service = VisitPreparationService();
  final generatedAt = DateTime.utc(2026, 9, 22, 12);

  test('discussion provenance preserves the full prompt source budget', () {
    final sources = [
      'prompt:id',
      'rule:id@version',
      ...List.generate(128, (i) => 'source:$i'),
    ];
    final report = service.create(
      generatedAt: generatedAt,
      snapshot: VisitPreparationSnapshot(
        activeDrugIds: [],
        medicationCatalog: [],
        intakes: [],
        discussionItems: [
          VisitDiscussionItem(
            label: 'Review',
            status: 'Unread',
            sourceIds: sources,
          ),
        ],
      ),
    );
    expect(report.discussionItems.single.sourceIds, sources);
    expect(report.plainText, contains('source:127'));
  });

  VisitPreparationReport report({
    List<String> active = const ['a'],
    List<DrugDefinition>? catalog,
    List<Intake> intakes = const [],
    List<VisitDiscussionItem> discussionItems = const [],
    List<VisitObservationSummary> observations = const [],
    Set<String>? includedObservationIds,
    List<CareMedicationDiscussionEntry> medicationDiscussionEntries = const [],
    List<CareMedicationDiscussionOutcome> medicationDiscussionOutcomes =
        const [],
    List<CareMedicationListReview> medicationListReviews = const [],
    List<VisitMedicationAssertionReview> medicationAssertionReviews = const [],
    int unreviewedMedicationAssertionIntakeCount = 0,
    List<String> userNotes = const [],
    DateTime? activeSelectionUpdatedAt,
    bool chinese = true,
  }) => service.create(
    snapshot: VisitPreparationSnapshot(
      activeDrugIds: active,
      medicationCatalog: catalog ?? [_drug('a'), _drug('b')],
      intakes: intakes,
      discussionItems: discussionItems,
      observations: observations,
      includedObservationIds: includedObservationIds,
      medicationDiscussionEntries: medicationDiscussionEntries,
      medicationDiscussionOutcomes: medicationDiscussionOutcomes,
      medicationListReviews: medicationListReviews,
      medicationAssertionReviews: medicationAssertionReviews,
      unreviewedMedicationAssertionIntakeCount:
          unreviewedMedicationAssertionIntakeCount,
      userNotes: userNotes,
      activeSelectionUpdatedAt: activeSelectionUpdatedAt,
    ),
    generatedAt: generatedAt,
    chinese: chinese,
  );

  test('report keeps category self-check owner-reported and time-bounded', () {
    final reviewedAt = generatedAt.subtract(const Duration(hours: 1));
    final futureAt = generatedAt.add(const Duration(seconds: 1));
    final result = report(
      active: [],
      medicationListReviews: [
        CareMedicationListReview(
          section: CareMedicationListReviewSection.currentSelection,
          recordedAt: reviewedAt,
          recorderId: 'local-account',
        ),
        CareMedicationListReview(
          section: CareMedicationListReviewSection.overTheCounter,
          recordedAt: futureAt,
          recorderId: 'local-account',
        ),
      ],
      chinese: false,
    );

    final current = result.medicationListReviewStatuses.singleWhere(
      (status) =>
          status.section == CareMedicationListReviewSection.currentSelection,
    );
    final otc = result.medicationListReviewStatuses.singleWhere(
      (status) =>
          status.section == CareMedicationListReviewSection.overTheCounter,
    );
    expect(current.recordedAt, reviewedAt);
    expect(otc.recordedAt, isNull);
    expect(result.excludedFutureRecordCount, 1);
    expect(
      result.plainText,
      contains('Account-holder medication-list self-check'),
    );
    expect(result.plainText, contains('Marked reviewed by account holder'));
    expect(result.plainText, contains('does not prove completeness, accuracy'));
    expect(
      result.plainText,
      contains('the catalog and history may be incomplete'),
    );
    expect(
      result.agendaText,
      contains('Medication list self-check (owner-reported)'),
    );
  });

  test(
    'manual OTC and supplement items appear as unverified discussion evidence',
    () {
      final entry = CareMedicationDiscussionEntry(
        id: 'account-entry-1',
        name: 'Synthetic herbal product',
        category: CareMedicationDiscussionCategory.overTheCounter,
        reportedUse: CareMedicationReportedUse.reportedCurrent,
        ingredientLabel: 'Example Ingredient A',
        doseAndScheduleText: 'unknown; bring the container',
        question: 'Could the ingredient list matter?',
        recordedAt: generatedAt.subtract(const Duration(hours: 2)),
        recorderId: 'local-account',
      );
      final result = report(
        active: [],
        medicationDiscussionEntries: [entry],
        chinese: false,
      );

      expect(result.medicationDiscussionEntries.single.id, entry.id);
      expect(result.plainText, contains('Synthetic herbal product'));
      expect(result.plainText, contains('Over-the-counter medicine'));
      expect(result.plainText, contains('Reported current'));
      expect(result.plainText, contains('unknown; bring the container'));
      expect(result.plainText, contains('Could the ingredient list matter?'));
      expect(result.plainText, contains('Example Ingredient A'));
      expect(result.plainText, contains('not matched to a medication catalog'));
      expect(result.plainText, contains('not used by rule evaluation'));
    },
  );

  test('future-dated medication discussion entries are not backfilled', () {
    final future = CareMedicationDiscussionEntry(
      id: 'future-account-entry',
      name: 'Future entry',
      category: CareMedicationDiscussionCategory.supplement,
      reportedUse: CareMedicationReportedUse.uncertain,
      doseAndScheduleText: null,
      question: null,
      recordedAt: generatedAt.add(const Duration(seconds: 1)),
      recorderId: 'local-account',
    );
    final result = report(active: [], medicationDiscussionEntries: [future]);

    expect(result.medicationDiscussionEntries, isEmpty);
    expect(result.excludedFutureRecordCount, 1);
    expect(result.plainText, isNot(contains('Future entry')));
  });

  test(
    'visit report carries bounded unresolved source assertions for review',
    () {
      final reviewTime = generatedAt.subtract(const Duration(days: 2));
      final review = VisitMedicationAssertionReview(
        intakeId: 'intake-source-conflict',
        drugId: 'a',
        intakeOccurredAt: reviewTime,
        sourceAssertions: [
          VisitMedicationAssertionSource(
            assertionId: 'assertion-local',
            evidenceClass:
                MedicationAssertionEvidenceClass.localUserConfirmation,
            status: MedicationAssertionStatus.taken,
            lifecycle: MedicationAssertionLifecycle.active,
            doseValue: 100,
            doseUnit: 'mg',
            effectiveStart: reviewTime,
            effectiveEnd: reviewTime,
            timePrecision: MedicationAssertionTimePrecision.exact,
            recordedAt: reviewTime.add(const Duration(minutes: 1)),
          ),
          VisitMedicationAssertionSource(
            assertionId: 'assertion-portal',
            evidenceClass: MedicationAssertionEvidenceClass.importedStatement,
            status: MedicationAssertionStatus.unknown,
            lifecycle: MedicationAssertionLifecycle.active,
            sourceDisplayLabel: 'Patient portal import',
            doseValue: 50,
            doseUnit: 'mg',
            effectiveStart: reviewTime,
            effectiveEnd: reviewTime,
            timePrecision: MedicationAssertionTimePrecision.exact,
            recordedAt: reviewTime.add(const Duration(minutes: 2)),
          ),
        ],
        blockingConflicts: [
          VisitMedicationAssertionConflict(
            edgeId: 'edge-dose-conflict',
            fromAssertionId: 'assertion-local',
            toAssertionId: 'assertion-portal',
            relationship: 'doseConflict',
            reasonCode: 'assertion_graph.dose_conflict',
          ),
        ],
        integrityFindings: [],
        staleDecisionCount: 0,
        reviewResolution:
            MedicationReconciliationResolution.confirmedNoConflict,
        reviewReasonCode: 'user.reviewed_no_conflict',
        reviewRecordedAt: reviewTime.add(const Duration(minutes: 3)),
      );

      final result = report(medicationAssertionReviews: [review]);

      expect(result.medicationAssertionReviews, hasLength(1));
      expect(result.plainText, contains('Patient portal import'));
      expect(result.plainText, contains('本人确认'));
      expect(result.plainText, contains('100 mg'));
      expect(result.plainText, contains('50 mg'));
      expect(result.plainText, contains('剂量冲突'));
      expect(result.plainText, contains('本人记录为未发现冲突；来源关系仍保留'));
      expect(result.plainText, contains('本人确认已查看也不会消除冲突'));
      expect(result.plainText, isNot(contains('clinically reconciled')));
    },
  );

  test('visit report names omitted source-review records at its limits', () {
    final reviews = List.generate(33, (index) {
      final id = 'review-$index';
      final eventTime = generatedAt.subtract(Duration(minutes: index + 1));
      VisitMedicationAssertionSource source(String suffix) =>
          VisitMedicationAssertionSource(
            assertionId: '$id-$suffix',
            evidenceClass: MedicationAssertionEvidenceClass.userStatement,
            status: MedicationAssertionStatus.unknown,
            lifecycle: MedicationAssertionLifecycle.active,
            recordedAt: eventTime,
            timePrecision: MedicationAssertionTimePrecision.unknown,
          );
      return VisitMedicationAssertionReview(
        intakeId: 'intake-$id',
        drugId: 'a',
        intakeOccurredAt: eventTime,
        sourceAssertions: [source('left'), source('right')],
        blockingConflicts: [
          VisitMedicationAssertionConflict(
            edgeId: 'edge-$id',
            fromAssertionId: '$id-left',
            toAssertionId: '$id-right',
            relationship: 'doseConflict',
            reasonCode: 'assertion_graph.dose_conflict',
          ),
        ],
        integrityFindings: [],
        staleDecisionCount: 0,
      );
    });

    final result = report(
      active: [],
      medicationAssertionReviews: reviews,
      unreviewedMedicationAssertionIntakeCount: 4,
      chinese: false,
    );

    expect(result.medicationAssertionReviews, hasLength(32));
    expect(result.omittedMedicationAssertionReviewCount, 1);
    expect(result.unreviewedMedicationAssertionIntakeCount, 4);
    expect(
      result.plainText,
      contains(
        'Additional intake records with identified source issues not displayed: 1',
      ),
    );
    expect(
      result.plainText,
      contains('source graphs were not checked for 4 older intake records'),
    );
  });

  test(
    'visit report shows the latest owner update and excludes future outcomes',
    () {
      final entry = CareMedicationDiscussionEntry(
        id: 'discussion-entry',
        name: 'Example supplement',
        category: CareMedicationDiscussionCategory.supplement,
        reportedUse: CareMedicationReportedUse.uncertain,
        doseAndScheduleText: null,
        question: 'Ask about the label.',
        recordedAt: generatedAt.subtract(const Duration(days: 1)),
        recorderId: 'local-account',
      );
      final outcomes = [
        CareMedicationDiscussionOutcome(
          id: 'outcome-1',
          entryId: entry.id,
          status: CareMedicationDiscussionOutcomeStatus.discussed,
          note: 'Owner says this was discussed.',
          recordedAt: generatedAt.subtract(const Duration(hours: 1)),
          recorderId: 'local-account',
        ),
        CareMedicationDiscussionOutcome(
          id: 'outcome-2',
          entryId: entry.id,
          status: CareMedicationDiscussionOutcomeStatus.followUpNeeded,
          note: 'Owner says one question remains.',
          recordedAt: generatedAt,
          recorderId: 'local-account',
        ),
        CareMedicationDiscussionOutcome(
          id: 'outcome-future',
          entryId: entry.id,
          status:
              CareMedicationDiscussionOutcomeStatus.followUpReportedComplete,
          note: 'Future update.',
          recordedAt: generatedAt.add(const Duration(seconds: 1)),
          recorderId: 'local-account',
        ),
      ];
      final result = report(
        active: [],
        medicationDiscussionEntries: [entry],
        medicationDiscussionOutcomes: outcomes,
        chinese: false,
      );

      expect(result.latestMedicationDiscussionOutcomes, hasLength(1));
      expect(
        result.latestMedicationDiscussionOutcomes.single.status,
        CareMedicationDiscussionOutcomeStatus.followUpNeeded,
      );
      expect(result.excludedFutureRecordCount, 1);
      expect(result.plainText, contains('Owner says one question remains.'));
      expect(result.plainText, isNot(contains('Future update.')));
      expect(result.plainText, contains('not clinician-verified'));
    },
  );

  test(
    'only explicit selections are current, regardless of intake recency',
    () {
      final result = report(
        active: ['a', 'missing'],
        intakes: [_intake('history', 'b')],
      );
      expect(result.currentMedications.map((row) => row.drugId), [
        'a',
        'missing',
      ]);
      expect(result.historicalMedications.single.drugId, 'b');
      expect(result.currentMedications.first.latestIntake, isNull);
      expect(result.currentMedications.last.displayName, '未知药品 (missing)');
      expect(result.historicalMedications.single.isCurrentSelection, isFalse);
      expect(result.plainText, contains('不视为当前用药'));
      expect(result.plainText, contains('是否已停用或只是未选择'));
    },
  );

  test(
    'checks only explicit equal ingredient fields on active latest evidence',
    () {
      final result = report(
        active: ['a', 'b', 'c', 'd', 'e'],
        catalog: [
          for (final id in ['a', 'b', 'c', 'd', 'e']) _drug(id),
        ],
        intakes: [
          _intake('a1', 'a', ingredient: '  Levodopa  '),
          _intake('b1', 'b', ingredient: 'levodopa'),
          _intake('c1', 'c', ingredient: 'levodopa hydrochloride'),
          _intake('d1', 'd', ingredient: 'levodopa / carbidopa'),
          _intake('e1', 'e'),
          _intake('past1', 'past', ingredient: 'levodopa'),
        ],
      );
      final check = result.duplicateIngredientChecks.single;
      expect(check.ingredientName, 'levodopa');
      expect(check.drugIds, ['a', 'b']);
      expect(check.sourceIds, ['intake:a1', 'intake:b1']);
      expect(check.message, '请核对是否同一药品');
      expect(result.plainText, contains('不代表重复用药或危险'));
    },
  );

  test(
    'user-entered ingredient labels produce only a literal review prompt',
    () {
      final entry = CareMedicationDiscussionEntry(
        id: 'account-entry-ingredient',
        name: 'Synthetic supplement',
        category: CareMedicationDiscussionCategory.supplement,
        reportedUse: CareMedicationReportedUse.uncertain,
        ingredientLabel: 'example   ingredient a',
        doseAndScheduleText: null,
        question: null,
        recordedAt: generatedAt.subtract(const Duration(minutes: 1)),
        recorderId: 'local-account',
      );
      final result = report(
        active: ['a'],
        intakes: [
          _intake('active-intake', 'a', ingredient: 'Example Ingredient A'),
        ],
        medicationDiscussionEntries: [entry],
        chinese: false,
      );

      expect(result.duplicateIngredientChecks, isEmpty);
      expect(result.unverifiedIngredientLabelMatches, hasLength(1));
      expect(result.unverifiedIngredientLabelMatches.single.labels, [
        'Example Ingredient A',
        'example   ingredient a',
      ]);
      expect(result.unverifiedIngredientLabelMatches.single.sourceIds, [
        'care-medication:account-entry-ingredient',
        'intake:active-intake',
      ]);
      expect(result.plainText, contains('check manually'));
      expect(result.plainText, contains('does not verify ingredient'));
    },
  );

  test('identical labels keep one spelling and every source', () {
    final entry = CareMedicationDiscussionEntry(
      id: 'exact-label-entry',
      name: 'Example product',
      category: CareMedicationDiscussionCategory.supplement,
      reportedUse: CareMedicationReportedUse.uncertain,
      ingredientLabel: 'Example Ingredient A',
      doseAndScheduleText: null,
      question: null,
      recordedAt: generatedAt,
      recorderId: 'local-account',
    );
    final result = report(
      active: ['a'],
      intakes: [
        _intake('active-intake', 'a', ingredient: 'Example Ingredient A'),
      ],
      medicationDiscussionEntries: [entry],
    );

    expect(result.unverifiedIngredientLabelMatches.single.labels, [
      'Example Ingredient A',
    ]);
    expect(result.unverifiedIngredientLabelMatches.single.sourceIds, [
      'care-medication:exact-label-entry',
      'intake:active-intake',
    ]);
  });

  test('ingredient aliases and unknown placeholders are not matched', () {
    final entries = [
      for (final (id, label) in [
        ('alias', 'Example-Ingredient A'),
        ('unknown', 'unknown'),
      ])
        CareMedicationDiscussionEntry(
          id: 'entry-$id',
          name: 'Synthetic item $id',
          category: CareMedicationDiscussionCategory.supplement,
          reportedUse: CareMedicationReportedUse.uncertain,
          ingredientLabel: label,
          doseAndScheduleText: null,
          question: null,
          recordedAt: generatedAt,
          recorderId: 'local-account',
        ),
    ];
    final result = report(
      active: ['a'],
      intakes: [
        _intake('active-intake', 'a', ingredient: 'Example Ingredient A'),
      ],
      medicationDiscussionEntries: entries,
    );

    expect(result.unverifiedIngredientLabelMatches, isEmpty);
  });

  test('ingredient-label matching remains bounded at the workspace limits', () {
    final activeIds = List.generate(128, (index) => 'drug-$index');
    final intakes = [
      for (final (index, id) in activeIds.indexed)
        _intake('intake-$index', id, ingredient: 'Example Ingredient A'),
    ];
    final entries = [
      for (var index = 0; index < 128; index++)
        CareMedicationDiscussionEntry(
          id: 'entry-$index',
          name: 'Example product $index',
          category: CareMedicationDiscussionCategory.supplement,
          reportedUse: CareMedicationReportedUse.uncertain,
          ingredientLabel: 'example ingredient a',
          doseAndScheduleText: null,
          question: null,
          recordedAt: generatedAt,
          recorderId: 'local-account',
        ),
    ];
    final result = report(
      active: activeIds,
      catalog: activeIds.map(_drug).toList(),
      intakes: intakes,
      medicationDiscussionEntries: entries,
    );

    expect(result.unverifiedIngredientLabelMatches, hasLength(1));
    expect(
      result.unverifiedIngredientLabelMatches.single.sourceIds,
      hasLength(256),
    );
  });

  test(
    'generic labels and older product snapshots do not establish ingredients',
    () {
      final result = report(
        active: ['a', 'b'],
        catalog: [
          _drug('a', name: 'Levodopa'),
          _drug('b', name: 'Levodopa'),
        ],
        intakes: [
          _intake('old-a', 'a', ingredient: 'Levodopa', day: 18),
          _intake('new-a', 'a', day: 20),
          _intake('new-b', 'b', ingredient: 'Levodopa', day: 20),
        ],
      );
      expect(result.duplicateIngredientChecks, isEmpty);
      expect(result.currentMedications.first.latestIntake!.id, 'new-a');
      expect(
        result.currentMedications.first.latestIntake!.doseBasisIngredient,
        isNull,
      );
      expect(result.missingInformation.join(' '), contains('未参与成分名称核对'));
    },
  );

  test(
    'unknowns and source times remain explicit; future evidence is excluded',
    () {
      final result = report(
        intakes: [
          _intake('now', 'a', dose: ''),
          _intake('future', 'b', day: 23),
        ],
        discussionItems: [
          VisitDiscussionItem(label: '睡眠问题', status: '待讨论'),
          VisitDiscussionItem(
            label: '未来事项',
            status: '待讨论',
            recordedAt: DateTime.utc(2026, 9, 23),
          ),
        ],
        observations: [
          VisitObservationSummary(label: '用户观察', summary: '未注明时间'),
        ],
      );
      expect(result.currentMedications.single.selectionUpdatedAt, isNull);
      expect(result.currentMedications.single.latestIntake!.doseNote, isNull);
      expect(
        result.currentMedications.single.latestIntake!.takenAt,
        DateTime.utc(2026, 9, 20, 10),
      );
      expect(result.excludedFutureRecordCount, 2);
      expect(result.historicalMedications, isEmpty);
      expect(result.plainText, contains('当前选择更新时间：未知'));
      expect(result.plainText, contains('历史剂量记录：未知'));
      expect(result.plainText, contains('原始时区未保留'));
      expect(result.plainText, contains('2026-09-20T10:00:00.000Z'));
      expect(result.plainText, isNot(contains('未来事项')));
    },
  );

  test('reordering inputs produces stable output including provenance', () {
    final a = _intake('a1', 'a', ingredient: 'levodopa');
    final b = _intake('b1', 'b', ingredient: 'Levodopa');
    VisitDiscussionItem discussion(List<String> sources) =>
        VisitDiscussionItem(label: '核对补充剂', status: '待核实', sourceIds: sources);
    final first = report(
      active: ['a', 'b'],
      intakes: [a, b],
      discussionItems: [
        discussion(['source-b', 'source-a']),
      ],
      userNotes: ['维生素记录不完整', '希望讨论睡眠'],
    );
    final second = report(
      active: ['b', 'a'],
      catalog: [_drug('b'), _drug('a')],
      intakes: [b, a],
      discussionItems: [
        discussion(['source-a', 'source-b']),
      ],
      userNotes: ['希望讨论睡眠', '维生素记录不完整'],
    );
    expect(first.plainText, second.plainText);
    expect(first.plainText, contains('维生素记录不完整'));
    expect(first.plainText, contains('仍待核实'));
  });

  test('backfilled observations retain distinct occurrence and entry times', () {
    final occurredAt = DateTime.parse('2026-09-20T08:15:00-04:00');
    final recordedAt = DateTime.parse('2026-09-21T09:30:00-04:00');
    final observations = [
      VisitObservationSummary(
        label: 'Backfilled',
        summary: 'User observation',
        occurredAt: occurredAt,
        recordedAt: recordedAt,
      ),
      VisitObservationSummary(
        label: 'Occurrence only',
        summary: 'User observation',
        occurredAt: occurredAt,
      ),
      VisitObservationSummary(
        label: 'Entry only',
        summary: 'User observation',
        recordedAt: recordedAt,
      ),
      VisitObservationSummary(label: 'No times', summary: 'User observation'),
    ];
    final chinese = report(observations: observations);
    final english = report(observations: observations, chinese: false);
    final backfilled = chinese.observations.first;
    expect(backfilled.occurredAt, DateTime.utc(2026, 9, 20, 12, 15));
    expect(backfilled.recordedAt, DateTime.utc(2026, 9, 21, 13, 30));
    expect(backfilled.occurredAt!.isUtc, isTrue);
    expect(backfilled.recordedAt!.isUtc, isTrue);
    expect(
      chinese.plainText,
      contains('发生时间：2026-09-20T12:15:00.000Z; 录入时间：2026-09-21T13:30:00.000Z'),
    );
    expect(
      english.plainText,
      contains(
        'Occurred at: 2026-09-20T12:15:00.000Z; Recorded at: 2026-09-21T13:30:00.000Z',
      ),
    );
    expect(
      chinese.plainText,
      contains('发生时间：2026-09-20T12:15:00.000Z; 录入时间：未知'),
    );
    expect(
      english.plainText,
      contains('Occurred at: Unknown; Recorded at: 2026-09-21T13:30:00.000Z'),
    );
    expect(chinese.plainText, contains('发生时间：未知; 录入时间：未知'));
    expect(
      english.plainText,
      contains('Occurred at: Unknown; Recorded at: Unknown'),
    );
  });

  test('concise agenda bounds each section and points to full evidence', () {
    final occurredAt = DateTime.utc(2026, 9, 20, 12, 15);
    final recordedAt = DateTime.utc(2026, 9, 21, 13, 30);
    final discussions = [
      for (final label in ['Question one', 'Question two', 'Question three'])
        VisitDiscussionItem(
          label: label,
          status: 'To review',
          sourceIds: ['prompt:$label', 'rule:synthetic@1'],
          recordedAt: recordedAt,
        ),
    ];
    final observations = [
      for (final label in [
        'Observation one',
        'Observation two',
        'Observation three',
      ])
        VisitObservationSummary(
          label: label,
          summary: 'Synthetic observation summary',
          occurredAt: occurredAt,
          recordedAt: recordedAt,
          sourceIds: ['observation:$label'],
        ),
    ];
    final result = report(
      active: ['a', 'b', 'c'],
      catalog: [_drug('a'), _drug('b'), _drug('c')],
      discussionItems: discussions,
      observations: observations,
      userNotes: [
        'Question note one',
        'Question note two',
        'Question note three',
      ],
      activeSelectionUpdatedAt: generatedAt.subtract(const Duration(days: 1)),
    );

    expect(result.agendaText, contains('就诊沟通摘要（简版）'));
    expect(result.agendaText, contains('Medicine a'));
    expect(result.agendaText, contains('Medicine b'));
    expect(result.agendaText, isNot(contains('Medicine c')));
    expect(result.agendaText, contains('另有 1 项未在摘要中展示'));
    expect(result.agendaText, contains('发生: 2026-09-20T12:15:00.000Z'));
    expect(result.agendaText, contains('录入: 2026-09-21T13:30:00.000Z'));
    expect(result.agendaText, contains('另有 1 项未在摘要中展示；详见下方清单。'));
    expect(result.agendaText, contains('摘要为便于沟通而缩短'));
    expect(result.plainText, contains('Medicine c'));
    expect(result.plainText, contains('Question three'));
    expect(result.plainText, contains('Question note three'));
    expect(result.agendaText.length, lessThan(5000));

    final english = report(
      active: [],
      observations: observations.take(1).toList(),
      chinese: false,
    );
    expect(english.agendaText, contains('Visit discussion summary (concise)'));
    expect(english.agendaText, contains('Occurred: 2026-09-20T12:15:00.000Z'));
    expect(english.agendaText, contains('Recorded: 2026-09-21T13:30:00.000Z'));
  });

  test('either future observation time excludes a record exactly once', () {
    final future = generatedAt.add(const Duration(seconds: 1));
    final result = report(
      observations: [
        VisitObservationSummary(
          label: 'Future occurrence',
          summary: 'User observation',
          occurredAt: future,
        ),
        VisitObservationSummary(
          label: 'Future entry',
          summary: 'User observation',
          recordedAt: future,
        ),
        VisitObservationSummary(
          label: 'Both future',
          summary: 'User observation',
          occurredAt: future,
          recordedAt: future,
        ),
        VisitObservationSummary(
          label: 'At report time',
          summary: 'User observation',
          occurredAt: generatedAt,
          recordedAt: generatedAt,
        ),
      ],
    );
    expect(result.excludedFutureRecordCount, 3);
    expect(result.observations.single.label, 'At report time');
    expect(result.plainText, isNot(contains('Future occurrence')));
    expect(result.plainText, isNot(contains('Future entry')));
    expect(result.plainText, isNot(contains('Both future')));
  });

  test('report selection is temporary and counts only eligible omissions', () {
    final future = generatedAt.add(const Duration(seconds: 1));
    final result = report(
      observations: [
        VisitObservationSummary(
          label: 'Selected observation',
          summary: 'Owner-entered summary',
          sourceRecordId: 'observation-selected',
          occurredAt: generatedAt,
        ),
        VisitObservationSummary(
          label: 'Unselected observation',
          summary: 'Owner-entered summary',
          sourceRecordId: 'observation-unselected',
          occurredAt: generatedAt,
        ),
        VisitObservationSummary(
          label: 'Future observation',
          summary: 'Owner-entered summary',
          sourceRecordId: 'observation-future',
          recordedAt: future,
        ),
      ],
      includedObservationIds: {'observation-selected', 'observation-future'},
      chinese: false,
    );

    expect(result.observations.map((item) => item.label), [
      'Selected observation',
    ]);
    expect(result.omittedObservationCount, 1);
    expect(result.excludedFutureRecordCount, 1);
    expect(
      result.plainText,
      contains('This selection applies only to this report'),
    );
    expect(
      result.plainText,
      contains('unselected records remain stored locally'),
    );
    expect(result.plainText, contains('Excluded by this report selection: 1'));
    expect(result.agendaText, contains('1 excluded'));
  });

  test(
    'observation ordering includes both occurrence and entry timestamps',
    () {
      VisitObservationSummary observation(int occurredDay, int recordedDay) =>
          VisitObservationSummary(
            label: 'Observation',
            summary: 'Same summary',
            occurredAt: DateTime.utc(2026, 9, occurredDay),
            recordedAt: DateTime.utc(2026, 9, recordedDay),
            sourceIds: ['same-source'],
          );
      final observations = [
        observation(21, 22),
        observation(20, 22),
        observation(20, 21),
      ];
      final first = report(observations: observations);
      final reversed = report(observations: observations.reversed.toList());
      expect(first.plainText, reversed.plainText);
      expect(
        first.observations.map(
          (item) => [item.occurredAt!.day, item.recordedAt!.day],
        ),
        [
          [20, 21],
          [20, 22],
          [21, 22],
        ],
      );
    },
  );

  test('snapshots and all report collections are immutable', () {
    final ids = ['a'];
    final catalog = [_drug('a')];
    final notes = ['用户问题'];
    final snapshot = VisitPreparationSnapshot(
      activeDrugIds: ids,
      medicationCatalog: catalog,
      intakes: [],
      userNotes: notes,
    );
    ids.add('b');
    catalog.clear();
    notes.clear();
    final result = service.create(snapshot: snapshot, generatedAt: generatedAt);
    expect(result.currentMedications.single.drugId, 'a');
    expect(result.currentMedications.single.displayName, 'Medicine a');
    expect(result.userNotes, ['用户问题']);
    expect(() => result.currentMedications.clear(), throwsUnsupportedError);
    expect(
      () => result.currentMedications.single.fieldsToConfirm.clear(),
      throwsUnsupportedError,
    );
    expect(() => snapshot.activeDrugIds.clear(), throwsUnsupportedError);
  });

  test(
    'bounded inputs reject excess and duplicate IDs rather than overwrite',
    () {
      expect(
        () => report(active: List.generate(129, (index) => 'drug-$index')),
        throwsArgumentError,
      );
      expect(
        () => report(catalog: [_drug('a'), _drug('a')]),
        throwsArgumentError,
      );
      expect(
        () => report(intakes: [_intake('id', 'a'), _intake('id', 'b')]),
        throwsArgumentError,
      );
      expect(
        () => report(userNotes: ['x' * (visitPreparationMaxTextLength + 1)]),
        throwsArgumentError,
      );
      expect(
        () => report(activeSelectionUpdatedAt: DateTime.utc(2026, 9, 23)),
        throwsArgumentError,
      );
    },
  );

  test('historical output has an explicit bounded omission count', () {
    final result = report(
      active: [],
      catalog: [],
      intakes: [for (var i = 0; i < 130; i++) _intake('i$i', 'drug-$i')],
    );
    expect(result.currentMedications, isEmpty);
    expect(result.historicalMedications.length, 128);
    expect(result.omittedHistoricalMedicationCount, 2);
    expect(result.plainText, contains('历史药品另有 2 项未展示'));
  });

  test(
    'English rendering covers fixed text, unknowns, and confirmation fields',
    () {
      final result = service.create(
        snapshot: VisitPreparationSnapshot(
          activeDrugIds: ['a', 'b', 'missing'],
          medicationCatalog: [_drug('a'), _drug('b')],
          intakes: [
            _intake('a1', 'a', ingredient: 'Levodopa'),
            _intake('b1', 'b', ingredient: 'levodopa'),
            _intake('old1', 'old'),
            _intake('future', 'future', day: 23),
          ],
          discussionItems: [
            VisitDiscussionItem(
              label: 'Review this item',
              status: 'Needs review',
              reason: '${'e' * 8000}${'r' * 2000}',
            ),
          ],
          observations: [
            VisitObservationSummary(
              label: 'Observation',
              summary: 'Reported stiffness',
            ),
          ],
          userNotes: ['Check my supplement list.'],
        ),
        generatedAt: generatedAt,
        chinese: false,
      );
      final chineseCharacters = RegExp(r'[\u3400-\u9fff]');
      expect(chineseCharacters.hasMatch(result.plainText), isFalse);
      expect(
        result.currentMedications
            .expand((row) => row.fieldsToConfirm)
            .any(chineseCharacters.hasMatch),
        isFalse,
      );
      expect(
        result.missingInformation.any(chineseCharacters.hasMatch),
        isFalse,
      );
      expect(
        result.plainText,
        contains('Current selection updated at: Unknown'),
      );
      expect(
        result.plainText,
        contains('Please check whether these refer to the same medicine'),
      );
      expect(
        result.plainText,
        contains('does not establish duplicate medication use or danger'),
      );
      expect(
        result.plainText,
        contains('Records later than report generation excluded: 1.'),
      );
      expect(result.plainText, contains('e' * 8000));
    },
  );

  test(
    'English empty and bounded-history notices contain no fixed Chinese',
    () {
      final result = service.create(
        snapshot: VisitPreparationSnapshot(
          activeDrugIds: [],
          medicationCatalog: [],
          intakes: [for (var i = 0; i < 130; i++) _intake('i$i', 'drug-$i')],
        ),
        generatedAt: generatedAt,
        chinese: false,
      );
      expect(RegExp(r'[\u3400-\u9fff]').hasMatch(result.plainText), isFalse);
      expect(
        result.plainText,
        contains('2 additional historical medicines are not displayed.'),
      );
      expect(
        result.plainText,
        contains('No identical explicit ingredient names found for review'),
      );
    },
  );
}

DrugDefinition _drug(String id, {String? name}) => DrugDefinition(
  id: id,
  genericName: name ?? 'Medicine $id',
  brandNames: [],
  tags: [],
  notes: '',
  sourceSystem: 'TEST_CATALOG',
);

Intake _intake(
  String id,
  String drugId, {
  String? ingredient,
  String dose = 'one recorded tablet',
  int day = 20,
}) => Intake(
  id: id,
  drugId: drugId,
  takenAt: DateTime.utc(2026, 9, day, 10),
  dosageNote: dose,
  productSelection: ingredient == null
      ? null
      : MedicationProductSelection(
          packId: 'pack-$drugId',
          identifierSystem: 'DIN',
          identifierValue: drugId,
          displayName: 'Recorded product $drugId',
          labelerName: null,
          strengthDisplay: '',
          packageDescription: '',
          doseBasisIngredient: ingredient,
        ),
);
