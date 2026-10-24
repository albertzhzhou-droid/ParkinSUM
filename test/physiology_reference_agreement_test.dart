import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/physiology_reference_agreement.dart';

void main() {
  test(
    'Dart port reproduces the Python reference within the stated tolerance',
    () {
      final fixture =
          jsonDecode(File(physiologyAgreementFixturePath).readAsStringSync())
              as Map<String, dynamic>;
      final report = comparePhysiologyAgreement(fixture);

      expect(report.failures, isEmpty);
      expect(report.relativeTolerance, 1e-9);
      expect(report.absoluteTolerance, 1e-12);
      // Every section the brief requires was compared, not skipped.
      expect(report.comparedValuesBySection.keys, {
        'curves',
        'derived',
        'timing_rows',
        'population_bands',
        'meal_timing_effects',
        'nutrition_outputs',
      });
      final curveIds = {
        for (final curve in fixture['curves'] as List) curve['id'] as String,
      };
      expect(
        curveIds,
        containsAll([
          'fasting_dose',
          'meal_with_dose',
          'lunch_before_dose_60',
          'lunch_after_dose_60',
          'tougas_meal',
          'carter_high',
          'carter_even',
          'carter_evening',
          'nutt_infusion_phe',
          'nutt_infusion_leu',
          'nutt_infusion_gly',
        ]),
      );
    },
  );

  test('a perturbed fixture fails the comparison', () {
    final fixture =
        jsonDecode(File(physiologyAgreementFixturePath).readAsStringSync())
            as Map<String, dynamic>;
    final derived = fixture['derived'] as Map<String, dynamic>;
    derived['nutt.meal_delay_min'] =
        (derived['nutt.meal_delay_min'] as num) + 1e-6;
    final report = comparePhysiologyAgreement(fixture);
    expect(report.pass, isFalse);
    expect(report.failures.single, startsWith('derived.nutt.meal_delay_min'));
  });
}
