import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_support.dart';

UnifiedRuntimeContext buildContext({
  required DrugRuntimeContext drug,
  MealRuntimeContext? meal,
  CoeventRuntimeContext? coevent,
  EnteralFeedRuntimeContext? enteralFeed,
  required TimestampRuntimeContext timestamps,
  String registrationRegion = 'US',
  String displayLocale = 'en-US',
  List<String> jurisdictionOverride = const [],
}) {
  return UnifiedRuntimeContext(
    userProfile: UserProfileRuntimeContext(
      patientId: 'patient_1',
      registrationRegion: registrationRegion,
      displayLocale: displayLocale,
      contentJurisdictionOverride: jurisdictionOverride,
      dietProfileRegion: registrationRegion,
      timezone: 'America/Toronto',
    ),
    drug: drug,
    meal: meal,
    coevent: coevent,
    enteralFeed: enteralFeed,
    timestamps: timestamps,
  );
}

void main() {
  final compiler = RuleRegistryCompiler();
  final rules = compiler.compileJsonList(
    baselineCdssRules,
    rulesVersion: 'test_rules',
  );
  final engine = RuntimeRuleEngine();

  test('levodopa plus protein matches temporal rule', () {
    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_1',
        genericName: 'carbidopa/levodopa',
        brandName: 'Sinemet',
        activeIngredients: ['carbidopa', 'levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 300,
        jurisdiction: 'US',
      ),
      meal: const MealRuntimeContext(
        id: 'meal_1',
        totalProteinG: 25,
        tyramineMgEstimate: 1,
        highFatHighCalorie: false,
        itemIds: ['food_1'],
      ),
      timestamps: TimestampRuntimeContext(
        drugTime: DateTime.parse('2026-01-01T08:00:00Z'),
        mealTime: DateTime.parse('2026-01-01T09:00:00Z'),
        coeventTime: null,
      ),
    );

    final matches = engine.evaluateCandidates(context: context, rules: rules);
    expect(
      matches.any((match) => match.rule.ruleId == 'pd.ldopa.protein.window.v1'),
      isTrue,
    );
  });

  test('levodopa plus iron matches warn rule', () {
    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_1',
        genericName: 'carbidopa/levodopa',
        brandName: 'Sinemet',
        activeIngredients: ['carbidopa', 'levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 300,
        jurisdiction: 'US',
      ),
      coevent: const CoeventRuntimeContext(
        substanceTags: ['iron_salt'],
        supplements: {'iron': true},
        thickenerType: null,
      ),
      timestamps: TimestampRuntimeContext(
        drugTime: DateTime.parse('2026-01-01T08:00:00Z'),
        mealTime: null,
        coeventTime: DateTime.parse('2026-01-01T09:00:00Z'),
      ),
    );

    final matches = engine.evaluateCandidates(context: context, rules: rules);
    expect(
      matches.any((match) => match.rule.ruleId == 'pd.ldopa.iron.v1'),
      isTrue,
    );
  });

  test('rasagiline plus tyramine matches dose rule', () {
    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_2',
        genericName: 'rasagiline',
        brandName: 'Azilect',
        activeIngredients: ['rasagiline'],
        substanceTags: ['maob_inhibitor'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 1,
        jurisdiction: 'US',
      ),
      meal: const MealRuntimeContext(
        id: 'meal_1',
        totalProteinG: 8,
        tyramineMgEstimate: 180,
        highFatHighCalorie: false,
        itemIds: ['food_1'],
      ),
      timestamps: TimestampRuntimeContext(
        drugTime: DateTime.parse('2026-01-01T08:00:00Z'),
        mealTime: DateTime.parse('2026-01-01T09:00:00Z'),
        coeventTime: null,
      ),
    );

    final matches = engine.evaluateCandidates(context: context, rules: rules);
    expect(
      matches
          .any((match) => match.rule.ruleId == 'pd.rasagiline.tyramine.us.v1'),
      isTrue,
    );
  });

  test('peg incompatibility matches hard constraint', () {
    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_3',
        genericName: 'peg 3350',
        brandName: null,
        activeIngredients: ['peg_3350'],
        substanceTags: ['peg_3350'],
        formulation: 'solution',
        dosageForm: 'powder',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 1,
        jurisdiction: 'US',
      ),
      coevent: const CoeventRuntimeContext(
        substanceTags: ['hydration'],
        supplements: {},
        thickenerType: 'starch_based',
      ),
      timestamps: const TimestampRuntimeContext(
        drugTime: null,
        mealTime: null,
        coeventTime: null,
      ),
    );

    final matches = engine.evaluateCandidates(context: context, rules: rules);
    expect(
      matches.any(
          (match) => match.rule.ruleId == 'pd.peg.starch_thickener.block.v1'),
      isTrue,
    );
  });

  test('enteral feeding conflict matches escalation rule', () {
    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_1',
        genericName: 'carbidopa/levodopa',
        brandName: null,
        activeIngredients: ['carbidopa', 'levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 300,
        jurisdiction: 'GLOBAL',
      ),
      enteralFeed: const EnteralFeedRuntimeContext(
        mode: 'continuous',
        formula: 'standard_feed',
        proteinGPerDay: 80,
      ),
      timestamps: TimestampRuntimeContext(
        drugTime: DateTime.parse('2026-01-01T08:00:00Z'),
        mealTime: null,
        coeventTime: null,
      ),
      registrationRegion: 'JP',
      displayLocale: 'ja-JP',
    );

    final matches = engine.evaluateCandidates(context: context, rules: rules);
    expect(
      matches.any(
          (match) => match.rule.ruleId == 'pd.ldopa.enteral.feed.review.v1'),
      isTrue,
    );
  });

  test('jurisdiction chain prefers database region map over static fallback',
      () {
    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_1',
        genericName: 'carbidopa/levodopa',
        brandName: null,
        activeIngredients: ['carbidopa', 'levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 300,
        jurisdiction: 'US',
      ),
      timestamps: const TimestampRuntimeContext(
        drugTime: null,
        mealTime: null,
        coeventTime: null,
      ),
      registrationRegion: 'US',
      displayLocale: 'en-US',
    );

    final chain = engine.resolveJurisdictionChain(
      context,
      regionJurisdictionRows: const [
        {
          'region_code': 'US',
          'jurisdiction_chain_json': '["US_DB","NORTH_AMERICA_DB","GLOBAL"]',
        },
      ],
    );

    expect(chain.take(3), ['US_DB', 'NORTH_AMERICA_DB', 'GLOBAL']);
    expect(
      engine.regionJurisdictionMapSource(
        context,
        regionJurisdictionRows: const [
          {
            'region_code': 'US',
            'jurisdiction_chain_json': '["US_DB","GLOBAL"]',
          },
        ],
      ),
      'database_region_jurisdiction_map',
    );
  });

  test('jurisdiction chain falls back to static map when database row missing',
      () {
    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_1',
        genericName: 'carbidopa/levodopa',
        brandName: null,
        activeIngredients: ['carbidopa', 'levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 300,
        jurisdiction: 'US',
      ),
      timestamps: const TimestampRuntimeContext(
        drugTime: null,
        mealTime: null,
        coeventTime: null,
      ),
      registrationRegion: 'US',
      displayLocale: 'en-US',
    );

    expect(engine.resolveJurisdictionChain(context).take(3),
        ['US', 'NA', 'GLOBAL']);
    expect(engine.regionJurisdictionMapSource(context), 'runtime_static_map');
  });

  test('JP locale falls back to JP/APAC/GLOBAL chain', () {
    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_1',
        genericName: 'carbidopa/levodopa',
        brandName: null,
        activeIngredients: ['levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 300,
        jurisdiction: null,
      ),
      timestamps: const TimestampRuntimeContext(
        drugTime: null,
        mealTime: null,
        coeventTime: null,
      ),
      registrationRegion: 'JP',
      displayLocale: 'ja-JP',
    );

    expect(
      engine.resolveJurisdictionChain(context),
      equals(['JP', 'APAC', 'GLOBAL']),
    );
  });

  test('dose band normalizes units and qualified trace values', () {
    final customRules = compiler.compileJsonList([
      {
        'rule_id': 'test.dose.grams',
        'version': '1.0.0',
        'status': 'active',
        'rule_type': 'soft_rule',
        'priority_band': 5,
        'specificity_band': 5,
        'jurisdiction': ['GLOBAL'],
        'applies_to': {
          'subject_types': ['drug'],
        },
        'when': {
          'dose_band': {
            'path': 'drug.daily_dose_mg',
            'threshold': {'value': 0.2, 'unit': 'g'},
            'op': 'gte'
          }
        },
        'then': {
          'decision': 'INFO',
          'severity': 'low',
          'messages': {'zh': '剂量提示'},
          'actions': [],
          'output_tags': []
        },
        'provenance': {
          'evidence_level': 'official_label',
          'source_refs': ['doc_dose']
        }
      },
      {
        'rule_id': 'test.trace.lt',
        'version': '1.0.0',
        'status': 'active',
        'rule_type': 'soft_rule',
        'priority_band': 5,
        'specificity_band': 5,
        'jurisdiction': ['GLOBAL'],
        'applies_to': {
          'subject_types': ['meal'],
        },
        'when': {
          'cmp': {
            'path': 'coevent.supplements.tyramine',
            'op': 'lt',
            'value': 1
          }
        },
        'then': {
          'decision': 'INFO',
          'severity': 'low',
          'messages': {'zh': 'trace提示'},
          'actions': [],
          'output_tags': []
        },
        'provenance': {
          'evidence_level': 'official_database',
          'source_refs': ['doc_trace']
        }
      },
    ], rulesVersion: 'unit_test_rules');

    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_1',
        genericName: 'levodopa',
        brandName: null,
        activeIngredients: ['levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 250,
        jurisdiction: 'US',
      ),
      meal: const MealRuntimeContext(
        id: 'meal_1',
        totalProteinG: 0,
        tyramineMgEstimate: 0,
        highFatHighCalorie: false,
        itemIds: [],
      ),
      coevent: const CoeventRuntimeContext(
        substanceTags: [],
        supplements: {
          'tyramine': {'qualifier_kind': 'trace'},
        },
        thickenerType: null,
      ),
      timestamps: const TimestampRuntimeContext(
        drugTime: null,
        mealTime: null,
        coeventTime: null,
      ),
    );

    final matches =
        engine.evaluateCandidates(context: context, rules: customRules);
    expect(matches.map((match) => match.rule.ruleId),
        containsAll(['test.dose.grams', 'test.trace.lt']));
  });

  test('same-band matrix escalates decision conflicts and explains tie-break',
      () {
    final customRules = compiler.compileJsonList([
      _testRuleJson(
        ruleId: 'same.warn.official',
        decision: 'WARN',
        evidenceLevel: 'official_label',
      ),
      _testRuleJson(
        ruleId: 'same.info.review',
        decision: 'INFO',
        evidenceLevel: 'review',
      ),
    ], rulesVersion: 'same_band_rules');
    final context = buildContext(
      drug: const DrugRuntimeContext(
        id: 'drug_1',
        genericName: 'levodopa',
        brandName: null,
        activeIngredients: ['levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: 100,
        jurisdiction: 'US',
      ),
      timestamps: const TimestampRuntimeContext(
        drugTime: null,
        mealTime: null,
        coeventTime: null,
      ),
    );
    final sorted = engine.resolveByPriority(
      engine.evaluateCandidates(context: context, rules: customRules),
      jurisdictionChain: engine.resolveJurisdictionChain(context),
    );
    const support = RuntimeRuleSupport();
    final escalation = support.evaluateSameBandEscalation(sorted);
    expect(escalation.requiresReview, isTrue);
    expect(escalation.reason, 'same_band_warn_permissive_conflict');
    expect(escalation.suppressedRuleIds, contains('same.info.review'));

    final sameDecisionRules = compiler.compileJsonList([
      _testRuleJson(
        ruleId: 'same.warn.official',
        decision: 'WARN',
        evidenceLevel: 'official_label',
      ),
      _testRuleJson(
        ruleId: 'same.warn.review',
        decision: 'WARN',
        evidenceLevel: 'review',
      ),
    ], rulesVersion: 'same_band_rules');
    final sameDecisionSorted = engine.resolveByPriority(
      engine.evaluateCandidates(context: context, rules: sameDecisionRules),
      jurisdictionChain: engine.resolveJurisdictionChain(context),
    );
    final tieBreak = support.evaluateSameBandEscalation(sameDecisionSorted);
    expect(tieBreak.requiresReview, isFalse);
    expect(tieBreak.reason, 'same_decision_provenance_tiebreak');
    expect(sameDecisionSorted.first.rule.ruleId, 'same.warn.official');
    expect(sameDecisionSorted.first.rule.sourceAuthority,
        greaterThan(sameDecisionSorted.last.rule.sourceAuthority));
  });
}

Map<String, dynamic> _testRuleJson({
  required String ruleId,
  required String decision,
  required String evidenceLevel,
}) =>
    {
      'rule_id': ruleId,
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': 7,
      'specificity_band': 7,
      'jurisdiction': ['GLOBAL'],
      'applies_to': {
        'subject_types': ['drug'],
      },
      'when': {
        'exists': {'path': 'drug.id'}
      },
      'then': {
        'decision': decision,
        'severity': 'low',
        'messages': {'zh': '测试规则'},
        'actions': [],
        'output_tags': []
      },
      'provenance': {
        'evidence_level': evidenceLevel,
        'source_refs': ['doc_$ruleId'],
        'effective_from': '2026-01-01T00:00:00Z',
      }
    };
