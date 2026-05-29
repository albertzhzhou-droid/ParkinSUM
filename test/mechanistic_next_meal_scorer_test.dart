import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
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

  test('invalid medication context → every candidate is insufficient_context',
      () {
    final invalid =
        validator.validate(const RawMedicationEntry(freeText: '100'));
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
            id: 'm', takenAt: now, medicationContext: invalid)
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
  });

  test(
      'protein redistribution: high-protein candidate carries higher overlap '
      'penalty and lower redistribution score than low-protein in the same '
      'window (NOT global minimization)', () {
    final v = validator.validate(validLevodopa);
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
            id: 'm',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: v),
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
      candidates: const [proteinShake, banana],
    );
    final bananaScore = scores.firstWhere((s) => s.candidateFoodId == 'banana');
    final shakeScore = scores.firstWhere((s) => s.candidateFoodId == 'shake');
    // The mechanism, not a naive "low protein always wins": the high-protein
    // candidate models at least as much conflict overlap and gets no higher
    // redistribution score than the low-protein candidate in this window.
    expect(shakeScore.conflictOverlapScore,
        greaterThanOrEqualTo(bananaScore.conflictOverlapScore));
    expect(bananaScore.proteinRedistributionScore,
        greaterThanOrEqualTo(shakeScore.proteinRedistributionScore));
    // Both candidates carry a protein-distribution trace and a final score.
    expect(bananaScore.proteinDistribution, isNotNull);
    expect(shakeScore.proteinDistribution, isNotNull);
  });

  test('candidate with missing nutrients has lower confidence', () {
    final v = validator.validate(validLevodopa);
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
            id: 'm',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: v),
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
      candidates: const [banana, unknownNutrients],
    );
    final unknownScore =
        scores.firstWhere((s) => s.candidateFoodId == 'unknown');
    expect(unknownScore.nutritionDataCompleteness, 0.0);
    expect(
      [ConfidenceBand.low, ConfidenceBand.insufficient],
      contains(unknownScore.confidenceBand),
    );
  });

  test('final candidate score drives ordering (composite, not raw overlap)',
      () {
    final v = validator.validate(validLevodopa);
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
            id: 'm',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: v),
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
      candidates: const [proteinShake, banana],
    );
    // Order must be non-increasing in finalCandidateScore.
    for (var i = 1; i < scores.length; i++) {
      expect(scores[i - 1].finalCandidateScore,
          greaterThanOrEqualTo(scores[i].finalCandidateScore));
    }
    // Every scored candidate exposes the composite fields.
    for (final s in scores) {
      expect(s.proteinDistribution, isNotNull);
      expect(s.finalCandidateScore, inInclusiveRange(0.0, 1.0));
    }
  });

  test('default scoring parameter set keeps conflict overlap dominant', () {
    final params = NextMealScoringParameterSet.literatureInformedDefault();
    expect(params.conflictRemainsDominant, isTrue);
    // Conflict weight must not be smaller than the combined provenance weight.
    expect(params.conflictOverlap.value,
        greaterThanOrEqualTo(params.provenanceWeightSum));
    // Each candidate score records which weight set was active.
  });

  test('scoring parameter set is injectable and changes ordering', () {
    final v = validator.validate(validLevodopa);
    final now = DateTime.utc(2026, 1, 1, 8);
    final ctx = builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
            id: 'm',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: v),
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
    final defaultScores = scorer.score(
      baseContext: ctx,
      baseMealCompositionsById: const {},
      candidates: const [proteinShake, banana],
    );
    expect(defaultScores.first.scoringParameterSetId, 'next_meal_scoring.v1');

    // An alternative — but still conflict-dominant — weight set produces a
    // different composite ordering metric → proves the weights are wired in.
    // (We zero the metadata-completeness weight, which defaults to a non-zero
    // neutral 0.5 contribution; conflict overlap stays the dominant term, so
    // the safety invariant still holds.)
    final base = NextMealScoringParameterSet.literatureInformedDefault();
    final altParams = NextMealScoringParameterSet(
      id: 'alt.v0',
      conflictOverlap: base.conflictOverlap,
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
    final altScorer = MechanisticNextMealScorer(scoringParameters: altParams);
    final altScores = altScorer.score(
      baseContext: ctx,
      baseMealCompositionsById: const {},
      candidates: const [proteinShake, banana],
    );
    final defShake =
        defaultScores.firstWhere((s) => s.candidateFoodId == 'shake');
    final altShake = altScores.firstWhere((s) => s.candidateFoodId == 'shake');
    expect(altShake.finalCandidateScore,
        isNot(closeTo(defShake.finalCandidateScore, 1e-9)));
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
}
