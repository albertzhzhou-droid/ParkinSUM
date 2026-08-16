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

  /// Safety invariant: the AI path may only reorder the deterministic
  /// candidate set; it must never add or drop a candidate. False here means
  /// a candidate id was invented or lost between the two paths.
  bool get aiPreservedCandidateSet =>
      _sortedEquals(deterministicRanking, aiRanking);

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
    'ai_preserved_candidate_set': aiPreservedCandidateSet,
  };

  /// One reviewer-facing section per case: every audit-relevant field plus a
  /// short safety note. [archetypeNote] explains what the archetype represents
  /// and why Local AI is expected to be allowed or blocked.
  String toReviewerMarkdown({String? archetypeNote}) {
    final aiBlocked = !aiUsed || gateReasons.isNotEmpty;
    final lines = <String>[
      '## ${benchmarkCase.caseId}',
      '',
      '**${benchmarkCase.title}**',
      '',
      if (archetypeNote != null && archetypeNote.isNotEmpty) ...[
        '_Archetype:_ $archetypeNote',
        '',
      ],
      '| Field | Value |',
      '| --- | --- |',
      '| Focus tags | ${benchmarkCase.focusTags.join(', ')} |',
      '| Deterministic ranking | ${deterministicRanking.join(' → ')} |',
      '| AI ranking | ${aiRanking.join(' → ')} |',
      '| Decision path | `$decisionPath` |',
      '| Local AI used | ${aiUsed ? 'yes' : 'no'} |',
      '| Gate reasons | ${gateReasons.isEmpty ? 'none' : gateReasons.join(' / ')} |',
      '| AI preserved candidate set | ${aiPreservedCandidateSet ? 'yes' : '**NO — invariant violated**'} |',
      '| Expected top ids matched | ${matchedExpectedTopFoodIds.isEmpty ? 'none' : matchedExpectedTopFoodIds.join(', ')} |',
      '| Expected top ids missing | ${missingExpectedTopFoodIds.isEmpty ? 'none' : missingExpectedTopFoodIds.join(', ')} |',
      '',
      aiBlocked
          ? '_Local AI was limited to wording polish here: '
                '${gateReasons.isEmpty ? 'the AI path was not engaged.' : 'the deterministic gate held the conservative ranking.'}_'
          : '_Local AI was allowed to reorder the safe whitelist only; the '
                'deterministic candidate set and decisions stayed authoritative._',
      '',
      '_Safety note: synthetic educational fixture. Deterministic rules remain '
          'the source of truth; this report is engineering review material and '
          'not medical advice._',
    ];
    return lines.join('\n');
  }

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
      cases.every((c) => c.aiPreservedCandidateSet);

  /// Reviewer-facing Markdown report. Deterministic: it intentionally carries
  /// no wall-clock timestamp, so two runs over the same dataset are
  /// byte-identical (any diff in the artifact is real behaviour drift).
  ///
  /// [archetypeNotes] maps a case's first focus tag to a short explanation of
  /// what the archetype represents and why Local AI is allowed or blocked.
  String toReviewerMarkdown({
    Map<String, String> archetypeNotes = const <String, String>{},
  }) {
    final buffer = StringBuffer()
      ..writeln('# Local AI Scenario Replay — Reviewer Report')
      ..writeln()
      ..writeln('Dataset version: `$datasetVersion`')
      ..writeln()
      ..writeln(
        'Educational prototype; synthetic fixtures only. This replay '
        'runs the same conservative + hybrid recommendation orchestrators '
        'the app uses, with an offline scripted Local AI stand-in. It is '
        'engineering review material, not medical advice and not a '
        'clinical evaluation.',
      )
      ..writeln()
      ..writeln('## How to read this report')
      ..writeln()
      ..writeln(
        '- **Invariant checked:** the Local AI path may only *reorder* '
        'the deterministic candidate whitelist. "AI preserved candidate '
        'set: yes" means no candidate was invented or dropped; a "NO" '
        'means the safety invariant was violated and the run fails.',
      )
      ..writeln(
        '- **Gate reasons:** when present, the deterministic safety '
        'gate held the conservative ranking and Local AI was limited to '
        'wording polish.',
      )
      ..writeln(
        '- **Drift:** this artifact is timestamp-free and '
        'deterministic. If a regenerated report differs from the committed '
        'or previously reviewed one, engine/gate/scenario behaviour '
        'changed and the diff should be reviewed, not regenerated away.',
      )
      ..writeln()
      ..writeln(
        'Candidate-set invariant held for all cases: '
        '**${allPreservedCandidateSet ? 'yes' : 'NO'}**',
      )
      ..writeln();
    for (final c in cases) {
      final tag = c.benchmarkCase.focusTags.isEmpty
          ? ''
          : c.benchmarkCase.focusTags.first;
      buffer
        ..writeln(c.toReviewerMarkdown(archetypeNote: archetypeNotes[tag]))
        ..writeln();
    }
    return buffer.toString();
  }

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
