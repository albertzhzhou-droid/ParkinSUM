import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/next_meal_plan.dart';
import '../../domain/usecases/physiology_reference_trace_provider.dart';

/// Colours of the Next-meal planner for the ambient brightness. The chart
/// colours are the physiology panel's light and dark tokens.
final class PlannerPalette {
  const PlannerPalette._({
    required this.dark,
    required this.surface,
    required this.sunken,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.infoSoft,
    required this.info,
    required this.warnSoft,
    required this.warn,
    required this.grid,
    required this.noMeal,
    required this.plate,
    required this.plateAlt,
    required this.dose,
  });

  final bool dark;
  final Color surface;
  final Color sunken;
  final Color border;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color infoSoft;
  final Color info;
  final Color warnSoft;
  final Color warn;
  final Color grid;
  final Color noMeal;
  final Color plate;
  final Color plateAlt;
  final Color dose;

  static PlannerPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const _light = PlannerPalette._(
    dark: false,
    surface: Paper.surface,
    sunken: Paper.surfaceSunken,
    border: Paper.border,
    ink: Paper.ink,
    muted: Paper.inkMuted,
    accent: Paper.accent,
    accentSoft: Paper.accentSoft,
    infoSoft: Paper.infoSoft,
    info: Paper.info,
    warnSoft: Paper.warningSoft,
    warn: Paper.warning,
    grid: Color(0xffe6dfd5),
    noMeal: Color(0xff2f6f5e),
    plate: Color(0xffb5562b),
    plateAlt: Color(0xff5b4fa3),
    dose: Color(0xff7a7068),
  );

  static const _dark = PlannerPalette._(
    dark: true,
    surface: Color(0xff23201c),
    sunken: Color(0xff2c2823),
    border: Color(0xff3a342e),
    ink: Color(0xffece6de),
    muted: Color(0xffa59b90),
    accent: Color(0xfff08a5d),
    accentSoft: Color(0xff3d2a20),
    infoSoft: Color(0xff1f2a36),
    info: Color(0xff9cbfe6),
    warnSoft: Color(0xff3a2f1b),
    warn: Color(0xffe0b84a),
    grid: Color(0xff3a342e),
    noMeal: Color(0xff6cc3a8),
    plate: Color(0xfff08a5d),
    plateAlt: Color(0xffa99cf0),
    dose: Color(0xffa59b90),
  );
}

/// Formats a ratio as a whole percentage.
String plannerPercent(double ratio) => (ratio * 100).round().toString();

/// "82" or "78–84": a range of whole percentages, one value when both ends
/// round to the same number.
String plannerPercentRange(double low, double high) {
  final a = plannerPercent(low);
  final b = plannerPercent(high);
  return a == b ? a : '$a–$b';
}

/// "meal 30 min after the dose" and its relatives.
String plannerOffsetText(AppI18n i18n, int offsetMinutes) {
  if (offsetMinutes == 0) return i18n.tr('planner.offset_same');
  return i18n.tr(
    offsetMinutes > 0 ? 'planner.offset_after' : 'planner.offset_before',
    {'minutes': '${offsetMinutes.abs()}'},
  );
}

/// What-if chart of a plate against no meal: plasma levodopa and the
/// brain-entry index over time relative to the dose, with population bands.
/// Every chart carries a text summary for screen readers, and the same
/// summary is printed under the charts.
class NextMealPlateChart extends StatelessWidget {
  const NextMealPlateChart({
    super.key,
    required this.curves,
    required this.i18n,
    required this.draws,
    required this.seed,
  });

  final NextMealPlateCurves curves;
  final AppI18n i18n;
  final int draws;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final palette = PlannerPalette.of(context);
    final scenarios = curves.scenarios;
    final effect = curves.effect;
    final offset = effect.offsetMinutes!;
    final first = scenarios.first;
    final times = first.timesMin;
    final xMin = times.first;
    final xMax = times.last;
    final altColor = scenarios.length > 1 ? palette.plateAlt : palette.plate;

    List<_Series> lines(
      PhysiologyBandedCurve Function(PhysiologyCurveComparison) meal,
      PhysiologyBandedCurve Function(PhysiologyCurveComparison) noMeal,
    ) => [
      for (var i = 0; i < scenarios.length; i++)
        _Series(
          xs: times,
          ys: meal(scenarios[i]).central,
          color: i == 0 ? palette.plate : altColor,
          dashed: false,
        ),
      _Series(
        xs: times,
        ys: noMeal(first).central,
        color: palette.noMeal,
        dashed: true,
      ),
    ];
    List<_Band> bands(
      PhysiologyBandedCurve Function(PhysiologyCurveComparison) meal,
      PhysiologyBandedCurve Function(PhysiologyCurveComparison) noMeal,
    ) => [
      _Band(
        xs: times,
        lo: noMeal(first).p05,
        hi: noMeal(first).p95,
        color: palette.noMeal,
      ),
      for (var i = 0; i < scenarios.length; i++)
        _Band(
          xs: times,
          lo: meal(scenarios[i]).p05,
          hi: meal(scenarios[i]).p95,
          color: i == 0 ? palette.plate : altColor,
        ),
    ];

    final levodopaMax = [
      for (final s in scenarios) ...s.levodopaMeal.p95,
      ...first.levodopaNoMeal.p95,
    ].reduce(math.max);
    final plateMax = [
      for (final s in scenarios) ...s.levodopaMeal.central,
    ].reduce(math.max);
    final noMealMax = first.levodopaNoMeal.central.reduce(math.max);
    final brainMin = [
      for (final s in scenarios) ...s.brainEntryMeal.p05,
    ].reduce(math.min);
    final plateBrainMin = [
      for (final s in scenarios) ...s.brainEntryMeal.central,
    ].reduce(math.min);
    final brainFloor = math.min(0.9, (brainMin * 10).floor() / 10);

    final summary = _summary(effect, offset);
    final range = {'start': '${xMin.round()}', 'end': '${xMax.round()}'};

    return DefaultTextStyle.merge(
      style: TextStyle(color: palette.ink),
      child: Column(
        key: const ValueKey('next-meal-plate-chart'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('planner.chart_title'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Legend(
                label: scenarios.length > 1
                    ? i18n.tr('planner.legend_solid')
                    : i18n.tr('planner.legend_plate'),
                color: palette.plate,
                dashed: false,
              ),
              if (scenarios.length > 1)
                _Legend(
                  label: i18n.tr('planner.legend_liquid'),
                  color: palette.plateAlt,
                  dashed: false,
                ),
              _Legend(
                label: i18n.tr('planner.legend_no_meal'),
                color: palette.noMeal,
                dashed: true,
              ),
              _Legend(
                label: i18n.tr('planner.legend_band'),
                color: palette.muted,
                band: true,
              ),
              _Legend(
                label: i18n.tr('planner.legend_meal_start'),
                color: palette.dose,
                marker: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Chart(
            id: 'levodopa',
            title: i18n.tr('planner.chart_levodopa'),
            semanticsLabel:
                '${i18n.tr('planner.chart_semantics_levodopa', {...range, 'plateMax': plateMax.toStringAsFixed(2), 'noMealMax': noMealMax.toStringAsFixed(2)})} $summary',
            lines: lines((s) => s.levodopaMeal, (s) => s.levodopaNoMeal),
            bands: bands((s) => s.levodopaMeal, (s) => s.levodopaNoMeal),
            xMin: xMin,
            xMax: xMax,
            yMin: 0,
            yMax: levodopaMax * 1.08,
            mealAt: offset.toDouble(),
            palette: palette,
          ),
          _Chart(
            id: 'brain-entry',
            title: i18n.tr('planner.chart_brain'),
            semanticsLabel:
                '${i18n.tr('planner.chart_semantics_brain', {...range, 'plateMin': plateBrainMin.toStringAsFixed(2)})} $summary',
            lines: lines((s) => s.brainEntryMeal, (s) => s.brainEntryNoMeal),
            bands: bands((s) => s.brainEntryMeal, (s) => s.brainEntryNoMeal),
            xMin: xMin,
            xMax: xMax,
            yMin: brainFloor,
            yMax: 1.05,
            mealAt: offset.toDouble(),
            palette: palette,
          ),
          Center(
            child: Text(
              i18n.tr('planner.chart_x'),
              style: TextStyle(fontSize: 11, color: palette.muted),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            key: const ValueKey('next-meal-plate-chart-summary'),
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            i18n.tr('planner.chart_boundary', {
              'draws': '$draws',
              'seed': '$seed',
            }),
            style: TextStyle(fontSize: 11, color: palette.muted, height: 1.35),
          ),
        ],
      ),
    );
  }

  String _summary(NextMealModeledEffect effect, int offset) {
    final band = effect.band!;
    final values = {
      'offset': plannerOffsetText(i18n, offset),
      'low': plannerPercent(band.p05),
      'high': plannerPercent(band.p95),
    };
    if (effect.bracketed) {
      return i18n.tr('planner.chart_summary_bracketed', {
        ...values,
        'range': plannerPercentRange(effect.centralLow!, effect.centralHigh!),
        'plasmaRange': plannerPercentRange(
          effect.plasmaLow!,
          effect.plasmaHigh!,
        ),
      });
    }
    return i18n.tr('planner.chart_summary', {
      ...values,
      'percent': plannerPercent(effect.centralLow!),
      'plasma': plannerPercent(effect.plasmaLow!),
      'plasmaLow': plannerPercent(effect.plasmaBand!.p05),
      'plasmaHigh': plannerPercent(effect.plasmaBand!.p95),
    });
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.label,
    required this.color,
    this.dashed = false,
    this.band = false,
    this.marker = false,
  });

  final String label;
  final Color color;
  final bool dashed;
  final bool band;
  final bool marker;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 12,
            child: CustomPaint(
              painter: _SwatchPainter(
                color: color,
                dashed: dashed,
                band: band,
                marker: marker,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({
    required this.color,
    required this.dashed,
    required this.band,
    required this.marker,
  });

  final Color color;
  final bool dashed;
  final bool band;
  final bool marker;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    if (band) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = color.withValues(alpha: 0.25),
      );
      return;
    }
    if (marker) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint,
      );
      return;
    }
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 5, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) =>
      old.color != color || old.dashed != dashed;
}

class _Series {
  const _Series({
    required this.xs,
    required this.ys,
    required this.color,
    required this.dashed,
  });

  final List<double> xs;
  final List<double> ys;
  final Color color;
  final bool dashed;
}

class _Band {
  const _Band({
    required this.xs,
    required this.lo,
    required this.hi,
    required this.color,
  });

  final List<double> xs;
  final List<double> lo;
  final List<double> hi;
  final Color color;
}

class _Chart extends StatelessWidget {
  const _Chart({
    required this.id,
    required this.title,
    required this.semanticsLabel,
    required this.lines,
    required this.bands,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.mealAt,
    required this.palette,
  });

  final String id;
  final String title;
  final String semanticsLabel;
  final List<_Series> lines;
  final List<_Band> bands;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final double mealAt;
  final PlannerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: palette.muted)),
          const SizedBox(height: 4),
          Semantics(
            key: ValueKey('next-meal-chart-$id'),
            label: semanticsLabel,
            image: true,
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _ChartPainter(
                  lines: lines,
                  bands: bands,
                  xMin: xMin,
                  xMax: xMax,
                  yMin: yMin,
                  yMax: yMax,
                  mealAt: mealAt,
                  palette: palette,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.lines,
    required this.bands,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.mealAt,
    required this.palette,
  });

  final List<_Series> lines;
  final List<_Band> bands;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final double mealAt;
  final PlannerPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(40, 6, size.width - 8, size.height - 18);
    double mapX(double x) =>
        plot.left + ((x - xMin) / (xMax - xMin)).clamp(0.0, 1.0) * plot.width;
    double mapY(double y) =>
        plot.bottom -
        ((y - yMin) / (yMax - yMin)).clamp(0.0, 1.0) * plot.height;

    final grid = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final value = yMin + (yMax - yMin) * i / 2;
      final y = mapY(value);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(canvas, _tick(value), Offset(plot.left - 4, y), alignRight: true);
    }
    final firstTick = (xMin / 60).ceil() * 60;
    for (var t = firstTick; t <= xMax; t += 60) {
      _label(
        canvas,
        '$t',
        Offset(mapX(t.toDouble()), plot.bottom + 9),
        center: true,
      );
    }

    for (final band in bands) {
      final path = Path()..moveTo(mapX(band.xs.first), mapY(band.hi.first));
      for (var i = 1; i < band.xs.length; i++) {
        path.lineTo(mapX(band.xs[i]), mapY(band.hi[i]));
      }
      for (var i = band.xs.length - 1; i >= 0; i--) {
        path.lineTo(mapX(band.xs[i]), mapY(band.lo[i]));
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = band.color.withValues(alpha: palette.dark ? 0.22 : 0.16),
      );
    }

    // Dose at zero, meal start at its offset.
    final markerPaint = Paint()
      ..color = palette.dose
      ..strokeWidth = 1;
    for (final x in {0.0, mealAt}) {
      final px = mapX(x);
      for (var y = plot.top; y < plot.bottom; y += 6) {
        canvas.drawLine(
          Offset(px, y),
          Offset(px, math.min(y + 3, plot.bottom)),
          markerPaint,
        );
      }
    }

    for (final item in lines) {
      final path = Path();
      for (var i = 0; i < item.xs.length; i++) {
        final point = Offset(mapX(item.xs[i]), mapY(item.ys[i]));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      final paint = Paint()
        ..color = item.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      if (!item.dashed) {
        canvas.drawPath(path, paint);
        continue;
      }
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 10) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + 6, metric.length)),
            paint,
          );
        }
      }
    }
  }

  static String _tick(double value) => value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: Paper.sans,
          fontSize: 9,
          color: palette.muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? anchor.dx - painter.width
        : center
        ? anchor.dx - painter.width / 2
        : anchor.dx;
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.lines != lines ||
      old.bands != bands ||
      old.mealAt != mealAt ||
      old.palette != palette;
}
