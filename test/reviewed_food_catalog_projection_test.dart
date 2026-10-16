import 'package:parkinsum_companion/core/db/app_database_memory.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'dart:convert';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'reviewed_import_activation_test.dart' show prepareOn, activate;
import 'held_import_review_evidence_test.dart' show serviceFor;

class CachedFoodDatabase extends InMemoryAppDatabase {
  List<FoodItem>? cached;
  @override
  Future<List<FoodItem>> loadFoods() async => cached ?? await super.loadFoods();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<WebCdssDatabase> selected() async {
    final db = WebCdssDatabase();
    final service = serviceFor(db);
    final held = await prepareOn(db, service);
    final preview = await service.previewReviewedImport(
      heldSnapshotId: held.snapshotId,
      decisionIds: [held.decisionId],
    );
    await activate(service, preview);
    return db;
  }

  test(
    'actual new backend selects original 10 without removing alternative 1',
    () async {
      await selected();
      final fresh = WebCdssDatabase();
      final result = await CdssCatalogProjectionService(
        database: fresh,
        requireConsistentCatalog: true,
      ).projectFoodsWithAudit();
      final food = result.foods.single;
      expect(food.proteinG, 10);
      expect(food.isNutrientMissing('proteinG'), false);
      expect(food.nutrientObservationEvidence, hasLength(2));
      expect(
        food.nutrientObservationEvidence
            .where((e) => e.selectedForLegacyPointProjection)
            .single
            .observationId,
        'b',
      );
      expect(
        (result.queryAudit['reviewed_nutrient_selection'] as List)
            .single['status'],
        'explicit_original_source_choice',
      );
      final before = (await SharedPreferences.getInstance()).getString(
        WebCdssDatabase.stateKey,
      );
      final captured = await fresh.readFoodCatalogSnapshot();
      expect(captured.holds, isEmpty);
      expect(captured.rows, hasLength(10));
      expect(
        (await SharedPreferences.getInstance()).getString(
          WebCdssDatabase.stateKey,
        ),
        before,
      );
      final mutable = Map<String, Object?>.from(
        (await fresh.queryTable('observation')).first,
      )..['value_num'] = 999;
      expect(
        captured.rows['observation']!.singleWhere(
          (r) => r['observation_id'] == 'a',
        )['value_num'],
        1,
      );
      expect(
        () => captured.rows['observation']!.first['value_num'] = 999,
        throwsUnsupportedError,
      );
      expect(mutable['value_num'], 999);
    },
  );
  final mutations = <String, void Function(Map)>{
    'chosen original amount': (t) => (t['observation'] as List).firstWhere(
      (r) => r['observation_id'] == 'b',
    )['value_num'] = 11,
    'unselected original method': (t) => (t['observation'] as List).firstWhere(
      (r) => r['observation_id'] == 'a',
    )['method_code'] = 'different-method',
    'original source retirement': (t) =>
        (t['source_document'] as List).single['source_status'] = 'retired',
    'original source content': (t) =>
        (t['source_document'] as List).single['raw_payload'] = 'changed source',
    'original scope': (t) =>
        (t['variant_scope'] as List).single['route'] = 'intravenous',
    'decision digest': (t) => (t['conflict_audit_log'] as List).firstWhere(
      (r) => r['audit_type'] == 'IMPORT_CONFLICT_REVIEW_DECISION',
    )['input_hash'] = 'corrupt',
    'receipt disappearance': (t) => (t['conflict_audit_log'] as List)
        .removeWhere((r) => r['audit_type'] == 'REVIEWED_IMPORT_ACTIVATION'),
    'new alternative': (t) {
      final extra = Map<String, dynamic>.from((t['observation'] as List).first)
        ..['observation_id'] = 'c';
      (t['observation'] as List).add(extra);
    },
    'original packet corruption': (t) {
      final row = (t['ingestion_run'] as List).firstWhere(
        (r) => r['status'] == 'held_for_conflict_review',
      );
      final notes = jsonDecode(row['notes_json'] as String) as Map;
      notes['review_evidence']['input_sha256'] = 'corrupt';
      row['notes_json'] = jsonEncode(notes);
    },
  };
  for (final mutation in mutations.entries) {
    test('${mutation.key} withholds arithmetic after fresh read', () async {
      await selected();
      final prefs = await SharedPreferences.getInstance();
      final state =
          jsonDecode(prefs.getString(WebCdssDatabase.stateKey)!) as Map;
      mutation.value(state['tables'] as Map);
      await prefs.setString(WebCdssDatabase.stateKey, jsonEncode(state));
      final before = prefs.getString(WebCdssDatabase.stateKey);
      final result = await CdssCatalogProjectionService(
        database: WebCdssDatabase(),
        requireConsistentCatalog: true,
      ).projectFoodsWithAudit();
      expect(
        result.foods.isEmpty ||
            result.foods.single.isNutrientMissing('proteinG'),
        true,
      );
      await prefs.reload();
      expect(prefs.getString(WebCdssDatabase.stateKey), before);
    });
  }

  for (final mutation in [
    'chosen original amount',
    'original packet corruption',
  ]) {
    test(
      'bootstrap replaces an apparently richer cached value after $mutation',
      () async {
        final db = WebCdssDatabase();
        final cache = CachedFoodDatabase();
        final services = Services.createEphemeral(
          cdssDatabase: db,
          appDatabase: cache,
        );
        await services.ready;
        final held = await prepareOn(db, serviceFor(db));
        final preview = await serviceFor(db).previewReviewedImport(
          heldSnapshotId: held.snapshotId,
          decisionIds: [held.decisionId],
        );
        await activate(serviceFor(db), preview);
        final selected =
            (await services.cdssCatalogProjectionService.projectFoods())
                .singleWhere(
                  (f) =>
                      f.proteinG == 10 &&
                      f.nutrientObservationEvidence.any(
                        (e) => e.observationId == 'b',
                      ),
                );
        cache.cached = [...await cache.loadFoods(), selected];
        final state = AppState(services: services);
        addTearDown(state.dispose);
        await state.bootstrap();
        expect(
          services.foodRepository.allFoods
              .singleWhere((f) => f.id == selected.id)
              .proteinG,
          10,
        );
        final prefs = await SharedPreferences.getInstance();
        final stored =
            jsonDecode(prefs.getString(WebCdssDatabase.stateKey)!) as Map;
        mutations[mutation]!(stored['tables'] as Map);
        await prefs.setString(WebCdssDatabase.stateKey, jsonEncode(stored));
        await state.bootstrap();
        final current = services.foodRepository.allFoods.singleWhere(
          (f) => f.id == selected.id,
        );
        expect(current.isNutrientMissing('proteinG'), true);
        expect(
          current.nutrientObservationEvidence.where(
            (e) => e.selectedForLegacyPointProjection,
          ),
          isEmpty,
        );
        expect(
          foodItemToCandidateFood(current).components.single.proteinGrams,
          isNull,
        );
      },
    );
  }
  test(
    'legacy independent keys never claim a Web common read boundary',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cdss.food_variant', '[]');
      expect(WebCdssDatabase().readFoodCatalogSnapshot(), throwsStateError);
      expect(prefs.getString(WebCdssDatabase.stateKey), isNull);
    },
  );
}
