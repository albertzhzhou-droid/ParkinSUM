import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/local_time_resolution.dart';
import 'package:parkinsum_companion/domain/usecases/timezone_local_time_resolver.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late TimezoneRuleSnapshot snapshot;
  const resolver = TimezoneLocalTimeResolver();

  setUpAll(() {
    timezone_data.initializeTimeZones();
  });

  setUp(() {
    snapshot = TimezoneRuleSnapshot(
      database: tz.timeZoneDatabase,
      tzdbRelease: '2025c',
      providerIdentity: 'timezone/0.11.1:data/latest_all',
    );
  });

  test('resolves a unique local time and round-trips versioned evidence', () {
    final evidence = resolver.resolve(
      localCivilTime: _civil(2026, 1, 15, 12, 30),
      ianaZoneId: 'America/Toronto',
      utcOffsetMinutes: -300,
      foldChoice: LocalTimeFoldChoice.reject,
      snapshot: snapshot,
    );

    expect(evidence.resolvedAtUtc, DateTime.utc(2026, 1, 15, 17, 30));
    expect(evidence.foldWasAmbiguous, isFalse);
    expect(evidence.tzdbRelease, '2025c');
    expect(evidence.zoneRulesSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(evidence.offsetTimestamp, '2026-01-15T12:30:00.000-05:00');
    expect(evidence.toJson()['sha256_digest'], evidence.sha256Digest);
    final restored = LocalTimeResolutionEvidence.fromJson(evidence.toJson());
    expect(restored.toJson(), evidence.toJson());
    expect(restored.sha256Digest, evidence.sha256Digest);
  });

  test('requires an explicit earlier or later choice for a DST fold', () {
    final civil = _civil(2026, 11, 1, 1, 30);

    expect(
      () => resolver.resolve(
        localCivilTime: civil,
        ianaZoneId: 'America/Toronto',
        utcOffsetMinutes: -240,
        foldChoice: LocalTimeFoldChoice.reject,
        snapshot: snapshot,
      ),
      throwsFormatException,
    );

    final earlier = resolver.resolve(
      localCivilTime: civil,
      ianaZoneId: 'America/Toronto',
      utcOffsetMinutes: -240,
      foldChoice: LocalTimeFoldChoice.earlier,
      snapshot: snapshot,
    );
    final later = resolver.resolve(
      localCivilTime: civil,
      ianaZoneId: 'America/Toronto',
      utcOffsetMinutes: -300,
      foldChoice: LocalTimeFoldChoice.later,
      snapshot: snapshot,
    );

    expect(earlier.foldWasAmbiguous, isTrue);
    expect(earlier.resolvedAtUtc, DateTime.utc(2026, 11, 1, 5, 30));
    expect(later.resolvedAtUtc, DateTime.utc(2026, 11, 1, 6, 30));
    expect(
      () => resolver.resolve(
        localCivilTime: civil,
        ianaZoneId: 'America/Toronto',
        utcOffsetMinutes: -300,
        foldChoice: LocalTimeFoldChoice.earlier,
        snapshot: snapshot,
      ),
      throwsFormatException,
    );
  });

  test('rejects a spring-forward gap without shifting it', () {
    expect(
      () => resolver.resolve(
        localCivilTime: _civil(2026, 3, 8, 2, 30),
        ianaZoneId: 'America/Toronto',
        utcOffsetMinutes: -300,
        foldChoice: LocalTimeFoldChoice.reject,
        snapshot: snapshot,
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed and unknown zones and offset-zone disagreement', () {
    final civil = _civil(2026, 7, 8, 12, 0);
    expect(
      () => resolver.resolve(
        localCivilTime: civil,
        ianaZoneId: 'America/../Toronto',
        utcOffsetMinutes: -240,
        foldChoice: LocalTimeFoldChoice.reject,
        snapshot: snapshot,
      ),
      throwsFormatException,
    );
    expect(
      () => resolver.resolve(
        localCivilTime: civil,
        ianaZoneId: 'Mars/Olympus',
        utcOffsetMinutes: 0,
        foldChoice: LocalTimeFoldChoice.reject,
        snapshot: snapshot,
      ),
      throwsFormatException,
    );
    expect(
      () => resolver.resolve(
        localCivilTime: civil,
        ianaZoneId: 'Europe/Paris',
        utcOffsetMinutes: 60,
        foldChoice: LocalTimeFoldChoice.reject,
        snapshot: snapshot,
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed civil values and tampered resolution evidence', () {
    expect(
      () => LocalCivilDateTime(
        year: 2026,
        month: 2,
        day: 30,
        hour: 1,
        minute: 0,
        second: 0,
      ),
      throwsArgumentError,
    );
    final evidence = resolver.resolve(
      localCivilTime: _civil(2026, 1, 15, 12, 30),
      ianaZoneId: 'America/Toronto',
      utcOffsetMinutes: -300,
      foldChoice: LocalTimeFoldChoice.reject,
      snapshot: snapshot,
    );
    final tampered = evidence.toJson()..['utc_offset_minutes'] = 60;
    expect(
      () => LocalTimeResolutionEvidence.fromJson(tampered),
      throwsFormatException,
    );
    final withUnknown = evidence.toJson()..['unknown'] = true;
    expect(
      () => LocalTimeResolutionEvidence.fromJson(withUnknown),
      throwsFormatException,
    );
    final unsupportedCalendar = evidence.toJson();
    final civil =
        unsupportedCalendar['local_civil_time']! as Map<String, Object?>;
    civil['calendar_system'] = 'julian';
    expect(() => LocalCivilDateTime.fromJson(civil), throwsFormatException);
  });
}

LocalCivilDateTime _civil(int year, int month, int day, int hour, int minute) =>
    LocalCivilDateTime(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: 0,
    );
