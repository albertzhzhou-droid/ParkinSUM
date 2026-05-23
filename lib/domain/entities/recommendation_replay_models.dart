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
}
