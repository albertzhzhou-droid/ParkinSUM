import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_scoring_parameters.dart';
import 'package:parkinsum_companion/domain/usecases/source_quality_perturbation_report.dart';

/// P4 — source-quality perturbation report. Deterministic educational analysis
/// of how candidate scoring moves when ONLY source/provenance quality changes,
/// holding the meal/conflict/model input constant. Asserts the safety
/// invariants: better provenance never hurts, conflict overlap stays dominant,
/// weaker amino-acid provenance widens uncertainty, and no advice copy leaks.
void main() {
  final runner = SourceQualityPerturbationReportRunner();

  test('report is generated deterministically', () {
    final a = encodeSourceQualityReport(runner.run());
    final b = encodeSourceQualityReport(runner.run());
    expect(a, b);
    expect(runner.run().rows, isNotEmpty);
  });

  test('official in-jurisdiction is not lower than synthetic equivalent', () {
    final r = runner.run();
    final official = r.byCase('prov_official_in_jurisdiction');
    final synthetic = r.byCase('prov_synthetic_demo');
    // Same meal/conflict input; only provenance differs.
    expect(
      official.conflictOverlapScore,
      closeTo(synthetic.conflictOverlapScore, 1e-9),
    );
    expect(
      official.finalCandidateScore,
      greaterThanOrEqualTo(synthetic.finalCandidateScore),
    );
    expect(
      official.sourceAuthorityScore,
      greaterThan(synthetic.sourceAuthorityScore),
    );
  });

  test('missing sourceRefs lowers provenance quality (and the score)', () {
    final r = runner.run();
    final missing = r.byCase('prov_missing_source_refs');
    final official = r.byCase('prov_official_in_jurisdiction');
    // Identical authority/jurisdiction + identical conflict input; missing
    // sourceRefs drops provenance quality + completeness, so the score is lower.
    expect(
      missing.conflictOverlapScore,
      closeTo(official.conflictOverlapScore, 1e-9),
    );
    expect(missing.finalCandidateScore, lessThan(official.finalCandidateScore));
  });

  test('imputed/assumed amino-acid tier widens uncertainty vs analytical', () {
    final r = runner.run();
    final analytical = r.byCase('aa_analytical');
    final imputed = r.byCase('aa_imputedOrAssumed');
    // Same composition + overlap; only the amino-acid provenance tier differs.
    expect(analytical.lnaaUncertaintyWidened, isFalse);
    expect(imputed.lnaaUncertaintyWidened, isTrue);
    // Analytical nutrient provenance does not imply narrow overall model
    // uncertainty: the fixed historical-meal/timing context still contributes
    // its own uncertainty. The provenance perturbation must widen the combined
    // band relative to that same baseline.
    const uncertaintyOrder = ['narrow', 'moderate', 'wide', 'veryWide'];
    expect(
      uncertaintyOrder.indexOf(imputed.competitionUncertaintyBand),
      greaterThan(
        uncertaintyOrder.indexOf(analytical.competitionUncertaintyBand),
      ),
    );
  });

  test('conflict overlap stays dominant: provenance swing is bounded', () {
    // Two identical-composition candidates (same conflict overlap) differing
    // ONLY in provenance (best vs worst). The provenance-driven score swing is
    // bounded by the summed provenance weights, which the conflict-dominant
    // invariant keeps strictly below the conflict-overlap weight. So provenance
    // can refine ranking but can never overpower a substantial conflict gap.
    final t = runner.tieBreakByProvenance();
    final swing = t.better - t.worse;
    final params = NextMealScoringParameterSet.literatureInformedDefault();
    expect(swing, greaterThanOrEqualTo(0.0));
    expect(swing, lessThanOrEqualTo(params.provenanceWeightSum + 1e-9));
    expect(params.provenanceWeightSum, lessThan(params.conflictOverlap.value));
  });

  test('provenance breaks ties when conflict scores are close', () {
    // Identical-composition candidates differing ONLY in provenance: the better
    // provenance ranks strictly higher than the worst (a bounded refinement).
    final t = runner.tieBreakByProvenance();
    expect(t.better, greaterThan(t.worse));
  });

  test('report contains no medical-advice phrasing', () {
    final report = runner.run();
    final json = encodeSourceQualityReport(report);
    final md = report.toMarkdown();
    expect(findBannedSubstrings(json), isEmpty);
    expect(findBannedSubstrings(md), isEmpty);
    // Every row carries the shared safety boundary + not-calibrated marker.
    for (final row in report.rows) {
      expect(row.safetyBoundary, RuleExplanation.defaultSafetyBoundary);
      expect(row.notClinicallyCalibrated, isTrue);
    }
  });

  test('every scored row is labeled as an educational trace', () {
    for (final row in runner.run().rows) {
      expect(row.rankerUsed, 'mechanistic_trace_only_window_sampled');
      expect(row.finalCandidateScore, greaterThan(0));
    }
  });

  test(
    'unexpected scorer abstention fails closed instead of emitting zero',
    () {
      final abstainingRunner = SourceQualityPerturbationReportRunner(
        scorer: MechanisticNextMealScorer(engine: _AlwaysAbstainingEngine()),
      );

      expect(
        abstainingRunner.run,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('unexpectedly abstained'),
          ),
        ),
      );
    },
  );

  // P5 — FDC provenance tier fields exposed in the report rows + JSON.
  test('rows expose nutrient-provenance + confidence fields (P5)', () {
    final report = runner.run();
    final json = jsonDecode(encodeSourceQualityReport(report)) as Map;
    final firstRow = (json['rows'] as List).first as Map;
    for (final key in const [
      'nutrient_confidence_tier',
      'nutrient_provenance_quality',
      'provenance_quality_score',
      'confidence_band',
      'metadata_completeness_score',
    ]) {
      expect(firstRow.containsKey(key), isTrue, reason: 'missing $key');
    }
    // Nutrient provenance quality is ordered by tier (analytical > imputed).
    final analytical = report.byCase('aa_analytical').nutrientProvenanceQuality;
    final imputed = report
        .byCase('aa_imputedOrAssumed')
        .nutrientProvenanceQuality;
    final unknown = report.byCase('aa_unknown').nutrientProvenanceQuality;
    expect(analytical, greaterThan(imputed));
    expect(imputed, greaterThan(unknown));
  });

  test(
    'source authority and nutrient-provenance tier move independently (P5)',
    () {
      final report = runner.run();
      final synthAnalytical = report.byCase(
        'mix_synthetic_source_analytical_provenance',
      );
      final officialImputed = report.byCase(
        'mix_official_source_imputed_provenance',
      );
      // Synthetic source but analytical nutrient provenance: low authority, high
      // nutrient provenance quality.
      expect(synthAnalytical.sourceAuthorityScore, lessThan(0.5));
      expect(synthAnalytical.nutrientProvenanceQuality, 1.0);
      // Official source but imputed nutrient provenance: high authority, low
      // nutrient provenance quality. The two axes do not collapse into each other.
      expect(officialImputed.sourceAuthorityScore, greaterThan(0.5));
      expect(officialImputed.nutrientProvenanceQuality, lessThan(0.5));
    },
  );
}

class _AlwaysAbstainingEngine extends MechanisticConflictEngine {
  @override
  MechanisticConflictResult evaluate({
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    String resultId = 'mechanistic_result',
    String? preferredMealId,
  }) => MechanisticConflictResult.insufficientContext(
    id: resultId,
    reason: MechanisticInteractionType.insufficientMealContext,
    missingInputs: const ['synthetic_forced_abstention'],
    sourceRefs: const ['synthetic:test'],
  );
}
