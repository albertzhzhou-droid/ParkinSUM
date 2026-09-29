import 'personal_observation.dart';

enum CareMedicationDiscussionOutcomeStatus {
  notDiscussed,
  discussed,
  followUpNeeded,
  followUpReportedComplete,
}

/// An account owner's append-only note about a medication discussion outcome.
/// It does not authenticate a clinician or establish a clinical decision.
final class CareMedicationDiscussionOutcome {
  CareMedicationDiscussionOutcome({
    required String id,
    required String entryId,
    required this.status,
    required String? note,
    required DateTime recordedAt,
    required String recorderId,
  }) : id = _requiredText(id, 'id', max: 200),
       entryId = _requiredText(entryId, 'entryId', max: 200),
       note = _optionalText(note, 'note', max: 1000),
       recorderId = _requiredText(recorderId, 'recorderId', max: 512),
       recordedAt = recordedAt.toUtc() {
    if (this.recordedAt.year < 1 || this.recordedAt.year > 9999) {
      throw const FormatException('Invalid discussion outcome timestamp.');
    }
  }

  final String id;
  final String entryId;
  final CareMedicationDiscussionOutcomeStatus status;
  final String? note;
  final DateTime recordedAt;
  final String recorderId;

  Map<String, Object?> toJson() => {
    'id': id,
    'entryId': entryId,
    'status': status.name,
    'note': note,
    'recordedAt': recordedAt.toIso8601String(),
    'recorderId': recorderId,
  };

  factory CareMedicationDiscussionOutcome.fromJson(Map<String, dynamic> json) {
    const expected = {
      'id',
      'entryId',
      'status',
      'note',
      'recordedAt',
      'recorderId',
    };
    if (json.length != expected.length || !expected.containsAll(json.keys)) {
      throw const FormatException('Unexpected discussion outcome fields.');
    }
    final status = json['status'];
    CareMedicationDiscussionOutcomeStatus? parsedStatus;
    for (final value in CareMedicationDiscussionOutcomeStatus.values) {
      if (value.name == status) parsedStatus = value;
    }
    if (parsedStatus == null) {
      throw const FormatException('Invalid discussion outcome status.');
    }
    return CareMedicationDiscussionOutcome(
      id: _requiredText(json['id'], 'id', max: 200),
      entryId: _requiredText(json['entryId'], 'entryId', max: 200),
      status: parsedStatus,
      note: _optionalText(json['note'], 'note', max: 1000),
      recordedAt: PersonalObservation.parseExplicitTimestamp(
        _requiredText(json['recordedAt'], 'recordedAt', max: 64),
      ),
      recorderId: _requiredText(json['recorderId'], 'recorderId', max: 512),
    );
  }
}

String _requiredText(Object? value, String field, {required int max}) {
  if (value is! String) throw FormatException('Invalid $field.');
  if (value.trim().isEmpty ||
      value.length > max ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
    throw FormatException('Invalid $field.');
  }
  return value.trim();
}

String? _optionalText(Object? value, String field, {required int max}) {
  if (value == null) return null;
  if (value is! String ||
      value.length > max ||
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(value)) {
    throw FormatException('Invalid $field.');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
