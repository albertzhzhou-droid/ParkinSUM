import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_candidate_score.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_scoring_parameters.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

/// D1 — source-quality perturbation. Demonstrates graceful degradation: a
/// candidate's score moves monotonically with its provenance/authority metadata
/// (better provenance never *hurts*), AND — the safety invariant — provenance
/// can never let a worse-conflict candidate outrank a clearly better-conflict
/// one. Conflict overlap stays dominant. Deterministic; tests only.
void main() {
  final scorer = MechanisticNextMealScorer();
  final validator = MedicationEntryValidator();
  final builder = TimeAxisBuilder();

  TimeAxisConflictContext ctx() {
    final now = DateTime.utc(2026, 1, 1, 8);
    final v = validator.validate(const RawMedicationEntry(
      activeIngredients: ['carbidopa', 'levodopa'],
      drugProductVariant: 'synthetic:demo',
      strength: 100,
      unit: 'mg',
      form: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      jurisdiction: 'US',
      sourceDocId: 'synthetic:demo',
    ));
    return builder.build(
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
  }

  CandidateFood food(String id, {required double protein}) => CandidateFood(
        id: id,
        name: id,
        regionalFoodLibraryRef: 'synthetic',
        declaredPhysicalForm: MealPhysicalForm.solid,
        components: [
          FoodComponent(
            id: id,
            name: id,
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: protein,
            fatGrams: 2,
            fiberGrams: 1,
            carbohydrateGrams: 20,
            calories: 150,
            portionGrams: 150,
            sourceDocId: 'synthetic',
          ),
        ],
      );

  CandidateMetadata meta({
    required double authority,
    required double provenance,
    required double completeness,
  }) =>
      CandidateMetadata(
        completeness: completeness,
        authorityScore: authority,
        jurisdictionMatchScore: authority,
        provenanceQuality: provenance,
        jurisdiction: 'US',
      );

  double scoreOf(List<MechanisticCandidateScore> s, String id) =>
      s.firstWhere((e) => e.candidateFoodId == id).finalCandidateScore;

  test('higher source quality never lowers a candidate score (monotonic)', () {
    final c = food('a', protein: 5);
    final low = scorer.score(
      baseContext: ctx(),
      baseMealCompositionsById: const {},
      candidates: [c],
      candidateMetadata: {
        'a': meta(authority: 0.1, provenance: 0.1, completeness: 0.3)
      },
    );
    final high = scorer.score(
      baseContext: ctx(),
      baseMealCompositionsById: const {},
      candidates: [c],
      candidateMetadata: {
        'a': meta(authority: 0.9, provenance: 0.9, completeness: 1.0)
      },
    );
    expect(scoreOf(high, 'a'), greaterThanOrEqualTo(scoreOf(low, 'a')));
  });

  test('provenance influence is bounded below the conflict-overlap weight', () {
    // Two IDENTICAL-composition candidates differing ONLY in source-quality
    // metadata (best vs worst). Provenance breaks the tie in the better
    // candidate's favour, but the score gap it can create must stay bounded by
    // the combined provenance weights — which the conflict-dominant invariant
    // keeps below the conflict-overlap weight. So provenance is a bounded
    // refinement, never the dominant term.
    final best = food('best', protein: 8);
    final worst = food('worst', protein: 8); // identical composition
    final scores = scorer.score(
      baseContext: ctx(),
      baseMealCompositionsById: const {},
      candidates: [best, worst],
      candidateMetadata: {
        'best': meta(authority: 1.0, provenance: 1.0, completeness: 1.0),
        'worst': meta(authority: 0.0, provenance: 0.0, completeness: 0.0),
      },
    );
    final gap = scoreOf(scores, 'best') - scoreOf(scores, 'worst');
    final params = NextMealScoringParameterSet.literatureInformedDefault();
    // Better provenance ranks at least as high (tie-break direction).
    expect(gap, greaterThanOrEqualTo(0.0));
    // ...but the provenance-driven swing cannot exceed the summed provenance
    // weights, which are strictly below the dominant conflict-overlap weight.
    expect(gap, lessThanOrEqualTo(params.provenanceWeightSum + 1e-9));
    expect(params.provenanceWeightSum, lessThan(params.conflictOverlap.value));
  });

  test('deterministic: identical inputs → identical scores', () {
    final c = food('a', protein: 10);
    final m = {'a': meta(authority: 0.5, provenance: 0.5, completeness: 0.8)};
    final r1 = scorer.score(
        baseContext: ctx(),
        baseMealCompositionsById: const {},
        candidates: [c],
        candidateMetadata: m);
    final r2 = scorer.score(
        baseContext: ctx(),
        baseMealCompositionsById: const {},
        candidates: [c],
        candidateMetadata: m);
    expect(scoreOf(r1, 'a'), scoreOf(r2, 'a'));
  });
}
