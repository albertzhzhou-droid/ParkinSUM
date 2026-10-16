import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database_memory.dart';
import 'package:parkinsum_companion/core/db/cdss_catalog_snapshot_reader.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_recommendation_models.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';

Map<String, List<Map<String, Object?>>> rows(String revision) => {
  for (final table in CdssCatalogTableSnapshot.tables) table: [],
  'food_concept': [
    {'food_concept_id': 'concept', 'canonical_name_en': revision},
  ],
  'food_variant': [
    {
      'food_variant_id': 'variant',
      'food_concept_id': 'concept',
      'source_family': 'SYNTHETIC',
      'status': 'active',
      'display_name_local': revision,
    },
  ],
  'source_document': [
    {
      'source_doc_id': 'source_$revision',
      'source_family': 'SYNTHETIC',
      'source_status': 'active',
      'raw_payload': revision,
    },
  ],
  'observation': [
    {
      'observation_id': 'obs',
      'domain': 'food',
      'entity_key': 'variant',
      'attribute_code': 'protein_g',
      'qualifier_kind': 'exact',
      'value_num': revision == 'old' ? 10.0 : 20.0,
      'source_doc_id': 'source_$revision',
      'unit': 'g',
      'basis_type': 'per_100g',
      'basis_amount': 100,
    },
  ],
};

class _Reader extends InMemoryCdssDatabase
    implements CdssCatalogSnapshotReader {
  _Reader(this.content);
  Map<String, List<Map<String, Object?>>> content;
  int atomicReads = 0;
  int sequentialReads = 0;
  @override
  Future<CdssCatalogTableSnapshot> readFoodCatalogSnapshot() async {
    atomicReads++;
    final captured = CdssCatalogTableSnapshot(
      rows: content,
      consistency: 'native_sqlite_transaction',
    );
    // Model a publication immediately after the transaction ended.
    content = rows('new');
    return captured;
  }

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async {
    sequentialReads++;
    throw StateError('Strict projection must never re-read a live table.');
  }
}

void main() {
  test(
    'strict HOLD cannot re-enter scoring through legacy caller repository',
    () async {
      final result =
          await NextMealRecommendationOrchestrator(
            conservativeRecommender: GetFoodRecommendationsUseCase(),
            projectionService: CdssCatalogProjectionService(
              database: InMemoryCdssDatabase(),
              requireConsistentCatalog: true,
            ),
            localAiAdapter: null,
          ).recommend(
            request: NextMealRecommendationRequest(
              userProfile: UserProfile.defaults(),
              history: const [],
              activeDrugs: const [],
              now: DateTime.utc(2026, 9, 30),
              mode: RecommendationMode.conservativeOnly,
            ),
            candidateFoods: [
              FoodItem(
                id: 'unfrozen_import',
                name: 'Unfrozen imported row',
                category: FoodCategory.other,
                proteinG: 999,
                carbsG: 0,
                fatG: 0,
                fiberG: 0,
                sodiumMg: 0,
                sourceSystem: 'SYNTHETIC_IMPORT',
                jurisdiction: 'US',
              ),
            ],
          );
      final payload =
          jsonDecode(result.candidateSetSnapshot.canonicalJson) as Map;
      expect(
        payload['merged_ordered_candidate_ids'],
        isNot(contains('unfrozen_import')),
      );
      expect(payload['built_in_p0_fallback_used'], isTrue);
      expect(
        (payload['candidate_input_boundary'] as Map)['caller_input_used'],
        isFalse,
      );
    },
  );
  test(
    'old/new complete snapshots, replay digest and no post-snapshot reads',
    () async {
      final db = _Reader(rows('old'));
      final projector = CdssCatalogProjectionService(
        database: db,
        requireConsistentCatalog: true,
      );
      final old = await projector.projectFoodsWithAudit();
      final next = await projector.projectFoodsWithAudit();
      expect(old.foods.single.proteinG, 10);
      expect(next.foods.single.proteinG, 20);
      expect(db.atomicReads, 2);
      expect(db.sequentialReads, 0);
      final replay = await CdssCatalogProjectionService(
        database: _Reader(rows('old')),
        requireConsistentCatalog: true,
      ).projectFoodsWithAudit();
      expect(jsonEncode(replay.queryAudit), jsonEncode(old.queryAudit));
      expect(
        old.queryAudit['catalog_snapshot'],
        isNot(next.queryAudit['catalog_snapshot']),
      );
    },
  );
  test(
    'missing variant lifecycle withholds points and retains observations',
    () async {
      final content = rows('old');
      content['food_variant']!.single.remove('status');
      final result = await CdssCatalogProjectionService(
        database: _Reader(content),
        requireConsistentCatalog: true,
      ).projectFoodsWithAudit();
      final food = result.foods.single;
      expect(food.missingNutrientFields, contains('proteinG'));
      expect(food.nutrientObservationEvidence.single.valueNum, 10);
      expect(
        food
            .nutrientObservationEvidence
            .single
            .selectedForLegacyPointProjection,
        isFalse,
      );
      expect(content['food_variant']!.single.containsKey('status'), isFalse);
    },
  );
  test('unsupported reader holds the whole imported candidate set', () async {
    final result = await CdssCatalogProjectionService(
      database: InMemoryCdssDatabase(),
      requireConsistentCatalog: true,
    ).projectFoodsWithAudit();
    expect(result.foods, isEmpty);
    expect(result.queryAudit['status'], 'HOLD');
    expect(result.queryAudit['reason'], 'atomic_catalog_reader_unavailable');
  });
  test(
    'dangling source/concept/scope/crosswalk never emit partial candidates',
    () async {
      for (final mutation in [
        (Map<String, List<Map<String, Object?>>> x) =>
            x['source_document']!.clear(),
        (Map<String, List<Map<String, Object?>>> x) =>
            x['food_concept']!.clear(),
        (Map<String, List<Map<String, Object?>>> x) =>
            x['observation']!.single['scope_hash'] = 'missing',
        (Map<String, List<Map<String, Object?>>> x) =>
            x['concept_variant_crosswalk']!.add({
              'crosswalk_id': 'link',
              'domain': 'food',
              'concept_id': 'concept',
              'variant_id': 'missing',
              'source_doc_id': 'source_old',
            }),
      ]) {
        final content = rows('old');
        mutation(content);
        final result = await CdssCatalogProjectionService(
          database: _Reader(content),
          requireConsistentCatalog: true,
        ).projectFoodsWithAudit();
        expect(result.foods, isEmpty);
        expect(result.queryAudit['status'], 'HOLD');
      }
    },
  );
  test('partial import is held until the exact completed promotion marker', () {
    final content = rows('old');
    content['ingestion_run']!.add({
      'run_id': 'run',
      'status': 'running',
      'snapshot_id': 'stage',
    });
    expect(
      CdssCatalogTableSnapshot(
        rows: content,
        consistency: 'native_sqlite_transaction',
      ).holds,
      contains('incomplete_promotion'),
    );
    content['ingestion_run']!.add({
      'run_id': 'run_promote',
      'status': 'completed',
      'snapshot_id': 'published',
      'notes_json': jsonEncode({'staging_snapshot_id': 'stage'}),
    });
    expect(
      CdssCatalogTableSnapshot(
        rows: content,
        consistency: 'native_sqlite_transaction',
      ).holds,
      contains('incomplete_promotion'),
    );
    content['engine_snapshot']!.add({
      'snapshot_id': 'published',
      'promoted_at': 123,
    });
    expect(
      CdssCatalogTableSnapshot(
        rows: content,
        consistency: 'native_sqlite_transaction',
      ).holds,
      isEmpty,
    );
  });
  test(
    'snapshot is deeply immutable and cannot be relabelled by source mutation',
    () {
      final input = rows('old');
      final snapshot = CdssCatalogTableSnapshot(
        rows: input,
        consistency: 'native_sqlite_transaction',
      );
      final before = snapshot.toAuditJson();
      input['food_variant']!.single['display_name_local'] = 'changed';
      expect(snapshot.toAuditJson(), before);
      expect(
        () => snapshot.rows['observation']!.single['value_num'] = 999,
        throwsUnsupportedError,
      );
      expect(
        CdssCatalogTableSnapshot(
          rows: input,
          consistency: 'two_sequential_reads',
        ).holds,
        contains('unverified_transaction_boundary'),
      );
    },
  );
  test(
    'non-finite snapshot values hold instead of yielding unbound candidates',
    () async {
      final content = rows('old');
      content['observation']!.single['value_num'] = double.nan;
      final result = await CdssCatalogProjectionService(
        database: _Reader(content),
        requireConsistentCatalog: true,
      ).projectFoodsWithAudit();
      expect(result.foods, isEmpty);
      expect(result.queryAudit['reason'], 'catalog_snapshot_read_failed');
    },
  );
}
