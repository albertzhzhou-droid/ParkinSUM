import 'dart:convert';

import 'package:crypto/crypto.dart';

const int localTimeResolutionSchemaVersion = 1;
const String localTimeResolutionSchema = 'parkinsum.local-time-resolution/1';
const String localTimeResolutionSource = 'timezone-local-time-resolver-v1';
const String localTimeCalendarSystem = 'gregorian';

enum LocalTimeFoldChoice { earlier, later, reject }

/// A wall-clock date and time without an implied timezone or UTC offset.
///
/// Keeping the components instead of a [DateTime] prevents the host device's
/// local timezone from silently changing the input.
final class LocalCivilDateTime {
  LocalCivilDateTime({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.second,
    this.millisecond = 0,
    this.microsecond = 0,
  }) {
    _validate();
  }

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;
  final int millisecond;
  final int microsecond;

  int get pseudoUtcMicroseconds => DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
    microsecond,
  ).microsecondsSinceEpoch;

  Map<String, Object?> toJson() => <String, Object?>{
    'calendar_system': localTimeCalendarSystem,
    'year': year,
    'month': month,
    'day': day,
    'hour': hour,
    'minute': minute,
    'second': second,
    'millisecond': millisecond,
    'microsecond': microsecond,
  };

  factory LocalCivilDateTime.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'calendar_system',
      'year',
      'month',
      'day',
      'hour',
      'minute',
      'second',
      'millisecond',
      'microsecond',
    }, 'local civil time');
    if (json['calendar_system'] != localTimeCalendarSystem) {
      throw const FormatException('Unsupported civil calendar system.');
    }
    return LocalCivilDateTime(
      year: _int(json['year'], 'year'),
      month: _int(json['month'], 'month'),
      day: _int(json['day'], 'day'),
      hour: _int(json['hour'], 'hour'),
      minute: _int(json['minute'], 'minute'),
      second: _int(json['second'], 'second'),
      millisecond: _int(json['millisecond'], 'millisecond'),
      microsecond: _int(json['microsecond'], 'microsecond'),
    );
  }

  void _validate() {
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'Must be in 1..9999.');
    }
    try {
      final value = DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
        millisecond,
        microsecond,
      );
      if (value.year != year ||
          value.month != month ||
          value.day != day ||
          value.hour != hour ||
          value.minute != minute ||
          value.second != second ||
          value.millisecond != millisecond ||
          value.microsecond != microsecond) {
        throw ArgumentError('Invalid local civil date-time components.');
      }
    } on ArgumentError {
      rethrow;
    }
  }
}

/// Immutable evidence for resolving one civil time against a particular zone
/// ruleset. The source and tzdb release are caller-supplied provenance labels;
/// [zoneRulesSha256] additionally fingerprints the exact zone rules used.
final class LocalTimeResolutionEvidence {
  LocalTimeResolutionEvidence({
    required this.localCivilTime,
    required this.ianaZoneId,
    required this.tzdbRelease,
    required this.providerIdentity,
    required this.zoneRulesSha256,
    required this.utcOffsetMinutes,
    required this.resolvedAtUtc,
    this.resolutionSource = localTimeResolutionSource,
    required this.foldChoice,
    required this.foldWasAmbiguous,
  }) {
    _validate();
  }

  final LocalCivilDateTime localCivilTime;
  final String ianaZoneId;
  final String tzdbRelease;
  final String providerIdentity;
  final String zoneRulesSha256;
  final int utcOffsetMinutes;
  final DateTime resolvedAtUtc;
  final String resolutionSource;
  final LocalTimeFoldChoice foldChoice;
  final bool foldWasAmbiguous;

  /// RFC 3339-style timestamp reconstructed from the supplied civil time and
  /// resolved offset, without consulting the host device timezone.
  String get offsetTimestamp {
    final civil = localCivilTime;
    final wallClock = DateTime.utc(
      civil.year,
      civil.month,
      civil.day,
      civil.hour,
      civil.minute,
      civil.second,
      civil.millisecond,
      civil.microsecond,
    ).toIso8601String();
    final sign = utcOffsetMinutes < 0 ? '-' : '+';
    final absoluteOffset = utcOffsetMinutes.abs();
    final hours = (absoluteOffset ~/ 60).toString().padLeft(2, '0');
    final minutes = (absoluteOffset % 60).toString().padLeft(2, '0');
    return '${wallClock.substring(0, wallClock.length - 1)}$sign$hours:$minutes';
  }

  Map<String, Object?> _bodyJson() => <String, Object?>{
    'schema': localTimeResolutionSchema,
    'local_civil_time': localCivilTime.toJson(),
    'iana_zone_id': ianaZoneId,
    'tzdb_release': tzdbRelease,
    'provider_identity': providerIdentity,
    'zone_rules_sha256': zoneRulesSha256,
    'utc_offset_minutes': utcOffsetMinutes,
    'resolved_at_utc': resolvedAtUtc.toIso8601String(),
    'resolution_source': resolutionSource,
    'fold_choice': foldChoice.name,
    'fold_was_ambiguous': foldWasAmbiguous,
  };

  String get sha256Digest =>
      sha256.convert(utf8.encode(_canonicalJson(_bodyJson()))).toString();

  Map<String, Object?> toJson() => <String, Object?>{
    ..._bodyJson(),
    'sha256_digest': sha256Digest,
  };

  factory LocalTimeResolutionEvidence.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const <String>{
      'schema',
      'local_civil_time',
      'iana_zone_id',
      'tzdb_release',
      'provider_identity',
      'zone_rules_sha256',
      'utc_offset_minutes',
      'resolved_at_utc',
      'resolution_source',
      'fold_choice',
      'fold_was_ambiguous',
      'sha256_digest',
    }, 'local time resolution');
    if (json['schema'] != localTimeResolutionSchema) {
      throw const FormatException('Unsupported local time resolution schema.');
    }
    final localTime = json['local_civil_time'];
    if (localTime is! Map) {
      throw const FormatException('Local civil time must be an object.');
    }
    final LocalTimeResolutionEvidence evidence;
    try {
      evidence = LocalTimeResolutionEvidence(
        localCivilTime: LocalCivilDateTime.fromJson(<String, Object?>{
          for (final entry in localTime.entries)
            _string(entry.key, 'local civil time key'): entry.value,
        }),
        ianaZoneId: _string(json['iana_zone_id'], 'iana_zone_id'),
        tzdbRelease: _string(json['tzdb_release'], 'tzdb_release'),
        providerIdentity: _string(
          json['provider_identity'],
          'provider_identity',
        ),
        zoneRulesSha256: _string(
          json['zone_rules_sha256'],
          'zone_rules_sha256',
        ),
        utcOffsetMinutes: _int(
          json['utc_offset_minutes'],
          'utc_offset_minutes',
        ),
        resolvedAtUtc: _utcDateTime(json['resolved_at_utc']),
        resolutionSource: _string(
          json['resolution_source'],
          'resolution_source',
        ),
        foldChoice: _enumByName(
          LocalTimeFoldChoice.values,
          json['fold_choice'],
          'fold_choice',
        ),
        foldWasAmbiguous: _bool(
          json['fold_was_ambiguous'],
          'fold_was_ambiguous',
        ),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid local time resolution: ${error.message}');
    }
    if (json['sha256_digest'] != evidence.sha256Digest) {
      throw const FormatException('Local time resolution digest mismatch.');
    }
    return evidence;
  }

  void _validate() {
    if (!_isValidIanaZoneId(ianaZoneId)) {
      throw ArgumentError.value(ianaZoneId, 'ianaZoneId');
    }
    if (!RegExp(r'^\d{4}[a-z]$').hasMatch(tzdbRelease)) {
      throw ArgumentError.value(tzdbRelease, 'tzdbRelease');
    }
    if (providerIdentity.trim().isEmpty ||
        providerIdentity.length > 256 ||
        providerIdentity.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw ArgumentError.value(providerIdentity, 'providerIdentity');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(zoneRulesSha256)) {
      throw ArgumentError.value(zoneRulesSha256, 'zoneRulesSha256');
    }
    if (utcOffsetMinutes < -840 || utcOffsetMinutes > 840) {
      throw ArgumentError.value(utcOffsetMinutes, 'utcOffsetMinutes');
    }
    if (!resolvedAtUtc.isUtc) {
      throw ArgumentError.value(resolvedAtUtc, 'resolvedAtUtc');
    }
    if (resolutionSource != localTimeResolutionSource) {
      throw ArgumentError.value(resolutionSource, 'resolutionSource');
    }
    final expectedUtcMicros =
        localCivilTime.pseudoUtcMicroseconds -
        utcOffsetMinutes * Duration.microsecondsPerMinute;
    if (resolvedAtUtc.microsecondsSinceEpoch != expectedUtcMicros) {
      throw ArgumentError(
        'Civil time, offset, and resolved UTC instant disagree.',
      );
    }
    if (foldWasAmbiguous && foldChoice == LocalTimeFoldChoice.reject) {
      throw ArgumentError(
        'An ambiguous time requires earlier or later choice.',
      );
    }
  }
}

bool isValidIanaZoneId(String value) => _isValidIanaZoneId(value);

bool _isValidIanaZoneId(String value) {
  if (value.length > 255 ||
      !RegExp(r'^[A-Za-z0-9._+-]+(?:/[A-Za-z0-9._+-]+)+$').hasMatch(value)) {
    return false;
  }
  return value.split('/').every((part) => part != '.' && part != '..');
}

void _requireExactKeys(
  Map<String, Object?> json,
  Set<String> expected,
  String label,
) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw FormatException('$label has unknown or missing fields.');
  }
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

int _int(Object? value, String label) {
  if (value is! int) throw FormatException('$label must be an integer.');
  return value;
}

String _string(Object? value, String label) {
  if (value is! String) throw FormatException('$label must be a string.');
  return value;
}

bool _bool(Object? value, String label) {
  if (value is! bool) throw FormatException('$label must be a boolean.');
  return value;
}

T _enumByName<T extends Enum>(List<T> values, Object? value, String label) {
  if (value is String) {
    for (final candidate in values) {
      if (candidate.name == value) return candidate;
    }
  }
  throw FormatException('$label is unsupported.');
}

DateTime _utcDateTime(Object? value) {
  final timestamp = _string(value, 'resolved_at_utc');
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.toIso8601String() != timestamp) {
    throw const FormatException('Resolved timestamp must be canonical UTC.');
  }
  return parsed;
}
