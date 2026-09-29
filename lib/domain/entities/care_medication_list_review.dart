import 'personal_observation.dart';

/// Categories an account holder can mark as reviewed while preparing for a
/// visit. A mark is a self-report about the app's current list, not proof that
/// the list is complete or that a clinician reconciled it.
enum CareMedicationListReviewSection {
  currentSelection,
  overTheCounter,
  vitaminsAndSupplements,
  stoppedOrUncertain,
}

final class CareMedicationListReview {
  CareMedicationListReview({
    required this.section,
    required DateTime recordedAt,
    required String recorderId,
  }) : recordedAt = recordedAt.toUtc(),
       recorderId = _reviewText(recorderId, 'recorderId', max: 512) {
    if (this.recordedAt.year < 1 || this.recordedAt.year > 9999) {
      throw const FormatException('Invalid medication list review time.');
    }
  }

  final CareMedicationListReviewSection section;
  final DateTime recordedAt;
  final String recorderId;

  Map<String, Object?> toJson() => {
    'section': section.name,
    'recordedAt': recordedAt.toIso8601String(),
    'recorderId': recorderId,
  };

  factory CareMedicationListReview.fromJson(Map<String, dynamic> json) {
    _reviewExactKeys(json, const {'section', 'recordedAt', 'recorderId'});
    return CareMedicationListReview(
      section: _reviewEnum(
        CareMedicationListReviewSection.values,
        json['section'],
      ),
      recordedAt: PersonalObservation.parseExplicitTimestamp(
        _reviewText(json['recordedAt'], 'recordedAt', max: 64),
      ),
      recorderId: _reviewText(json['recorderId'], 'recorderId', max: 512),
    );
  }
}

T _reviewEnum<T extends Enum>(List<T> values, Object? value) {
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw const FormatException('Invalid medication review section.');
}

String _reviewText(Object? value, String field, {required int max}) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > max ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
    throw FormatException('Invalid medication review $field.');
  }
  return value.trim();
}

void _reviewExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length || !expected.containsAll(json.keys)) {
    throw const FormatException('Unexpected medication review fields.');
  }
}
