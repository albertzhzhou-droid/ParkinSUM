import 'package:flutter/material.dart';

import '../../domain/entities/personal_observation.dart';
import '../../domain/entities/personal_observation_event_ledger.dart';

class PersonalObservationEventLedgerCard extends StatelessWidget {
  const PersonalObservationEventLedgerCard({
    super.key,
    required this.ledger,
    required this.chinese,
  });

  final PersonalObservationEventLedger ledger;
  final bool chinese;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recentEvents = ledger.events.reversed.take(8).toList();
    return Card(
      key: const ValueKey('personal-observation-event-ledger-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chinese ? '观察事件审计投影' : 'Observation event audit projection',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              chinese
                  ? '从当前账号持有人录入的 ${ledger.events.length} 条观察记录生成，只读保存在内存中。症状标签、备注、录入者 ID 和账号 ID 均不进入投影；ID 以 SHA-256 形式保留为记录令牌。'
                  : 'Read-only in-memory projection of ${ledger.events.length} observations entered by the active account holder. Symptom labels, notes, recorder IDs, and account IDs are omitted; record identity is represented by a SHA-256 token.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SelectableText(
              '${chinese ? '投影 SHA-256' : 'Projection SHA-256'}: ${ledger.sha256Digest}',
              key: const ValueKey('personal-observation-ledger-digest'),
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(
              chinese
                  ? '来源内容未经独立核实；所记录的时区名称只是录入时声明，未用时区数据库验证。此投影不作临床解释、不联网、不额外写入存储，也不会进入预测或建议计算。'
                  : 'Source claims are not independently verified. A recorded timezone name is retained as declared and is not checked against a timezone database. This projection has no clinical interpretation, network access, additional storage write, or prediction/recommendation input.',
              style: textTheme.bodySmall,
            ),
            ExpansionTile(
              key: const ValueKey('personal-observation-ledger-events'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                chinese
                    ? '查看最近 ${recentEvents.length} 条（共 ${ledger.events.length} 条）'
                    : 'Inspect the latest ${recentEvents.length} of ${ledger.events.length} events',
                style: textTheme.labelLarge,
              ),
              children: [
                for (final event in recentEvents) _eventTile(context, event),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventTile(
    BuildContext context,
    PersonalObservationLedgerEvent event,
  ) {
    final title = switch (event.kind) {
      PersonalObservationKind.symptom => chinese ? '症状记录' : 'Symptom entry',
      PersonalObservationKind.selfReportedMotorState =>
        chinese ? '自报运动状态' : 'Self-reported motor state',
      PersonalObservationKind.bloodPressure =>
        chinese ? '血压记录' : 'Blood pressure',
    };
    final status = switch (event.status) {
      PersonalObservationStatus.recorded => chinese ? '已记录' : 'Recorded',
      PersonalObservationStatus.unknown => chinese ? '未知' : 'Unknown',
      PersonalObservationStatus.notMeasured => chinese ? '未测量' : 'Not measured',
    };
    final source = switch (event.source) {
      PersonalObservationSource.selfReported =>
        chinese ? '本人自报' : 'Self-reported',
      PersonalObservationSource.deviceManual =>
        chinese ? '手动录入设备读数' : 'Device reading entered manually',
      PersonalObservationSource.caregiverReported =>
        chinese ? '照护者报告' : 'Caregiver-reported',
    };
    final measurements = event.measurements.map(_measurementText).join(' · ');
    final motorState = event.motorState == null
        ? null
        : switch (event.motorState!) {
            SelfReportedMotorState.on => chinese ? 'ON' : 'ON',
            SelfReportedMotorState.off => chinese ? 'OFF' : 'OFF',
            SelfReportedMotorState.uncertain => chinese ? '不确定' : 'Uncertain',
          };
    final posture = event.posture == null
        ? null
        : switch (event.posture!) {
            BloodPressurePosture.sitting => chinese ? '坐位' : 'Sitting',
            BloodPressurePosture.standing => chinese ? '立位' : 'Standing',
            BloodPressurePosture.lying => chinese ? '卧位' : 'Lying',
            BloodPressurePosture.unknown =>
              chinese ? '体位未知' : 'Posture unknown',
          };
    final details = <String>[
      if (measurements.isNotEmpty) measurements,
      ?motorState,
      ?posture,
      if (event.labelOmitted) chinese ? '症状标签已省略' : 'Symptom label omitted',
      if (event.synthetic) chinese ? '合成测试记录' : 'Synthetic fixture',
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('$title · $status'),
      subtitle: Text(
        <String>[
          '${chinese ? '发生' : 'Occurred'}: ${event.occurredAtUtc.toIso8601String()}',
          '${chinese ? '录入' : 'Recorded'}: ${event.recordedAtUtc.toIso8601String()}',
          '${chinese ? '声明时区' : 'Declared timezone'}: ${event.declaredTimezone}',
          '${chinese ? '来源' : 'Source'}: $source',
          ...details,
        ].join('\n'),
      ),
    );
  }

  String _measurementText(PersonalObservationLedgerMeasurement measurement) {
    final name = switch (measurement.id) {
      'systolic' => chinese ? '收缩压' : 'Systolic',
      'diastolic' => chinese ? '舒张压' : 'Diastolic',
      'severity' => chinese ? '自报严重度' : 'Reported severity',
      _ => measurement.id,
    };
    if (measurement.state ==
        PersonalObservationLedgerMeasurementState.unknown) {
      return '$name · ${chinese ? '未知' : 'Unknown'}';
    }
    if (measurement.state ==
        PersonalObservationLedgerMeasurementState.notCollected) {
      return '$name · ${chinese ? '未测量' : 'Not measured'}';
    }
    if (measurement.id == 'severity') {
      return '$name · ${_number(measurement.originalValue!)}/10';
    }
    return '$name · ${_number(measurement.originalValue!)} ${measurement.originalUnit} '
        '→ ${_number(measurement.canonicalValue!)} ${measurement.canonicalUnit}';
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
