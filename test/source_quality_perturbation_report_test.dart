import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
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
    expect(official.conflictOverlapScore,
        closeTo(synthetic.conflictOverlapScore, 1e-9));
    expect(official.finalCandidateScore,
        greaterThanOrEqualTo(synthetic.finalCandidateScore));
    expect(official.sourceAuthorityScore,
        greaterThan(synthetic.sourceAuthorityScore));
  });

  test('missing sourceRefs lowers provenance quality (and the score)', () {
    final r = runner.run();
    final missing = r.byCase('prov_missing_source_refs');
    final official = r.byCase('prov_official_in_jurisdiction');
    // Identical authority/jurisdiction + identical conflict input; missing
    // sourceRefs drops provenance quality + completeness, so the score is lower.
    expect(missing.conflictOverlapScore,
        closeTo(official.conflictOverlapScore, 1e-9));
    expect(missing.finalCandidateScore, lessThan(official.finalCandidateScore));
  });

  test('imputed/assumed amino-acid tier widens uncertainty vs analytical', () {
    final r = runner.run();
    final analytical = r.byCase('aa_analytical');
    final imputed = r.byCase('aa_imputedOrAssumed');
    // Same composition + overlap; only the amino-acid provenance tier differs.
    expect(analytical.lnaaUncertaintyWidened, isFalse);
    expect(imputed.lnaaUncertaintyWidened, isTrue);
    expect(analytical.competitionUncertaintyBand, 'narrow');
    expect(imputed.competitionUncertaintyBand, isNot('narrow'));
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

  test('every scored row uses the mechanistic-primary ranker', () {
    for (final row in runner.run().rows) {
      expect(row.rankerUsed, 'mechanistic_primary_window_sampled');
    }
  });
}
