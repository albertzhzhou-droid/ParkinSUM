import 'timeline_event.dart';

/// Display-only identity. IDs from different record types never alias.
final class TypedLogRecordRef {
  const TypedLogRecordRef(this.type, this.recordId);
  final TimelineEventType type;
  final String recordId;
  factory TypedLogRecordRef.fromEvent(TimelineEvent event) =>
      TypedLogRecordRef(event.type, event.recordId);
  @override
  bool operator ==(Object other) =>
      other is TypedLogRecordRef &&
      other.type == type &&
      other.recordId == recordId;
  @override
  int get hashCode => Object.hash(type, recordId);
  String get viewKey => '${type.name}:$recordId';
}

/// A date without an implied instant or device time zone.
final class LogCivilDate implements Comparable<LogCivilDate> {
  factory LogCivilDate(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw const FormatException('Invalid calendar date.');
    }
    return LogCivilDate._(year, month, day);
  }
  const LogCivilDate._(this.year, this.month, this.day);
  factory LogCivilDate.fromDateTime(DateTime value) =>
      LogCivilDate(value.year, value.month, value.day);
  final int year;
  final int month;
  final int day;
  DateTime get calendarValue => DateTime.utc(year, month, day);
  LogCivilDate addDays(int days) =>
      LogCivilDate.fromDateTime(calendarValue.add(Duration(days: days)));
  @override
  int compareTo(LogCivilDate other) =>
      calendarValue.compareTo(other.calendarValue);
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

final class PersonalLogDateWindow {
  PersonalLogDateWindow({
    required this.start,
    required this.endInclusive,
    required this.zoneId,
  }) {
    if (start.compareTo(endInclusive) > 0) {
      throw const FormatException('The end date precedes the start date.');
    }
  }
  final LogCivilDate start;
  final LogCivilDate endInclusive;
  final String zoneId;
  int get calendarDays =>
      endInclusive.calendarValue.difference(start.calendarValue).inDays + 1;
}

final class ResolvedLogWindow {
  const ResolvedLogWindow({
    required this.selection,
    required this.startUtc,
    required this.endUtcExclusive,
    required this.asOfUtc,
  });
  final PersonalLogDateWindow selection;
  final DateTime startUtc;
  final DateTime endUtcExclusive;
  final DateTime asOfUtc;
  bool contains(DateTime instant) =>
      !instant.toUtc().isBefore(startUtc) &&
      instant.toUtc().isBefore(endUtcExclusive);
  bool isFuture(DateTime instant) => instant.toUtc().isAfter(asOfUtc);
}

enum LoggedProteinStatus { known, unknown, invalid }

final class LoggedProteinSample {
  const LoggedProteinSample({
    required this.record,
    required this.time,
    required this.status,
    required this.valueG,
    required this.reason,
  });
  final TypedLogRecordRef record;
  final DateTime time;
  final LoggedProteinStatus status;
  final double? valueG;
  final String? reason;
  bool get isReportedZero => status == LoggedProteinStatus.known && valueG == 0;
}

enum TimelineFocusStatus {
  none,
  found,
  unavailable,
  ambiguous,
  hiddenByFilters,
}

/// View state only: never saved, restored, or fed into a clinical calculation.
final class TimelineViewQuery {
  TimelineViewQuery({
    this.window,
    this.name = '',
    Set<TimelineEventType> types = const {},
    Set<String> sources = const {},
  }) : types = Set.unmodifiable(types),
       sources = Set.unmodifiable(sources);
  final ResolvedLogWindow? window;
  final String name;
  final Set<TimelineEventType> types;
  final Set<String> sources;
  bool get isFiltered =>
      window != null ||
      name.trim().isNotEmpty ||
      types.isNotEmpty ||
      sources.isNotEmpty;
}

final class TimelineSourceFacet {
  const TimelineSourceFacet({
    required this.id,
    required this.value,
    required this.isCurrentCatalog,
    required this.isUnconfirmed,
  });
  final String id;
  final String value;
  final bool isCurrentCatalog;
  final bool isUnconfirmed;
}
