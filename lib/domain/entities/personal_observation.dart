enum PersonalObservationKind { symptom, selfReportedMotorState, bloodPressure }

enum PersonalObservationSource { selfReported, deviceManual, caregiverReported }

enum PersonalObservationStatus { recorded, notMeasured, unknown }

enum SelfReportedMotorState { on, off, uncertain }

enum BloodPressurePosture { sitting, standing, lying, unknown }

/// A user's observation, never an inferred diagnosis or treatment instruction.
/// Missing measurements remain null. Instants use UTC and retain the explicitly
/// supplied original timezone separately; parsing never substitutes the clock.
class PersonalObservation {
  static const int schemaVersion = 1;
  static const String bloodPressureUnit = 'mm[Hg]';

  final String id;
  final PersonalObservationKind kind;
  final DateTime occurredAt;
  final DateTime recordedAt;
  final String originalTimezone;
  final PersonalObservationSource source;
  final String recorderId;
  final PersonalObservationStatus status;
  final String? symptomLabel;
  final int? severity;
  final String? notes;
  final SelfReportedMotorState? motorState;
  final double? systolic;
  final double? diastolic;
  final String? unit;
  final BloodPressurePosture? posture;

  const PersonalObservation._({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.recordedAt,
    required this.originalTimezone,
    required this.source,
    required this.recorderId,
    required this.status,
    this.symptomLabel,
    this.severity,
    this.notes,
    this.motorState,
    this.systolic,
    this.diastolic,
    this.unit,
    this.posture,
  });

  factory PersonalObservation.create({
    required String id,
    required PersonalObservationKind kind,
    required DateTime occurredAt,
    required DateTime recordedAt,
    required String originalTimezone,
    required PersonalObservationSource source,
    required String recorderId,
    required PersonalObservationStatus status,
    String? symptomLabel,
    int? severity,
    String? notes,
    SelfReportedMotorState? motorState,
    double? systolic,
    double? diastolic,
    String? unit,
    BloodPressurePosture? posture,
  }) {
    final cleanId = _text(id, 'id', 200);
    final cleanRecorder = _text(recorderId, 'recorderId', 200);
    final timezone = _text(originalTimezone, 'originalTimezone', 100);
    if (!isExplicitTimezone(timezone)) {
      throw const FormatException(
        'An explicit timezone offset or name is required.',
      );
    }
    final label = symptomLabel == null
        ? null
        : _text(symptomLabel, 'symptomLabel', 200);
    final cleanNotes = notes == null ? null : _text(notes, 'notes', 4000);
    if (occurredAt.year < 1 ||
        occurredAt.year > 9999 ||
        recordedAt.year < 1 ||
        recordedAt.year > 9999) {
      throw const FormatException(
        'Observation timestamps are outside the supported range.',
      );
    }
    if (severity != null && (severity < 0 || severity > 10)) {
      throw const FormatException(
        'Subjective severity must be an integer from 0 to 10.',
      );
    }
    final hasValue = status == PersonalObservationStatus.recorded;
    if (!hasValue &&
        (severity != null ||
            motorState != null ||
            systolic != null ||
            diastolic != null)) {
      throw const FormatException(
        'Unknown or unmeasured observations cannot contain measured values.',
      );
    }
    switch (kind) {
      case PersonalObservationKind.symptom:
        if (label == null ||
            motorState != null ||
            systolic != null ||
            diastolic != null ||
            unit != null ||
            posture != null) {
          throw const FormatException(
            'A symptom needs a label and no unrelated measurement fields.',
          );
        }
      case PersonalObservationKind.selfReportedMotorState:
        if ((hasValue && motorState == null) ||
            label != null ||
            severity != null ||
            systolic != null ||
            diastolic != null ||
            unit != null ||
            posture != null) {
          throw const FormatException(
            'A recorded motor state needs an explicit self-reported state.',
          );
        }
      case PersonalObservationKind.bloodPressure:
        if (label != null ||
            severity != null ||
            motorState != null ||
            unit != bloodPressureUnit ||
            posture == null ||
            (hasValue && (systolic == null || diastolic == null))) {
          throw const FormatException(
            'Blood pressure requires both values when recorded, mm[Hg], and an explicit posture or unknown.',
          );
        }
        for (final value in [systolic, diastolic]) {
          if (value != null && (!value.isFinite || value <= 0)) {
            throw const FormatException(
              'Blood pressure values must be finite and positive.',
            );
          }
        }
    }
    return PersonalObservation._(
      id: cleanId,
      kind: kind,
      occurredAt: occurredAt.toUtc(),
      recordedAt: recordedAt.toUtc(),
      originalTimezone: timezone,
      source: source,
      recorderId: cleanRecorder,
      status: status,
      symptomLabel: label,
      severity: severity,
      notes: cleanNotes,
      motorState: motorState,
      systolic: systolic,
      diastolic: diastolic,
      unit: unit,
      posture: posture,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'kind': kind.name,
    'occurredAt': occurredAt.toIso8601String(),
    'recordedAt': recordedAt.toIso8601String(),
    'originalTimezone': originalTimezone,
    'source': source.name,
    'recorderId': recorderId,
    'status': status.name,
    'symptomLabel': symptomLabel,
    'severity': severity,
    'notes': notes,
    'motorState': motorState?.name,
    'systolic': systolic,
    'diastolic': diastolic,
    'unit': unit,
    'posture': posture?.name,
  };

  String summary({bool chinese = false}) {
    final missing = switch (status) {
      PersonalObservationStatus.notMeasured => chinese ? '未测量' : 'Not measured',
      PersonalObservationStatus.unknown => chinese ? '未知' : 'Unknown',
      PersonalObservationStatus.recorded => null,
    };
    final heading = switch (kind) {
      PersonalObservationKind.symptom => symptomLabel!,
      PersonalObservationKind.selfReportedMotorState =>
        chinese ? '自报运动状态' : 'Self-reported motor state',
      PersonalObservationKind.bloodPressure =>
        chinese ? '血压' : 'Blood pressure',
    };
    if (missing != null) return '$heading · $missing';
    return switch (kind) {
      PersonalObservationKind.symptom =>
        severity == null ? heading : '$heading · $severity/10',
      PersonalObservationKind.selfReportedMotorState =>
        '$heading · ${motorState == SelfReportedMotorState.uncertain ? (chinese ? '不确定' : 'Uncertain') : motorState!.name.toUpperCase()}',
      PersonalObservationKind.bloodPressure =>
        '$heading · ${_displayNumber(systolic!)} / ${_displayNumber(diastolic!)} mmHg · ${switch (posture) {
          BloodPressurePosture.sitting => chinese ? '坐位' : 'Sitting',
          BloodPressurePosture.standing => chinese ? '立位' : 'Standing',
          BloodPressurePosture.lying => chinese ? '卧位' : 'Lying',
          _ => chinese ? '体位未知' : 'Posture unknown',
        }}',
    };
  }

  static String _displayNumber(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  factory PersonalObservation.fromJson(Map<String, dynamic> json) {
    const fields = {
      'schemaVersion',
      'id',
      'kind',
      'occurredAt',
      'recordedAt',
      'originalTimezone',
      'source',
      'recorderId',
      'status',
      'symptomLabel',
      'severity',
      'notes',
      'motorState',
      'systolic',
      'diastolic',
      'unit',
      'posture',
    };
    if (json['schemaVersion'] is! int ||
        json['schemaVersion'] != schemaVersion ||
        json.keys.any((key) => !fields.contains(key))) {
      throw const FormatException('Unsupported observation schema or fields.');
    }
    T choice<T extends Enum>(String key, List<T> values) {
      final raw = json[key];
      for (final value in values) {
        if (raw is String && value.name == raw) return value;
      }
      throw FormatException('Invalid $key.');
    }

    String requiredText(String key) {
      final value = json[key];
      if (value is! String) throw FormatException('Missing or invalid $key.');
      return value;
    }

    String? optionalText(String key) =>
        json[key] == null ? null : requiredText(key);
    double? number(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num) throw FormatException('Invalid $key.');
      return value.toDouble();
    }

    final severity = json['severity'];
    if (severity != null && severity is! int) {
      throw const FormatException('Severity must be an integer.');
    }
    return PersonalObservation.create(
      id: requiredText('id'),
      kind: choice('kind', PersonalObservationKind.values),
      occurredAt: parseExplicitTimestamp(requiredText('occurredAt')),
      recordedAt: parseExplicitTimestamp(requiredText('recordedAt')),
      originalTimezone: requiredText('originalTimezone'),
      source: choice('source', PersonalObservationSource.values),
      recorderId: requiredText('recorderId'),
      status: choice('status', PersonalObservationStatus.values),
      symptomLabel: optionalText('symptomLabel'),
      severity: severity as int?,
      notes: optionalText('notes'),
      motorState: json['motorState'] == null
          ? null
          : choice('motorState', SelfReportedMotorState.values),
      systolic: number('systolic'),
      diastolic: number('diastolic'),
      unit: optionalText('unit'),
      posture: json['posture'] == null
          ? null
          : choice('posture', BloodPressurePosture.values),
    );
  }

  /// Accepts explicit ISO 8601 instants, rejecting overflow-normalized dates.
  static DateTime parseExplicitTimestamp(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}:\d{2})$',
    ).firstMatch(value);
    if (match == null) {
      throw const FormatException(
        'Use a complete timestamp with an explicit UTC offset.',
      );
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4]!);
    final minute = int.parse(match[5]!);
    final second = int.parse(match[6]!);
    if (year < 1 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime.utc(year, month + 1, 0).day ||
        hour > 23 ||
        minute > 59 ||
        second > 59 ||
        !_validOffset(match[8]!)) {
      throw const FormatException('Invalid observation timestamp.');
    }
    return DateTime.parse(value).toUtc();
  }

  static bool isExplicitTimezone(String value) {
    if (value == 'UTC' || value == 'Z') return true;
    final offset = value.startsWith('UTC') ? value.substring(3) : value;
    if (RegExp(r'^[+-]\d{2}:\d{2}$').hasMatch(offset)) {
      return _validOffset(offset);
    }
    // Names are retained as provenance, not claimed to be tzdb-validated.
    return RegExp(
      r'^[A-Za-z][A-Za-z0-9_+-]*(?:/[A-Za-z][A-Za-z0-9_+-]*)+$',
    ).hasMatch(value);
  }

  static bool _validOffset(String value) {
    if (value == 'Z') return true;
    final hours = int.parse(value.substring(1, 3));
    final minutes = int.parse(value.substring(4, 6));
    return hours <= 14 && minutes < 60 && (hours != 14 || minutes == 0);
  }

  static String _text(String value, String name, int maxLength) {
    final result = value.trim();
    if (result.isEmpty ||
        result.length > maxLength ||
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(result)) {
      throw FormatException('Invalid $name.');
    }
    return result;
  }
}
