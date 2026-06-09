import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/local_ai_replay_scenarios.dart';
import 'package:parkinsum_companion/domain/entities/recommendation_replay_models.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';

import 'helpers/local_ai_replay_harness.dart';

/// Reviewer-friendly replay report workflow.
///
/// Running this file is the one-command way to (re)generate and verify the
/// deterministic reviewer artifact for the five Local-AI replay archetypes:
///
///   flutter test test/local_ai_replay_report_test.dart
///
/// It writes `build/recommendation_scenario_replay/latest.json` and
/// `latest.md` (both timestamp-free, so regenerated artifacts diff cleanly)
/// and asserts the report's content, determinism, and safety-copy hygiene.
/// Educational prototype only; synthetic fixtures; no PHI.
void main() {
  const outDirPath = 'build/recommendation_scenario_replay';

  Future<RecommendationReplayRunReport> generate() =>
      buildLocalAiReplayRunner().run(dataset: localAiReplayScenarioDataset);

  String jsonOf(RecommendationReplayRunReport r) =>
      const JsonEncoder.withIndent('  ').convert(r.toJson());

  String markdownOf(RecommendationReplayRunReport r) =>
      r.toReviewerMarkdown(archetypeNotes: localAiReplayArchetypeNotes);

  test('writes the deterministic reviewer artifact (JSON + Markdown)',
      () async {
    final report = await generate();
    final outDir = Directory(outDirPath);
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    File('$outDirPath/latest.json').writeAsStringSync(jsonOf(report));
    File('$outDirPath/latest.md').writeAsStringSync(markdownOf(report));

    expect(File('$outDirPath/latest.json').existsSync(), isTrue);
    expect(File('$outDirPath/latest.md').existsSync(), isTrue);
  });

  test('report covers all five archetypes with the required fields', () async {
    final report = await generate();
    final md = markdownOf(report);
    final json = jsonDecode(jsonOf(report)) as Map<String, dynamic>;

    expect((json['cases'] as List), hasLength(5));
    for (final caseId in const [
      'replay_missing_medication_time_or_dose',
      'replay_low_risk_next_meal',
      'replay_source_fallback_partial_provenance',
      'replay_safety_gate_blocks_local_ai',
      'replay_medication_catalog_selection_context',
    ]) {
      expect(md, contains('## $caseId'),
          reason: 'Markdown is missing the $caseId section');
    }
    // Every archetype note is surfaced for its case.
    for (final note in localAiReplayArchetypeNotes.values) {
      expect(md, contains(note.split('. ').first),
          reason: 'Markdown is missing an archetype explanation');
    }
    // Per-case required fields exist in the JSON snapshot.
    for (final raw in json['cases'] as List) {
      final c = raw as Map<String, dynamic>;
      for (final key in const [
        'case_id',
        'focus_tags',
        'deterministic_ranking',
        'ai_ranking',
        'decision_path',
        'ai_used',
        'gate_reasons',
        'ai_preserved_candidate_set',
        'matched_expected_top_food_ids',
        'missing_expected_top_food_ids',
      ]) {
        expect(c.containsKey(key), isTrue,
            reason: 'JSON case ${c['case_id']} is missing `$key`');
      }
    }
  });

  test('reviewer Markdown is deterministic across runs (drift guard)',
      () async {
    final a = markdownOf(await generate());
    final b = markdownOf(await generate());
    expect(a, b, reason: 'Reviewer Markdown drifted between identical runs.');
    // No wall-clock leakage: the deterministic artifacts must not embed a
    // generated-at timestamp.
    expect(a, isNot(contains('Generated at')));
    expect(a, isNot(contains(RegExp(r'20\d{2}-\d{2}-\d{2}T'))));
  });

  test('report contains no banned prescriptive or public-claim phrases',
      () async {
    final report = await generate();
    final blob = '${markdownOf(report)}\n${jsonOf(report)}';
    expect(findBannedSubstrings(blob), isEmpty,
        reason: 'Replay report contains banned prescriptive copy.');
    for (final phrase in const [
      'clinically validated',
      'medical device',
      'patient-calibrated',
      'safe for you',
    ]) {
      expect(blob.toLowerCase(), isNot(contains(phrase)),
          reason: 'Replay report contains public-claim phrase "$phrase".');
    }
  });

  test('candidate-set invariant and gate reasons are visible to reviewers',
      () async {
    final report = await generate();
    final md = markdownOf(report);

    // The invariant is stated up front and per case.
    expect(md, contains('Candidate-set invariant held for all cases: **yes**'));
    expect('AI preserved candidate set'.allMatches(md).length,
        greaterThanOrEqualTo(5));
    expect(md, isNot(contains('invariant violated')));

    // Blocked scenarios surface their gate reasons in the Markdown.
    for (final c in report.cases.where((c) => c.gateReasons.isNotEmpty)) {
      for (final reason in c.gateReasons) {
        expect(md, contains(reason),
            reason:
                '${c.benchmarkCase.caseId} gate reason missing from Markdown');
      }
    }
    // And the two gate-blocked archetypes are visibly non-AI-reranked.
    final gated = report.cases.firstWhere(
        (c) => c.benchmarkCase.caseId == 'replay_safety_gate_blocks_local_ai');
    expect(gated.gateReasons, isNotEmpty);
    expect(
        md, contains('the deterministic gate held the conservative ranking'));
  });
}
