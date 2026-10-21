import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/domain/entities/local_time_resolution.dart';
import 'package:parkinsum_companion/domain/usecases/timezone_local_time_resolver.dart';
import 'package:parkinsum_companion/domain/usecases/pinned_timezone_rules.dart';
import 'package:timezone/timezone.dart' as tz;

import '../test/support/frozen_timezone_2025c.dart';

void main(List<String> args) {
  if (args.length != 4) {
    throw ArgumentError(
      'Expected civil domain, UTC reference, asset and output.',
    );
  }
  final domain =
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final reference =
      jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
  final rows = domain['rows'] as List<dynamic>;
  final points = reference['utc_points'] as List<dynamic>;
  if (rows.length > 32 || points.length > 64) {
    throw const FormatException('Timezone research budget exceeded.');
  }
  final historical = loadFrozenTimezone2025c();
  final bytes = File(args[2]).readAsBytesSync();
  final pinned = PinnedTimezoneRules.fromBytes(bytes);
  final newDatabase = pinned.snapshot.database;
  final snapshots = <String, TimezoneRuleSnapshot>{
    '2025c': historical,
    '2026e': pinned.snapshot,
  };
  const resolver = TimezoneLocalTimeResolver();
  final observations = <Map<String, Object?>>[];
  for (final entry in snapshots.entries) {
    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final civil = (row['civil'] as List<dynamic>).cast<int>();
      try {
        final evidence = resolver.resolve(
          localCivilTime: LocalCivilDateTime(
            year: civil[0],
            month: civil[1],
            day: civil[2],
            hour: civil[3],
            minute: civil[4],
            second: 0,
          ),
          ianaZoneId: row['zone'] as String,
          utcOffsetMinutes: row['offset_minutes'] as int,
          foldChoice: LocalTimeFoldChoice.values.byName(
            row['fold_choice'] as String,
          ),
          snapshot: entry.value,
        );
        observations.add(<String, Object?>{
          'id': row['id'],
          'release': entry.key,
          'accepted': true,
          'utc': evidence.resolvedAtUtc.toIso8601String(),
          'ambiguous': evidence.foldWasAmbiguous,
          'evidence': evidence.toJson(),
        });
      } on Object catch (error) {
        observations.add(<String, Object?>{
          'id': row['id'],
          'release': entry.key,
          'accepted': false,
          'reason': error.toString(),
        });
      }
    }
  }
  final utcObservations = <Map<String, Object?>>[];
  for (final raw in points) {
    final point = raw as Map<String, dynamic>;
    final instant = DateTime.parse(point['utc'] as String);
    final location = newDatabase.get(point['zone'] as String);
    final local = tz.TZDateTime.from(instant, location);
    utcObservations.add(<String, Object?>{
      'id': point['id'],
      'epoch_millis': local.millisecondsSinceEpoch,
      'civil': <int>[
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
      ],
      'offset_minutes': local.timeZoneOffset.inMinutes,
    });
  }
  final output = <String, Object?>{
    'schema': 'parkinsum.timezone-rule-research-vectors/1',
    'asset_sha256': sha256.convert(bytes).toString(),
    'civil_observations': observations,
    'utc_projections': utcObservations,
    'source_sha256': <String, String>{
      for (final file in <String>[
        'lib/domain/usecases/timezone_local_time_resolver.dart',
        'lib/domain/entities/local_time_resolution.dart',
        'lib/domain/usecases/pinned_timezone_rules.dart',
        'tool/run_timezone_rule_research_vectors.dart',
        'test/support/frozen_timezone_2025c.dart',
        frozenTimezone2025cAssetPath,
        frozenTimezone2025cManifestPath,
      ])
        file: sha256.convert(File(file).readAsBytesSync()).toString(),
    },
  };
  File(args[3])
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(output)}\n',
    );
}
