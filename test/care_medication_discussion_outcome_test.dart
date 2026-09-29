import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_outcome.dart';

CareMedicationDiscussionOutcome _outcome({
  String id = 'outcome-1',
  String entryId = 'entry-1',
  CareMedicationDiscussionOutcomeStatus status =
      CareMedicationDiscussionOutcomeStatus.followUpNeeded,
  String? note = 'Ask again at the next visit.',
}) => CareMedicationDiscussionOutcome(
  id: id,
  entryId: entryId,
  status: status,
  note: note,
  recordedAt: DateTime.utc(2026, 9, 22, 13),
  recorderId: 'account-a',
);

void main() {
  test('roundtrip preserves the owner-reported outcome and source entry', () {
    final value = _outcome();
    final restored = CareMedicationDiscussionOutcome.fromJson(value.toJson());

    expect(restored.toJson(), value.toJson());
    expect(
      restored.status,
      CareMedicationDiscussionOutcomeStatus.followUpNeeded,
    );
    expect(restored.entryId, 'entry-1');
  });

  test('missing note stays missing and never creates a response', () {
    final value = _outcome(
      status: CareMedicationDiscussionOutcomeStatus.discussed,
      note: null,
    );
    final restored = CareMedicationDiscussionOutcome.fromJson(value.toJson());

    expect(restored.note, isNull);
    expect(restored.status, CareMedicationDiscussionOutcomeStatus.discussed);
  });

  test(
    'strict parsing rejects unsupported status, unknown fields and identity',
    () {
      final json = _outcome().toJson();
      final malformed = <Map<String, Object?>>[
        {...json, 'unknown': true},
        {...json, 'status': 'clinicianApproved'},
        {...json, 'entryId': '\t'},
        {...json, 'note': 'x' * 1001},
        {...json, 'recordedAt': '2026-09-22T13:00:00'},
      ];
      for (final value in malformed) {
        expect(
          () => CareMedicationDiscussionOutcome.fromJson(
            Map<String, dynamic>.from(value),
          ),
          throwsFormatException,
        );
      }
    },
  );
}
