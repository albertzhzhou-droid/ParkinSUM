import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../entities/catalog_version_change_diff.dart';

/// Aggregate-only counts for exact food source-code references in the current
/// local catalog and saved meal lines. Meal rows do not bind catalog releases,
/// so every hit remains a potential reference.
final class FoodCatalogVersionChangeImpactPreview {
  FoodCatalogVersionChangeImpactPreview({
    required this.foodCatalogEntryCount,
    required this.foodEntriesWithComparableSourceIdentity,
    required this.foodEntriesWithPotentialChangedCodeMatch,
    required Map<CatalogVersionChangeKind, int> foodMatchesByKind,
    required this.mealCount,
    required this.mealLineCount,
    required this.mealLinesWithComparableFoodIdentity,
    required this.mealLinesWithPotentialChangedCodeMatch,
    required this.mealsWithPotentialChangedCodeMatch,
    required Map<CatalogVersionChangeKind, int> mealLineMatchesByKind,
  }) : foodMatchesByKind = Map<CatalogVersionChangeKind, int>.unmodifiable(
         foodMatchesByKind,
       ),
       mealLineMatchesByKind = Map<CatalogVersionChangeKind, int>.unmodifiable(
         mealLineMatchesByKind,
       );

  final int foodCatalogEntryCount;
  final int foodEntriesWithComparableSourceIdentity;
  final int foodEntriesWithPotentialChangedCodeMatch;
  final Map<CatalogVersionChangeKind, int> foodMatchesByKind;
  final int mealCount;
  final int mealLineCount;
  final int mealLinesWithComparableFoodIdentity;
  final int mealLinesWithPotentialChangedCodeMatch;
  final int mealsWithPotentialChangedCodeMatch;
  final Map<CatalogVersionChangeKind, int> mealLineMatchesByKind;

  int get foodEntriesWithoutComparableSourceIdentity =>
      foodCatalogEntryCount - foodEntriesWithComparableSourceIdentity;

  int get mealLinesWithoutComparableFoodIdentity =>
      mealLineCount - mealLinesWithComparableFoodIdentity;

  /// Meal and FoodItem schemas do not bind these references to a catalog
  /// release, so a matching code cannot establish that a row was affected.
  bool get sourceReleaseBindingAvailable => false;
}

/// Finds exact source-code references without exposing or changing local rows.
final class FoodCatalogVersionChangeImpactService {
  const FoodCatalogVersionChangeImpactService();

  static const int maxFoodEntries = 100000;
  static const int maxMeals = 100000;
  static const int maxMealLines = 1000000;

  FoodCatalogVersionChangeImpactPreview preview({
    required CatalogVersionChangeDiff diff,
    required List<FoodItem> foods,
    required List<Meal> meals,
  }) {
    if (foods.length > maxFoodEntries || meals.length > maxMeals) {
      throw ArgumentError('Food catalog impact input exceeds its size bound.');
    }
    var mealLineCount = 0;
    for (final meal in meals) {
      mealLineCount += meal.items.length;
      if (mealLineCount > maxMealLines) {
        throw ArgumentError(
          'Food catalog impact input exceeds its size bound.',
        );
      }
    }

    final sourceSystem = _sourceKey(diff.previousSnapshot.sourceSystem);
    final jurisdiction = _sourceKey(diff.previousSnapshot.jurisdiction);
    final changedKindsByCode = <String, CatalogVersionChangeKind>{
      for (final entry in diff.entries)
        if (entry.previousConcept != null &&
            entry.kind != CatalogVersionChangeKind.unchanged)
          entry.previousConcept!.code: entry.kind,
    };
    final foodsById = <String, FoodItem>{};
    final duplicateFoodIds = <String>{};
    for (final food in foods) {
      if (foodsById.containsKey(food.id)) {
        duplicateFoodIds.add(food.id);
      } else {
        foodsById[food.id] = food;
      }
    }
    for (final id in duplicateFoodIds) {
      foodsById.remove(id);
    }

    final foodMatchesByKind = _emptyCounts();
    final mealLineMatchesByKind = _emptyCounts();
    var comparableFoodEntries = 0;
    var matchedFoodEntries = 0;
    for (final food in foods) {
      if (duplicateFoodIds.contains(food.id) ||
          !_hasComparableSourceIdentity(
            food: food,
            sourceSystem: sourceSystem,
            jurisdiction: jurisdiction,
          )) {
        continue;
      }
      comparableFoodEntries++;
      final kind = changedKindsByCode[food.sourceFoodCode];
      if (kind != null) {
        matchedFoodEntries++;
        foodMatchesByKind[kind] = foodMatchesByKind[kind]! + 1;
      }
    }

    var comparableMealLines = 0;
    var matchedMealLines = 0;
    var matchedMeals = 0;
    for (final meal in meals) {
      var mealHasMatch = false;
      for (final item in meal.items) {
        final food = foodsById[item.foodId];
        if (food == null ||
            !_hasComparableSourceIdentity(
              food: food,
              sourceSystem: sourceSystem,
              jurisdiction: jurisdiction,
            )) {
          continue;
        }
        comparableMealLines++;
        final kind = changedKindsByCode[food.sourceFoodCode];
        if (kind != null) {
          matchedMealLines++;
          mealHasMatch = true;
          mealLineMatchesByKind[kind] = mealLineMatchesByKind[kind]! + 1;
        }
      }
      if (mealHasMatch) matchedMeals++;
    }

    return FoodCatalogVersionChangeImpactPreview(
      foodCatalogEntryCount: foods.length,
      foodEntriesWithComparableSourceIdentity: comparableFoodEntries,
      foodEntriesWithPotentialChangedCodeMatch: matchedFoodEntries,
      foodMatchesByKind: foodMatchesByKind,
      mealCount: meals.length,
      mealLineCount: mealLineCount,
      mealLinesWithComparableFoodIdentity: comparableMealLines,
      mealLinesWithPotentialChangedCodeMatch: matchedMealLines,
      mealsWithPotentialChangedCodeMatch: matchedMeals,
      mealLineMatchesByKind: mealLineMatchesByKind,
    );
  }

  Map<CatalogVersionChangeKind, int> _emptyCounts() => {
    for (final kind in CatalogVersionChangeKind.values) kind: 0,
  };

  String _sourceKey(String value) => value.trim().toUpperCase();

  bool _hasComparableSourceIdentity({
    required FoodItem food,
    required String sourceSystem,
    required String jurisdiction,
  }) =>
      _sourceKey(food.sourceSystem) == sourceSystem &&
      _sourceKey(food.jurisdiction) == jurisdiction &&
      _isUsableFoodCode(food.sourceFoodCode);

  bool _isUsableFoodCode(String? value) =>
      value != null &&
      value.isNotEmpty &&
      value.trim() == value &&
      !value.toUpperCase().startsWith('UNSPECIFIED_');
}
