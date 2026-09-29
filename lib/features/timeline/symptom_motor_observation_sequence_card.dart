import 'package:flutter/material.dart';

import '../../domain/entities/personal_observation.dart';
import '../../domain/usecases/symptom_motor_observation_projection.dart';

class SymptomMotorObservationSequenceCard extends StatelessWidget {
  final SymptomMotorObservationProjection projection;
  final bool chinese;
  final bool canExportCollection;
  final VoidCallback onExportCollection;

  const SymptomMotorObservationSequenceCard({
    super.key,
    required this.projection,
    required this.chinese,
    required this.canExportCollection,
    required this.onExportCollection,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final observations = projection.observations;
    final sourceLabels = <PersonalObservationSource, String>{
      PersonalObservationSource.selfReported: chinese
          ? '本人自报'
          : 'Self-reported',
      PersonalObservationSource.deviceManual: chinese
          ? '手动录入设备读数'
          : 'Device reading entered manually',
      PersonalObservationSource.caregiverReported: chinese
          ? '照护者报告（由账号持有人录入）'
          : 'Caregiver-reported (entered by account holder)',
    };

    return Card(
      key: const ValueKey('symptom-motor-observation-sequence-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chinese ? '症状与运动状态记录' : 'Symptom and movement-state records',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              chinese
                  ? '按发生时间从旧到新显示最近 ${observations.length} 条。顺序只表示先后，不表示测量间隔，也不代表与餐食或用药存在因果关系。来源为账号内选择，未经独立核实；此视图不作临床解释。'
                  : 'Shows the ${observations.length} most recent entries in occurrence order. Order does not represent measurement intervals or a causal relationship to meals or medication. Sources are account-entered and not independently verified; this view provides no clinical interpretation.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              chinese
                  ? '本窗口：${projection.recordedCount} 条已记录，${projection.unknownCount} 条未知，${projection.notMeasuredCount} 条未测。'
                  : 'In this window: ${projection.recordedCount} recorded, ${projection.unknownCount} unknown, ${projection.notMeasuredCount} not measured.',
              style: textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < observations.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              ListTile(
                key: ValueKey(
                  'symptom-motor-sequence-record-${observations[index].id}',
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(observations[index].summary(chinese: chinese)),
                subtitle: Text(
                  chinese
                      ? '发生 ${observations[index].occurredAt.toUtc().toIso8601String()} · 记录 ${observations[index].recordedAt.toUtc().toIso8601String()} · ${sourceLabels[observations[index].source]} · 原始时区 ${observations[index].originalTimezone}'
                      : 'Occurred ${observations[index].occurredAt.toUtc().toIso8601String()} · Recorded ${observations[index].recordedAt.toUtc().toIso8601String()} · ${sourceLabels[observations[index].source]} · Original timezone ${observations[index].originalTimezone}',
                ),
              ),
            ],
            if (projection.omittedObservationCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                chinese
                    ? '另有 ${projection.omittedObservationCount} 条较早记录仍显示在下方完整时间线中。'
                    : '${projection.omittedObservationCount} earlier entries remain in the full timeline below.',
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('fhir-symptom-motor-export-collection'),
              onPressed: canExportCollection ? onExportCollection : null,
              icon: const Icon(Icons.code_outlined),
              label: Text(
                chinese
                    ? '预览 FHIR R4 观察集合'
                    : 'Preview FHIR R4 observation collection',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
