import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/domain/entities/gastric_structural_uncertainty.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_structural_uncertainty_service.dart';
import 'run_gastric_high_precision_domain_vectors.dart' as precision;

void main() {
  const root = 'build/gastric_identifiability';
  Directory(root).createSync(recursive: true);
  final target = File('$root/actual_vectors.json');
  final studies = <Map<String, Object?>>[];
  for (final planName in [
    'config/gastric_identifiability_coarse_plan.json',
    'config/gastric_identifiability_fine_plan.json',
  ]) {
    final bytes = File(planName).readAsBytesSync();
    final plan = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final models = <Map<String, Object?>>[];
    for (final model in (plan['models'] as List).cast<Map<String, dynamic>>()) {
      final id = model['id'] as String;
      final elashoff = id.contains('elashoff');
      final kind = elashoff
          ? 'elashoffPowerExponential'
          : 'explicitLagExponential';
      final prefix = elashoff ? 'elashoff' : 'lag_exp';
      final grid = (model['grid'] as Map).cast<String, List>();
      final keys = grid.keys.toList();
      final times = <int>{
        ...((plan['additional_failure_design'] as List).single['schedule']
                as List)
            .cast<int>(),
        for (final schedule in model['schedules'] as List)
          ...(schedule['minutes'] as List).cast<int>(),
      }.toList()..sort();
      final vectors = <Map<String, Object?>>[];
      for (final a in grid[keys[0]]!) {
        for (final b in grid[keys[1]]!) {
          final parameters = <String, Object?>{
            '$prefix.${keys[0]}': a,
            '$prefix.${keys[1]}': b,
          };
          final points = <Map<String, Object?>>[];
          for (final t in times) {
            final hold = precision.holdReason(kind, parameters, t);
            if (hold != null) {
              throw StateError('Declared domain is held: $hold');
            }
            final value = precision.captureValue(kind, parameters, t);
            if (!value.isFinite) {
              throw StateError('Nonfinite production value.');
            }
            points.add({'minute': t, 'value': value});
          }
          vectors.add({
            'parameters': {keys[0]: a, keys[1]: b},
            'points': points,
          });
        }
      }
      final truth = (model['truth'] as Map).cast<String, num>();
      final contract = GastricStructureContract(
        id: id,
        kind: GastricStructureKind.values.byName(kind),
        name: 'Manufactured identifiability research only',
        formula: model['equation'] as String,
        observable: GastricMeasuredObservable.normalizedIntragastricRetention,
        modality: GastricMeasurementModality.scintigraphy,
        originalUnit: 'fraction',
        canonicalUnit: 'fraction',
        freeParameterIds: truth.keys.map((key) => '$prefix.$key').toList(),
        parameters: [
          for (final entry in truth.entries)
            GastricStructureParameter(
              id: '$prefix.${entry.key}',
              symbol: entry.key,
              value: entry.value.toDouble(),
              unit: entry.key == 'beta' ? '1' : 'min',
              authority: GastricParameterAuthority.priorFixed,
              sourceIds: const ['src.synthetic.gastric.identifiability'],
              limitation: 'Manufactured finite grid, no person or calibration.',
            ),
        ],
        evidenceSourceIds: const ['src.synthetic.gastric.identifiability'],
        supportedDomain: 'Frozen synthetic finite-grid study only.',
        limitation:
            'No clinical calibration, fitted production defaults or scoring changes.',
      );
      final series = GastricObservationSeries(
        id: 'synthetic_grid_hold',
        observable: contract.observable,
        modality: contract.modality,
        originalUnit: 'fraction',
        canonicalUnit: 'fraction',
        points: [
          for (final t in times)
            GastricObservationPoint(
              minute: t,
              value: precision.captureValue(kind, {
                for (final entry in truth.entries)
                  '$prefix.${entry.key}': entry.value,
              }, t),
            ),
        ],
        synthetic: true,
        derivedFromProduction: true,
        sourceIds: const ['src.synthetic.gastric.identifiability'],
      );
      final authorization = const GastricStructuralUncertaintyService()
          .authorizeFit(contract: contract, series: series, evidence: null);
      if (authorization.disposition != GastricFitDisposition.priorFixedOnly ||
          !authorization.reasons.contains(
            'synthetic_series_cannot_authorize_fit',
          )) {
        throw StateError('Synthetic fit authorization changed.');
      }
      models.add({
        'model_id': id,
        'kind': kind,
        'grid_candidate_count': vectors.length,
        'vectors': vectors,
        'actual_fit_disposition': authorization.disposition.name,
        'actual_fit_reasons': authorization.reasons,
      });
    }
    studies.add({
      'plan_path': planName,
      'plan_sha256': sha256.convert(bytes).toString(),
      'models': models,
    });
  }
  target.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'schema': 'parkinsum.gastric-identifiability-vectors/1',
      'observed_at_utc': DateTime.now().toUtc().toIso8601String(),
      'producer': 'Actual GastricStructuralUncertaintyService.evaluateDeclaredStructure via existing domain-vector harness; no copied equation.',
      'studies': studies,
      'source_file_sha256': {
        for (final p in ['lib/domain/usecases/gastric_structural_uncertainty_service.dart', 'lib/domain/entities/gastric_structural_uncertainty.dart', 'tool/run_gastric_high_precision_domain_vectors.dart']) p: sha256.convert(File(p).readAsBytesSync()).toString(),
      },
      'boundary': 'All inputs manufactured; independent grid recovery comparison is separate. Actual synthetic fit authorization remains priorFixedOnly.',
    })}\n',
  );
  stdout.writeln(target.path);
}
