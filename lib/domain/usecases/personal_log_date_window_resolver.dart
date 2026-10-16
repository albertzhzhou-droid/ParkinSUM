import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../entities/personal_log_view.dart';
import 'pinned_timezone_rules.dart';
import 'timezone_local_time_resolver.dart';

/// Calendar display projection only. It does not reconstruct a record's
/// original time zone, resolve future clinical intent, or issue a tzdb receipt.
final class PersonalLogDateWindowResolver {
  PersonalLogDateWindowResolver({TimezoneRuleSnapshot? ruleSnapshot})
    : _snapshot = ruleSnapshot ?? PinnedTimezoneRules.active?.snapshot {
    // Web and ephemeral flows cannot depend on native reminder initialization.
    if (_snapshot == null && !tz.timeZoneDatabase.isInitialized) {
      tz_data.initializeTimeZones();
    }
  }

  final TimezoneRuleSnapshot? _snapshot;

  tz.Location location(String zoneId) {
    if (zoneId.trim() != zoneId || zoneId.isEmpty) {
      throw const FormatException(
        'An explicit supported time zone is required.',
      );
    }
    try {
      return (_snapshot?.database ?? tz.timeZoneDatabase).get(zoneId);
    } on tz.LocationNotFoundException {
      throw const FormatException('The declared time zone is unavailable.');
    }
  }

  LogCivilDate dateAt(DateTime instant, String zoneId) =>
      LogCivilDate.fromDateTime(displayTime(instant, zoneId));

  DateTime displayTime(DateTime instant, String zoneId) {
    _requireSupported(instant);
    return tz.TZDateTime.from(instant.toUtc(), location(zoneId));
  }

  void _requireSupported(DateTime instant) {
    if (_snapshot?.supportsInstant(instant) == false) {
      throw const FormatException('Calendar projection rules are unavailable.');
    }
  }

  ResolvedLogWindow resolve(
    PersonalLogDateWindow selection, {
    required DateTime asOf,
  }) {
    final zone = location(selection.zoneId);
    DateTime midnight(LogCivilDate day) {
      final value = tz.TZDateTime(zone, day.year, day.month, day.day);
      // Some historical zones skip civil dates or midnight. Do not normalize
      // a user's selected boundary into a different date or hour silently.
      if (value.year != day.year ||
          value.month != day.month ||
          value.day != day.day ||
          value.hour != 0 ||
          value.minute != 0) {
        throw const FormatException(
          'The selected calendar boundary is unavailable.',
        );
      }
      return value.toUtc();
    }

    final start = midnight(selection.start);
    final end = midnight(selection.endInclusive.addDays(1));
    _requireSupported(start);
    // The exclusive end may equal the artifact's exclusive support boundary.
    final supportedEnd = _snapshot?.supportedEndUtcExclusive;
    if (supportedEnd != null && end.isAfter(supportedEnd)) {
      throw const FormatException('Calendar projection rules are unavailable.');
    }
    if (!end.isAfter(start)) {
      throw const FormatException('Empty calendar interval.');
    }
    return ResolvedLogWindow(
      selection: selection,
      startUtc: start,
      endUtcExclusive: end,
      asOfUtc: asOf.toUtc(),
    );
  }
}
