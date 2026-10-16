import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/constants/clinical_evidence_source_seed.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/entities/rule_test_case.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rules = RuleRegistryCompiler().compileJsonList(
    baselineCdssRules,
    rulesVersion: 'baseline_cdss_rules_v1',
  );

  Future<EngineRunOutput> evaluate(
    String route, {
    String ingredient = 'levodopa',
    List<String> supplements = const ['iron_salt'],
    bool proteinEvidenceMissing = false,
    double proteinG = 20,
  }) =>
      ClinicalDecisionSupportService(
        database: InMemoryCdssDatabase(),
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ).run(
        context: context(
          route,
          ingredient: ingredient,
          supplements: supplements,
          proteinEvidenceMissing: proteinEvidenceMissing,
          proteinG: proteinG,
        ),
        rules: rules,
        factsVersion: 'synthetic',
        rulesVersion: 'baseline_cdss_rules_v1',
      );

  test(
    'missing protein is withheld rather than silently evaluating as measured zero',
    () async {
      final unknown = await evaluate(
        'oral',
        proteinG: 0,
        proteinEvidenceMissing: true,
        supplements: const [],
      );
      final hold = unknown.alerts.singleWhere(
        (alert) =>
            alert.ruleIds.contains('pd.ldopa.protein.missing.withheld.v1'),
      );
      expect(hold.decision, RuntimeDecisionType.requireReview);
      expect(hold.explanation, contains('unknown'));
      expect(
        unknown.alerts.expand((alert) => alert.ruleIds),
        isNot(contains('pd.ldopa.protein.window.v1')),
      );
      expect(
        unknown.alerts.any(
          (alert) => alert.decision == RuntimeDecisionType.allow,
        ),
        isFalse,
      );
      final measuredZero = await evaluate(
        'oral',
        proteinG: 0,
        supplements: const [],
      );
      expect(
        measuredZero.alerts.expand((alert) => alert.ruleIds),
        isNot(contains('pd.ldopa.protein.missing.withheld.v1')),
      );
      final contextMissing = context(
        'oral',
        ingredient: 'levodopa',
        supplements: const [],
        proteinG: 0,
        proteinEvidenceMissing: true,
      );
      expect((contextMissing.toJson()['meal'] as Map)['protein_g'], isNull);
      final ruleSet = RuleTestRuleSet.baseline();
      final testCase = RuleTestCase.seed(
        ruleSet: ruleSet,
      ).copyWith(context: contextMissing);
      final roundTrip = RuleTestCase.decode(testCase.encode());
      expect(roundTrip.context.meal!.proteinEvidenceMissing, isTrue);
      expect((roundTrip.context.toJson()['meal'] as Map)['protein_g'], isNull);
    },
  );

  test(
    'explicit oral levodopa retains both qualitative rule signals',
    () async {
      final result = await evaluate('oral');
      final ids = result.alerts.expand((alert) => alert.ruleIds);
      expect(
        ids,
        containsAll(['pd.ldopa.protein.window.v1', 'pd.ldopa.iron.v1']),
      );
      expect(ids, isNot(contains('pd.ldopa.oral.scope.withheld.v1')));
    },
  );

  test(
    'inhaled and unknown routes withhold oral results and never imply safety',
    () async {
      for (final route in [
        'inhaled',
        'subcutaneous',
        'unspecified',
        'unknown',
        '',
      ]) {
        final result = await evaluate(route);
        final ids = result.alerts.expand((alert) => alert.ruleIds).toList();
        expect(
          ids,
          isNot(contains('pd.ldopa.protein.window.v1')),
          reason: route,
        );
        expect(ids, isNot(contains('pd.ldopa.iron.v1')), reason: route);
        final hold = result.alerts.singleWhere(
          (alert) => alert.ruleIds.contains('pd.ldopa.oral.scope.withheld.v1'),
        );
        expect(hold.decision, RuntimeDecisionType.requireReview, reason: route);
        expect(hold.explanation, contains('withheld'));
        expect(
          hold.actions.any(
            (action) => action['type'] == 'withhold_rule_evaluation',
          ),
          isTrue,
        );
        expect(
          result.alerts.any(
            (alert) => alert.decision == RuntimeDecisionType.allow,
          ),
          isFalse,
        );
      }
    },
  );

  test(
    'scope withholding stays limited to levodopa and iron salt exposure',
    () async {
      final unrelated = await evaluate(
        'inhaled',
        ingredient: 'unrelated_synthetic_ingredient',
      );
      expect(
        unrelated.alerts.expand((alert) => alert.ruleIds),
        isNot(contains('pd.ldopa.oral.scope.withheld.v1')),
      );
      final foodIron = await evaluate('oral', supplements: ['dietary_iron']);
      expect(
        foodIron.alerts.expand((alert) => alert.ruleIds),
        isNot(contains('pd.ldopa.iron.v1')),
      );
    },
  );

  test(
    'timing and protein cutoffs remain explicit uncalibrated operational defaults',
    () {
      final protein = rules.singleWhere(
        (rule) => rule.ruleId == 'pd.ldopa.protein.window.v1',
      );
      final iron = rules.singleWhere(
        (rule) => rule.ruleId == 'pd.ldopa.iron.v1',
      );
      for (final rule in [protein, iron]) {
        final action = rule.thenClause.actions.first;
        expect(
          (action['params'] as Map)['note'],
          'operational_default_unspecified_by_label',
        );
      }
      for (final id in [
        'fda-dhivy-high-protein',
        'dailymed-carbidopa-levodopa-iron',
      ]) {
        final source = clinicalEvidenceSourceDocuments.singleWhere(
          (item) => item.sourceDocId == id,
        );
        final payload = jsonDecode(source.rawPayload) as Map;
        expect(source.originUrl, contains('setid='));
        expect(
          payload['operational_defaults_not_label_thresholds'],
          isA<Map>(),
        );
        expect(
          payload['checksum_semantics'],
          'legacy_metadata_identifier_not_source_payload_digest',
        );
      }
    },
  );
}

UnifiedRuntimeContext context(
  String route, {
  required String ingredient,
  required List<String> supplements,
  bool proteinEvidenceMissing = false,
  double proteinG = 20,
}) => UnifiedRuntimeContext(
  userProfile: const UserProfileRuntimeContext(
    patientId: ruleTestSyntheticPatientId,
    registrationRegion: 'US',
    displayLocale: 'en-US',
    contentJurisdictionOverride: [],
    dietProfileRegion: 'US',
    timezone: 'UTC',
  ),
  drug: DrugRuntimeContext(
    id: 'synthetic_drug',
    genericName: ingredient,
    brandName: null,
    activeIngredients: [ingredient],
    substanceTags: [],
    formulation: 'immediate_release',
    dosageForm: 'tablet',
    route: route,
    releaseType: 'immediate_release',
    dailyDoseMg: null,
    jurisdiction: 'US',
  ),
  meal: MealRuntimeContext(
    id: 'synthetic_meal',
    totalProteinG: proteinG,
    proteinEvidenceMissing: proteinEvidenceMissing,
    tyramineMgEstimate: 0,
    highFatHighCalorie: false,
    itemIds: [],
  ),
  coevent: CoeventRuntimeContext(
    substanceTags: supplements,
    supplements: {},
    thickenerType: null,
  ),
  enteralFeed: null,
  timestamps: TimestampRuntimeContext(
    drugTime: DateTime.utc(2026, 9, 29, 12),
    mealTime: DateTime.utc(2026, 9, 29, 12),
    coeventTime: DateTime.utc(2026, 9, 29, 12),
  ),
);
