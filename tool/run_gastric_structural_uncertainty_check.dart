import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/gastric_structural_uncertainty.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_structural_uncertainty_service.dart';

void main() {
  final service = AlgorithmObservatoryService();
  final snapshot = service.build(ObservatoryScenario.mixedReference);
  final replay = service.build(ObservatoryScenario.mixedReference);
  final report = snapshot.gastricStructuralUncertainty!;
  final checks = <Map<String, Object?>>[];

  void check(String id, bool passed, String detail) {
    checks.add(<String, Object?>{'id': id, 'passed': passed, 'detail': detail});
  }

  final available = report.trajectories
      .where(
        (trajectory) =>
            trajectory.availability == GastricTrajectoryAvailability.available,
      )
      .toList(growable: false);
  final held = report.trajectories
      .where(
        (trajectory) =>
            trajectory.availability ==
            GastricTrajectoryAvailability.observableMismatch,
      )
      .toList(growable: false);
  check(
    'six_structure_contracts',
    report.trajectories.length == GastricStructureKind.values.length,
    '${report.trajectories.length} structures',
  );
  check(
    'four_observable_matched',
    available.length == 4,
    '${available.length} comparable trajectories',
  );
  check(
    'two_observable_held',
    held.length == 2 && held.every((trajectory) => trajectory.points.isEmpty),
    '${held.length} held trajectories with no numeric projection',
  );
  check(
    'formula_identity_complete',
    report.trajectories.every(
      (trajectory) =>
          trajectory.structure.formula.isNotEmpty &&
          trajectory.structure.evidenceSourceIds.isNotEmpty &&
          trajectory.structure.originalUnit.isNotEmpty &&
          trajectory.structure.canonicalUnit.isNotEmpty,
    ),
    'formula, source, and unit identity present',
  );
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
  check(
    'elashoff_siegel_not_conflated',
    elashoff.structure.formula != siegel.structure.formula &&
        elashoff.structure.freeParameterIds
            .toSet()
            .intersection(siegel.structure.freeParameterIds.toSet())
            .isEmpty,
    'distinct equations and parameter namespaces',
  );
  check(
    'production_invariant',
    report.productionOutputDigestBefore == report.productionOutputDigestAfter,
    report.productionOutputDigestBefore,
  );
  check(
    'ledger_identity_bound',
    report.eventLedgerDigest == snapshot.eventLedger.sha256Digest &&
        report.eventLedgerReplayDigest ==
            snapshot.eventLedger.canonicalReplayDigest &&
        report.configurationDigest ==
            snapshot.configurationIdentity.sha256Digest,
    'ledger, replay, and configuration identities match',
  );
  check(
    'trajectory_bounds',
    available.every(
      (trajectory) =>
          trajectory.points.isNotEmpty &&
          trajectory.points.every(
            (point) =>
                point.value.isFinite && point.value >= 0 && point.value <= 1,
          ),
    ),
    'all comparable points finite and within [0,1]',
  );
  check(
    'deterministic_replay',
    replay.gastricStructuralUncertainty!.sha256Digest == report.sha256Digest,
    report.sha256Digest,
  );
  check(
    'pairwise_disagreement_complete',
    report.disagreements.length == 6 &&
        report.disagreements.every(
          (item) =>
              item.meanAbsoluteDifference.isFinite &&
              item.maximumAbsoluteDifference >= item.meanAbsoluteDifference,
        ),
    '${report.disagreements.length} pairwise comparisons',
  );
  check(
    'synthetic_fit_held',
    report.trajectories.every(
      (trajectory) =>
          trajectory.fitAuthorization.disposition !=
          GastricFitDisposition.eligibleForResearchFit,
    ),
    'production-derived synthetic series cannot authorize fitting',
  );

  final fitService = const GastricStructuralUncertaintyService();
  final externalSeries = GastricObservationSeries(
    id: 'gate_external_scintigraphy_v1',
    observable: GastricMeasuredObservable.normalizedIntragastricRetention,
    modality: GastricMeasurementModality.scintigraphy,
    originalUnit: 'percent_retained',
    canonicalUnit: 'fraction',
    points: [
      GastricObservationPoint(minute: 0, value: 1),
      GastricObservationPoint(minute: 30, value: 0.94),
      GastricObservationPoint(minute: 60, value: 0.81),
      GastricObservationPoint(minute: 90, value: 0.66),
      GastricObservationPoint(minute: 120, value: 0.49),
      GastricObservationPoint(minute: 180, value: 0.21),
    ],
    synthetic: false,
    derivedFromProduction: false,
    sourceIds: const ['src.synthetic.gastric.structural.fixture'],
  );
  GastricFitEvidence evidence({
    int multistart = 20,
    int optima = 1,
    bool bounded = true,
    double condition = 50,
    int heldOut = 2,
    double rmse = 0.03,
    bool independent = true,
  }) => GastricFitEvidence(
    datasetSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    multistartRuns: multistart,
    distinctStableOptima: optima,
    profileLikelihoodBounded: bounded,
    conditionNumber: condition,
    heldOutPointCount: heldOut,
    heldOutRmse: rmse,
    heldOutRmseThreshold: 0.05,
    independentImplementation: independent,
  );

  GastricFitAuthorization authorize(GastricFitEvidence diagnostics) =>
      fitService.authorizeFit(
        contract: elashoff.structure,
        series: externalSeries,
        evidence: diagnostics,
      );
  check(
    'eligible_external_fit',
    authorize(evidence()).disposition ==
        GastricFitDisposition.eligibleForResearchFit,
    'all prospective research-fit prerequisites observed',
  );
  check(
    'multistart_mutation_blocked',
    authorize(evidence(multistart: 2, optima: 3)).disposition ==
        GastricFitDisposition.blocked,
    'insufficient multistart and multiple optima blocked',
  );
  check(
    'identifiability_mutation_blocked',
    authorize(evidence(bounded: false, condition: 10000000)).disposition ==
        GastricFitDisposition.blocked,
    'unbounded profile and ill-conditioned fit blocked',
  );
  check(
    'heldout_mutation_blocked',
    authorize(evidence(heldOut: 1, rmse: 0.20)).disposition ==
        GastricFitDisposition.blocked,
    'insufficient and failed held-out prediction blocked',
  );
  check(
    'independence_mutation_blocked',
    authorize(evidence(independent: false)).disposition ==
        GastricFitDisposition.blocked,
    'shared diagnostic implementation blocked',
  );
  check(
    'nonclinical_boundary',
    report.boundary.contains('not an ensemble') &&
        report.boundary.contains('clinical validation'),
    report.boundary,
  );

  final productionProfile = snapshot.conflict.primaryEmptyingProfile!;
  const referenceMinutes = <int>[0, 10, 30, 60, 120, 240, 480];
  final referenceVectors = <Map<String, Object?>>[
    for (final trajectory in report.trajectories)
      <String, Object?>{
        'structure_id': trajectory.structure.id,
        'kind': trajectory.structure.kind.name,
        'observable': trajectory.structure.observable.name,
        'canonical_unit': trajectory.structure.canonicalUnit,
        'formula': trajectory.structure.formula,
        'parameters': <String, String>{
          for (final parameter in trajectory.structure.parameters)
            parameter.id: parameter.value.toString(),
        },
        'dart_values': <Map<String, Object?>>[
          for (final minute in referenceMinutes)
            <String, Object?>{
              'minute': minute,
              'value_decimal': fitService
                  .evaluateDeclaredStructure(
                    contract: trajectory.structure,
                    minute: minute,
                    productionProfile: productionProfile,
                  )
                  .toString(),
            },
        ],
      },
  ];
  check(
    'precision_reference_vectors_complete',
    referenceVectors.length == GastricStructureKind.values.length &&
        referenceVectors.every(
          (vector) =>
              (vector['dart_values']! as List).length ==
              referenceMinutes.length,
        ),
    '${referenceVectors.length} structures × ${referenceMinutes.length} points',
  );

  final passed = checks.every((item) => item['passed'] == true);
  final output = <String, Object?>{
    'schema': 'parkinsum.gastric-structural-uncertainty-check/1',
    'passed': passed,
    'case_count': checks.length,
    'report_digest': report.sha256Digest,
    'configuration_digest': report.configurationDigest,
    'reference_vectors': referenceVectors,
    'checks': checks,
    'boundary': report.boundary,
  };
  final directory = Directory('build/gastric_structural_uncertainty')
    ..createSync(recursive: true);
  File('${directory.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
  File('${directory.path}/latest.md').writeAsStringSync(
    <String>[
      '# Gastric structural-uncertainty check',
      '',
      '**Result:** ${passed ? 'PASS' : 'FAILED'}',
      '',
      '| Check | Status | Detail |',
      '| --- | --- | --- |',
      for (final item in checks)
        '| ${item['id']} | ${item['passed'] == true ? 'pass' : 'FAILED'} | ${item['detail']} |',
      '',
      '## Boundary',
      '',
      report.boundary,
      '',
    ].join('\n'),
  );
  stdout.writeln(
    'Gastric structural-uncertainty check: '
    '${passed ? 'PASS' : 'FAILED'}; ${checks.length} cases; '
    'digest=${report.sha256Digest.substring(0, 12)}.',
  );
  if (!passed) exitCode = 1;
}
