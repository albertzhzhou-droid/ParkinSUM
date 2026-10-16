import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';

import 'held_import_review_evidence_test.dart' show serviceFor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Claude nutrition survives atomic import with separate label evidence',
    () async {
      final bundle =
          const FdcP0Importer(
            fetchClient: FakeSourceFetchClient(textByUrl: {}),
          ).importFoods([
            {
              'fdcId': 990015,
              'description': 'Synthetic integration food',
              'dataType': 'Branded',
              'servingSize': 50,
              'servingSizeUnit': 'g',
              'labelNutrients': {
                'protein': {'value': 5},
              },
              'foodNutrients': [
                {
                  'amount': 10,
                  'nutrient': {
                    'id': 1003,
                    'number': '203',
                    'name': 'Protein',
                    'unitName': 'g',
                  },
                },
                {
                  'amount': 20,
                  'nutrient': {
                    'id': 1005,
                    'number': '205',
                    'name': 'Carbohydrate, by difference',
                    'unitName': 'g',
                  },
                },
                {
                  'amount': 2,
                  'nutrient': {
                    'id': 1079,
                    'number': '291',
                    'name': 'Fiber, total dietary',
                    'unitName': 'g',
                  },
                },
              ],
            },
          ], sourceLabel: 'synthetic-claude-integration');

      final labels = bundle.observations
          .where((row) => row.basisType == 'per_serving_label')
          .toList();
      expect(labels, hasLength(1));
      expect(labels.single.value.valueNum, 5);
      expect(bundle.projectedFoods.single.proteinG, 10);
      expect(bundle.projectedFoods.single.carbsG, 18);

      final database = WebCdssDatabase();
      final report = await serviceFor(database).importBundle(bundle);
      final fresh = WebCdssDatabase();
      expect(
        (await serviceFor(fresh).latestPromotedSnapshot())?.snapshotId,
        report.promotedSnapshotId,
      );
      final observations = await fresh.queryTable('observation');
      expect(observations, hasLength(bundle.observations.length));
      expect(
        observations.where((row) => row['basis_type'] == 'per_serving_label'),
        hasLength(1),
      );
      final facts = await fresh.queryTable('resolved_fact');
      expect(
        facts.any(
          (row) => row['chosen_observation_id'] == labels.single.observationId,
        ),
        isFalse,
      );
      final food = (await CdssCatalogProjectionService(
        database: fresh,
      ).projectFoods()).single;
      expect(food.proteinG, 10);
      expect(food.carbsG, 18);
      final labelEvidence = food.nutrientObservationEvidence.singleWhere(
        (row) => row.basisType == 'per_serving_label',
      );
      expect(labelEvidence.valueNum, 5);
      expect(labelEvidence.selectedForLegacyPointProjection, isFalse);
      final proteinPoint = food.nutrientObservationEvidence.singleWhere(
        (row) =>
            row.attributeCode == 'protein_g' &&
            row.basisType == 'per_100g_edible_part',
      );
      expect(proteinPoint.valueNum, 10);
      expect(proteinPoint.selectedForLegacyPointProjection, isTrue);
      expect(await fresh.queryTable('observation'), observations);
    },
  );

  test(
    'label-only quantity remains evidence and never supplies a mass point',
    () async {
      final bundle =
          const FdcP0Importer(
            fetchClient: FakeSourceFetchClient(textByUrl: {}),
          ).importFoods([
            {
              'fdcId': 990016,
              'description': 'Synthetic label-only food',
              'dataType': 'Branded',
              'servingSize': 50,
              'servingSizeUnit': 'g',
              'labelNutrients': {
                'protein': {'value': 5},
              },
              'foodNutrients': <Object?>[],
            },
          ], sourceLabel: 'synthetic-claude-label-only');
      final database = WebCdssDatabase();
      await serviceFor(database).importBundle(bundle);
      final fresh = WebCdssDatabase();
      final before = await fresh.queryTable('observation');
      final food = (await CdssCatalogProjectionService(
        database: fresh,
      ).projectFoods()).single;
      expect(food.isNutrientMissing('proteinG'), isTrue);
      expect(food.nutrientObservationEvidence.single.valueNum, 5);
      expect(
        food.nutrientObservationEvidence.single.basisType,
        'per_serving_label',
      );
      expect(
        food
            .nutrientObservationEvidence
            .single
            .selectedForLegacyPointProjection,
        isFalse,
      );
      expect(await fresh.queryTable('resolved_fact'), isEmpty);
      expect(await fresh.queryTable('observation'), before);
    },
  );
}
