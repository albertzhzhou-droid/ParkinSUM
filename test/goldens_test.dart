import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/constants/clinical_evidence_source_seed.dart';
import 'package:parkinsum_companion/core/constants/local_ai_replay_scenarios.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/explanation_copy_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/explanation_copy_diagnostics.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/localization_lint_diagnostics.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_replay_runner.dart';
import 'package:parkinsum_companion/domain/usecases/public_demo_walkthrough_generator.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

import 'helpers/golden_artifact.dart';
import 'helpers/local_ai_replay_harness.dart';

/// W2 — Cross-commit drift detection.
///
/// The existing determinism guards compare an artifact against a copy of
/// itself generated moments earlier in the same process. These compare it
/// against a **committed** baseline, which is what actually catches a
/// behaviour change between commits.
///
/// Refresh deliberately:
///   UPDATE_GOLDENS=1 flutter test test/goldens_test.dart
///
/// Educational prototype only; synthetic/demo data only.
void main() {
  String prettyJson(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  test('mechanistic replay report matches its golden', () {
    final report = MechanisticReplayRunner().run();
    expectGolden('mechanistic_replay.md', report.toMarkdown());

    // The full JSON is ~900 KB — too large to commit as a reviewable diff. A
    // per-case digest still catches any byte-level drift while naming the
    // exact scenario that moved; the Markdown golden above shows what changed.
    final json = report.toJson();
    final cases = (json['cases'] as List).cast<Map<String, dynamic>>();
    expectGolden(
      'mechanistic_replay.cases.digest',
      digestTable(
        rows: cases,
        idOf: (row) => '${row['scenario_id']}',
        canonicalOf: prettyJson,
      ),
    );
  });

  test('explanation copy compile report matches its golden', () {
    final report = compileRegistryWithSamples(
      registry: const SafeCopyTemplateRegistry(),
      compiler: const ExplanationCopyCompiler(),
    );
    expectGolden(
      'explanation_copy_compile.md',
      renderCopyCompileMarkdown(report),
    );
    expectGolden(
      'explanation_copy_compile.json',
      encodeCopyCompileReport(report),
    );
  });

  test('localization safety lint report matches its golden', () {
    final report = lintAllLocalizationSurfaces();
    expectGolden(
      'localization_lint.json',
      encodeLocalizationSafetyReport(report),
    );
  });

  test('public demo walkthrough matches its golden', () {
    // Fed the *real* replay report rather than a hand-written fixture, so this
    // golden covers the whole composition chain end to end.
    final replay = MechanisticReplayRunner().run().toJson();
    final walkthrough = const PublicDemoWalkthroughGenerator().build(
      PublicDemoWalkthroughInputs(
        replayReport: replay,
        capabilityMatrixSummary: 'see docs/CAPABILITY_MATRIX.md',
      ),
    );
    expectGolden('public_demo_walkthrough.md', walkthrough.toMarkdown());
  });

  test('local AI recommendation replay report matches its golden', () async {
    final report = await buildLocalAiReplayRunner().run(
      dataset: localAiReplayScenarioDataset,
    );
    expectGolden(
      'recommendation_scenario_replay.md',
      report.toReviewerMarkdown(archetypeNotes: localAiReplayArchetypeNotes),
    );
    expectGolden(
      'recommendation_scenario_replay.json',
      prettyJson(report.toJson()),
    );
  });

  test('rule explanation audit contract matches its golden', () async {
    // The W1 audit projection. Goldening it is what stops the audit trail from
    // quietly changing shape or losing a field.
    final service = ClinicalDecisionSupportService(
      database: InMemoryCdssDatabase(),
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    await service.initializeKnowledgeBase(
      sourceDocuments: clinicalEvidenceSourceDocuments,
      variantScopes: const <VariantScopeRecord>[],
      observations: const <ObservationRecord>[],
      resolvedFacts: const <ResolvedFactRecord>[],
    );
    final output = await service.run(
      context: UnifiedRuntimeContext(
        userProfile: const UserProfileRuntimeContext(
          patientId: 'synthetic_patient',
          registrationRegion: 'US',
          displayLocale: 'en-US',
          contentJurisdictionOverride: [],
          dietProfileRegion: 'US',
          timezone: 'America/Toronto',
        ),
        drug: const DrugRuntimeContext(
          id: 'synthetic_drug',
          genericName: 'carbidopa/levodopa',
          brandName: 'Sinemet',
          activeIngredients: ['carbidopa', 'levodopa'],
          substanceTags: ['levodopa'],
          formulation: 'tablet',
          dosageForm: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
          dailyDoseMg: null,
          jurisdiction: 'US',
        ),
        meal: const MealRuntimeContext(
          id: 'synthetic_meal',
          totalProteinG: 25,
          tyramineMgEstimate: 0,
          highFatHighCalorie: false,
          itemIds: ['synthetic_food'],
        ),
        coevent: null,
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.utc(2026, 1, 1, 8),
          mealTime: DateTime.utc(2026, 1, 1, 9),
          coeventTime: null,
        ),
      ),
      rules: RuleRegistryCompiler().compileJsonList(
        baselineCdssRules,
        rulesVersion: 'golden_rules',
      ),
      factsVersion: 'facts_v1',
      rulesVersion: 'rules_v1',
    );
    expectGolden(
      'rule_explanations.json',
      prettyJson(output.ruleExplanationsJson),
    );
  });
}
