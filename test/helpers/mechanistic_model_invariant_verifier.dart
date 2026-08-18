import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_competition.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_parameters.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_scoring_parameters.dart';

/// Independent engineering-verification boundary for the educational model.
///
/// Passing this gate establishes only deterministic mathematical consistency
/// for the declared structures and observables. It is not biological, clinical,
/// predictive, or patient-level validation.
final class MechanisticModelInvariantVerifier {
  static const double defaultTolerance = 1e-10;
  static const double arrivalIntegrationTolerance = 0.01;

  static const double severityModerateThreshold = 0.15;
  static const double severityHighThreshold = 0.35;
  static const double competitionModerateThreshold = 0.10;
  static const double competitionHighThreshold = 0.25;
  static const double delayedModerateResidualThreshold = 0.40;
  static const double delayedHighResidualThreshold = 0.70;

  static const String evidenceBoundary =
      'Engineering verification of declared mathematical invariants only; '
      'not biological, clinical, predictive, or patient-level validation.';

  MechanisticInvariantReport verifyGastricProfile(
    GastricEmptyingProfile profile, {
    int startMinute = 0,
    int endMinute = 1440,
    int stepMinutes = 1,
    double tolerance = defaultTolerance,
  }) {
    final violations = <MechanisticInvariantViolation>[];
    final wire = profile.toJson();
    if (wire['result_availability'] != profile.availability.name ||
        wire['has_modeled_output'] != profile.hasModeledOutput ||
        wire['model_applicable'] != profile.modelApplicable) {
      violations.add(
        const MechanisticInvariantViolation(
          'gastric_availability_wire_mismatch',
          'Typed gastric availability markers must agree with provider output state.',
        ),
      );
    }
    if (startMinute < 0 || endMinute < startMinute || stepMinutes <= 0) {
      violations.add(
        const MechanisticInvariantViolation(
          'grid_invalid',
          'The deterministic minute grid is invalid.',
        ),
      );
      return MechanisticInvariantReport(violations);
    }
    if (!profile.modelApplicable) {
      if (profile.effectiveApplicabilityReasons.isEmpty) {
        violations.add(
          const MechanisticInvariantViolation(
            'gastric_abstention_contract',
            'A non-applicable gastric provider must expose a reasoned abstention.',
          ),
        );
      }
      if ((wire['component_profiles'] as List).isNotEmpty ||
          wire['aggregate_lag_minutes'] != null ||
          wire['peak_emptying_window'] != null ||
          wire['mostly_emptied_window'] != null ||
          wire['time_scale_sensitivity_fraction'] != null) {
        violations.add(
          const MechanisticInvariantViolation(
            'gastric_abstention_wire_contract',
            'A non-applicable gastric provider must serialize modeled lag, windows, sensitivity, and curves as null or empty.',
          ),
        );
      }
      return MechanisticInvariantReport(violations);
    }
    if (profile.applicabilityReasons.isNotEmpty ||
        wire['aggregate_lag_minutes'] == null ||
        wire['peak_emptying_window'] == null ||
        wire['mostly_emptied_window'] == null ||
        wire['time_scale_sensitivity_fraction'] == null) {
      violations.add(
        const MechanisticInvariantViolation(
          'gastric_applicable_wire_contract',
          'An applicable gastric provider must serialize its modeled lag, windows, and sensitivity without abstention reasons.',
        ),
      );
    }
    if (profile.componentProfiles.isEmpty) {
      violations.add(
        const MechanisticInvariantViolation(
          'component_structure_empty',
          'A gastric profile must contain at least one structural component.',
        ),
      );
      return MechanisticInvariantReport(violations);
    }

    var fractionSum = 0.0;
    var componentStructureSafe = true;
    for (final component in profile.componentProfiles) {
      if (!component.lagMinutes.isFinite || component.lagMinutes < 0) {
        componentStructureSafe = false;
        violations.add(
          MechanisticInvariantViolation(
            'component_lag_invalid',
            '${component.componentId} has a non-finite or negative lag.',
          ),
        );
      }
      if (!component.halfEmptyingMinutes.isFinite ||
          component.halfEmptyingMinutes <= 0) {
        componentStructureSafe = false;
        violations.add(
          MechanisticInvariantViolation(
            'component_half_time_invalid',
            '${component.componentId} has a non-finite or non-positive half-time.',
          ),
        );
      }
      if (!component.fractionOfMeal.isFinite ||
          component.fractionOfMeal < 0 ||
          component.fractionOfMeal > 1) {
        componentStructureSafe = false;
        violations.add(
          MechanisticInvariantViolation(
            'component_fraction_invalid',
            '${component.componentId} has a fraction outside [0, 1].',
          ),
        );
      } else {
        fractionSum += component.fractionOfMeal;
      }
    }
    if (!fractionSum.isFinite || (fractionSum - 1.0).abs() > tolerance) {
      violations.add(
        MechanisticInvariantViolation(
          'component_fraction_sum',
          'Component fractions sum to $fractionSum instead of one.',
        ),
      );
    }
    final sensitivity = profile.timeScaleSensitivityFraction;
    final sensitivitySafe =
        sensitivity.isFinite && sensitivity >= 0 && sensitivity < 1;
    if (!sensitivitySafe) {
      violations.add(
        const MechanisticInvariantViolation(
          'time_scale_sensitivity_invalid',
          'Time-scale sensitivity must be finite and in [0, 1).',
        ),
      );
    }
    if (!componentStructureSafe) {
      return MechanisticInvariantReport(violations);
    }

    var previousRemaining = double.infinity;
    var previousFasterRemaining = double.infinity;
    var previousSlowerRemaining = double.infinity;
    var integratedArrival = 0.0;
    try {
      for (
        var minute = startMinute;
        minute <= endMinute;
        minute += stepMinutes
      ) {
        final remaining = profile.remainingFractionAt(minute);
        final emptied = profile.emptiedFractionAt(minute);
        if (!remaining.isFinite || remaining < 0 || remaining > 1) {
          violations.add(
            MechanisticInvariantViolation(
              'remaining_curve_bounds',
              'Remaining mass is non-finite or outside [0, 1] at minute $minute.',
            ),
          );
        }
        if (!emptied.isFinite || emptied < 0 || emptied > 1) {
          violations.add(
            MechanisticInvariantViolation(
              'emptied_curve_bounds',
              'Emptied mass is non-finite or outside [0, 1] at minute $minute.',
            ),
          );
        }
        if (remaining > previousRemaining + tolerance) {
          violations.add(
            MechanisticInvariantViolation(
              'remaining_curve_monotonicity',
              'Remaining mass increased at minute $minute.',
            ),
          );
        }
        if ((remaining + emptied - 1.0).abs() > tolerance) {
          violations.add(
            MechanisticInvariantViolation(
              'mass_complementarity',
              'Remaining plus emptied mass differs from one at minute $minute.',
            ),
          );
        }
        previousRemaining = remaining;

        final rate = profile.intestinalArrivalRateAt(minute);
        if (!rate.isFinite || rate < 0 || rate > 1) {
          violations.add(
            MechanisticInvariantViolation(
              'arrival_rate_bounds',
              'Arrival rate is non-finite or outside [0, 1]/minute at minute $minute.',
            ),
          );
        } else {
          integratedArrival += rate * stepMinutes;
        }

        if (sensitivitySafe) {
          final envelope = profile.sensitivityEnvelopeAt(minute);
          final faster = envelope.fasterRemaining;
          final slower = envelope.slowerRemaining;
          if (!faster.isFinite || !slower.isFinite) {
            violations.add(
              MechanisticInvariantViolation(
                'sensitivity_envelope_nonfinite',
                'A structural envelope is non-finite at minute $minute.',
              ),
            );
          } else if (faster < 0 ||
              faster > 1 ||
              slower < 0 ||
              slower > 1 ||
              faster > remaining + tolerance ||
              remaining > slower + tolerance) {
            violations.add(
              MechanisticInvariantViolation(
                'sensitivity_envelope_order',
                'Expected faster <= central <= slower at minute $minute.',
              ),
            );
          }
          if (faster.isFinite &&
              slower.isFinite &&
              (faster > previousFasterRemaining + tolerance ||
                  slower > previousSlowerRemaining + tolerance)) {
            violations.add(
              MechanisticInvariantViolation(
                'sensitivity_envelope_monotonicity',
                'A remaining-mass sensitivity curve increased at minute $minute.',
              ),
            );
          }
          if (faster.isFinite) previousFasterRemaining = faster;
          if (slower.isFinite) previousSlowerRemaining = slower;
        }
      }

      final cumulativeEmptied =
          profile.emptiedFractionAt(endMinute) -
          profile.emptiedFractionAt(startMinute);
      if ((integratedArrival - cumulativeEmptied).abs() >
          arrivalIntegrationTolerance) {
        violations.add(
          MechanisticInvariantViolation(
            'arrival_mass_integration',
            'Integrated arrival $integratedArrival differs from cumulative '
                'emptied mass $cumulativeEmptied.',
          ),
        );
      }
    } on Object {
      violations.add(
        const MechanisticInvariantViolation(
          'curve_evaluation_failed',
          'The curve could not be evaluated on the deterministic grid.',
        ),
      );
    }
    return MechanisticInvariantReport(violations);
  }

  MechanisticInvariantReport verifyCurveFixture(
    MechanisticCurveFixture fixture, {
    double tolerance = defaultTolerance,
  }) {
    final violations = <MechanisticInvariantViolation>[];
    if (fixture.central.isEmpty) {
      return MechanisticInvariantReport(const [
        MechanisticInvariantViolation(
          'curve_empty',
          'A declared curve must contain at least one observation.',
        ),
      ]);
    }
    final expectedDimension = switch (fixture.observable) {
      MechanisticCurveObservable.normalizedRemainingMass =>
        MechanisticDimension.normalizedFraction,
      MechanisticCurveObservable.absoluteVolume => MechanisticDimension.volume,
    };
    if (fixture.dimension != expectedDimension) {
      violations.add(
        const MechanisticInvariantViolation(
          'observable_dimension_mismatch',
          'Curve dimension does not match its declared observable.',
        ),
      );
    }
    final hasEnvelope =
        fixture.lowerEnvelope != null || fixture.upperEnvelope != null;
    if (hasEnvelope &&
        (fixture.lowerEnvelope == null ||
            fixture.upperEnvelope == null ||
            fixture.lowerEnvelope!.length != fixture.central.length ||
            fixture.upperEnvelope!.length != fixture.central.length)) {
      violations.add(
        const MechanisticInvariantViolation(
          'envelope_shape_mismatch',
          'Lower, central, and upper structural curves must align.',
        ),
      );
      return MechanisticInvariantReport(violations);
    }

    var previous = double.infinity;
    var previousLower = double.infinity;
    var previousUpper = double.infinity;
    for (var index = 0; index < fixture.central.length; index++) {
      final value = fixture.central[index];
      if (!value.isFinite) {
        violations.add(
          MechanisticInvariantViolation(
            'curve_nonfinite',
            'Curve value at index $index is non-finite.',
          ),
        );
        continue;
      }
      switch (fixture.observable) {
        case MechanisticCurveObservable.normalizedRemainingMass:
          if (value < 0 || value > 1) {
            violations.add(
              MechanisticInvariantViolation(
                'normalized_curve_bounds',
                'Normalized remaining mass is outside [0, 1] at index $index.',
              ),
            );
          }
          if (value > previous + tolerance) {
            violations.add(
              MechanisticInvariantViolation(
                'normalized_curve_monotonicity',
                'Normalized remaining mass increased at index $index.',
              ),
            );
          }
          break;
        case MechanisticCurveObservable.absoluteVolume:
          if (value < 0) {
            violations.add(
              MechanisticInvariantViolation(
                'absolute_volume_negative',
                'Absolute volume is negative at index $index.',
              ),
            );
          }
          // An early secretion-related rise can be structurally valid for this
          // observable, so normalized-retention monotonicity is not applied.
          break;
      }
      previous = value;

      if (hasEnvelope) {
        final lower = fixture.lowerEnvelope![index];
        final upper = fixture.upperEnvelope![index];
        if (!lower.isFinite ||
            !upper.isFinite ||
            lower > value + tolerance ||
            value > upper + tolerance) {
          violations.add(
            MechanisticInvariantViolation(
              'structural_envelope_order',
              'Expected lower <= central <= upper at index $index.',
            ),
          );
        }
        if (lower.isFinite && upper.isFinite) {
          switch (fixture.observable) {
            case MechanisticCurveObservable.normalizedRemainingMass:
              if (lower < 0 || lower > 1 || upper < 0 || upper > 1) {
                violations.add(
                  MechanisticInvariantViolation(
                    'structural_envelope_bounds',
                    'A normalized structural envelope is outside [0, 1] at index $index.',
                  ),
                );
              }
              if (lower > previousLower + tolerance ||
                  upper > previousUpper + tolerance) {
                violations.add(
                  MechanisticInvariantViolation(
                    'structural_envelope_monotonicity',
                    'A normalized structural envelope increased at index $index.',
                  ),
                );
              }
              break;
            case MechanisticCurveObservable.absoluteVolume:
              if (lower < 0 || upper < 0) {
                violations.add(
                  MechanisticInvariantViolation(
                    'structural_envelope_bounds',
                    'An absolute-volume structural envelope is negative at index $index.',
                  ),
                );
              }
              break;
          }
          previousLower = lower;
          previousUpper = upper;
        }
      }
    }
    return MechanisticInvariantReport(violations);
  }

  MechanisticInvariantReport verifyAbsorptionOpportunityCurve(
    AbsorptionOpportunityWindow window, {
    double tolerance = defaultTolerance,
  }) {
    final violations = <MechanisticInvariantViolation>[];
    final wire = window.toJson();
    if (wire['result_availability'] != window.availability.name ||
        wire['has_modeled_output'] != window.hasModeledOutput ||
        wire['model_applicable'] != window.modelApplicable) {
      violations.add(
        const MechanisticInvariantViolation(
          'absorption_availability_wire_mismatch',
          'Typed absorption availability markers must agree with provider output state.',
        ),
      );
    }
    if (!window.modelApplicable) {
      if (window.effectiveApplicabilityReasons.isEmpty) {
        violations.add(
          const MechanisticInvariantViolation(
            'absorption_abstention_contract',
            'A non-applicable model must expose an explicit, reasoned abstention.',
          ),
        );
      }
      if (wire['window'] != null ||
          wire['peak_minute'] != null ||
          wire['peak_openness'] != null ||
          (wire['openness_profile'] as List).isNotEmpty) {
        violations.add(
          const MechanisticInvariantViolation(
            'absorption_abstention_wire_contract',
            'A non-applicable model must serialize timeline and peak outputs as null and its curve as empty.',
          ),
        );
      }
      return MechanisticInvariantReport(violations);
    } else {
      if (window.applicabilityReasons.isNotEmpty) {
        violations.add(
          const MechanisticInvariantViolation(
            'absorption_applicability_contract',
            'An applicable curve cannot carry abstention reasons.',
          ),
        );
      }
      if (window.window.durationMinutes <= 0 ||
          window.opennessProfile.isEmpty) {
        violations.add(
          const MechanisticInvariantViolation(
            'absorption_applicable_curve_missing',
            'An applicable absorption model must emit a positive-width sampled curve.',
          ),
        );
      }
      if (wire['window'] == null ||
          wire['peak_minute'] == null ||
          wire['peak_openness'] == null ||
          (wire['openness_profile'] as List).isEmpty) {
        violations.add(
          const MechanisticInvariantViolation(
            'absorption_applicable_wire_missing',
            'An applicable model must serialize its modeled timeline, peak, and sampled curve.',
          ),
        );
      }
    }
    if (window.peakMinute < window.window.startMinute ||
        window.peakMinute > window.window.endMinute) {
      violations.add(
        const MechanisticInvariantViolation(
          'absorption_peak_outside_window',
          'The declared absorption peak is outside its modeled window.',
        ),
      );
    }

    int? previousMinute;
    double? maximumFiniteOpenness;
    for (var index = 0; index < window.opennessProfile.length; index++) {
      final sample = window.opennessProfile[index];
      if (previousMinute != null && sample.minute <= previousMinute) {
        violations.add(
          MechanisticInvariantViolation(
            'absorption_sample_order',
            'Absorption sample $index is not strictly time ordered.',
          ),
        );
      }
      previousMinute = sample.minute;
      if (sample.minute < window.window.startMinute ||
          sample.minute > window.window.endMinute) {
        violations.add(
          MechanisticInvariantViolation(
            'absorption_sample_outside_window',
            'Absorption sample $index lies outside the modeled window.',
          ),
        );
      }
      if (!sample.openness.isFinite ||
          sample.openness < 0 ||
          sample.openness > 1) {
        violations.add(
          MechanisticInvariantViolation(
            'absorption_openness_bounds',
            'Absorption openness is non-finite or outside [0, 1] at index $index.',
          ),
        );
      } else if (maximumFiniteOpenness == null ||
          sample.openness > maximumFiniteOpenness) {
        maximumFiniteOpenness = sample.openness;
      }
    }

    if (window.opennessProfile.isNotEmpty &&
        !window.opennessProfile.any(
          (sample) =>
              sample.minute == window.peakMinute &&
              sample.openness.isFinite &&
              maximumFiniteOpenness != null &&
              (sample.openness - maximumFiniteOpenness).abs() <= tolerance,
        )) {
      violations.add(
        const MechanisticInvariantViolation(
          'absorption_peak_structure',
          'The declared peak is not represented by a maximum curve sample.',
        ),
      );
    }
    return MechanisticInvariantReport(violations);
  }

  MechanisticInvariantReport verifyCompetitionPressureCurve(
    CompetitionPressureTimeline timeline, {
    double tolerance = defaultTolerance,
  }) {
    final violations = <MechanisticInvariantViolation>[];
    final wire = timeline.toJson();
    if (wire['result_availability'] != timeline.availability.name ||
        wire['has_modeled_output'] != timeline.hasModeledOutput ||
        wire['model_applicable'] != timeline.modelApplicable) {
      violations.add(
        const MechanisticInvariantViolation(
          'competition_availability_wire_mismatch',
          'Typed competition availability markers must agree with provider output state.',
        ),
      );
    }
    if (!timeline.modelApplicable) {
      if (timeline.effectiveApplicabilityReasons.isEmpty) {
        violations.add(
          const MechanisticInvariantViolation(
            'competition_abstention_contract',
            'A non-applicable competition provider must expose a reasoned abstention.',
          ),
        );
      }
      if (wire['peak_minute'] != null ||
          wire['peak_pressure'] != null ||
          wire['overlap_with_absorption_window'] != null ||
          (wire['samples'] as List).isNotEmpty ||
          wire['lnaa_summary'] != null) {
        violations.add(
          const MechanisticInvariantViolation(
            'competition_abstention_wire_contract',
            'A non-applicable competition provider must serialize modeled numeric outputs as null and samples as empty.',
          ),
        );
      }
      return MechanisticInvariantReport(violations);
    }
    if (timeline.applicabilityReasons.isNotEmpty ||
        wire['peak_minute'] == null ||
        wire['peak_pressure'] == null ||
        wire['overlap_with_absorption_window'] == null) {
      violations.add(
        const MechanisticInvariantViolation(
          'competition_applicable_wire_contract',
          'An applicable competition provider must serialize modeled numeric outputs without abstention reasons.',
        ),
      );
    }
    if (!timeline.peakPressure.isFinite ||
        timeline.peakPressure < 0 ||
        timeline.peakPressure > 1) {
      violations.add(
        const MechanisticInvariantViolation(
          'competition_peak_bounds',
          'Peak competition pressure must be finite and in [0, 1].',
        ),
      );
    }
    final overlap = timeline.overlapWithAbsorptionWindow;
    if (!overlap.isFinite || overlap < 0 || overlap > 1) {
      violations.add(
        const MechanisticInvariantViolation(
          'competition_overlap_bounds',
          'Competition overlap must be finite and in [0, 1].',
        ),
      );
    }

    int? previousMinute;
    double? maximumFinitePressure;
    for (var index = 0; index < timeline.samples.length; index++) {
      final sample = timeline.samples[index];
      if (previousMinute != null && sample.minute <= previousMinute) {
        violations.add(
          MechanisticInvariantViolation(
            'competition_sample_order',
            'Competition sample $index is not strictly time ordered.',
          ),
        );
      }
      previousMinute = sample.minute;
      if (!sample.pressure.isFinite ||
          sample.pressure < 0 ||
          sample.pressure > 1) {
        violations.add(
          MechanisticInvariantViolation(
            'competition_pressure_bounds',
            'Competition pressure is non-finite or outside [0, 1] at index $index.',
          ),
        );
      } else if (maximumFinitePressure == null ||
          sample.pressure > maximumFinitePressure) {
        maximumFinitePressure = sample.pressure;
      }
    }

    if (timeline.samples.isNotEmpty &&
        (!timeline.peakPressure.isFinite ||
            maximumFinitePressure == null ||
            (timeline.peakPressure - maximumFinitePressure).abs() > tolerance ||
            !timeline.samples.any(
              (sample) =>
                  sample.minute == timeline.peakMinute &&
                  sample.pressure.isFinite &&
                  (sample.pressure - timeline.peakPressure).abs() <= tolerance,
            ))) {
      violations.add(
        const MechanisticInvariantViolation(
          'competition_peak_structure',
          'The declared competition peak does not match the sampled curve.',
        ),
      );
    }
    return MechanisticInvariantReport(violations);
  }

  MechanisticCanonicalQuantity canonicalize(
    MechanisticQuantity quantity, {
    bool allowNegative = false,
  }) {
    if (!quantity.value.isFinite) {
      throw const MechanisticUnitException(
        'quantity_nonfinite',
        'A quantity must be finite before unit conversion.',
      );
    }
    if (!allowNegative && quantity.value < 0) {
      throw const MechanisticUnitException(
        'quantity_negative',
        'This quantity must not be negative.',
      );
    }
    final token = quantity.unit.trim().toLowerCase();
    if (token.isEmpty || token == 'm' || token == 'unit') {
      throw const MechanisticUnitException(
        'unit_ambiguous',
        'The unit token is missing or ambiguous.',
      );
    }
    final definition = _unitDefinitions[token];
    if (definition == null) {
      throw MechanisticUnitException(
        'unit_unsupported',
        'Unsupported unit token: ${quantity.unit}.',
      );
    }
    if (definition.dimension != quantity.dimension) {
      throw MechanisticUnitException(
        'unit_dimension_mismatch',
        'Unit ${quantity.unit} does not match ${quantity.dimension.name}.',
      );
    }
    final canonicalValue = quantity.value * definition.toCanonicalFactor;
    if (!canonicalValue.isFinite) {
      throw const MechanisticUnitException(
        'canonical_quantity_nonfinite',
        'Unit conversion produced a non-finite canonical value.',
      );
    }
    return MechanisticCanonicalQuantity(
      value: canonicalValue,
      dimension: quantity.dimension,
      unit: _canonicalUnit(quantity.dimension),
    );
  }

  MechanisticInvariantReport verifyCanonicalAnchor({
    required MechanisticQuantity quantity,
    required double expectedCanonicalValue,
    double tolerance = defaultTolerance,
  }) {
    try {
      final canonical = canonicalize(quantity);
      if (!expectedCanonicalValue.isFinite ||
          (canonical.value - expectedCanonicalValue).abs() > tolerance) {
        return MechanisticInvariantReport([
          MechanisticInvariantViolation(
            'canonical_anchor_mismatch',
            'Observed ${canonical.value} ${canonical.unit}; expected '
                '$expectedCanonicalValue ${canonical.unit}.',
          ),
        ]);
      }
      return MechanisticInvariantReport(const []);
    } on MechanisticUnitException catch (error) {
      return MechanisticInvariantReport([
        MechanisticInvariantViolation(error.code, error.message),
      ]);
    }
  }

  MechanisticInvariantReport verifyGastricParameters(
    GastricEmptyingParameterSet parameters,
  ) {
    final violations = <MechanisticInvariantViolation>[];
    final ids = <String>{};
    for (final parameter in parameters.all) {
      if (parameter.id.trim().isEmpty || !ids.add(parameter.id)) {
        violations.add(
          MechanisticInvariantViolation(
            'gastric_parameter_id_invalid',
            'Duplicate or empty parameter id: ${parameter.id}.',
          ),
        );
      }
      if (!parameter.value.toDouble().isFinite) {
        violations.add(
          MechanisticInvariantViolation(
            'gastric_parameter_nonfinite',
            '${parameter.id} is non-finite.',
          ),
        );
      }
    }
    void nonnegative(GastricEmptyingParameter<num> parameter) {
      if (parameter.value < 0) {
        violations.add(
          MechanisticInvariantViolation(
            'gastric_parameter_sign',
            '${parameter.id} must be nonnegative.',
          ),
        );
      }
    }

    void positive(GastricEmptyingParameter<num> parameter) {
      if (parameter.value <= 0) {
        violations.add(
          MechanisticInvariantViolation(
            'gastric_parameter_sign',
            '${parameter.id} must be positive.',
          ),
        );
      }
    }

    nonnegative(parameters.solidLagMinutes);
    nonnegative(parameters.liquidLagMinutes);
    positive(parameters.solidHalfMinutes);
    positive(parameters.liquidHalfMinutes);
    positive(parameters.referenceMealCalories);
    if (parameters.fatSlowdownMultiplier.value < 1 ||
        parameters.fiberSlowdownMultiplier.value < 1) {
      violations.add(
        const MechanisticInvariantViolation(
          'slowdown_multiplier_sign',
          'A slowdown multiplier must be finite and at least one.',
        ),
      );
    }
    if (parameters.fatFractionThreshold.value < 0 ||
        parameters.fatFractionThreshold.value > 1) {
      violations.add(
        const MechanisticInvariantViolation(
          'fat_threshold_domain',
          'Fat fraction threshold must be in [0, 1].',
        ),
      );
    }
    positive(parameters.highCalorieFractionThreshold);
    final sensitivity = parameters.timeScaleSensitivityFraction.value;
    if (!sensitivity.isFinite || sensitivity < 0 || sensitivity >= 1) {
      violations.add(
        const MechanisticInvariantViolation(
          'time_scale_sensitivity_invalid',
          'Time-scale sensitivity must be finite and in [0, 1).',
        ),
      );
    }
    nonnegative(parameters.mixedMealUncertaintyBoost);
    nonnegative(parameters.overlapUncertaintyBoost);
    nonnegative(parameters.fatUncertaintyBoost);
    nonnegative(parameters.highCalorieUncertaintyBoost);
    return MechanisticInvariantReport(violations);
  }

  MechanisticInvariantReport verifyScoringParameters(
    NextMealScoringParameterSet parameters, {
    NextMealScoringParameterSet? expected,
    double tolerance = defaultTolerance,
  }) {
    final violations = <MechanisticInvariantViolation>[];
    if (!parameters.conflictRemainsDominant) {
      violations.add(
        const MechanisticInvariantViolation(
          'conflict_not_dominant',
          'Conflict overlap must remain the dominant scoring contribution.',
        ),
      );
    }
    violations.addAll(
      verifyScoringFormula(
        scoringFormulaWitness(parameters),
        expected: expected == null ? null : scoringFormulaWitness(expected),
        tolerance: tolerance,
      ).violations,
    );
    return MechanisticInvariantReport(violations);
  }

  MechanisticInvariantReport verifyScoringFormula(
    List<MechanisticFormulaTermWitness> terms, {
    List<MechanisticFormulaTermWitness>? expected,
    double tolerance = defaultTolerance,
  }) {
    final violations = <MechanisticInvariantViolation>[];
    final ids = <String>{};
    var contributionSum = 0.0;
    for (var index = 0; index < terms.length; index++) {
      final term = terms[index];
      if (term.semanticId.trim().isEmpty || !ids.add(term.semanticId)) {
        violations.add(
          MechanisticInvariantViolation(
            'scoring_term_id_invalid',
            'Duplicate or empty formula term id: ${term.semanticId}.',
          ),
        );
      }
      if (!term.coefficient.isFinite) {
        violations.add(
          MechanisticInvariantViolation(
            'scoring_weight_nonfinite',
            '${term.semanticId} has a non-finite coefficient.',
          ),
        );
        continue;
      }
      final isPenalty = term.semanticId == 'score.uncertainty_penalty';
      if (isPenalty) {
        if (term.coefficient >= 0) {
          violations.add(
            const MechanisticInvariantViolation(
              'scoring_penalty_sign',
              'The uncertainty term must have a negative formula coefficient.',
            ),
          );
        }
      } else {
        if (term.coefficient < 0) {
          violations.add(
            MechanisticInvariantViolation(
              'scoring_contribution_sign',
              '${term.semanticId} must not have a negative coefficient.',
            ),
          );
        }
        contributionSum += term.coefficient;
      }
    }
    if ((contributionSum - 1.0).abs() > tolerance) {
      violations.add(
        MechanisticInvariantViolation(
          'scoring_weights_not_normalized',
          'Positive scoring contributions sum to $contributionSum, not one.',
        ),
      );
    }
    if (expected != null) {
      if (terms.length != expected.length) {
        violations.add(
          const MechanisticInvariantViolation(
            'scoring_term_count_mismatch',
            'Formula term count differs from the declared structure.',
          ),
        );
      }
      final sharedLength = terms.length < expected.length
          ? terms.length
          : expected.length;
      for (var index = 0; index < sharedLength; index++) {
        if (terms[index].semanticId != expected[index].semanticId) {
          violations.add(
            MechanisticInvariantViolation(
              'scoring_term_order_mismatch',
              'Formula term $index is ${terms[index].semanticId}; expected '
                  '${expected[index].semanticId}.',
            ),
          );
        }
        if ((terms[index].coefficient - expected[index].coefficient).abs() >
            tolerance) {
          violations.add(
            MechanisticInvariantViolation(
              'scoring_weight_value_mismatch',
              '${terms[index].semanticId} coefficient differs from the '
                  'declared configuration.',
            ),
          );
        }
      }
    }
    return MechanisticInvariantReport(violations);
  }

  List<MechanisticFormulaTermWitness> scoringFormulaWitness(
    NextMealScoringParameterSet parameters,
  ) => List<MechanisticFormulaTermWitness>.unmodifiable([
    MechanisticFormulaTermWitness(
      parameters.conflictOverlap.id,
      parameters.conflictOverlap.value,
    ),
    MechanisticFormulaTermWitness(
      parameters.proteinRedistribution.id,
      parameters.proteinRedistribution.value,
    ),
    MechanisticFormulaTermWitness(
      parameters.nutritionAdequacy.id,
      parameters.nutritionAdequacy.value,
    ),
    MechanisticFormulaTermWitness(
      parameters.metadataCompleteness.id,
      parameters.metadataCompleteness.value,
    ),
    MechanisticFormulaTermWitness(
      parameters.sourceAuthority.id,
      parameters.sourceAuthority.value,
    ),
    MechanisticFormulaTermWitness(
      parameters.jurisdictionMatch.id,
      parameters.jurisdictionMatch.value,
    ),
    MechanisticFormulaTermWitness(
      parameters.provenanceQuality.id,
      parameters.provenanceQuality.value,
    ),
    MechanisticFormulaTermWitness(
      parameters.uncertaintyPenalty.id,
      -parameters.uncertaintyPenalty.value,
    ),
  ]);

  SeverityBand classifySeverity(
    double score, {
    required CompetitionBand competition,
  }) {
    _requireNormalized(score, 'severity_score');
    if (competition == CompetitionBand.unknown) return SeverityBand.unknown;
    if (score >= severityHighThreshold) return SeverityBand.high;
    if (score >= severityModerateThreshold) return SeverityBand.moderate;
    if (score > 0) return SeverityBand.low;
    return SeverityBand.none;
  }

  CompetitionBand classifyCompetition(double overlap) {
    _requireNormalized(overlap, 'competition_overlap');
    if (overlap >= competitionHighThreshold) return CompetitionBand.high;
    if (overlap >= competitionModerateThreshold) {
      return CompetitionBand.moderate;
    }
    if (overlap > 0) return CompetitionBand.low;
    return CompetitionBand.none;
  }

  DelayedArrivalLikelihood classifyDelayedArrival(
    double residual, {
    bool mealProfileAvailable = true,
  }) {
    _requireNormalized(residual, 'gastric_residual');
    if (!mealProfileAvailable) return DelayedArrivalLikelihood.unknown;
    if (residual > delayedHighResidualThreshold) {
      return DelayedArrivalLikelihood.high;
    }
    if (residual > delayedModerateResidualThreshold) {
      return DelayedArrivalLikelihood.moderate;
    }
    return DelayedArrivalLikelihood.low;
  }

  MechanisticInvariantReport verifySeverityObservation({
    required double score,
    required CompetitionBand competition,
    required SeverityBand observed,
  }) => _thresholdObservation(
    code: 'severity_threshold_mismatch',
    observed: observed.name,
    expected: classifySeverity(score, competition: competition).name,
  );

  MechanisticInvariantReport verifyCompetitionObservation({
    required double overlap,
    required CompetitionBand observed,
  }) => _thresholdObservation(
    code: 'competition_threshold_mismatch',
    observed: observed.name,
    expected: classifyCompetition(overlap).name,
  );

  MechanisticInvariantReport verifyDelayedArrivalObservation({
    required double residual,
    required DelayedArrivalLikelihood observed,
    bool mealProfileAvailable = true,
  }) => _thresholdObservation(
    code: 'delayed_arrival_threshold_mismatch',
    observed: observed.name,
    expected: classifyDelayedArrival(
      residual,
      mealProfileAvailable: mealProfileAvailable,
    ).name,
  );

  MechanisticInvariantReport _thresholdObservation({
    required String code,
    required String observed,
    required String expected,
  }) => observed == expected
      ? MechanisticInvariantReport(const [])
      : MechanisticInvariantReport([
          MechanisticInvariantViolation(
            code,
            'Observed $observed; expected $expected at the exact boundary.',
          ),
        ]);

  void _requireNormalized(double value, String name) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw MechanisticUnitException(
        '${name}_invalid',
        '$name must be finite and in [0, 1].',
      );
    }
  }
}

enum MechanisticDimension {
  time,
  mass,
  normalizedFraction,
  ratePerTime,
  volume,
}

enum MechanisticCurveObservable { normalizedRemainingMass, absoluteVolume }

final class MechanisticQuantity {
  const MechanisticQuantity({
    required this.value,
    required this.unit,
    required this.dimension,
  });

  final double value;
  final String unit;
  final MechanisticDimension dimension;
}

final class MechanisticCanonicalQuantity {
  const MechanisticCanonicalQuantity({
    required this.value,
    required this.unit,
    required this.dimension,
  });

  final double value;
  final String unit;
  final MechanisticDimension dimension;
}

final class MechanisticCurveFixture {
  MechanisticCurveFixture({
    required this.structureId,
    required this.observable,
    required this.dimension,
    required List<double> central,
    List<double>? lowerEnvelope,
    List<double>? upperEnvelope,
  }) : central = List<double>.unmodifiable(central),
       lowerEnvelope = lowerEnvelope == null
           ? null
           : List<double>.unmodifiable(lowerEnvelope),
       upperEnvelope = upperEnvelope == null
           ? null
           : List<double>.unmodifiable(upperEnvelope);

  final String structureId;
  final MechanisticCurveObservable observable;
  final MechanisticDimension dimension;
  final List<double> central;
  final List<double>? lowerEnvelope;
  final List<double>? upperEnvelope;
}

final class MechanisticFormulaTermWitness {
  const MechanisticFormulaTermWitness(this.semanticId, this.coefficient);

  final String semanticId;
  final double coefficient;
}

final class MechanisticInvariantViolation {
  const MechanisticInvariantViolation(this.code, this.message);

  final String code;
  final String message;
}

final class MechanisticInvariantReport {
  MechanisticInvariantReport(List<MechanisticInvariantViolation> violations)
    : violations = List<MechanisticInvariantViolation>.unmodifiable(violations);

  final List<MechanisticInvariantViolation> violations;

  bool get passed => violations.isEmpty;
  Set<String> get codes =>
      Set<String>.unmodifiable(violations.map((violation) => violation.code));
}

final class MechanisticUnitException implements Exception {
  const MechanisticUnitException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

final class _UnitDefinition {
  const _UnitDefinition(this.dimension, this.toCanonicalFactor);

  final MechanisticDimension dimension;
  final double toCanonicalFactor;
}

const Map<String, _UnitDefinition> _unitDefinitions = {
  'min': _UnitDefinition(MechanisticDimension.time, 1),
  'minute': _UnitDefinition(MechanisticDimension.time, 1),
  'minutes': _UnitDefinition(MechanisticDimension.time, 1),
  'h': _UnitDefinition(MechanisticDimension.time, 60),
  'hr': _UnitDefinition(MechanisticDimension.time, 60),
  'hour': _UnitDefinition(MechanisticDimension.time, 60),
  'hours': _UnitDefinition(MechanisticDimension.time, 60),
  'mg': _UnitDefinition(MechanisticDimension.mass, 1),
  'milligram': _UnitDefinition(MechanisticDimension.mass, 1),
  'milligrams': _UnitDefinition(MechanisticDimension.mass, 1),
  'g': _UnitDefinition(MechanisticDimension.mass, 1000),
  'gram': _UnitDefinition(MechanisticDimension.mass, 1000),
  'grams': _UnitDefinition(MechanisticDimension.mass, 1000),
  'mcg': _UnitDefinition(MechanisticDimension.mass, 0.001),
  'ug': _UnitDefinition(MechanisticDimension.mass, 0.001),
  'µg': _UnitDefinition(MechanisticDimension.mass, 0.001),
  'μg': _UnitDefinition(MechanisticDimension.mass, 0.001),
  'microgram': _UnitDefinition(MechanisticDimension.mass, 0.001),
  'micrograms': _UnitDefinition(MechanisticDimension.mass, 0.001),
  'fraction': _UnitDefinition(MechanisticDimension.normalizedFraction, 1),
  'unitless': _UnitDefinition(MechanisticDimension.normalizedFraction, 1),
  '1': _UnitDefinition(MechanisticDimension.normalizedFraction, 1),
  '%': _UnitDefinition(MechanisticDimension.normalizedFraction, 0.01),
  '1/min': _UnitDefinition(MechanisticDimension.ratePerTime, 1),
  'per_minute': _UnitDefinition(MechanisticDimension.ratePerTime, 1),
  '1/h': _UnitDefinition(MechanisticDimension.ratePerTime, 1 / 60),
  'per_hour': _UnitDefinition(MechanisticDimension.ratePerTime, 1 / 60),
  'ml': _UnitDefinition(MechanisticDimension.volume, 1),
  'milliliter': _UnitDefinition(MechanisticDimension.volume, 1),
  'milliliters': _UnitDefinition(MechanisticDimension.volume, 1),
  'l': _UnitDefinition(MechanisticDimension.volume, 1000),
  'liter': _UnitDefinition(MechanisticDimension.volume, 1000),
  'liters': _UnitDefinition(MechanisticDimension.volume, 1000),
};

String _canonicalUnit(MechanisticDimension dimension) => switch (dimension) {
  MechanisticDimension.time => 'minute',
  MechanisticDimension.mass => 'mg',
  MechanisticDimension.normalizedFraction => 'fraction',
  MechanisticDimension.ratePerTime => '1/min',
  MechanisticDimension.volume => 'mL',
};
