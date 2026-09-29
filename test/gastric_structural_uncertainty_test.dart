import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/gastric_structural_uncertainty.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_structural_uncertainty_service.dart';

void main() {
  late AlgorithmObservatorySnapshot snapshot;
  late GastricStructuralUncertaintyReport report;

  setUp(() {
    snapshot = AlgorithmObservatoryService().build(
      ObservatoryScenario.mixedReference,
    );
    report = snapshot.gastricStructuralUncertainty!;
  });

  test(
    'all six structures are explicit and observable mismatch fails closed',
    () {
      expect(report.integrityReasons, isEmpty);
      expect(
        report.trajectories,
        hasLength(GastricStructureKind.values.length),
      );
      expect(
        report.trajectories
            .map((trajectory) => trajectory.structure.kind)
            .toSet(),
        GastricStructureKind.values.toSet(),
      );
      final available = report.trajectories
          .where(
            (trajectory) =>
                trajectory.availability ==
                GastricTrajectoryAvailability.available,
          )
          .toList(growable: false);
      expect(available, hasLength(4));
      expect(report.disagreements, hasLength(6));

      final linear = report.trajectories.singleWhere(
        (trajectory) =>
            trajectory.structure.kind ==
            GastricStructureKind.linearExponentialVolume,
      );
      expect(
        linear.availability,
        GastricTrajectoryAvailability.observableMismatch,
      );
      expect(linear.points, isEmpty);
      expect(
        linear.structure.observable,
        GastricMeasuredObservable.absoluteGastricVolume,
      );
      expect(
        linear.structure.modality,
        GastricMeasurementModality.magneticResonanceImaging,
      );

      final doubleWeibull = report.trajectories.singleWhere(
        (trajectory) =>
            trajectory.structure.kind ==
            GastricStructureKind.doubleWeibullPellet,
      );
      expect(
        doubleWeibull.availability,
        GastricTrajectoryAvailability.observableMismatch,
      );
      expect(
        doubleWeibull.structure.observable,
        GastricMeasuredObservable.pelletRetention,
      );
    },
  );

  test('Elashoff and Siegel structures remain mathematically distinct', () {
    final elashoff = report.trajectories.singleWhere(
      (trajectory) =>
          trajectory.structure.kind ==
          GastricStructureKind.elashoffPowerExponential,
    );
    final siegel = report.trajectories.singleWhere(
      (trajectory) =>
          trajectory.structure.kind ==
          GastricStructureKind.siegelModifiedPowerExponential,
    );
    expect(elashoff.structure.formula, contains('2^'));
    expect(siegel.structure.formula, contains('1-(1-exp'));
    expect(elashoff.structure.freeParameterIds, contains('elashoff.t50'));
    expect(siegel.structure.freeParameterIds, contains('siegel.k'));
    expect(elashoff.structure.formula, isNot(siegel.structure.formula));
    expect(
      elashoff.points.map((point) => point.value).toList(),
      isNot(siegel.points.map((point) => point.value).toList()),
    );
  });

  test(
    'read-only shadows are deterministic, bounded, and production-invariant',
    () {
      final replay = AlgorithmObservatoryService().build(
        ObservatoryScenario.mixedReference,
      );
      expect(
        replay.gastricStructuralUncertainty!.sha256Digest,
        report.sha256Digest,
      );
      expect(
        report.productionOutputDigestBefore,
        report.productionOutputDigestAfter,
      );
      expect(
        jsonEncode(replay.conflict.toJson()),
        jsonEncode(snapshot.conflict.toJson()),
      );
      expect(
        jsonEncode(
          replay.candidateScores.map((score) => score.toJson()).toList(),
        ),
        jsonEncode(
          snapshot.candidateScores.map((score) => score.toJson()).toList(),
        ),
      );
      for (final trajectory in report.trajectories.where(
        (trajectory) =>
            trajectory.availability == GastricTrajectoryAvailability.available,
      )) {
        expect(trajectory.points, isNotEmpty);
        expect(trajectory.points.first.minute, 0);
        expect(trajectory.points.first.value, closeTo(1, 1e-12));
        for (final point in trajectory.points) {
          expect(point.value, inInclusiveRange(0, 1));
        }
      }
    },
  );

  test(
    'synthetic production-derived observations can never authorize fitting',
    () {
      for (final trajectory in report.trajectories) {
        expect(
          trajectory.fitAuthorization.disposition,
          isNot(GastricFitDisposition.eligibleForResearchFit),
        );
      }
      final elashoff = report.trajectories.singleWhere(
        (trajectory) =>
            trajectory.structure.kind ==
            GastricStructureKind.elashoffPowerExponential,
      );
      expect(
        elashoff.fitAuthorization.reasons,
        contains('synthetic_series_cannot_authorize_fit'),
      );
      expect(
        elashoff.fitAuthorization.reasons,
        contains('circular_production_derived_series'),
      );
    },
  );

  test(
    'research fit requires phase coverage, diagnostics, and held-out checks',
    () {
      final service = const GastricStructuralUncertaintyService();
      final contract = report.trajectories
          .singleWhere(
            (trajectory) =>
                trajectory.structure.kind ==
                GastricStructureKind.elashoffPowerExponential,
          )
          .structure;
      final series = GastricObservationSeries(
        id: 'external_scintigraphy_series_v1',
        observable: GastricMeasuredObservable.normalizedIntragastricRetention,
        modality: GastricMeasurementModality.scintigraphy,
        originalUnit: 'percent_retained',
        canonicalUnit: 'fraction',
        points: [
          GastricObservationPoint(minute: 0, value: 1),
          GastricObservationPoint(minute: 30, value: 0.94),
          GastricObservationPoint(minute: 60, value: 0.80),
          GastricObservationPoint(minute: 90, value: 0.63),
          GastricObservationPoint(minute: 120, value: 0.48),
          GastricObservationPoint(minute: 180, value: 0.20),
        ],
        synthetic: false,
        derivedFromProduction: false,
        sourceIds: const ['src.synthetic.gastric.structural.fixture'],
      );
      final evidence = GastricFitEvidence(
        datasetSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        multistartRuns: 20,
        distinctStableOptima: 1,
        profileLikelihoodBounded: true,
        conditionNumber: 50,
        heldOutPointCount: 2,
        heldOutRmse: 0.03,
        heldOutRmseThreshold: 0.05,
        independentImplementation: true,
      );
      expect(
        service
            .authorizeFit(
              contract: contract,
              series: series,
              evidence: evidence,
            )
            .disposition,
        GastricFitDisposition.eligibleForResearchFit,
      );

      final unstable = GastricFitEvidence(
        datasetSha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        multistartRuns: 2,
        distinctStableOptima: 3,
        profileLikelihoodBounded: false,
        conditionNumber: 10000000,
        heldOutPointCount: 1,
        heldOutRmse: 0.20,
        heldOutRmseThreshold: 0.05,
        independentImplementation: false,
      );
      final blocked = service.authorizeFit(
        contract: contract,
        series: series,
        evidence: unstable,
      );
      expect(blocked.disposition, GastricFitDisposition.blocked);
      expect(blocked.reasons, contains('multistart_runs_insufficient'));
      expect(
        blocked.reasons,
        contains('practical_identifiability_not_demonstrated'),
      );
      expect(blocked.reasons, contains('held_out_predictive_check_failed'));
      expect(
        blocked.reasons,
        contains('independent_diagnostic_implementation_missing'),
      );
    },
  );

  test('declared-structure evaluator rejects negative time', () {
    final trajectory = report.trajectories.first;
    expect(
      () =>
          const GastricStructuralUncertaintyService().evaluateDeclaredStructure(
            contract: trajectory.structure,
            minute: -1,
            productionProfile: snapshot.conflict.primaryEmptyingProfile!,
          ),
      throwsArgumentError,
    );
  });
}
