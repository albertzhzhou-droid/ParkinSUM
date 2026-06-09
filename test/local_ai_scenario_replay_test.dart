import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/local_ai_replay_scenarios.dart';

import 'helpers/local_ai_replay_harness.dart';

/// P1 — Synthetic scenario replay system.
///
/// Replays the five fixed Local-AI scenario archetypes through the real
/// deterministic + hybrid orchestrators with an offline, scripted Local AI
/// (see `helpers/local_ai_replay_harness.dart`). Asserts per-archetype decision
/// paths, a Local-AI safety invariant (the AI path may only reorder the
/// deterministic candidate set), and that the structured JSON snapshot is
/// byte-stable across runs (drift guard). Educational prototype only;
/// synthetic fixtures; no PHI.
void main() {
  test('replays the five archetypes with expected decision paths', () async {
    final report = await buildLocalAiReplayRunner()
        .run(dataset: localAiReplayScenarioDataset);
    expect(report.cases, hasLength(5));

    final byId = {for (final c in report.cases) c.benchmarkCase.caseId: c};

    // 1 — missing medication time/dose ⇒ conservative safety gate, gate reasons.
    final missing = byId['replay_missing_medication_time_or_dose']!;
    expect(missing.decisionPath, 'conservative_safety_gate');
    expect(missing.gateReasons, isNotEmpty);

    // 2 — low-risk next meal ⇒ Local AI rerank allowed.
    final lowRisk = byId['replay_low_risk_next_meal']!;
    expect(lowRisk.decisionPath, 'hybrid_local_ai');
    expect(lowRisk.aiUsed, isTrue);
    expect(lowRisk.rankingDiffs, isNotEmpty);

    // 3 — source fallback (AI disabled) ⇒ conservative deterministic path.
    final fallback = byId['replay_source_fallback_partial_provenance']!;
    expect(fallback.decisionPath, 'conservative_cdss');
    expect(fallback.aiUsed, isFalse);

    // 4 — levodopa-sensitive window ⇒ safety gate blocks reranking.
    final gated = byId['replay_safety_gate_blocks_local_ai']!;
    expect(gated.decisionPath, 'conservative_safety_gate');
    expect(gated.gateReasons, isNotEmpty);

    // 5 — medication catalog selection with safe candidates ⇒ AI path.
    final catalog = byId['replay_medication_catalog_selection_context']!;
    expect(catalog.decisionPath, 'hybrid_local_ai');
    expect(catalog.aiUsed, isTrue);
  });

  test('Local AI never changes the deterministic candidate set (safety)',
      () async {
    final report = await buildLocalAiReplayRunner()
        .run(dataset: localAiReplayScenarioDataset);
    expect(report.allPreservedCandidateSet, isTrue);
    for (final c in report.cases) {
      // Whatever the AI did, the resulting set of food ids equals the
      // deterministic set (reorder-only; never invent or drop).
      expect(c.aiRanking.toSet(), c.deterministicRanking.toSet(),
          reason: '${c.benchmarkCase.caseId} changed the candidate set');
      expect(c.aiPreservedCandidateSet, isTrue);
    }
  });

  test('structured JSON snapshot is byte-stable across runs (drift guard)',
      () async {
    final first = await buildLocalAiReplayRunner()
        .run(dataset: localAiReplayScenarioDataset);
    final second = await buildLocalAiReplayRunner()
        .run(dataset: localAiReplayScenarioDataset);
    final a = const JsonEncoder.withIndent('  ').convert(first.toJson());
    final b = const JsonEncoder.withIndent('  ').convert(second.toJson());
    expect(a, b, reason: 'Replay output drifted between identical runs.');
    // Sanity: snapshot carries the dataset version and all five cases.
    final decoded = jsonDecode(a) as Map<String, dynamic>;
    expect(decoded['dataset_version'], localAiReplayScenarioDataset.version);
    expect((decoded['cases'] as List), hasLength(5));
  });
}
