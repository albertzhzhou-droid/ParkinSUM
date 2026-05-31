/// P1 — InputQuality entities.
///
/// Educational/research prototype only. The InputQualityGate evaluates whether a
/// meal + medication entry carries enough structured, source-linked,
/// non-ambiguous context to enter mechanistic scoring or mechanistic-primary
/// ranking. It is an **input/context-completeness** assessment, NOT a
/// recommendation engine. It never tells a user what to eat, when to eat, when
/// to take medication, how to dose, or what is safe. It does not validate
/// clinical correctness and is not clinically calibrated. Synthetic/demo data
/// only; no patient/subject/encounter semantics.
library;

import 'rule_explanation.dart';

/// Context-completeness status (mirrors `MetadataCompletenessScore`).
class InputQualityStatus {
  static const String complete = 'complete';
  static const String sufficient = 'sufficient';
  static const String partial = 'partial';
  static const String insufficient = 'insufficient';
  static const String invalid = 'invalid';

  /// Ordering for "weakest-wins" aggregation (lower = weaker).
  static const List<String> order = [
    invalid,
    insufficient,
    partial,
    sufficient,
    complete,
  ];

  static int rank(String s) {
    final i = order.indexOf(s);
    return i < 0 ? 0 : i;
  }

  /// The weaker of two statuses.
  static String weaker(String a, String b) => rank(a) <= rank(b) ? a : b;

  /// Deterministic 0..1 score for a status.
  static double score(String s) {
    switch (s) {
      case complete:
        return 1.0;
      case sufficient:
        return 0.8;
      case partial:
        return 0.5;
      case insufficient:
        return 0.25;
      default:
        return 0.0;
    }
  }
}

/// Finding severity.
class InputQualitySeverity {
  static const String info = 'info';
  static const String warn = 'warn';
  static const String blocker = 'blocker';
}

/// Dimensions scored by the gate.
class InputQualityDimension {
  static const String medicationDosage = 'medication_dosage';
  static const String medicationIdentity = 'medication_identity';
  static const String medicationMetadata = 'medication_metadata';
  static const String mealComposition = 'meal_composition';
  static const String mealTimingWindow = 'meal_timing_window';
  static const String foodSourceQuality = 'food_source_quality';
  static const String nutrientProvenance = 'nutrient_provenance';
  static const String localizationReadiness = 'localization_readiness';
  static const String overall = 'overall';

  /// Dimensions that contribute to the overall context status (the timing
  /// window and localization readiness affect eligibility/findings but, by
  /// design, do not by themselves make the *context* invalid).
  static const List<String> contextDimensions = [
    medicationDosage,
    medicationIdentity,
    medicationMetadata,
    mealComposition,
    foodSourceQuality,
    nutrientProvenance,
  ];
}

class InputQualityFinding {
  final String findingId;
  final String severity;
  final String dimension;
  final String message;
  final String missingField;
  final String observedValue;
  final String expectedRequirement;
  final List<String> sourceRefs;
  final String safetyBoundary;
  final String notAdviceText;

  const InputQualityFinding({
    required this.findingId,
    required this.severity,
    required this.dimension,
    required this.message,
    this.missingField = '',
    this.observedValue = '',
    this.expectedRequirement = '',
    this.sourceRefs = const [],
    this.safetyBoundary = RuleExplanation.defaultSafetyBoundary,
    this.notAdviceText = RuleExplanation.defaultNotAdvice,
  });

  Map<String, dynamic> toJson() => {
        'finding_id': findingId,
        'severity': severity,
        'dimension': dimension,
        'message': message,
        'missing_field': missingField,
        'observed_value': observedValue,
        'expected_requirement': expectedRequirement,
        'source_refs': sourceRefs,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
      };
}

class InputQualityDimensionScore {
  final String dimension;
  final String status;
  final double score;
  final List<InputQualityFinding> findings;

  const InputQualityDimensionScore({
    required this.dimension,
    required this.status,
    required this.score,
    this.findings = const [],
  });

  Map<String, dynamic> toJson() => {
        'dimension': dimension,
        'status': status,
        'score': score,
        'findings': findings.map((f) => f.toJson()).toList(growable: false),
      };
}

class MealMedicationInputQualityResult {
  static const String kReportType = 'meal_medication_input_quality';

  final String overallStatus;
  final double overallScore;
  final List<InputQualityDimensionScore> dimensionScores;
  final List<InputQualityFinding> findings;
  final bool mechanisticPrimaryEligible;
  final List<String> blockingReasons;
  final List<String> fallbackReasons;
  final List<String> sourceRefs;
  final String safetyBoundary;
  final String notAdviceText;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const MealMedicationInputQualityResult({
    required this.overallStatus,
    required this.overallScore,
    required this.dimensionScores,
    required this.findings,
    required this.mechanisticPrimaryEligible,
    required this.blockingReasons,
    required this.fallbackReasons,
    required this.sourceRefs,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  int get blockerCount =>
      findings.where((f) => f.severity == InputQualitySeverity.blocker).length;

  InputQualityDimensionScore? dimension(String d) {
    for (final s in dimensionScores) {
      if (s.dimension == d) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'report_type': kReportType,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'not_medical_advice': true,
        'input_completeness_assessment_only': true,
        'overall_status': overallStatus,
        'overall_score': overallScore,
        'mechanistic_primary_eligible': mechanisticPrimaryEligible,
        'blocking_reasons': blockingReasons,
        'fallback_reasons': fallbackReasons,
        'dimension_scores':
            dimensionScores.map((d) => d.toJson()).toList(growable: false),
        'findings': findings.map((f) => f.toJson()).toList(growable: false),
        'source_refs': sourceRefs,
        'limitations': limitations,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
      };
}

/// Optional, lightweight localization-readiness status (NOT a full lint run).
class LocalizationReadinessStatus {
  /// Whether any localization status was supplied at all.
  final bool provided;

  /// A localization safety lint (or registry) reported an unsafe localized
  /// copy finding. When true the gate emits a blocker.
  final bool hasUnsafeLocalizedCopy;

  /// Required localized safety/boundary copy is missing for a locale. When true
  /// the gate emits a warn (never a blocker).
  final bool missingLocalizedSafetyCopy;

  const LocalizationReadinessStatus({
    this.provided = false,
    this.hasUnsafeLocalizedCopy = false,
    this.missingLocalizedSafetyCopy = false,
  });

  static const LocalizationReadinessStatus notProvided =
      LocalizationReadinessStatus();
}

/// Optional configuration.
class InputQualityGateConfig {
  /// When true, levodopa component identity is expected (levodopa-specific
  /// scoring); a missing levodopa component downgrades the identity dimension.
  final bool expectsLevodopaContext;

  /// Deterministic timestamp placeholder for report artifacts.
  final String deterministicTimestamp;

  const InputQualityGateConfig({
    this.expectsLevodopaContext = false,
    this.deterministicTimestamp = 'synthetic-demo',
  });
}
