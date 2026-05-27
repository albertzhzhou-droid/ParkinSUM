import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/features/shared/mechanistic_trace_view.dart';

void main() {
  test(
      'fromJson populates score, severity, confidence, drivers, and refs '
      'label', () {
    final view = MechanisticTraceViewModel.fromJson({
      'interaction_score': 0.32,
      'severity_band': 'moderate',
      'confidence_band': 'medium',
      'primary_drivers': ['amino_acid_competition_proxy_moderate'],
      'modeled_timeline_windows': [
        {'start_minute': 0, 'end_minute': 90}
      ],
      'uncertainty_reasons': ['meal_composition_incomplete'],
      'limitation_text': 'Educational only.',
      'safety_boundary': RuleExplanation.defaultSafetyBoundary,
      'not_advice_text': RuleExplanation.defaultNotAdvice,
      'source_refs': ['src.dailymed.sinemet.label'],
    });
    expect(view.scoreText, '0.32');
    expect(view.severityLabel, 'moderate');
    expect(view.confidenceLabel, 'medium');
    expect(
        view.primaryDrivers, contains('amino_acid_competition_proxy_moderate'));
    expect(view.sourceRefsLabel, contains('Sources (1)'));
  });

  test('no banned substrings appear in formatted output', () {
    final view = MechanisticTraceViewModel.fromJson({
      'interaction_score': 0.0,
      'severity_band': 'none',
      'confidence_band': 'high',
      'primary_drivers': [],
      'modeled_timeline_windows': [],
      'uncertainty_reasons': [],
      'limitation_text': 'Educational only.',
      'safety_boundary': RuleExplanation.defaultSafetyBoundary,
      'not_advice_text': RuleExplanation.defaultNotAdvice,
      'source_refs': [],
    });
    final blob = [
      view.scoreText,
      view.severityLabel,
      view.confidenceLabel,
      view.limitationText,
      view.safetyBoundary,
      view.notAdviceText,
      view.sourceRefsLabel,
    ].join(' ');
    expect(findBannedSubstrings(blob), isEmpty);
  });

  test('empty source refs label says "none recorded"', () {
    final view = MechanisticTraceViewModel.fromJson({
      'interaction_score': 0.0,
      'severity_band': 'none',
      'confidence_band': 'high',
      'primary_drivers': [],
      'modeled_timeline_windows': [],
      'uncertainty_reasons': [],
      'limitation_text': '',
      'safety_boundary': RuleExplanation.defaultSafetyBoundary,
      'not_advice_text': RuleExplanation.defaultNotAdvice,
      'source_refs': [],
    });
    expect(view.sourceRefsLabel, contains('none recorded'));
  });
}
