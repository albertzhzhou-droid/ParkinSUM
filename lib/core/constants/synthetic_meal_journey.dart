import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/food_item.dart';
import '../models/meal.dart';

/// Code-owned engineering fixtures. FDC-shaped evidence here is fabricated,
/// openly labelled, and only used inside an isolated, resettable memory graph.
List<FoodItem> syntheticMealJourneyFoods() {
  const sourceFoodId = 'synthetic-1001';
  const sourceDocId = 'synthetic-fdc-shaped-document';
  return [
    FoodItem.fromJson({
      'id': 'synthetic_portion_food',
      'name': 'Synthetic portion food / 合成份量食物',
      'category': 'protein',
      'sourceSystem': 'Foundation',
      'sourceFoodCode': sourceFoodId,
      'jurisdiction': 'US',
      'description':
          'Fabricated FDC-shaped engineering fixture. Not a USDA food record. 合成工程案例，不是 USDA 食物记录。',
      'proteinG': 10.0,
      'carbsG': 20.0,
      'fatG': 4.0,
      'fiberG': 0.0,
      'sodiumMg': 0.0,
      'missingNutrientFields': ['fiberG', 'sodiumMg', 'energyKcal', 'waterG'],
      'foodPortionEvidence': [
        FoodPortionEvidence.fromFdc(
          sourceDocId: sourceDocId,
          sourceFoodId: sourceFoodId,
          portionIndex: 0,
          portion: {
            'amount': 1,
            'gramWeight': 160,
            'measureUnit': {'name': 'synthetic cup / 合成杯'},
          },
        ).toJson(),
      ],
      'nutrientObservationEvidence': [
        for (final nutrient in {
          'protein_g': 10.0,
          'carbohydrate_g': 20.0,
          'fat_g': 4.0,
        }.entries)
          {
            'observation_id': 'synthetic:${nutrient.key}',
            'domain': 'food',
            'entity_type': 'food_variant',
            'entity_key': 'synthetic-variant',
            'attribute_code': nutrient.key,
            'value_type': 'numeric_interval',
            'value_num': nutrient.value,
            'low': nutrient.value,
            'high': nutrient.value,
            'qualifier_kind': 'exact',
            'unit': 'g',
            'basis_type': 'per_100g_edible_part',
            'basis_amount': 100,
            'scope_hash': 'synthetic-scope',
            'source_doc_id': sourceDocId,
            'record_locator': '$sourceFoodId:${nutrient.key}:exact',
            'selected_for_legacy_point_projection': true,
          },
      ],
      'catalogProvenanceEvidence': {
        'source_documents': [
          {
            'source_doc_id': sourceDocId,
            'source_family': 'FDC',
            'organization': 'USDA',
            'jurisdiction': 'US',
            'resolution_status': 'resolved',
            'title': 'Synthetic fixture: FDC-shaped, not an official record',
            'stored_payload_present': true,
            'payload_sha256': sha256
                .convert(utf8.encode('synthetic-meal-journey/1'))
                .toString(),
          },
        ],
      },
    }),
    FoodItem(
      id: 'synthetic_unknown_food',
      name: 'Synthetic unknown food / 合成未知食物',
      category: FoodCategory.other,
      sourceSystem: 'SYNTHETIC',
      description: 'Synthetic missing-data fixture / 合成缺失案例',
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
      fiberG: 0,
      sodiumMg: 0,
      missingNutrientFields: const {
        'proteinG',
        'carbsG',
        'fatG',
        'fiberG',
        'sodiumMg',
      },
    ),
  ];
}

Meal syntheticMealJourneyHistory(FoodItem food) => Meal(
  id: 'synthetic-history-meal',
  title: 'Synthetic previous meal / 合成历史餐',
  eatenAt: DateTime.utc(2026, 9, 28, 16),
  occurredAt: DateTime.utc(2026, 9, 28, 16),
  items: [MealItem.fromFood(food: food, quantityFactor: 1)],
);
