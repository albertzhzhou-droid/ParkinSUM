import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/paper_theme.dart';
import '../../domain/entities/fhir_r4_medication_dispense_import_preview.dart';
import '../../domain/usecases/fhir_r4_medication_dispense_import_mapper.dart';

/// Local source preview. Input is held only in this page's memory.
class FhirR4MedicationDispenseImportPage extends StatefulWidget {
  const FhirR4MedicationDispenseImportPage({
    super.key,
    required this.localeTag,
  });

  final String localeTag;

  @override
  State<FhirR4MedicationDispenseImportPage> createState() =>
      _FhirR4MedicationDispenseImportPageState();
}

class _FhirR4MedicationDispenseImportPageState
    extends State<FhirR4MedicationDispenseImportPage> {
  final _version = TextEditingController(text: '4.0.1');
  final _jurisdiction = TextEditingController();
  final _patient = TextEditingController();
  final _json = TextEditingController();
  FhirR4MedicationDispenseImportPreview? _preview;
  String? _error;

  bool get _chinese => widget.localeTag.toLowerCase().startsWith('zh');
  String _text(String en, String zh) => _chinese ? zh : en;

  @override
  void dispose() {
    _version.dispose();
    _jurisdiction.dispose();
    _patient.dispose();
    _json.dispose();
    super.dispose();
  }

  void _invalidate(String _) {
    if (_preview == null && _error == null) return;
    setState(() {
      _preview = null;
      _error = null;
    });
  }

  Map<String, Object?> _concept(String system, String code, String display) => {
    'coding': [
      {'system': system, 'code': code, 'display': display},
    ],
    'text': display,
  };

  void _loadExample() {
    _version.text = '4.0.1';
    _jurisdiction.text = 'CA';
    _patient.text = 'Patient/synthetic-1';
    _json.text = const JsonEncoder.withIndent('  ').convert({
      'resourceType': 'MedicationDispense',
      'id': 'synthetic-dispense-1',
      'meta': {
        'versionId': '1',
        'source': 'https://pharmacy.example.org/fhir/demo',
        'lastUpdated': '2026-09-20T12:05:00Z',
      },
      'status': 'completed',
      'category': _concept(
        'https://example.org/synthetic-dispense-category',
        'community',
        'Synthetic community pharmacy',
      ),
      'medicationCodeableConcept': _concept(
        'https://example.org/synthetic-medication-codes',
        'demo-medication',
        'Synthetic medication',
      ),
      'subject': {'reference': 'Patient/synthetic-1'},
      'quantity': {'value': 30, 'unit': 'tablets', 'code': '1'},
      'daysSupply': {'value': 30, 'unit': 'days', 'code': 'd'},
      'whenPrepared': '2026-09-20T11:20:00-04:00',
      'whenHandedOver': '2026-09-20T11:30:00-04:00',
    });
    setState(() {
      _preview = null;
      _error = null;
    });
  }

  void _clear() {
    _version.text = '4.0.1';
    _jurisdiction.clear();
    _patient.clear();
    _json.clear();
    setState(() {
      _preview = null;
      _error = null;
    });
  }

  void _runPreview() {
    final input = _json.text;
    if (input.trim().isEmpty) {
      setState(() {
        _preview = null;
        _error = _text(
          'Enter one MedicationDispense or a collection Bundle.',
          '请输入一个 MedicationDispense 或 collection Bundle。',
        );
      });
      return;
    }
    try {
      final preview = const FhirR4MedicationDispenseImportMapper().previewJson(
        input: input,
        context: FhirR4MedicationDispenseImportContext(
          fhirVersion: _version.text.trim(),
          jurisdiction: _jurisdiction.text.trim(),
          expectedPatientReference: _patient.text.trim(),
        ),
      );
      setState(() {
        _preview = preview;
        _error = null;
      });
      debugPrint(
        '[FhirR4MedicationDispenseImport] preview_complete '
        'entries=${preview.entries.length} held=${preview.heldEntryCount}',
      );
    } on FormatException {
      setState(() {
        _preview = null;
        _error = _text(
          'The JSON could not be previewed. Check the resource shape and try again.',
          '无法预览此 JSON。请检查资源结构后重试。',
        );
      });
    } on Object {
      setState(() {
        _preview = null;
        _error = _text('The resource could not be previewed.', '无法预览此资源。');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: PaperAppBar(
        title: Text(
          _text(
            'FHIR R4 MedicationDispense preview',
            'FHIR R4 MedicationDispense 预览',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text('Development-only local preview', '仅供开发检查的本地预览'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _text(
                    'Use fabricated or de-identified data only. Input stays in memory while this page is open; it is not saved, sent, or used by a CDSS rule. Status, medication coding, quantity, days supply, and times are displayed as source claims only. A dispense or handover record does not prove pickup, use, or adherence. References are not resolved, quantities are not converted, and this is not FHIR conformance validation.',
                    '仅使用虚构或去标识化数据。页面打开期间输入只保留在内存中；不会保存、发送或用于 CDSS 规则。状态、药品编码、数量、供应天数和时间仅作为来源声明显示。发药或交接记录不能证明已取药、服用或依从。不会解析引用或换算数量；这也不是 FHIR 一致性验证。',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  key: const Key('fhir-med-dispense-version'),
                  controller: _version,
                  label: _text('FHIR release', 'FHIR 版本'),
                ),
                _field(
                  key: const Key('fhir-med-dispense-jurisdiction'),
                  controller: _jurisdiction,
                  label: _text(
                    'Declared jurisdiction (ISO code)',
                    '声明的辖区（ISO 代码）',
                  ),
                  capitalization: TextCapitalization.characters,
                ),
                _field(
                  key: const Key('fhir-med-dispense-patient'),
                  controller: _patient,
                  label: _text('Expected Patient reference', '预期 Patient 引用'),
                ),
                _field(
                  key: const Key('fhir-med-dispense-json'),
                  controller: _json,
                  label: _text(
                    'MedicationDispense JSON or collection Bundle',
                    'MedicationDispense JSON 或 collection Bundle',
                  ),
                  maxLength:
                      FhirR4MedicationDispenseImportPreview.maximumInputBytes,
                  minLines: 8,
                  maxLines: 20,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      key: const Key('fhir-med-dispense-import-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('fhir-med-dispense-load-example'),
                      onPressed: _loadExample,
                      child: Text(_text('Load synthetic example', '载入合成示例')),
                    ),
                    OutlinedButton(
                      key: const Key('fhir-med-dispense-clear'),
                      onPressed: _clear,
                      child: Text(_text('Clear', '清除')),
                    ),
                    FilledButton.icon(
                      key: const Key('fhir-med-dispense-run-preview'),
                      onPressed: _runPreview,
                      icon: const Icon(Icons.preview_outlined),
                      label: Text(_text('Preview', '预览')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (preview case final result?) ...[
            const SizedBox(height: 12),
            _PreviewResult(preview: result, chinese: _chinese),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization capitalization = TextCapitalization.none,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: key,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: capitalization,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        alignLabelWithHint: minLines > 1,
      ),
      onChanged: _invalidate,
    ),
  );
}

class _PreviewResult extends StatelessWidget {
  const _PreviewResult({required this.preview, required this.chinese});

  final FhirR4MedicationDispenseImportPreview preview;
  final bool chinese;

  String _text(String en, String zh) => chinese ? zh : en;

  String _concept(FhirR4MedicationDispenseConceptPreview? concept) {
    if (concept == null) return '—';
    final parts = <String>[];
    if (concept.text != null) parts.add(concept.text!);
    for (final coding in concept.codings) {
      if (coding.code != null) {
        parts.add('${coding.system ?? '?'} | ${coding.code}');
      }
      if (coding.display != null) parts.add(coding.display!);
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  String _medication(FhirR4MedicationDispenseImportEntryPreview entry) =>
      _concept(
        FhirR4MedicationDispenseConceptPreview(
          codings: entry.medicationCodings,
          text: entry.medicationConceptText,
        ),
      );

  String _quantity(FhirR4MedicationDispenseQuantityPreview? quantity) {
    if (quantity == null) return '—';
    final value = quantity.value?.toString() ?? '—';
    final unit = quantity.unit ?? quantity.code;
    final code = quantity.code != null && quantity.code != unit
        ? ' [${quantity.code}]'
        : '';
    final system = quantity.system == null ? '' : ' · ${quantity.system}';
    return '$value${unit == null ? '' : ' $unit'}$code$system';
  }

  @override
  Widget build(BuildContext context) => PaperCard(
    key: const Key('fhir-med-dispense-import-result'),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text(
            'MedicationDispense source preview',
            'MedicationDispense 来源字段预览',
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          _text(
            '${preview.entries.length} entries · ${preview.heldEntryCount} held · ${preview.previewable ? "previewable subset" : "review required"}',
            '${preview.entries.length} 条 · 暂挂 ${preview.heldEntryCount} 条 · ${preview.previewable ? "字段子集可预览" : "需要检查"}',
          ),
          key: const Key('fhir-med-dispense-import-summary'),
        ),
        const SizedBox(height: 4),
        SelectableText(
          'SHA-256 ${preview.inputSha256}',
          key: const Key('fhir-med-dispense-import-digest'),
        ),
        for (var index = 0; index < preview.entries.length; index++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              key: Key('fhir-med-dispense-entry-$index'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _entry(context, preview.entries[index], index),
            ),
          ),
        if (preview.reasonCodes.isNotEmpty ||
            preview.unmappedPaths.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _text('Held reason codes', '暂挂原因代码'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final reason in preview.reasonCodes) SelectableText(reason),
          for (final path in preview.unmappedPaths)
            SelectableText('${_text("Unmapped", "未映射")}: $path'),
        ],
      ],
    ),
  );

  Widget _entry(
    BuildContext context,
    FhirR4MedicationDispenseImportEntryPreview entry,
    int index,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _text('Dispense ${index + 1}', '发药记录 ${index + 1}'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      if (entry.resourceId != null)
        Text('Source resource ID: ${entry.resourceId}'),
      if (entry.bundleEntryFullUrl != null)
        Text('Bundle entry fullUrl: ${entry.bundleEntryFullUrl}'),
      Text(
        '${_text("Patient reference matched", "Patient 引用匹配")}: ${entry.patientReferenceMatched}',
        key: Key('fhir-med-dispense-patient-match-$index'),
      ),
      Text('${_text("Status (source)", "状态（来源）")}: ${entry.status ?? "—"}'),
      Text('${_text("Medication (source)", "药品（来源）")}: ${_medication(entry)}'),
      Text(
        '${_text("Category (source)", "类别（来源）")}: ${_concept(entry.category)}',
      ),
      Text('${_text("Type (source)", "类型（来源）")}: ${_concept(entry.type)}'),
      Text(
        '${_text("Status reason (source)", "状态原因（来源）")}: ${_concept(entry.statusReason)}',
      ),
      Text(
        '${_text("Quantity (source)", "数量（来源）")}: ${_quantity(entry.quantity)}',
      ),
      Text(
        '${_text("Days supply (source)", "供应天数（来源）")}: ${_quantity(entry.daysSupply)}',
      ),
      Text(
        '${_text("When prepared (source)", "准备时间（来源）")}: ${entry.whenPrepared?.lexical ?? "—"}',
      ),
      Text(
        '${_text("When handed over (source)", "交接时间（来源）")}: ${entry.whenHandedOver?.lexical ?? "—"}',
      ),
      if (entry.metaSource != null) Text('Source: ${entry.metaSource}'),
      if (entry.resourceVersionId != null)
        Text('Version: ${entry.resourceVersionId}'),
      if (entry.metaLastUpdated != null)
        Text('Last updated: ${entry.metaLastUpdated!.lexical}'),
      for (final reason in entry.reasonCodes)
        Text(
          '${_text("Held", "暂挂")}: $reason',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      for (final path in entry.unmappedPaths)
        Text('${_text("Unmapped", "未映射")}: $path'),
    ],
  );
}
