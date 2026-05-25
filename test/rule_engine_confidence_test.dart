import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/copy/response_copy_service.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

void main() {
  final compiler = RuleRegistryCompiler();
  final rules = compiler.compileJsonList(
    baselineCdssRules,
    rulesVersion: 'rule_engine_confidence_test',
  );
  final engine = RuntimeRuleEngine();

  test('synthetic levodopa protein scenario triggers stable warning metadata',
      () {
    final matches = engine.evaluateCandidates(
      context: _runtimeContext(
        drug: _levodopaDrug(),
        meal: const MealRuntimeContext(
          id: 'demo_meal_high_protein',
          totalProteinG: 28,
          tyramineMgEstimate: 0,
          highFatHighCalorie: false,
          itemIds: ['demo_food_tofu', 'demo_food_lentils'],
        ),
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.parse('2026-01-01T08:00:00Z'),
          mealTime: DateTime.parse('2026-01-01T09:00:00Z'),
          coeventTime: null,
        ),
      ),
      rules: rules,
    );

    final proteinRule = matches.singleWhere(
      (match) => match.rule.ruleId == 'pd.ldopa.protein.window.v1',
    );
    expect(proteinRule.rule.thenClause.decision.wireValue, 'WARN');
    expect(proteinRule.rule.thenClause.severity, 'high');
    expect(proteinRule.rule.thenClause.outputTags,
        contains('levodopa_protein_timing'));
    expect(proteinRule.rule.provenance.sourceRefs,
        contains('fda-dhivy-high-protein'));
    expect(proteinRule.explanation, isNotEmpty);
    expect(proteinRule.evidence['source_refs'], isA<List<dynamic>>());
  });

  test('synthetic low-protein levodopa scenario remains non-triggering', () {
    final matches = engine.evaluateCandidates(
      context: _runtimeContext(
        drug: _levodopaDrug(),
        meal: const MealRuntimeContext(
          id: 'demo_meal_low_protein',
          totalProteinG: 4,
          tyramineMgEstimate: 0,
          highFatHighCalorie: false,
          itemIds: ['demo_food_applesauce'],
        ),
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.parse('2026-01-01T08:00:00Z'),
          mealTime: DateTime.parse('2026-01-01T09:00:00Z'),
          coeventTime: null,
        ),
      ),
      rules: rules,
    );

    expect(
      matches.map((match) => match.rule.ruleId),
      isNot(contains('pd.ldopa.protein.window.v1')),
    );
  });

  test('synthetic levodopa and iron coevent triggers supplement warning', () {
    final matches = engine.evaluateCandidates(
      context: _runtimeContext(
        drug: _levodopaDrug(),
        coevent: const CoeventRuntimeContext(
          substanceTags: ['iron_salt'],
          supplements: {'synthetic_demo_iron': true},
          thickenerType: null,
        ),
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.parse('2026-01-01T08:00:00Z'),
          mealTime: null,
          coeventTime: DateTime.parse('2026-01-01T08:45:00Z'),
        ),
      ),
      rules: rules,
    );

    final ironRule = matches.singleWhere(
      (match) => match.rule.ruleId == 'pd.ldopa.iron.v1',
    );
    expect(ironRule.rule.thenClause.decision.wireValue, 'WARN');
    expect(ironRule.rule.thenClause.severity, 'high');
    expect(ironRule.rule.thenClause.outputTags,
        contains('levodopa_iron_chelation'));
    expect(ironRule.explanation, contains('pd.ldopa.iron.v1'));
  });

  test('synthetic rasagiline tyramine rule stays jurisdiction-bound', () {
    final usMatches = engine.evaluateCandidates(
      context: _runtimeContext(
        registrationRegion: 'US',
        drug: _rasagilineDrug(),
        meal: const MealRuntimeContext(
          id: 'demo_meal_tyramine_context',
          totalProteinG: 8,
          tyramineMgEstimate: 180,
          highFatHighCalorie: false,
          itemIds: ['demo_food_tyramine_context'],
        ),
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.parse('2026-01-01T08:00:00Z'),
          mealTime: DateTime.parse('2026-01-01T09:00:00Z'),
          coeventTime: null,
        ),
      ),
      rules: rules,
    );
    final caMatches = engine.evaluateCandidates(
      context: _runtimeContext(
        registrationRegion: 'CA',
        displayLocale: 'en-CA',
        drug: _rasagilineDrug(),
        meal: const MealRuntimeContext(
          id: 'demo_meal_tyramine_context',
          totalProteinG: 8,
          tyramineMgEstimate: 180,
          highFatHighCalorie: false,
          itemIds: ['demo_food_tyramine_context'],
        ),
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.parse('2026-01-01T08:00:00Z'),
          mealTime: DateTime.parse('2026-01-01T09:00:00Z'),
          coeventTime: null,
        ),
      ),
      rules: rules,
    );

    expect(usMatches.map((match) => match.rule.ruleId),
        contains('pd.rasagiline.tyramine.us.v1'));
    expect(caMatches.map((match) => match.rule.ruleId),
        isNot(contains('pd.rasagiline.tyramine.us.v1')));
  });

  test('baseline rule messages expose stable localization fallback', () {
    final proteinRule = rules.singleWhere(
      (rule) => rule.ruleId == 'pd.ldopa.protein.window.v1',
    );

    final exactSpanish = proteinRule.thenClause.messages.forLocale('es-MX');
    final familySpanish = proteinRule.thenClause.messages.forLocale('es-AR');
    final unknownFallback = proteinRule.thenClause.messages.forLocale('xx-ZZ');

    expect(exactSpanish.trim(), isNotEmpty);
    expect(familySpanish.trim(), isNotEmpty);
    expect(unknownFallback.trim(), isNotEmpty);
    expect(proteinRule.thenClause.messages.asLocaleMap(),
        containsPair('zh', isA<String>()));
    expect(proteinRule.thenClause.messages.asLocaleMap(),
        containsPair('es-MX', exactSpanish));
  });

  test('explanation copy keeps structure without exposing machine codes', () {
    final copy = ResponseCopyService(i18n: AppI18n.fromLocaleTag('en-US'));
    final result = InteractionResult(
      mealId: 'demo_meal_high_protein',
      status: InteractionStatus.warning,
      summary: 'Database-backed checks found 1 advisory item.',
      analysisText:
          'The engine checked this meal against 1 active medication(s). Estimated meal protein from the current item list was about 28.0 g.',
      keyFindings: const [
        'Warn · Synthetic Demo Context: Rule pd.ldopa.protein.window.v1 matched target drug-meal.',
      ],
      nextActions: const ['emit_machine_tag: levodopa_protein_timing'],
      dataNotes: const [
        'Real nutrient facts from database food variants were used when available.',
      ],
      issues: [
        InteractionIssue(
          severity: InteractionSeverity.moderate,
          title: 'Warn · Synthetic Demo Context',
          detail:
              'Rule pd.ldopa.protein.window.v1 matched target drug-meal. Official label evidence was used.',
          relatedDrugId: 'demo_drug_levodopa_context',
        ),
      ],
      generatedAt: DateTime.utc(2026, 1, 1),
      score: 72,
    );

    final summary = copy.interactionSummary(result);
    final analysis = copy.interactionAnalysis(result);
    final dataNote = copy.dataNote(result.dataNotes.first);

    expect(summary, contains('72'));
    expect(analysis, contains('28.0 g'));
    expect(analysis.toLowerCase(), contains('diagnosis'));
    expect(dataNote.toLowerCase(), contains('database'));
    expect(summary, isNot(contains('pd.ldopa.protein.window.v1')));
    expect(dataNote, isNot(contains('selected=')));
  });
}

UnifiedRuntimeContext _runtimeContext({
  required DrugRuntimeContext drug,
  MealRuntimeContext? meal,
  CoeventRuntimeContext? coevent,
  required TimestampRuntimeContext timestamps,
  String registrationRegion = 'US',
  String displayLocale = 'en-US',
}) {
  return UnifiedRuntimeContext(
    userProfile: UserProfileRuntimeContext(
      patientId: 'demo_user_rule_engine_confidence',
      registrationRegion: registrationRegion,
      displayLocale: displayLocale,
      contentJurisdictionOverride: const [],
      dietProfileRegion: registrationRegion,
      timezone: 'America/Toronto',
    ),
    drug: drug,
    meal: meal,
    coevent: coevent,
    enteralFeed: null,
    timestamps: timestamps,
  );
}

DrugRuntimeContext _levodopaDrug() {
  return const DrugRuntimeContext(
    id: 'demo_drug_levodopa_context',
    genericName: 'carbidopa/levodopa',
    brandName: 'Synthetic Demo Context',
    activeIngredients: ['carbidopa', 'levodopa'],
    substanceTags: ['levodopa'],
    formulation: 'tablet',
    dosageForm: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    dailyDoseMg: 300,
    jurisdiction: 'US',
  );
}

DrugRuntimeContext _rasagilineDrug() {
  return const DrugRuntimeContext(
    id: 'demo_drug_rasagiline_context',
    genericName: 'rasagiline',
    brandName: 'Synthetic Demo Context',
    activeIngredients: ['rasagiline'],
    substanceTags: ['maob_inhibitor'],
    formulation: 'tablet',
    dosageForm: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    dailyDoseMg: 1,
    jurisdiction: 'US',
  );
}
