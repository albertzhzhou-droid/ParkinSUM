/// Compares the Dart physiology reference port with the Python reference.
///
/// The fixture (`test/fixtures/physiology_reference_agreement.json`) is
/// written by `tool/physiology_reference/agreement.py`. This library rebuilds
/// every scenario from its specification, runs the Dart port and checks each
/// number against the fixture within the fixture's stated tolerance. Shared by
/// `tool/run_physiology_reference_agreement.dart` (gate report) and
/// `test/physiology_reference_agreement_test.dart`.
library;

import 'dart:math' as math;

import 'package:parkinsum_companion/domain/entities/physiology_reference_parameters.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_model.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_trace_provider.dart';

const String physiologyAgreementFixturePath =
    'test/fixtures/physiology_reference_agreement.json';
const String physiologyAgreementReportSchema =
    'parkinsum.physiology-reference-agreement-report/1';

final class PhysiologyAgreementReport {
  final double relativeTolerance;
  final double absoluteTolerance;
  final Map<String, double> maxRelativeDifferenceBySection;
  final Map<String, int> comparedValuesBySection;
  final List<String> failures;

  const PhysiologyAgreementReport({
    required this.relativeTolerance,
    required this.absoluteTolerance,
    required this.maxRelativeDifferenceBySection,
    required this.comparedValuesBySection,
    required this.failures,
  });

  bool get pass => failures.isEmpty;

  double get maxRelativeDifference =>
      maxRelativeDifferenceBySection.values.fold(0.0, math.max);

  Map<String, Object?> toJson() => {
    'schema': physiologyAgreementReportSchema,
    'pass': pass,
    'fixture': physiologyAgreementFixturePath,
    'parameter_set_version':
        PhysiologyReferenceParameterSet.parameterSetVersion,
    'tolerance': {'relative': relativeTolerance, 'absolute': absoluteTolerance},
    'max_relative_difference': maxRelativeDifference,
    'max_relative_difference_by_section': maxRelativeDifferenceBySection,
    'compared_values_by_section': comparedValuesBySection,
    'failures': failures.take(50).toList(),
    'boundary':
        'Agreement of two implementations of the same educational model; it '
        'is not validation against human data (see reality_checks.py) and '
        'not a prediction for any person.',
  };
}

PhysiologyComponentForm _form(String name) =>
    PhysiologyComponentForm.values.firstWhere((form) => form.name == name);

PhysiologyComponent physiologyComponentFromSpec(Map<String, dynamic> spec) {
  final aminoAcids = spec['amino_acids_g'] as Map<String, dynamic>?;
  return PhysiologyComponent(
    spec['name'] as String,
    _form(spec['form'] as String),
    kcal: (spec['kcal'] as num).toDouble(),
    proteinG: (spec['protein_g'] as num).toDouble(),
    aminoAcidsG: aminoAcids?.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    ),
    waterMl: (spec['water_ml'] as num).toDouble(),
  );
}

PhysiologyScenario physiologyScenarioFromSpec(Map<String, dynamic> spec) {
  double d(Object? value) => (value as num).toDouble();
  return PhysiologyScenario(
    meals: [
      for (final meal in spec['meals'] as List)
        PhysiologyMeal(d(meal['time_min']), [
          for (final component in meal['components'] as List)
            physiologyComponentFromSpec(component as Map<String, dynamic>),
        ]),
    ],
    doses: [
      for (final dose in spec['doses'] as List)
        PhysiologyDose(d(dose['time_min']), d(dose['levodopa_mg'])),
    ],
    infusions: [
      for (final infusion in spec['infusions'] as List)
        PhysiologyInfusion(
          d(infusion['start_min']),
          d(infusion['end_min']),
          d(infusion['mg_per_min']),
        ),
    ],
    tEndMin: d(spec['t_end_min']),
    dtMin: d(spec['dt_min']),
    recordEveryMin: d(spec['record_every_min']),
  );
}

/// Carter 1989 sampling times: hourly 08:00–21:00 on day two.
final List<double> _carterSampleTimes = [
  for (var h = 8; h < 22; h++) 1440.0 + h * 60.0,
];

/// The reality-check quantities, defined as in `reality_checks.py`.
Map<String, double> physiologyDerivedQuantities(
  Map<String, PhysiologySeries> curves,
) {
  final out = <String, double>{};
  final sf = curves['fasting_dose']!;
  final sm = curves['meal_with_dose']!;
  final (tmaxF, cmaxF) = sf.peak('levodopa_mg_per_l');
  final (tmaxM, cmaxM) = sm.peak('levodopa_mg_per_l');
  final y0 = sf.at('levodopa_mg_per_l', 180);
  final y1 = sf.at('levodopa_mg_per_l', 360);
  out['nutt.fasting_tmax_min'] = tmaxF;
  out['nutt.meal_delay_min'] = tmaxM - tmaxF;
  out['nutt.meal_peak_reduction'] = 1 - cmaxM / cmaxF;
  out['levodopa.half_life_min'] = 180 * math.ln2 / math.log(y0 / y1);
  for (final t in [60, 120, 240]) {
    out['tougas.retention_${t}_min'] = curves['tougas_meal']!.at(
      'stomach_retention_solid',
      t.toDouble(),
    );
  }
  final sg = curves['brener_glucose']!;
  out['brener.energy_rate_kcal_per_min'] =
      (sg.at('stomach_kcal', 20) - sg.at('stomach_kcal', 90)) / 70.0;
  for (final diet in ['high', 'even', 'evening']) {
    final s = curves['carter_$diet']!;
    double mean(String key) {
      var total = 0.0;
      for (final t in _carterSampleTimes) {
        total += s.at(key, t);
      }
      return total / _carterSampleTimes.length;
    }

    out['carter.${diet}_lnaa6_daytime_mean_umol_per_l'] = mean(
      'lnaa6_umol_per_l',
    );
    out['carter.${diet}_levodopa_daytime_mean_mg_per_l'] = mean(
      'levodopa_mg_per_l',
    );
  }
  for (final aa in ['phe', 'leu', 'gly']) {
    out['nutt.infusion_${aa}_brain_entry_index_min'] =
        curves['nutt_infusion_$aa']!.trough('brain_entry_index', 240, 600).$2;
  }
  for (final name in ['whey', 'casein']) {
    final (t, y) = curves['boirie_$name']!.peak('leu_umol_per_l');
    out['boirie.${name}_leu_peak_min'] = t;
    out['boirie.${name}_leu_peak_umol_per_l'] = y;
  }
  return out;
}

PhysiologyAgreementReport comparePhysiologyAgreement(
  Map<String, dynamic> fixture,
) {
  final tolerance = fixture['tolerance'] as Map<String, dynamic>;
  final relative = (tolerance['relative'] as num).toDouble();
  final absolute = (tolerance['absolute'] as num).toDouble();
  final failures = <String>[];
  final worst = <String, double>{};
  final counts = <String, int>{};

  void check(String section, String path, Object? expected, double actual) {
    counts[section] = (counts[section] ?? 0) + 1;
    if (expected is! num) {
      failures.add('$path: expected a number, found $expected');
      return;
    }
    final e = expected.toDouble();
    final diff = (e - actual).abs();
    final scale = math.max(e.abs(), actual.abs());
    if (scale > 0) {
      worst[section] = math.max(worst[section] ?? 0.0, diff / scale);
    }
    if (!(diff <= absolute + relative * scale)) {
      failures.add('$path: Dart $actual, Python $e');
    }
  }

  if (fixture['parameter_set_version'] !=
      PhysiologyReferenceParameterSet.parameterSetVersion) {
    failures.add(
      'parameter_set_version: fixture ${fixture['parameter_set_version']}, '
      'Dart ${PhysiologyReferenceParameterSet.parameterSetVersion}',
    );
  }

  final central = PhysiologyParameterValues.central();
  final curves = <String, PhysiologySeries>{};
  for (final raw in fixture['curves'] as List) {
    final curve = raw as Map<String, dynamic>;
    final id = curve['id'] as String;
    final series = simulatePhysiology(
      physiologyScenarioFromSpec(curve['scenario'] as Map<String, dynamic>),
      central,
    );
    curves[id] = series;
    final stride = curve['sample_stride'] as int;
    final samples = curve['samples'] as Map<String, dynamic>;
    for (final key in PhysiologySeries.keys) {
      final expected = samples[key] as List;
      final actual = [
        for (var i = 0; i < series[key].length; i += stride) series[key][i],
      ];
      if (expected.length != actual.length) {
        failures.add(
          '$id.$key: ${actual.length} samples, expected '
          '${expected.length}',
        );
        continue;
      }
      for (var i = 0; i < actual.length; i++) {
        check('curves', '$id.$key[$i]', expected[i], actual[i]);
      }
    }
  }

  final derived = fixture['derived'] as Map<String, dynamic>;
  final dartDerived = physiologyDerivedQuantities(curves);
  if (derived.keys.toSet().length != dartDerived.length ||
      !dartDerived.keys.every(derived.containsKey)) {
    failures.add('derived: quantity names differ');
  }
  for (final entry in dartDerived.entries) {
    check('derived', 'derived.${entry.key}', derived[entry.key], entry.value);
  }

  final convention = fixture['timing_convention'] as Map<String, dynamic>;
  final provider = PhysiologyReferenceTraceProvider(
    draws: convention['draws'] as int,
    seed: convention['seed'] as int,
  );
  if ((convention['dose_mg'] as num) != physiologyReferenceDoseMg ||
      (convention['window_min'] as List).last !=
          physiologyComparisonWindowEndMin) {
    failures.add('timing_convention differs from the trace provider');
  }
  final rows = fixture['timing_rows'] as List;
  final dartRows = provider.observatoryRows;
  if (rows.length != dartRows.length) {
    failures.add(
      'timing_rows: ${dartRows.length} rows, expected '
      '${rows.length}',
    );
  }
  for (var r = 0; r < math.min(rows.length, dartRows.length); r++) {
    final row = rows[r] as Map<String, dynamic>;
    final dart = dartRows[r];
    final label = 'timing_rows[${dart.label}]';
    if (row['meal_offset_min'] != dart.mealOffsetMin) {
      failures.add(
        '$label: offset ${dart.mealOffsetMin}, expected '
        '${row['meal_offset_min']}',
      );
    }
    final expectedCentral = row['central'] as Map<String, dynamic>;
    final c = dart.central;
    final actualCentral = <String, double?>{
      'tmax_min': c.tmaxMin,
      'cmax_mg_per_l': c.cmaxMgPerL,
      'brain_entry_index_min_0_4h': c.brainEntryIndexMin,
      'brain_delivery_area': c.brainDeliveryArea,
      'plasma_area': c.plasmaArea,
      'peak_energy_out_kcal_per_min': c.peakEnergyOutKcalPerMin,
      'plasma_area_vs_no_meal': c.plasmaRelative,
      'brain_delivery_area_vs_no_meal': c.brainDeliveryRelative,
    };
    for (final entry in expectedCentral.entries) {
      final actual = actualCentral[entry.key];
      if (actual == null) {
        failures.add('$label.central.${entry.key}: missing in Dart');
      } else {
        check(
          'timing_rows',
          '$label.central.${entry.key}',
          entry.value,
          actual,
        );
      }
    }
    final bands = row['bands_p05_p50_p95'] as Map<String, dynamic>;
    if (bands.length != dart.bands.length) {
      failures.add('$label.bands: ${dart.bands.keys}, expected ${bands.keys}');
    }
    for (final entry in bands.entries) {
      final band = dart.bands[entry.key];
      if (band == null) {
        failures.add('$label.bands.${entry.key}: missing in Dart');
        continue;
      }
      final values = band.toList();
      for (var i = 0; i < 3; i++) {
        check(
          'population_bands',
          '$label.bands.${entry.key}[$i]',
          (entry.value as List)[i],
          values[i],
        );
      }
    }
  }
  // The rows must describe the Observatory's synthetic meal.
  final lunch =
      (fixture['curves'] as List).firstWhere(
            (curve) => curve['id'] == 'lunch_before_dose_60',
          )['scenario']['meals'][0]['components']
          as List;
  if (!_sameMeal(lunch, physiologyObservatoryMeal)) {
    failures.add('timing_rows: fixture meal differs from the Observatory meal');
  }

  for (final raw in fixture['meal_timing_effects'] as List) {
    final effect = raw as Map<String, dynamic>;
    final id = effect['id'] as String;
    final meal = [
      for (final component in effect['meal'] as List)
        physiologyComponentFromSpec(component as Map<String, dynamic>),
    ];
    final dart = provider.mealTimingEffect(
      meal,
      (effect['meal_offset_min'] as num).toDouble(),
    );
    if (dart == null) {
      failures.add('meal_timing_effects.$id: Dart returned no effect');
      continue;
    }
    check(
      'meal_timing_effects',
      '$id.central',
      effect['central'],
      dart.central,
    );
    final band = effect['band_p05_p50_p95'] as List;
    final values = dart.band.toList();
    for (var i = 0; i < 3; i++) {
      check('meal_timing_effects', '$id.band[$i]', band[i], values[i]);
    }
  }

  return PhysiologyAgreementReport(
    relativeTolerance: relative,
    absoluteTolerance: absolute,
    maxRelativeDifferenceBySection: Map.unmodifiable(worst),
    comparedValuesBySection: Map.unmodifiable(counts),
    failures: List.unmodifiable(failures),
  );
}

bool _sameMeal(List spec, List<PhysiologyComponent> meal) {
  if (spec.length != meal.length) return false;
  for (var i = 0; i < meal.length; i++) {
    final s = physiologyComponentFromSpec(spec[i] as Map<String, dynamic>);
    final m = meal[i];
    if (s.name != m.name ||
        s.form != m.form ||
        s.kcal != m.kcal ||
        s.proteinG != m.proteinG ||
        s.waterMl != m.waterMl ||
        (s.aminoAcidsG == null) != (m.aminoAcidsG == null)) {
      return false;
    }
  }
  return true;
}
