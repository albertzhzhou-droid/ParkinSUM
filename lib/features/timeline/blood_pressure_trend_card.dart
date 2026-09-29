import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/personal_observation.dart';
import '../../domain/usecases/blood_pressure_trend_projection.dart';

class BloodPressureTrendCard extends StatelessWidget {
  final BloodPressureTrendProjection projection;
  final bool chinese;
  final bool canExportCollection;
  final VoidCallback onExportCollection;

  const BloodPressureTrendCard({
    super.key,
    required this.projection,
    required this.chinese,
    required this.canExportCollection,
    required this.onExportCollection,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final systolicColor = colors.primary;
    final diastolicColor = colors.tertiary;
    final observations = projection.observations;

    return Card(
      key: const ValueKey('blood-pressure-trend-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chinese ? '血压记录趋势' : 'Blood-pressure readings over time',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              chinese
                  ? '按发生时间从旧到新展示最近 ${observations.length} 条观察。横向位置仅表示先后顺序，不表示测量间隔；纵轴按当前数值缩放。仅连接相邻的已测读数；未知或未测会断开曲线。图中没有临床阈值或判断。'
                  : 'Shows the ${observations.length} most recent observations from older to newer by occurrence time. Horizontal positions show sequence only, not elapsed time; the vertical axis scales to these values. Lines connect adjacent measured readings only; unknown or not-measured entries break the line. No clinical thresholds or interpretation are applied.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _LegendItem(
                  color: systolicColor,
                  label: chinese ? '收缩压' : 'Systolic',
                ),
                _LegendItem(
                  color: diastolicColor,
                  label: chinese ? '舒张压' : 'Diastolic',
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (projection.recordedCount == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  chinese
                      ? '此范围内没有带数值的血压记录。未知和未测记录仍保留在下方明细中。'
                      : 'There are no numeric readings in this window. Unknown and not-measured entries remain in the details below.',
                ),
              )
            else
              _BloodPressureChart(
                projection: projection,
                systolicColor: systolicColor,
                diastolicColor: diastolicColor,
                textColor: colors.onSurfaceVariant,
                gridColor: colors.outlineVariant,
                textStyle:
                    textTheme.labelSmall ?? const TextStyle(fontSize: 11),
                chinese: chinese,
              ),
            const SizedBox(height: 6),
            Text(
              chinese
                  ? '本窗口：${projection.recordedCount} 条已测，${projection.unknownCount} 条未知，${projection.notMeasuredCount} 条未测。'
                        '${projection.omittedObservationCount > 0 ? ' 另有 ${projection.omittedObservationCount} 条较早观察仍在时间线中。' : ''}'
                  : 'In this window: ${projection.recordedCount} measured, ${projection.unknownCount} unknown, ${projection.notMeasuredCount} not measured.'
                        '${projection.omittedObservationCount > 0 ? ' ${projection.omittedObservationCount} earlier observations remain in the timeline.' : ''}',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: const ValueKey('fhir-bp-export-collection'),
                onPressed: canExportCollection ? onExportCollection : null,
                icon: const Icon(Icons.ios_share_outlined),
                label: Text(
                  chinese
                      ? '导出最近记录为 FHIR 集合'
                      : 'Export recent readings as FHIR collection',
                ),
              ),
            ),
            ExpansionTile(
              key: const ValueKey('blood-pressure-trend-details'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(chinese ? '查看记录明细' : 'View reading details'),
              children: [
                for (final observation in observations.reversed)
                  _ObservationDetail(
                    observation: observation,
                    chinese: chinese,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label),
    ],
  );
}

class _BloodPressureChart extends StatelessWidget {
  final BloodPressureTrendProjection projection;
  final Color systolicColor;
  final Color diastolicColor;
  final Color textColor;
  final Color gridColor;
  final TextStyle textStyle;
  final bool chinese;

  const _BloodPressureChart({
    required this.projection,
    required this.systolicColor,
    required this.diastolicColor,
    required this.textColor,
    required this.gridColor,
    required this.textStyle,
    required this.chinese,
  });

  @override
  Widget build(BuildContext context) {
    final accessibleReadings = projection.observations
        .map((item) {
          final time = '${item.occurredAt.toIso8601String()} UTC';
          final value = item.status == PersonalObservationStatus.recorded
              ? '${_formatNumber(item.systolic!)} / ${_formatNumber(item.diastolic!)} mmHg'
              : _statusLabel(item.status, chinese);
          return '$time (${item.originalTimezone}): $value';
        })
        .join('; ');
    final chartLabel = chinese
        ? '血压序列图，按发生时间从旧到新。纵轴为毫米汞柱；横轴为记录顺序。$accessibleReadings'
        : 'Blood-pressure sequence chart, oldest to newest by occurrence time. Vertical axis is mmHg; horizontal axis is record order. $accessibleReadings';

    return Semantics(
      key: const ValueKey('blood-pressure-trend-chart'),
      container: true,
      label: chartLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 164,
          child: CustomPaint(
            key: const ValueKey('blood-pressure-trend-painter'),
            painter: _BloodPressureChartPainter(
              observations: projection.observations,
              systolicColor: systolicColor,
              diastolicColor: diastolicColor,
              textColor: textColor,
              gridColor: gridColor,
              textStyle: textStyle,
              olderLabel: chinese ? '较早' : 'Older',
              newerLabel: chinese ? '较新' : 'Newer',
            ),
          ),
        ),
      ),
    );
  }
}

class _BloodPressureChartPainter extends CustomPainter {
  final List<PersonalObservation> observations;
  final Color systolicColor;
  final Color diastolicColor;
  final Color textColor;
  final Color gridColor;
  final TextStyle textStyle;
  final String olderLabel;
  final String newerLabel;

  const _BloodPressureChartPainter({
    required this.observations,
    required this.systolicColor,
    required this.diastolicColor,
    required this.textColor,
    required this.gridColor,
    required this.textStyle,
    required this.olderLabel,
    required this.newerLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final item in observations)
        if (item.status == PersonalObservationStatus.recorded) ...[
          item.systolic!,
          item.diastolic!,
        ],
    ];
    if (values.isEmpty || size.width <= 48 || size.height <= 36) return;

    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    final span = math.max(rawMax - rawMin, 10.0);
    final padding = span * 0.1;
    final minValue = math.max(0.0, ((rawMin - padding) / 10).floor() * 10.0);
    final maxValue = ((rawMax + padding) / 10).ceil() * 10.0;
    final safeMax = maxValue > minValue ? maxValue : minValue + 10;
    final plot = Rect.fromLTRB(42, 10, size.width - 8, size.height - 24);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final textColorStyle = textStyle.copyWith(color: textColor);
    for (final value in [safeMax, minValue]) {
      final y = _y(value, minValue, safeMax, plot);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _drawText(
        canvas,
        _formatNumber(value),
        Offset(0, y - 7),
        textColorStyle,
        width: plot.left - 5,
        align: TextAlign.right,
      );
    }
    _drawText(
      canvas,
      'mmHg',
      const Offset(0, 0),
      textColorStyle,
      width: plot.left - 5,
      align: TextAlign.right,
    );
    _drawText(
      canvas,
      olderLabel,
      Offset(plot.left, plot.bottom + 4),
      textColorStyle,
      width: plot.width / 2,
    );
    _drawText(
      canvas,
      newerLabel,
      Offset(plot.center.dx, plot.bottom + 4),
      textColorStyle,
      width: plot.width / 2,
      align: TextAlign.right,
    );

    _drawSeries(
      canvas,
      plot,
      minValue,
      safeMax,
      systolicColor,
      (item) => item.systolic,
    );
    _drawSeries(
      canvas,
      plot,
      minValue,
      safeMax,
      diastolicColor,
      (item) => item.diastolic,
    );
  }

  void _drawSeries(
    Canvas canvas,
    Rect plot,
    double minValue,
    double maxValue,
    Color color,
    double? Function(PersonalObservation) valueOf,
  ) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    Offset? previous;
    for (var index = 0; index < observations.length; index++) {
      final item = observations[index];
      final value = item.status == PersonalObservationStatus.recorded
          ? valueOf(item)
          : null;
      if (value == null) {
        previous = null;
        continue;
      }
      final xFraction = observations.length == 1
          ? 0.5
          : index / (observations.length - 1);
      final point = Offset(
        plot.left + plot.width * xFraction,
        _y(value, minValue, maxValue, plot),
      );
      if (previous != null) canvas.drawLine(previous, point, line);
      canvas.drawCircle(point, 3.5, dot);
      previous = point;
    }
  }

  double _y(double value, double minValue, double maxValue, Rect plot) =>
      plot.bottom - (value - minValue) / (maxValue - minValue) * plot.height;

  void _drawText(
    Canvas canvas,
    String value,
    Offset offset,
    TextStyle style, {
    required double width,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _BloodPressureChartPainter oldDelegate) =>
      oldDelegate.observations != observations ||
      oldDelegate.systolicColor != systolicColor ||
      oldDelegate.diastolicColor != diastolicColor ||
      oldDelegate.textColor != textColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.textStyle != textStyle ||
      oldDelegate.olderLabel != olderLabel ||
      oldDelegate.newerLabel != newerLabel;
}

class _ObservationDetail extends StatelessWidget {
  final PersonalObservation observation;
  final bool chinese;

  const _ObservationDetail({required this.observation, required this.chinese});

  @override
  Widget build(BuildContext context) {
    final value = observation.status == PersonalObservationStatus.recorded
        ? '${_formatNumber(observation.systolic!)} / ${_formatNumber(observation.diastolic!)} mmHg'
        : _statusLabel(observation.status, chinese);
    final occurred = '${observation.occurredAt.toIso8601String()} UTC';
    final recorded = '${observation.recordedAt.toIso8601String()} UTC';
    final source = switch (observation.source) {
      PersonalObservationSource.selfReported =>
        chinese ? '本人自报' : 'Self-reported',
      PersonalObservationSource.deviceManual =>
        chinese ? '手动抄录设备读数' : 'Device reading entered manually',
      PersonalObservationSource.caregiverReported =>
        chinese ? '照护者报告' : 'Reported by a caregiver',
    };
    final posture = switch (observation.posture) {
      BloodPressurePosture.sitting => chinese ? '坐位' : 'Sitting',
      BloodPressurePosture.standing => chinese ? '立位' : 'Standing',
      BloodPressurePosture.lying => chinese ? '卧位' : 'Lying',
      BloodPressurePosture.unknown ||
      null => chinese ? '体位未知' : 'Posture unknown',
    };
    return ListTile(
      key: ValueKey('bp-trend-record-${observation.id}'),
      dense: true,
      title: Text(value),
      subtitle: Text(
        chinese
            ? '发生：$occurred（原始时区 ${observation.originalTimezone}）\n记录：$recorded · $source · $posture'
            : 'Occurred: $occurred (original timezone ${observation.originalTimezone})\nRecorded: $recorded · $source · $posture',
      ),
    );
  }
}

String _formatNumber(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toString();

String _statusLabel(PersonalObservationStatus status, bool chinese) =>
    switch (status) {
      PersonalObservationStatus.recorded => chinese ? '已测' : 'Measured',
      PersonalObservationStatus.notMeasured => chinese ? '未测量' : 'Not measured',
      PersonalObservationStatus.unknown => chinese ? '未知' : 'Unknown',
    };
