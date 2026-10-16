import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';

const _general = 'energy_atwater_general_kcal';
const _specific = 'energy_atwater_specific_kcal';
const _importer = FdcP0Importer(
  fetchClient: FakeSourceFetchClient(textByUrl: {}),
);

Map<String, dynamic> _officialFood() =>
    jsonDecode(
          File(
            'test/fixtures/importers/usda_fdc_foundation_1750339_2026_04.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _row(
  int id,
  String number,
  Object amount, {
  String unit = 'kcal',
}) => {
  'id': id == 2047 ? 21115518 : 21115519,
  'amount': amount,
  'nutrient': <String, dynamic>{
    'id': id,
    'number': number,
    'name': 'source label',
    'unitName': unit,
  },
  'foodNutrientDerivation': {'code': 'NC', 'description': 'Calculated'},
};

P0ImportBundle _import(List<Map<String, dynamic>> rows) =>
    _importer.importFoods([
      {
        'fdcId': 123,
        'description': 'Synthetic method identity fixture',
        'dataType': 'Foundation',
        'foodNutrients': rows,
      },
    ], sourceLabel: 'synthetic_method_identity');

Map<String, dynamic> _payload(P0ImportBundle bundle) =>
    jsonDecode(bundle.sourceDocuments.single.rawPayload)
        as Map<String, dynamic>;

List<ObservationRecord> _energy(P0ImportBundle bundle) => bundle.observations
    .where((row) => [_general, _specific].contains(row.attributeCode))
    .toList();

void main() {
  test(
    'official-style JSON null slots are retained as metadata; malformed nonnull slots are rejected',
    () {
      List<int> zip(Object value) {
        final bytes = utf8.encode(jsonEncode(value));
        return ZipEncoder().encode(
          Archive()
            ..addFile(ArchiveFile('foundation.json', bytes.length, bytes)),
        );
      }

      final bytes = zip({
        'FoundationFoods': [null, _officialFood(), null],
      });
      final bundle = _importer.importZipBytes(
        bytes,
        sourceLabel: 'synthetic_null_slots',
      );
      expect(bundle.foodVariants, hasLength(1));
      final metadata = _payload(bundle)['source_archive_metadata'] as Map;
      expect(metadata['raw_food_array_slot_count'], 3);
      expect(metadata['food_object_count'], 1);
      expect(metadata['null_food_slot_indexes'], [0, 2]);
      expect(metadata['archive_sha256'], sha256.convert(bytes).toString());
      final relocated = _importer.importZipBytes(
        zip({
          'FoundationFoods': [_officialFood(), null, null],
        }),
        sourceLabel: 'synthetic_null_slots',
      );
      expect(
        relocated.sourceDocuments.single.sourceDocId,
        isNot(bundle.sourceDocuments.single.sourceDocId),
      );
      for (final input in [
        {
          'FoundationFoods': ['invalid nonnull object'],
        },
        {
          'FoundationFoods': {'incorrect': 'shape'},
        },
        'incorrect top-level shape',
      ]) {
        expect(
          () => _importer.importZipBytes(
            zip(input),
            sourceLabel: 'synthetic_bad_shape',
          ),
          throwsFormatException,
        );
      }
    },
  );
  test('a method with an absent or blank source unit stays unqualified', () {
    for (final unit in [null, '', '  ']) {
      final row = _row(2047, '957', 61.8);
      (row['nutrient'] as Map)['unitName'] = unit;
      final bundle = _import([row]);
      expect(bundle.observations, isEmpty);
      expect(bundle.resolvedFacts, isEmpty);
      expect(bundle.projectedFoods.single.energyKcal, isNull);
    }
  });
  test(
    'complete official object and independent expectation hashes remain exact',
    () {
      expect(
        sha256
            .convert(
              File(
                'test/fixtures/importers/usda_fdc_foundation_1750339_2026_04.json',
              ).readAsBytesSync(),
            )
            .toString(),
        '2dba6f7daf12a45102a7685cfd20f6e249d222c75ae4649a4b9b414f1c194c96',
      );
      expect(
        sha256
            .convert(
              File(
                'test/fixtures/importers/fdc_energy_method_expectations.json',
              ).readAsBytesSync(),
            )
            .toString(),
        '2f1bcc3264bd2d34ec9a71be0438b5253c16dd79beaf1d2aa7168cbae4ddc3f7',
      );
      final expected =
          jsonDecode(
                File(
                  'test/fixtures/importers/fdc_energy_method_expectations.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(
        expected['official_source_expectations_sha256'],
        '93d9dd32663208eb2ec848e38794772d62218a2e21ca3bebf8d403cc041c847d',
      );
      expect(expected['method_fields'], [
        {
          'nutrient_id': 2047,
          'nutrient_number': '957',
          'source_amount': 61.8,
          'method': 'atwater_general_factors',
          'unit': 'kcal',
        },
        {
          'nutrient_id': 2048,
          'nutrient_number': '958',
          'source_amount': 55.6,
          'method': 'atwater_specific_factors',
          'unit': 'kcal',
        },
      ]);
    },
  );

  test(
    'complete food retains both source methods and selects Claude specific-energy fallback',
    () {
      final bundle = _importer.importFoods([
        _officialFood(),
      ], sourceLabel: 'official_complete_food');
      final energy = _energy(bundle);
      expect(energy.map((o) => o.attributeCode), [_general, _specific]);
      expect(energy.map((o) => o.value.valueNum), [61.8, 55.6]);
      expect(energy.map((o) => o.value.rawValueText), ['61.8', '55.6']);
      for (final o in energy) {
        expect(o.methodCode, 'NC');
        expect(o.unit, 'kcal');
        expect(o.basisType, 'per_100g_edible_part');
        expect(o.basisAmount, 100);
        expect(o.sourceDocId, bundle.sourceDocuments.single.sourceDocId);
        expect(o.recordLocator, contains(':summary:food_nutrient:'));
      }
      expect(energy.map((o) => o.recordLocator).toSet(), hasLength(2));
      final food = bundle.projectedFoods.single;
      expect(food.energyKcal, 55.6);
      expect(food.isNutrientMissing('energyKcal'), isFalse);
      expect(foodItemToCandidateFood(food).components.single.calories, 55.6);
      expect(
        (_payload(bundle)['nutrient_value_audit'] as List).where(
          (row) =>
              row['reason'] == 'duplicate_nutrient_attribute' &&
              '$row'.contains('energy'),
        ),
        isEmpty,
      );
      final summaries = (_payload(bundle)['source_nutrient_summaries'] as List)
          .where((row) => [2047, 2048].contains(row['nutrient_id']))
          .toList();
      expect(summaries.map((r) => r['energy_method']), [
        'atwater_general_factors',
        'atwater_specific_factors',
      ]);
      expect(summaries.map((r) => r['nutrient_number']), ['957', '958']);
      expect(
        (summaries.first['derivation_fields']
            as Map)['foodNutrientSource']['code'],
        '4',
      );
      expect(
        (_payload(bundle)['nutrient_statistics_audit'] as List)
            .where((r) => r['attribute_code'] == _general)
            .single['nutrient_source_code'],
        '4',
      );
    },
  );

  test(
    'equal amounts from different methods remain separately attributable',
    () {
      final bundle = _import([_row(2047, '957', 50), _row(2048, '958', 50)]);
      expect(_energy(bundle).map((r) => r.attributeCode), [
        _general,
        _specific,
      ]);
      expect(bundle.resolvedFacts.map((r) => r.attributeCode), [
        _general,
        _specific,
        'energy_kcal',
      ]);
      expect(bundle.projectedFoods.single.energyKcal, 50);
      expect(
        bundle.observations
            .singleWhere((o) => o.attributeCode == 'energy_kcal')
            .methodCode,
        FdcP0Importer.derivedEnergyFromSpecificMethodCode,
      );
    },
  );

  test(
    'Claude extract-number policy resolves independently numbered rows without bypassing units',
    () {
      for (final item in [
        (_row(2047, '958', 61.8), _specific, 61.8),
        (_row(2048, '957', 55.6), _general, 55.6),
        (_row(9999, '957', 61.8), _general, 61.8),
      ]) {
        (item.$1['nutrient'] as Map)['name'] =
            'Energy (Atwater General Factors)';
        final bundle = _import([item.$1]);
        expect(_energy(bundle).single.attributeCode, item.$2);
        expect(bundle.projectedFoods.single.energyKcal, item.$3);
        expect(
          (_payload(bundle)['source_nutrient_summaries'] as List)
              .single['nutrient_id'],
          (item.$1['nutrient'] as Map)['id'],
        );
      }
      // Number 203 identifies protein, so an energy unit cannot qualify it.
      final incompatible = _import([_row(2047, '203', 61.8)]);
      expect(incompatible.observations, isEmpty);
      expect(incompatible.projectedFoods.single.energyKcal, isNull);
    },
  );

  test(
    'ID-only, number-only and exact names use Claude definitions with explicit units',
    () {
      for (final method in [
        (2047, '957', _general),
        (2048, '958', _specific),
      ]) {
        for (final omitted in ['id', 'number']) {
          final row = _row(method.$1, method.$2, 20);
          (row['nutrient'] as Map).remove(omitted);
          final bundle = _import([row]);
          expect(_energy(bundle).single.attributeCode, method.$3);
          expect(bundle.projectedFoods.single.energyKcal, 20);
        }
      }
      final row = _row(2047, '957', 20);
      row['nutrient'] = {
        'name': 'Energy (Atwater General Factors)',
        'unitName': 'kcal',
      };
      expect(_energy(_import([row])).single.attributeCode, _general);
    },
  );

  test(
    'wrong units and invalid values do not create a method point or generic fallback',
    () {
      for (final row in [
        _row(2047, '957', 61.8, unit: 'kJ'),
        _row(2048, '958', -1),
        _row(2047, '957', 'NaN'),
        _row(2048, '958', double.infinity),
      ]) {
        // JSON source values cannot carry infinities; use a lexical token instead.
        if (row['amount'] is double && !(row['amount'] as double).isFinite) {
          row['amount'] = 'Infinity';
        }
        final bundle = _import([row]);
        expect(bundle.observations, isEmpty);
        expect(bundle.resolvedFacts, isEmpty);
        expect(bundle.projectedFoods.single.energyKcal, isNull);
        expect(
          (_payload(bundle)['nutrient_value_audit'] as List).single['decision'],
          'withheld',
        );
      }
    },
  );

  test(
    'quantification and ambiguous peers retain existing withholding rules within each method',
    () {
      final a = _row(2047, '957', 50);
      final b = _row(2047, '957', 70)..['id'] = 999;
      final bundle = _import([a, b, _row(2048, '958', 55.6)]);
      expect(_energy(bundle).map((o) => o.value.valueNum), [50, 70, 55.6]);
      expect(bundle.resolvedFacts.map((o) => o.attributeCode), [
        _specific,
        'energy_kcal',
      ]);
      expect(bundle.projectedFoods.single.energyKcal, 55.6);
      final held = _import([_row(2047, '957', 0)..['loq'] = 0.03]);
      expect(held.observations.single.value.valueNum, isNull);
      expect(held.observations.single.value.high, 0.03);
      expect(held.projectedFoods.single.energyKcal, isNull);
    },
  );

  test(
    'factor fields remain exact while Claude identity audits consume qualified factors',
    () {
      final original = _officialFood();
      final before = _importer.importFoods([
        original,
      ], sourceLabel: 'factor_source');
      final payload = _payload(before);
      final factors =
          (payload['food_conversion_factor_evidence'] as List).single;
      expect(factors['source_fields'], original['nutrientConversionFactors']);
      expect(factors['source_field_present'], isTrue);
      expect(factors['source_values_modified'], isFalse);
      expect(factors['calculation_scope'], 'composition_identity_audit_only');
      expect(
        (payload['food_publication_metadata'] as List)
            .single['publication_date'],
        '10/30/2020',
      );
      expect(before.sourceDocuments.single.publishedAt, isNull);
      expect(before.sourceDocuments.single.effectiveAt, isNull);
      final changed = _officialFood();
      changed['nutrientConversionFactors'] = [
        {'type': '.UnreviewedFactor', 'value': 9999},
      ];
      final after = _importer.importFoods([
        changed,
      ], sourceLabel: 'factor_source');
      expect(_energy(after).map((o) => o.value.valueNum), [61.8, 55.6]);
      expect(
        after.projectedFoods.single.proteinG,
        before.projectedFoods.single.proteinG,
      );
      expect(
        after.sourceDocuments.single.sourceDocId,
        isNot(before.sourceDocuments.single.sourceDocId),
      );
      expect(
        (_payload(after)['food_conversion_factor_evidence'] as List)
            .single['source_fields'],
        changed['nutrientConversionFactors'],
      );
    },
  );

  test(
    'absent, null and empty factors remain distinct, without date guesses',
    () {
      for (final state in ['absent', 'null', 'empty']) {
        final food = _officialFood()
          ..['publicationDate'] = 'unknown source date';
        if (state == 'absent') food.remove('nutrientConversionFactors');
        if (state == 'null') food['nutrientConversionFactors'] = null;
        if (state == 'empty') food['nutrientConversionFactors'] = [];
        final bundle = _importer.importFoods([food], sourceLabel: state);
        final payload = _payload(bundle);
        expect(
          (payload['food_conversion_factor_evidence'] as List)
              .single['source_field_present'],
          state != 'absent',
        );
        expect(
          (payload['food_conversion_factor_evidence'] as List)
              .single['source_fields'],
          state == 'empty' ? [] : null,
        );
        expect(
          (payload['food_publication_metadata'] as List)
              .single['publication_date'],
          'unknown source date',
        );
        expect(
          (payload['food_publication_metadata'] as List)
              .single['timezone_inferred'],
          isFalse,
        );
        expect(bundle.sourceDocuments.single.publishedAt, isNull);
      }
    },
  );

  test(
    'CSV joins IDs, nested derivation source, factors and original publication string',
    () {
      final bundle = _importer.importCsvArchive(
        _csv(),
        sourceLabel: 'synthetic_csv_factors',
      );
      expect(_energy(bundle).map((o) => o.value.valueNum), [61.8, 55.6]);
      expect(_energy(bundle).map((o) => o.attributeCode), [
        _general,
        _specific,
      ]);
      expect(
        _energy(bundle).first.recordLocator,
        endsWith(':food_nutrient:21115518'),
      );
      expect(
        (_payload(bundle)['nutrient_statistics_audit'] as List)
            .first['nutrient_source_code'],
        '4',
      );
      final factors =
          (_payload(bundle)['food_conversion_factor_evidence'] as List)
                  .single['source_fields']
              as List;
      expect(factors.map((f) => f['type']), [
        '.CalorieConversionFactor',
        '.ProteinConversionFactor',
        '.FatConversionFactor',
      ]);
      expect(factors.first['proteinValue'], '3.36');
      expect(factors[1]['value'], '6.25');
      expect(factors[2]['fatNleaValue'], '0.8');
      expect(factors.every((f) => f['join_status'] == 'source_joined'), isTrue);
      expect(factors.first['source_parent_fields'], {
        'id': '7',
        'fdc_id': '123',
      });
      expect(
        (factors.first['source_factor_fields']
            as Map)['food_nutrient_conversion_factor_id'],
        '7',
      );
      expect(
        (_payload(bundle)['food_publication_metadata'] as List)
            .single['publication_date'],
        '10/30/2020',
      );
      expect(bundle.projectedFoods.single.energyKcal, 55.6);
    },
  );

  test(
    'CSV factor owner collision is retained as held raw evidence without inferred values',
    () {
      final csv = _csv();
      csv['bulk/food_nutrient_conversion_factor.csv'] =
          'id,fdc_id\n7,123\n7,999';
      final bundle = _importer.importCsvArchive(
        csv,
        sourceLabel: 'synthetic_ambiguous_factor',
      );
      final factors =
          (_payload(bundle)['food_conversion_factor_evidence'] as List)
                  .single['source_fields']
              as List;
      for (final factor in factors) {
        expect(factor['join_status'], 'hold_ambiguous_food_owner');
        expect(factor.containsKey('proteinValue'), isFalse);
        expect(factor.containsKey('value'), isFalse);
        expect(factor['source_factor_fields'], isNotEmpty);
      }
      expect(_energy(bundle).map((o) => o.value.valueNum), [61.8, 55.6]);
    },
  );

  test(
    'catalogue projection retains original methods and selects the derived generic energy',
    () async {
      final bundle = _importer.importFoods([
        _officialFood(),
      ], sourceLabel: 'official_complete_food');
      final projection = CdssCatalogProjectionService(
        database: _BundleDatabase(bundle),
      );
      final food = (await projection.projectFoods()).single;
      final methods = food.nutrientObservationEvidence
          .where((o) => [_general, _specific].contains(o.attributeCode))
          .toList();
      expect(methods, hasLength(2));
      expect(methods.every((o) => !o.selectedForLegacyPointProjection), isTrue);
      expect(food.energyKcal, 55.6);
      expect(foodItemToCandidateFood(food).components.single.calories, 55.6);
      final roundtrip = FoodItem.fromJson(food.toJson());
      expect(roundtrip.toJson(), food.toJson());
      final lines = (await projection.projectFoodDetail(food))!.nutrientLines
          .where((line) => [_general, _specific].contains(line.attributeCode));
      expect(lines.map((line) => line.displayLabel), [
        'Energy (Atwater General Factors)',
        'Energy (Atwater Specific Factors)',
      ]);
      expect(lines.map((line) => line.rawValueText), ['61.8', '55.6']);
    },
  );

  test(
    'a separately supplied legacy Energy row keeps its existing explicit point',
    () async {
      final legacy = _row(1008, '208', 64.2)..['id'] = 333;
      final bundle = _import([
        _row(2047, '957', 61.8),
        _row(2048, '958', 55.6),
        legacy,
      ]);
      expect(bundle.projectedFoods.single.energyKcal, 64.2);
      final food = (await CdssCatalogProjectionService(
        database: _BundleDatabase(bundle),
      ).projectFoods()).single;
      expect(food.energyKcal, 64.2);
      expect(
        food.nutrientObservationEvidence
            .where((o) => o.selectedForLegacyPointProjection)
            .map((o) => o.attributeCode),
        ['energy_kcal'],
      );
    },
  );

  test(
    'the conflict engine refuses to resolve a mixed-method numeric cluster',
    () {
      final bundle = _import([
        _row(2047, '957', 61.8),
        _row(2048, '958', 55.6),
      ]);
      final resolution = FactConflictEngine().resolveCluster(
        observations: _energy(bundle),
        existingFacts: [],
        sourceDocumentsById: {
          bundle.sourceDocuments.single.sourceDocId:
              bundle.sourceDocuments.single,
        },
      );
      expect(resolution.status, 'incompatible_cluster');
      expect(resolution.chosenObservation, isNull);
      expect(resolution.needsManualReview, isTrue);
    },
  );
}

Map<String, String> _csv() => {
  'bulk/food.csv':
      'fdc_id,description,data_type,publication_date\n123,Synthetic apple,Foundation,10/30/2020',
  'bulk/nutrient.csv':
      'id,number,name,unit_name\n2047,957,General energy,kcal\n2048,958,Specific energy,kcal',
  'bulk/food_nutrient.csv':
      'id,fdc_id,nutrient_id,amount,derivation_id\n21115518,123,2047,61.8,1\n21115519,123,2048,55.6,1',
  'bulk/food_nutrient_derivation.csv':
      'id,code,description,source_id\n1,NC,Calculated,2',
  'bulk/food_nutrient_source.csv':
      'id,code,description\n2,4,Calculated or imputed',
  'bulk/food_nutrient_conversion_factor.csv': 'id,fdc_id\n7,123',
  'bulk/food_calorie_conversion_factor.csv':
      'food_nutrient_conversion_factor_id,protein_value,fat_value,carbohydrate_value\n7,3.36,8.37,3.6',
  'bulk/food_protein_conversion_factor.csv':
      'food_nutrient_conversion_factor_id,value\n7,6.25',
  'bulk/food_fat_conversion_factor.csv':
      'food_nutrient_conversion_factor_id,fat_nlea_value\n7,0.8',
};

/// Projection-table fixture only. It does not simulate native/Web atomic writes.
class _BundleDatabase extends InMemoryCdssDatabase {
  _BundleDatabase(this.bundle);
  final P0ImportBundle bundle;
  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      switch (table) {
        'food_variant' => [
          for (final v in bundle.foodVariants)
            {
              'food_variant_id': v.foodVariantId,
              'food_concept_id': v.foodConceptId,
              'source_family': v.sourceFamily,
              'source_food_code': v.sourceFoodCode,
              'display_name_local': v.displayNameLocal,
              'jurisdiction': v.jurisdiction,
            },
        ],
        'food_concept' => [
          for (final c in bundle.foodConcepts)
            {
              'food_concept_id': c.foodConceptId,
              'canonical_name_en': c.canonicalNameEn,
              'canonical_name_zh': c.canonicalNameZh,
              'food_group': c.foodGroup,
            },
        ],
        'observation' => [
          for (final o in bundle.observations)
            {
              'observation_id': o.observationId,
              'domain': o.domain,
              'entity_type': o.entityType,
              'entity_key': o.entityKey,
              'attribute_code': o.attributeCode,
              'value_type': o.valueType,
              'value_num': o.value.valueNum,
              'low': o.value.low,
              'high': o.value.high,
              'qualifier_kind': o.value.qualifierKind.name,
              'raw_value_text': o.value.rawValueText,
              'unit': o.unit,
              'basis_type': o.basisType,
              'basis_amount': o.basisAmount,
              'scope_hash': o.scopeHash,
              'source_doc_id': o.sourceDocId,
              'record_locator': o.recordLocator,
              'method_code': o.methodCode,
            },
        ],
        'source_document' => [
          for (final s in bundle.sourceDocuments)
            {
              'source_doc_id': s.sourceDocId,
              'title': s.title,
              'source_family': s.sourceFamily,
              'raw_payload': s.rawPayload,
            },
        ],
        _ => [],
      };
}
