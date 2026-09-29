import 'personal_observation.dart';

enum CareMedicationDiscussionCategory {
  prescription,
  overTheCounter,
  vitamin,
  supplement,
  other,
  unspecified,
}

enum CareMedicationReportedUse { reportedCurrent, reportedStopped, uncertain }

/// An account-entered medication item for visit discussion only.
///
/// The free-text name and dose/schedule are deliberately not normalized,
/// matched to a catalog, or consumed by the decision-support engine.
final class CareMedicationDiscussionEntry {
  CareMedicationDiscussionEntry({
    required String id,
    required String name,
    required this.category,
    required this.reportedUse,
    String? ingredientLabel,
    required String? doseAndScheduleText,
    required String? question,
    required DateTime recordedAt,
    required String recorderId,
  }) : id = _requiredText(id, 'id', max: 200),
       name = _requiredText(name, 'name', max: 300),
       ingredientLabel = _optionalText(
         ingredientLabel,
         'ingredientLabel',
         max: 300,
       ),
       doseAndScheduleText = _optionalText(
         doseAndScheduleText,
         'doseAndScheduleText',
         max: 1000,
       ),
       question = _optionalText(question, 'question', max: 1000),
       recorderId = _requiredText(recorderId, 'recorderId', max: 512),
       recordedAt = recordedAt.toUtc() {
    if (this.recordedAt.year < 1 || this.recordedAt.year > 9999) {
      throw const FormatException('Invalid medication discussion timestamp.');
    }
  }

  final String id;
  final String name;
  final CareMedicationDiscussionCategory category;
  final CareMedicationReportedUse reportedUse;

  /// A user-entered label only; never normalized or treated as a drug identity.
  final String? ingredientLabel;
  final String? doseAndScheduleText;
  final String? question;
  final DateTime recordedAt;
  final String recorderId;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'reportedUse': reportedUse.name,
    'ingredientLabel': ingredientLabel,
    'doseAndScheduleText': doseAndScheduleText,
    'question': question,
    'recordedAt': recordedAt.toIso8601String(),
    'recorderId': recorderId,
  };

  factory CareMedicationDiscussionEntry.fromJson(
    Map<String, dynamic> json, {
    bool legacyV2 = false,
  }) {
    final expectedFields = <String>{
      'id',
      'name',
      'category',
      'reportedUse',
      'doseAndScheduleText',
      'question',
      'recordedAt',
      'recorderId',
      if (!legacyV2) 'ingredientLabel',
    };
    _exactKeys(json, expectedFields);
    return CareMedicationDiscussionEntry(
      id: _requiredText(json['id'], 'id', max: 200),
      name: _requiredText(json['name'], 'name', max: 300),
      category: _enumValue(
        CareMedicationDiscussionCategory.values,
        json['category'],
      ),
      reportedUse: _enumValue(
        CareMedicationReportedUse.values,
        json['reportedUse'],
      ),
      ingredientLabel: legacyV2
          ? null
          : _optionalText(json['ingredientLabel'], 'ingredientLabel', max: 300),
      doseAndScheduleText: _optionalText(
        json['doseAndScheduleText'],
        'doseAndScheduleText',
        max: 1000,
      ),
      question: _optionalText(json['question'], 'question', max: 1000),
      recordedAt: PersonalObservation.parseExplicitTimestamp(
        _requiredText(json['recordedAt'], 'recordedAt', max: 64),
      ),
      recorderId: _requiredText(json['recorderId'], 'recorderId', max: 512),
    );
  }
}

T _enumValue<T extends Enum>(List<T> values, Object? value) {
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw const FormatException('Invalid medication discussion category.');
}

String _requiredText(Object? value, String field, {required int max}) {
  if (value is! String) throw FormatException('Invalid $field.');
  _requireText(value, field, max: max);
  return value.trim();
}

void _requireText(String value, String field, {required int max}) {
  if (value.trim().isEmpty ||
      value.length > max ||
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(value)) {
    throw FormatException('Invalid $field.');
  }
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

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length || !expected.containsAll(json.keys)) {
    throw const FormatException('Unexpected medication discussion fields.');
  }
}
