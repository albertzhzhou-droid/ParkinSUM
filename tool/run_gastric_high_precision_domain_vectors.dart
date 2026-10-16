import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/gastric_structural_uncertainty.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_structural_uncertainty_service.dart';

const domainCorpusSchema = 'parkinsum.gastric-high-precision-domain-corpus/1';
const domainVectorSchema = 'parkinsum.gastric-high-precision-domain-vectors/1';
const inputPath = 'test/fixtures/gastric_high_precision_domain/cases.json';

// Protocol/domain validation is local to this manufactured vector harness.
// It neither updates production defaults nor authorizes research/clinical fits.
String? holdReason(String kind, Map<String, Object?> raw, num minute) {
  if (!minute.isFinite ||
      minute != minute.roundToDouble() ||
      minute < 0 ||
      minute > 10080) {
    return 'time_domain';
  }
  final parameters = <String, double>{};
  final decimal = RegExp(
    r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$',
    caseSensitive: false,
  );
  for (final entry in raw.entries) {
    final text = '${entry.value}'.trim();
    final exponent = int.tryParse(text.toLowerCase().split('e').last);
    final value = double.tryParse(text);
    if (!decimal.hasMatch(text) ||
        text.length > 512 ||
        value == null ||
        !value.isFinite ||
        (text.toLowerCase().contains('e') &&
            (exponent == null || exponent.abs() > 400))) {
      return 'finite_decimal_required';
    }
    parameters[entry.key] = value;
  }
  bool range(String id, double low, double high) =>
      parameters[id] != null &&
      parameters[id]! >= low &&
      parameters[id]! <= high;
  bool shape(String id) => range(id, .05, 8);
  bool scale(String id) => range(id, .000001, 1000000);
  List<String> keys;
  switch (kind) {
    case 'productionComponentLagExponential':
      final pattern = RegExp(r'^production\.([^.]+)\.(fraction|lag|half)$');
      final ids = <String>{};
      for (final id in parameters.keys) {
        final match = pattern.firstMatch(id);
        if (match == null) return 'component_identity';
        ids.add(match.group(1)!);
      }
      if (ids.isEmpty || ids.length > 4) return 'component_identity';
      var total = 0.0;
      for (final id in ids) {
        if (!range('production.$id.fraction', 0, 1) ||
            !range('production.$id.lag', 0, 1440) ||
            !scale('production.$id.half')) {
          return 'parameter_domain';
        }
        total += parameters['production.$id.fraction']!;
      }
      if (parameters.length != ids.length * 3 || (total - 1).abs() > 1e-12) {
        return 'component_weights';
      }
      return null;
    case 'elashoffPowerExponential':
      keys = ['elashoff.t50', 'elashoff.beta'];
      if (!scale(keys[0]) || !shape(keys[1])) return 'parameter_domain';
    case 'siegelModifiedPowerExponential':
      keys = ['siegel.k', 'siegel.beta'];
      if (!range(keys[0], 1e-9, 4) || !shape(keys[1])) {
        return 'parameter_domain';
      }
      if (minute > 0 &&
          parameters[keys[1]]! < 1 &&
          parameters[keys[0]]! * minute < 1e-6) {
        return 'siegel_cancellation_domain';
      }
    case 'explicitLagExponential':
      keys = ['lag_exp.lag', 'lag_exp.half'];
      if (!range(keys[0], 0, 1440) || !scale(keys[1])) {
        return 'parameter_domain';
      }
    case 'linearExponentialVolume':
      keys = ['linexp.v0', 'linexp.kappa', 'linexp.time'];
      if (!range(keys[0], 0, 2000) ||
          !range(keys[1], 0, 2) ||
          !scale(keys[2])) {
        return 'parameter_domain';
      }
    case 'doubleWeibullPellet':
      keys = [
        'double_weibull.h',
        'double_weibull.eta1',
        'double_weibull.beta1',
        'double_weibull.eta2',
        'double_weibull.beta2',
      ];
      if (!range(keys[0], 0, 1) ||
          !scale(keys[1]) ||
          !shape(keys[2]) ||
          !scale(keys[3]) ||
          !shape(keys[4])) {
        return 'parameter_domain';
      }
    default:
      return 'unsupported_structure';
  }
  return parameters.length == keys.length &&
          parameters.keys.every(keys.contains)
      ? null
      : 'parameter_identity';
}

double captureValue(String kind, Map<String, Object?> raw, int minute) {
  final p = {
    for (final entry in raw.entries) entry.key: double.parse('${entry.value}'),
  };
  final components = <EmptyingComponentProfile>[];
  if (kind == 'productionComponentLagExponential') {
    for (final id in p.keys.where((id) => id.endsWith('.fraction'))) {
      final prefix = id.substring(0, id.length - '.fraction'.length);
      components.add(
        EmptyingComponentProfile(
          componentId: prefix.substring('production.'.length),
          physicalForm: MealPhysicalForm.mixed,
          lagMinutes: p['$prefix.lag']!,
          halfEmptyingMinutes: p['$prefix.half']!,
          fractionOfMeal: p[id]!,
          appliedModifiers: const [],
        ),
      );
    }
  }
  final profile = GastricEmptyingProfile(
    mealId: 'manufactured_precision_domain',
    componentProfiles: components,
    uncertaintyBand: UncertaintyBand.veryWide,
    assumptions: const [
      'Manufactured calculation input, not fitted observations.',
    ],
    missingInputs: const [],
    sourceRefs: const ['src.synthetic.gastric.structural.fixture'],
    aggregateLagMinutes: components.fold(
      0,
      (sum, c) => sum + c.lagMinutes * c.fractionOfMeal,
    ),
    peakEmptyingWindow: const TimelineWindow(startMinute: 0, endMinute: 1),
    mostlyEmptiedWindow: const TimelineWindow(startMinute: 0, endMinute: 1),
    timeScaleSensitivityFraction: 0,
  );
  final structureKind = GastricStructureKind.values.byName(kind);
  final contract = GastricStructureContract(
    id: 'gastric.manufactured.precision_domain',
    kind: structureKind,
    name: 'Manufactured precision-domain vector',
    formula: 'Existing declared production/shadow evaluator only',
    observable: structureKind == GastricStructureKind.linearExponentialVolume
        ? GastricMeasuredObservable.absoluteGastricVolume
        : structureKind == GastricStructureKind.doubleWeibullPellet
        ? GastricMeasuredObservable.pelletRetention
        : GastricMeasuredObservable.normalizedIntragastricRetention,
    modality: structureKind == GastricStructureKind.linearExponentialVolume
        ? GastricMeasurementModality.magneticResonanceImaging
        : GastricMeasurementModality.scintigraphy,
    originalUnit: structureKind == GastricStructureKind.linearExponentialVolume
        ? 'mL'
        : 'fraction',
    canonicalUnit: structureKind == GastricStructureKind.linearExponentialVolume
        ? 'mL'
        : 'fraction',
    freeParameterIds: const [],
    parameters: [
      for (final entry in p.entries)
        GastricStructureParameter(
          id: entry.key,
          symbol: entry.key,
          value: entry.value,
          unit: entry.key.endsWith('.k')
              ? '1/min'
              : entry.key.endsWith('.v0')
              ? 'mL'
              : RegExp(r'\.(lag|half|t50|time|eta1|eta2)$').hasMatch(entry.key)
              ? 'min'
              : '1',
          authority: GastricParameterAuthority.priorFixed,
          sourceIds: const ['src.synthetic.gastric.structural.fixture'],
          limitation:
              'Manufactured arithmetic check; no fit or clinical qualification.',
        ),
    ],
    evidenceSourceIds: const ['src.synthetic.gastric.structural.fixture'],
    supportedDomain: 'Frozen manufactured precision-verification domain only.',
    limitation: 'No clinical calibration or automatic parameter changes.',
  );
  return const GastricStructuralUncertaintyService().evaluateDeclaredStructure(
    contract: contract,
    minute: minute,
    productionProfile: profile,
  );
}

void main() {
  final bytes = File(inputPath).readAsBytesSync();
  final corpus = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (corpus['schema'] != domainCorpusSchema ||
      corpus['seed'] != 20260930 ||
      corpus['tolerance_decimal'] != '0.000000000005') {
    throw FormatException('Unsupported manufactured domain corpus.');
  }
  final vectors = <Map<String, Object?>>[];
  for (final input in (corpus['cases'] as List).cast<Map<String, dynamic>>()) {
    final kind = input['kind'] as String;
    final parameters = Map<String, Object?>.from(input['parameters'] as Map);
    final points = <Map<String, Object?>>[];
    for (final minute in (input['minutes'] as List).cast<num>()) {
      final reason = holdReason(kind, parameters, minute);
      final diagnostic = input['diagnostic_only'] == true;
      final value = reason == null || diagnostic
          ? captureValue(kind, parameters, minute.toInt())
          : null;
      if (value != null && !value.isFinite) {
        throw StateError('Non-finite production vector.');
      }
      points.add({
        'minute': minute,
        'status': reason == null ? 'supported' : 'HOLD',
        'hold_reason': reason,
        'value_decimal': value?.toString(),
        'diagnostic_only': diagnostic,
      });
    }
    vectors.add({
      'case_id': input['case_id'],
      'kind': kind,
      'parameters': parameters,
      'points': points,
    });
  }
  final output = {
    'schema': domainVectorSchema,
    'input_sha256': sha256.convert(bytes).toString(),
    'vector_capture_complete': true,
    'clinical_calibration': 'HOLD',
    'production_formula_source':
        'GastricStructuralUncertaintyService.evaluateDeclaredStructure',
    'vectors': vectors,
  };
  Directory(
    'build/gastric_high_precision_domain_vectors',
  ).createSync(recursive: true);
  File(
    'build/gastric_high_precision_domain_vectors/latest.json',
  ).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
  stdout.writeln(
    'Manufactured production domain vectors: ${vectors.length} parameter cases.',
  );
}
