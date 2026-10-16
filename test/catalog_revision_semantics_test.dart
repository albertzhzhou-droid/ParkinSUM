import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/features/catalog/catalog_detail_pages.dart';

import 'helpers/page_test_harness.dart';

class _RevisionDatabase extends InMemoryCdssDatabase {
  _RevisionDatabase(this.observations);
  final List<Map<String, Object?>> observations;
  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      switch (table) {
        'food_variant' => [
          {
            'food_variant_id': 'v1',
            'food_concept_id': 'c1',
            'source_family': 'Foundation',
            'source_food_code': '123',
            'jurisdiction': 'US',
            'display_name_local': 'Synthetic source revision food',
          },
        ],
        'food_concept' => [
          {
            'food_concept_id': 'c1',
            'canonical_name_en': 'Synthetic food',
            'food_group': 'other',
          },
        ],
        'observation' => observations,
        _ => [],
      };
}

void main() {
  Map<String, Object?> observation(
    String id,
    String source, {
    bool censored = false,
  }) => {
    'observation_id': id,
    'entity_key': 'v1',
    'domain': 'food',
    'entity_type': 'food_variant',
    'attribute_code': 'protein_g',
    'qualifier_kind': censored ? 'lt' : 'exact',
    'value_num': censored ? null : 10,
    'low': censored ? 0 : 10,
    'high': censored ? 0.03 : 10,
    'unit': 'g',
    'basis_type': 'per_100g_edible_part',
    'basis_amount': 100,
    'source_doc_id': source,
    'scope_hash': 's1',
    'raw_value_text': censored ? '<0.03' : '10',
  };

  test(
    'historical exact plus newer censored value cannot choose a stale point',
    () async {
      final rows = [
        observation('old', 'doc_old'),
        observation('new', 'doc_new', censored: true),
      ];
      for (final ordering in [rows, rows.reversed.toList()]) {
        final foods = await CdssCatalogProjectionService(
          database: _RevisionDatabase(ordering),
        ).projectFoods();
        expect(foods.single.isNutrientMissing('proteinG'), isTrue);
        expect(foods.single.nutrientObservationEvidence, hasLength(2));
        expect(
          foods.single.nutrientObservationEvidence.every(
            (row) => !row.selectedForLegacyPointProjection,
          ),
          isTrue,
        );
      }
    },
  );

  test('duplicate exact values cannot win by row order', () async {
    final foods = await CdssCatalogProjectionService(
      database: _RevisionDatabase([
        observation('one', 'doc'),
        observation('two', 'doc'),
      ]),
    ).projectFoods();
    expect(foods.single.isNutrientMissing('proteinG'), isTrue);
    expect(foods.single.nutrientObservationEvidence, hasLength(2));
  });

  testWidgets('drug detail shows retained version, date, strength and source', (
    tester,
  ) async {
    final drug = DrugDefinition(
      id: 'synthetic',
      genericName: 'Synthetic medicine',
      brandNames: [],
      tags: [],
      notes: 'Synthetic source fixture',
    );
    final document = ProjectedDrugSourceDocument.fromRow({
      'source_doc_id': 'doc',
      'origin_url': 'https://dailymed.nlm.nih.gov/example',
      'raw_payload': jsonEncode({
        'version_number': '2',
        'effective_time': '20260929',
        'active_ingredient_details': [
          {
            'name': 'synthetic ingredient',
            'numerator_value': '95',
            'numerator_unit': 'mg',
            'denominator_value': '1',
            'denominator_unit': '1',
          },
        ],
      }),
    });
    await pumpFeaturePage(
      tester,
      DrugDetailPage(
        drug: drug,
        future: Future.value(
          ProjectedDrugDetail(
            drug: drug,
            variantIds: ['v'],
            sections: [],
            packagingDescriptions: [],
            mediaLinks: [],
            labelFacts: [],
            sourceDocuments: [document],
          ),
        ),
      ),
      settle: true,
    );
    expect(find.text('Version: 2'), findsOneWidget);
    expect(find.text('Label effective time: 20260929'), findsOneWidget);
    expect(find.text('synthetic ingredient: 95 mg / 1 1'), findsOneWidget);
    expect(
      find.textContaining('do not define an administered dose'),
      findsOneWidget,
    );
    expectNoWidgetErrors();
  });
}
