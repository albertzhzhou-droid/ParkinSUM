/// P5 — synthetic scenario fuzzer entities.
///
/// Educational/research prototype only. **Synthetic data only.** This is a
/// deterministic regression/stress-testing tool — NOT a clinical simulator, NOT
/// patient generation, NOT clinical validation, NOT clinically calibrated, and
/// NOT medical advice. It emits no PHI and no patient/subject/encounter
/// semantics. It generates boundary-case inputs and checks that ParkinSUM's
/// existing deterministic gates respond in a stable, non-prescriptive way.
library;

/// Scenario families exercised by the fuzzer.
enum SyntheticScenarioFamily {
  medicationDosage, // A
  mealMissingness, // B
  releaseTimeline, // C
  sourceQuality, // D
  windowRanking, // E
  safetyCopyNoPhi, // F
}

extension SyntheticScenarioFamilyName on SyntheticScenarioFamily {
  String get id => switch (this) {
        SyntheticScenarioFamily.medicationDosage => 'medication_dosage',
        SyntheticScenarioFamily.mealMissingness => 'meal_missingness',
        SyntheticScenarioFamily.releaseTimeline => 'release_timeline',
        SyntheticScenarioFamily.sourceQuality => 'source_quality',
        SyntheticScenarioFamily.windowRanking => 'window_ranking',
        SyntheticScenarioFamily.safetyCopyNoPhi => 'safety_copy_no_phi',
      };
}

/// Failure categories the evaluator can record (never thrown for data issues).
class SyntheticScenarioFailureCategory {
  static const String unexpectedRankerSwitch = 'unexpected_ranker_switch';
  static const String missingnessRegression = 'missingness_regression';
  static const String dosageRegression = 'dosage_regression';
  static const String sourceQualityRegression = 'source_quality_regression';
  static const String unsafePhraseHit = 'unsafe_phrase_hit';
  static const String phiKeyHit = 'phi_key_hit';
  static const String missingArtifact = 'missing_artifact';
  static const String unexpectedException = 'unexpected_exception';
}

class SyntheticScenarioFuzzerConfig {
  final int seed;
  final int caseCount;
  final Set<SyntheticScenarioFamily> enabledFamilies;
  final int maxMutationsPerCase;
  final bool includeUnsafePhraseProbe;
  final bool includeNoPhiProbe;
  final String deterministicTimestamp;

  const SyntheticScenarioFuzzerConfig({
    this.seed = 1,
    // Default covers the full catalog (clamped to the available count). A smaller
    // caseCount deterministically samples a seed-ordered subset.
    this.caseCount = 64,
    this.enabledFamilies = const {
      SyntheticScenarioFamily.medicationDosage,
      SyntheticScenarioFamily.mealMissingness,
      SyntheticScenarioFamily.releaseTimeline,
      SyntheticScenarioFamily.sourceQuality,
      SyntheticScenarioFamily.windowRanking,
      SyntheticScenarioFamily.safetyCopyNoPhi,
    },
    this.maxMutationsPerCase = 2,
    this.includeUnsafePhraseProbe = true,
    this.includeNoPhiProbe = true,
    this.deterministicTimestamp = 'synthetic-demo',
  });
}

class SyntheticScenarioMutation {
  final String mutationId;
  final String field;
  final String from;
  final String to;
  final String reason;
  final String expectedEffect;

  const SyntheticScenarioMutation({
    required this.mutationId,
    required this.field,
    required this.from,
    required this.to,
    required this.reason,
    required this.expectedEffect,
  });

  Map<String, dynamic> toJson() => {
        'mutation_id': mutationId,
        'field': field,
        'from': from,
        'to': to,
        'reason': reason,
        'expected_effect': expectedEffect,
      };
}

class SyntheticScenarioExpectedInvariant {
  final String invariantId;
  final String description;
  final String severity; // 'must' | 'should'
  final bool mustPass;
  final String failureMessage;

  const SyntheticScenarioExpectedInvariant({
    required this.invariantId,
    required this.description,
    required this.severity,
    required this.mustPass,
    required this.failureMessage,
  });

  Map<String, dynamic> toJson() => {
        'invariant_id': invariantId,
        'description': description,
        'severity': severity,
        'must_pass': mustPass,
        'failure_message': failureMessage,
      };
}

class SyntheticScenarioCase {
  final String scenarioId;
  final String family;
  final String description;
  final List<SyntheticScenarioMutation> mutations;

  /// Structured, synthetic-only input descriptor consumed by the evaluator.
  final Map<String, dynamic> inputSummary;
  final List<SyntheticScenarioExpectedInvariant> expectedInvariants;
  final bool syntheticOnly;
  final String safetyBoundary;
  final bool notClinicallyCalibrated;

  const SyntheticScenarioCase({
    required this.scenarioId,
    required this.family,
    required this.description,
    required this.mutations,
    required this.inputSummary,
    required this.expectedInvariants,
    required this.safetyBoundary,
    this.syntheticOnly = true,
    this.notClinicallyCalibrated = true,
  });

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'family': family,
        'description': description,
        'mutations': mutations.map((m) => m.toJson()).toList(growable: false),
        'input_summary': inputSummary,
        'expected_invariants':
            expectedInvariants.map((i) => i.toJson()).toList(growable: false),
        'synthetic_only': syntheticOnly,
        'safety_boundary': safetyBoundary,
        'not_clinically_calibrated': notClinicallyCalibrated,
      };
}

class SyntheticScenarioEvaluation {
  final String scenarioId;
  final bool passed;
  final List<String> failedInvariants;
  final List<String> observedSignals;
  final List<String> unsafePhraseHits;
  final List<String> phiKeyHits;
  final bool unexpectedRankerSwitch;
  final bool missingnessRegression;
  final bool dosageRegression;
  final bool sourceQualityRegression;

  const SyntheticScenarioEvaluation({
    required this.scenarioId,
    required this.passed,
    required this.failedInvariants,
    required this.observedSignals,
    required this.unsafePhraseHits,
    required this.phiKeyHits,
    required this.unexpectedRankerSwitch,
    required this.missingnessRegression,
    required this.dosageRegression,
    required this.sourceQualityRegression,
  });

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'passed': passed,
        'failed_invariants': failedInvariants,
        'observed_signals': observedSignals,
        'unsafe_phrase_hits': unsafePhraseHits,
        'phi_key_hits': phiKeyHits,
        'unexpected_ranker_switch': unexpectedRankerSwitch,
        'missingness_regression': missingnessRegression,
        'dosage_regression': dosageRegression,
        'source_quality_regression': sourceQualityRegression,
      };
}

/// A case paired with its evaluation, for the report.
class SyntheticScenarioResult {
  final SyntheticScenarioCase scenario;
  final SyntheticScenarioEvaluation evaluation;

  const SyntheticScenarioResult(this.scenario, this.evaluation);

  Map<String, dynamic> toJson() => {
        'scenario': scenario.toJson(),
        'evaluation': evaluation.toJson(),
      };
}

class SyntheticScenarioFuzzerReport {
  static const String kReportType = 'synthetic_scenario_fuzzer';

  final int seed;
  final int caseCount;
  final int passed;
  final int failed;
  final List<String> families;
  final List<SyntheticScenarioResult> cases;
  final String safetyBoundary;
  final String notAdviceText;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const SyntheticScenarioFuzzerReport({
    required this.seed,
    required this.caseCount,
    required this.passed,
    required this.failed,
    required this.families,
    required this.cases,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  /// True iff every must-pass invariant passed across all cases.
  bool get allMustPass => failed == 0;

  Map<String, dynamic> toJson() => {
        'report_type': kReportType,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'synthetic_demo_data_only': true,
        'no_medical_advice': true,
        'seed': seed,
        'case_count': caseCount,
        'passed': passed,
        'failed': failed,
        'families': families,
        'cases': cases.map((c) => c.toJson()).toList(growable: false),
        'limitations': limitations,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
      };
}
