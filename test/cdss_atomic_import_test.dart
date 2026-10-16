import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';

import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';

import 'held_import_review_evidence_test.dart'
    show serviceFor, conflictingBundle;

class FailOnConceptWrite extends WebCdssDatabase {
  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {
    throw StateError('Synthetic backend failure before concept write');
  }
}

const before = CountryDietProfileRecord(
  countryCode: 'US',
  guidelineSource: 'original-active-source',
  mealPatternJson: '{"value":"original"}',
  stapleFoodsJson: '[]',
  preferredProteinSourcesJson: '[]',
  avoidanceNotesJson: '[]',
);
const attempted = CountryDietProfileRecord(
  countryCode: 'US',
  guidelineSource: 'new-candidate-source',
  mealPatternJson: '{"value":"attempted"}',
  stapleFoodsJson: '[]',
  preferredProteinSourcesJson: '[]',
  avoidanceNotesJson: '[]',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'a failed import preserves every active catalogue row on fresh load',
    () async {
      final database = FailOnConceptWrite();
      await database.insertCountryDietProfile(before);
      await database.insertEngineSnapshot(
        EngineSnapshotRecord(
          snapshotId: 'active_before_failure',
          factsVersion: 'original-facts',
          rulesVersion: 'original-rules',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          promotedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          rollbackParent: null,
          inputHash: 'original-input',
        ),
      );
      final original = await database.queryTable('country_diet_profile');
      await expectLater(
        serviceFor(database).importBundle(
          const P0ImportBundle(
            countryDietProfiles: [attempted],
            foodConcepts: [
              FoodConceptRecord(
                foodConceptId: 'new-concept',
                canonicalNameEn: 'Candidate concept',
                canonicalNameZh: '合成候选',
                foodGroup: 'other',
              ),
            ],
          ),
        ),
        throwsStateError,
      );
      final reopened = WebCdssDatabase();
      expect(
        (await serviceFor(reopened).latestPromotedSnapshot())?.snapshotId,
        'active_before_failure',
      );
      expect(await reopened.queryTable('country_diet_profile'), original);
      expect(await reopened.queryTable('food_concept'), isEmpty);
    },
  );

  test(
    'one complete commit includes live rows, history and activation markers',
    () async {
      final writes = <String>[];
      final db = WebCdssDatabase(
        stateWriter: (prefs, key, value) async {
          writes.add(key);
          return prefs.setString(key, value);
        },
      );
      await db.insertCountryDietProfile(before);
      writes.clear();
      final report = await serviceFor(db).importBundle(
        const P0ImportBundle(
          countryDietProfiles: [attempted],
          foodConcepts: [
            FoodConceptRecord(
              foodConceptId: 'new',
              canonicalNameEn: 'New',
              canonicalNameZh: '新',
              foodGroup: 'other',
            ),
          ],
        ),
      );
      expect(writes, [WebCdssDatabase.stateKey]);
      final fresh = WebCdssDatabase();
      expect(
        (await fresh.queryTable(
          'country_diet_profile',
        )).single['guideline_source'],
        attempted.guidelineSource,
      );
      expect(
        (await fresh.queryTable('food_concept')).single['food_concept_id'],
        'new',
      );
      expect(
        (await serviceFor(fresh).latestPromotedSnapshot())?.snapshotId,
        report.promotedSnapshotId,
      );
      expect(await fresh.queryTable('cdss_record_history'), isNotEmpty);
      expect(await fresh.queryTable('staging_food_variant'), isEmpty);
    },
  );

  test(
    'pending changes remain invisible and another graph retains its later write',
    () async {
      final db = WebCdssDatabase();
      await db.insertCountryDietProfile(before);
      final entered = Completer<void>(), release = Completer<void>();
      final pending = db.runAtomicWrite(() async {
        await db.insertCountryDietProfile(attempted);
        expect(
          (await db.queryTable(
            'country_diet_profile',
          )).single['guideline_source'],
          attempted.guidelineSource,
        );
        entered.complete();
        await release.future;
      });
      await entered.future;
      final other = WebCdssDatabase();
      expect(
        (await other.queryTable(
          'country_diet_profile',
        )).single['guideline_source'],
        before.guidelineSource,
      );
      final later = other.insertFoodConcept(
        const FoodConceptRecord(
          foodConceptId: 'later',
          canonicalNameEn: 'Later',
          canonicalNameZh: '后',
          foodGroup: 'other',
        ),
      );
      release.complete();
      await pending;
      await later;
      expect(
        (await db.queryTable('food_concept')).single['food_concept_id'],
        'later',
      );
      expect(
        (await other.queryTable(
          'country_diet_profile',
        )).single['guideline_source'],
        attempted.guidelineSource,
      );
    },
  );

  for (final failure in ['return_false', 'throw_before_write']) {
    test(
      'a rejected complete-document write preserves every table: $failure',
      () async {
        final seeded = WebCdssDatabase();
        await seeded.insertCountryDietProfile(before);
        await seeded.insertRuleRegistry({
          'rule_id': 'old',
          'rule_version': 'original',
          'effect_json': 'old',
        });
        final prefs = await SharedPreferences.getInstance();
        final original = prefs.getString(WebCdssDatabase.stateKey);
        final db = WebCdssDatabase(
          stateWriter: (_, _, _) async {
            if (failure == 'return_false') return false;
            throw StateError('Synthetic quota failure');
          },
        );
        await expectLater(
          serviceFor(db).importBundle(
            const P0ImportBundle(countryDietProfiles: [attempted]),
          ),
          throwsStateError,
        );
        await prefs.reload();
        expect(prefs.getString(WebCdssDatabase.stateKey), original);
        expect(
          (await WebCdssDatabase().queryTable(
            'country_diet_profile',
          )).single['guideline_source'],
          before.guidelineSource,
        );
        expect(await WebCdssDatabase().queryTable('ingestion_run'), isEmpty);
      },
    );
  }

  test(
    'an exact persisted document recovers a lost acknowledgment without duplicate import',
    () async {
      var writes = 0;
      final db = WebCdssDatabase(
        stateWriter: (prefs, key, value) async {
          writes += 1;
          await prefs.setString(key, value);
          throw StateError('Synthetic lost acknowledgment after commit');
        },
      );
      final report = await serviceFor(
        db,
      ).importBundle(const P0ImportBundle(countryDietProfiles: [attempted]));
      expect(writes, 1);
      final fresh = WebCdssDatabase();
      expect(
        (await serviceFor(fresh).latestPromotedSnapshot())?.snapshotId,
        report.promotedSnapshotId,
      );
      expect(await fresh.queryTable('engine_snapshot'), hasLength(2));
      expect(await fresh.queryTable('ingestion_run'), hasLength(2));
    },
  );

  test(
    'a caught nested failure still aborts the complete pending state',
    () async {
      final db = WebCdssDatabase();
      await db.insertCountryDietProfile(before);
      await expectLater(
        db.runAtomicWrite(() async {
          await db.insertCountryDietProfile(attempted);
          try {
            await db.runAtomicWrite<void>(
              () async => throw StateError('Synthetic nested failure'),
            );
          } on StateError {
            // Caller handling cannot promote earlier partial mutations.
          }
        }),
        throwsStateError,
      );
      expect(
        (await WebCdssDatabase().queryTable(
          'country_diet_profile',
        )).single['guideline_source'],
        before.guidelineSource,
      );
    },
  );

  test(
    'an awaited child cannot write through an already closed transaction zone',
    () async {
      final db = WebCdssDatabase();
      await db.insertCountryDietProfile(before);
      final release = Completer<void>();
      late Future<void> lateWrite;
      await db.runAtomicWrite(() async {
        lateWrite = release.future.then(
          (_) => db.insertCountryDietProfile(attempted),
        );
      });
      final assertion = expectLater(lateWrite, throwsStateError);
      release.complete();
      await assertion;
      expect(
        (await WebCdssDatabase().queryTable(
          'country_diet_profile',
        )).single['guideline_source'],
        before.guidelineSource,
      );
    },
  );

  test(
    'legacy migration preserves original keys, arbitrary table rows and history',
    () async {
      final legacy = {
        'cdss.country_diet_profile': jsonEncode([
          {
            'country_code': 'US',
            'guideline_source': 'legacy-original',
            'meal_pattern_json': '[]',
            'staple_foods_json': '[]',
            'preferred_protein_sources_json': '[]',
            'avoidance_notes_json': '[]',
          },
        ]),
        'cdss.unlisted_source_evidence': '[{"original":"retained"}]',
        'cdss.cdss_record_history':
            '[{"history_id":"original-history","payload_json":"original text"}]',
      };
      SharedPreferences.setMockInitialValues(legacy);
      final db = WebCdssDatabase();
      await db.initialize();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(WebCdssDatabase.stateKey), isNull);
      await db.insertFoodConcept(
        const FoodConceptRecord(
          foodConceptId: 'new',
          canonicalNameEn: 'New',
          canonicalNameZh: '新',
          foodGroup: 'other',
        ),
      );
      for (final entry in legacy.entries) {
        expect(prefs.getString(entry.key), entry.value);
      }
      final fresh = WebCdssDatabase();
      expect(
        (await fresh.queryTable(
          'country_diet_profile',
        )).single['guideline_source'],
        'legacy-original',
      );
      expect(await fresh.queryTable('unlisted_source_evidence'), [
        {'original': 'retained'},
      ]);
      expect(await fresh.queryTable('cdss_record_history'), [
        {'history_id': 'original-history', 'payload_json': 'original text'},
      ]);
    },
  );

  test(
    'a changed committed document aborts promotion and preserves the newer writer',
    () async {
      final db = WebCdssDatabase();
      await db.insertCountryDietProfile(before);
      final prefs = await SharedPreferences.getInstance();
      final external =
          jsonDecode(prefs.getString(WebCdssDatabase.stateKey)!) as Map;
      external['revision'] = (external['revision'] as int) + 1;
      ((external['tables'] as Map)['food_concept'] as List).add({
        'food_concept_id': 'external-original',
      });
      final externalBytes = jsonEncode(external);
      await expectLater(
        db.runAtomicWrite(() async {
          await db.insertCountryDietProfile(attempted);
          await prefs.setString(WebCdssDatabase.stateKey, externalBytes);
        }),
        throwsStateError,
      );
      await prefs.reload();
      expect(prefs.getString(WebCdssDatabase.stateKey), externalBytes);
      expect(
        (await WebCdssDatabase().queryTable(
          'country_diet_profile',
        )).single['guideline_source'],
        before.guidelineSource,
      );
    },
  );

  test(
    'changed legacy input aborts migration and preserves both original and later rows',
    () async {
      const original = '[{"country_code":"US","guideline_source":"original"}]';
      SharedPreferences.setMockInitialValues({
        'cdss.country_diet_profile': original,
      });
      final db = WebCdssDatabase();
      final prefs = await SharedPreferences.getInstance();
      await expectLater(
        db.runAtomicWrite(() async {
          await db.insertCountryDietProfile(attempted);
          await prefs.setString(
            'cdss.food_concept',
            '[{"food_concept_id":"external-legacy"}]',
          );
        }),
        throwsStateError,
      );
      await prefs.reload();
      expect(prefs.getString(WebCdssDatabase.stateKey), isNull);
      expect(prefs.getString('cdss.country_diet_profile'), original);
      expect(
        (await WebCdssDatabase().queryTable(
          'food_concept',
        )).single['food_concept_id'],
        'external-legacy',
      );
    },
  );

  test(
    'an incomplete active document rejects reads and writes without falling back to stale legacy data',
    () async {
      const malformed =
          '{"schema":"parkinsum.cdss-web-state/1","revision":1,"tables":{}}';
      SharedPreferences.setMockInitialValues({
        WebCdssDatabase.stateKey: malformed,
        'cdss.country_diet_profile':
            '[{"country_code":"US","guideline_source":"stale"}]',
      });
      final db = WebCdssDatabase();
      await expectLater(
        db.queryTable('country_diet_profile'),
        throwsFormatException,
      );
      await expectLater(
        db.insertCountryDietProfile(attempted),
        throwsFormatException,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getString(WebCdssDatabase.stateKey), malformed);
    },
  );

  test(
    'a deliberate conflict hold commits its packet and no live source rows',
    () async {
      final db = WebCdssDatabase();
      await expectLater(
        serviceFor(db).importBundle(conflictingBundle()),
        throwsA(isA<CdssImportHeldException>()),
      );
      final fresh = WebCdssDatabase();
      final hold = (await fresh.queryTable(
        'ingestion_run',
      )).singleWhere((r) => r['status'] == 'held_for_conflict_review');
      final packet = await serviceFor(
        fresh,
      ).loadHeldImportReviewEvidence(snapshotId: hold['snapshot_id'] as String);
      expect(packet['schema'], 'parkinsum.held-import-review-evidence/2');
      expect(await fresh.queryTable('source_document'), isEmpty);
      expect(await fresh.queryTable('observation'), isEmpty);
      expect(await fresh.queryTable('staging_observation'), hasLength(2));
      expect(await serviceFor(fresh).latestPromotedSnapshot(), isNull);
    },
  );
}
