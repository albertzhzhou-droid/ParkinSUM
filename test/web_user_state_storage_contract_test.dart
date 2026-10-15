import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_web.dart';
import 'package:parkinsum_companion/core/db/web_user_state_store.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'migration witness distinguishes absent, empty and changed legacy values',
    () {
      final original = _snapshot();
      final empty = _snapshot({'db.meals': ''});
      expect(original.digest, isNot(empty.digest));
      expect(
        WebUserStateLegacySnapshot(
          Map.fromEntries(original.values.entries.toList().reversed),
        ).canonicalJson,
        original.canonicalJson,
      );
      expect(
        () => WebUserStateLegacySnapshot({'db.meals': null}),
        throwsArgumentError,
      );
      expect(
        () => original.values['db.meals'] = 'changed',
        throwsUnsupportedError,
      );
    },
  );

  test(
    'existing explicit preferences mock remains the legacy test backend',
    () async {
      final database = WebAppDatabase();
      await database.saveOnboarded(true);
      expect(database.userStateBackendId, contains('explicit test backend'));
      expect(
        (await SharedPreferences.getInstance()).getString('db.user_state.v1'),
        isNotNull,
      );
    },
  );

  test(
    'injected aggregate backend preserves all six original values and restarts',
    () async {
      final originalProfile = UserProfile.defaults().copyWith(
        displayLocale: 'zh-CN',
      );
      SharedPreferences.setMockInitialValues({
        'db.user_profile': jsonEncode(originalProfile.toJson()),
        'db.active_drugs': '["unknown-drug"]',
        'unrelated.original': 'keep this exact value',
      });
      final preferences = await SharedPreferences.getInstance();
      final original = _readSnapshot(preferences);
      final store = _WitnessStore();
      final database = WebAppDatabase(userStateStore: store);
      expect((await database.loadUserProfile()).displayLocale, 'zh-CN');
      await database.saveOnboarded(true);
      await preferences.reload();
      expect(_readSnapshot(preferences).canonicalJson, original.canonicalJson);
      expect(
        preferences.getString('unrelated.original'),
        'keep this exact value',
      );
      expect(
        await WebAppDatabase(userStateStore: store).loadOnboarded(),
        isTrue,
      );
      expect(await database.loadActiveDrugIds(), ['unknown-drug']);
    },
  );

  test(
    'legacy sequential writer refuses read and mutation while retaining both states',
    () async {
      final store = _WitnessStore();
      final database = WebAppDatabase(userStateStore: store);
      await database.saveOnboarded(true);
      final before = store.document;
      final preferences = await SharedPreferences.getInstance();
      const legacy = '{"doNotReplace":"older writer value"}';
      await preferences.setString('db.user_profile', legacy);
      await expectLater(
        database.loadOnboarded(),
        throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
      );
      await expectLater(
        database.saveOnboarded(false),
        throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
      );
      expect(store.document, before);
      expect(preferences.getString('db.user_profile'), legacy);
    },
  );

  test(
    'injected lost acknowledgment is read back without a second publication',
    () async {
      final store = _WitnessStore()..loseAcknowledgment = true;
      final database = WebAppDatabase(userStateStore: store);
      await database.saveOnboarded(true);
      expect(await database.loadOnboarded(), isTrue);
      expect(store.publications, 1);
      expect(
        (await SharedPreferences.getInstance()).getString('db.user_state.v1'),
        isNull,
      );
    },
  );

  test(
    'failure before publication retains old aggregate and next write can proceed',
    () async {
      final store = _WitnessStore();
      final database = WebAppDatabase(userStateStore: store);
      await database.saveOnboarded(true);
      final before = store.document;
      store.rejectPublication = true;
      await expectLater(database.saveOnboarded(false), throwsStateError);
      expect(store.document, before);
      store.rejectPublication = false;
      await database.saveOnboarded(false);
      expect(await database.loadOnboarded(), isFalse);
    },
  );

  test(
    'legacy writer and injected durable store cannot be selected together',
    () {
      expect(
        () => WebAppDatabase(
          userStateStore: _WitnessStore(),
          userStateWriter: (preferences, key, value) =>
              preferences.setString(key, value),
        ),
        throwsArgumentError,
      );
    },
  );

  test('parallel reads and ordered writes share one isolate queue', () async {
    final store = _WitnessStore();
    final database = WebAppDatabase(userStateStore: store);
    await database.saveOnboarded(true);
    final beforeReads = store.readCount;
    store.holdNextRead = true;
    final first = database.loadMeals();
    await store.readEntered.future;
    final second = database.loadIntakes();
    final mutation = database.saveOnboarded(false);
    final after = database.loadOnboarded();
    await Future<void>.delayed(Duration.zero);
    expect(
      store.readCount,
      beforeReads + 1,
      reason: 'Other reads and the mutation must wait for the entered read.',
    );
    store.releaseRead.complete();
    final values = await Future.wait<Object?>([first, second, mutation, after]);
    expect(values[0], isEmpty);
    expect(values[1], isEmpty);
    expect(values[3], isFalse);
    expect(await database.loadOnboarded(), isFalse);
  });
}

WebUserStateLegacySnapshot _snapshot([
  Map<String, String?> replacements = const {},
]) => WebUserStateLegacySnapshot({
  for (final key in webUserStateLegacyKeys) key: replacements[key],
});

WebUserStateLegacySnapshot _readSnapshot(SharedPreferences preferences) =>
    WebUserStateLegacySnapshot({
      for (final key in webUserStateLegacyKeys) key: preferences.getString(key),
    });

/// An independently controlled failure model exercises the database integration.
/// Actual browser transactions and capacity are covered in the separate suite.
final class _WitnessStore implements WebUserStateStore {
  WebUserStateLegacySnapshot? original;
  String? document;
  bool loseAcknowledgment = false;
  bool rejectPublication = false;
  int publications = 0;
  int readCount = 0;
  bool holdNextRead = false;
  final readEntered = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  String get backendId => 'synthetic witness store';

  @override
  Future<String?> read(WebUserStateLegacySnapshot legacy) async {
    readCount += 1;
    if (holdNextRead) {
      holdNextRead = false;
      readEntered.complete();
      await releaseRead.future;
    }
    original ??= legacy;
    if (original!.canonicalJson != legacy.canonicalJson) {
      throw StateError('synthetic_legacy_writer_conflict');
    }
    return document ?? legacy.values['db.user_state.v1'];
  }

  @override
  Future<void> write(
    String next, {
    required String? expectedDocument,
    required WebUserStateLegacySnapshot legacy,
    required bool Function() authorize,
  }) async {
    if (!authorize() ||
        await read(legacy) != expectedDocument ||
        rejectPublication) {
      throw StateError('synthetic_publication_refused');
    }
    document = next;
    publications += 1;
    if (loseAcknowledgment) throw StateError('synthetic_lost_acknowledgment');
  }
}
