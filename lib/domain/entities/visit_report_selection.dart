import 'personal_diary_strip.dart';
import 'personal_log_view.dart';

/// Explicit, report-only choices. They never alter stored records or CDSS input.
final class VisitReportSelection {
  VisitReportSelection({
    required this.window,
    required Iterable<String> intakeIds,
    required Iterable<String> observationIds,
    required Iterable<String> questionNoteIds,
    required Iterable<String> medicationEntryIds,
    required Iterable<String> followupPromptIds,
    required this.includeCurrentMedications,
    required this.includeRecordNotes,
    required this.includeDiscussionUpdates,
    required this.includeSourceAssertions,
    this.includeDiaryStrip = false,
    this.diaryProteinFilterG = diaryDefaultProteinFilterG,
  }) : intakeIds = _ids(intakeIds, 20000),
       observationIds = _ids(observationIds, 128),
       questionNoteIds = _ids(questionNoteIds, 60),
       medicationEntryIds = _ids(medicationEntryIds, 128),
       followupPromptIds = _ids(followupPromptIds, 128) {
    if (window.calendarDays < 1 || window.calendarDays > 366) {
      throw const FormatException('Visit report date range exceeds its limit.');
    }
    if (!diaryProteinFilterOptionsG.contains(diaryProteinFilterG)) {
      throw const FormatException('Unsupported diary protein display filter.');
    }
  }

  final PersonalLogDateWindow window;
  final Set<String> intakeIds;
  final Set<String> observationIds;
  final Set<String> questionNoteIds;
  final Set<String> medicationEntryIds;
  final Set<String> followupPromptIds;
  final bool includeCurrentMedications;
  final bool includeRecordNotes;
  final bool includeDiscussionUpdates;
  final bool includeSourceAssertions;

  /// Adds the day strip of every intake, meal and motor-state entry in the
  /// last days of [window], independent of the record choices above.
  final bool includeDiaryStrip;

  /// Meal-protein display filter for the strip's counts; not a target.
  final int diaryProteinFilterG;

  Map<String, Object?> toJson() => {
    'startDate': window.start.toString(),
    'endDateInclusive': window.endInclusive.toString(),
    'zoneId': window.zoneId,
    'intakeIds': intakeIds.toList()..sort(),
    'observationIds': observationIds.toList()..sort(),
    'questionNoteIds': questionNoteIds.toList()..sort(),
    'medicationEntryIds': medicationEntryIds.toList()..sort(),
    'followupPromptIds': followupPromptIds.toList()..sort(),
    'includeCurrentMedications': includeCurrentMedications,
    'includeRecordNotes': includeRecordNotes,
    'includeDiscussionUpdates': includeDiscussionUpdates,
    'includeSourceAssertions': includeSourceAssertions,
    'includeDiaryStrip': includeDiaryStrip,
    'diaryProteinFilterG': diaryProteinFilterG,
  };

  static Set<String> _ids(Iterable<String> values, int limit) {
    final list = values.take(limit + 1).toList(growable: false);
    if (list.length > limit ||
        list.toSet().length != list.length ||
        list.any((id) => id.isEmpty || id.trim() != id || id.length > 512)) {
      throw const FormatException('Invalid visit report record selection.');
    }
    return Set.unmodifiable(list);
  }
}

/// Ephemeral source lease, not an exported owner ID or clinical receipt.
final class VisitPreparationSourceLease {
  const VisitPreparationSourceLease({
    required this.owner,
    required this.sessionEpoch,
    required this.sourceRevision,
  });
  final String owner;
  final int sessionEpoch;
  final String sourceRevision;
}
