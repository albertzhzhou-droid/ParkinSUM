import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import '../entities/local_time_resolution.dart';

/// A caller-supplied identity for the exact timezone database loaded by the
/// application. The resolver fingerprints the selected zone's actual tables
/// as an additional guard against a mislabeled or changed ruleset.
final class TimezoneRuleSnapshot {
  TimezoneRuleSnapshot({
    required this.database,
    required this.tzdbRelease,
    required this.providerIdentity,
  }) {
    if (!RegExp(r'^\d{4}[a-z]$').hasMatch(tzdbRelease)) {
      throw ArgumentError.value(tzdbRelease, 'tzdbRelease');
    }
    if (providerIdentity.trim().isEmpty ||
        providerIdentity.length > 256 ||
        providerIdentity.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw ArgumentError.value(providerIdentity, 'providerIdentity');
    }
  }

  final tz.LocationDatabase database;
  final String tzdbRelease;
  final String providerIdentity;
}

/// Resolves an explicitly supplied local civil time against an injected IANA
/// timezone database. Gaps fail closed; folds require an explicit choice and
/// the supplied UTC offset must match the selected result.
final class TimezoneLocalTimeResolver {
  const TimezoneLocalTimeResolver();

  static const String resolutionSource = localTimeResolutionSource;

  LocalTimeResolutionEvidence resolve({
    required LocalCivilDateTime localCivilTime,
    required String ianaZoneId,
    required int utcOffsetMinutes,
    required LocalTimeFoldChoice foldChoice,
    required TimezoneRuleSnapshot snapshot,
  }) {
    if (!snapshot.database.isInitialized) {
      throw const FormatException('Timezone rules are not initialized.');
    }
    if (!isValidIanaZoneId(ianaZoneId)) {
      throw FormatException('Malformed IANA timezone identifier: $ianaZoneId');
    }
    if (utcOffsetMinutes < -840 || utcOffsetMinutes > 840) {
      throw const FormatException('UTC offset is outside RFC3339 bounds.');
    }

    final tz.Location location;
    try {
      location = snapshot.database.get(ianaZoneId);
    } on tz.LocationNotFoundException {
      throw FormatException(
        'Timezone is not in the supplied ruleset: $ianaZoneId',
      );
    }
    if (location.name != ianaZoneId) {
      throw const FormatException(
        'Timezone identifier and database entry disagree.',
      );
    }
    _validateLocationTables(location);

    final localPseudoMicros = localCivilTime.pseudoUtcMicroseconds;
    final localPseudoMillis =
        localPseudoMicros ~/ Duration.microsecondsPerMillisecond;
    final possibleOffsets = location.zones
        .map((zone) => zone.offset.inSeconds)
        .where((seconds) => seconds % 60 == 0)
        .map((seconds) => seconds ~/ 60)
        .toSet();
    final candidates = <_Candidate>[];
    for (final offsetMinutes in possibleOffsets) {
      final candidateMillis =
          localPseudoMillis - offsetMinutes * Duration.millisecondsPerMinute;
      final actualOffsetSeconds = location
          .timeZone(candidateMillis)
          .offset
          .inSeconds;
      if (actualOffsetSeconds != offsetMinutes * 60 ||
          location.translate(candidateMillis) != localPseudoMillis) {
        continue;
      }
      final candidateMicros =
          localPseudoMicros - offsetMinutes * Duration.microsecondsPerMinute;
      candidates.add(
        _Candidate(
          utc: DateTime.fromMicrosecondsSinceEpoch(
            candidateMicros,
            isUtc: true,
          ),
          offsetMinutes: offsetMinutes,
        ),
      );
    }
    candidates.sort((left, right) => left.utc.compareTo(right.utc));
    if (candidates.isEmpty) {
      throw const FormatException(
        'Local civil time falls in a timezone gap or uses an unsupported historical offset.',
      );
    }
    if (candidates.length > 2) {
      throw const FormatException(
        'Timezone rules produced more than two instants.',
      );
    }

    final wasAmbiguous = candidates.length == 2;
    if (wasAmbiguous && foldChoice == LocalTimeFoldChoice.reject) {
      throw const FormatException(
        'Local civil time is ambiguous; choose earlier or later explicitly.',
      );
    }
    final selected = switch ((wasAmbiguous, foldChoice)) {
      (true, LocalTimeFoldChoice.later) => candidates.last,
      _ => candidates.first,
    };
    if (selected.offsetMinutes != utcOffsetMinutes) {
      throw const FormatException(
        'Explicit UTC offset does not match the selected timezone interpretation.',
      );
    }

    return LocalTimeResolutionEvidence(
      localCivilTime: localCivilTime,
      ianaZoneId: ianaZoneId,
      tzdbRelease: snapshot.tzdbRelease,
      providerIdentity: snapshot.providerIdentity,
      zoneRulesSha256: _zoneRulesDigest(location),
      utcOffsetMinutes: utcOffsetMinutes,
      resolvedAtUtc: selected.utc,
      foldChoice: foldChoice,
      foldWasAmbiguous: wasAmbiguous,
    );
  }

  static void _validateLocationTables(tz.Location location) {
    if (location.zones.isEmpty && location.transitionAt.isNotEmpty) {
      throw const FormatException('Timezone rule table has no offset records.');
    }
    if (location.transitionAt.length != location.transitionZone.length) {
      throw const FormatException(
        'Timezone transition tables have different lengths.',
      );
    }
    int? previous;
    for (var index = 0; index < location.transitionAt.length; index++) {
      final transition = location.transitionAt[index];
      final zoneIndex = location.transitionZone[index];
      if ((previous != null && transition <= previous) ||
          zoneIndex < 0 ||
          zoneIndex >= location.zones.length) {
        throw const FormatException('Timezone transition table is malformed.');
      }
      previous = transition;
    }
  }

  static String _zoneRulesDigest(tz.Location location) {
    final body = <String, Object?>{
      'profile': 'timezone-zone-rules-v1',
      'zone_id': location.name,
      'transition_at_millis': location.transitionAt,
      'transition_zone_indices': location.transitionZone,
      'zones': <Object?>[
        for (final zone in location.zones)
          <String, Object?>{
            'offset_microseconds': zone.offset.inMicroseconds,
            'is_dst': zone.isDst,
            'abbreviation': zone.abbreviation,
          },
      ],
    };
    return sha256.convert(utf8.encode(_canonicalJson(body))).toString();
  }
}

final class _Candidate {
  const _Candidate({required this.utc, required this.offsetMinutes});

  final DateTime utc;
  final int offsetMinutes;
}

String _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}
