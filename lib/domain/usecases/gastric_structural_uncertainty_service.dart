import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../entities/gastric_emptying_profile.dart';
import '../entities/gastric_structural_uncertainty.dart';
import '../entities/mechanistic_event_ledger.dart';
import '../entities/time_axis_events.dart';

/// Builds a read-only model-form sensitivity report around the unchanged
/// production gastric curve. It never feeds a shadow output into scoring,
/// ranking, recommendation copy, or medication timing.
final class GastricStructuralUncertaintyService {
  const GastricStructuralUncertaintyService();

  GastricStructuralUncertaintyReport build({
    required String reportId,
    required DateTime generatedAtUtc,
    required MechanisticEventLedger eventLedger,
    required GastricEmptyingProfile productionProfile,
    required MealPhysicalForm physicalForm,
    GastricFitEvidence? fitEvidence,
  }) {
    if (!generatedAtUtc.isUtc) {
      throw ArgumentError('Gastric structural reports require UTC time.');
    }
    if (!productionProfile.hasModeledOutput) {
      throw StateError(
        'A structurally valid production gastric profile is required.',
      );
    }
    if (!eventLedger.events.any(
      (event) =>
          event.kind == MechanisticLedgerEventKind.meal &&
          (event.id == productionProfile.mealId ||
              event.attributes['composition_id'] == productionProfile.mealId),
    )) {
      throw StateError('The event ledger does not bind the production meal.');
    }

    final productionDigestBefore = _digest(productionProfile.toJson());
    final weightedHalfMinutes = productionProfile.componentProfiles
        .fold<double>(
          0,
          (sum, component) =>
              sum + component.fractionOfMeal * component.halfEmptyingMinutes,
        );
    final t50Minutes = math.max(
      1.0,
      productionProfile.aggregateLagMinutes + weightedHalfMinutes,
    );
    final maxMinute = math.max(
      240,
      math.min(
        480,
        productionProfile.mostlyEmptiedWindow.durationMinutes +
            productionProfile.aggregateLagMinutes.round(),
      ),
    );
    final observationMinutes = <int>{
      0,
      30,
      60,
      120,
      180,
      240,
      maxMinute,
    }.where((minute) => minute <= maxMinute).toList()..sort();
    final observationSeries = GastricObservationSeries(
      id: '${reportId}_normalized_retention',
      observable: GastricMeasuredObservable.normalizedIntragastricRetention,
      modality: GastricMeasurementModality.scintigraphy,
      originalUnit: 'fraction',
      canonicalUnit: 'fraction',
      points: [
        for (final minute in observationMinutes)
          GastricObservationPoint(
            minute: minute,
            value: productionProfile.remainingFractionAt(minute),
          ),
      ],
      synthetic: true,
      derivedFromProduction: true,
      sourceIds: const <String>[
        'src.synthetic.gastric.structural.fixture',
        'src.internal.prototype.heuristic',
      ],
    );

    final contracts = _contracts(
      productionProfile: productionProfile,
      physicalForm: physicalForm,
      weightedHalfMinutes: weightedHalfMinutes,
      t50Minutes: t50Minutes,
    );
    final sampleMinutes = <int>[
      for (var minute = 0; minute <= maxMinute; minute += 10) minute,
    ];
    if (sampleMinutes.last != maxMinute) sampleMinutes.add(maxMinute);

    final trajectories = <GastricShadowTrajectory>[];
    for (final contract in contracts) {
      final authorization = authorizeFit(
        contract: contract,
        series: observationSeries,
        evidence: fitEvidence,
      );
      final matches =
          contract.observable == observationSeries.observable &&
          contract.modality == observationSeries.modality;
      if (!matches) {
        trajectories.add(
          GastricShadowTrajectory(
            structure: contract,
            availability: GastricTrajectoryAvailability.observableMismatch,
            reasons: <String>[
              'observable_or_modality_mismatch',
              'required:${contract.observable.name}/${contract.modality.name}',
              'available:${observationSeries.observable.name}/${observationSeries.modality.name}',
            ],
            points: const <GastricTrajectoryPoint>[],
            fitAuthorization: authorization,
          ),
        );
        continue;
      }
      final points = <GastricTrajectoryPoint>[];
      var valid = true;
      for (final minute in sampleMinutes) {
        final value = _evaluate(
          contract: contract,
          minute: minute,
          productionProfile: productionProfile,
        );
        if (!value.isFinite || value < 0 || value > 1) {
          valid = false;
          break;
        }
        points.add(GastricTrajectoryPoint(minute: minute, value: value));
      }
      trajectories.add(
        GastricShadowTrajectory(
          structure: contract,
          availability: valid
              ? GastricTrajectoryAvailability.available
              : GastricTrajectoryAvailability.blockedIntegrity,
          reasons: <String>[
            if (contract.kind ==
                GastricStructureKind.productionComponentLagExponential)
              'unchanged_production_reference'
            else
              'read_only_prior_fixed_shadow',
            if (!valid) 'nonfinite_or_out_of_range_trajectory',
            'never_used_for_score_rank_or_recommendation',
          ],
          points: valid ? points : const <GastricTrajectoryPoint>[],
          fitAuthorization: authorization,
        ),
      );
    }

    final disagreements = _pairwiseDisagreements(trajectories);
    final productionDigestAfter = _digest(productionProfile.toJson());
    return GastricStructuralUncertaintyReport(
      reportId: reportId,
      generatedAtUtc: generatedAtUtc,
      eventLedgerDigest: eventLedger.sha256Digest,
      eventLedgerReplayDigest: eventLedger.canonicalReplayDigest,
      configurationDigest: eventLedger.configurationDigest,
      productionOutputDigestBefore: productionDigestBefore,
      productionOutputDigestAfter: productionDigestAfter,
      observationSeries: observationSeries,
      trajectories: trajectories,
      disagreements: disagreements,
      boundary:
          'Read-only engineering model-form sensitivity. Pairwise differences '
          'are not an ensemble, confidence interval, accuracy gain, individual '
          'gastric-emptying test, plasma concentration, symptom prediction, '
          'clinical validation, or treatment guidance.',
    );
  }

  GastricFitAuthorization authorizeFit({
    required GastricStructureContract contract,
    required GastricObservationSeries series,
    required GastricFitEvidence? evidence,
  }) {
    final reasons = <String>[];
    if (contract.observable != series.observable) {
      reasons.add('observable_mismatch');
    }
    if (contract.modality != series.modality) {
      reasons.add('measurement_modality_mismatch');
    }
    if (contract.kind ==
        GastricStructureKind.productionComponentLagExponential) {
      reasons.add('production_parameters_are_configuration_bound');
    }
    if (series.synthetic) reasons.add('synthetic_series_cannot_authorize_fit');
    if (series.derivedFromProduction) {
      reasons.add('circular_production_derived_series');
    }
    if (reasons.isNotEmpty) {
      return GastricFitAuthorization(
        structureId: contract.id,
        seriesId: series.id,
        disposition:
            contract.observable == series.observable &&
                contract.modality == series.modality
            ? GastricFitDisposition.priorFixedOnly
            : GastricFitDisposition.blocked,
        reasons: reasons,
      );
    }

    final requiredInformativePoints = contract.freeParameterCount + 2;
    if (series.points.length < requiredInformativePoints) {
      reasons.add('informative_observations_do_not_exceed_free_parameters');
    }
    final earlyCount = series.points
        .where((point) => point.minute <= 60)
        .length;
    final lateCount = series.points
        .where((point) => point.minute >= 120)
        .length;
    if (earlyCount < 2) reasons.add('early_phase_not_spanned');
    if (lateCount < 2) reasons.add('late_phase_not_spanned');
    if (evidence == null) {
      reasons.add('fit_diagnostics_missing');
    } else {
      if (evidence.multistartRuns < 10) {
        reasons.add('multistart_runs_insufficient');
      }
      if (evidence.distinctStableOptima != 1) {
        reasons.add('multiple_or_absent_stable_optima');
      }
      if (!evidence.profileLikelihoodBounded &&
          evidence.conditionNumber > 1000000) {
        reasons.add('practical_identifiability_not_demonstrated');
      }
      if (evidence.heldOutPointCount < 2) {
        reasons.add('held_out_points_insufficient');
      }
      if (evidence.heldOutRmse > evidence.heldOutRmseThreshold) {
        reasons.add('held_out_predictive_check_failed');
      }
      if (!evidence.independentImplementation) {
        reasons.add('independent_diagnostic_implementation_missing');
      }
    }
    return GastricFitAuthorization(
      structureId: contract.id,
      seriesId: series.id,
      disposition: reasons.isEmpty
          ? GastricFitDisposition.eligibleForResearchFit
          : GastricFitDisposition.blocked,
      reasons: reasons.isEmpty
          ? const <String>['all_research_fit_preconditions_observed']
          : reasons,
    );
  }

  /// Evaluates one declared structure without changing the production model.
  ///
  /// This exists so release verification can compare every observable-specific
  /// equation, including structures that are correctly held from the current
  /// UI scenario because their measurement modality is unavailable. The value
  /// is never used by scoring, ranking, copy, or medication timing.
  double evaluateDeclaredStructure({
    required GastricStructureContract contract,
    required int minute,
    required GastricEmptyingProfile productionProfile,
  }) {
    if (minute < 0) {
      throw ArgumentError.value(minute, 'minute', 'must be nonnegative');
    }
    return _evaluate(
      contract: contract,
      minute: minute,
      productionProfile: productionProfile,
    );
  }

  List<GastricStructureContract> _contracts({
    required GastricEmptyingProfile productionProfile,
    required MealPhysicalForm physicalForm,
    required double weightedHalfMinutes,
    required double t50Minutes,
  }) {
    final beta = switch (physicalForm) {
      MealPhysicalForm.liquid => 0.85,
      MealPhysicalForm.solid => 1.35,
      MealPhysicalForm.mixed => 1.20,
      MealPhysicalForm.unknown => 1.0,
    };
    final k = math.ln2 / math.max(weightedHalfMinutes, 1.0);
    final modifiedBeta = math
        .exp(k * productionProfile.aggregateLagMinutes)
        .clamp(1.0, 6.0)
        .toDouble();
    final productionParameters = <GastricStructureParameter>[];
    for (final component in productionProfile.componentProfiles) {
      final safeComponent = component.componentId.replaceAll(
        RegExp(r'[^a-zA-Z0-9._:-]'),
        '_',
      );
      productionParameters.addAll(<GastricStructureParameter>[
        _parameter(
          id: 'production.$safeComponent.fraction',
          symbol: 'w_$safeComponent',
          value: component.fractionOfMeal,
          unit: 'fraction',
          authority: GastricParameterAuthority.productionBound,
          sources: productionProfile.sourceRefs,
        ),
        _parameter(
          id: 'production.$safeComponent.lag',
          symbol: 'L_$safeComponent',
          value: component.lagMinutes,
          unit: 'min',
          authority: GastricParameterAuthority.productionBound,
          sources: productionProfile.sourceRefs,
        ),
        _parameter(
          id: 'production.$safeComponent.half',
          symbol: 'T50_$safeComponent',
          value: component.halfEmptyingMinutes,
          unit: 'min',
          authority: GastricParameterAuthority.productionBound,
          sources: productionProfile.sourceRefs,
        ),
      ]);
    }

    return <GastricStructureContract>[
      GastricStructureContract(
        id: 'gastric.production.component_lag_exponential.v1',
        kind: GastricStructureKind.productionComponentLagExponential,
        name: 'Production component lag-exponential',
        formula: 'R(t)=sum_i w_i * [t<=L_i ? 1 : exp(-ln(2)*(t-L_i)/T50_i)]',
        observable: GastricMeasuredObservable.normalizedIntragastricRetention,
        modality: GastricMeasurementModality.scintigraphy,
        originalUnit: 'fraction',
        canonicalUnit: 'fraction',
        freeParameterIds: const <String>[],
        parameters: productionParameters,
        evidenceSourceIds: productionProfile.sourceRefs,
        supportedDomain:
            'Synthetic normalized meal-retention sensitivity for the declared meal composition.',
        limitation:
            'Existing production engineering structure; not fitted to the current person or meal.',
      ),
      GastricStructureContract(
        id: 'gastric.shadow.elashoff_power_exponential.v1',
        kind: GastricStructureKind.elashoffPowerExponential,
        name: 'Elashoff power-exponential',
        formula: 'R(t)=2^(-(t/T50)^beta)',
        observable: GastricMeasuredObservable.normalizedIntragastricRetention,
        modality: GastricMeasurementModality.scintigraphy,
        originalUnit: 'percent_retained',
        canonicalUnit: 'fraction',
        freeParameterIds: const <String>['elashoff.t50', 'elashoff.beta'],
        parameters: <GastricStructureParameter>[
          _prior(
            'elashoff.t50',
            'T50',
            t50Minutes,
            'min',
            'src.elashoff.gastric.powerexp.1982',
          ),
          _prior(
            'elashoff.beta',
            'beta',
            beta,
            '1',
            'src.elashoff.gastric.powerexp.1982',
          ),
        ],
        evidenceSourceIds: const <String>[
          'src.elashoff.gastric.powerexp.1982',
          'src.hou.gastric.modelcomparison.2010',
        ],
        supportedDomain:
            'Scintigraphic normalized intragastric retention with sufficiently sampled early and late phases.',
        limitation:
            'Prior-fixed shape is a model-form sensitivity and not an individual nonlinear fit.',
      ),
      GastricStructureContract(
        id: 'gastric.shadow.siegel_modified_power_exponential.v1',
        kind: GastricStructureKind.siegelModifiedPowerExponential,
        name: 'Siegel modified power-exponential',
        formula: 'R(t)=1-(1-exp(-k*t))^beta',
        observable: GastricMeasuredObservable.normalizedIntragastricRetention,
        modality: GastricMeasurementModality.scintigraphy,
        originalUnit: 'percent_retained',
        canonicalUnit: 'fraction',
        freeParameterIds: const <String>['siegel.k', 'siegel.beta'],
        parameters: <GastricStructureParameter>[
          _prior(
            'siegel.k',
            'k',
            k,
            '1/min',
            'src.siegel.gastric.biphasic.1988',
          ),
          _prior(
            'siegel.beta',
            'beta',
            modifiedBeta,
            '1',
            'src.siegel.gastric.biphasic.1988',
          ),
        ],
        evidenceSourceIds: const <String>[
          'src.siegel.gastric.biphasic.1988',
          'src.hou.gastric.modelcomparison.2010',
        ],
        supportedDomain:
            'Scintigraphic fractional retention with additional early sampling for lag characterization.',
        limitation:
            'Not the Elashoff equation; its parameters and lag definition are not interchangeable.',
      ),
      GastricStructureContract(
        id: 'gastric.shadow.explicit_lag_exponential.v1',
        kind: GastricStructureKind.explicitLagExponential,
        name: 'Explicit-lag exponential',
        formula: 'R(t)=t<=L ? 1 : exp(-ln(2)*(t-L)/T50)',
        observable: GastricMeasuredObservable.normalizedIntragastricRetention,
        modality: GastricMeasurementModality.scintigraphy,
        originalUnit: 'percent_retained',
        canonicalUnit: 'fraction',
        freeParameterIds: const <String>['lag_exp.lag', 'lag_exp.half'],
        parameters: <GastricStructureParameter>[
          _prior(
            'lag_exp.lag',
            'L',
            productionProfile.aggregateLagMinutes,
            'min',
            'src.burmen.gastric.pellets.2009',
          ),
          _prior(
            'lag_exp.half',
            'T50',
            weightedHalfMinutes,
            'min',
            'src.burmen.gastric.pellets.2009',
          ),
        ],
        evidenceSourceIds: const <String>[
          'src.burmen.gastric.pellets.2009',
          'src.internal.prototype.heuristic',
        ],
        supportedDomain:
            'Read-only single-phase normalized retention comparison; pellet evidence does not calibrate an ordinary meal.',
        limitation:
            'Single aggregate lag cannot reproduce component-specific or interruptive emptying.',
      ),
      GastricStructureContract(
        id: 'gastric.shadow.linear_exponential_volume.v1',
        kind: GastricStructureKind.linearExponentialVolume,
        name: 'Linear-exponential volume',
        formula: 'V(t)=V0*(1+kappa*t/T)*exp(-t/T)',
        observable: GastricMeasuredObservable.absoluteGastricVolume,
        modality: GastricMeasurementModality.magneticResonanceImaging,
        originalUnit: 'mL',
        canonicalUnit: 'mL',
        freeParameterIds: const <String>[
          'linexp.v0',
          'linexp.kappa',
          'linexp.time',
        ],
        parameters: <GastricStructureParameter>[
          _prior(
            'linexp.v0',
            'V0',
            400,
            'mL',
            'src.bertoli.gastric.linearexp.2023',
          ),
          _prior(
            'linexp.kappa',
            'kappa',
            0.2,
            '1',
            'src.bertoli.gastric.linearexp.2023',
          ),
          _prior(
            'linexp.time',
            'T',
            t50Minutes,
            'min',
            'src.bertoli.gastric.linearexp.2023',
          ),
        ],
        evidenceSourceIds: const <String>['src.bertoli.gastric.linearexp.2023'],
        supportedDomain:
            'Serial MRI absolute gastric volume where secretion-related early volume increase is measurable.',
        limitation:
            'Absolute volume can initially rise and cannot be overlaid as normalized scintigraphic retention.',
      ),
      GastricStructureContract(
        id: 'gastric.shadow.double_weibull_pellet.v1',
        kind: GastricStructureKind.doubleWeibullPellet,
        name: 'Double-Weibull pellet retention',
        formula: 'R(t)=(1-H)*exp(-(t/eta1)^beta1)+H*exp(-(t/eta2)^beta2)',
        observable: GastricMeasuredObservable.pelletRetention,
        modality: GastricMeasurementModality.scintigraphy,
        originalUnit: 'percent_pellets_retained',
        canonicalUnit: 'fraction',
        freeParameterIds: const <String>[
          'double_weibull.h',
          'double_weibull.eta1',
          'double_weibull.beta1',
          'double_weibull.eta2',
          'double_weibull.beta2',
        ],
        parameters: <GastricStructureParameter>[
          _prior(
            'double_weibull.h',
            'H',
            0.35,
            'fraction',
            'src.burmen.gastric.pellets.2009',
          ),
          _prior(
            'double_weibull.eta1',
            'eta1',
            t50Minutes * 0.65,
            'min',
            'src.burmen.gastric.pellets.2009',
          ),
          _prior(
            'double_weibull.beta1',
            'beta1',
            1.3,
            '1',
            'src.burmen.gastric.pellets.2009',
          ),
          _prior(
            'double_weibull.eta2',
            'eta2',
            t50Minutes * 1.55,
            'min',
            'src.burmen.gastric.pellets.2009',
          ),
          _prior(
            'double_weibull.beta2',
            'beta2',
            0.85,
            '1',
            'src.burmen.gastric.pellets.2009',
          ),
        ],
        evidenceSourceIds: const <String>['src.burmen.gastric.pellets.2009'],
        supportedDomain:
            'Scintigraphic retention of multiparticulate pellets under the declared fed or fasting protocol.',
        limitation:
            'Pellet transit is not interchangeable with ordinary food retention or whole-stomach MRI volume.',
      ),
    ];
  }

  GastricStructureParameter _prior(
    String id,
    String symbol,
    double value,
    String unit,
    String source,
  ) => _parameter(
    id: id,
    symbol: symbol,
    value: value,
    unit: unit,
    authority: GastricParameterAuthority.priorFixed,
    sources: <String>[source, 'src.internal.prototype.heuristic'],
  );

  GastricStructureParameter _parameter({
    required String id,
    required String symbol,
    required double value,
    required String unit,
    required GastricParameterAuthority authority,
    required List<String> sources,
  }) => GastricStructureParameter(
    id: id,
    symbol: symbol,
    value: value,
    unit: unit,
    authority: authority,
    sourceIds: sources,
    limitation: authority == GastricParameterAuthority.productionBound
        ? 'Bound to the unchanged production profile for this replay.'
        : 'Prior-fixed illustrative value; not estimated from an individual or clinical dataset.',
  );

  double _evaluate({
    required GastricStructureContract contract,
    required int minute,
    required GastricEmptyingProfile productionProfile,
  }) {
    final p = <String, double>{
      for (final parameter in contract.parameters)
        parameter.id: parameter.value,
    };
    final t = minute.toDouble();
    return switch (contract.kind) {
      GastricStructureKind.productionComponentLagExponential =>
        productionProfile.remainingFractionAt(minute),
      GastricStructureKind.elashoffPowerExponential =>
        math
            .pow(2, -math.pow(t / p['elashoff.t50']!, p['elashoff.beta']!))
            .toDouble(),
      GastricStructureKind.siegelModifiedPowerExponential =>
        1 -
            math
                .pow(1 - math.exp(-p['siegel.k']! * t), p['siegel.beta']!)
                .toDouble(),
      GastricStructureKind.explicitLagExponential =>
        t <= p['lag_exp.lag']!
            ? 1
            : math.exp(
                -math.ln2 * (t - p['lag_exp.lag']!) / p['lag_exp.half']!,
              ),
      GastricStructureKind.linearExponentialVolume =>
        p['linexp.v0']! *
            (1 + p['linexp.kappa']! * t / p['linexp.time']!) *
            math.exp(-t / p['linexp.time']!),
      GastricStructureKind.doubleWeibullPellet =>
        (1 - p['double_weibull.h']!) *
                math.exp(
                  -math.pow(
                    t / p['double_weibull.eta1']!,
                    p['double_weibull.beta1']!,
                  ),
                ) +
            p['double_weibull.h']! *
                math.exp(
                  -math.pow(
                    t / p['double_weibull.eta2']!,
                    p['double_weibull.beta2']!,
                  ),
                ),
    };
  }

  List<GastricStructuralDisagreement> _pairwiseDisagreements(
    List<GastricShadowTrajectory> trajectories,
  ) {
    final available = trajectories
        .where(
          (trajectory) =>
              trajectory.availability ==
              GastricTrajectoryAvailability.available,
        )
        .toList(growable: false);
    final out = <GastricStructuralDisagreement>[];
    for (var leftIndex = 0; leftIndex < available.length; leftIndex++) {
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < available.length;
        rightIndex++
      ) {
        final left = available[leftIndex];
        final right = available[rightIndex];
        if (left.structure.observable != right.structure.observable ||
            left.structure.modality != right.structure.modality ||
            left.points.length != right.points.length) {
          continue;
        }
        var sum = 0.0;
        var maximum = -1.0;
        var maximumMinute = 0;
        for (
          var pointIndex = 0;
          pointIndex < left.points.length;
          pointIndex++
        ) {
          final leftPoint = left.points[pointIndex];
          final rightPoint = right.points[pointIndex];
          if (leftPoint.minute != rightPoint.minute) {
            throw StateError('Shadow trajectories do not share a time grid.');
          }
          final difference = (leftPoint.value - rightPoint.value).abs();
          sum += difference;
          if (difference > maximum) {
            maximum = difference;
            maximumMinute = leftPoint.minute;
          }
        }
        out.add(
          GastricStructuralDisagreement(
            leftStructureId: left.structure.id,
            rightStructureId: right.structure.id,
            observable: left.structure.observable,
            meanAbsoluteDifference: sum / left.points.length,
            maximumAbsoluteDifference: maximum,
            maximumDifferenceMinute: maximumMinute,
          ),
        );
      }
    }
    return List<GastricStructuralDisagreement>.unmodifiable(out);
  }
}

String _digest(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is Iterable) return '[${value.map(_canonicalJson).join(',')}]';
  return jsonEncode(value);
}
