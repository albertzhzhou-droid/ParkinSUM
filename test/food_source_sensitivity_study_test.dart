import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import '../tool/food_source_sensitivity_study.dart';

void main() {
  const root = 'test/fixtures/food_research';
  Map<String, dynamic> read(String name) =>
      jsonDecode(File('$root/$name').readAsStringSync())
          as Map<String, dynamic>;
  Map<String, dynamic> domain() => read('joint_source_domain.json');
  Map<String, dynamic> source() => read('six_original_foundation_foods.json');
  final expectations = read('joint_independent_expectations.json');
  test(
    'all original five nutrient identities and same-food portions agree with frozen independent arithmetic',
    () {
      final actual = jointSourceStudy(domain(), source());
      expect(actual['legal_joint_combinations'], 64);
      final options = {
        for (final g in expectations['groups'] as List)
          for (final o in g['options'] as List) o['option_id']: o,
      };
      final scenarios = actual['scenarios'] as List;
      expect(scenarios, hasLength(128));
      for (final scenario in scenarios) {
        for (final c in scenario['choices'] as List) {
          final expected = options[c['option_id']] as Map;
          expect(c['fdc_id'], expected['fdc_id']);
          expect(c['portion_id'], expected['portion_id']);
          for (final e in (expected['expected_per_portion'] as Map).entries) {
            expect(
              c['per_portion'][e.key],
              closeTo(double.parse(e.value as String), 1e-9),
            );
          }
        }
        expect(
          (scenario['results'] as List).every(
            (r) => r['availability'] == 'available',
          ),
          isTrue,
        );
      }
    },
  );
  test(
    'reversing groups and options keeps complete canonical output for the same source document',
    () {
      final d = domain();
      final original = jointSourceStudy(d, source());
      d['groups'] = (d['groups'] as List).reversed.toList();
      for (final g in d['groups'] as List) {
        g['options'] = (g['options'] as List).reversed.toList();
      }
      expect(jointSourceStudy(d, source()), original);
    },
  );
  test(
    'food order changes source identity while preserving computed results',
    () {
      final original = jointSourceStudy(domain(), source());
      final src = source();
      src['FoundationFoods'] = (src['FoundationFoods'] as List).reversed
          .toList();
      final reordered = jointSourceStudy(domain(), src);
      final a = original['scenarios'] as List,
          b = reordered['scenarios'] as List;
      for (var i = 0; i < a.length; i++) {
        expect(b[i]['scenario_id'], a[i]['scenario_id']);
        expect(b[i]['results'], a[i]['results']);
        for (var j = 0; j < (a[i]['choices'] as List).length; j++) {
          final x = a[i]['choices'][j] as Map, y = b[i]['choices'][j] as Map;
          expect(y['source_doc_id'], isNot(x['source_doc_id']));
          expect(
            Map.from(y)..remove('source_doc_id'),
            Map.from(x)..remove('source_doc_id'),
          );
        }
      }
    },
  );
  for (final mutation in [
    'foreign-portion',
    'duplicate-group',
    'duplicate-option',
    'unreviewed-matching',
    'overflow',
    'fractional-index',
    'invalid-window',
    'foreign-base',
  ]) {
    test('whole joint study rejects $mutation', () {
      final d = domain();
      final groups = d['groups'] as List;
      switch (mutation) {
        case 'foreign-portion':
          groups[0]['options'][0]['portion_id'] = 312717;
        case 'duplicate-group':
          groups[1]['candidate_id'] = groups[0]['candidate_id'];
        case 'duplicate-option':
          groups[0]['options'][1]['option_id'] =
              groups[0]['options'][0]['option_id'];
        case 'unreviewed-matching':
          groups[0]['matching_status'] = 'automatic_match';
        case 'overflow':
          d['maximum_joint_combinations'] = 32;
        case 'fractional-index':
          groups[0]['options'][0]['original_food_portion_index'] = .5;
        case 'invalid-window':
          d['windows'][0]['end_minute'] = 0;
        case 'foreign-base':
          d['synthetic_base_meal']['portion_id'] = 312717;
      }
      expect(
        () => jointSourceStudy(d, source()),
        throwsA(anyOf(isA<StateError>(), isA<TypeError>())),
      );
    });
  }
  test(
    'distinct original source methods survive separately and never fill one another',
    () {
      final bundle =
          const FdcP0Importer(
            fetchClient: FakeSourceFetchClient(textByUrl: {}),
          ).importFoods(
            (source()['FoundationFoods'] as List).cast<Map<String, dynamic>>(),
            sourceLabel: 'source-method-check',
          );
      final facts = bundle.observations.where(
        (o) => o.recordLocator.contains('sample_range') != true,
      );
      expect(
        facts.where((o) => o.attributeCode == 'carbohydrate_by_summation_g'),
        hasLength(3),
      );
      expect(
        facts.where((o) => o.attributeCode == 'fiber_aoac_2011_25_g'),
        hasLength(4),
      );
      expect(
        bundle.projectedFoods.every(
          (f) =>
              !f.isNutrientMissing('carbsG') && !f.isNutrientMissing('fiberG'),
        ),
        isTrue,
      );
    },
  );
  test(
    'foreign method IDs or descriptive fiber names cannot become generic point nutrition',
    () {
      final importer = const FdcP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      for (final nutrient in [
        {
          'id': 2033,
          'number': '291',
          'name': 'Fiber, total dietary',
          'unitName': 'g',
        },
        {
          'id': 1050,
          'number': '205',
          'name': 'Carbohydrate, by difference',
          'unitName': 'g',
        },
        {'id': 999999, 'name': 'Fiber invented subset', 'unitName': 'g'},
        {
          'id': 2033,
          'number': '293',
          'name': 'Total dietary fiber (AOAC 2011.25)',
          'unitName': 'g',
        },
        {
          'id': 1050,
          'number': '205.2',
          'name': 'Carbohydrate, by summation',
          'unitName': 'g',
        },
      ]) {
        final bundle = importer.importFoods([
          {
            'fdcId': 123,
            'description': 'Synthetic method rejection',
            'dataType': 'Foundation',
            'foodNutrients': [
              {'nutrient': nutrient, 'amount': 4},
            ],
          },
        ], sourceLabel: 'method-hold');
        expect(
          bundle.projectedFoods.single.isNutrientMissing('proteinG'),
          isTrue,
        );
        expect(
          bundle.projectedFoods.single.isNutrientMissing('carbsG'),
          isTrue,
        );
        expect(
          bundle.projectedFoods.single.isNutrientMissing('fiberG'),
          isTrue,
        );
      }
    },
  );
  test(
    'heuristic finite grid preserves defaults and rejects duplicate identity and overflow',
    () {
      final d = read('heuristic_domain.json');
      final report = fixedHeuristicStudy(d);
      expect(report['cases'], hasLength(81));
      expect(
        report['default_parameters_before'],
        report['default_parameters_after'],
      );
      d['cases'][1]['id'] = d['cases'][0]['id'];
      expect(() => fixedHeuristicStudy(d), throwsStateError);
      final overflow = read('heuristic_domain.json');
      overflow['cases'] = [for (var i = 0; i < 129; i++) overflow['cases'][0]];
      expect(() => fixedHeuristicStudy(overflow), throwsStateError);
    },
  );
}
