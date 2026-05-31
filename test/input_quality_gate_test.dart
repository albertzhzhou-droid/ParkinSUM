import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/input_quality.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/input_quality_gate.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P1 — InputQualityGate. Pure, deterministic context-completeness aggregator
/// over in-memory fixtures. NOT medical advice, NOT a recommendation engine,
/// NOT clinically calibrated. No PHI / patient / subject / encounter semantics.
void main() {
  final gate = InputQualityGate();
  final normalizer = MealCompositionNormalizer();

  RawMedicationEntry validMed({
    String ingredient = 'levodopa',
    String? releaseType = 'immediate',
    num? strength = 100,
    String? unit = 'mg',
    String? sourceDocId = 'src.dailymed.sinemet.label',
  }) =>
      RawMedicationEntry(
        activeIngredient: ingredient,
        drugProductVariant: 'levodopa-carbidopa 100/25 tablet',
        form: 'tablet',
        route: 'oral',
        releaseType: releaseType,
        strength: strength,
        unit: unit,
        jurisdiction: 'US',
        sourceDocId: sourceDocId,
      );

  FoodComponent comp({
    double? protein = 8,
    double? fat = 5,
    double? fiber = 3,
    double? carbs = 30,
    double? calories = 200,
    double? portion = 150,
  }) =>
      FoodComponent(
        id: 'c1',
        name: 'demo oats',
        physicalForm: MealPhysicalForm.solid,
        proteinGrams: protein,
        fatGrams: fat,
        fiberGrams: fiber,
        carbohydrateGrams: carbs,
        calories: calories,
        portionGrams: portion,
        sourceDocId: 'src.usda.fdc.foundation_docs',
      );

  MealComposition meal(List<FoodComponent> comps) =>
      normalizer.normalize(mealId: 'm1', components: comps);

  FoodVariantMetadata foodMeta({
    String? tier = 'analytical',
    List<String> sourceRefs = const ['src.usda.fdc.foundation_docs'],
    String sourceSystem = 'USDA_FDC',
  }) =>
      FoodVariantMetadata(
        foodVariantId: 'fv1',
        sourceSystem: sourceSystem,
        jurisdiction: 'US',
        language: 'en',
        foodName: 'demo oats',
        basisType: 'per_100g',
        servingUnit: 'g',
        preparationState: 'cooked',
        aminoAcidFieldsPresent: true,
        extractionConfidence: 0.9,
        sourceRefs: sourceRefs,
        limitationText: 'synthetic demo',
        nutrientConfidenceTier: tier,
      );

  const window = UserDefinedMealWindow(
    window: TimelineWindow(startMinute: 0, endMinute: 30),
    source: 'synthetic_demo_fixture',
  );

  InputQualityGateInput completeInput() => InputQualityGateInput(
        medicationEntry: validMed(),
        mealComposition: meal([comp()]),
        foodMetadata: foodMeta(),
        foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
        userDefinedWindow: window,
        candidateMetadataPresent: true,
      );

  String statusOf(MealMedicationInputQualityResult r, String dim) =>
      r.dimension(dim)!.status;

  // 1 — complete synthetic context → complete or sufficient.
  test('complete context is complete/sufficient and eligible', () {
    final r = gate.evaluate(completeInput());
    expect(
      [InputQualityStatus.complete, InputQualityStatus.sufficient]
          .contains(r.overallStatus),
      isTrue,
      reason: 'got ${r.overallStatus}',
    );
    expect(r.mechanisticPrimaryEligible, isTrue);
    expect(r.blockingReasons, isEmpty);
  });

  // 2 — unitless dose → insufficient/invalid.
  test('unitless dose is insufficient/invalid', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(unit: null),
      mealComposition: meal([comp()]),
      userDefinedWindow: window,
    ));
    final s = statusOf(r, InputQualityDimension.medicationDosage);
    expect(
        [InputQualityStatus.insufficient, InputQualityStatus.invalid]
            .contains(s),
        isTrue);
    expect(r.mechanisticPrimaryEligible, isFalse);
  });

  // 3 — product strength does not rescue a missing user dose.
  test('product strength does not rescue missing user dosage', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(), // has a numeric strength
      productStrengthMetadataOnly: true,
      mealComposition: meal([comp()]),
      userDefinedWindow: window,
    ));
    final dim = r.dimension(InputQualityDimension.medicationDosage)!;
    expect(dim.status, InputQualityStatus.insufficient);
    expect(
        dim.findings.any((f) =>
            f.findingId == 'dosage_product_strength_only' &&
            f.message.contains('not a user intake dose')),
        isTrue);
  });

  // 4 — slash-format dose remains insufficient/invalid.
  test('slash-format dose remains invalid', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: const RawMedicationEntry(freeText: '25/100'),
      mealComposition: meal([comp()]),
      userDefinedWindow: window,
    ));
    final s = statusOf(r, InputQualityDimension.medicationDosage);
    expect(
        [InputQualityStatus.insufficient, InputQualityStatus.invalid]
            .contains(s),
        isTrue);
  });

  // 5 — missing active ingredient blocks medication identity.
  test('missing active ingredient blocks identity', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: const RawMedicationEntry(
        drugProductVariant: 'something',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        strength: 100,
        unit: 'mg',
        jurisdiction: 'US',
        sourceDocId: 'src.demo',
      ),
      mealComposition: meal([comp()]),
      userDefinedWindow: window,
    ));
    expect(statusOf(r, InputQualityDimension.medicationIdentity),
        InputQualityStatus.invalid);
    expect(r.mechanisticPrimaryEligible, isFalse);
  });

  // 6 — unknown/missing releaseType lowers metadata but does not fabricate IR.
  test('missing releaseType lowers metadata quality, not fabricated', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(releaseType: null),
      mealComposition: meal([comp()]),
      userDefinedWindow: window,
    ));
    final dim = r.dimension(InputQualityDimension.medicationMetadata)!;
    expect(
        [InputQualityStatus.sufficient, InputQualityStatus.partial]
            .contains(dim.status),
        isTrue);
    expect(
        dim.findings.any((f) =>
            f.findingId == 'metadata_missing_release_type' &&
            f.message.contains('not fabricated')),
        isTrue);
    // dosage + identity still fine (no IR invented).
    expect(statusOf(r, InputQualityDimension.medicationDosage),
        InputQualityStatus.complete);
  });

  // 7 — missing sourceRefs lowers quality.
  test('missing sourceRefs lowers food source quality', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal([comp()]),
      foodMetadata: foodMeta(sourceRefs: const []),
      foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
      userDefinedWindow: window,
    ));
    final dim = r.dimension(InputQualityDimension.foodSourceQuality)!;
    expect(dim.status, isNot(InputQualityStatus.complete));
    expect(dim.findings.any((f) => f.findingId == 'food_missing_sourcerefs'),
        isTrue);
  });

  // 8 — empty meal is invalid.
  test('empty meal is invalid', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal(const []),
      userDefinedWindow: window,
    ));
    expect(statusOf(r, InputQualityDimension.mealComposition),
        InputQualityStatus.invalid);
    expect(r.overallStatus, InputQualityStatus.invalid);
    expect(r.mechanisticPrimaryEligible, isFalse);
  });

  // 9 — missing protein is not treated as 0 g.
  test('missing protein is unknown, not zero', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal([comp(protein: null)]),
      userDefinedWindow: window,
    ));
    final dim = r.dimension(InputQualityDimension.mealComposition)!;
    expect(
        dim.findings.any((f) =>
            f.findingId == 'meal_missing_protein' &&
            f.message.contains('NOT as 0')),
        isTrue);
  });

  // 10 — true 0 g protein remains a valid zero.
  test('true 0g protein is a valid zero', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal([comp(protein: 0)]),
      userDefinedWindow: window,
    ));
    final dim = r.dimension(InputQualityDimension.mealComposition)!;
    expect(dim.findings.any((f) => f.findingId == 'meal_missing_protein'),
        isFalse);
    expect(dim.findings.any((f) => f.findingId == 'meal_protein_true_zero'),
        isTrue);
  });

  // 11 — missing calories lowers completeness.
  test('missing calories lowers meal completeness', () {
    final full = gate.evaluate(InputQualityGateInput(
        medicationEntry: validMed(),
        mealComposition: meal([comp()]),
        userDefinedWindow: window));
    final noCal = gate.evaluate(InputQualityGateInput(
        medicationEntry: validMed(),
        mealComposition: meal([comp(calories: null)]),
        userDefinedWindow: window));
    final fullDim = full.dimension(InputQualityDimension.mealComposition)!;
    final noCalDim = noCal.dimension(InputQualityDimension.mealComposition)!;
    expect(noCalDim.score, lessThan(fullDim.score));
    expect(noCalDim.findings.any((f) => f.findingId == 'meal_missing_calories'),
        isTrue);
  });

  // 12 — missing portion lowers completeness.
  test('missing portion lowers meal completeness', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal([comp(portion: null)]),
      userDefinedWindow: window,
    ));
    final dim = r.dimension(InputQualityDimension.mealComposition)!;
    expect(dim.status, isNot(InputQualityStatus.complete));
    expect(
        dim.findings.any((f) => f.findingId == 'meal_missing_portion'), isTrue);
  });

  // 13 — analytical provenance outranks imputed/unknown.
  test('analytical provenance outranks imputed and unknown', () {
    double provScore(String? tier) => gate
        .evaluate(InputQualityGateInput(
          medicationEntry: validMed(),
          mealComposition: meal([comp()]),
          foodMetadata: foodMeta(tier: tier),
          userDefinedWindow: window,
        ))
        .dimension(InputQualityDimension.nutrientProvenance)!
        .score;
    final analytical = provScore('analytical');
    final imputed = provScore('imputedOrAssumed');
    final unknown = provScore('unknown');
    expect(analytical, greaterThan(imputed));
    expect(imputed, greaterThan(unknown));
  });

  // 14 — synthetic source does not get official-level confidence.
  test('synthetic source capped below official confidence', () {
    final synthetic = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal([comp()]),
      foodMetadata: foodMeta(sourceSystem: 'synthetic_demo'),
      foodSourceAuthorityTier: SourceAuthorityTier.syntheticDemo,
      userDefinedWindow: window,
    ));
    final official = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal([comp()]),
      foodMetadata: foodMeta(),
      foodSourceAuthorityTier:
          SourceAuthorityTier.officialDatabaseInJurisdiction,
      userDefinedWindow: window,
    ));
    final synDim =
        synthetic.dimension(InputQualityDimension.foodSourceQuality)!;
    final offDim = official.dimension(InputQualityDimension.foodSourceQuality)!;
    expect(synDim.status, isNot(InputQualityStatus.complete));
    expect(synDim.score, lessThan(offDim.score));
    expect(synDim.findings.any((f) => f.findingId == 'food_synthetic_source'),
        isTrue);
  });

  // 15 — no user-defined window blocks eligibility but emits no advice.
  test('no window blocks eligibility without advice', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal([comp()]),
      foodMetadata: foodMeta(),
      foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
    ));
    expect(r.mechanisticPrimaryEligible, isFalse);
    expect(r.fallbackReasons.contains('mechanistic_primary_window_unavailable'),
        isTrue);
    // Window missing must NOT make the context invalid.
    expect(r.overallStatus, isNot(InputQualityStatus.invalid));
    // No suggested meal time / advice leaked.
    final json = encodeInputQualityResult(r).toLowerCase();
    expect(json.contains('take your medication at'), isFalse);
    expect(json.contains('you should eat'), isFalse);
  });

  // 16 — missing candidate metadata creates a fallback reason.
  test('missing candidate metadata creates fallback reason', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal([comp()]),
      userDefinedWindow: window,
      candidateMetadataPresent: false,
    ));
    expect(r.fallbackReasons.contains('missing_candidate_metadata'), isTrue);
    expect(r.mechanisticPrimaryEligible, isFalse);
  });

  // 17 — unsafe localization status creates a blocker.
  test('unsafe localization status creates blocker', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(),
      mealComposition: meal([comp()]),
      foodMetadata: foodMeta(),
      foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
      userDefinedWindow: window,
      localizationStatus: const LocalizationReadinessStatus(
          provided: true, hasUnsafeLocalizedCopy: true),
    ));
    expect(r.blockerCount, greaterThan(0));
    expect(r.mechanisticPrimaryEligible, isFalse);
  });

  // 18 — missing localization status is info/warn only.
  test('missing localization status is info only', () {
    final r = gate.evaluate(completeInput());
    final dim = r.dimension(InputQualityDimension.localizationReadiness)!;
    expect(
        dim.findings.every((f) => f.severity != InputQualitySeverity.blocker),
        isTrue);
    expect(dim.findings.any((f) => f.findingId == 'localization_not_provided'),
        isTrue);
  });

  // 19 — JSON output is deterministic.
  test('JSON output is deterministic', () {
    final a = encodeInputQualityResult(gate.evaluate(completeInput()));
    final b = encodeInputQualityResult(gate.evaluate(completeInput()));
    expect(a, equals(b));
    final decoded = jsonDecode(a) as Map<String, dynamic>;
    expect(decoded['report_type'], 'meal_medication_input_quality');
    expect(decoded['not_clinically_calibrated'], isTrue);
    expect(decoded['input_completeness_assessment_only'], isTrue);
  });

  // 20 — no PHI / patient / subject / encounter keys emitted.
  test('no PHI/patient/subject/encounter keys emitted', () {
    final decoded =
        jsonDecode(encodeInputQualityResult(gate.evaluate(completeInput())))
            as Map<String, dynamic>;
    scanNoPhiKeys(decoded);
  });

  // 21 — no medical advice phrases emitted.
  test('no medical advice phrases emitted', () {
    final cases = [
      completeInput(),
      InputQualityGateInput(
          medicationEntry: validMed(unit: null),
          mealComposition: meal([comp(protein: null)])),
    ];
    final banned = RegExp(
        r'recommended dose|adjust your dose|take your medication at|'
        r'safe for you|confirmed safe|you should eat|clinically validated',
        caseSensitive: false);
    for (final c in cases) {
      final json = encodeInputQualityResult(gate.evaluate(c));
      expect(banned.hasMatch(json), isFalse);
    }
  });

  // 22 — findings carry safetyBoundary + notAdviceText.
  test('findings carry safety boundary and not-advice text', () {
    final r = gate.evaluate(InputQualityGateInput(
      medicationEntry: validMed(unit: null),
      mealComposition: meal([comp()]),
    ));
    expect(r.findings, isNotEmpty);
    for (final f in r.findings) {
      expect(f.safetyBoundary, isNotEmpty);
      expect(f.notAdviceText, isNotEmpty);
    }
    expect(r.safetyBoundary, isNotEmpty);
    expect(r.notAdviceText, isNotEmpty);
  });
}
