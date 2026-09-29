import '../entities/algorithm_component_identity_witness.dart';
import '../entities/absorption_opportunity.dart';
import '../entities/gastric_emptying_profile.dart';
import '../entities/levodopa_absorption_opportunity_parameters.dart';
import '../entities/mechanistic_medication_applicability.dart';
import '../entities/time_axis_events.dart';

/// Estimates a window in which levodopa could become available for
/// small-intestinal absorption, given a medication event and any overlapping
/// meal's gastric emptying profile.
///
/// Educational simulation only. Does NOT predict blood concentration.
class LevodopaAbsorptionOpportunityModel
    with RegisteredAlgorithmComponentIdentity {
  static const MechanisticMedicationApplicabilityPolicy _applicabilityPolicy =
      MechanisticMedicationApplicabilityPolicy();

  /// Reference parameters for immediate-release formulations.
  static const int referenceIrLagMinutes =
      LevodopaAbsorptionOpportunityParameterSet.defaultReferenceIrLagMinutes;
  static const int referenceIrDurationMinutes =
      LevodopaAbsorptionOpportunityParameterSet
          .defaultReferenceIrDurationMinutes;

  /// Mean meal-associated absorption delay reported for nine selected
  /// participants in Nutt et al. (1984). Mapping this group mean onto the
  /// residual-load thresholds below is a prototype heuristic: it is an
  /// illustrative central shift, never an individual or formulation estimate.
  static const int illustrativeMealDelayMinutes =
      LevodopaAbsorptionOpportunityParameterSet
          .defaultIllustrativeMealDelayMinutes;

  /// Openness-curve shape constants (prototype heuristic; unitless 0..1
  /// educational weights, NOT an absorbed fraction or blood concentration).
  /// The supported IR tablet trace rises to a full-openness peak then decays to
  /// a low tail.
  static const int opennessSampleStrideMinutes =
      LevodopaAbsorptionOpportunityParameterSet
          .defaultOpennessSampleStrideMinutes;
  static const double irPeakOpenness =
      LevodopaAbsorptionOpportunityParameterSet.defaultIrPeakOpenness;
  static const double irTailOpenness =
      LevodopaAbsorptionOpportunityParameterSet.defaultIrTailOpenness;

  static const List<String> baseSourceRefs = [
    'src.dailymed.sinemet.label',
    'src.nutt.onoff.1984',
    'src.doi.ge.levodopa.2012',
    'src.internal.prototype.heuristic',
  ];

  static const String smallIntestineAssumption =
      'ldopa.absorption.small_intestine';
  static const String highResidualAssumption =
      'ldopa.absorption.high_residual_group_mean_shift_prototype_heuristic';
  static const String moderateResidualAssumption =
      'ldopa.absorption.moderate_residual_half_shift_prototype_heuristic';
  static const String opennessProfileAssumption =
      'ldopa.absorption.openness_profile_immediate_sharper';
  static const String modelNotApplicableAssumption =
      'ldopa.absorption.model_not_applicable';
  static const String overlappingMealMissingReason =
      'absorption.overlapping_meal_profile_missing';
  static const String gastricNotApplicableReason =
      'absorption.gastric_emptying_not_applicable';

  final LevodopaAbsorptionOpportunityParameterSet parameters;

  LevodopaAbsorptionOpportunityModel({
    LevodopaAbsorptionOpportunityParameterSet? parameters,
  }) : parameters =
           parameters ??
           LevodopaAbsorptionOpportunityParameterSet.prototypeDefault();

  /// Canonical declaration of every fixed branch used by the generator.
  ///
  /// The executable source and this declaration are jointly digest-bound by
  /// the configuration-completeness witness. This is an engineering audit
  /// surface, not a scientific or clinical validation claim.
  static Map<String, dynamic> get generatorStructure => {
    r'$schema': 'parkinsum.levodopa-absorption-generator-structure/1',
    'applicability_binding': {
      'provider_id': 'levodopa_absorption_opportunity',
      'manifest_id': MechanisticApplicabilityManifest.manifestId,
      'manifest_version': MechanisticApplicabilityManifest.manifestVersion,
      'manifest_sha256': MechanisticApplicabilityManifest.current.sha256Digest,
      'status_to_availability': {
        'applicable': 'continue',
        'notApplicable': 'notApplicable',
        'insufficient': 'insufficient',
      },
    },
    'residual_load': {
      'elapsed_origin':
          'dose_minute-minus-peak_emptying_start-plus-rounded_aggregate_lag',
      'aggregate_lag_rounding': 'round_half_away_from_zero',
      'negative_elapsed_policy': 'clamp_to_zero',
      'threshold_order': 'high_strict_gt_then_moderate_strict_gt_else_low',
    },
    'window_construction': {
      'baseline_peak_offset': 'floor_integer_division_duration_by_divisor',
      'high_shift':
          'start_plus_delay,end_plus_delay_times_multiplier,peak_plus_delay',
      'moderate_shift':
          'start_plus_floor_delay_by_divisor,end_plus_delay,peak_plus_floor_delay_by_divisor',
      'initial_delay_likelihood': 'low',
    },
    'uncertainty': {
      'initial': 'narrow',
      'upstream_merge': 'maximum_enum_ordinal',
    },
    'openness_curve': {
      'shape': 'piecewise_linear_rise_to_peak_then_linear_decay_to_tail',
      'peak_minute_policy': 'clamp_to_closed_window',
      'sampling': 'inclusive_stride_with_forced_peak_and_end_samples',
      'openness_domain': [0.0, 1.0],
      'openness_policy': 'clamp_to_closed_domain',
    },
    'abstention': {
      'missing_meal_profile': 'insufficient',
      'upstream_unavailable': 'propagate_availability_and_reasons',
      'in_memory_window': 'zero_width_at_dose_minute',
      'openness_profile': 'empty',
      'delay_likelihood': 'unknown',
      'uncertainty': 'veryWide',
    },
    'output_codes': {
      'assumptions': [
        smallIntestineAssumption,
        highResidualAssumption,
        moderateResidualAssumption,
        opennessProfileAssumption,
        modelNotApplicableAssumption,
      ],
      'reasons': [overlappingMealMissingReason, gastricNotApplicableReason],
    },
    'source_refs': baseSourceRefs,
  };

  Map<String, dynamic> get configuration => {
    'parameters': parameters.toJson(),
    'generator_structure': generatorStructure,
    'output_integrity_contract':
        AbsorptionOpportunityWindow.integrityConfiguration,
  };

  AbsorptionOpportunityWindow build({
    required MedicationTimelineEvent medication,
    GastricEmptyingProfile? overlappingMealProfile,
  }) {
    final applicability = _applicabilityPolicy.evaluate(medication.context);
    if (!applicability.applicable) {
      return _abstainedWindow(
        medication: medication,
        availability:
            applicability.status ==
                MechanisticMedicationApplicabilityStatus.notApplicable
            ? MechanisticProviderAvailability.notApplicable
            : MechanisticProviderAvailability.insufficient,
        reasonCodes: applicability.reasonCodes,
      );
    }
    if (overlappingMealProfile == null) {
      return _abstainedWindow(
        medication: medication,
        availability: MechanisticProviderAvailability.insufficient,
        reasonCodes: const [overlappingMealMissingReason],
      );
    }
    if (!overlappingMealProfile.modelApplicable) {
      return _abstainedWindow(
        medication: medication,
        availability: overlappingMealProfile.availability,
        reasonCodes: [
          gastricNotApplicableReason,
          ...overlappingMealProfile.effectiveApplicabilityReasons,
        ],
      );
    }

    // The v1 applicability policy admits only the IR whole-tablet context.
    // Arbitrary non-empty strings and other formulations never default to IR.
    final lag = parameters.referenceIrLagMinutes;
    final duration = parameters.referenceIrDurationMinutes;

    final assumptions = <String>[smallIntestineAssumption];

    var startMinute = medication.minute + lag;
    var endMinute = medication.minute + lag + duration;
    var peakMinute =
        medication.minute +
        lag +
        (duration ~/ parameters.peakOffsetDurationDivisor);

    DelayedArrivalLikelihood delayLikelihood = DelayedArrivalLikelihood.low;
    var uncertainty = UncertaintyBand.narrow;

    // Estimate residual stomach load at medication time.
    final tSinceMealStart =
        medication.minute -
        overlappingMealProfile.peakEmptyingWindow.startMinute +
        overlappingMealProfile.aggregateLagMinutes.round();
    final residual = overlappingMealProfile.remainingFractionAt(
      tSinceMealStart < 0 ? 0 : tSinceMealStart,
    );

    if (residual > parameters.highResidualThreshold) {
      startMinute += parameters.illustrativeMealDelayMinutes;
      endMinute +=
          parameters.illustrativeMealDelayMinutes *
          parameters.highResidualEndDelayMultiplier;
      peakMinute += parameters.illustrativeMealDelayMinutes;
      delayLikelihood = DelayedArrivalLikelihood.high;
      assumptions.add(highResidualAssumption);
    } else if (residual > parameters.moderateResidualThreshold) {
      final moderateShift =
          parameters.illustrativeMealDelayMinutes ~/
          parameters.moderateResidualShiftDivisor;
      startMinute += moderateShift;
      endMinute += parameters.illustrativeMealDelayMinutes;
      peakMinute += moderateShift;
      delayLikelihood = DelayedArrivalLikelihood.moderate;
      assumptions.add(moderateResidualAssumption);
    } else {
      delayLikelihood = DelayedArrivalLikelihood.low;
    }

    // Downstream uncertainty cannot be narrower than the meal model that
    // supplies its gastric-arrival input.
    uncertainty = _inheritUncertainty(
      uncertainty,
      overlappingMealProfile.uncertaintyBand,
    );

    final opennessProfile = _buildOpennessProfile(
      startMinute: startMinute,
      endMinute: endMinute,
      peakMinute: peakMinute,
    );
    assumptions.add(opennessProfileAssumption);

    return AbsorptionOpportunityWindow(
      medicationEventId: medication.id,
      window: TimelineWindow(startMinute: startMinute, endMinute: endMinute),
      peakMinute: peakMinute,
      delayedArrivalLikelihood: delayLikelihood,
      uncertaintyBand: uncertainty,
      assumptions: List.unmodifiable(assumptions),
      missingInputs: const [],
      sourceRefs: baseSourceRefs,
      opennessProfile: opennessProfile,
    );
  }

  AbsorptionOpportunityWindow _abstainedWindow({
    required MedicationTimelineEvent medication,
    required MechanisticProviderAvailability availability,
    required List<String> reasonCodes,
  }) {
    return AbsorptionOpportunityWindow(
      medicationEventId: medication.id,
      window: TimelineWindow(
        startMinute: medication.minute,
        endMinute: medication.minute,
      ),
      peakMinute: medication.minute,
      delayedArrivalLikelihood: DelayedArrivalLikelihood.unknown,
      uncertaintyBand: UncertaintyBand.veryWide,
      assumptions: const [modelNotApplicableAssumption],
      missingInputs: List.unmodifiable(reasonCodes),
      sourceRefs: baseSourceRefs,
      availability: availability,
      applicabilityReasons: List.unmodifiable(reasonCodes),
      opennessProfile: const [],
    );
  }

  /// Deterministic sampled openness curve over [startMinute, endMinute] with a
  /// rise to [peakMinute] then a decay to the supported IR tail.
  /// Educational shape only — not blood concentration, not PK/PD calibration.
  List<AbsorptionOpennessSample> _buildOpennessProfile({
    required int startMinute,
    required int endMinute,
    required int peakMinute,
  }) {
    if (endMinute <= startMinute) return const [];
    final peakOpenness = parameters.irPeakOpenness;
    final tailOpenness = parameters.irTailOpenness;
    final peak = peakMinute.clamp(startMinute, endMinute);

    final samples = <AbsorptionOpennessSample>[];
    for (
      var t = startMinute;
      t <= endMinute;
      t += parameters.opennessSampleStrideMinutes
    ) {
      double o;
      if (t <= peak) {
        final rise = peak == startMinute
            ? 1.0
            : (t - startMinute) / (peak - startMinute);
        o = rise * peakOpenness;
      } else {
        final decay = endMinute == peak ? 0.0 : (t - peak) / (endMinute - peak);
        o = peakOpenness - decay * (peakOpenness - tailOpenness);
      }
      samples.add(
        AbsorptionOpennessSample(minute: t, openness: o.clamp(0.0, 1.0)),
      );
    }
    // A caller-supplied stride is not required to divide the peak offset.
    // Preserve the declared peak as an explicit sample so output integrity
    // cannot turn an otherwise valid configuration into a blocked result.
    if (!samples.any((sample) => sample.minute == peak)) {
      samples.add(
        AbsorptionOpennessSample(minute: peak, openness: peakOpenness),
      );
      samples.sort((left, right) => left.minute.compareTo(right.minute));
    }
    // Ensure the window end is represented as a sample.
    if (samples.isEmpty || samples.last.minute != endMinute) {
      samples.add(
        AbsorptionOpennessSample(minute: endMinute, openness: tailOpenness),
      );
    }
    return List.unmodifiable(samples);
  }

  UncertaintyBand _inheritUncertainty(
    UncertaintyBand current,
    UncertaintyBand upstream,
  ) =>
      UncertaintyBand.values[current.index > upstream.index
          ? current.index
          : upstream.index];
}
