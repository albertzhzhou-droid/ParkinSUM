import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/domain/usecases/timezone_local_time_resolver.dart';
import 'package:timezone/timezone.dart' as tz;

const String frozenTimezone2025cAssetPath =
    'test/fixtures/timezone_research/iana_2025c_five_zones.tzf';
const String frozenTimezone2025cManifestPath =
    'test/fixtures/timezone_research/iana_2025c_five_zones_manifest.json';
const String frozenTimezone2025cAssetSha256 =
    'e20a656edf5a9715563cf6ca870e6a84c6917862d8d88e184c51b08011f1b455';

/// Loads unchanged 2025c tables extracted from timezone 0.11.1, independent
/// of whichever data the installed package now calls latest_all.
///
/// Replaces the package-global database for isolation tests, while returning
/// a separate database whose location entries survive a later global reload.
/// This five-zone fixture is used only by finite tests and research tools.
TimezoneRuleSnapshot loadFrozenTimezone2025c() {
  final bytes = File(frozenTimezone2025cAssetPath).readAsBytesSync();
  if (sha256.convert(bytes).toString() != frozenTimezone2025cAssetSha256) {
    throw const FormatException('Historical 2025c fixture identity changed.');
  }
  tz.initializeDatabase(bytes);
  final database = tz.LocationDatabase();
  for (final location in tz.timeZoneDatabase.locations.values) {
    database.add(location);
  }
  return TimezoneRuleSnapshot(
    database: database,
    tzdbRelease: '2025c',
    providerIdentity:
        'timezone/0.11.1:frozen-five-zones:'
        '$frozenTimezone2025cAssetSha256',
  );
}
