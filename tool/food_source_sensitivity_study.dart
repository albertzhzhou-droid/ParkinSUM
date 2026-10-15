import 'dart:convert';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/legacy_food_recommendation_parameters.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';

/// Manufactured finite study only. Source density stays per 100g; only
/// FoodComponent values are per source-reported portion. No catalog writes.
Map<String, Object?> jointSourceStudy(
  Map<String, dynamic> domain,
  Map<String, dynamic> source,
) {
  final rawFoods = (source['FoundationFoods'] as List)
      .cast<Map<String, dynamic>>();
  if (rawFoods.isEmpty || rawFoods.length > 32) {
    throw StateError('invalid-source-food-budget');
  }
  final imported =
      const FdcP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      ).importFoods(
        rawFoods,
        sourceLabel: 'six-original-foundation-objects-finite-study',
      );
  final byCode = {
    for (final f in imported.projectedFoods) f.sourceFoodCode!: f,
  };
  final rawByCode = {for (final f in rawFoods) '${f['fdcId']}': f};
  final groups =
      (domain['groups'] as List).cast<Map<String, dynamic>>().toList()..sort(
        (a, b) => '${a['candidate_id']}'.compareTo('${b['candidate_id']}'),
      );
  final bound = domain['maximum_joint_combinations'] as int;
  if (bound < 1 || bound > 128 || groups.isEmpty || groups.length > 8) {
    throw StateError('invalid-study-budget');
  }
  final groupIds = <String>{};
  var count = 1;
  final choices = <List<Map<String, Object?>>>[];
  for (final group in groups) {
    final id = group['candidate_id'] as String;
    if (!groupIds.add(id) || !RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(id)) {
      throw StateError('duplicate-or-invalid-group');
    }
    if (group['matching_status'] !=
        'explicit_research_alternatives_not_validated_catalog_equivalence') {
      throw StateError('matching-unreviewed');
    }
    final options =
        (group['options'] as List).cast<Map<String, dynamic>>().toList()
          ..sort((a, b) => '${a['option_id']}'.compareTo('${b['option_id']}'));
    if (options.isEmpty ||
        options.length > 16 ||
        count > bound ~/ options.length) {
      throw StateError('whole-study-over-budget');
    }
    count *= options.length;
    final seen = <String>{};
    final row = <Map<String, Object?>>[];
    for (final option in options) {
      final code = option['fdc_id'] as String;
      final food = byCode[code];
      final index = option['original_food_portion_index'] as int;
      if (food == null ||
          !seen.add(option['option_id'] as String) ||
          food.basisType != 'per_100g_edible_part') {
        throw StateError('invalid-option-binding');
      }
      final rawPortions = rawByCode[code]!['foodPortions'] as List;
      if (index < 0 || index >= rawPortions.length) {
        throw StateError('foreign-or-absent-portion');
      }
      final raw = rawPortions[index] as Map;
      if (raw['id'] != option['portion_id']) {
        throw StateError('foreign-or-absent-portion');
      }
      final portion = food.foodPortionEvidence
          .where((p) => p.recordLocator == '$code:foodPortions:$index')
          .toList();
      if (portion.length != 1 || portion.single.sourceFoodId != code) {
        throw StateError('imported-portion-binding-mismatch');
      }
      final grams = portion.single.gramWeight;
      if (grams == null || !grams.isFinite || grams <= 0) {
        throw StateError('invalid-source-weight');
      }
      final fields = {
        'protein_g': food.proteinG,
        'fat_g': food.fatG,
        'fiber_g': food.fiberG,
        'carbohydrate_g': food.carbsG,
        'energy_kcal': food.energyKcal,
      };
      final names = {
        'protein_g': 'proteinG',
        'fat_g': 'fatG',
        'fiber_g': 'fiberG',
        'carbohydrate_g': 'carbsG',
        'energy_kcal': 'energyKcal',
      };
      final values = <String, double?>{};
      for (final e in fields.entries) {
        final v = e.value;
        final scaled = v == null || food.isNutrientMissing(names[e.key]!)
            ? null
            : v * grams / 100;
        if (scaled != null && (!scaled.isFinite || scaled < 0)) {
          throw StateError('invalid-source-nutrient');
        }
        values[e.key] = scaled;
      }
      row.add({
        'option_id': option['option_id'],
        'fdc_id': code,
        'portion_id': raw['id'],
        'portion_record_locator': portion.single.recordLocator,
        'source_doc_id': portion.single.sourceDocId,
        'portion_grams': grams,
        'candidate_id': id,
        'name': food.name,
        'per_portion': values,
      });
    }
    choices.add(row);
  }
  final windows = (domain['windows'] as List).cast<Map<String, dynamic>>();
  if (windows.isEmpty ||
      windows.length > 4 ||
      windows.map((w) => w['id']).toSet().length != windows.length) {
    throw StateError('invalid-study-windows');
  }
  for (final w in windows) {
    if (w['start_minute'] is! int ||
        w['end_minute'] is! int ||
        (w['start_minute'] as int) < 0 ||
        (w['end_minute'] as int) <= (w['start_minute'] as int) ||
        (w['end_minute'] as int) > 1440) {
      throw StateError('invalid-study-window');
    }
  }
  final now = DateTime.parse(domain['time_origin_utc'] as String).toUtc();
  final minute = dateTimeToMinute(now);
  final asOf = DateTime.parse(domain['evidence_as_of_utc'] as String).toUtc();
  const med = NormalizedMedicationContext(
    drugProductVariant: 'synthetic-joint-study',
    activeIngredients: ['carbidopa', 'levodopa'],
    strength: 100,
    unit: 'mg',
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    jurisdiction: 'US',
    sourceDocId: 'synthetic-joint-study',
    labelSection: 'synthetic input',
    extractionConfidence: 1,
    limitationText:
        'Manufactured model context; no administration assertion or clinical suitability.',
  );
  final base = domain['synthetic_base_meal'] as Map;
  final baseOptions = choices
      .expand((row) => row)
      .where(
        (c) =>
            c['fdc_id'] == base['fdc_id'] &&
            c['portion_id'] == base['portion_id'] &&
            c['portion_record_locator'] ==
                '${base['fdc_id']}:foodPortions:${base['original_food_portion_index']}',
      )
      .toList();
  if (baseOptions.length != 1 ||
      base['minute_offset'] is! int ||
      (base['minute_offset'] as int) > 0 ||
      (base['minute_offset'] as int) < -60) {
    throw StateError('invalid-synthetic-base-meal-binding');
  }
  final baseline = baseOptions.single;
  final baseComponent = componentFromSourceChoice(baseline);
  final baseComposition = MealCompositionNormalizer().normalize(
    mealId: 'synthetic-base-composition',
    components: [baseComponent],
    declaredPhysicalForm: MealPhysicalForm.solid,
  );
  final scorer = MechanisticNextMealScorer();
  final scenarios = <Map<String, Object?>>[];
  final selected = <Map<String, Object?>>[];
  void evaluate() {
    final candidates = [
      for (final c in selected)
        CandidateFood(
          id: c['candidate_id'] as String,
          name: c['name'] as String,
          regionalFoodLibraryRef: 'FDC_source_reported_portion',
          declaredPhysicalForm: MealPhysicalForm.solid,
          components: [componentFromSourceChoice(c)],
        ),
    ];
    for (final w in (domain['windows'] as List).cast<Map<String, dynamic>>()) {
      final window = UserDefinedMealWindow(
        window: TimelineWindow(
          startMinute: minute + (w['start_minute'] as num).toInt(),
          endMinute: minute + (w['end_minute'] as num).toInt(),
        ),
        source: 'fixed-manufactured-study-window',
      );
      final context = TimeAxisConflictContext(
        referenceMinute: minute,
        medicationEvents: [
          MedicationTimelineEvent(
            id: 'synthetic-med',
            minute: minute,
            context: med,
          ),
        ],
        mealEvents: [
          MealTimelineEvent(
            id: 'synthetic-base-meal',
            minute: minute + (base['minute_offset'] as int),
            compositionId: baseComposition.id,
            physicalForm: MealPhysicalForm.solid,
          ),
        ],
        userDefinedWindow: window,
      );
      final scores = scorer.score(
        baseContext: context,
        baseMealCompositionsById: {baseComposition.id: baseComposition},
        candidates: candidates,
        evidenceAsOfUtc: asOf,
      );
      scenarios.add({
        'scenario_id':
            '${w['id']}:${selected.map((c) => c['option_id']).join('|')}',
        'window_id': w['id'],
        'choices': [for (final c in selected) Map<String, Object?>.from(c)],
        'results': [
          for (final s in scores)
            {
              'candidate_id': s.candidateFoodId,
              'explanation': s.explanation,
              'uncertainty_reasons': s.upstreamResult?.uncertaintyReasons,
              'availability': s.availability.name,
              'score': s.insufficientContext ? null : s.finalCandidateScore,
              'conflict_overlap': s.insufficientContext
                  ? null
                  : s.conflictOverlapScore,
              'confidence': s.confidenceBand.name,
              'uncertainty_penalty': s.insufficientContext
                  ? null
                  : s.uncertaintyPenalty,
              'redistribution': s.insufficientContext
                  ? null
                  : s.proteinRedistributionScore,
              'adequacy': s.insufficientContext
                  ? null
                  : s.nutritionAdequacyContribution,
              'nutrition_completeness': s.nutritionDataCompleteness,
              'metadata': s.metadataCompletenessScore,
              'authority': s.sourceAuthorityScore,
              'jurisdiction': s.jurisdictionMatchScore,
              'provenance': s.provenanceQualityScore,
            },
        ],
      });
    }
  }

  void enumerate(int i) {
    if (i == choices.length) {
      evaluate();
      return;
    }
    for (final c in choices[i]) {
      selected.add(c);
      enumerate(i + 1);
      selected.removeLast();
    }
  }

  enumerate(0);
  return {
    'schema': 'parkinsum.joint-source-scenario-study-result/1',
    'configuration': AlgorithmConfigurationIdentity.defaults().toJson(),
    'source_macro_basis': 'per_100g_edible_part',
    'component_macro_basis': 'per_explicit_source_portion',
    'legal_joint_combinations': count,
    'scenarios': scenarios,
    'production_default_changed': false,
    'probabilities': null,
    'clinical_confidence': null,
    'boundary':
        'Source-reported mean/weight finite alternatives only. Source matching and solid form are manufactured study declarations; fixed historical evidence clock. No unseen-domain robustness, clinical confidence, automatic catalog matching or activation.',
  };
}

FoodComponent componentFromSourceChoice(Map<String, Object?> c) {
  final values = c['per_portion'] as Map;
  return FoodComponent(
    id: c['option_id'] as String,
    name: c['name'] as String,
    physicalForm: MealPhysicalForm.solid,
    proteinGrams: values['protein_g'] as double?,
    fatGrams: values['fat_g'] as double?,
    fiberGrams: values['fiber_g'] as double?,
    carbohydrateGrams: values['carbohydrate_g'] as double?,
    calories: values['energy_kcal'] as double?,
    portionGrams: c['portion_grams'] as double,
    sourceDocId: c['source_doc_id'] as String?,
  );
}

Map<String, Object?> fixedHeuristicStudy(Map<String, dynamic> domain) {
  final before = LegacyFoodRecommendationParameterSet.prototypeDefault()
      .toJson();
  final foods = [
    for (final f in domain['foods'] as List)
      FoodItem(
        id: f['id'] as String,
        name: 'Synthetic ${f['id']}',
        category: FoodCategory.other,
        proteinG: double.parse(f['protein_g'] as String),
        fiberG: double.parse(f['fiber_g'] as String),
        fatG: 0,
        carbsG: 0,
        sodiumMg: 0,
        sourceSystem: 'FDC',
        sourceFoodCode: 'synthetic-${f['id']}',
        jurisdiction: 'US',
        basisType: 'per_100g_edible_part',
      ),
  ];
  final cases = domain['cases'] as List;
  if (cases.isEmpty ||
      cases.length > 128 ||
      foods.isEmpty ||
      foods.length > 64 ||
      foods.map((f) => f.id).toSet().length != foods.length) {
    throw StateError('invalid-research-budget-or-identity');
  }
  final ids = <String>{};
  for (final c in cases) {
    if (!ids.add(c['id'] as String)) throw StateError('duplicate-study-case');
  }
  for (final food in foods) {
    if (!food.proteinG.isFinite ||
        food.proteinG < 0 ||
        !food.fiberG.isFinite ||
        food.fiberG < 0) {
      throw StateError('invalid-study-nutrients');
    }
  }
  final rows = <Map<String, Object?>>[];
  for (final c in cases) {
    final p = c['parameters'] as Map;
    var parameters = LegacyFoodRecommendationParameterSet.prototypeDefault();
    for (final e in {
      LegacyFoodRecommendationParameterIds.safetyWeight: p['safety_weight'],
      LegacyFoodRecommendationParameterIds.fiberSupportWeight:
          p['fiber_weight'],
      LegacyFoodRecommendationParameterIds.safetyCautionProteinG:
          p['caution_protein_g'],
      LegacyFoodRecommendationParameterIds.warningProteinG:
          p['warning_protein_g'],
      LegacyFoodRecommendationParameterIds.maximumCandidates:
          '${domain['reporting_candidate_limit_override']}',
    }.entries) {
      parameters = parameters.withValue(e.key, double.parse(e.value as String));
    }
    final output = GetFoodRecommendationsUseCase(parameters: parameters).call(
      history: [],
      drugs: [
        DrugDefinition(
          id: 'synthetic-levodopa-tag',
          genericName: 'Synthetic levodopa context',
          brandNames: [],
          tags: [DrugTag.levodopaLike],
          notes:
              'Manufactured research tag; no administration or suitability assertion.',
          route: 'oral',
          dosageForm: 'tablet',
          releaseType: 'immediate',
        ),
      ],
      allFoods: foods,
      userProfile: UserProfile.defaults(),
    );
    rows.add({
      'id': c['id'],
      'parameters': p,
      'results': [
        for (final r in output)
          {
            'id': r.food.id,
            'score': r.score,
            'decision': r.decision,
            'feature_snapshot': r.featureSnapshot.toJson(),
            'score_breakdown': r.scoreBreakdown,
            'reasons': r.reasons,
          },
      ],
    });
  }
  final after = LegacyFoodRecommendationParameterSet.prototypeDefault()
      .toJson();
  if (jsonEncode(before) != jsonEncode(after)) {
    throw StateError('production-default-changed');
  }
  return {
    'schema': 'parkinsum.fixed-heuristic-study-vectors/1',
    'default_parameters_before': before,
    'default_parameters_after': after,
    'cases': rows,
    'production_defaults_changed': false,
    'clinical_correctness_claim': false,
    'boundary':
        'Finite injected heuristic parameter grid and per100g synthetic density fixtures. Empty history deliberately retains timing gap; legacy ALLOW/WARN is not mechanistic clinical availability.',
  };
}
