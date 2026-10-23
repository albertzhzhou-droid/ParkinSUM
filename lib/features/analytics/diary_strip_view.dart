import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/personal_diary_strip.dart';
import '../../domain/entities/personal_log_view.dart';
import '../../domain/entities/personal_observation.dart';
import '../../domain/usecases/personal_diary_strip_projector.dart';

/// Day strip in the paper-diary layout clinicians use: medication intakes,
/// meals with logged protein, and self-reported motor state on one 24-hour
/// axis. Every mark is a stored entry; the view adds no duration, trend,
/// cause or advice. Colours follow the ambient brightness, every mark kind
/// also differs in shape or text, and every lane reads as text to a screen
/// reader. Controls are buttons with targets of at least 48 px.

const double _minTarget = 48;

String _clock(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

String diaryStateLabel(AppI18n i18n, SelfReportedMotorState state) =>
    switch (state) {
      SelfReportedMotorState.on => i18n.tr('diary.state_on'),
      SelfReportedMotorState.off => i18n.tr('diary.state_off'),
      SelfReportedMotorState.uncertain => i18n.tr('diary.state_uncertain'),
    };

String diaryProteinLabel(AppI18n i18n, DiaryMealMark meal) =>
    switch (meal.proteinStatus) {
      LoggedProteinStatus.known when meal.proteinG != null => i18n.tr(
        'diary.protein_known',
        {'grams': meal.proteinG!.toStringAsFixed(1)},
      ),
      LoggedProteinStatus.invalid => i18n.tr('diary.protein_invalid'),
      _ => i18n.tr('diary.protein_unknown'),
    };

String diaryCountLine(AppI18n i18n, DiaryStripProjection p, DiaryMotorCount c) {
  final key = switch (c.state) {
    SelfReportedMotorState.off => 'diary.count_off',
    SelfReportedMotorState.on => 'diary.count_on',
    SelfReportedMotorState.uncertain => 'diary.count_uncertain',
  };
  return i18n.tr(key, {
    'hours': '${p.lookbackHours}',
    'grams': '${p.proteinFilterG}',
    'n': '${c.afterFilteredMeal}',
    'm': '${c.total}',
  });
}

final class _Palette {
  const _Palette({
    required this.ink,
    required this.muted,
    required this.track,
    required this.grid,
    required this.medication,
    required this.meal,
    required this.on,
    required this.onInk,
    required this.label,
  });

  factory _Palette.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return _Palette(
      ink: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      track: scheme.onSurface.withAlpha(dark ? 26 : 13),
      grid: scheme.onSurface.withAlpha(dark ? 56 : 36),
      medication: dark ? const Color(0xFF9DBBE0) : Paper.info,
      meal: dark ? const Color(0xFFF0A07E) : Paper.accent,
      on: dark ? const Color(0xFF8FCBA4) : Paper.success,
      onInk: dark ? const Color(0xFF10251A) : Colors.white,
      label: theme.textTheme.labelSmall ?? const TextStyle(),
    );
  }

  final Color ink;
  final Color muted;
  final Color track;
  final Color grid;
  final Color medication;
  final Color meal;
  final Color on;
  final Color onInk;

  /// Theme label style, so pill text uses the app's font family.
  final TextStyle label;
}

enum _Mark { dose, mealKnown, mealUnknown, on, off, uncertain }

_Mark _motorMark(SelfReportedMotorState state) => switch (state) {
  SelfReportedMotorState.on => _Mark.on,
  SelfReportedMotorState.off => _Mark.off,
  SelfReportedMotorState.uncertain => _Mark.uncertain,
};

/// Draws one mark. [label] is drawn inside motor pills on the full strip.
void _paintMark(
  Canvas canvas,
  Offset c,
  _Mark mark,
  _Palette palette, {
  double scale = 1,
  String? label,
}) {
  final fill = Paint()..style = PaintingStyle.fill;
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2 * scale;
  switch (mark) {
    case _Mark.dose:
      final r = 7 * scale;
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r, c.dy)
        ..close();
      canvas.drawPath(path, fill..color = palette.medication);
    case _Mark.mealKnown:
      canvas.drawCircle(c, 6.5 * scale, fill..color = palette.meal);
    case _Mark.mealUnknown:
      canvas.drawCircle(c, 5.5 * scale, stroke..color = palette.meal);
    case _Mark.on || _Mark.off || _Mark.uncertain:
      final text = label == null
          ? null
          : (TextPainter(
              text: TextSpan(
                text: label,
                style: palette.label.copyWith(
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: mark == _Mark.on
                      ? palette.onInk
                      : mark == _Mark.off
                      ? palette.ink
                      : palette.muted,
                ),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout());
      final width = text == null ? 11 * scale : text.width + 10;
      final height = text == null ? 11 * scale : 18.0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: width, height: height),
        Radius.circular(height / 2),
      );
      if (mark == _Mark.on) {
        canvas.drawRRect(rect, fill..color = palette.on);
      } else {
        canvas.drawRRect(
          rect,
          stroke
            ..color = mark == _Mark.off ? palette.ink : palette.muted
            ..strokeWidth = mark == _Mark.off ? 2 * scale : 1.2 * scale,
        );
      }
      text?.paint(
        canvas,
        Offset(c.dx - text.width / 2, c.dy - text.height / 2),
      );
  }
}

/// Horizontal inset so marks at 00:00 and 23:59 stay inside the track.
const double _inset = 18;
double _x(double width, int minuteOfDay) =>
    _inset + (width - 2 * _inset) * (minuteOfDay / 1440);

class _LanePainter extends CustomPainter {
  _LanePainter(this.marks, this.palette, {this.rows = 1, this.labels = true});

  /// (row, minute, mark, label)
  final List<(int, int, _Mark, String?)> marks;
  final _Palette palette;
  final int rows;
  final bool labels;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      Paint()..color = palette.track,
    );
    final grid = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    for (var hour = 0; hour <= 24; hour += 6) {
      final x = _x(size.width, hour * 60);
      canvas.drawLine(Offset(x, 3), Offset(x, size.height - 3), grid);
    }
    final rowHeight = size.height / rows;
    // A labelled pill is about 36 px wide; a mark closer than that to the
    // previous labelled one is drawn compact. The text below names both.
    double? lastLabelled;
    for (final (row, minute, mark, label) in marks) {
      final x = _x(size.width, minute);
      final roomy = lastLabelled == null || x - lastLabelled >= 38;
      final shown = labels && label != null && roomy ? label : null;
      if (shown != null) lastLabelled = x;
      _paintMark(
        canvas,
        Offset(x, rowHeight * row + rowHeight / 2),
        mark,
        palette,
        scale: rows == 1 ? 1 : 0.62,
        label: shown,
      );
    }
  }

  @override
  bool shouldRepaint(_LanePainter old) =>
      old.marks != marks || old.palette.ink != palette.ink || old.rows != rows;
}

class _Axis extends StatelessWidget {
  const _Axis();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: _Palette.of(context).muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ExcludeSemantics(
      child: SizedBox(
        height: 16,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            clipBehavior: Clip.none,
            children: [
              for (var hour = 0; hour <= 24; hour += 6)
                Positioned(
                  left: _x(constraints.maxWidth, hour * 60) - 10,
                  width: 20,
                  child: Text(
                    hour.toString().padLeft(2, '0'),
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three lanes of one day, each followed by its entries as text.
class DiaryDayLanes extends StatelessWidget {
  const DiaryDayLanes({
    super.key,
    required this.day,
    this.showMealTitles = true,
  });

  final DiaryDay day;

  /// Visit exports leave meal titles out; the strip on Insights shows them.
  final bool showMealTitles;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final palette = _Palette.of(context);
    final doses = [
      for (final dose in day.doses)
        '${_clock(dose.minuteOfDay)} · ${dose.medicationName} · '
            '${dose.doseText ?? i18n.tr('diary.dose_unknown')}',
    ];
    final meals = [
      for (final meal in day.meals)
        [
          _clock(meal.minuteOfDay),
          if (showMealTitles && meal.title.trim().isNotEmpty) meal.title.trim(),
          diaryProteinLabel(i18n, meal),
        ].join(' · '),
    ];
    final motor = [
      for (final mark in day.motor)
        '${_clock(mark.minuteOfDay)} · ${diaryStateLabel(i18n, mark.state)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Axis(),
        const SizedBox(height: 4),
        _Lane(
          laneKey: 'medication',
          icon: Icons.medication_outlined,
          title: i18n.tr('diary.lane_medication'),
          entries: doses,
          color: palette.medication,
          marks: [
            for (final dose in day.doses)
              (0, dose.minuteOfDay, _Mark.dose, null),
          ],
        ),
        _Lane(
          laneKey: 'meals',
          icon: Icons.restaurant_outlined,
          title: i18n.tr('diary.lane_meals'),
          entries: meals,
          color: palette.meal,
          marks: [
            for (final meal in day.meals)
              (
                0,
                meal.minuteOfDay,
                meal.hasKnownProtein ? _Mark.mealKnown : _Mark.mealUnknown,
                null,
              ),
          ],
        ),
        _Lane(
          laneKey: 'motor',
          icon: Icons.accessibility_new_outlined,
          title: i18n.tr('diary.lane_motor'),
          entries: motor,
          color: palette.ink,
          marks: [
            for (final mark in day.motor)
              (
                0,
                mark.minuteOfDay,
                _motorMark(mark.state),
                mark.state == SelfReportedMotorState.uncertain
                    ? '?'
                    : diaryStateLabel(i18n, mark.state),
              ),
          ],
        ),
        if (day.motorWithoutState > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              i18n.tr('diary.motor_without_state', {
                'count': '${day.motorWithoutState}',
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.laneKey,
    required this.icon,
    required this.title,
    required this.entries,
    required this.marks,
    required this.color,
  });

  final String laneKey;
  final IconData icon;
  final String title;
  final List<String> entries;
  final List<(int, int, _Mark, String?)> marks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final theme = Theme.of(context);
    final palette = _Palette.of(context);
    final none = i18n.tr('diary.none');
    return Semantics(
      key: ValueKey('diary-lane-$laneKey'),
      container: true,
      label: '$title: ${entries.isEmpty ? none : entries.join('; ')}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: palette.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: CustomPaint(painter: _LanePainter(marks, palette)),
            ),
            const SizedBox(height: 6),
            if (entries.isEmpty)
              Text(
                none,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in entries)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.grid),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.ink,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Seven (or fewer) compact day rows; choosing a row shows that day.
class DiaryWeekRows extends StatelessWidget {
  const DiaryWeekRows({
    super.key,
    required this.projection,
    required this.selected,
    required this.onSelect,
  });

  final DiaryStripProjection projection;
  final LogCivilDate selected;
  final ValueChanged<LogCivilDate> onSelect;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final theme = Theme.of(context);
    final palette = _Palette.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(left: 72), child: const _Axis()),
        for (final day in projection.days.reversed)
          _weekRow(context, i18n, theme, palette, localizations, day),
        const SizedBox(height: 8),
        _Legend(palette: palette),
      ],
    );
  }

  Widget _weekRow(
    BuildContext context,
    AppI18n i18n,
    ThemeData theme,
    _Palette palette,
    MaterialLocalizations localizations,
    DiaryDay day,
  ) {
    final isSelected = day.date.compareTo(selected) == 0;
    final date = day.date.calendarValue;
    final label = i18n.tr('diary.week_row', {
      'date': localizations.formatFullDate(date),
      'doses': '${day.doses.length}',
      'meals': '${day.meals.length}',
      'on': '${day.motorCount(SelfReportedMotorState.on)}',
      'off': '${day.motorCount(SelfReportedMotorState.off)}',
      'uncertain': '${day.motorCount(SelfReportedMotorState.uncertain)}',
    });
    void select() => onSelect(day.date);
    return Semantics(
      key: ValueKey('diary-week-row-${day.date}'),
      button: true,
      selected: isSelected,
      label: label,
      onTap: select,
      excludeSemantics: true,
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withAlpha(28)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: select,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      '${localizations.narrowWeekdays[date.weekday % 7]} '
                      '${localizations.formatShortMonthDay(date)}',
                      maxLines: 2,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette.ink,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: CustomPaint(
                        painter: _LanePainter(
                          [
                            for (final dose in day.doses)
                              (0, dose.minuteOfDay, _Mark.dose, null),
                            for (final meal in day.meals)
                              (
                                1,
                                meal.minuteOfDay,
                                meal.hasKnownProtein
                                    ? _Mark.mealKnown
                                    : _Mark.mealUnknown,
                                null,
                              ),
                            for (final mark in day.motor)
                              (
                                2,
                                mark.minuteOfDay,
                                _motorMark(mark.state),
                                null,
                              ),
                          ],
                          palette,
                          rows: 3,
                          labels: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.palette});
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.ink);
    Widget item(_Mark mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CustomPaint(painter: _SwatchPainter(mark, palette)),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: style)),
      ],
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          item(_Mark.dose, i18n.tr('diary.legend_medication')),
          item(_Mark.mealKnown, i18n.tr('diary.legend_meal_known')),
          item(_Mark.mealUnknown, i18n.tr('diary.legend_meal_unknown')),
          item(_Mark.on, i18n.tr('diary.state_on')),
          item(_Mark.off, i18n.tr('diary.state_off')),
          item(_Mark.uncertain, i18n.tr('diary.state_uncertain')),
        ],
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.mark, this.palette);
  final _Mark mark;
  final _Palette palette;

  @override
  void paint(Canvas canvas, Size size) =>
      _paintMark(canvas, size.center(Offset.zero), mark, palette, scale: 0.8);

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.mark != mark || old.palette.ink != palette.ink;
}

/// Descriptive counts with the user-chosen meal filter and the boundary.
/// Without [onFilterChanged] the filter is shown as text only.
class DiaryCounts extends StatelessWidget {
  const DiaryCounts({
    super.key,
    required this.projection,
    this.onFilterChanged,
  });

  final DiaryStripProjection projection;
  final ValueChanged<int>? onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(i18n.tr('diary.counts_title'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          i18n.tr('diary.counts_range', {
            'start': '${projection.start}',
            'end': '${projection.end}',
            'zone': projection.zoneId,
          }),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(i18n.tr('diary.counts_filter')),
        if (onFilterChanged == null)
          Text(
            i18n.tr('diary.filter_option', {
              'grams': '${projection.proteinFilterG}',
            }),
          )
        else
          Wrap(
            spacing: 8,
            children: [
              for (final grams
                  in PersonalDiaryStripProjector.proteinFilterOptionsG)
                ChoiceChip(
                  key: ValueKey('diary-filter-$grams'),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  label: Text(
                    i18n.tr('diary.filter_option', {'grams': '$grams'}),
                  ),
                  selected: projection.proteinFilterG == grams,
                  onSelected: (_) => onFilterChanged!(grams),
                ),
            ],
          ),
        Text(
          i18n.tr('diary.counts_filter_note'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        for (final count in projection.counts) ...[
          Text(
            diaryCountLine(i18n, projection, count),
            key: ValueKey('diary-count-${count.state.name}'),
          ),
          if (count.unclassified > 0)
            Text(
              i18n.tr('diary.count_unclassified', {
                'count': '${count.unclassified}',
                'hours': '${projection.lookbackHours}',
              }),
              key: ValueKey('diary-unclassified-${count.state.name}'),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 4),
        ],
        if (projection.futureRecordCount > 0)
          Text(
            i18n.tr('diary.future_excluded', {
              'count': '${projection.futureRecordCount}',
            }),
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        Text(
          i18n.tr('diary.counts_boundary'),
          key: const ValueKey('diary-counts-boundary'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Day stepping with buttons only: previous (not before [earliest]), next
/// (not past [latest]) and, when [showToday], a jump back to [latest].
class DiaryDayStepper extends StatelessWidget {
  const DiaryDayStepper({
    super.key,
    required this.day,
    required this.latest,
    required this.onChanged,
    this.earliest,
    this.showToday = true,
  });

  final LogCivilDate day;
  final LogCivilDate latest;
  final LogCivilDate? earliest;
  final bool showToday;
  final ValueChanged<LogCivilDate> onChanged;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final localizations = MaterialLocalizations.of(context);
    final canNext = day.compareTo(latest) < 0;
    final canPrevious = earliest == null || day.compareTo(earliest!) > 0;
    const size = Size(_minTarget, _minTarget);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i18n.tr('diary.showing_day', {
            'date': localizations.formatFullDate(day.calendarValue),
          }),
          key: const ValueKey('diary-showing-day'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton.outlined(
              key: const ValueKey('diary-prev-day'),
              constraints: BoxConstraints.tight(size),
              tooltip: i18n.tr('diary.previous_day'),
              onPressed: canPrevious ? () => onChanged(day.addDays(-1)) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton.outlined(
              key: const ValueKey('diary-next-day'),
              constraints: BoxConstraints.tight(size),
              tooltip: i18n.tr('diary.next_day'),
              onPressed: canNext ? () => onChanged(day.addDays(1)) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            if (showToday)
              OutlinedButton(
                key: const ValueKey('diary-today'),
                style: OutlinedButton.styleFrom(minimumSize: size),
                onPressed: canNext ? () => onChanged(latest) : null,
                child: Text(i18n.tr('diary.today')),
              ),
          ],
        ),
      ],
    );
  }
}

/// The full strip: stepper, the shown day's lanes, the seven-day rows and the
/// counts. [onDayChanged] and [onFilterChanged] are null in read-only use.
class DiaryStripPanel extends StatelessWidget {
  const DiaryStripPanel({
    super.key,
    required this.projection,
    required this.shownDay,
    required this.latest,
    required this.onDayChanged,
    this.onFilterChanged,
    this.showMealTitles = true,
    this.earliest,
    this.showToday = true,
  });

  final DiaryStripProjection projection;
  final LogCivilDate shownDay;
  final LogCivilDate latest;
  final LogCivilDate? earliest;
  final bool showToday;
  final ValueChanged<LogCivilDate> onDayChanged;
  final ValueChanged<int>? onFilterChanged;
  final bool showMealTitles;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final theme = Theme.of(context);
    final day = projection.days.firstWhere(
      (day) => day.date.compareTo(shownDay) == 0,
      orElse: () => projection.days.last,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          i18n.tr('diary.subtitle', {'zone': projection.zoneId}),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        DiaryDayStepper(
          day: day.date,
          latest: latest,
          earliest: earliest,
          showToday: showToday,
          onChanged: onDayChanged,
        ),
        const SizedBox(height: 12),
        if (day.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              i18n.tr('diary.no_entries_day'),
              key: const ValueKey('diary-empty-day'),
            ),
          ),
        DiaryDayLanes(day: day, showMealTitles: showMealTitles),
        const Divider(height: 28),
        Text(i18n.tr('diary.week_title'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(i18n.tr('diary.week_subtitle'), style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        DiaryWeekRows(
          projection: projection,
          selected: day.date,
          onSelect: onDayChanged,
        ),
        const Divider(height: 28),
        DiaryCounts(projection: projection, onFilterChanged: onFilterChanged),
      ],
    );
  }
}
