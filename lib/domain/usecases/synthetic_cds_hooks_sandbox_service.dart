import '../entities/rule_explanation.dart';
import '../entities/rule_test_case.dart';
import '../entities/runtime_context.dart';
import 'rule_explanation_projection.dart';
import 'synthetic_cds_hooks_card_projector.dart';
import 'synthetic_rule_test_runner.dart';

enum SyntheticCdsHooksScenario {
  completeProteinMeal,
  missingMealContext,
  lowProteinMeal,
}

final class SyntheticCdsHooksSandboxRun {
  SyntheticCdsHooksSandboxRun({
    required this.scenario,
    required this.rulePackVersion,
    required this.inputDigest,
    required Map<String, dynamic> response,
    required this.traceDecision,
    required this.resultState,
    required this.missingInputs,
  }) : response = _freezeMap(response);

  final SyntheticCdsHooksScenario scenario;
  final String rulePackVersion;
  final String inputDigest;
  final Map<String, dynamic> response;
  final String? traceDecision;
  final String? resultState;
  final List<String> missingInputs;
}

/// Runs fixed, code-owned synthetic contexts through the current in-memory
/// rule engine and projects at most one information-only card. No account,
/// persisted records, network client, EHR request or rule activation is used.
final class SyntheticCdsHooksSandboxService {
  final SyntheticRuleTestRunner _runner;

  const SyntheticCdsHooksSandboxService({SyntheticRuleTestRunner? runner})
    : _runner = runner ?? const SyntheticRuleTestRunner();

  Future<SyntheticCdsHooksSandboxRun> run(
    SyntheticCdsHooksScenario scenario,
  ) async {
    final ruleSet = RuleTestRuleSet.baseline();
    final seededCase = RuleTestCase.seed(ruleSet: ruleSet);
    final testCase = _caseForScenario(seededCase, scenario);
    final report = await _runner.run(testCase: testCase, ruleSet: ruleSet);
    final output = report.output;
    if (report.status == RuleTestRunStatus.bindingMismatch || output == null) {
      throw StateError('The fixed synthetic rule binding did not match.');
    }

    final traces = (output.alertsJson['rule_hit_trace'] as List)
        .cast<Map<String, dynamic>>();
    final explanations = projectRuleExplanations(
      auditEntries: output.auditEntries,
      ruleHitTrace: traces,
    );
    final selected = _selectExplanation(scenario, explanations, traces);
    final response = selected == null
        ? <String, dynamic>{'cards': <Object?>[]}
        : projectSyntheticRuleExplanationCard(
            explanation: selected.explanation,
            ruleTrace: selected.trace,
            rulePackVersion: ruleSet.bundleVersion,
            rulePackDigest: report.rulesDigest,
            inputDigest: report.inputDigest,
          );
    final card = (response['cards'] as List).cast<Map<String, dynamic>>();
    final extension = card.isEmpty
        ? null
        : ((card.single['extension']
                  as Map<String, dynamic>)[cdsHooksRuleTraceExtensionName]
              as Map<String, dynamic>);
    return SyntheticCdsHooksSandboxRun(
      scenario: scenario,
      rulePackVersion: ruleSet.bundleVersion,
      inputDigest: report.inputDigest,
      response: response,
      traceDecision: extension?['traceDecision'] as String?,
      resultState: extension?['resultState'] as String?,
      missingInputs: List<String>.unmodifiable(
        (extension?['missingOrUncertainInputs'] as List? ?? const <String>[])
            .cast<String>(),
      ),
    );
  }
}

RuleTestCase _caseForScenario(
  RuleTestCase seed,
  SyntheticCdsHooksScenario scenario,
) {
  final source = seed.context;
  final meal = switch (scenario) {
    SyntheticCdsHooksScenario.completeProteinMeal => const MealRuntimeContext(
      id: 'synthetic_meal_complete',
      totalProteinG: 25,
      tyramineMgEstimate: 0,
      highFatHighCalorie: false,
      itemIds: <String>['synthetic_food'],
    ),
    SyntheticCdsHooksScenario.missingMealContext => null,
    SyntheticCdsHooksScenario.lowProteinMeal => const MealRuntimeContext(
      id: 'synthetic_meal_low_protein',
      totalProteinG: 5,
      tyramineMgEstimate: 0,
      highFatHighCalorie: false,
      itemIds: <String>['synthetic_food'],
    ),
  };
  final timestamps = TimestampRuntimeContext(
    drugTime: source.timestamps.drugTime,
    mealTime: meal == null ? null : source.timestamps.mealTime,
    coeventTime: source.timestamps.coeventTime,
  );
  return seed.copyWith(
    context: UnifiedRuntimeContext(
      userProfile: source.userProfile,
      drug: source.drug,
      meal: meal,
      coevent: source.coevent,
      enteralFeed: source.enteralFeed,
      timestamps: timestamps,
    ),
  );
}

typedef _RuleCandidate = ({
  RuleExplanation explanation,
  Map<String, dynamic> trace,
});

_RuleCandidate? _selectExplanation(
  SyntheticCdsHooksScenario scenario,
  List<RuleExplanation> explanations,
  List<Map<String, dynamic>> traces,
) {
  final candidates = <_RuleCandidate>[
    for (final explanation in explanations)
      (
        explanation: explanation,
        trace: traces.singleWhere(
          (row) => row['rule_id'] == explanation.ruleId,
        ),
      ),
  ];
  switch (scenario) {
    case SyntheticCdsHooksScenario.completeProteinMeal:
      for (final candidate in candidates) {
        if (candidate.explanation.triggered) return candidate;
      }
      throw StateError('The fixed complete fixture produced no matched rule.');
    case SyntheticCdsHooksScenario.missingMealContext:
      for (final candidate in candidates) {
        if (candidate.trace['trace_decision'] == 'not_matched' &&
            candidate.trace['missing_fields'] is List &&
            (candidate.trace['missing_fields'] as List).isNotEmpty) {
          return candidate;
        }
      }
      throw StateError('The missing-meal fixture produced no missing trace.');
    case SyntheticCdsHooksScenario.lowProteinMeal:
      if (candidates.any((candidate) => candidate.explanation.triggered)) {
        throw StateError(
          'The low-protein fixture unexpectedly matched a rule.',
        );
      }
      return null;
  }
}

Map<String, dynamic> _freezeMap(Map<String, dynamic> source) =>
    Map<String, dynamic>.unmodifiable({
      for (final entry in source.entries) entry.key: _freeze(entry.value),
    });

Object? _freeze(Object? value) => switch (value) {
  Map<String, dynamic> map => _freezeMap(map),
  List<dynamic> list => List<Object?>.unmodifiable(list.map(_freeze)),
  _ => value,
};
