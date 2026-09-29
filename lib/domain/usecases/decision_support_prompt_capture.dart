import '../entities/cdss_runtime.dart';
import '../entities/decision_support_followup.dart';
import '../entities/runtime_context.dart';

/// Captures only actionable bookkeeping from the exact deterministic run.
/// Neither a generated evaluation id nor the current clock enters identity.
List<DecisionSupportPrompt> captureDecisionSupportPrompts({
  required EngineRunOutput output,
  required UnifiedRuntimeContext context,
  required String sourceRecordId,
  required String candidateId,
  required DateTime createdAt,
}) {
  final traces = (output.alertsJson['rule_hit_trace'] as List? ?? const [])
      .whereType<Map>()
      .toList();
  final snapshot = Map<String, Object?>.from(
    output.alertsJson['snapshot'] as Map? ?? const {},
  );
  final prompts = <DecisionSupportPrompt>[];
  for (final alert in output.alerts) {
    if (alert.decision == RuntimeDecisionType.allow ||
        alert.decision == RuntimeDecisionType.info) {
      continue;
    }
    final audits = output.auditEntries.where((a) => a.target == alert.target);
    final ids = audits.expand((a) => a.winningRuleIds).toSet().toList()..sort();
    final ruleIds = ids.isEmpty ? ['runtime_context_gate'] : ids;
    for (final ruleId in ruleIds) {
      final matchedTrace = traces.where((t) => t['rule_id'] == ruleId);
      final version = ruleId == 'runtime_context_gate' && ids.isEmpty
          ? 'runtime_context_gate_v1'
          : matchedTrace.isEmpty
          ? null
          : matchedTrace.first['rule_version'] as String?;
      // A missing actual version is not promoted to the requested version.
      if (version == null || version.isEmpty) continue;
      final explanations = output.ruleExplanationsJson.where(
        (row) => row['rule_id'] == ruleId,
      );
      final missing =
          explanations
              .expand(
                (row) =>
                    (row['missing_or_uncertain_inputs'] as List? ?? const [])
                        .whereType<String>(),
              )
              .toSet()
              .toList()
            ..sort();
      prompts.add(
        DecisionSupportPrompt.create(
          ownerScope: context.userProfile.patientId,
          ruleId: ruleId,
          ruleVersion: version,
          sourceRecordId: sourceRecordId,
          candidateId: '$candidateId:${alert.target}',
          inputSnapshot: {
            'runtimeContext': context.toJson(),
            'knowledgeSnapshot': snapshot,
            'decision': alert.decision.wireValue,
            'sourceRefs': [...alert.evidenceSources]..sort(),
          },
          title: alert.target,
          explanation: alert.explanation,
          sourceRefs: alert.evidenceSources,
          missingInputs: missing,
          createdAt: createdAt,
        ),
      );
    }
  }
  return List.unmodifiable(prompts);
}
