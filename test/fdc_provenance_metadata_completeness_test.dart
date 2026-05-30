import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/nutrient_derivation.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_candidate_score.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/metadata_completeness_gate.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

/// P5 — FDC nutrient provenance tier → FoodVariantMetadata + completeness +
/// ranking. Verifies the tier is explicit/serializable on the metadata, that the
/// completeness gate orders analytical > calculated > imputed > unknown, that
/// missing nutrient is worse than weak-but-present provenance, that true 0 g is
/// not missing, and that the tier flows through the gate → weight →
/// CandidateMetadata.completeness → scorer (analytical ranks >= imputed), while
/// conflict overlap stays dominant. Source-quality only; no clinical claim.
void main() {
  final gate = MetadataCompletenessGate();

  FoodVariantMetadata foodMeta({
    String? tier,
    double? provenanceQuality,
    String? limitation,
  }) =>
      FoodVariantMetadata(
        foodVariantId: 'f1',
        sourceSystem: 'usda_fdc',
        jurisdiction: 'US',
        language: 'und',
        foodName: 'demo food (synthetic)',
        basisType: 'per_100g',
        servingUnit: 'g',
        preparationState: 'raw',
        aminoAcidFieldsPresent: true,
        extractionConfidence: null,
        sourceRefs: const ['src.usda.fdc.foundation_docs'],
        limitationText: 'educational',
        nutrientConfidenceTier: tier,
        aminoAcidConfidenceTier: tier,
        nutrientProvenanceQuality: provenanceQuality,
        nutrientProvenanceLimitationText: limitation,
      );

  group('FoodVariantMetadata provenance fields', () {
    test('new fields serialize deterministically; null stays null', () {
      final meta = foodMeta(
        tier: 'analytical',
        provenanceQuality: 1.0,
      );
      final json = meta.toJson();
      expect(json['nutrient_confidence_tier'], 'analytical');
      expect(json['amino_acid_confidence_tier'], 'analytical');
      expect(json['nutrient_provenance_quality'], 1.0);
      expect(
          json['uses_analytical_nutrient_values'], false); // default unless set
      expect(json['nutrient_provenance_limitation_text'], isNull);
      expect(jsonEncode(meta.toJson()), jsonEncode(meta.toJson()));
      // A metadata with no provenance keeps the fields null/false (inert).
      final bare = foodMeta();
      expect(bare.toJson()['nutrient_confidence_tier'], isNull);
      expect(bare.toJson()['nutrient_provenance_quality'], isNull);
    });
  });

  group('tier → source-quality helpers', () {
    test('quality is ordered analytical > calculated > imputed > unknown', () {
      final a = nutrientProvenanceQualityFor(NutrientConfidenceTier.analytical);
      final c = nutrientProvenanceQualityFor(NutrientConfidenceTier.calculated);
      final i =
          nutrientProvenanceQualityFor(NutrientConfidenceTier.imputedOrAssumed);
      final u = nutrientProvenanceQualityFor(NutrientConfidenceTier.unknown);
      expect(a, greaterThan(c));
      expect(c, greaterThan(i));
      expect(i, greaterThan(u));
    });

    test('limitation is null for analytical, mentions the tier otherwise', () {
      expect(nutrientProvenanceLimitationFor(NutrientConfidenceTier.analytical),
          isNull);
      final imputed = nutrientProvenanceLimitationFor(
          NutrientConfidenceTier.imputedOrAssumed);
      expect(imputed, isNotNull);
      expect(imputed, contains('imputedOrAssumed'));
      // Source-quality framing, not a clinical claim.
      expect(imputed!.toLowerCase(), contains('source-quality'));
      expect(findBannedSubstrings(imputed), isEmpty);
    });
  });

  group('completeness gate ordering', () {
    double w(NutrientConfidenceTier? t) =>
        gate.toWeight(gate.scoreCandidateFood(
          foodMeta(),
          nutrientCompleteness: 1.0,
          nutrientConfidenceTier: t,
        ));

    test('analytical >= calculated >= imputed/assumed >= unknown', () {
      final a = w(NutrientConfidenceTier.analytical);
      final c = w(NutrientConfidenceTier.calculated);
      final i = w(NutrientConfidenceTier.imputedOrAssumed);
      final u = w(NutrientConfidenceTier.unknown);
      expect(a, greaterThanOrEqualTo(c));
      expect(c, greaterThanOrEqualTo(i));
      expect(i, greaterThanOrEqualTo(u));
      expect(a, greaterThan(u)); // strict end-to-end separation
    });

    test('missing nutrient is worse than weak-but-present provenance', () {
      // Hold the provenance tier equal (imputed) and vary ONLY nutrient
      // completeness: a candidate missing most nutrients scores below one whose
      // nutrients are fully present, even though both have weak provenance.
      final weakButPresent = gate.toWeight(gate.scoreCandidateFood(
        foodMeta(),
        nutrientCompleteness: 1.0,
        nutrientConfidenceTier: NutrientConfidenceTier.imputedOrAssumed,
      ));
      final missingNutrients = gate.toWeight(gate.scoreCandidateFood(
        foodMeta(),
        nutrientCompleteness: 0.2,
        nutrientConfidenceTier: NutrientConfidenceTier.imputedOrAssumed,
      ));
      expect(missingNutrients, lessThan(weakButPresent));
    });

    test('present nutrients (incl. true 0 g) outrank missing nutrients', () {
      // The normalizer encodes "missing ≠ true 0 g" as nutrientCompleteness
      // (see missing_not_zero_test.dart). At the gate, full completeness (all
      // fields present, which may include legitimate zeros) grades strictly
      // above low completeness (fields actually missing), holding tier equal.
      final present = gate.toWeight(gate.scoreCandidateFood(foodMeta(),
          nutrientCompleteness: 1.0,
          nutrientConfidenceTier: NutrientConfidenceTier.analytical));
      final missing = gate.toWeight(gate.scoreCandidateFood(foodMeta(),
          nutrientCompleteness: 0.2,
          nutrientConfidenceTier: NutrientConfidenceTier.analytical));
      expect(present, greaterThan(missing));
    });

    test('missing derivation (null tier) does not raise confidence', () {
      final nullTier = gate.scoreCandidateFood(foodMeta(),
          nutrientCompleteness: 1.0, nutrientConfidenceTier: null);
      final analytical = gate.scoreCandidateFood(foodMeta(),
          nutrientCompleteness: 1.0,
          nutrientConfidenceTier: NutrientConfidenceTier.analytical);
      // A null tier is inert (never better than analytical).
      expect(gate.toWeight(nullTier),
          lessThanOrEqualTo(gate.toWeight(analytical)));
    });
  });

  // End-to-end: tier → gate → weight → CandidateMetadata.completeness → scorer.
  group('tier flows into candidate ranking', () {
    final scorer = MechanisticNextMealScorer();
    final validator = MedicationEntryValidator();
    final builder = TimeAxisBuilder();
    final now = DateTime.utc(2026, 1, 1, 8);

    TimeAxisConflictContext ctx() {
      final v = validator.validate(const RawMedicationEntry(
        activeIngredients: ['carbidopa', 'levodopa'],
        drugProductVariant: 's',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 's',
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
              endMinute: dateTimeToMinute(now) + 120),
          source: 'test',
        ),
      );
    }

    CandidateFood food(String id) => CandidateFood(
          id: id,
          name: id,
          regionalFoodLibraryRef: 'usda_fdc',
          declaredPhysicalForm: MealPhysicalForm.solid,
          components: [
            FoodComponent(
              id: id,
              name: id,
              physicalForm: MealPhysicalForm.solid,
              proteinGrams: 8,
              fatGrams: 2,
              fiberGrams: 1,
              carbohydrateGrams: 20,
              calories: 150,
              portionGrams: 150,
              sourceDocId: 'usda_fdc',
            ),
          ],
        );

    // Completeness derived through the real gate from the nutrient tier.
    CandidateMetadata metaForTier(NutrientConfidenceTier tier) {
      final completeness = gate.toWeight(gate.scoreCandidateFood(
        foodMeta(),
        nutrientCompleteness: 1.0,
        nutrientConfidenceTier: tier,
      ));
      return CandidateMetadata(
        completeness: completeness,
        authorityScore: 0.6,
        jurisdictionMatchScore: 0.6,
        provenanceQuality: 0.6,
        jurisdiction: 'US',
      );
    }

    double scoreOf(List<MechanisticCandidateScore> s, String id) =>
        s.firstWhere((e) => e.candidateFoodId == id).finalCandidateScore;

    test('identical candidates: analytical ranks >= imputed/assumed', () {
      final scores = scorer.score(
        baseContext: ctx(),
        baseMealCompositionsById: const {},
        candidates: [food('analytical'), food('imputed')],
        candidateMetadata: {
          'analytical': metaForTier(NutrientConfidenceTier.analytical),
          'imputed': metaForTier(NutrientConfidenceTier.imputedOrAssumed),
        },
      );
      expect(scoreOf(scores, 'analytical'),
          greaterThanOrEqualTo(scoreOf(scores, 'imputed')));
    });

    test('tier difference cannot break conflict-overlap dominance', () {
      // The provenance/completeness swing from the tier is bounded and cannot
      // overpower the dominant conflict-overlap term (same invariant as PR #38).
      final scores = scorer.score(
        baseContext: ctx(),
        baseMealCompositionsById: const {},
        candidates: [food('analytical'), food('imputed')],
        candidateMetadata: {
          'analytical': metaForTier(NutrientConfidenceTier.analytical),
          'imputed': metaForTier(NutrientConfidenceTier.imputedOrAssumed),
        },
      );
      final gap = scoreOf(scores, 'analytical') - scoreOf(scores, 'imputed');
      // Identical composition ⇒ identical conflict overlap ⇒ the tier-driven
      // gap is small (a refinement), never a dominant swing.
      expect(gap, lessThan(0.2));
      expect(gap, greaterThanOrEqualTo(0.0));
    });
  });
}
