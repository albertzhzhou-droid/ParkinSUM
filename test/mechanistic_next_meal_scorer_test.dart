import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_scoring_parameters.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

void main() {
  final validator = MedicationEntryValidator();
  final builder = TimeAxisBuilder();
  final scorer = MechanisticNextMealScorer();

  const validLevodopa = RawMedicationEntry(
    activeIngredients: ['carbidopa', 'levodopa'],
    drugProductVariant: 'synthetic:demo',
    strength: 100,
    unit: 'mg',
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    jurisdiction: 'US',
    sourceDocId: 'synthetic:demo',
  );

  const banana = CandidateFood(
    id: 'banana',
    name: 'banana',
    regionalFoodLibraryRef: 'synthetic',
    declaredPhysicalForm: MealPhysicalForm.solid,
    components: [
      FoodComponent(
        id: 'banana',
        name: 'banana',
        physicalForm: MealPhysicalForm.solid,
        proteinGrams: 1,
        fatGrams: 0,
        fiberGrams: 3,
        carbohydrateGrams: 27,
        calories: 105,
        portionGrams: 120,
        sourceDocId: 'synthetic',
      ),
    ],
  );

  const proteinShake = CandidateFood(
    id: 'shake',
    name: 'shake',
    regionalFoodLibraryRef: 'synthetic',
    declaredPhysicalForm: MealPhysicalForm.liquid,
    components: [
      FoodComponent(
        id: 'shake',
        name: 'shake',
        physicalForm: MealPhysicalForm.liquid,
        proteinGrams: 25,
        fatGrams: 3,
        fiberGrams: 1,
        carbohydrateGrams: 20,
        calories: 220,
        portionGrams: 300,
        sourceDocId: 'synthetic',
      ),
    ],
  );

  const unknownNutrients = CandidateFood(
    id: 'unknown',
    name: 'unknown',
    regionalFoodLibraryRef: 'synthetic',
    declaredPhysicalForm: MealPhysicalForm.unknown,
    components: [
      FoodComponent(
        id: 'unknown',
        name: 'unknown',
        physicalForm: MealPhysicalForm.unknown,
        proteinGrams: null,
        fatGrams: null,
        fiberGrams: null,
        carbohydrateGrams: null,
        calories: null,
        portionGrams: null,
        sourceDocId: 'synthetic',
      ),
    ],
  );

  final doseTimeComposition = MealCompositionNormalizer().normalize(
    mealId: 'dose_time_history',
    components: banana.components,
    declaredPhysicalForm: MealPhysicalForm.solid,
  );

  TimeAxisConflictContext modeledContext(DateTime now) {
    final medication = validator.validate(validLevodopa);
    return builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'm',
          takenAt: now.add(const Duration(minutes: 30)),
          medicationContext: medication,
        ),
      ],
      mealInputs: [
        MealTimelineInput(
          id: 'dose_time_history',
          startedAt: now.subtract(const Duration(minutes: 60)),
          compositionId: doseTimeComposition.id,
          physicalForm: MealPhysicalForm.solid,
        ),
      ],
      userDefinedWindow: UserDefinedMealWindow(
        window: TimelineWindow(
          startMinute: dateTimeToMinute(now) + 60,
          endMinute: dateTimeToMinute(now) + 120,
        ),
        source: 'test',
      ),
    );
  }

  test('missing window → every candidate is insufficient_context', () {
    final v = validator.validate(validLevodopa);
    final ctx = builder.build(
      now: DateTime.utc(2026, 1, 1, 8),
      medicationInputs: [
        MedicationTimelineInput(
          id: 'm',
          takenAt: DateTime.utc(2026, 1, 1, 8),
          medicationContext: v,
        ),
      ],
      mealInputs: const [],
    );
    final scores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: const {},
      candidates: const [banana, proteinShake],
    );
    expect(scores.length, 2);
    expect(scores.every((s) => s.insufficientContext), isTrue);
  });

  test(
    'invalid medication context → every candidate is insufficient_context',
    () {
      final invalid = validator.validate(
        const RawMedicationEntry(freeText: '100'),
      );
      final now = DateTime.utc(2026, 1, 1, 8);
      final ctx = builder.build(
        now: now,
        medicationInputs: [
          MedicationTimelineInput(
            id: 'm',
            takenAt: now,
            medicationContext: invalid,
          ),
        ],
        mealInputs: const [],
        userDefinedWindow: UserDefinedMealWindow(
          window: TimelineWindow(
            startMinute: dateTimeToMinute(now) + 60,
            endMinute: dateTimeToMinute(now) + 120,
          ),
          source: 'test',
        ),
      );
      final scores = scorer.score(
        baseContext: ctx,
        baseMealCompositionsById: const {},
        candidates: const [banana],
      );
      expect(scores.single.insufficientContext, isTrue);
    },
  );

  test(
    'a dropped second dose propagates engine abstention to the candidate',
    () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final valid = validator.validate(validLevodopa);
      final invalid = validator.validate(
        const RawMedicationEntry(freeText: '100'),
      );
      final context = builder.build(
        now: now,
        medicationInputs: [
          MedicationTimelineInput(
            id: 'valid_dose',
            takenAt: now,
            medicationContext: valid,
          ),
          MedicationTimelineInput(
            id: 'invalid_dose',
            takenAt: now.add(const Duration(minutes: 10)),
            medicationContext: invalid,
          ),
        ],
        mealInputs: const [],
        userDefinedWindow: UserDefinedMealWindow(
          window: TimelineWindow(
            startMinute: dateTimeToMinute(now) + 60,
            endMinute: dateTimeToMinute(now) + 120,
          ),
          source: 'test',
        ),
      );

      final score = scorer
          .score(
            baseContext: context,
            baseMealCompositionsById: const {},
            candidates: const [banana],
          )
          .single;

      expect(score.availability, MechanisticResultAvailability.insufficient);
      expect(score.upstreamResult?.availability, score.availability);
      expect(
        score.upstreamResult?.uncertaintyReasons,
        contains('medication.invalid_context(invalid_dose)'),
      );
      expect(score.sampledWindowSummary, isEmpty);
      expect(score.proteinDistribution, isNull);
      expect(score.toJson()['final_candidate_score'], isNull);
    },
  );

  test(
    'first abstained sample stops scoring and preserves all typed states',
    () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final valid = validator.validate(validLevodopa);
      final context = builder.build(
        now: now,
        medicationInputs: [
          MedicationTimelineInput(
            id: 'dose',
            takenAt: now,
            medicationContext: valid,
          ),
        ],
        mealInputs: const [],
        userDefinedWindow: UserDefinedMealWindow(
          window: TimelineWindow(
            startMinute: dateTimeToMinute(now) + 60,
            endMinute: dateTimeToMinute(now) + 120,
          ),
          source: 'test',
        ),
      );

      for (final availability in [
        MechanisticResultAvailability.notApplicable,
        MechanisticResultAvailability.insufficient,
        MechanisticResultAvailability.blockedIntegrity,
      ]) {
        final engine = _AbstainingEngine(availability);
        final score = MechanisticNextMealScorer(engine: engine)
            .score(
              baseContext: context,
              baseMealCompositionsById: const {},
              candidates: const [banana],
            )
            .single;

        expect(engine.callCount, 1, reason: availability.name);
        expect(score.availability, availability);
        expect(score.upstreamResult?.availability, availability);
        expect(score.sampledWindowSummary, isEmpty);
        expect(score.proteinDistribution, isNull);
        expect(score.toJson()['result_availability'], availability.name);
        expect(score.toJson()['final_candidate_score'], isNull);
        expect(
          score.explanation.join(' '),
          contains('synthetic_upstream_abstention'),
        );
      }
    },
  );

  test('protein redistribution: high-protein candidate carries higher overlap '
      'penalty and lower redistribution score than low-protein in the same '
      'window (NOT global minimization)', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = modeledContext(now);
    final scores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: {doseTimeComposition.id: doseTimeComposition},
      candidates: const [proteinShake, banana],
    );
    final bananaScore = scores.firstWhere((s) => s.candidateFoodId == 'banana');
    final shakeScore = scores.firstWhere((s) => s.candidateFoodId == 'shake');
    // The mechanism, not a naive "low protein always wins": the high-protein
    // candidate models at least as much conflict overlap and gets no higher
    // redistribution score than the low-protein candidate in this window.
    expect(
      shakeScore.conflictOverlapScore,
      greaterThanOrEqualTo(bananaScore.conflictOverlapScore),
    );
    expect(
      bananaScore.proteinRedistributionScore,
      greaterThanOrEqualTo(shakeScore.proteinRedistributionScore),
    );
    // Both candidates carry a protein-distribution trace and a final score.
    expect(bananaScore.proteinDistribution, isNotNull);
    expect(shakeScore.proteinDistribution, isNotNull);
  });

  test('candidate with missing nutrients abstains without a zero score', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = modeledContext(now);
    final scores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: {doseTimeComposition.id: doseTimeComposition},
      candidates: const [banana, unknownNutrients],
    );
    final unknownScore = scores.firstWhere(
      (s) => s.candidateFoodId == 'unknown',
    );
    expect(
      unknownScore.availability,
      MechanisticResultAvailability.insufficient,
    );
    expect(unknownScore.hasModeledOutput, isFalse);
    expect(unknownScore.modeledNutritionDataCompleteness, isNull);
    expect(unknownScore.modeledConfidenceBand, isNull);
    expect(unknownScore.toJson()['final_candidate_score'], isNull);
  });

  test(
    'candidate composition ID cannot overwrite a historical meal composition',
    () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final medication = validator.validate(validLevodopa);
      final historical = MealCompositionNormalizer().normalize(
        mealId: 'candidate_banana',
        components: proteinShake.components,
        declaredPhysicalForm: MealPhysicalForm.liquid,
      );
      final context = builder.build(
        now: now,
        medicationInputs: [
          MedicationTimelineInput(
            id: 'dose',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: medication,
          ),
        ],
        mealInputs: [
          MealTimelineInput(
            id: 'history',
            startedAt: now.subtract(const Duration(minutes: 30)),
            compositionId: historical.id,
            physicalForm: MealPhysicalForm.liquid,
          ),
        ],
        userDefinedWindow: UserDefinedMealWindow(
          window: TimelineWindow(
            startMinute: dateTimeToMinute(now) + 60,
            endMinute: dateTimeToMinute(now) + 120,
          ),
          source: 'test',
        ),
      );

      final score = scorer
          .score(
            baseContext: context,
            baseMealCompositionsById: {historical.id: historical},
            candidates: const [banana],
          )
          .single;

      expect(
        score.availability,
        MechanisticResultAvailability.blockedIntegrity,
      );
      expect(score.hasModeledOutput, isFalse);
      expect(score.upstreamResult, isNull);
      expect(
        score.explanation.join(' '),
        contains('candidate_composition_id_collision(candidate_banana)'),
      );
      expect(score.toJson()['final_candidate_score'], isNull);
      expect(score.toJson()['sample_count'], isNull);
    },
  );

  test(
    'final candidate score drives ordering (composite, not raw overlap)',
    () {
      final now = DateTime.utc(2026, 1, 1, 8);
      final ctx = modeledContext(now);
      final scores = scorer.score(
        baseContext: ctx,
        baseMealCompositionsById: {doseTimeComposition.id: doseTimeComposition},
        candidates: const [proteinShake, banana],
      );
      // Order must be non-increasing in finalCandidateScore.
      for (var i = 1; i < scores.length; i++) {
        expect(
          scores[i - 1].finalCandidateScore,
          greaterThanOrEqualTo(scores[i].finalCandidateScore),
        );
      }
      // Every scored candidate exposes the composite fields.
      for (final s in scores) {
        expect(s.proteinDistribution, isNotNull);
        expect(s.finalCandidateScore, inInclusiveRange(0.0, 1.0));
      }
    },
  );

  test('default scoring parameter set keeps conflict overlap dominant', () {
    final params = NextMealScoringParameterSet.literatureInformedDefault();
    expect(params.conflictRemainsDominant, isTrue);
    // Conflict weight must not be smaller than the combined provenance weight.
    expect(
      params.conflictOverlap.value,
      greaterThanOrEqualTo(params.provenanceWeightSum),
    );
    // Each candidate score records which weight set was active.
  });

  test('scoring parameter set is injectable and changes ordering', () {
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = modeledContext(now);
    final defaultScores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: {doseTimeComposition.id: doseTimeComposition},
      candidates: const [proteinShake, banana],
    );
    expect(defaultScores.first.scoringParameterSetId, 'next_meal_scoring.v1');

    // An alternative — but still conflict-dominant — weight set produces a
    // different composite ordering metric → proves the weights are wired in.
    // (We move the metadata-completeness weight into the dominant conflict
    // term. The positive contribution weights remain normalized to one.)
    final base = NextMealScoringParameterSet.literatureInformedDefault();
    final altParams = NextMealScoringParameterSet(
      id: 'alt.v0',
      conflictOverlap: ScoringWeight(
        id: base.conflictOverlap.id,
        label: base.conflictOverlap.label,
        value: 0.55,
        sourceRefs: base.conflictOverlap.sourceRefs,
        evidenceLevel: base.conflictOverlap.evidenceLevel,
        limitation: base.conflictOverlap.limitation,
      ),
      proteinRedistribution: base.proteinRedistribution,
      nutritionAdequacy: base.nutritionAdequacy,
      metadataCompleteness: ScoringWeight(
        id: base.metadataCompleteness.id,
        label: base.metadataCompleteness.label,
        value: 0.0, // drop the metadata-completeness term
        sourceRefs: base.metadataCompleteness.sourceRefs,
        evidenceLevel: base.metadataCompleteness.evidenceLevel,
        limitation: base.metadataCompleteness.limitation,
      ),
      sourceAuthority: base.sourceAuthority,
      jurisdictionMatch: base.jurisdictionMatch,
      provenanceQuality: base.provenanceQuality,
      uncertaintyPenalty: base.uncertaintyPenalty,
    );
    expect(altParams.conflictRemainsDominant, isTrue);
    expect(altParams.isValidForExecution, isTrue);
    final altScorer = MechanisticNextMealScorer(scoringParameters: altParams);
    final altScores = altScorer.score(
      baseContext: ctx,
      baseMealCompositionsById: {doseTimeComposition.id: doseTimeComposition},
      candidates: const [proteinShake, banana],
    );
    final defShake = defaultScores.firstWhere(
      (s) => s.candidateFoodId == 'shake',
    );
    final altShake = altScores.firstWhere((s) => s.candidateFoodId == 'shake');
    expect(
      altShake.finalCandidateScore,
      isNot(closeTo(defShake.finalCandidateScore, 1e-9)),
    );
    expect(altShake.scoringParameterSetId, 'alt.v0');
  });

  test('scorer REJECTS a non-conflict-dominant weight set (ArgumentError)', () {
    final base = NextMealScoringParameterSet.literatureInformedDefault();
    // Conflict overlap weight dropped below the combined provenance weight →
    // provenance/metadata could overpower modeled conflict. Must be rejected.
    final nonDominant = NextMealScoringParameterSet(
      id: 'bad.v0',
      conflictOverlap: ScoringWeight(
        id: base.conflictOverlap.id,
        label: base.conflictOverlap.label,
        value: 0.0,
        sourceRefs: base.conflictOverlap.sourceRefs,
        evidenceLevel: base.conflictOverlap.evidenceLevel,
        limitation: base.conflictOverlap.limitation,
      ),
      proteinRedistribution: base.proteinRedistribution,
      nutritionAdequacy: base.nutritionAdequacy,
      metadataCompleteness: base.metadataCompleteness,
      sourceAuthority: base.sourceAuthority,
      jurisdictionMatch: base.jurisdictionMatch,
      provenanceQuality: base.provenanceQuality,
      uncertaintyPenalty: base.uncertaintyPenalty,
    );
    expect(nonDominant.conflictRemainsDominant, isFalse);
    expect(
      () => MechanisticNextMealScorer(scoringParameters: nonDominant),
      throwsArgumentError,
    );
  });

  test('candidate metadata rejects non-finite and out-of-range scores', () {
    for (final value in [double.nan, double.infinity, -0.01, 1.01]) {
      expect(
        () => CandidateMetadata(
          completeness: value,
          authorityScore: 0.5,
          jurisdictionMatchScore: 0.5,
          provenanceQuality: 0.5,
          jurisdiction: 'synthetic',
        ),
        throwsArgumentError,
        reason: '$value',
      );
    }
  });

  test('scorer rejects every malformed injected weight graph', () {
    final base = NextMealScoringParameterSet.literatureInformedDefault();

    NextMealScoringParameterSet withNutritionWeight(double value) =>
        NextMealScoringParameterSet(
          id: 'synthetic:invalid-$value',
          conflictOverlap: base.conflictOverlap,
          proteinRedistribution: base.proteinRedistribution,
          nutritionAdequacy: ScoringWeight(
            id: base.nutritionAdequacy.id,
            label: base.nutritionAdequacy.label,
            value: value,
            sourceRefs: base.nutritionAdequacy.sourceRefs,
            evidenceLevel: base.nutritionAdequacy.evidenceLevel,
            limitation: base.nutritionAdequacy.limitation,
          ),
          metadataCompleteness: base.metadataCompleteness,
          sourceAuthority: base.sourceAuthority,
          jurisdictionMatch: base.jurisdictionMatch,
          provenanceQuality: base.provenanceQuality,
          uncertaintyPenalty: base.uncertaintyPenalty,
        );

    for (final value in [double.nan, double.infinity, -0.1, 0.2, 1.1]) {
      final malformed = withNutritionWeight(value);
      expect(malformed.validationErrors, isNotEmpty, reason: '$value');
      expect(
        () => MechanisticNextMealScorer(scoringParameters: malformed),
        throwsArgumentError,
        reason: '$value',
      );
    }
  });
}

class _AbstainingEngine extends MechanisticConflictEngine {
  final MechanisticResultAvailability resultAvailability;
  int callCount = 0;

  _AbstainingEngine(this.resultAvailability);

  @override
  MechanisticConflictResult evaluate({
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    String resultId = 'mechanistic_result',
    String? preferredMealId,
  }) {
    callCount += 1;
    const reasons = ['synthetic_upstream_abstention'];
    return switch (resultAvailability) {
      MechanisticResultAvailability.notApplicable =>
        MechanisticConflictResult.notApplicable(
          id: resultId,
          reason: MechanisticInteractionType.insufficientMedicationContext,
          reasonCodes: reasons,
          sourceRefs: const ['synthetic:test'],
        ),
      MechanisticResultAvailability.insufficient =>
        MechanisticConflictResult.insufficientContext(
          id: resultId,
          reason: MechanisticInteractionType.insufficientMealContext,
          missingInputs: reasons,
          sourceRefs: const ['synthetic:test'],
        ),
      MechanisticResultAvailability.blockedIntegrity =>
        MechanisticConflictResult.blockedIntegrity(
          id: resultId,
          reason: MechanisticInteractionType.insufficientMedicationContext,
          integrityReasons: reasons,
          sourceRefs: const ['synthetic:test'],
        ),
      MechanisticResultAvailability.available => throw StateError(
        'The fake engine only produces abstentions.',
      ),
    };
  }
}
