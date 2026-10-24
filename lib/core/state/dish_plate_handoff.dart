import 'package:flutter/foundation.dart';

import '../../domain/entities/dish_recipe.dart';
import '../../domain/usecases/dish_nutrition_view.dart';

/// One catalog food of a dish, at its grams for the requested servings.
@immutable
final class DishPlateItem {
  const DishPlateItem({required this.foodId, required this.grams});

  final String foodId;
  final double grams;

  @override
  bool operator ==(Object other) =>
      other is DishPlateItem && other.foodId == foodId && other.grams == grams;

  @override
  int get hashCode => Object.hash(foodId, grams);

  @override
  String toString() => 'DishPlateItem($foodId, $grams g)';
}

/// "Add ingredients to plate" from the Advanced dishes page.
///
/// Only ingredients resolved in the catalog are carried; the rest are named
/// in [skippedIngredientNames] so a consumer can say what was left out.
/// Nothing here changes a meal or a plate by itself.
@immutable
final class DishPlateRequest {
  const DishPlateRequest({
    required this.dishId,
    required this.catalogVersion,
    required this.servings,
    required this.items,
    required this.skippedIngredientNames,
  });

  /// Builds the request for [servings] servings of [nutrition]'s dish.
  factory DishPlateRequest.fromNutrition(
    DishNutrition nutrition, {
    required String catalogVersion,
    int servings = 1,
  }) => DishPlateRequest(
    dishId: nutrition.dish.id,
    catalogVersion: catalogVersion,
    servings: servings,
    items: List.unmodifiable([
      for (final row in nutrition.ingredients)
        if (row.resolved)
          DishPlateItem(
            foodId: row.food!.id,
            grams: row.ingredient.gramsPerServing * servings,
          ),
    ]),
    skippedIngredientNames: List.unmodifiable([
      for (final row in nutrition.ingredients)
        if (!row.resolved) row.ingredient.name,
    ]),
  );

  final String dishId;
  final String catalogVersion;
  final int servings;
  final List<DishPlateItem> items;
  final List<DishText> skippedIngredientNames;
}

/// Hand-off point between the Advanced dishes page and the Next-meal plate
/// builder. The page [offer]s a request and navigates to Next meal; the
/// planner listens and [take]s it once. Holds at most one pending request,
/// in memory only.
final class DishPlateHandoff extends ChangeNotifier {
  DishPlateHandoff();

  /// App-wide instance used when the page is not given a callback.
  static final DishPlateHandoff instance = DishPlateHandoff();

  DishPlateRequest? _pending;

  DishPlateRequest? get pending => _pending;

  void offer(DishPlateRequest request) {
    _pending = request;
    debugPrint(
      '[DishPlateHandoff] offer dish=${request.dishId} '
      'items=${request.items.length} skipped=${request.skippedIngredientNames.length}',
    );
    notifyListeners();
  }

  /// Returns and clears the pending request.
  DishPlateRequest? take() {
    final request = _pending;
    if (request == null) return null;
    _pending = null;
    notifyListeners();
    return request;
  }
}
