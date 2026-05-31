// Runs the InputQualityGate over a few DETERMINISTIC SYNTHETIC cases and writes
// a report under build/input_quality/.
//
// Usage:
//   dart run tool/run_input_quality_demo.dart
//
// Educational/research prototype. The InputQualityGate assesses input/context
// completeness only. It is NOT medical advice, NOT a recommendation engine, and
// NOT clinically calibrated. It never recommends dose, timing, or meal choices,
// and never fabricates missing values. Synthetic/demo data only; no network.

import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/input_quality.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/source_metadata.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/input_quality_gate.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

final _gate = InputQualityGate();
final _normalizer = MealCompositionNormalizer();

RawMedicationEntry _validMed({
  String? releaseType = 'immediate',
  num? strength = 100,
  String? unit = 'mg',
}) =>
    RawMedicationEntry(
      activeIngredient: 'levodopa',
      drugProductVariant: 'levodopa-carbidopa 100/25 tablet',
      form: 'tablet',
      route: 'oral',
      releaseType: releaseType,
      strength: strength,
      unit: unit,
      jurisdiction: 'US',
      sourceDocId: 'src.dailymed.sinemet.label',
    );

FoodComponent _comp({double? protein = 8, double? portion = 150}) =>
    FoodComponent(
      id: 'c1',
      name: 'demo oats',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: protein,
      fatGrams: 5,
      fiberGrams: 3,
      carbohydrateGrams: 30,
      calories: 200,
      portionGrams: portion,
      sourceDocId: 'src.usda.fdc.foundation_docs',
    );

MealComposition _meal(List<FoodComponent> comps) =>
    _normalizer.normalize(mealId: 'm1', components: comps);

FoodVariantMetadata _foodMeta({
  String? tier = 'analytical',
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
      sourceRefs: const ['src.usda.fdc.foundation_docs'],
      limitationText: 'synthetic demo',
      nutrientConfidenceTier: tier,
    );

const _window = UserDefinedMealWindow(
  window: TimelineWindow(startMinute: 0, endMinute: 30),
  source: 'synthetic_demo_fixture',
);

void main() {
  final cases = <String, InputQualityGateInput>{
    'complete_context': InputQualityGateInput(
      medicationEntry: _validMed(),
      mealComposition: _meal([_comp()]),
      foodMetadata: _foodMeta(),
      foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
      userDefinedWindow: _window,
    ),
    'unitless_dose': InputQualityGateInput(
      medicationEntry: _validMed(unit: null),
      mealComposition: _meal([_comp()]),
      userDefinedWindow: _window,
    ),
    'missing_protein': InputQualityGateInput(
      medicationEntry: _validMed(),
      mealComposition: _meal([_comp(protein: null)]),
      foodMetadata: _foodMeta(),
      foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
      userDefinedWindow: _window,
    ),
    'true_zero_protein': InputQualityGateInput(
      medicationEntry: _validMed(),
      mealComposition: _meal([_comp(protein: 0)]),
      foodMetadata: _foodMeta(),
      foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
      userDefinedWindow: _window,
    ),
    'missing_user_window': InputQualityGateInput(
      medicationEntry: _validMed(),
      mealComposition: _meal([_comp()]),
      foodMetadata: _foodMeta(),
      foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
    ),
    'unknown_release_type': InputQualityGateInput(
      medicationEntry: _validMed(releaseType: null),
      mealComposition: _meal([_comp()]),
      foodMetadata: _foodMeta(),
      foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
      userDefinedWindow: _window,
    ),
    'synthetic_source': InputQualityGateInput(
      medicationEntry: _validMed(),
      mealComposition: _meal([_comp()]),
      foodMetadata: _foodMeta(sourceSystem: 'synthetic_demo'),
      foodSourceAuthorityTier: SourceAuthorityTier.syntheticDemo,
      userDefinedWindow: _window,
    ),
    'imputed_provenance': InputQualityGateInput(
      medicationEntry: _validMed(),
      mealComposition: _meal([_comp()]),
      foodMetadata: _foodMeta(tier: 'imputedOrAssumed'),
      foodSourceAuthorityTier: SourceAuthorityTier.foodCompositionTable,
      userDefinedWindow: _window,
    ),
  };

  final results = <MapEntry<String, MealMedicationInputQualityResult>>[];
  for (final entry in cases.entries) {
    results.add(MapEntry(entry.key, _gate.evaluate(entry.value)));
  }

  final jsonDoc = {
    'report_type': 'input_quality_demo',
    'not_clinically_calibrated': true,
    'input_completeness_assessment_only': true,
    'generated_at': 'synthetic-demo',
    'case_count': results.length,
    'cases': [
      for (final r in results) {'case': r.key, 'result': r.value.toJson()},
    ],
  };

  final outDir = Directory('build/input_quality');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonDoc));
  File('${outDir.path}/latest.md').writeAsStringSync(_markdown(results));

  stdout.writeln('Input quality demo: ${results.length} synthetic cases.');
  for (final r in results) {
    stdout.writeln('  - ${r.key}: ${r.value.overallStatus} '
        '(eligible=${r.value.mechanisticPrimaryEligible}, '
        'blockers=${r.value.blockerCount})');
  }
  stdout
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
}

String _markdown(List<MapEntry<String, MealMedicationInputQualityResult>> rs) {
  final b = StringBuffer()
    ..writeln('# ParkinSUM Input Quality Gate — synthetic demo')
    ..writeln()
    ..writeln('Educational/research prototype. **Input/context-completeness '
        'assessment only — not medical advice, not a recommendation engine, '
        'and not clinically calibrated.** It never recommends dose, timing, or '
        'meal choices and never fabricates missing values. Synthetic data only.')
    ..writeln()
    ..writeln('| case | overall | score | mechanistic-primary eligible | '
        'blockers |')
    ..writeln('| --- | --- | --- | --- | --- |');
  for (final r in rs) {
    final v = r.value;
    b.writeln('| ${r.key} | ${v.overallStatus} | '
        '${v.overallScore.toStringAsFixed(2)} | '
        '${v.mechanisticPrimaryEligible} | ${v.blockerCount} |');
  }
  b
    ..writeln()
    ..writeln('## Per-case dimension status');
  for (final r in rs) {
    b
      ..writeln()
      ..writeln('### ${r.key}')
      ..writeln()
      ..writeln('| dimension | status | score |')
      ..writeln('| --- | --- | --- |');
    for (final d in r.value.dimensionScores) {
      b.writeln(
          '| ${d.dimension} | ${d.status} | ${d.score.toStringAsFixed(2)} |');
    }
    if (r.value.fallbackReasons.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Fallback reasons: ${r.value.fallbackReasons.join(', ')}');
    }
  }
  b
    ..writeln()
    ..writeln('## Safety boundary')
    ..writeln()
    ..writeln(rs.first.value.safetyBoundary)
    ..writeln()
    ..writeln(rs.first.value.notAdviceText);
  return b.toString();
}
