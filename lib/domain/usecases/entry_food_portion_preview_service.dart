import '../../core/models/food_item.dart';
import '../entities/food_composition_candidate_set_snapshot.dart';
import '../entities/food_portion_composition_projection.dart';
import 'cdss_catalog_projection_service.dart';
import 'food_portion_composition_projection_service.dart';

class EntryFoodPortionPreviewContext {
  const EntryFoodPortionPreviewContext({
    required this.food,
    required this.snapshot,
  });
  final FoodItem food;
  final FoodCompositionCandidateSetSnapshot snapshot;

  FoodPortionCompositionProjection preview(String locator, String nutrient) =>
      const FoodPortionCompositionProjectionService().calculatePreview(
        candidateSetSnapshot: snapshot,
        food: food,
        portionRecordLocator: locator,
        nutrientAttributeCode: nutrient,
      );
}

/// Reuses the projection query audit and the canonical candidate snapshot;
/// no projected quantity or rule result is persisted as an entry input.
class EntryFoodPortionPreviewService {
  const EntryFoodPortionPreviewService({required this.projectionService});
  final CdssCatalogProjectionService projectionService;

  Future<EntryFoodPortionPreviewContext> load({
    required FoodItem food,
    required String registrationRegion,
  }) async {
    final projection = await projectionService.projectFoodsWithAudit();
    final projected = projection.foods
        .where((item) => item.id == food.id)
        .firstOrNull;
    final exactFood = projected ?? food;
    return EntryFoodPortionPreviewContext(
      food: exactFood,
      snapshot: FoodCompositionCandidateSetSnapshot.capture(
        callerCandidateFoods: [food],
        fallbackCandidateFoods: const [],
        projectedFoods: projected == null ? const [] : [projected],
        mergedCandidates: [exactFood],
        projectionQueryAudit: projection.queryAudit,
        builtInP0FallbackUsed: false,
        contentJurisdictionOverride: const [],
        registrationRegion: registrationRegion,
        dietProfileRegion: null,
        tieBreakPolicy: 'entry_explicit_single_food_preview',
      ),
    );
  }
}
