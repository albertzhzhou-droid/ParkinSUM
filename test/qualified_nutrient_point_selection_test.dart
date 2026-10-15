import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/usecases/qualified_nutrient_point_selection.dart';

Map<String, Object?> row({
  Object? value = 20,
  String qualifier = 'exact',
  String source = 'synthetic_source',
  String entity = 'synthetic_food',
  String attribute = 'protein_g',
}) => {
  'entity_key': entity,
  'attribute_code': attribute,
  'qualifier_kind': qualifier,
  'value_num': value,
  'source_doc_id': source,
  'unit': 'g',
  'basis_type': 'per_100g_edible_part',
  'basis_amount': 100,
};

void main() {
  test(
    'competing primary qualifiers withhold while explicit same-source sample statistics preserve one exact point',
    () {
      for (final qualifier in ['lt', 'gt', 'missing', 'range']) {
        final selected = selectQualifiedNutrientPoints([
          row(),
          row(qualifier: qualifier),
        ]);
        expect(selected.points, isEmpty, reason: qualifier);
        expect(selected.hasEvidence('synthetic_food', 'protein_g'), isTrue);
      }
      final sampleRange = {
        ...row(value: null, qualifier: 'range'),
        'record_locator': 'synthetic_food:protein_g:sample_range',
        'raw_value_text': 'source_min=15; source_max=25; data_points=6',
        'low': 15,
        'high': 25,
      };
      for (final rows in [
        [row(), sampleRange],
        [sampleRange, row()],
      ]) {
        expect(
          selectQualifiedNutrientPoints(
            rows,
          ).points['synthetic_food']!['protein_g']!.value,
          20,
        );
      }
      expect(
        selectQualifiedNutrientPoints([row(value: 30), sampleRange]).points,
        isEmpty,
      );
      expect(
        selectQualifiedNutrientPoints([
          row(),
          {...sampleRange, 'raw_value_text': '15-25'},
        ]).points,
        isEmpty,
      );
    },
  );
  test(
    'explicit wrong units or basis withhold points without invalidating legacy omitted metadata',
    () {
      for (final wrong in [
        {'unit': 'mg'},
        {'basis_type': 'per_serving'},
        {'basis_amount': 30},
        {'basis_amount': double.infinity},
      ]) {
        final selected = selectQualifiedNutrientPoints([
          {...row(), ...wrong},
        ]);
        expect(selected.points, isEmpty);
        expect(selected.hasEvidence('synthetic_food', 'protein_g'), isTrue);
      }
      final legacy = row(value: 0)
        ..remove('unit')
        ..remove('basis_type')
        ..remove('basis_amount');
      expect(
        selectQualifiedNutrientPoints([
          legacy,
        ]).points['synthetic_food']!['protein_g']!.value,
        0,
      );
    },
  );
  test(
    'one exact zero remains usable and records its original evidence index',
    () {
      final selected = selectQualifiedNutrientPoints([
        row(entity: 'other'),
        row(value: 0),
      ]);
      expect(selected.points['synthetic_food']!['protein_g']!.value, 0);
      expect(selected.points['synthetic_food']!['protein_g']!.rowIndex, 1);
    },
  );
  test(
    'duplicates and ambiguous source revisions withhold arithmetic in either order',
    () {
      for (final pair in [
        [row(value: 20), row(value: 40)],
        [row(value: 20), row(value: 40, source: 'old_source')],
        [row(), row(value: 1, qualifier: 'lt', source: 'old_source')],
      ]) {
        for (final rows in [pair, pair.reversed.toList()]) {
          final selected = selectQualifiedNutrientPoints(rows);
          expect(selected.points['synthetic_food']?['protein_g'], isNull);
          expect(selected.hasEvidence('synthetic_food', 'protein_g'), isTrue);
        }
      }
    },
  );
  test(
    'censored missing invalid and non-finite observations remain evidence without a point',
    () {
      for (final value in [
        row(qualifier: 'lt'),
        row(qualifier: 'missing', value: null),
        row(value: -1),
        row(value: double.nan),
        row(value: double.infinity),
      ]) {
        final selected = selectQualifiedNutrientPoints([value]);
        expect(selected.points, isEmpty);
        expect(selected.hasEvidence('synthetic_food', 'protein_g'), isTrue);
      }
      expect(
        selectQualifiedNutrientPoints([
          row(entity: ''),
          row(attribute: ''),
        ]).points,
        isEmpty,
      );
    },
  );
}
