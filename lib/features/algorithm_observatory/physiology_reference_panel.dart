import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/paper_theme.dart';
import '../../domain/entities/physiology_reference_parameters.dart';
import '../../domain/usecases/physiology_reference_trace_provider.dart';

/// Observatory panel for the physiology reference model: a synthetic dose
/// with a meal at different times, in physical units, with seeded population
/// bands. Descriptive only; it ranks nothing and names no best time.
class PhysiologyReferencePanel extends StatelessWidget {
  final PhysiologyReferenceTraceProvider provider;

  PhysiologyReferencePanel({
    super.key,
    PhysiologyReferenceTraceProvider? provider,
  }) : provider = provider ?? PhysiologyReferenceTraceProvider.shared;

  @override
  Widget build(BuildContext context) {
    final palette = _PhysiologyPalette.of(Theme.of(context).brightness);
    // "No meal" is drawn last and dashed so it stays visible where curves
    // coincide, as in tool/physiology_reference/whatif.py.
    final rows = provider.observatoryRows;
    final ordered = [...rows.where((r) => r.mealOffsetMin != null), rows.first];
    Color colorOf(PhysiologyTimingRow row) => switch (row.mealOffsetMin) {
      null => palette.c0,
      < 0.0 => palette.c1,
      0.0 => palette.c2,
      _ => palette.c3,
    };
    List<_UnitSeries> seriesFor(String key) => [
      for (final row in ordered)
        _UnitSeries(
          color: colorOf(row),
          dashed: row.mealOffsetMin == null,
          xs: row.central.series.t,
          ys: row.central.series[key],
        ),
    ];
    final levodopaMax =
        rows.map((r) => r.central.cmaxMgPerL).reduce(math.max) * 1.1;
    final lnaa = [
      for (final row in rows) ...row.central.series['lnaa6_umol_per_l'],
    ];
    final lnaaMin = (lnaa.reduce(math.min) / 50).floor() * 50.0;
    final lnaaMax = (lnaa.reduce(math.max) / 50).ceil() * 50.0;
    final noMeal = rows.first;

    return PaperCard(
      key: const Key('chart-panel-physiology-reference'),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: palette.fg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Physiology reference model (physical units)',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Synthetic ${physiologyReferenceDoseMg.round()} mg '
              'immediate-release levodopa dose at minute 0; ~600 kcal, 30 g '
              'protein meal at different times. Lines use central '
              'parameters; the table gives the median and the 5th–95th '
              'percentile of ${provider.draws} seeded draws '
              '(seed ${provider.seed}).',
              style: const TextStyle(color: Paper.inkMuted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final row in rows)
                  _Legend(
                    label: row.label,
                    color: colorOf(row),
                    dashed: row.mealOffsetMin == null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _UnitChart(
              id: 'levodopa',
              title: 'Plasma levodopa (mg/L)',
              semanticsLabel:
                  'Plasma levodopa in milligrams per litre over 360 minutes '
                  'after the dose for no meal and three meal timings. No '
                  'meal peaks at ${noMeal.central.cmaxMgPerL.toStringAsFixed(2)} '
                  'mg/L at minute ${noMeal.central.tmaxMin.round()}.',
              series: seriesFor('levodopa_mg_per_l'),
              yMin: 0,
              yMax: levodopaMax,
              palette: palette,
            ),
            _UnitChart(
              id: 'lnaa',
              title: 'Plasma large neutral amino acids, six summed (µmol/L)',
              semanticsLabel:
                  'Sum of six plasma large neutral amino acids in micromoles '
                  'per litre; flat at the fasting value with no meal and '
                  'rising after each meal.',
              series: seriesFor('lnaa6_umol_per_l'),
              yMin: lnaaMin,
              yMax: lnaaMax,
              palette: palette,
            ),
            _UnitChart(
              id: 'brain-entry',
              title:
                  'Brain-entry index, levodopa relative to the fasting state '
                  '(axis starts at 0.6)',
              semanticsLabel:
                  'Brain-entry index between 0.6 and 1.05; 1 with no meal, '
                  'lower while meal amino acids compete at the blood-brain '
                  'barrier.',
              series: seriesFor('brain_entry_index'),
              yMin: 0.6,
              yMax: 1.05,
              palette: palette,
            ),
            Center(
              child: Text(
                'Minutes after the dose',
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
            ),
            const SizedBox(height: 10),
            _BandTable(rows: rows),
            const SizedBox(height: 8),
            Text(
              'Brain delivery is the 0–4 h area of plasma levodopa × '
              'brain-entry index, relative to the same draw with no meal. '
              'Parameters ${PhysiologyReferenceParameterSet.parameterSetVersion}: '
              'the blood-brain-barrier Km set and fasting amino-acid values '
              'are still marked "verify". Population-typical curves from a '
              'research prototype checked against published group data; not '
              'a prediction for any person, not a motor response, and not '
              'timing, dosing or dietary advice.',
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhysiologyPalette {
  final Color fg;
  final Color muted;
  final Color grid;
  final Color c0;
  final Color c1;
  final Color c2;
  final Color c3;

  const _PhysiologyPalette({
    required this.fg,
    required this.muted,
    required this.grid,
    required this.c0,
    required this.c1,
    required this.c2,
    required this.c3,
  });

  /// The light and dark tokens of the reference what-if SVG.
  static _PhysiologyPalette of(Brightness brightness) =>
      brightness == Brightness.dark
      ? const _PhysiologyPalette(
          fg: Color(0xffece6de),
          muted: Color(0xffa59b90),
          grid: Color(0xff3a342e),
          c0: Color(0xff6cc3a8),
          c1: Color(0xfff08a5d),
          c2: Color(0xffa99cf0),
          c3: Color(0xffe0b84a),
        )
      : const _PhysiologyPalette(
          fg: Color(0xff2b2622),
          muted: Color(0xff7a7068),
          grid: Color(0xffe6dfd5),
          c0: Color(0xff2f6f5e),
          c1: Color(0xffb5562b),
          c2: Color(0xff5b4fa3),
          c3: Color(0xffa07a17),
        );
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  final bool dashed;

  const _Legend({
    required this.label,
    required this.color,
    required this.dashed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 8,
          child: CustomPaint(
            painter: _UnitChartPainter(
              series: [
                _UnitSeries(
                  color: color,
                  dashed: dashed,
                  xs: const [0, 1],
                  ys: const [0.5, 0.5],
                ),
              ],
              yMin: 0,
              yMax: 1,
              xMax: 1,
              palette: null,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

class _UnitSeries {
  final Color color;
  final bool dashed;
  final List<double> xs;
  final List<double> ys;

  const _UnitSeries({
    required this.color,
    required this.dashed,
    required this.xs,
    required this.ys,
  });
}

class _UnitChart extends StatelessWidget {
  final String id;
  final String title;
  final String semanticsLabel;
  final List<_UnitSeries> series;
  final double yMin;
  final double yMax;
  final _PhysiologyPalette palette;

  const _UnitChart({
    required this.id,
    required this.title,
    required this.semanticsLabel,
    required this.series,
    required this.yMin,
    required this.yMax,
    required this.palette,
  });

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
            key: Key('physiology-reference-chart-$id'),
            label: semanticsLabel,
            image: true,
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _UnitChartPainter(
                  series: series,
                  yMin: yMin,
                  yMax: yMax,
                  xMax: 360,
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

class _UnitChartPainter extends CustomPainter {
  final List<_UnitSeries> series;
  final double yMin;
  final double yMax;
  final double xMax;

  /// Null draws only the lines (legend swatches).
  final _PhysiologyPalette? palette;

  const _UnitChartPainter({
    required this.series,
    required this.yMin,
    required this.yMax,
    required this.xMax,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final axes = palette;
    final plot = axes == null
        ? Offset.zero & size
        : Rect.fromLTRB(40, 6, size.width - 8, size.height - 18);
    double mapX(double x) =>
        plot.left + (x / xMax).clamp(0.0, 1.0) * plot.width;
    double mapY(double y) =>
        plot.bottom -
        ((y - yMin) / (yMax - yMin)).clamp(0.0, 1.0) * plot.height;

    if (axes != null) {
      final grid = Paint()
        ..color = axes.grid
        ..strokeWidth = 1;
      for (var i = 0; i <= 2; i++) {
        final value = yMin + (yMax - yMin) * i / 2;
        final y = mapY(value);
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
        _label(
          canvas,
          _tick(value),
          Offset(plot.left - 4, y),
          axes.muted,
          alignRight: true,
        );
      }
      for (var t = 0; t <= xMax; t += 60) {
        _label(
          canvas,
          '$t',
          Offset(mapX(t.toDouble()), plot.bottom + 9),
          axes.muted,
          center: true,
        );
      }
    }

    for (final item in series) {
      final path = Path();
      var started = false;
      for (var i = 0; i < item.xs.length; i += 3) {
        final x = item.xs[i];
        if (x < 0 || x > xMax) continue;
        final point = Offset(mapX(x), mapY(item.ys[i]));
        if (!started) {
          path.moveTo(point.dx, point.dy);
          started = true;
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

  static void _label(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color, {
    bool alignRight = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 9, color: color),
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
  bool shouldRepaint(covariant _UnitChartPainter oldDelegate) =>
      oldDelegate.series != series ||
      oldDelegate.yMin != yMin ||
      oldDelegate.yMax != yMax ||
      oldDelegate.palette != palette;
}

class _BandTable extends StatelessWidget {
  final List<PhysiologyTimingRow> rows;

  const _BandTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    String band(
      PhysiologyTimingRow row,
      String key,
      String Function(double) f,
    ) {
      final b = row.bands[key];
      return b == null ? 'reference' : '${f(b.p50)} (${f(b.p05)}–${f(b.p95)})';
    }

    String percent(double x) => '${(x * 100).round()}%';
    const header = TextStyle(fontSize: 11, fontWeight: FontWeight.w700);
    const cell = TextStyle(fontSize: 11);
    return SingleChildScrollView(
      key: const Key('physiology-reference-band-table'),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 36,
        columnSpacing: 14,
        columns: const [
          DataColumn(label: Text('Scenario', style: header)),
          DataColumn(label: Text('Peak time (min)', style: header)),
          DataColumn(label: Text('Peak (mg/L)', style: header)),
          DataColumn(
            label: Text('Lowest brain-entry index, 0–4 h', style: header),
          ),
          DataColumn(
            label: Text(
              'Peak gastric energy delivery (kcal/min)',
              style: header,
            ),
          ),
          DataColumn(
            label: Text('Brain delivery 0–4 h vs no meal', style: header),
          ),
        ],
        rows: [
          for (final row in rows)
            DataRow(
              cells: [
                DataCell(Text(row.label, style: cell)),
                DataCell(
                  Text(
                    band(row, 'tmax_min', (x) => x.toStringAsFixed(0)),
                    style: cell,
                  ),
                ),
                DataCell(
                  Text(
                    band(row, 'cmax_mg_per_l', (x) => x.toStringAsFixed(2)),
                    style: cell,
                  ),
                ),
                DataCell(
                  Text(
                    band(
                      row,
                      'brain_entry_index_min_0_4h',
                      (x) => x.toStringAsFixed(2),
                    ),
                    style: cell,
                  ),
                ),
                DataCell(
                  Text(
                    row.central.peakEnergyOutKcalPerMin.toStringAsFixed(2),
                    style: cell,
                  ),
                ),
                DataCell(
                  Text(
                    band(row, 'brain_delivery_area_vs_no_meal', percent),
                    style: cell,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
