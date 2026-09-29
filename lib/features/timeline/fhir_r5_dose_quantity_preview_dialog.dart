import 'package:flutter/material.dart';

import '../../domain/entities/fhir_r5_dose_quantity_preview.dart';

/// Read-only presentation of the bounded FHIR R5 dose-quantity fragment.
///
/// It intentionally has no copy, save, or send action: this view is neither a
/// complete FHIR resource nor an exchange artifact.
final class FhirR5DoseQuantityPreviewDialog extends StatelessWidget {
  const FhirR5DoseQuantityPreviewDialog({super.key, required this.preview});

  final FhirR5DoseQuantityPreview preview;

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('zh');
    final quantity = _quantity;
    final projected = preview.projected && quantity != null;
    final accent = projected
        ? const Color(0xff287d6b)
        : const Color(0xff9a6700);

    return AlertDialog(
      key: const ValueKey<String>('fhir-r5-dose-preview-dialog'),
      title: Text(chinese ? 'FHIR R5 剂量预览' : 'FHIR R5 dose preview'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    projected
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      projected
                          ? (chinese
                                ? '仅显示一个已确认剂量'
                                : 'One confirmed dose is shown')
                          : (chinese ? '预览已暂停' : 'Preview held'),
                      key: ValueKey<String>(
                        projected
                            ? 'fhir-r5-dose-preview-projected'
                            : 'fhir-r5-dose-preview-held',
                      ),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (projected) ...[
                _PreviewField(
                  key: const ValueKey<String>('fhir-r5-dose-preview-quantity'),
                  label: chinese ? '每次给药量' : 'Dose per administration',
                  value: '${quantity['value']} ${quantity['unit']}',
                ),
                _PreviewField(
                  label: chinese
                      ? 'Quantity.code（预览绑定）'
                      : 'Quantity.code (preview binding)',
                  value: '${quantity['code']}',
                ),
                _PreviewField(
                  label: chinese ? 'Quantity.system' : 'Quantity.system',
                  value: '${quantity['system']}',
                ),
                const SizedBox(height: 8),
                Text(
                  chinese
                      ? '只映射了一个 doseQuantity 数量。这里不验证完整 FHIR Profile 或一般 UCUM 语义。'
                      : 'Only one doseQuantity is mapped. This view does not validate a full FHIR profile or general UCUM semantics.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...[
                Text(
                  _heldExplanation(chinese),
                  key: const ValueKey<String>(
                    'fhir-r5-dose-preview-held-reason',
                  ),
                ),
              ],
              if (preview.unmappedLocalFields.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  chinese ? '未投影的本地字段' : 'Local fields not projected',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(preview.unmappedLocalFields.join(' · ')),
              ],
              const SizedBox(height: 12),
              Text(
                chinese
                    ? '此处仅在本机临时查看，不修改或保存记录、不联网、不复制或发送，也不会进入结果算法。它不是完整 FHIR 资源、处方验证或服药证明。'
                    : 'This local view does not modify or save the record, use the network, copy or send data, or feed result algorithms. It is not a complete FHIR resource, prescription check, or proof of administration.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(chinese ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  Map<String, Object?>? get _quantity {
    final dosage = preview.dosageFragment;
    final doseAndRate = dosage?['doseAndRate'];
    if (doseAndRate is! List || doseAndRate.length != 1) return null;
    final first = doseAndRate.single;
    if (first is! Map) return null;
    final quantity = first['doseQuantity'];
    if (quantity is! Map) return null;
    return Map<String, Object?>.from(quantity);
  }

  String _heldExplanation(bool chinese) {
    final reasons = preview.reasonCodes.join(' ').toLowerCase();
    if (reasons.contains('confirm') || reasons.contains('receipt')) {
      return chinese
          ? '当前记录没有通过重新核验的剂量确认；原始记录保持不变。'
          : 'The current record did not pass dose-confirmation rechecks. The source record is unchanged.';
    }
    if (reasons.contains('assertion') || reasons.contains('conflict')) {
      return chinese
          ? '用药记录仍有待处理的来源或冲突；确认完成前不显示数值。'
          : 'Medication source or conflict checks remain unresolved, so no number is shown.';
    }
    if (reasons.contains('mapping') || reasons.contains('unit')) {
      return chinese
          ? '数值或单位不在当前有限预览映射范围内；原始记录保持不变。'
          : 'The value or unit is outside the narrow preview mapping. The source record is unchanged.';
    }
    return chinese
        ? '当前剂量检查未允许生成预览；原始记录保持不变。'
        : 'Current dose checks did not permit a preview. The source record is unchanged.';
  }
}

final class _PreviewField extends StatelessWidget {
  const _PreviewField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(value),
      ],
    ),
  );
}
