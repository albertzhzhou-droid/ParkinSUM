import 'recommendation_benchmark_models.dart';

class RecommendationReplayCaseReport {
  final RecommendationBenchmarkCase benchmarkCase;
  final List<String> deterministicRanking;
  final List<String> aiRanking;
  final bool aiUsed;
  final String decisionPath;
  final List<String> gateReasons;
  final List<String> explanations;
  final List<String> rankingDiffs;
  final List<String> matchedExpectedTopFoodIds;
  final List<String> missingExpectedTopFoodIds;

  const RecommendationReplayCaseReport({
    required this.benchmarkCase,
    required this.deterministicRanking,
    required this.aiRanking,
    required this.aiUsed,
    required this.decisionPath,
    required this.gateReasons,
    required this.explanations,
    required this.rankingDiffs,
    required this.matchedExpectedTopFoodIds,
    required this.missingExpectedTopFoodIds,
  });

  String toMarkdown() {
    final lines = <String>[
      '## ${benchmarkCase.caseId} · ${benchmarkCase.title}',
      'Deterministic ranking: ${deterministicRanking.join(' -> ')}',
      'AI ranking: ${aiRanking.join(' -> ')}',
      'Decision path: $decisionPath',
      'AI used: ${aiUsed ? 'yes' : 'no'}',
      'Gate reasons: ${gateReasons.isEmpty ? 'none' : gateReasons.join(' | ')}',
      'Expected top ids matched: ${matchedExpectedTopFoodIds.isEmpty ? 'none' : matchedExpectedTopFoodIds.join(', ')}',
      'Expected top ids missing: ${missingExpectedTopFoodIds.isEmpty ? 'none' : missingExpectedTopFoodIds.join(', ')}',
      'Ranking diffs: ${rankingDiffs.isEmpty ? 'none' : rankingDiffs.join(' | ')}',
    ];
    if (explanations.isNotEmpty) {
      lines.add('Explanations: ${explanations.join(' | ')}');
    }
    return lines.join('\n');
  }

  /// Deterministic, no-PHI structured snapshot for replay/drift comparison.
  /// Excludes any wall-clock timestamp so two runs of the same scenario set
  /// produce byte-identical JSON.
  Map<String, dynamic> toJson() => {
        'case_id': benchmarkCase.caseId,
        'title': benchmarkCase.title,
        'focus_tags': benchmarkCase.focusTags,
        'deterministic_ranking': deterministicRanking,
        'ai_ranking': aiRanking,
        'ai_used': aiUsed,
        'decision_path': decisionPath,
        'gate_reasons': gateReasons,
        'ranking_diffs': rankingDiffs,
        'matched_expected_top_food_ids': matchedExpectedTopFoodIds,
        'missing_expected_top_food_ids': missingExpectedTopFoodIds,
        // Safety invariant: the AI path may only reorder the deterministic
        // candidate set; it must never add or drop a candidate.
        'ai_preserved_candidate_set': _sortedEquals(
          deterministicRanking,
          aiRanking,
        ),
      };

  static bool _sortedEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }
}

class RecommendationReplayRunReport {
  final String generatedAtIso;
  final String datasetVersion;
  final List<RecommendationReplayCaseReport> cases;

  const RecommendationReplayRunReport({
    required this.generatedAtIso,
    required this.datasetVersion,
    required this.cases,
  });

  String toMarkdown() => [
        '# Recommendation Replay Report',
        'Generated at: $generatedAtIso',
        'Dataset version: $datasetVersion',
        '',
        ...cases.map((item) => item.toMarkdown()),
      ].join('\n\n');

  /// Whether every case preserved the deterministic candidate set under the AI
  /// path (a coarse, scenario-level Local-AI safety invariant).
  bool get allPreservedCandidateSet =>
      cases.every((c) => c.toJson()['ai_preserved_candidate_set'] == true);

  /// Deterministic structured snapshot. `generated_at` is intentionally
  /// excluded from [cases] so the case array is stable across runs; callers
  /// that need provenance can read [datasetVersion].
  Map<String, dynamic> toJson() => {
        'report_type': 'recommendation_scenario_replay',
        'dataset_version': datasetVersion,
        'no_medical_advice': true,
        'cases': cases.map((c) => c.toJson()).toList(growable: false),
      };
}
