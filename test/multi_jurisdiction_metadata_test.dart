import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_adapter_registry.dart';
import 'package:parkinsum_companion/domain/entities/nutrient_derivation.dart';
import 'package:parkinsum_companion/domain/entities/source_metadata.dart';
import 'package:parkinsum_companion/domain/usecases/metadata_completeness_gate.dart';
import 'package:parkinsum_companion/domain/usecases/source_authority_scorer.dart';

SourceDocumentMetadata _doc({
  required String system,
  required String jurisdiction,
  required SourceAuthorityTier tier,
  ReferenceTranslationStatus translation =
      ReferenceTranslationStatus.notTranslation,
  String language = 'en',
}) {
  return SourceDocumentMetadata(
    sourceDocId: 'doc:$system',
    sourceSystem: system,
    jurisdiction: jurisdiction,
    language: language,
    sourceOwner: system,
    docType: 'label',
    authorityTier: tier,
    translationStatus: translation,
    publishedAt: null,
    effectiveAt: null,
    lastUpdated: null,
    licenseOrUseLimitations: '',
    sourceRefs: const ['src.x'],
    limitationText: 'educational',
  );
}

void main() {
  group('SourceAuthorityScorer', () {
    final scorer = SourceAuthorityScorer();

    test('official-in-jurisdiction outranks out-of-jurisdiction official', () {
      final us = _doc(
          system: 'DailyMed',
          jurisdiction: 'US',
          tier: SourceAuthorityTier.officialLabelInJurisdiction);
      final foreign = _doc(
          system: 'EMA',
          jurisdiction: 'EU',
          tier: SourceAuthorityTier.officialOutOfJurisdiction);
      final chain = ['US', 'NA', 'GLOBAL'];
      expect(scorer.score(us, userJurisdictionChain: chain),
          greaterThan(scorer.score(foreign, userJurisdictionChain: chain)));
    });

    test('synthetic/seed can never outrank official', () {
      final official = _doc(
          system: 'DailyMed',
          jurisdiction: 'US',
          tier: SourceAuthorityTier.officialLabelInJurisdiction);
      final synthetic = _doc(
          system: 'synthetic_demo',
          jurisdiction: 'US',
          tier: SourceAuthorityTier.syntheticDemo);
      final chain = ['US', 'GLOBAL'];
      expect(scorer.score(synthetic, userJurisdictionChain: chain),
          lessThan(scorer.score(official, userJurisdictionChain: chain)));
      expect(scorer.seedMayOverride(synthetic, official), isFalse);
    });

    test('reference translation is downgraded vs non-translation', () {
      final official = _doc(
          system: 'PMDA',
          jurisdiction: 'JP',
          tier: SourceAuthorityTier.officialLabelInJurisdiction);
      final translation = _doc(
          system: 'PMDA',
          jurisdiction: 'JP',
          tier: SourceAuthorityTier.officialLabelInJurisdiction,
          translation: ReferenceTranslationStatus.referenceOnlyTranslation);
      final chain = ['JP', 'GLOBAL'];
      expect(scorer.score(translation, userJurisdictionChain: chain),
          lessThan(scorer.score(official, userJurisdictionChain: chain)));
    });

    test('cross-jurisdiction conflict is preserved, not collapsed', () {
      final us = _doc(
          system: 'DailyMed',
          jurisdiction: 'US',
          tier: SourceAuthorityTier.officialLabelInJurisdiction);
      final ca = _doc(
          system: 'HealthCanadaDPD',
          jurisdiction: 'CA',
          tier: SourceAuthorityTier.officialDatabaseInJurisdiction);
      expect(scorer.classifyConflict(a: us, b: ca, valuesAgree: false),
          CrossJurisdictionConflictStatus.differentJurisdictionConflict);
      expect(scorer.classifyConflict(a: us, b: ca, valuesAgree: true),
          CrossJurisdictionConflictStatus.differentJurisdictionNoConflict);
    });

    test('jurisdiction match score decays along the chain', () {
      expect(
          scorer.jurisdictionMatchScore(
              sourceJurisdiction: 'US', userJurisdictionChain: ['US', 'NA']),
          1.0);
      expect(
          scorer.jurisdictionMatchScore(
              sourceJurisdiction: 'NA', userJurisdictionChain: ['US', 'NA']),
          lessThan(1.0));
      expect(
          scorer.jurisdictionMatchScore(
              sourceJurisdiction: 'GLOBAL', userJurisdictionChain: ['US']),
          0.2);
      expect(
          scorer.jurisdictionMatchScore(
              sourceJurisdiction: 'JP', userJurisdictionChain: ['US']),
          0.0);
    });
  });

  group('MetadataCompletenessGate', () {
    final gate = MetadataCompletenessGate();

    DrugProductVariantMetadata drug({
      List<String> ingredients = const ['levodopa'],
      double? strength = 100,
      String unit = 'mg',
      String form = 'tablet',
      String release = 'immediate',
      String route = 'oral',
      List<String> refs = const ['src.x'],
      String jurisdiction = 'US',
    }) {
      return DrugProductVariantMetadata(
        drugProductVariantId: 'v',
        sourceSystem: 'DailyMed',
        jurisdiction: jurisdiction,
        language: 'en',
        genericName: 'levodopa',
        brandName: null,
        activeIngredients: ingredients,
        strengthValue: strength,
        strengthUnit: unit,
        doseForm: form,
        route: route,
        releaseType: release,
        productIdentifier: 'NDC',
        labelSection: 'dosage',
        translationStatus: ReferenceTranslationStatus.notTranslation,
        extractionConfidence: 0.9,
        sourceRefs: refs,
        limitationText: 'educational',
      );
    }

    test('complete metadata scores complete', () {
      expect(gate.scoreMedicationContext(drug()),
          MetadataCompletenessScore.complete);
    });

    test('no active ingredient → invalid', () {
      expect(gate.scoreMedicationContext(drug(ingredients: const [])),
          MetadataCompletenessScore.invalid);
    });

    test('no unit → insufficient (no dose)', () {
      expect(gate.scoreMedicationContext(drug(unit: '')),
          MetadataCompletenessScore.insufficient);
    });

    test('missing release type + provenance downgrades', () {
      final score =
          gate.scoreMedicationContext(drug(release: 'unknown', refs: const []));
      expect([
        MetadataCompletenessScore.partial,
        MetadataCompletenessScore.sufficient
      ], contains(score));
    });

    test('rule explanation with no sourceRefs is insufficient', () {
      expect(
          gate.scoreRuleExplanation(
              sourceRefs: const [],
              hasLimitationText: true,
              hasSafetyBoundary: true),
          MetadataCompletenessScore.insufficient);
    });

    test('completeness weight is monotonic', () {
      expect(gate.toWeight(MetadataCompletenessScore.complete),
          greaterThan(gate.toWeight(MetadataCompletenessScore.partial)));
      expect(gate.toWeight(MetadataCompletenessScore.invalid), 0.0);
    });

    FoodVariantMetadata foodMeta() => const FoodVariantMetadata(
          foodVariantId: 'f',
          sourceSystem: 'USDA_FDC',
          jurisdiction: 'US',
          language: 'und',
          foodName: 'food',
          basisType: 'per_100g',
          servingUnit: null,
          preparationState: 'unknown',
          aminoAcidFieldsPresent: true,
          extractionConfidence: null,
          sourceRefs: ['src.usda.fdc.foundation_docs'],
          limitationText: 'educational',
        );

    test('candidate food: full metadata + analytical tier → complete (B1)', () {
      expect(
        gate.scoreCandidateFood(foodMeta(),
            nutrientCompleteness: 1.0,
            nutrientConfidenceTier: NutrientConfidenceTier.analytical),
        MetadataCompletenessScore.complete,
      );
    });

    test('candidate food: imputed tier blocks complete (B1)', () {
      final score = gate.scoreCandidateFood(foodMeta(),
          nutrientCompleteness: 1.0,
          nutrientConfidenceTier: NutrientConfidenceTier.imputedOrAssumed);
      expect(score, isNot(MetadataCompletenessScore.complete));
    });

    test('candidate food: calculated tier downgrades vs analytical (B1)', () {
      final analytical = gate.toWeight(gate.scoreCandidateFood(foodMeta(),
          nutrientCompleteness: 1.0,
          nutrientConfidenceTier: NutrientConfidenceTier.analytical));
      final calculated = gate.toWeight(gate.scoreCandidateFood(foodMeta(),
          nutrientCompleteness: 1.0,
          nutrientConfidenceTier: NutrientConfidenceTier.calculated));
      expect(calculated, lessThan(analytical));
    });

    test('candidate food: null tier is inert (backward compatible)', () {
      // No FDC provenance supplied → unchanged from the pre-B1 grade.
      expect(
        gate.scoreCandidateFood(foodMeta(), nutrientCompleteness: 1.0),
        gate.scoreCandidateFood(foodMeta(),
            nutrientCompleteness: 1.0, nutrientConfidenceTier: null),
      );
    });
  });

  group('SourceAdapterRegistry', () {
    test('covers all required medication source families', () {
      final systems = SourceAdapterRegistry.coveredSourceSystems;
      for (final required in [
        'DailyMed',
        'HealthCanadaDPD',
        'EMA',
        'EU_National_Register',
        'NHS_DMD',
        'PMDA',
        'NMPA',
        'synthetic_demo',
      ]) {
        expect(systems, contains(required),
            reason: 'missing source family $required');
      }
    });

    test('covers food source families', () {
      final systems = SourceAdapterRegistry.coveredSourceSystems;
      for (final required in [
        'USDA_FDC',
        'CIQUAL',
        'China_Food_Composition',
        'app_seed',
      ]) {
        expect(systems, contains(required));
      }
    });

    test('PMDA + NMPA carry reference-translation / language flags', () {
      final pmda = SourceAdapterRegistry.bySourceSystem('PMDA')!;
      expect(pmda.translationStatus,
          ReferenceTranslationStatus.referenceOnlyTranslation);
      final nmpa = SourceAdapterRegistry.bySourceSystem('NMPA')!;
      expect(nmpa.language, 'zh');
    });

    test('all named medication source families now have concrete parsers', () {
      // DailyMed, NMPA, NHS dm+d, and EU national register all have
      // fixture-tested concrete parsers now.
      for (final system in [
        'DailyMed',
        'NMPA',
        'NHS_DMD',
        'EU_National_Register',
      ]) {
        expect(
            SourceAdapterRegistry.bySourceSystem(system)!.implemented, isTrue,
            reason: '$system should be implemented');
      }
    });

    test('every spec serializes without error', () {
      for (final s in SourceAdapterRegistry.all) {
        expect(s.toJson()['source_system'], s.sourceSystem);
      }
    });
  });
}
