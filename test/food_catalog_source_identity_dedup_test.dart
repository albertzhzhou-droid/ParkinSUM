import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clinical_decision_support_service_test.dart' show RecordingCdssDatabase;

/// Stores food concepts and variants with the columns the web and native
/// adapters write, so the boot projection sees source family and code.
class _VariantKeepingCdssDatabase extends RecordingCdssDatabase {
  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {
    tables['food_concept']!.add({
      'food_concept_id': record.foodConceptId,
      'canonical_name_en': record.canonicalNameEn,
      'canonical_name_zh': record.canonicalNameZh,
      'food_group': record.foodGroup,
    });
  }

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {
    tables['food_variant']!.add({
      'food_variant_id': record.foodVariantId,
      'food_concept_id': record.foodConceptId,
      'jurisdiction': record.jurisdiction,
      'source_family': record.sourceFamily,
      'source_food_code': record.sourceFoodCode,
      'display_name_local': record.displayNameLocal,
      'is_authoritative_for_region': record.isAuthoritativeForRegion,
      'is_authoritative_fallback': record.isAuthoritativeFallback,
      'status': record.status,
      'fallback_chain_json': record.fallbackChainJson,
    });
  }
}

const _allMissing = {
  'proteinG',
  'carbsG',
  'fatG',
  'fiberG',
  'sodiumMg',
  'energyKcal',
  'waterG',
};

FoodItem _food(
  String id, {
  String sourceSystem = 'USDA_FDC',
  String? code = '171265',
  Set<String> missing = const {},
  String description = '',
}) => FoodItem(
  id: id,
  name: id,
  category: FoodCategory.dairy,
  description: description,
  sourceSystem: sourceSystem,
  sourceFoodCode: code,
  jurisdiction: 'US',
  proteinG: 3.15,
  carbsG: 4.8,
  fatG: 3.25,
  fiberG: 0,
  sodiumMg: 43,
  energyKcal: missing.contains('energyKcal') ? null : 61,
  waterG: missing.contains('waterG') ? null : 88,
  missingNutrientFields: missing,
);

void main() {
  group('collapseFoodsBySourceIdentity', () {
    test('drops an all-unknown projection of a complete catalogue food', () {
      final complete = _food('food_ref_usda_171265');
      final projection = _food(
        'food_projected_food_food_ref_usda_171265#us#usda_fdc#171265',
        missing: _allMissing,
      );
      expect(AppState.collapseFoodsBySourceIdentity([projection, complete]), [
        same(complete),
      ]);
      expect(AppState.collapseFoodsBySourceIdentity([complete, projection]), [
        same(complete),
      ]);
    });

    test('an equally complete pair keeps the stable catalogue id', () {
      final catalogue = _food(
        'food_milk',
        sourceSystem: 'CIQUAL',
        code: 'UNSPECIFIED_CIQUAL_MILK',
      );
      final projection = _food(
        'food_projected_food_milk#fr#ciqual#unspecified_ciqual_milk',
        sourceSystem: 'CIQUAL',
        code: 'UNSPECIFIED_CIQUAL_MILK',
      );
      expect(AppState.collapseFoodsBySourceIdentity([projection, catalogue]), [
        same(catalogue),
      ]);
    });

    test('a more complete projection keeps its values under the stable id', () {
      final sparse = _food(
        'food_ref_usda_171265',
        missing: const {'sodiumMg', 'energyKcal', 'waterG'},
      );
      final richer = _food(
        'food_projected_food_food_ref_usda_171265#us#usda_fdc#171265',
      );
      final other = _food('food_ref_usda_171267', code: '171267');
      final collapsed = AppState.collapseFoodsBySourceIdentity([
        sparse,
        other,
        richer,
      ]);
      expect(collapsed.map((food) => food.id), [
        'food_ref_usda_171265',
        'food_ref_usda_171267',
      ]);
      expect(collapsed.first.missingNutrientFields, isEmpty);
      expect(collapsed.first.energyKcal, 61);
      expect(collapsed.first.toJson(), {
        ...richer.toJson(),
        'id': 'food_ref_usda_171265',
      });
    });

    test('a group of fallback projections keeps its most complete one', () {
      final sparse = _food('food_projected_a', missing: _allMissing);
      final richer = _food('food_projected_b');
      expect(AppState.collapseFoodsBySourceIdentity([sparse, richer]), [
        same(richer),
      ]);
    });

    test('FDC data types share one id namespace; other keys stay apart', () {
      final catalogue = _food('food_ref_usda_171265');
      final imported = _food(
        'food_projected_import',
        sourceSystem: 'sr_legacy_food',
        missing: _allMissing,
      );
      final otherCode = _food('food_ref_usda_171267', code: '171267');
      final otherSource = _food('food_ciqual_19024', sourceSystem: 'CIQUAL');
      final noCode = _food('custom_a', code: null);
      final noCodeAgain = _food('custom_b', code: '  ');
      expect(
        AppState.collapseFoodsBySourceIdentity([
          noCode,
          catalogue,
          imported,
          otherCode,
          otherSource,
          noCodeAgain,
        ]),
        [
          same(noCode),
          same(catalogue),
          same(otherCode),
          same(otherSource),
          same(noCodeAgain),
        ],
      );
    });
  });

  test(
    'boot keeps one complete record per source food and no projection copy',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        services: Services.createEphemeral(
          cdssDatabase: _VariantKeepingCdssDatabase(),
        ),
      );
      addTearDown(state.dispose);
      await state.services.ready;
      await state.bootstrap();

      final foods = state.services.foodRepository.allFoods;
      final keys = [
        for (final food in foods)
          if ((food.sourceFoodCode ?? '').isNotEmpty)
            '${food.sourceSystem}|${food.sourceFoodCode}',
      ];
      expect(keys.toSet().length, keys.length);
      expect(
        foods.where((food) => food.id.startsWith('food_projected_')),
        isEmpty,
      );

      for (final query in ['milk', 'chicken breast']) {
        final results = state.catalogEngine.searchFoods(query);
        expect(results, isNotEmpty, reason: query);
        final codes = [
          for (final food in results)
            '${food.sourceSystem}|${food.sourceFoodCode}',
        ];
        expect(codes.toSet().length, codes.length, reason: query);
        for (final food in results) {
          expect(
            food.description,
            isNot(contains('Projected from CDSS')),
            reason: food.id,
          );
          expect(
            _allMissing.difference(food.missingNutrientFields),
            isNotEmpty,
            reason: '${food.id} surfaced with every nutrient unknown',
          );
        }
      }
      for (final fdcId in ['172446', '171265', '171267', '171269', '171477']) {
        final records = foods.where((food) => food.sourceFoodCode == fdcId);
        expect(records, hasLength(1), reason: fdcId);
        expect(records.single.id, 'food_ref_usda_$fdcId');
        expect(records.single.isNutrientMissing('proteinG'), isFalse);
      }
      expect(
        foods.where((food) => food.sourceFoodCode == 'UNSPECIFIED_CIQUAL_MILK'),
        [isA<FoodItem>().having((food) => food.id, 'id', 'food_milk')],
      );
    },
  );
}
