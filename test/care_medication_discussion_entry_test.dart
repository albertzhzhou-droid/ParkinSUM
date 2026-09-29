import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_entry.dart';

final _recordedAt = DateTime.utc(2026, 9, 22, 12);

CareMedicationDiscussionEntry _entry({
  String name = 'Vitamin D',
  String recorderId = 'account-a',
  String? ingredientLabel = 'D3 as printed',
  String? doseAndScheduleText = 'unknown; check the bottle',
  String? question = 'Could this matter?',
}) => CareMedicationDiscussionEntry(
  id: 'entry-1',
  name: name,
  category: CareMedicationDiscussionCategory.supplement,
  reportedUse: CareMedicationReportedUse.uncertain,
  ingredientLabel: ingredientLabel,
  doseAndScheduleText: doseAndScheduleText,
  question: question,
  recordedAt: _recordedAt,
  recorderId: recorderId,
);

void main() {
  test(
    'roundtrip preserves user text and does not infer a catalog identity',
    () {
      final entry = _entry();
      final restored = CareMedicationDiscussionEntry.fromJson(entry.toJson());

      expect(restored.toJson(), entry.toJson());
      expect(restored.doseAndScheduleText, 'unknown; check the bottle');
      expect(restored.category, CareMedicationDiscussionCategory.supplement);
      expect(restored.reportedUse, CareMedicationReportedUse.uncertain);
      expect(restored.ingredientLabel, 'D3 as printed');
      expect(entry.toJson().keys, isNot(contains('catalogCode')));
      expect(entry.toJson().keys, isNot(contains('ingredientId')));
    },
  );

  test(
    'missing optional text remains missing, not zero or an invented dose',
    () {
      final entry = _entry(
        ingredientLabel: null,
        doseAndScheduleText: null,
        question: null,
      );
      final restored = CareMedicationDiscussionEntry.fromJson(entry.toJson());

      expect(restored.ingredientLabel, isNull);
      expect(restored.doseAndScheduleText, isNull);
      expect(restored.question, isNull);
    },
  );

  test('schema-v2 entry shape loads with an unknown ingredient label', () {
    final legacy = _entry().toJson()..remove('ingredientLabel');
    final restored = CareMedicationDiscussionEntry.fromJson(
      Map<String, dynamic>.from(legacy),
      legacyV2: true,
    );

    expect(restored.ingredientLabel, isNull);
    expect(
      () => CareMedicationDiscussionEntry.fromJson(
        Map<String, dynamic>.from(legacy),
      ),
      throwsFormatException,
    );
  });

  test(
    'strict parsing rejects invalid fields, enums, identity and control text',
    () {
      final json = _entry().toJson();
      final malformed = <Map<String, Object?>>[
        {...json, 'unverified': false},
        {...json, 'category': 'fuzzyMatch'},
        {...json, 'reportedUse': 'confirmedCurrent'},
        {...json, 'name': '  '},
        {...json, 'name': 'bad\u0000name'},
        {...json, 'question': 'x' * 1001},
        {...json, 'ingredientLabel': 'x' * 301},
        {...json, 'recordedAt': '2026-09-22T12:00:00'},
      ];
      for (final value in malformed) {
        expect(
          () => CareMedicationDiscussionEntry.fromJson(
            Map<String, dynamic>.from(value),
          ),
          throwsFormatException,
        );
      }
    },
  );
}
