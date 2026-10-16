import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/qualified_nutrient_point_selection.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

import 'clinical_decision_support_service_test.dart' show RecordingCdssDatabase;

// Capture actual database write arguments. This proves the service/projection
// contract only; it does not stand in for durable SQLite or device storage.
class _ProjectionDatabase extends RecordingCdssDatabase {
  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {
    tables['food_variant']!.add({
      'food_variant_id': record.foodVariantId,
      'food_concept_id': record.foodConceptId,
      'source_food_code': record.sourceFoodCode,
      'source_family': record.sourceFamily,
      'jurisdiction': record.jurisdiction,
      'display_name_local': record.displayNameLocal,
    });
  }

  @override
  Future<void> insertObservation(ObservationRecord record) async {
    tables['observation']!.add({
      'observation_id': record.observationId,
      'domain': record.domain,
      'entity_type': record.entityType,
      'entity_key': record.entityKey,
      'attribute_code': record.attributeCode,
      'value_type': record.valueType,
      ...record.value.toJson(),
      'unit': record.unit,
      'basis_type': record.basisType,
      'basis_amount': record.basisAmount,
      'scope_hash': record.scopeHash,
      'source_doc_id': record.sourceDocId,
      'record_locator': record.recordLocator,
      'method_code': record.methodCode,
      'extraction_confidence': record.extractionConfidence,
    });
  }
}

// Historical source vectors stay unchanged. These explicit migration expectations
// use the Claude current-release quantity contract, not the old local aliases.
const _currentAttributes = {
  'carbohydrate_by_summation_g': 'carbohydrate_g',
  'vitamin_e_alpha_tocopherol_mg': 'vitamin_e_mg',
  'vitamin_d_total_ug': 'vitamin_d_ug',
  'vitamin_k_phylloquinone_ug': 'vitamin_k1_ug',
  'choline_total_mg': 'choline_mg',
  'sugars_total_1063_g': 'sugars_total_by_summation_g',
  'sugars_total_2000_g': 'sugars_total_g',
};
const _sourceOnlyAttributes = {
  'vitamin_d2_ug',
  'vitamin_d3_ug',
  'vitamin_d_total_iu',
  'vitamin_k_menaquinone4_ug',
  'vitamin_k_dihydrophylloquinone_ug',
  'sucrose_g',
  'glucose_g',
  'fructose_g',
  'lactose_g',
  'maltose_g',
  'galactose_g',
  'fiber_soluble_g',
  'fiber_insoluble_g',
  'ala_n3_g',
  'epa_n3_g',
  'dha_n3_g',
};
String _currentAttribute(Map vector) =>
    _currentAttributes[vector['expected_attribute']] ??
    '${vector['expected_attribute']}';

// Claude canonicalizes source kilojoule spelling to kJ; raw unit spelling is
// still asserted separately against the untouched historical source vector.
String _currentUnit(Map vector) =>
    vector['expected_unit'] == 'kj' ? 'kJ' : '${vector['expected_unit']}';

void main() {
  const importer = FdcP0Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/importers/fdc_extended_quantity_source_vectors_2026_04.json',
            ).readAsStringSync(),
          )
          as Map;
  final vectors = fixture['vectors'] as List;
  test(
    'current-release quantities survive writes while unsupported source fields remain attributable',
    () async {
      final foods = <String, Map<String, dynamic>>{};
      for (final vector in vectors) {
        final food = foods.putIfAbsent(
          '${vector['fdc_id']}',
          () => {
            'fdcId': vector['fdc_id'],
            'description': vector['description'],
            'dataType': 'Foundation',
            'foodNutrients': <Object?>[],
          },
        );
        (food['foodNutrients'] as List).add(vector['source_row']);
      }
      final bundle = importer.importFoods(
        foods.values.toList(),
        sourceLabel: 'cropped_official_quantity_fields_persistence',
      );
      final database = _ProjectionDatabase();
      await ClinicalDecisionSupportService(
        database: database,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      ).importBundle(bundle);
      final projected = await CdssCatalogProjectionService(
        database: database,
      ).projectFoods();
      expect(projected, hasLength(foods.length));
      for (final vector in vectors) {
        if (_sourceOnlyAttributes.contains(vector['expected_attribute'])) {
          expect(
            database.tables['observation']!.where(
              (row) => row['attribute_code'] == vector['expected_attribute'],
            ),
            isEmpty,
          );
          continue;
        }
        final food = projected.singleWhere(
          (food) => food.sourceFoodCode == '${vector['fdc_id']}',
        );
        final evidence = food.nutrientObservationEvidence.singleWhere(
          (row) =>
              row.attributeCode == _currentAttribute(vector) &&
              !(row.recordLocator?.endsWith(':sample_range') ?? false),
        );
        expect(evidence.unit, _currentUnit(vector));
        expect(evidence.qualifierKind, vector['expected_qualifier']);
        expect(evidence.valueNum, vector['expected_point']);
        expect(evidence.sourceDocId, bundle.sourceDocuments.single.sourceDocId);
        expect(
          evidence.selectedForLegacyPointProjection,
          _currentAttribute(vector) == 'carbohydrate_g',
          reason:
              'Only the Claude available-carbohydrate quantity has a legacy field here',
        );
      }
    },
  );
  for (final raw in vectors) {
    final vector = Map<String, dynamic>.from(raw as Map);
    test(
      'official ${vector['expected_attribute']} retains quantity, unit and method',
      () {
        final bundle = importer.importFoods([
          {
            'fdcId': vector['fdc_id'],
            'description': vector['description'],
            'dataType': 'Foundation',
            'foodNutrients': [vector['source_row']],
          },
        ], sourceLabel: 'cropped_official_quantity_fields');
        final summaries = bundle.observations
            .where((o) => !o.recordLocator.endsWith(':sample_range'))
            .toList();
        final supported = !_sourceOnlyAttributes.contains(
          vector['expected_attribute'],
        );
        if (!supported) {
          expect(summaries, isEmpty);
          final source =
              jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
          final summary =
              (source['source_nutrient_summaries'] as List).single as Map;
          expect(summary['source_fields'], vector['source_row']);
          expect(
            summary['reported_amount'],
            (vector['source_row'] as Map)['amount'],
          );
          expect(
            summary['nutrient_id'],
            ((vector['source_row'] as Map)['nutrient'] as Map)['id'],
          );
          expect(
            (source['nutrient_value_audit'] as List).single['decision'],
            'retained_source_fields_only',
          );
          return;
        }
        final observation = summaries.singleWhere(
          (o) => o.attributeCode == _currentAttribute(vector),
        );
        expect(observation.attributeCode, _currentAttribute(vector));
        expect(observation.unit, _currentUnit(vector));
        expect(
          observation.value.qualifierKind.wireValue,
          vector['expected_qualifier'],
        );
        expect(observation.value.valueNum, vector['expected_point']);
        expect(observation.basisAmount, 100);
        final source =
            jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
        final sourceSummary =
            (source['source_nutrient_summaries'] as List).single as Map;
        expect(sourceSummary['source_fields'], vector['source_row']);
        expect(sourceSummary['unit'], vector['original_unit']);
        expect(
          sourceSummary['reported_amount'],
          (vector['source_row'] as Map)['amount'],
        );
        expect(
          sourceSummary['nutrient_id'],
          ((vector['source_row'] as Map)['nutrient'] as Map)['id'],
        );
      },
    );
  }

  test(
    'Claude extract-number policy retains independently numbered source rows without inventing a unique duplicate point',
    () {
      final bundle = importer.importFoods([
        {
          'fdcId': 1,
          'description': 'Synthetic conflicting IDs',
          'foodNutrients': [
            {
              'amount': 5,
              'nutrient': {
                'id': 1087,
                'number': '203',
                'name': 'Protein',
                'unitName': 'g',
              },
            },
            {
              'amount': 5,
              'nutrient': {
                'id': 99999,
                'number': '203',
                'name': 'Protein',
                'unitName': 'g',
              },
            },
          ],
        },
      ], sourceLabel: 'synthetic_identifier_disagreement');
      expect(bundle.observations, hasLength(2));
      expect(
        bundle.observations.every((o) => o.attributeCode == 'protein_g'),
        isTrue,
      );
      expect(bundle.resolvedFacts, isEmpty);
      expect(
        bundle.projectedFoods.single.isNutrientMissing('proteinG'),
        isTrue,
      );
      final payload =
          jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      expect(payload['source_nutrient_summaries'], hasLength(2));
    },
  );

  test(
    'IU and kJ point evidence retain their own units without conversion',
    () {
      for (final quantity in [
        ('vitamin_d_total_iu', 'IU'),
        ('energy_kj', 'kJ'),
      ]) {
        final result = selectQualifiedNutrientPoints([
          {
            'entity_key': 'food',
            'attribute_code': quantity.$1,
            'source_doc_id': 'source',
            'qualifier_kind': 'exact',
            'value_num': 1.5,
            'unit': quantity.$2,
            'basis_type': 'per_100g_edible_part',
            'basis_amount': 100,
          },
        ]);
        expect(result.points['food']![quantity.$1]!.value, 1.5);
      }
    },
  );
}
