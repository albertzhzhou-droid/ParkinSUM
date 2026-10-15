import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';

import 'held_import_review_evidence_test.dart' show serviceFor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  // Full USDA API responses acquired 2026-10-02, before these source changes.
  // Raw response digests and original amounts are independent of the importer.
  const sources = {
    2642521: (
      '5887a5f5f291fa5fd5978c5b69183b58f95ad47be23d6acb14002ac51fed378f',
      'MLT',
      'source_basis_unqualified',
      16,
    ),
    2385707: (
      '7598393d82d95711bacb23b905a897810bd9a189ae0f20dcbe8ecd4748e2e92a',
      'ml',
      'per_100ml_product',
      14,
    ),
  };
  for (final entry in sources.entries) {
    test(
      'full Branded source ${entry.key} preserves original quantities and units',
      () async {
        final bytes = File(
          'test/fixtures/importers/usda_fdc_branded_${entry.key}_full_2026_10_02.json',
        ).readAsBytesSync();
        expect(sha256.convert(bytes).toString(), entry.value.$1);
        final original = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        expect(original['servingSizeUnit'], entry.value.$2);
        final nutrients = original['foodNutrients'] as List;
        expect(nutrients, hasLength(entry.value.$4));
        final bundle = const FdcP0Importer(
          fetchClient: FakeSourceFetchClient(textByUrl: {}),
        ).importFoods([original], sourceLabel: 'official-branded-${entry.key}');
        final payload =
            jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
        final product =
            (payload['branded_product_details'] as List).single as Map;
        expect(product['source_fields'], original);
        expect(product['parser_contract'], 'fdc_branded_product_detail_v1');
        expect(product['source_currency_inferred'], isFalse);
        expect(product['ingredient_quantity_inferred'], isFalse);
        final summaries = payload['source_nutrient_summaries'] as List;
        expect(summaries, hasLength(nutrients.length));
        for (var index = 0; index < nutrients.length; index++) {
          final row = nutrients[index] as Map;
          final nutrient = row['nutrient'] as Map;
          final summary = summaries[index] as Map;
          expect(summary['food_nutrient_id'], row['id']);
          expect(summary['nutrient_id'], nutrient['id']);
          expect(summary['reported_amount'], row['amount']);
          expect(summary['unit'], nutrient['unitName']);
          expect(summary['derivation_fields'], row['foodNutrientDerivation']);
        }
        final sourceFields =
            (payload['food_basis_evidence'] as List).single['source_fields']
                as Map;
        expect(sourceFields['labelNutrients'], original['labelNutrients']);
        expect(sourceFields['servingSizeUnit'], original['servingSizeUnit']);
        expect(sourceFields['servingSize'], original['servingSize']);
        expect(
          bundle.observations
              .where((row) => row.methodCode != 'fdc:label_nutrients')
              .every((row) => row.basisType == entry.value.$3),
          isTrue,
        );
        final database = WebCdssDatabase();
        await serviceFor(database).importBundle(bundle);
        final fresh = WebCdssDatabase();
        final persistedSource = (await fresh.queryTable(
          'source_document',
        )).single;
        expect(
          (jsonDecode(
                    persistedSource['raw_payload'] as String,
                  )['branded_product_details']
                  as List)
              .single['source_fields'],
          original,
        );
        final food = (await CdssCatalogProjectionService(
          database: fresh,
        ).projectFoods()).single;
        expect(food.sourceBasisEvidence, sourceFields);
        expect(food.foodProductEvidence.single.sourceFields, original);
        final cached = FoodItem.fromJson(jsonDecode(jsonEncode(food.toJson())));
        expect(cached.foodProductEvidence.single.sourceFields, original);
        expect(
          () => cached.foodProductEvidence.single.sourceFields['brandName'] =
              'changed',
          throwsUnsupportedError,
        );
        expect(
          () =>
              (cached.foodProductEvidence.single.sourceFields['foodNutrients']
                      as List)
                  .clear(),
          throwsUnsupportedError,
        );
        expect(
          cached.foodProductEvidence.single
              .toJson()['quantity_conversion_applied'],
          false,
        );

        expect(food.supportsEdibleMassPoint, isFalse);
        expect(
          foodItemToCandidateFood(food).components.single.proteinGrams,
          isNull,
        );
        expect(
          FoodItem.fromJson(food.toJson()).supportsEdibleMassPoint,
          isFalse,
        );
        expect(
          food.nutrientObservationEvidence.every(
            (row) => !row.selectedForLegacyPointProjection,
          ),
          isTrue,
        );
      },
    );
  }
}
