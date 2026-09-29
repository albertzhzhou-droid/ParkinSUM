/// Typed, immutable configuration for the educational levodopa absorption-
/// opportunity generator.
///
/// These values preserve the existing deterministic prototype. They are not
/// fitted pharmacokinetic parameters, patient-specific estimates, treatment
/// targets, clinical cutoffs, or medication advice.
library;

abstract final class LevodopaAbsorptionOpportunityParameterIds {
  static const String referenceIrLagMinutes =
      'absorption.ir.reference_lag_minutes';
  static const String referenceIrDurationMinutes =
      'absorption.ir.reference_duration_minutes';
  static const String illustrativeMealDelayMinutes =
      'absorption.meal.illustrative_delay_minutes';
  static const String highResidualThreshold =
      'absorption.meal.high_residual_threshold';
  static const String moderateResidualThreshold =
      'absorption.meal.moderate_residual_threshold';
  static const String highResidualEndDelayMultiplier =
      'absorption.meal.high_end_delay_multiplier';
  static const String moderateResidualShiftDivisor =
      'absorption.meal.moderate_shift_divisor';
  static const String peakOffsetDurationDivisor =
      'absorption.ir.peak_offset_duration_divisor';
  static const String opennessSampleStrideMinutes =
      'absorption.openness.sample_stride_minutes';
  static const String irPeakOpenness = 'absorption.openness.ir_peak';
  static const String irTailOpenness = 'absorption.openness.ir_tail';
  static const String generatorStructure =
      'absorption.structure.generator_policy';
  static const String outputIntegrityContract =
      'absorption.structure.output_integrity_contract';

  static const Set<String> numeric = {
    referenceIrLagMinutes,
    referenceIrDurationMinutes,
    illustrativeMealDelayMinutes,
    highResidualThreshold,
    moderateResidualThreshold,
    highResidualEndDelayMultiplier,
    moderateResidualShiftDivisor,
    peakOffsetDurationDivisor,
    opennessSampleStrideMinutes,
    irPeakOpenness,
    irTailOpenness,
  };

  static const Set<String> structural = {
    generatorStructure,
    outputIntegrityContract,
  };

  /// Exact field/provider set reviewed by the configuration-completeness
  /// witness. Any added or removed record invalidates that witness.
  static const Set<String> completeCoverage = {
    ...numeric,
    ...structural,
    'trace_provider.levodopa_absorption_opportunity',
  };
}

final class LevodopaAbsorptionOpportunityParameterSet {
  static const String schema =
      'parkinsum.levodopa-absorption-opportunity-parameters/1';
  static const String defaultId =
      'levodopa_absorption_opportunity.prototype_ir';
  static const String defaultVersion = '2026.09.02-v1';
  static const String defaultLastReviewed = '2026-09-02';

  static const int defaultReferenceIrLagMinutes = 5;
  static const int defaultReferenceIrDurationMinutes = 90;
  static const int defaultIllustrativeMealDelayMinutes = 34;
  static const double defaultHighResidualThreshold = 0.7;
  static const double defaultModerateResidualThreshold = 0.4;
  static const int defaultHighResidualEndDelayMultiplier = 2;
  static const int defaultModerateResidualShiftDivisor = 2;
  static const int defaultPeakOffsetDurationDivisor = 3;
  static const int defaultOpennessSampleStrideMinutes = 10;
  static const double defaultIrPeakOpenness = 1.0;
  static const double defaultIrTailOpenness = 0.15;

  final String id;
  final String version;
  final String lastReviewed;
  final int referenceIrLagMinutes;
  final int referenceIrDurationMinutes;
  final int illustrativeMealDelayMinutes;
  final double highResidualThreshold;
  final double moderateResidualThreshold;
  final int highResidualEndDelayMultiplier;
  final int moderateResidualShiftDivisor;
  final int peakOffsetDurationDivisor;
  final int opennessSampleStrideMinutes;
  final double irPeakOpenness;
  final double irTailOpenness;

  factory LevodopaAbsorptionOpportunityParameterSet({
    required String id,
    required String version,
    required String lastReviewed,
    required int referenceIrLagMinutes,
    required int referenceIrDurationMinutes,
    required int illustrativeMealDelayMinutes,
    required double highResidualThreshold,
    required double moderateResidualThreshold,
    required int highResidualEndDelayMultiplier,
    required int moderateResidualShiftDivisor,
    required int peakOffsetDurationDivisor,
    required int opennessSampleStrideMinutes,
    required double irPeakOpenness,
    required double irTailOpenness,
  }) {
    final candidate = LevodopaAbsorptionOpportunityParameterSet._(
      id: id,
      version: version,
      lastReviewed: lastReviewed,
      referenceIrLagMinutes: referenceIrLagMinutes,
      referenceIrDurationMinutes: referenceIrDurationMinutes,
      illustrativeMealDelayMinutes: illustrativeMealDelayMinutes,
      highResidualThreshold: highResidualThreshold,
      moderateResidualThreshold: moderateResidualThreshold,
      highResidualEndDelayMultiplier: highResidualEndDelayMultiplier,
      moderateResidualShiftDivisor: moderateResidualShiftDivisor,
      peakOffsetDurationDivisor: peakOffsetDurationDivisor,
      opennessSampleStrideMinutes: opennessSampleStrideMinutes,
      irPeakOpenness: irPeakOpenness,
      irTailOpenness: irTailOpenness,
    );
    final errors = candidate.validationErrors;
    if (errors.isNotEmpty) {
      throw ArgumentError.value(errors, 'parameters', errors.join('; '));
    }
    return candidate;
  }

  const LevodopaAbsorptionOpportunityParameterSet._({
    required this.id,
    required this.version,
    required this.lastReviewed,
    required this.referenceIrLagMinutes,
    required this.referenceIrDurationMinutes,
    required this.illustrativeMealDelayMinutes,
    required this.highResidualThreshold,
    required this.moderateResidualThreshold,
    required this.highResidualEndDelayMultiplier,
    required this.moderateResidualShiftDivisor,
    required this.peakOffsetDurationDivisor,
    required this.opennessSampleStrideMinutes,
    required this.irPeakOpenness,
    required this.irTailOpenness,
  });

  factory LevodopaAbsorptionOpportunityParameterSet.prototypeDefault() =>
      LevodopaAbsorptionOpportunityParameterSet(
        id: defaultId,
        version: defaultVersion,
        lastReviewed: defaultLastReviewed,
        referenceIrLagMinutes: defaultReferenceIrLagMinutes,
        referenceIrDurationMinutes: defaultReferenceIrDurationMinutes,
        illustrativeMealDelayMinutes: defaultIllustrativeMealDelayMinutes,
        highResidualThreshold: defaultHighResidualThreshold,
        moderateResidualThreshold: defaultModerateResidualThreshold,
        highResidualEndDelayMultiplier: defaultHighResidualEndDelayMultiplier,
        moderateResidualShiftDivisor: defaultModerateResidualShiftDivisor,
        peakOffsetDurationDivisor: defaultPeakOffsetDurationDivisor,
        opennessSampleStrideMinutes: defaultOpennessSampleStrideMinutes,
        irPeakOpenness: defaultIrPeakOpenness,
        irTailOpenness: defaultIrTailOpenness,
      );

  LevodopaAbsorptionOpportunityParameterSet copyWith({
    String? id,
    String? version,
    String? lastReviewed,
    int? referenceIrLagMinutes,
    int? referenceIrDurationMinutes,
    int? illustrativeMealDelayMinutes,
    double? highResidualThreshold,
    double? moderateResidualThreshold,
    int? highResidualEndDelayMultiplier,
    int? moderateResidualShiftDivisor,
    int? peakOffsetDurationDivisor,
    int? opennessSampleStrideMinutes,
    double? irPeakOpenness,
    double? irTailOpenness,
  }) => LevodopaAbsorptionOpportunityParameterSet(
    id: id ?? this.id,
    version: version ?? this.version,
    lastReviewed: lastReviewed ?? this.lastReviewed,
    referenceIrLagMinutes: referenceIrLagMinutes ?? this.referenceIrLagMinutes,
    referenceIrDurationMinutes:
        referenceIrDurationMinutes ?? this.referenceIrDurationMinutes,
    illustrativeMealDelayMinutes:
        illustrativeMealDelayMinutes ?? this.illustrativeMealDelayMinutes,
    highResidualThreshold: highResidualThreshold ?? this.highResidualThreshold,
    moderateResidualThreshold:
        moderateResidualThreshold ?? this.moderateResidualThreshold,
    highResidualEndDelayMultiplier:
        highResidualEndDelayMultiplier ?? this.highResidualEndDelayMultiplier,
    moderateResidualShiftDivisor:
        moderateResidualShiftDivisor ?? this.moderateResidualShiftDivisor,
    peakOffsetDurationDivisor:
        peakOffsetDurationDivisor ?? this.peakOffsetDurationDivisor,
    opennessSampleStrideMinutes:
        opennessSampleStrideMinutes ?? this.opennessSampleStrideMinutes,
    irPeakOpenness: irPeakOpenness ?? this.irPeakOpenness,
    irTailOpenness: irTailOpenness ?? this.irTailOpenness,
  );

  List<String> get validationErrors {
    final errors = <String>[];
    final safeIdentity = RegExp(r'^[A-Za-z0-9._:/-]{1,160}$');
    if (!safeIdentity.hasMatch(id)) errors.add('id_invalid');
    if (!safeIdentity.hasMatch(version)) errors.add('version_invalid');
    final parsedReviewDate = DateTime.tryParse('${lastReviewed}T00:00:00Z');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(lastReviewed) ||
        parsedReviewDate == null ||
        parsedReviewDate.toIso8601String().substring(0, 10) != lastReviewed) {
      errors.add('last_reviewed_invalid');
    }
    if (referenceIrLagMinutes < 0 || referenceIrLagMinutes > 1440) {
      errors.add('reference_lag_out_of_range');
    }
    if (referenceIrDurationMinutes <= 0 || referenceIrDurationMinutes > 2880) {
      errors.add('reference_duration_out_of_range');
    }
    if (illustrativeMealDelayMinutes < 0 ||
        illustrativeMealDelayMinutes > 1440) {
      errors.add('illustrative_meal_delay_out_of_range');
    }
    if (!moderateResidualThreshold.isFinite ||
        !highResidualThreshold.isFinite ||
        moderateResidualThreshold < 0 ||
        moderateResidualThreshold >= highResidualThreshold ||
        highResidualThreshold > 1) {
      errors.add('residual_threshold_order_invalid');
    }
    if (highResidualEndDelayMultiplier <= 0 ||
        highResidualEndDelayMultiplier > 100) {
      errors.add('high_end_delay_multiplier_out_of_range');
    }
    if (moderateResidualShiftDivisor <= 0 ||
        moderateResidualShiftDivisor > 100) {
      errors.add('moderate_shift_divisor_out_of_range');
    }
    if (peakOffsetDurationDivisor <= 0 || peakOffsetDurationDivisor > 100) {
      errors.add('peak_offset_divisor_out_of_range');
    }
    if (opennessSampleStrideMinutes <= 0 ||
        opennessSampleStrideMinutes > 1440) {
      errors.add('sample_stride_out_of_range');
    }
    if (!irPeakOpenness.isFinite ||
        !irTailOpenness.isFinite ||
        irPeakOpenness <= 0 ||
        irPeakOpenness > 1 ||
        irTailOpenness < 0 ||
        irTailOpenness > irPeakOpenness) {
      errors.add('openness_bounds_invalid');
    }
    return List<String>.unmodifiable(errors);
  }

  Map<String, num> get numericValues => Map<String, num>.unmodifiable({
    LevodopaAbsorptionOpportunityParameterIds.referenceIrLagMinutes:
        referenceIrLagMinutes,
    LevodopaAbsorptionOpportunityParameterIds.referenceIrDurationMinutes:
        referenceIrDurationMinutes,
    LevodopaAbsorptionOpportunityParameterIds.illustrativeMealDelayMinutes:
        illustrativeMealDelayMinutes,
    LevodopaAbsorptionOpportunityParameterIds.highResidualThreshold:
        highResidualThreshold,
    LevodopaAbsorptionOpportunityParameterIds.moderateResidualThreshold:
        moderateResidualThreshold,
    LevodopaAbsorptionOpportunityParameterIds.highResidualEndDelayMultiplier:
        highResidualEndDelayMultiplier,
    LevodopaAbsorptionOpportunityParameterIds.moderateResidualShiftDivisor:
        moderateResidualShiftDivisor,
    LevodopaAbsorptionOpportunityParameterIds.peakOffsetDurationDivisor:
        peakOffsetDurationDivisor,
    LevodopaAbsorptionOpportunityParameterIds.opennessSampleStrideMinutes:
        opennessSampleStrideMinutes,
    LevodopaAbsorptionOpportunityParameterIds.irPeakOpenness: irPeakOpenness,
    LevodopaAbsorptionOpportunityParameterIds.irTailOpenness: irTailOpenness,
  });

  Map<String, dynamic> toJson() => {
    r'$schema': schema,
    'id': id,
    'version': version,
    'last_reviewed': lastReviewed,
    'reference_ir_lag_minutes': referenceIrLagMinutes,
    'reference_ir_duration_minutes': referenceIrDurationMinutes,
    'illustrative_meal_delay_minutes': illustrativeMealDelayMinutes,
    'high_residual_threshold': highResidualThreshold,
    'moderate_residual_threshold': moderateResidualThreshold,
    'high_residual_end_delay_multiplier': highResidualEndDelayMultiplier,
    'moderate_residual_shift_divisor': moderateResidualShiftDivisor,
    'peak_offset_duration_divisor': peakOffsetDurationDivisor,
    'openness_sample_stride_minutes': opennessSampleStrideMinutes,
    'ir_peak_openness': irPeakOpenness,
    'ir_tail_openness': irTailOpenness,
  };
}
