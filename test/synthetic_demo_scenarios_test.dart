import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

void main() {
  late Map<String, dynamic> pack;
  late List<Map<String, dynamic>> scenarios;

  setUpAll(() {
    final file = File('docs/assets/demo/synthetic-scenarios.json');
    pack = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    scenarios = (pack['scenarios'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
  });

  test('synthetic demo pack carries explicit public safety labels', () {
    expect(pack['schemaVersion'], '0.1.0-alpha');
    expect(pack['packId'], 'parkinsum_synthetic_demo_scenarios_v0_1_alpha');

    final labels = (pack['labels'] as List<dynamic>).cast<String>();
    expect(labels, contains('synthetic data'));
    expect(labels, contains('fictional user'));
    expect(labels, contains('educational demonstration'));
    expect(labels, contains('not medical advice'));
    expect(labels, contains('not a medical device'));

    final safetyNotice = Map<String, dynamic>.from(pack['safetyNotice'] as Map);
    final mustNotUseFor =
        (safetyNotice['mustNotUseFor'] as List<dynamic>).cast<String>();
    expect(mustNotUseFor, contains('medication timing changes'));
    expect(mustNotUseFor, contains('clinical decision-making'));
    expect(safetyNotice['patientData'], contains('No real patient'));
  });

  test('all demo scenarios parse through current Meal and Intake models', () {
    expect(scenarios, hasLength(4));

    for (final scenario in scenarios) {
      expect(scenario['id'], startsWith('demo_'));
      final meal = Meal.fromJson(
        Map<String, dynamic>.from(scenario['meal'] as Map),
      );
      expect(meal.id, startsWith('demo_'));
      expect(meal.title.toLowerCase(), contains('synthetic'));
      expect(meal.items, isNotEmpty);
      for (final item in meal.items) {
        expect(item.foodId, startsWith('demo_'));
        expect(item.foodName.toLowerCase(), contains('synthetic'));
        expect(item.foodTags, contains('synthetic'));
        expect(item.foodTags, contains('demo'));
      }

      final intakes = (scenario['intakes'] as List<dynamic>)
          .map((value) =>
              Intake.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList(growable: false);
      expect(intakes, isNotEmpty);
      for (final intake in intakes) {
        expect(intake.id, startsWith('demo_'));
        expect(intake.dosageNote.toLowerCase(), contains('synthetic'));
        expect(intake.dosageNote.toLowerCase(), contains('not a prescription'));
      }
    }
  });

  test('expected baseline rule matches are deterministic', () {
    final compiler = RuleRegistryCompiler();
    final rules = compiler.compileJsonList(
      baselineCdssRules,
      rulesVersion: 'synthetic_demo_test',
    );
    final engine = RuntimeRuleEngine();
    final drug = _drugContextFromPack(pack);

    for (final scenario in scenarios) {
      final meal = Meal.fromJson(
        Map<String, dynamic>.from(scenario['meal'] as Map),
      );
      final intake = Intake.fromJson(
        Map<String, dynamic>.from(
          (scenario['intakes'] as List<dynamic>).first as Map,
        ),
      );
      final expected = Map<String, dynamic>.from(
        scenario['expectedEngineBehavior'] as Map,
      );
      final expectedMatches =
          (expected['baselineRuleMatches'] as List<dynamic>).cast<String>();

      final matches = engine.evaluateCandidates(
        context: _runtimeContext(
          pack: pack,
          drug: drug,
          meal: meal,
          intake: intake,
        ),
        rules: rules,
      );
      final actualMatches = matches.map((match) => match.rule.ruleId).toSet();

      expect(
        actualMatches,
        expectedMatches.toSet(),
        reason: 'Scenario ${scenario['id']} should match documented rules.',
      );
    }
  });

  test('fiber and fat scenario flags high-fat high-calorie context only', () {
    final scenario = scenarios.firstWhere(
      (value) => value['id'] == 'demo_fiber_fat_heavy_meal_context',
    );
    final meal = Meal.fromJson(
      Map<String, dynamic>.from(scenario['meal'] as Map),
    );
    final expected = Map<String, dynamic>.from(
      scenario['expectedEngineBehavior'] as Map,
    );

    expect(_isHighFatHighCalorie(meal), expected['highFatHighCalorieContext']);
    expect(
      (expected['explanationFocus'] as List<dynamic>).cast<String>(),
      contains('no standalone fat/fiber clinical claim'),
    );
  });
}

DrugRuntimeContext _drugContextFromPack(Map<String, dynamic> pack) {
  final json = Map<String, dynamic>.from(pack['activeDrugContext'] as Map);
  return DrugRuntimeContext(
    id: json['id'] as String,
    genericName: json['genericName'] as String,
    brandName: json['brandName'] as String?,
    activeIngredients:
        (json['activeIngredients'] as List<dynamic>).cast<String>(),
    substanceTags: (json['substanceTags'] as List<dynamic>).cast<String>(),
    formulation: json['formulation'] as String,
    dosageForm: json['dosageForm'] as String,
    route: json['route'] as String,
    releaseType: json['releaseType'] as String,
    dailyDoseMg: (json['dailyDoseMg'] as num?)?.toDouble(),
    jurisdiction: json['jurisdiction'] as String?,
  );
}

UnifiedRuntimeContext _runtimeContext({
  required Map<String, dynamic> pack,
  required DrugRuntimeContext drug,
  required Meal meal,
  required Intake intake,
}) {
  final user = Map<String, dynamic>.from(pack['fictionalUser'] as Map);
  final totals = meal.computeTotals();
  return UnifiedRuntimeContext(
    userProfile: UserProfileRuntimeContext(
      patientId: user['id'] as String,
      registrationRegion: user['registrationRegion'] as String,
      displayLocale: user['displayLocale'] as String,
      contentJurisdictionOverride: const [],
      dietProfileRegion: user['registrationRegion'] as String,
      timezone: user['timezone'] as String,
    ),
    drug: drug,
    meal: MealRuntimeContext(
      id: meal.id,
      totalProteinG: totals.totalProteinG,
      tyramineMgEstimate: 0,
      highFatHighCalorie: _isHighFatHighCalorie(meal),
      itemIds: meal.items.map((item) => item.foodId).toList(growable: false),
    ),
    coevent: CoeventRuntimeContext(
      substanceTags: meal.coeventSubstanceTags,
      supplements: const {},
      thickenerType: meal.thickenerType,
    ),
    enteralFeed: meal.enteralFeedMode == null
        ? null
        : EnteralFeedRuntimeContext(
            mode: meal.enteralFeedMode!,
            formula: meal.enteralFeedFormula,
            proteinGPerDay: meal.enteralFeedProteinGPerDay,
          ),
    timestamps: TimestampRuntimeContext(
      drugTime: intake.takenAt,
      mealTime: meal.effectiveOccurredAt,
      coeventTime: meal.coeventTime,
    ),
  );
}

bool _isHighFatHighCalorie(Meal meal) {
  final totals = meal.computeTotals();
  final macroTotal =
      totals.totalCarbsG + totals.totalProteinG + totals.totalFatG;
  return totals.totalFatG >= 20 && macroTotal >= 40;
}
