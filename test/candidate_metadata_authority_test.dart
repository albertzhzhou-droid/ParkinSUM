import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/source_authority_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

/// Guards Obj 5: real source authority/jurisdiction/provenance metadata flows
/// into candidate ranking. Official-in-jurisdiction must outrank synthetic/seed
/// when all else is equal; seed must never override official; out-of-
/// jurisdiction official is retained but downgraded.
void main() {
  final scorer = MechanisticNextMealScorer();
  final validator = MedicationEntryValidator();
  final builder = TimeAxisBuilder();
  final authority = SourceAuthorityScorer();

  SourceDocumentMetadata source(SourceAuthorityTier tier, String jur) =>
      SourceDocumentMetadata(
        sourceDocId: 'doc',
        sourceSystem: 'sys',
        jurisdiction: jur,
        language: 'und',
        sourceOwner: 'owner',
        docType: 'food_composition',
        authorityTier: tier,
        translationStatus: ReferenceTranslationStatus.notTranslation,
        publishedAt: null,
        effectiveAt: null,
        lastUpdated: null,
        licenseOrUseLimitations: 'x',
        sourceRefs: const ['ref'],
        limitationText: 'x',
      );

  group('SourceAuthorityScorer policy', () {
    test('official food-composition table in-jurisdiction outranks synthetic',
        () {
      final official = authority.score(
        source(SourceAuthorityTier.foodCompositionTable, 'US'),
        userJurisdictionChain: const ['US'],
      );
      final synthetic = authority.score(
        source(SourceAuthorityTier.syntheticDemo, 'US'),
        userJurisdictionChain: const ['US'],
      );
      expect(official, greaterThan(synthetic));
    });

    test('out-of-jurisdiction official is retained but downgraded', () {
      final inJur = authority.score(
        source(SourceAuthorityTier.foodCompositionTable, 'US'),
        userJurisdictionChain: const ['US'],
      );
      final outJur = authority.score(
        source(SourceAuthorityTier.foodCompositionTable, 'JP'),
        userJurisdictionChain: const ['US'],
      );
      expect(outJur, greaterThan(0.0)); // retained
      expect(outJur, lessThan(inJur)); // downgraded
    });

    test('seed never overrides official', () {
      expect(
        authority.seedMayOverride(
          source(SourceAuthorityTier.seedOrManualDemo, 'US'),
          source(SourceAuthorityTier.officialLabelInJurisdiction, 'US'),
        ),
        isFalse,
      );
    });
  });

  group('CandidateMetadata flows into ranking', () {
    const a = CandidateFood(
      id: 'a',
      name: 'official food',
      regionalFoodLibraryRef: 'USDA',
      declaredPhysicalForm: MealPhysicalForm.solid,
      components: [
        FoodComponent(
          id: 'a',
          name: 'official food',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 2,
          fatGrams: 0,
          fiberGrams: 3,
          carbohydrateGrams: 27,
          calories: 105,
          portionGrams: 120,
          sourceDocId: 'USDA',
        ),
      ],
    );
    // Identical nutrition; only the provenance metadata differs.
    const b = CandidateFood(
      id: 'b',
      name: 'synthetic food',
      regionalFoodLibraryRef: 'synthetic',
      declaredPhysicalForm: MealPhysicalForm.solid,
      components: [
        FoodComponent(
          id: 'b',
          name: 'synthetic food',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 2,
          fatGrams: 0,
          fiberGrams: 3,
          carbohydrateGrams: 27,
          calories: 105,
          portionGrams: 120,
          sourceDocId: 'synthetic',
        ),
      ],
    );

    test(
        'official-in-jurisdiction candidate scores >= synthetic, all else equal',
        () {
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
      final now = DateTime.utc(2026, 1, 1, 8);
      final ctx = builder.build(
        now: now,
        medicationInputs: [
          MedicationTimelineInput(
            id: 'm',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: v,
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
        candidates: const [a, b],
        candidateMetadata: const {
          'a': CandidateMetadata(
            completeness: 1.0,
            authorityScore: 0.7,
            jurisdictionMatchScore: 1.0,
            provenanceQuality: 0.9,
            jurisdiction: 'US',
          ),
          'b': CandidateMetadata(
            completeness: 1.0,
            authorityScore: 0.1,
            jurisdictionMatchScore: 0.2,
            provenanceQuality: 0.1,
            jurisdiction: 'US',
          ),
        },
      );
      final sa = scores.firstWhere((s) => s.candidateFoodId == 'a');
      final sb = scores.firstWhere((s) => s.candidateFoodId == 'b');
      expect(sa.finalCandidateScore, greaterThan(sb.finalCandidateScore));
    });
  });
}
