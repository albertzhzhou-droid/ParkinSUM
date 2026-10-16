import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import 'timezone_local_time_resolver.dart';

const pinnedTimezoneRelease = '2026e';
const pinnedTimezoneAssetPath = 'assets/timezone/iana_2026e_1900_2100.tzf';
const pinnedTimezoneAssetSha256 =
    'fc3e41d604ce68e0da3f19339d02a8682ea2fedb54748fc45ab9340832a78d3a';
const pinnedTimezoneSourceArchiveSha256 =
    'b26882805f26aac59d5b222978e6580484b834ccdc98be89df2f05a6dc53a652';

/// Exact offline artifact identity; labels alone cannot requalify old tables.
/// The locked package codec is used without copying its implementation.
final class PinnedTimezoneRules {
  PinnedTimezoneRules._(this._bytes, this.snapshot);
  static PinnedTimezoneRules? _active;
  static PinnedTimezoneRules? get active => _active;

  factory PinnedTimezoneRules.fromBytes(List<int> bytes) {
    if (bytes.length != 661152 ||
        sha256.convert(bytes).toString() != pinnedTimezoneAssetSha256) {
      throw const FormatException(
        'Pinned timezone artifact identity mismatch.',
      );
    }
    final ownedBytes = Uint8List.fromList(bytes);
    // The package's public codec initializes its global database. This factory
    // is synchronous: capture and restore its prior entries/local setting,
    // then retain an independent immutable copy without an internal API import.
    final previousLocations = tz.timeZoneDatabase.locations.values.toList();
    final previousLocal = tz.timeZoneDatabase.isInitialized ? tz.local : tz.UTC;
    final _FrozenTimezoneDatabase database;
    try {
      tz.initializeDatabase(ownedBytes);
      database = _FrozenTimezoneDatabase(tz.timeZoneDatabase.locations.values);
    } finally {
      tz.timeZoneDatabase.clear();
      for (final location in previousLocations) {
        tz.timeZoneDatabase.add(location);
      }
      tz.setLocalLocation(previousLocal);
    }
    if (database.locations.length != 597) {
      throw const FormatException('Pinned timezone artifact is incomplete.');
    }
    final snapshot = TimezoneRuleSnapshot(
      database: database,
      tzdbRelease: pinnedTimezoneRelease,
      providerIdentity:
          'IANA/2026e:$pinnedTimezoneSourceArchiveSha256;'
          'timezone/0.11.1:$pinnedTimezoneAssetSha256',
      supportedStartUtc: DateTime.utc(1900),
      supportedEndUtcExclusive: DateTime.utc(2100),
    );
    return PinnedTimezoneRules._(ownedBytes, snapshot);
  }

  final Uint8List _bytes;
  final TimezoneRuleSnapshot snapshot;

  /// Package-global data is for current display/reminder conversion. Immutable
  /// evidence snapshots remain independent if another consumer replaces it.
  void initializeGlobalDatabase() {
    tz.initializeDatabase(_bytes);
    _active = this;
  }
}

final class _FrozenTimezoneDatabase extends tz.LocationDatabase {
  _FrozenTimezoneDatabase(Iterable<tz.Location> locations) {
    for (final location in locations) {
      super.add(
        tz.Location(
          location.name,
          List<int>.unmodifiable(location.transitionAt),
          List<int>.unmodifiable(location.transitionZone),
          List<tz.TimeZone>.unmodifiable(location.zones),
        ),
      );
    }
  }

  @override
  Map<String, tz.Location> get locations =>
      Map<String, tz.Location>.unmodifiable(super.locations);

  @override
  void add(tz.Location location) =>
      throw UnsupportedError('Pinned timezone snapshot is immutable.');

  @override
  void clear() =>
      throw UnsupportedError('Pinned timezone snapshot is immutable.');
}
