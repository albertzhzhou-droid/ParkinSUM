import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_list_review.dart';

void main() {
  test('review marks roundtrip with explicit UTC time and owner', () {
    final mark = CareMedicationListReview(
      section: CareMedicationListReviewSection.currentSelection,
      recordedAt: DateTime.parse('2026-09-22T12:00:00-04:00'),
      recorderId: 'account-local',
    );

    final restored = CareMedicationListReview.fromJson(mark.toJson());
    expect(restored.section, CareMedicationListReviewSection.currentSelection);
    expect(restored.recordedAt, DateTime.utc(2026, 9, 22, 16));
    expect(restored.recorderId, 'account-local');
  });

  test('review marks reject unknown sections and unexpected fields', () {
    final mark = CareMedicationListReview(
      section: CareMedicationListReviewSection.vitaminsAndSupplements,
      recordedAt: DateTime.utc(2026, 9, 22, 12),
      recorderId: 'account-local',
    ).toJson();

    expect(
      () => CareMedicationListReview.fromJson({...mark, 'section': 'other'}),
      throwsFormatException,
    );
    expect(
      () => CareMedicationListReview.fromJson({...mark, 'unreviewed': true}),
      throwsFormatException,
    );
  });
}
