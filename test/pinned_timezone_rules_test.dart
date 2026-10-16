import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/pinned_timezone_rules_service.dart';
import 'package:parkinsum_companion/domain/entities/local_time_resolution.dart';
import 'package:parkinsum_companion/domain/entities/personal_log_view.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_date_window_resolver.dart';
import 'package:parkinsum_companion/domain/usecases/pinned_timezone_rules.dart';
import 'package:parkinsum_companion/domain/usecases/timezone_local_time_resolver.dart';
import 'package:timezone/data/latest_all.dart' as historical_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = File(pinnedTimezoneAssetPath).readAsBytesSync();
  final rules = PinnedTimezoneRules.fromBytes(bytes);

  test(
    'bundled actual bytes load with exact source and bounded interval',
    () async {
      final bundled = await rootBundle.load(pinnedTimezoneAssetPath);
      final loaded = PinnedTimezoneRules.fromBytes(
        bundled.buffer.asUint8List(
          bundled.offsetInBytes,
          bundled.lengthInBytes,
        ),
      );
      expect(loaded.snapshot.tzdbRelease, '2026e');
      expect(
        loaded.snapshot.providerIdentity,
        contains(pinnedTimezoneAssetSha256),
      );
      expect(
        loaded.snapshot.providerIdentity,
        contains(pinnedTimezoneSourceArchiveSha256),
      );
      expect(loaded.snapshot.database.locations.length, 597);
      expect(loaded.snapshot.supportsInstant(DateTime.utc(1900)), isTrue);
      expect(loaded.snapshot.supportsInstant(DateTime.utc(2100)), isFalse);
    },
  );

  test(
    'corrupt or truncated bytes never receive the current release label',
    () {
      final corrupt = List<int>.of(bytes)..[100] ^= 1;
      expect(
        () => PinnedTimezoneRules.fromBytes(corrupt),
        throwsFormatException,
      );
      expect(
        () => PinnedTimezoneRules.fromBytes(bytes.take(100).toList()),
        throwsFormatException,
      );
    },
  );

  test('snapshot zone map and actual transition arrays cannot be changed', () {
    final database = rules.snapshot.database;
    final zone = database.get('America/Toronto');
    expect(() => database.clear(), throwsUnsupportedError);
    expect(() => database.add(zone), throwsUnsupportedError);
    expect(() => database.locations.clear(), throwsUnsupportedError);
    expect(() => zone.transitionAt[0] = 0, throwsUnsupportedError);
    expect(() => zone.transitionZone[0] = 0, throwsUnsupportedError);
    expect(() => zone.zones.clear(), throwsUnsupportedError);
  });

  test(
    'another package-global database cannot relabel the immutable snapshot',
    () {
      historical_data.initializeTimeZones();
      final evidence = _resolve(
        rules.snapshot,
        'America/Winnipeg',
        [2026, 11, 1, 1, 30],
        -300,
        LocalTimeFoldChoice.reject,
      );
      expect(evidence.foldWasAmbiguous, isFalse);
      expect(evidence.resolvedAtUtc, DateTime.utc(2026, 11, 1, 6, 30));
      expect(
        tz
            .getLocation('America/Winnipeg')
            .timeZone(DateTime.utc(2026, 11, 1, 8).millisecondsSinceEpoch)
            .offset
            .inMinutes,
        -360,
      );
    },
  );

  final domain =
      jsonDecode(
            File(
              'test/fixtures/timezone_research/manual_expected_before_compilation.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final raw in domain['rows'] as List<dynamic>) {
    final row = raw as Map<String, dynamic>;
    test('source-derived current civil expectation: ${row['id']}', () {
      final expected =
          (row['expected'] as Map<String, dynamic>)['2026e']
              as Map<String, dynamic>;
      LocalTimeResolutionEvidence run() => _resolve(
        rules.snapshot,
        row['zone'] as String,
        (row['civil'] as List<dynamic>).cast<int>(),
        row['offset_minutes'] as int,
        LocalTimeFoldChoice.values.byName(row['fold_choice'] as String),
      );
      if (expected['accepted'] != true) {
        expect(run, throwsFormatException);
      } else {
        final evidence = run();
        expect(evidence.resolvedAtUtc.toIso8601String(), expected['utc']);
        expect(evidence.foldWasAmbiguous, expected['ambiguous']);
        expect(
          LocalTimeResolutionEvidence.fromJson(evidence.toJson()).toJson(),
          evidence.toJson(),
        );
      }
    });
  }

  test(
    'historical2025c receipt retains its civil intent and whole JSON after upgrade',
    () {
      historical_data.initializeTimeZones();
      final old = TimezoneRuleSnapshot(
        database: tz.timeZoneDatabase,
        tzdbRelease: '2025c',
        providerIdentity: 'timezone/0.11.1:data/latest_all',
      );
      final evidence = _resolve(
        old,
        'America/Winnipeg',
        [2026, 11, 1, 1, 30],
        -360,
        LocalTimeFoldChoice.later,
      );
      final original = jsonEncode(evidence.toJson());
      rules.initializeGlobalDatabase();
      final display = tz.TZDateTime.from(
        evidence.resolvedAtUtc,
        tz.getLocation('America/Winnipeg'),
      );
      expect(display.hour, 2);
      expect(display.minute, 30);
      expect(evidence.offsetTimestamp, '2026-11-01T01:30:00.000-06:00');
      expect(jsonEncode(evidence.toJson()), original);
      expect(
        jsonEncode(
          LocalTimeResolutionEvidence.fromJson(
            jsonDecode(original) as Map<String, dynamic>,
          ).toJson(),
        ),
        original,
      );
    },
  );

  test(
    'pinned resolver refuses unsupported UTC instants instead of extrapolating',
    () {
      for (final civil in [
        [1899, 12, 31, 23, 59],
        [2100, 1, 1, 0, 0],
      ]) {
        expect(
          () => _resolve(
            rules.snapshot,
            'Etc/UTC',
            civil,
            0,
            LocalTimeFoldChoice.reject,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => TimezoneRuleSnapshot(
          database: rules.snapshot.database,
          tzdbRelease: '2026e',
          providerIdentity: 'test',
          supportedStartUtc: DateTime.utc(1900),
        ),
        throwsArgumentError,
      );
    },
  );

  test('current explicit calendar windows preserve23/25/24hour rule days', () {
    final calendar = PersonalLogDateWindowResolver(
      ruleSnapshot: rules.snapshot,
    );
    for (final row in <(String, LogCivilDate, int)>[
      ('America/Toronto', LogCivilDate(2026, 3, 8), 23),
      ('America/Toronto', LogCivilDate(2026, 11, 1), 25),
      ('America/Winnipeg', LogCivilDate(2026, 11, 1), 24),
      ('America/Vancouver', LogCivilDate(2026, 11, 1), 24),
      ('Australia/Sydney', LogCivilDate(2026, 4, 5), 25),
    ]) {
      final window = calendar.resolve(
        PersonalLogDateWindow(
          start: row.$2,
          endInclusive: row.$2,
          zoneId: row.$1,
        ),
        asOf: DateTime.utc(2026, 12),
      );
      expect(
        window.endUtcExclusive.difference(window.startUtc).inHours,
        row.$3,
      );
    }
    expect(
      () => calendar.displayTime(DateTime.utc(2100), 'Etc/UTC'),
      throwsFormatException,
    );
    expect(
      () => calendar.resolve(
        PersonalLogDateWindow(
          start: LogCivilDate(2100, 1, 1),
          endInclusive: LogCivilDate(2100, 1, 1),
          zoneId: 'Etc/UTC',
        ),
        asOf: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
  });

  test(
    'zone change alters display and injected clock rollback only changes future classification',
    () {
      final calendar = PersonalLogDateWindowResolver(
        ruleSnapshot: rules.snapshot,
      );
      final instant = DateTime.utc(2026, 11, 1, 7, 30);
      final recorded = jsonEncode({
        'id': 'synthetic_time_record',
        'utc': instant.toIso8601String(),
        'original_zone': null,
      });
      final a = calendar.displayTime(instant, 'America/Winnipeg');
      final b = calendar.displayTime(instant, 'America/Toronto');
      expect(a.hour, 2);
      expect(b.hour, 2);
      expect(a.minute, 30);
      expect(b.minute, 30);
      final c = calendar.displayTime(instant, 'America/Vancouver');
      expect(c.day, 1);
      expect(c.hour, 0);
      expect(c.minute, 30);
      expect(a.toUtc(), instant);
      expect(b.toUtc(), instant);
      expect(c.toUtc(), instant);
      final selection = PersonalLogDateWindow(
        start: LogCivilDate(2026, 11, 1),
        endInclusive: LogCivilDate(2026, 11, 1),
        zoneId: 'America/Winnipeg',
      );
      final before = calendar.resolve(
        selection,
        asOf: DateTime.utc(2026, 11, 2),
      );
      final rolledBack = calendar.resolve(
        selection,
        asOf: DateTime.utc(2026, 10, 31),
      );
      expect(before.startUtc, rolledBack.startUtc);
      expect(before.endUtcExclusive, rolledBack.endUtcExclusive);
      expect(before.isFuture(instant), isFalse);
      expect(rolledBack.isFuture(instant), isTrue);
      expect(
        recorded,
        jsonEncode({
          'id': 'synthetic_time_record',
          'utc': instant.toIso8601String(),
          'original_zone': null,
        }),
      );
    },
  );

  test('concurrent loads share one real verified result', () async {
    final delayed = Completer<List<int>>();
    var calls = 0;
    final service = PinnedTimezoneRulesService(
      loadBytes: () {
        calls++;
        return delayed.future;
      },
    );
    final first = service.load(), second = service.load();
    expect(first, same(second));
    expect(calls, 1);
    delayed.complete(bytes);
    expect(await first, same(await second));
    expect(await service.load(), same(service.loaded));
    expect(calls, 1);
  });

  test(
    'failed load does not poison retry or silently use older rules',
    () async {
      var calls = 0;
      final service = PinnedTimezoneRulesService(
        loadBytes: () async => ++calls == 1 ? [0] : bytes,
      );
      await expectLater(service.load(), throwsFormatException);
      expect(service.loaded, isNull);
      final loaded = await service.load();
      expect(loaded.snapshot.tzdbRelease, '2026e');
      expect(calls, 2);
    },
  );

  test(
    'resolver uses explicit civil components independent of host local zone',
    () {
      tz.setLocalLocation(rules.snapshot.database.get('Australia/Sydney'));
      final evidence = _resolve(
        rules.snapshot,
        'America/Toronto',
        [2026, 1, 15, 12, 30],
        -300,
        LocalTimeFoldChoice.reject,
      );
      expect(evidence.resolvedAtUtc, DateTime.utc(2026, 1, 15, 17, 30));
      expect(evidence.localCivilTime.hour, 12);
    },
  );
}

LocalTimeResolutionEvidence _resolve(
  TimezoneRuleSnapshot snapshot,
  String zone,
  List<int> civil,
  int offset,
  LocalTimeFoldChoice choice,
) => const TimezoneLocalTimeResolver().resolve(
  localCivilTime: LocalCivilDateTime(
    year: civil[0],
    month: civil[1],
    day: civil[2],
    hour: civil[3],
    minute: civil[4],
    second: 0,
  ),
  ianaZoneId: zone,
  utcOffsetMinutes: offset,
  foldChoice: choice,
  snapshot: snapshot,
);
