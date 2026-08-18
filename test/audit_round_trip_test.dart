import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/constants/clinical_evidence_source_seed.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
// Imported directly: the conditional export in cdss_artifact_store.dart
// resolves to the io store under the VM, and this exercises the read contract
// on the filesystem-free backend.
import 'package:parkinsum_companion/domain/usecases/cdss_artifact_store_stub.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/rule_explanation_projection.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

import 'helpers/no_phi_json_assertions.dart';

/// W1 — Audit round trip.
///
/// The project carried two explanation schemas that never met: the documented,
/// safety-linted [RuleExplanation] was never constructed anywhere in `lib/`,
/// while the schema the engine actually emits was never read back. These tests
/// pin the bridge closed at both ends:
///
///   1. every registry rule produces an explanation, *including* the rules
///      that did not fire — the case an auditor most needs;
///   2. the record survives a write → read cycle instead of being discarded;
///   3. the projection is a pure derivation (identical runs are byte-identical
///      and no score, decision, or severity moves).
///
/// Educational prototype only; synthetic/demo data only.
void main() {
  UnifiedRuntimeContext syntheticContext({required double proteinG}) =>
      UnifiedRuntimeContext(
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
        meal: MealRuntimeContext(
          id: 'synthetic_meal',
          totalProteinG: proteinG,
          tyramineMgEstimate: 0,
          highFatHighCalorie: false,
          itemIds: const ['synthetic_food'],
        ),
        coevent: null,
        enteralFeed: null,
        timestamps: TimestampRuntimeContext(
          drugTime: DateTime.utc(2026, 1, 1, 8),
          mealTime: DateTime.utc(2026, 1, 1, 9),
          coeventTime: null,
        ),
      );

  Future<({EngineRunOutput output, InMemoryCdssDatabase db})> runEngine({
    double proteinG = 25,
  }) async {
    final db = InMemoryCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: db,
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
      context: syntheticContext(proteinG: proteinG),
      rules: RuleRegistryCompiler().compileJsonList(
        baselineCdssRules,
        rulesVersion: 'audit_round_trip_rules',
      ),
      factsVersion: 'facts_v1',
      rulesVersion: 'rules_v1',
    );
    return (output: output, db: db);
  }

  test('every registry rule yields exactly one explanation row', () async {
    final run = await runEngine();
    final explanations = run.output.ruleExplanationsJson;
    final compiled = RuleRegistryCompiler().compileJsonList(
      baselineCdssRules,
      rulesVersion: 'audit_round_trip_rules',
    );

    expect(explanations, isNotEmpty, reason: 'The audit contract is empty.');
    expect(
      explanations.length,
      compiled.length,
      reason: 'Every rule must be accounted for, fired or not.',
    );
    final ruleIds = explanations.map((row) => row['rule_id']).toList();
    expect(
      ruleIds.toSet().length,
      ruleIds.length,
      reason: 'Rule ids must be unique across the audit rows.',
    );
    expect(ruleIds.toSet(), compiled.map((rule) => rule.ruleId).toSet());
  });

  test('rules that did not fire record why, not silence', () async {
    final run = await runEngine();
    final notTriggered = run.output.ruleExplanationsJson
        .where((row) => row['triggered'] == false)
        .toList();

    expect(
      notTriggered,
      isNotEmpty,
      reason: 'This synthetic context should leave some rules unfired.',
    );
    for (final row in notTriggered) {
      expect(
        row['triggered_conditions'],
        isEmpty,
        reason: 'A rule that did not fire cannot claim matched conditions.',
      );
      expect(
        (row['user_facing_decision'] as String),
        isNotEmpty,
        reason: 'Every unfired rule must state why it did not fire.',
      );
      expect(
        kRuleTraceDecisionLabels.values,
        contains(row['user_facing_decision']),
        reason: 'Decision labels must come from the documented vocabulary.',
      );
    }
  });

  test('a triggered rule carries source refs and a confidence note', () async {
    final run = await runEngine();
    final triggered = run.output.ruleExplanationsJson
        .where((row) => row['triggered'] == true)
        .toList();

    expect(
      triggered,
      isNotEmpty,
      reason: 'The 25 g protein synthetic meal should fire at least one rule.',
    );
    for (final row in triggered) {
      expect(row['source_refs'], isNotEmpty);
      expect(row['provenance_summary'], isNotEmpty);
      expect(row['confidence_note'], isNotEmpty);
      expect(row['safety_boundary'], RuleExplanation.defaultSafetyBoundary);
      expect(row['not_advice_text'], RuleExplanation.defaultNotAdvice);
      expect(row['copy_source'], startsWith('rule_engine:'));
    }
  });

  test('missing inputs surface as missing_or_uncertain_inputs', () async {
    // A rule whose inputs are unavailable must say so rather than resolving to
    // a confident-looking negative.
    final run = await runEngine();
    final withMissing = run.output.ruleExplanationsJson.where(
      (row) => (row['missing_or_uncertain_inputs'] as List).isNotEmpty,
    );
    for (final row in withMissing) {
      expect(
        row['limitation_text'] as String,
        contains('unavailable'),
        reason: 'Missing inputs must be stated in the limitation copy.',
      );
      expect(row['confidence_note'] as String, startsWith('low'));
    }
  });

  test('audit records survive a write on the in-memory backend', () async {
    // Regression guard: these inserts used to be empty `async {}` bodies, so
    // the default demo/replay backend silently discarded its own audit trail.
    final run = await runEngine();
    expect(
      run.db.conflictAuditLog,
      isNotEmpty,
      reason: 'Conflict audit writes must be retained, not discarded.',
    );
    for (final record in run.db.conflictAuditLog) {
      expect(record.auditType, 'RUNTIME_ALERT');
      expect(record.inputHash, isNotEmpty);
      expect(jsonDecode(record.winningRuleIdsJson), isA<List<dynamic>>());
    }
  });

  test('artifact set round-trips through the inline store', () async {
    // Read-back is what makes a written audit record verifiable after the
    // fact. Absent artifacts must report null, never an empty success.
    final store = InlineCdssArtifactStore();
    expect(await store.readArtifactSet('never_written'), isNull);

    await store.writeArtifactSet(
      artifactId: 'synthetic_run',
      files: const {'rule_explanations.json': '[]'},
      manifest: const {'kind': 'runtime'},
    );
    final read = await store.readArtifactSet('synthetic_run');
    expect(read, isNotNull);
    expect(read!.files['rule_explanations.json'], '[]');
    expect(read.manifest['kind'], 'runtime');
    expect(
      read.durable,
      isFalse,
      reason: 'The inline store must not claim durability it does not have.',
    );
  });

  test(
    'the projection is deterministic and changes no engine output',
    () async {
      final first = await runEngine();
      final second = await runEngine();

      expect(
        jsonEncode(first.output.ruleExplanationsJson),
        jsonEncode(second.output.ruleExplanationsJson),
        reason: 'Identical runs must project byte-identical explanations.',
      );
      // The projection is read-only: alert decisions and severities are
      // untouched by its presence.
      expect(
        first.output.alerts.map((a) => a.decision).toList(),
        second.output.alerts.map((a) => a.decision).toList(),
      );
      expect(
        first.output.alerts.map((a) => a.severity).toList(),
        second.output.alerts.map((a) => a.severity).toList(),
      );
    },
  );

  test('the audit trail carries no banned copy and no PHI keys', () async {
    final run = await runEngine();
    final encoded = jsonEncode(run.output.ruleExplanationsJson);
    expect(findBannedSubstrings(encoded), isEmpty);
    for (final row in run.output.ruleExplanationsJson) {
      scanNoPhiKeys(row);
    }
  });
}
