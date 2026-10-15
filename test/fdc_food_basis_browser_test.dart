import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_artifact_store_stub.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'source basis survives Web backend write and fresh service projection',
    () async {
      // Synthetic source fields; this is not a verified branded source corpus
      // or evidence of real browser reload/OS-kill durability.
      for (final (family, description, unit, basis, eligible) in [
        ('Branded', 'Synthetic drink', 'mL', 'per_100ml_product', false),
        (
          'Branded',
          'Synthetic unknown unit',
          '',
          'source_basis_unqualified',
          false,
        ),
        ('Branded', 'Synthetic mass source', 'g', 'per_100g_edible_part', true),
        (
          'Foundation',
          'Synthetic beans (0% moisture)',
          '',
          'per_100g_dry_matter',
          false,
        ),
      ]) {
        SharedPreferences.setMockInitialValues({});
        final bundle =
            const FdcP0Importer(
              fetchClient: FakeSourceFetchClient(textByUrl: {}),
            ).importFoods([
              {
                'fdcId': 999,
                'dataType': family,
                'description': description,
                'servingSize': 30,
                'servingSizeUnit': unit,
                'foodNutrients': [
                  {
                    'id': 1,
                    'amount': 5,
                    'nutrient': {
                      'id': 1003,
                      'number': '203',
                      'name': 'Protein',
                      'unitName': 'g',
                    },
                  },
                ],
              },
            ], sourceLabel: 'synthetic_backend_basis');
        await ClinicalDecisionSupportService(
          database: WebCdssDatabase(),
          factConflictEngine: FactConflictEngine(),
          runtimeRuleEngine: RuntimeRuleEngine(),
          artifactStore: InlineCdssArtifactStore(),
        ).importBundle(bundle);
        final fresh = WebCdssDatabase();
        final rowsBefore = await fresh.queryTable('observation');
        final result = await CdssCatalogProjectionService(
          database: fresh,
        ).projectFoods();
        final food = result.single;
        expect(food.basisType, basis, reason: description);
        expect(food.isNutrientMissing('proteinG'), !eligible);
        expect(food.nutrientObservationEvidence.single.valueNum, 5);
        expect(
          food
              .nutrientObservationEvidence
              .single
              .selectedForLegacyPointProjection,
          eligible,
        );
        expect(await fresh.queryTable('observation'), rowsBefore);
        final source = (await fresh.queryTable('source_document')).single;
        final payload = jsonDecode(source['raw_payload'] as String) as Map;
        final retained =
            (payload['food_basis_evidence'] as List).single['source_fields'];
        expect(retained['servingSize'], 30);
        expect(retained['servingSizeUnit'], unit);
        if (eligible) expect(food.proteinG, 5);
      }
    },
  );
  test(
    'retired unknown and provider-mismatched ingestion markers retain original values but withhold arithmetic',
    () async {
      for (final status in [
        'retired',
        'inactive',
        'held',
        'draft',
        'imported_unknown_provider',
        'imported_ciqual_xml',
        'seeded_from_verified_report',
        'imported_china_cdc_food_page',
      ]) {
        SharedPreferences.setMockInitialValues({});
        final bundle =
            const FdcP0Importer(
              fetchClient: FakeSourceFetchClient(textByUrl: {}),
            ).importFoods([
              {
                'fdcId': 999,
                'dataType': 'Branded',
                'description': 'Synthetic mass source',
                'servingSize': 30,
                'servingSizeUnit': 'g',
                'foodNutrients': [
                  {
                    'id': 1,
                    'amount': 5,
                    'nutrient': {
                      'id': 1003,
                      'number': '203',
                      'name': 'Protein',
                      'unitName': 'g',
                    },
                  },
                ],
              },
            ], sourceLabel: 'synthetic_marker_rejection');
        final db = WebCdssDatabase();
        await ClinicalDecisionSupportService(
          database: db,
          factConflictEngine: FactConflictEngine(),
          runtimeRuleEngine: RuntimeRuleEngine(),
          artifactStore: InlineCdssArtifactStore(),
        ).importBundle(bundle);
        final variant = bundle.foodVariants.single;
        await db.insertFoodVariant(
          FoodVariantRecord(
            foodVariantId: variant.foodVariantId,
            foodConceptId: variant.foodConceptId,
            jurisdiction: variant.jurisdiction,
            sourceFamily: variant.sourceFamily,
            sourceFoodCode: variant.sourceFoodCode,
            displayNameLocal: variant.displayNameLocal,
            isAuthoritativeForRegion: variant.isAuthoritativeForRegion,
            isAuthoritativeFallback: variant.isAuthoritativeFallback,
            status: status,
            fallbackChainJson: variant.fallbackChainJson,
          ),
        );
        final fresh = WebCdssDatabase();
        final original = await fresh.queryTable('observation');
        final projection = await CdssCatalogProjectionService(
          database: fresh,
        ).projectFoodsWithAudit();
        final food = projection.foods.single;
        expect(food.isNutrientMissing('proteinG'), isTrue, reason: status);
        expect(food.nutrientObservationEvidence.single.valueNum, 5);
        expect(
          food
              .nutrientObservationEvidence
              .single
              .selectedForLegacyPointProjection,
          isFalse,
        );
        expect(
          projection.queryAudit['read_consistency'],
          'web_single_document',
        );
        expect(await fresh.queryTable('observation'), original);
        expect(
          (await fresh.queryTable('food_variant')).single['status'],
          status,
        );
      }
    },
  );
}
