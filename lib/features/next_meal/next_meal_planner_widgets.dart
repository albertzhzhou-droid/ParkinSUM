import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/models/food_item.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/food_serving_reference.dart';
import '../../domain/entities/next_meal_plan.dart';
import '../../domain/entities/personal_diary_strip.dart';
import '../../domain/usecases/next_meal_planner.dart';
import 'next_meal_plate_chart.dart';

// Presentation of the Next-meal planner. Values come from NextMealPlanner;
// these widgets format them, never order or score foods, and keep every
// control a button (no drag-only gesture) at least 48 px tall.

String _two(int n) => n.toString().padLeft(2, '0');

/// "08:30".
String plannerClockText(DateTime local) =>
    '${_two(local.hour)}:${_two(local.minute)}';

String _number(double value, {int digits = 1}) => value.toStringAsFixed(digits);

/// A card surface that follows the ambient brightness.
class PlannerCard extends StatelessWidget {
  const PlannerCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = PlannerPalette.of(context);
    // A Material surface, so list tiles and ink inside paint on the card.
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Paper.radiusLg),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: palette.ink),
          child: child,
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );
}

enum PlannerChipTone { neutral, protein, energy, info, warn }

/// Compact value chip. Not interactive.
class PlannerChip extends StatelessWidget {
  const PlannerChip({
    super.key,
    required this.label,
    this.tone = PlannerChipTone.neutral,
    this.icon,
    this.semanticsLabel,
  });

  final String label;
  final PlannerChipTone tone;
  final IconData? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = PlannerPalette.of(context);
    final (bg, fg) = switch (tone) {
      PlannerChipTone.neutral => (p.sunken, p.ink),
      PlannerChipTone.protein => (
        p.accentSoft,
        p.dark ? p.accent : Paper.accentInk,
      ),
      PlannerChipTone.energy => (p.warnSoft, p.warn),
      PlannerChipTone.info => (p.infoSoft, p.info),
      PlannerChipTone.warn => (p.sunken, p.muted),
    };
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Paper.radiusXs),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Can't model: no levodopa dose is logged; …".
String plannerCantModelText(
  AppI18n i18n,
  List<NextMealUnavailableReason> reasons,
) => i18n.tr('planner.cant_model', {
  'reason': reasons
      .map((r) => i18n.tr('planner.reason.${r.wireName}'))
      .join('; '),
});

/// The modeled-effect sentence for a food or plate, or the reason it is not
/// shown.
String plannerEffectText(AppI18n i18n, NextMealModeledEffect effect) {
  if (!effect.modeled) return plannerCantModelText(i18n, effect.reasons);
  final band = effect.band;
  if (effect.bracketed) {
    return i18n.tr('planner.modeled_entry_bracketed', {
      'range': plannerPercentRange(effect.centralLow!, effect.centralHigh!),
      'low': band == null ? '?' : plannerPercent(band.p05),
      'high': band == null ? '?' : plannerPercent(band.p95),
    });
  }
  return i18n.tr('planner.modeled_entry', {
    'percent': plannerPercent(effect.centralLow!),
    'low': band == null ? '?' : plannerPercent(band.p05),
    'high': band == null ? '?' : plannerPercent(band.p95),
  });
}

/// One modeled-effect line, styled by availability.
class PlannerEffectLine extends StatelessWidget {
  const PlannerEffectLine({
    super.key,
    required this.i18n,
    required this.effect,
  });

  final AppI18n i18n;
  final NextMealModeledEffect effect;

  @override
  Widget build(BuildContext context) {
    final text = plannerEffectText(i18n, effect);
    return PlannerChip(
      label: text,
      tone: effect.modeled ? PlannerChipTone.info : PlannerChipTone.warn,
      icon: effect.modeled ? Icons.show_chart_rounded : Icons.block_outlined,
      semanticsLabel: effect.modeled
          ? '$text. ${i18n.tr('planner.modeled_semantics_suffix')}'
          : text,
    );
  }
}

// -----------------------------------------------------------------------------
// Day strip and day context.
// -----------------------------------------------------------------------------

/// Today's logged doses and meals on a 24-hour line, with the current time
/// and the planned meal, followed by descriptive protein totals.
class PlannerDayStrip extends StatelessWidget {
  const PlannerDayStrip({
    super.key,
    required this.i18n,
    required this.day,
    required this.nowMinute,
    required this.plannedMinute,
  });

  final AppI18n i18n;

  /// Null when today's records cannot be projected (for example an
  /// unavailable time zone).
  final DiaryDay? day;
  final int nowMinute;

  /// Null when the planned time is on another day.
  final int? plannedMinute;

  String _clock(int minute) => '${_two(minute ~/ 60)}:${_two(minute % 60)}';

  @override
  Widget build(BuildContext context) {
    final palette = PlannerPalette.of(context);
    final doses = day?.doses ?? const <DiaryDoseMark>[];
    final meals = day?.meals ?? const <DiaryMealMark>[];
    final known = meals.where((m) => m.hasKnownProtein);
    final unknown = meals.length - known.length;
    final protein = known.fold<double>(0, (sum, m) => sum + m.proteinG!);
    String times(Iterable<int> minutes) => minutes.isEmpty
        ? ''
        : i18n.tr('planner.strip_at', {
            'times': minutes.map(_clock).join(', '),
          });
    final semantics = i18n.tr('planner.strip_semantics', {
      'doses': '${doses.length}',
      'doseTimes': times(doses.map((d) => d.minuteOfDay)),
      'meals': '${meals.length}',
      'mealTimes': times(meals.map((m) => m.minuteOfDay)),
      'now': _clock(nowMinute),
      'planned': plannedMinute == null ? '—' : _clock(plannedMinute!),
    });
    return PlannerCard(
      key: const ValueKey('next-meal-day-strip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(i18n.tr('planner.today_title')),
          const SizedBox(height: 10),
          Semantics(
            label: semantics,
            image: true,
            child: SizedBox(
              height: 46,
              child: CustomPaint(
                painter: _StripPainter(
                  doses: [for (final d in doses) d.minuteOfDay],
                  meals: [for (final m in meals) m.minuteOfDay],
                  now: nowMinute,
                  planned: plannedMinute,
                  palette: palette,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _StripKey(
                  color: palette.plateAlt,
                  label: i18n.tr('planner.legend_dose'),
                  shape: _KeyShape.dose,
                ),
                _StripKey(
                  color: palette.noMeal,
                  label: i18n.tr('planner.legend_meal'),
                  shape: _KeyShape.meal,
                ),
                _StripKey(
                  color: palette.muted,
                  label: i18n.tr('planner.now'),
                  shape: _KeyShape.line,
                ),
                _StripKey(
                  color: palette.accent,
                  label: i18n.tr('planner.planned_marker'),
                  shape: _KeyShape.line,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              PlannerChip(
                label: i18n.tr('planner.today_doses', {
                  'count': '${doses.length}',
                }),
              ),
              PlannerChip(
                label: i18n.tr('planner.today_meals', {
                  'count': '${meals.length}',
                }),
              ),
            ],
          ),
          if (meals.isEmpty && doses.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              i18n.tr('planner.no_entries_today'),
              style: TextStyle(fontSize: 13, color: palette.muted),
            ),
          ],
          if (meals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              unknown == 0
                  ? i18n.tr('planner.today_protein_total', {
                      'grams': _number(protein),
                    })
                  : i18n.tr('planner.today_protein_partial', {
                      'grams': _number(protein),
                      'count': '$unknown',
                    }),
              key: const ValueKey('next-meal-day-protein'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            for (final meal in meals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  i18n.tr('planner.today_meal_line', {
                    'time': _clock(meal.minuteOfDay),
                    'title': meal.title,
                    'protein': meal.hasKnownProtein
                        ? i18n.tr('diary.protein_known', {
                            'grams': _number(meal.proteinG!),
                          })
                        : i18n.tr('diary.protein_unknown'),
                  }),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            i18n.tr('planner.context_note'),
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

enum _KeyShape { dose, meal, line }

class _StripKey extends StatelessWidget {
  const _StripKey({
    required this.color,
    required this.label,
    required this.shape,
  });

  final Color color;
  final String label;
  final _KeyShape shape;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: shape == _KeyShape.line ? 3 : 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: shape == _KeyShape.meal ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
      const SizedBox(width: 4),
      Flexible(child: Text(label, style: const TextStyle(fontSize: 11))),
    ],
  );
}

class _StripPainter extends CustomPainter {
  const _StripPainter({
    required this.doses,
    required this.meals,
    required this.now,
    required this.planned,
    required this.palette,
  });

  final List<int> doses;
  final List<int> meals;
  final int now;
  final int? planned;
  final PlannerPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 4.0;
    final right = size.width - 4;
    double x(int minute) => left + (minute / 1440) * (right - left);
    final axisY = size.height - 14;
    canvas.drawLine(
      Offset(left, axisY),
      Offset(right, axisY),
      Paint()
        ..color = palette.border
        ..strokeWidth = 2,
    );
    for (var h = 0; h <= 24; h += 6) {
      final px = x(h * 60);
      canvas.drawLine(
        Offset(px, axisY - 3),
        Offset(px, axisY + 3),
        Paint()..color = palette.muted,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _two(h % 24 == 0 && h == 24 ? 24 : h),
          style: TextStyle(
            fontFamily: Paper.sans,
            fontSize: 9,
            color: palette.muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((px - tp.width / 2).clamp(0, size.width - tp.width), axisY + 4),
      );
    }
    final nowPaint = Paint()
      ..color = palette.muted
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x(now), 2), Offset(x(now), axisY), nowPaint);
    if (planned != null) {
      canvas.drawLine(
        Offset(x(planned!), 2),
        Offset(x(planned!), axisY),
        Paint()
          ..color = palette.accent
          ..strokeWidth = 3,
      );
    }
    for (final m in meals) {
      canvas.drawCircle(
        Offset(x(m), axisY - 18),
        6,
        Paint()..color = palette.noMeal,
      );
    }
    for (final d in doses) {
      final px = x(d);
      final path = Path()
        ..moveTo(px, axisY - 12)
        ..lineTo(px - 6, axisY - 2)
        ..lineTo(px + 6, axisY - 2)
        ..close();
      canvas.drawPath(path, Paint()..color = palette.plateAlt);
    }
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) =>
      old.now != now ||
      old.planned != planned ||
      old.doses.length != doses.length ||
      old.meals.length != meals.length ||
      old.palette != palette;
}

// -----------------------------------------------------------------------------
// Planned time.
// -----------------------------------------------------------------------------

/// Planned meal time: −15 / +15 buttons, a typed time and anchors taken from
/// logged doses. There is no default "good" time.
class PlannerTimeCard extends StatefulWidget {
  const PlannerTimeCard({
    super.key,
    required this.i18n,
    required this.plannedText,
    required this.onStep,
    required this.onTyped,
    required this.anchors,
    required this.onAnchor,
    required this.contextLine,
  });

  final AppI18n i18n;
  final String plannedText;
  final ValueChanged<int> onStep;

  /// Returns false when the typed text is not a valid time.
  final bool Function(int hour, int minute) onTyped;
  final NextMealTimeAnchors anchors;

  /// Sets the planned time to an anchor plus minutes.
  final void Function(DateTime anchor, int plusMinutes) onAnchor;
  final Widget contextLine;

  @override
  State<PlannerTimeCard> createState() => _PlannerTimeCardState();
}

class _PlannerTimeCardState extends State<PlannerTimeCard> {
  bool _typing = false;
  String? _error;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final match = RegExp(
      r'^\s*(\d{1,2})[:：](\d{2})\s*$',
    ).firstMatch(_controller.text);
    final hour = match == null ? null : int.parse(match.group(1)!);
    final minute = match == null ? null : int.parse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      setState(() => _error = widget.i18n.tr('planner.time_field_invalid'));
      return;
    }
    widget.onTyped(hour, minute);
    setState(() {
      _typing = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    final palette = PlannerPalette.of(context);
    final last = widget.anchors.lastDoseAt;
    final next = widget.anchors.nextDoseAt;
    return PlannerCard(
      key: const ValueKey('next-meal-time-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(i18n.tr('planner.time_title')),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final minus = _StepButton(
                key: const ValueKey('next-meal-time-minus'),
                label: '−15',
                semanticsLabel: i18n.tr('planner.time_minus'),
                onPressed: () => widget.onStep(-15),
              );
              final plus = _StepButton(
                key: const ValueKey('next-meal-time-plus'),
                label: '+15',
                semanticsLabel: i18n.tr('planner.time_plus'),
                onPressed: () => widget.onStep(15),
              );
              final time = Semantics(
                liveRegion: true,
                label: i18n.tr('planner.time_title'),
                value: widget.plannedText,
                excludeSemantics: true,
                child: Text(
                  widget.plannedText,
                  key: const ValueKey('next-meal-planned-time'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              );
              // With large text on a narrow screen the time sits above the
              // two buttons instead of between them.
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              if (constraints.maxWidth < 200 + 120 * textScale) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    time,
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      spacing: 8,
                      runSpacing: 8,
                      children: [minus, plus],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  minus,
                  Expanded(child: time),
                  plus,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          if (!_typing)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                key: const ValueKey('next-meal-time-type'),
                onPressed: () => setState(() => _typing = true),
                icon: const Icon(Icons.keyboard_outlined),
                label: Text(i18n.tr('planner.time_type')),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('next-meal-time-field'),
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.datetime,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9:：]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: InputDecoration(
                      labelText: i18n.tr('planner.time_field_label'),
                      errorText: _error,
                      errorMaxLines: 3,
                    ),
                    onSubmitted: (_) => _apply(),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilledButton(
                    key: const ValueKey('next-meal-time-apply'),
                    onPressed: _apply,
                    child: Text(i18n.tr('planner.time_apply')),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('planner.anchor_title'),
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const ValueKey('next-meal-anchor-last'),
                onPressed: last == null ? null : () => widget.onAnchor(last, 0),
                child: Text(i18n.tr('planner.anchor_last_dose')),
              ),
              OutlinedButton(
                key: const ValueKey('next-meal-anchor-after-last'),
                onPressed: last == null
                    ? null
                    : () => widget.onAnchor(last, 30),
                child: Text(i18n.tr('planner.anchor_after_last_dose')),
              ),
              OutlinedButton(
                key: const ValueKey('next-meal-anchor-next'),
                onPressed: next == null ? null : () => widget.onAnchor(next, 0),
                child: Text(i18n.tr('planner.anchor_next_dose')),
              ),
            ],
          ),
          if (last == null || next == null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (last == null) i18n.tr('planner.anchor_none_last'),
                if (next == null) i18n.tr('planner.anchor_none_next'),
              ].join(' '),
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ],
          const SizedBox(height: 10),
          widget.contextLine,
          const SizedBox(height: 8),
          Text(
            i18n.tr('planner.time_neutral_note'),
            style: TextStyle(fontSize: 12, color: palette.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticsLabel,
    excludeSemantics: true,
    child: Tooltip(
      message: semanticsLabel,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Food card.
// -----------------------------------------------------------------------------

String plannerServingText(AppI18n i18n, NextMealCandidate c) {
  final grams = c.serving.grams;
  if (grams == null) return i18n.tr('planner.per_100g_unknown');
  return i18n.tr('planner.per_serving', {
    'grams': grams.toStringAsFixed(0),
    'basis': i18n.tr(
      c.serving.basis == FoodServingBasis.sourcePortion
          ? 'serving.basis.source_portion'
          : 'serving.basis.category_default',
    ),
  });
}

String plannerProteinText(AppI18n i18n, double? grams) => grams == null
    ? i18n.tr('planner.chip_protein_unknown')
    : i18n.tr('planner.chip_protein', {'value': _number(grams)});

String plannerEnergyText(
  AppI18n i18n,
  NextMealCandidate c, {
  double servings = 1,
}) {
  final kcal = c.energyKcal;
  if (kcal == null) return i18n.tr('planner.chip_energy_unknown');
  return i18n.tr(
    c.energyDerived ? 'planner.chip_energy_derived' : 'planner.chip_energy',
    {'value': (kcal * servings).toStringAsFixed(0)},
  );
}

String plannerLnaaText(AppI18n i18n, NextMealCandidate c) =>
    switch (c.lnaaBasis) {
      NextMealLnaaBasis.measured => i18n.tr('planner.chip_lnaa', {
        'value': _number(c.lnaaG!, digits: 2),
      }),
      NextMealLnaaBasis.estimatedFromProtein => i18n.tr(
        'planner.chip_lnaa_estimated',
        {'value': _number(c.lnaaG!, digits: 2)},
      ),
      NextMealLnaaBasis.unknown => i18n.tr('planner.chip_lnaa_unknown'),
    };

String plannerTextureText(AppI18n i18n, FoodItem food) {
  final texture = switch (food.textureClass) {
    null => i18n.tr('planner.texture_unknown'),
    'liquid' => i18n.tr('planner.texture_liquid'),
    'soft' => i18n.tr('planner.texture_soft'),
    _ => i18n.tr('planner.texture_regular'),
  };
  final level = food.iddsiLevel;
  return level == null
      ? texture
      : '$texture · ${i18n.tr('planner.iddsi', {'level': '$level'})}';
}

String plannerCompletenessSemantics(AppI18n i18n, NextMealCandidate c) =>
    c.missingFields.isEmpty
    ? i18n.tr('planner.completeness_full', {
        'present': '${c.presentFieldCount}',
        'total': '${NextMealDataFields.all.length}',
      })
    : i18n.tr('planner.completeness_semantics', {
        'present': '${c.presentFieldCount}',
        'total': '${NextMealDataFields.all.length}',
        'missing': c.missingFields
            .map((f) => i18n.tr('planner.field.$f'))
            .join(', '),
      });

class PlannerFoodCard extends StatelessWidget {
  const PlannerFoodCard({
    super.key,
    required this.i18n,
    required this.candidate,
    required this.name,
    required this.effect,
    required this.onPlate,
    required this.pinned,
    required this.onTogglePlate,
    required this.onTogglePin,
    this.evidenceText,
    this.lastEatenText,
    this.alternativesCount,
    this.onToggleAlternatives,
    this.alternativesDeck,
  });

  final AppI18n i18n;
  final NextMealCandidate candidate;
  final String name;
  final NextMealModeledEffect effect;
  final bool onPlate;
  final bool pinned;
  final VoidCallback onTogglePlate;
  final VoidCallback onTogglePin;

  /// Regional or own-meal evidence, nutrition only.
  final String? evidenceText;
  final String? lastEatenText;
  final int? alternativesCount;
  final VoidCallback? onToggleAlternatives;

  /// Shown under the card when the user opened its alternatives.
  final Widget? alternativesDeck;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final palette = PlannerPalette.of(context);
    return PlannerCard(
      key: ValueKey('next-meal-food-${c.id}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              if (c.familiar) ...[
                const SizedBox(width: 8),
                PlannerChip(
                  label: i18n.tr('planner.familiar', {
                    'count': '${c.timesLogged}',
                  }),
                  icon: Icons.history_rounded,
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            plannerServingText(i18n, c),
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PlannerChip(
                label: plannerProteinText(i18n, c.proteinG),
                tone: PlannerChipTone.protein,
              ),
              PlannerChip(
                label: plannerEnergyText(i18n, c),
                tone: PlannerChipTone.energy,
              ),
              PlannerChip(label: plannerLnaaText(i18n, c)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PlannerChip(
                label: plannerTextureText(i18n, c.food),
                icon: Icons.texture_rounded,
              ),
              PlannerChip(
                label:
                    '${i18n.sourceSystemLabel(c.food.sourceSystem)} · '
                    '${i18n.regionLabel(c.food.jurisdiction)}',
                icon: Icons.menu_book_outlined,
              ),
              PlannerChip(
                key: ValueKey('next-meal-completeness-${c.id}'),
                label: i18n.tr('planner.completeness', {
                  'present': '${c.presentFieldCount}',
                  'total': '${NextMealDataFields.all.length}',
                }),
                icon: c.completeData
                    ? Icons.check_circle_outline
                    : Icons.data_usage_rounded,
                semanticsLabel: plannerCompletenessSemantics(i18n, c),
              ),
            ],
          ),
          if (evidenceText != null || lastEatenText != null) ...[
            const SizedBox(height: 6),
            Text(
              [?evidenceText, ?lastEatenText].join(' · '),
              key: ValueKey('next-meal-evidence-${c.id}'),
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ],
          const SizedBox(height: 8),
          KeyedSubtree(
            key: ValueKey('next-meal-effect-${c.id}'),
            child: PlannerEffectLine(i18n: i18n, effect: effect),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Semantics(
                button: true,
                toggled: onPlate,
                label: onPlate
                    ? '${i18n.tr('planner.on_plate')}: $name'
                    : i18n.tr('planner.add_to_plate_named', {'name': name}),
                excludeSemantics: true,
                child: FilledButton.tonalIcon(
                  key: ValueKey('next-meal-add-${c.id}'),
                  onPressed: onTogglePlate,
                  icon: Icon(onPlate ? Icons.check_rounded : Icons.add_rounded),
                  label: Text(
                    onPlate
                        ? i18n.tr('planner.on_plate')
                        : i18n.tr('planner.add_to_plate'),
                  ),
                ),
              ),
              Semantics(
                button: true,
                toggled: pinned,
                label: pinned
                    ? '${i18n.tr('planner.unpin')}: $name'
                    : i18n.tr('planner.pin_named', {'name': name}),
                excludeSemantics: true,
                child: TextButton.icon(
                  key: ValueKey('next-meal-pin-${c.id}'),
                  onPressed: onTogglePin,
                  icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
                  label: Text(
                    pinned ? i18n.tr('planner.unpin') : i18n.tr('planner.pin'),
                  ),
                ),
              ),
              if (onToggleAlternatives != null)
                TextButton.icon(
                  key: ValueKey('next-meal-alternatives-${c.id}'),
                  onPressed: onToggleAlternatives,
                  icon: const Icon(Icons.style_outlined),
                  label: Text(
                    i18n.tr('planner.alternatives', {
                      'count': '${alternativesCount ?? 0}',
                    }),
                  ),
                ),
            ],
          ),
          ?alternativesDeck,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Plate.
// -----------------------------------------------------------------------------

String plannerTotalText(
  AppI18n i18n,
  NextMealNutrientTotal total, {
  bool kcal = false,
  int digits = 1,
}) {
  final value = i18n.tr(kcal ? 'planner.total_kcal' : 'planner.total_grams', {
    'value': total.known.toStringAsFixed(kcal ? 0 : digits),
  });
  return total.complete
      ? value
      : i18n.tr('planner.total_unknown', {
          'value': value,
          'count': '${total.unknownItemCount}',
        });
}

class PlannerPlateItemRow extends StatelessWidget {
  const PlannerPlateItemRow({
    super.key,
    required this.i18n,
    required this.item,
    required this.name,
    required this.onLess,
    required this.onMore,
    required this.onRemove,
    this.onAlternatives,
    this.alternativesDeck,
  });

  final AppI18n i18n;
  final NextMealPlateItem item;
  final String name;
  final VoidCallback? onLess;
  final VoidCallback? onMore;
  final VoidCallback onRemove;
  final VoidCallback? onAlternatives;
  final Widget? alternativesDeck;

  @override
  Widget build(BuildContext context) {
    final palette = PlannerPalette.of(context);
    final servings = item.servings == item.servings.roundToDouble()
        ? item.servings.toStringAsFixed(0)
        : item.servings.toStringAsFixed(1);
    final grams = item.candidate.serving.evaluatedGrams * item.servings;
    final row = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${i18n.tr('planner.servings', {'count': servings})} · '
                '${grams.toStringAsFixed(0)} g · '
                '${plannerProteinText(i18n, item.candidate.proteinG == null ? null : item.candidate.proteinG! * item.servings)}',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('next-meal-less-${item.candidate.id}'),
          tooltip: i18n.tr('planner.servings_less', {'name': name}),
          onPressed: onLess,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        IconButton(
          key: ValueKey('next-meal-more-${item.candidate.id}'),
          tooltip: i18n.tr('planner.servings_more', {'name': name}),
          onPressed: onMore,
          icon: const Icon(Icons.add_circle_outline),
        ),
        if (onAlternatives != null)
          IconButton(
            key: ValueKey('next-meal-plate-alternatives-${item.candidate.id}'),
            tooltip: i18n.tr('planner.alternatives_title'),
            onPressed: onAlternatives,
            icon: const Icon(Icons.style_outlined),
          ),
        IconButton(
          key: ValueKey('next-meal-remove-${item.candidate.id}'),
          tooltip: i18n.tr('planner.remove', {'name': name}),
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
    return Padding(
      key: ValueKey('next-meal-plate-item-${item.candidate.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [row, ?alternativesDeck],
      ),
    );
  }
}

class PlannerTotals extends StatelessWidget {
  const PlannerTotals({super.key, required this.i18n, required this.totals});

  final AppI18n i18n;
  final NextMealPlateTotals totals;

  @override
  Widget build(BuildContext context) {
    final palette = PlannerPalette.of(context);
    final rows = [
      ('planner.total_protein', plannerTotalText(i18n, totals.protein)),
      (
        'planner.total_carbohydrate',
        plannerTotalText(i18n, totals.carbohydrate),
      ),
      ('planner.total_fat', plannerTotalText(i18n, totals.fat)),
      (
        'planner.total_energy',
        plannerTotalText(i18n, totals.energy, kcal: true),
      ),
      ('planner.total_lnaa', plannerTotalText(i18n, totals.lnaa, digits: 2)),
    ];
    return Container(
      key: const ValueKey('next-meal-plate-totals'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.sunken,
        borderRadius: BorderRadius.circular(Paper.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('planner.totals'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final (key, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i18n.tr(key),
                      style: TextStyle(fontSize: 13, color: palette.muted),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Compare.
// -----------------------------------------------------------------------------

/// One pinned food or plate with the same rows as every other.
class PlannerCompareColumn extends StatelessWidget {
  const PlannerCompareColumn({
    super.key,
    required this.i18n,
    required this.title,
    required this.subtitle,
    required this.totals,
    required this.effect,
    required this.dataText,
    required this.onUnpin,
  });

  final AppI18n i18n;
  final String title;
  final String subtitle;
  final NextMealPlateTotals totals;
  final NextMealModeledEffect effect;
  final String dataText;
  final VoidCallback onUnpin;

  String _modeled() {
    if (!effect.modeled) {
      return i18n.tr('planner.compare_not_modeled', {
        'reason': effect.reasons
            .map((r) => i18n.tr('planner.reason.${r.wireName}'))
            .join('; '),
      });
    }
    final band = effect.band!;
    return effect.bracketed
        ? i18n.tr('planner.compare_value_bracket', {
            'range': plannerPercentRange(
              effect.centralLow!,
              effect.centralHigh!,
            ),
            'low': plannerPercent(band.p05),
            'high': plannerPercent(band.p95),
          })
        : i18n.tr('planner.compare_value_band', {
            'percent': plannerPercent(effect.centralLow!),
            'low': plannerPercent(band.p05),
            'high': plannerPercent(band.p95),
          });
  }

  String _plasma() {
    if (!effect.modeled) return '—';
    final band = effect.plasmaBand!;
    return effect.bracketed
        ? i18n.tr('planner.compare_value_bracket', {
            'range': plannerPercentRange(effect.plasmaLow!, effect.plasmaHigh!),
            'low': plannerPercent(band.p05),
            'high': plannerPercent(band.p95),
          })
        : i18n.tr('planner.compare_value_band', {
            'percent': plannerPercent(effect.plasmaLow!),
            'low': plannerPercent(band.p05),
            'high': plannerPercent(band.p95),
          });
  }

  @override
  Widget build(BuildContext context) {
    final palette = PlannerPalette.of(context);
    final rows = [
      ('planner.compare_protein', plannerTotalText(i18n, totals.protein)),
      (
        'planner.compare_energy',
        plannerTotalText(i18n, totals.energy, kcal: true),
      ),
      ('planner.compare_lnaa', plannerTotalText(i18n, totals.lnaa, digits: 2)),
      ('planner.compare_modeled', _modeled()),
      ('planner.compare_plasma', _plasma()),
      ('planner.compare_data', dataText),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 12),
      decoration: BoxDecoration(
        color: palette.sunken,
        borderRadius: BorderRadius.circular(Paper.radiusMd),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '${i18n.tr('planner.unpin')}: $title',
                onPressed: onUnpin,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          for (final (key, value) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr(key),
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Alternatives (nutrition only) and evidence lines.
// -----------------------------------------------------------------------------

String _signed(double value, int digits) {
  final text = value.abs().toStringAsFixed(digits);
  if (double.parse(text) == 0) return '±$text';
  return value > 0 ? '+$text' : '−$text';
}

/// "Seen in 3 of your logged or imported meals", "Listed in USDA FoodData
/// Central (United States)" or "No evidence for United States".
String plannerEvidenceText(
  AppI18n i18n,
  NextMealCandidate c,
  Set<String> regions,
) {
  if (c.familiar) {
    return i18n.tr('planner.evidence_seen', {'count': '${c.timesLogged}'});
  }
  if (regions.contains(c.food.jurisdiction.toUpperCase())) {
    return i18n.tr('planner.evidence_listed', {
      'source': i18n.sourceSystemLabel(c.food.sourceSystem),
      'region': i18n.regionLabel(c.food.jurisdiction),
    });
  }
  return i18n.tr('planner.evidence_none', {
    'regions': regions.map(i18n.regionLabel).join(', '),
  });
}

/// "Last eaten 2 days ago", or null when the food is not in the user's meals.
String? plannerLastEatenText(AppI18n i18n, int? days) => switch (days) {
  null => null,
  0 => i18n.tr('planner.last_eaten_today'),
  1 => i18n.tr('planner.last_eaten_one'),
  _ => i18n.tr('planner.last_eaten_days', {'days': '$days'}),
};

/// A deck of alternatives in the same nutritional position, one card at a
/// time, moved with previous / next buttons (no swipe-only control).
class PlannerAlternativesDeck extends StatelessWidget {
  const PlannerAlternativesDeck({
    super.key,
    required this.i18n,
    required this.deckKey,
    required this.original,
    required this.alternatives,
    required this.index,
    required this.regions,
    required this.nameOf,
    required this.onIndex,
    required this.actionLabel,
    required this.actionSemantics,
    required this.onAction,
    required this.onClose,
  });

  final AppI18n i18n;
  final String deckKey;
  final NextMealCandidate original;
  final List<NextMealAlternative> alternatives;
  final int index;
  final Set<String> regions;
  final String Function(NextMealCandidate) nameOf;
  final ValueChanged<int> onIndex;
  final String actionLabel;
  final String Function(NextMealCandidate) actionSemantics;
  final ValueChanged<NextMealCandidate> onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = PlannerPalette.of(context);
    final p0 = original.proteinG;
    final e0 = original.energyKcal;
    Widget frame(List<Widget> children) => Container(
      key: ValueKey('next-meal-alternatives-$deckKey'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: palette.sunken,
        borderRadius: BorderRadius.circular(Paper.radiusMd),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    i18n.tr('planner.alternatives_title'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('next-meal-alt-close-$deckKey'),
                tooltip: i18n.tr('planner.alt_close'),
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
    if (alternatives.isEmpty) {
      return frame([
        Text(
          i18n.tr('planner.alternatives_none'),
          style: TextStyle(fontSize: 13, color: palette.muted),
        ),
      ]);
    }
    final i = index.clamp(0, alternatives.length - 1);
    final alt = alternatives[i];
    final c = alt.candidate;
    final name = nameOf(c);
    final position = i18n.tr('planner.alt_position', {
      'index': '${i + 1}',
      'count': '${alternatives.length}',
    });
    return frame([
      Row(
        children: [
          IconButton(
            key: ValueKey('next-meal-alt-prev-$deckKey'),
            tooltip: i18n.tr('planner.alt_previous'),
            onPressed: i > 0 ? () => onIndex(i - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                position,
                key: ValueKey('next-meal-alt-position-$deckKey'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('next-meal-alt-next-$deckKey'),
            tooltip: i18n.tr('planner.alt_next'),
            onPressed: i < alternatives.length - 1
                ? () => onIndex(i + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      Container(
        key: ValueKey('next-meal-alt-card-$deckKey-${c.id}'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(Paper.radiusSm),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              plannerServingText(i18n, c),
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PlannerChip(
                  label: i18n.tr('planner.delta_protein', {
                    'value': _signed(alt.proteinDeltaG, 1),
                  }),
                  tone: PlannerChipTone.protein,
                ),
                PlannerChip(
                  label: i18n.tr('planner.delta_energy', {
                    'value': _signed(alt.energyDeltaKcal, 0),
                  }),
                  tone: PlannerChipTone.energy,
                ),
                PlannerChip(
                  label: alt.lnaaDeltaG == null
                      ? i18n.tr('planner.delta_lnaa_unknown')
                      : i18n.tr('planner.delta_lnaa', {
                          'value': _signed(alt.lnaaDeltaG!, 2),
                        }),
                ),
                PlannerChip(
                  label: alt.sameTexture
                      ? i18n.tr('planner.delta_texture_same')
                      : i18n.tr('planner.delta_texture', {
                          'texture': plannerTextureText(i18n, c.food),
                        }),
                  icon: Icons.texture_rounded,
                ),
                PlannerChip(
                  label: i18n.tr('planner.delta_data', {
                    'present': '${c.presentFieldCount}',
                    'total': '${NextMealDataFields.all.length}',
                    'value': alt.completenessDelta == 0
                        ? '±0'
                        : (alt.completenessDelta > 0
                              ? '+${alt.completenessDelta}'
                              : '−${-alt.completenessDelta}'),
                  }),
                  semanticsLabel: plannerCompletenessSemantics(i18n, c),
                ),
                PlannerChip(
                  label: i18n.tr('planner.alt_closeness', {
                    'score': '${(alt.closeness * 100).round()}',
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              plannerEvidenceText(i18n, c, regions),
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: actionSemantics(c),
              excludeSemantics: true,
              child: FilledButton.tonal(
                key: ValueKey('next-meal-alt-action-$deckKey'),
                onPressed: () => onAction(c),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
      if (p0 != null && e0 != null) ...[
        const SizedBox(height: 8),
        Text(
          i18n.tr('planner.alternatives_rule', {
            'protein': NextMealPlanner.proteinTolerance(p0).toStringAsFixed(1),
            'energy': NextMealPlanner.energyTolerance(e0).toStringAsFixed(0),
          }),
          style: TextStyle(fontSize: 11, color: palette.muted, height: 1.35),
        ),
      ],
    ]);
  }
}
