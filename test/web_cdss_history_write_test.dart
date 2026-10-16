import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/constants/p0_food_source_seed.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';

const rule = {
  'rule_id': 'synthetic-rule',
  'rule_version': 'v1',
  'compiled_hash': 'synthetic-hash',
  'updated_at': 0,
  'effect_json': 'review',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'identical fact/rule seed on a new graph preserves history verbatim',
    () async {
      final fact = buildP0FoodKnowledgeBaseSeed().resolvedFacts.first;
      final db = WebCdssDatabase();
      await db.initialize();
      await db.insertResolvedFact(fact);
      await db.insertRuleRegistry(rule);
      final before = await db.queryTable('cdss_record_history');
      final fresh = WebCdssDatabase();
      await fresh.initialize();
      await fresh.insertResolvedFact(fact);
      await fresh.insertRuleRegistry(rule);
      expect(await fresh.queryTable('cdss_record_history'), before);
      expect(before, hasLength(2));
    },
  );
  test(
    'changed content at the same version retains and retires old history',
    () async {
      final db = WebCdssDatabase();
      await db.initialize();
      await db.insertRuleRegistry(rule);
      final first = (await db.queryTable('cdss_record_history')).single;
      await db.insertRuleRegistry({...rule, 'effect_json': 'hold'});
      final history = await db.queryTable('cdss_record_history');
      expect(history, hasLength(2));
      expect(history.first['payload_json'], first['payload_json']);
      expect(history.first['retired_at'], isNotNull);
      expect(history.first['superseded_by'], history.last['history_id']);
      expect(history.last['history_id'], isNot(first['history_id']));
      expect(
        (await db.queryTable('rule_registry')).single['effect_json'],
        'hold',
      );
    },
  );
  test(
    'key order is immaterial but explicit provenance changes are retained',
    () async {
      final db = WebCdssDatabase();
      await db.initialize();
      await db.insertRuleRegistry(rule);
      await db.insertRuleRegistry(
        Map.fromEntries(rule.entries.toList().reversed),
      );
      expect(await db.queryTable('cdss_record_history'), hasLength(1));
      await db.insertRuleRegistry({
        ...rule,
        'import_run_id': 'new-source-acquisition',
      });
      expect(await db.queryTable('cdss_record_history'), hasLength(2));
    },
  );
  test(
    'concurrent different graphs retain every history and current record',
    () async {
      final dbs = [WebCdssDatabase(), WebCdssDatabase()];
      await Future.wait(dbs.map((d) => d.initialize()));
      await Future.wait([
        for (var i = 0; i < 4; i++)
          dbs[i % 2].insertRuleRegistry({
            ...rule,
            'rule_id': 'synthetic-concurrent-$i',
          }),
      ]);
      expect(await dbs.first.queryTable('rule_registry'), hasLength(4));
      final history = await dbs.first.queryTable('cdss_record_history');
      expect(history, hasLength(4));
      expect(history.map((r) => r['record_id']).toSet(), hasLength(4));
    },
  );
  test(
    'concurrent revisions of one record preserve both with one current row',
    () async {
      final a = WebCdssDatabase(), b = WebCdssDatabase();
      await a.initialize();
      await Future.wait([
        a.insertRuleRegistry(rule),
        b.insertRuleRegistry({...rule, 'effect_json': 'hold'}),
      ]);
      expect(await a.queryTable('rule_registry'), hasLength(1));
      final history = await a.queryTable('cdss_record_history');
      expect(history, hasLength(2));
      expect(history.where((r) => r['retired_at'] == null), hasLength(1));
    },
  );
  test(
    'a rejected write does not poison the queue or erase existing history',
    () async {
      final db = WebCdssDatabase();
      await db.initialize();
      await db.insertRuleRegistry(rule);
      final prefs = await SharedPreferences.getInstance();
      final rows = await db.queryTable('cdss_record_history');
      rows.single['payload_json'] = 'invalid JSON';
      final state =
          jsonDecode(prefs.getString(WebCdssDatabase.stateKey)!) as Map;
      (state['tables'] as Map)['cdss_record_history'] = rows;
      await prefs.setString(WebCdssDatabase.stateKey, jsonEncode(state));
      await expectLater(db.insertRuleRegistry(rule), throwsFormatException);
      await db.insertRuleRegistry({...rule, 'rule_id': 'unrelated-valid'});
      final history = await db.queryTable('cdss_record_history');
      expect(history, hasLength(2));
      expect(history.first['payload_json'], 'invalid JSON');
    },
  );
  test(
    'rapid same-version revisions receive distinct opaque history IDs',
    () async {
      final db = WebCdssDatabase();
      await db.initialize();
      for (var i = 0; i < 40; i++) {
        await db.insertRuleRegistry({...rule, 'effect_json': 'revision-$i'});
      }
      final history = await db.queryTable('cdss_record_history');
      expect(history, hasLength(40));
      expect(history.map((r) => r['history_id']).toSet(), hasLength(40));
      expect(history.where((r) => r['retired_at'] == null), hasLength(1));
    },
  );
}
