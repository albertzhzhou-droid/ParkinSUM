import 'dart:convert';

import '../../domain/entities/cdss_records.dart';
import 'food_item.dart';
import 'meal.dart';

/// Only user inputs are retained. Checks, traces and source-portion previews
/// are deliberately absent and must be recalculated in the active session.
class MealDraft {
  static const schemaId = 'parkinsum.meal-draft/1';

  const MealDraft({
    required this.draftId,
    required this.meal,
    required this.updatedAt,
    this.editingMealId,
    this.reusedFromMealId,
    this.timeConfirmed = false,
    this.quantitiesConfirmed = false,
  });

  final String draftId;
  final Meal meal;
  final DateTime updatedAt;
  final String? editingMealId;
  final String? reusedFromMealId;
  final bool timeConfirmed;
  final bool quantitiesConfirmed;

  bool get requiresConfirmation => reusedFromMealId != null;
  bool get readyToSave =>
      meal.items.isNotEmpty &&
      (!requiresConfirmation || (timeConfirmed && quantitiesConfirmed));

  /// Reuses the existing template record shape, without adding a second
  /// template catalogue or copying the old occurrence / result context.
  static MealTemplateRecord templateFromHistory(
    Meal history, {
    required String countryCode,
    required List<FoodItem> catalog,
  }) => MealTemplateRecord(
    mealTemplateId: 'history:${history.id}',
    countryCode: countryCode,
    mealSlot: 'user_history',
    textureLevel: 'unspecified',
    templateJson: jsonEncode({
      'title': history.title,
      'items': [
        for (final item in history.items)
          (catalog.where((food) => food.id == item.foodId).firstOrNull == null
                  ? item.copyWith(foodTags: List<String>.of(item.foodTags))
                  : MealItem.fromFood(
                      food: catalog.firstWhere(
                        (food) => food.id == item.foodId,
                      ),
                      quantityFactor: item.quantityFactor,
                      foodTags: List<String>.of(item.foodTags),
                    ))
              .toJson(),
      ],
    }),
  );

  factory MealDraft.fromTemplate({
    required MealTemplateRecord template,
    required String draftId,
    required String newMealId,
    required DateTime now,
    required String historyMealId,
  }) {
    if (newMealId == historyMealId) {
      throw ArgumentError('A reused meal must have a fresh identity');
    }
    final input = jsonDecode(template.templateJson) as Map<String, dynamic>;
    return MealDraft(
      draftId: draftId,
      updatedAt: now,
      reusedFromMealId: historyMealId,
      meal: Meal(
        id: newMealId,
        title: input['title'] as String,
        eatenAt: now,
        recordedAt: now,
        occurredAt: now,
        timeSource: 'user_exact',
        items: [
          for (final item in input['items'] as List)
            MealItem.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
      ),
    );
  }

  MealDraft copyWith({
    Meal? meal,
    DateTime? updatedAt,
    bool? timeConfirmed,
    bool? quantitiesConfirmed,
  }) => MealDraft(
    draftId: draftId,
    meal: meal ?? this.meal,
    updatedAt: updatedAt ?? this.updatedAt,
    editingMealId: editingMealId,
    reusedFromMealId: reusedFromMealId,
    timeConfirmed: timeConfirmed ?? this.timeConfirmed,
    quantitiesConfirmed: quantitiesConfirmed ?? this.quantitiesConfirmed,
  );

  Map<String, dynamic> toJson() => {
    'schemaId': schemaId,
    'draftId': draftId,
    'meal': meal.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
    'editingMealId': editingMealId,
    'reusedFromMealId': reusedFromMealId,
    'timeConfirmed': timeConfirmed,
    'quantitiesConfirmed': quantitiesConfirmed,
  };

  factory MealDraft.fromJson(Map<String, dynamic> json) {
    const fields = {
      'schemaId',
      'draftId',
      'meal',
      'updatedAt',
      'editingMealId',
      'reusedFromMealId',
      'timeConfirmed',
      'quantitiesConfirmed',
    };
    if (json['schemaId'] != schemaId ||
        json.keys.toSet().difference(fields).isNotEmpty ||
        json.length != fields.length ||
        json['timeConfirmed'] is! bool ||
        json['quantitiesConfirmed'] is! bool) {
      throw const FormatException('Unsupported meal draft');
    }
    const mealFields = {
      'id',
      'eatenAt',
      'recordedAt',
      'occurredAt',
      'occurredRangeStart',
      'occurredRangeEnd',
      'timeSource',
      'timePrecision',
      'nextMealWindowStart',
      'nextMealWindowEnd',
      'coeventTime',
      'coeventSubstanceTags',
      'thickenerType',
      'enteralFeedMode',
      'enteralFeedFormula',
      'enteralFeedProteinGPerDay',
      'title',
      'items',
    };
    const itemFields = {
      'foodId',
      'foodName',
      'foodCategory',
      'quantityFactor',
      'foodTags',
      'proteinPer100g',
      'carbsPer100g',
      'fatPer100g',
      'fiberPer100g',
      'sodiumPer100g',
    };
    const missingFields = {
      'proteinG',
      'carbsG',
      'fatG',
      'fiberG',
      'sodiumMg',
      'energyKcal',
      'waterG',
    };
    final mealJson = Map<String, dynamic>.from(json['meal'] as Map);
    if (mealJson.keys.toSet().difference(mealFields).isNotEmpty ||
        mealJson.length != mealFields.length ||
        mealJson['items'] is! List) {
      throw const FormatException('Unsupported nested meal draft');
    }
    if (mealJson['coeventSubstanceTags'] is! List ||
        (mealJson['coeventSubstanceTags'] as List).any(
          (tag) => tag is! String,
        )) {
      throw const FormatException('Invalid draft context tags');
    }
    for (final raw in mealJson['items'] as List) {
      if (raw is! Map) throw const FormatException('Invalid draft item');
      final item = Map<String, dynamic>.from(raw);
      if (item.keys.toSet().difference({
            ...itemFields,
            'missingNutrientFields',
          }).isNotEmpty ||
          itemFields.difference(item.keys.toSet()).isNotEmpty) {
        throw const FormatException('Unsupported nested draft item');
      }
      if (item['foodId'] is! String ||
          item['foodName'] is! String ||
          !FoodCategory.values.any(
            (category) => category.name == item['foodCategory'],
          ) ||
          item['foodTags'] is! List ||
          (item['foodTags'] as List).any((tag) => tag is! String)) {
        throw const FormatException('Invalid draft food identity');
      }
      for (final field in [
        'proteinPer100g',
        'carbsPer100g',
        'fatPer100g',
        'fiberPer100g',
        'sodiumPer100g',
      ]) {
        final value = item[field];
        if (value is! num || !value.isFinite || value < 0) {
          throw const FormatException('Invalid draft nutrient');
        }
      }
      final missing = item['missingNutrientFields'];
      if (item.containsKey('missingNutrientFields') &&
          (missing is! List ||
              missing.any(
                (field) => field is! String || !missingFields.contains(field),
              ))) {
        throw const FormatException('Unsupported draft missingness');
      }
    }
    final draft = MealDraft(
      draftId: json['draftId'] as String,
      meal: Meal.fromJson(mealJson),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      editingMealId: json['editingMealId'] as String?,
      reusedFromMealId: json['reusedFromMealId'] as String?,
      timeConfirmed: json['timeConfirmed'] as bool,
      quantitiesConfirmed: json['quantitiesConfirmed'] as bool,
    );
    if (draft.draftId.isEmpty ||
        draft.meal.id.isEmpty ||
        draft.meal.items.length > 100 ||
        draft.meal.items.any(
          (item) => !item.quantityFactor.isFinite || item.quantityFactor <= 0,
        ) ||
        (draft.editingMealId != null && draft.editingMealId != draft.meal.id) ||
        draft.reusedFromMealId == draft.meal.id) {
      throw const FormatException('Invalid meal draft inputs');
    }
    return draft;
  }
}
