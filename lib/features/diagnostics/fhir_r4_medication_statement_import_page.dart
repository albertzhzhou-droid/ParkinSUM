import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/paper_theme.dart';
import '../../domain/entities/fhir_r4_medication_statement_import_preview.dart';
import '../../domain/usecases/fhir_r4_medication_statement_import_mapper.dart';

/// Local, in-memory preview for a FHIR R4 MedicationStatement or collection.
/// It never persists, transmits, or resolves the supplied resource.
class FhirR4MedicationStatementImportPage extends StatefulWidget {
  const FhirR4MedicationStatementImportPage({
    super.key,
    required this.localeTag,
  });

  final String localeTag;

  @override
  State<FhirR4MedicationStatementImportPage> createState() =>
      _FhirR4MedicationStatementImportPageState();
}

class _FhirR4MedicationStatementImportPageState
    extends State<FhirR4MedicationStatementImportPage> {
  final _fhirVersion = TextEditingController(text: '4.0.1');
  final _jurisdiction = TextEditingController();
  final _patientReference = TextEditingController();
  final _resourceJson = TextEditingController();
  FhirR4MedicationStatementImportPreview? _preview;
  String? _inputError;

  bool get _isChinese => widget.localeTag.toLowerCase().startsWith('zh');

  String _text(String english, String chinese) =>
      _isChinese ? chinese : english;

  @override
  void dispose() {
    _fhirVersion.dispose();
    _jurisdiction.dispose();
    _patientReference.dispose();
    _resourceJson.dispose();
    super.dispose();
  }

  void _invalidate(String _) {
    if (_preview == null && _inputError == null) return;
    setState(() {
      _preview = null;
      _inputError = null;
    });
  }

  void _loadExample() {
    _fhirVersion.text = '4.0.1';
    _jurisdiction.text = 'CA';
    _patientReference.text = 'Patient/synthetic-1';
    _resourceJson.text = const JsonEncoder.withIndent('  ').convert({
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': [
        {
          'fullUrl': 'urn:uuid:synthetic-medication-statement-1',
          'resource': {
            'resourceType': 'MedicationStatement',
            'id': 'synthetic-medication-statement-1',
            'meta': {
              'versionId': '1',
              'source': 'https://ehr.example.org/fhir/MedicationStatement/demo',
              'lastUpdated': '2026-09-20T12:05:00Z',
            },
            'status': 'unknown',
            'medicationCodeableConcept': {
              'coding': [
                {
                  'system': 'https://example.org/medication-codes',
                  'version': 'synthetic-1',
                  'code': 'demo-medication',
                  'display': 'Synthetic medication',
                },
              ],
              'text': 'Synthetic medication',
            },
            'subject': {'reference': 'Patient/synthetic-1'},
            'effectiveDateTime': '2026-09-20',
            'dateAsserted': '2026-09-20T12:00:00Z',
            'dosage': [
              {'text': 'Synthetic source instruction; not parsed as a dose.'},
            ],
          },
        },
      ],
    });
    setState(() {
      _preview = null;
      _inputError = null;
    });
  }

  void _clear() {
    _fhirVersion.text = '4.0.1';
    _jurisdiction.clear();
    _patientReference.clear();
    _resourceJson.clear();
    setState(() {
      _preview = null;
      _inputError = null;
    });
  }

  void _runPreview() {
    final input = _resourceJson.text;
    if (input.trim().isEmpty) {
      setState(() {
        _preview = null;
        _inputError = _text(
          'Enter one MedicationStatement or a collection Bundle.',
          '请输入一个 MedicationStatement 或 collection Bundle。',
        );
      });
      return;
    }
    if (utf8.encode(input).length >
        FhirR4MedicationStatementImportPreview.maximumInputBytes) {
      setState(() {
        _preview = null;
        _inputError = _text(
          'This preview accepts up to 128 KiB of JSON.',
          '此预览最多接受 128 KiB 的 JSON。',
        );
      });
      return;
    }
    try {
      final preview = const FhirR4MedicationStatementImportMapper().previewJson(
        input: input,
        context: FhirR4MedicationStatementImportContext(
          fhirVersion: _fhirVersion.text.trim(),
          jurisdiction: _jurisdiction.text.trim(),
          expectedPatientReference: _patientReference.text.trim(),
        ),
      );
      setState(() {
        _preview = preview;
        _inputError = null;
      });
      debugPrint(
        '[FhirR4MedicationStatementImport] preview_complete '
        'entries=${preview.entries.length} held=${preview.heldEntryCount}',
      );
    } on FormatException {
      setState(() {
        _preview = null;
        _inputError = _text(
          'The JSON could not be previewed. Check the resource shape and try again.',
          '无法预览此 JSON。请检查资源结构后重试。',
        );
      });
    } on Object {
      setState(() {
        _preview = null;
        _inputError = _text('The resource could not be previewed.', '无法预览此资源。');
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
            'FHIR R4 MedicationStatement import preview',
            'FHIR R4 MedicationStatement 导入预览',
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
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _text('Development-only local preview', '仅供开发检查的本地预览'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _text(
                    'Use fabricated or de-identified data only. Input stays in memory while this page is open; it is not saved, sent, exported, or used by a CDSS rule. Leaving the page clears it. FHIR status and dosage are source-reported fields, not proof of administration or a parsed dose.',
                    '仅使用虚构或去标识化数据。页面打开期间输入只保留在内存中；不会保存、发送、导出，也不会用于 CDSS 规则。离开页面后输入会清空。FHIR 状态和剂量文字是来源声明，不证明实际给药，也不会被解析为剂量。',
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
                  key: const Key('fhir-med-statement-version'),
                  controller: _fhirVersion,
                  label: _text('FHIR release', 'FHIR 版本'),
                ),
                _field(
                  key: const Key('fhir-med-statement-jurisdiction'),
                  controller: _jurisdiction,
                  label: _text(
                    'Declared jurisdiction (ISO code)',
                    '声明的辖区（ISO 代码）',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                _field(
                  key: const Key('fhir-med-statement-patient'),
                  controller: _patientReference,
                  label: _text('Expected Patient reference', '预期 Patient 引用'),
                ),
                _field(
                  key: const Key('fhir-med-statement-json'),
                  controller: _resourceJson,
                  label: _text(
                    'MedicationStatement JSON or collection Bundle',
                    'MedicationStatement JSON 或 collection Bundle',
                  ),
                  maxLength:
                      FhirR4MedicationStatementImportPreview.maximumInputBytes,
                  minLines: 8,
                  maxLines: 20,
                ),
                if (_inputError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _inputError!,
                      key: const Key('fhir-med-statement-input-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('fhir-med-statement-fill-example'),
                      onPressed: _loadExample,
                      icon: const Icon(Icons.science_outlined),
                      label: Text(_text('Load synthetic example', '载入合成示例')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('fhir-med-statement-clear'),
                      onPressed: _clear,
                      icon: const Icon(Icons.clear),
                      label: Text(_text('Clear', '清除')),
                    ),
                    FilledButton.icon(
                      key: const Key('fhir-med-statement-run'),
                      onPressed: _runPreview,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(_text('Preview locally', '本地预览')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: 12),
            _previewCard(preview),
          ],
        ],
      ),
    );
  }

  Widget _previewCard(FhirR4MedicationStatementImportPreview preview) {
    final ready = preview.previewable;
    final theme = Theme.of(context);
    return PaperCard(
      key: const Key('fhir-med-statement-result'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
                color: ready ? Colors.green.shade700 : theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _text(
                    ready ? 'Ready for local review' : 'Needs review',
                    ready ? '可供本地复核' : '需要复核',
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _text(
              'Nothing was imported or saved. These are reported medication statements, not administration records.',
              '没有导入或保存任何记录。这些是来源报告的用药陈述，不是给药记录。',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_text('FHIR release', 'FHIR 版本')}: ${preview.context.fhirVersion}',
          ),
          Text(
            '${_text('Jurisdiction', '辖区')}: ${preview.context.jurisdiction}',
          ),
          Text(
            '${_text('Expected Patient', '预期 Patient')}: ${preview.context.expectedPatientReference}',
          ),
          Text(
            '${_text('Container', '容器')}: ${preview.containerType ?? _text('Unknown', '未知')}',
          ),
          Text('${_text('Statements', '陈述数')}: ${preview.entries.length}'),
          Text(
            '${_text('Input SHA-256', '输入 SHA-256')}: ${preview.inputSha256}',
          ),
          for (var index = 0; index < preview.entries.length; index++) ...[
            const Divider(height: 24),
            _entry(preview.entries[index], index),
          ],
          if (preview.reasonCodes.isNotEmpty ||
              preview.unmappedPaths.isNotEmpty) ...[
            const Divider(height: 24),
            ExpansionTile(
              key: const Key('fhir-med-statement-diagnostics'),
              tilePadding: EdgeInsets.zero,
              title: Text(_text('Review details', '复核详情')),
              children: [
                for (final reason in preview.reasonCodes)
                  ListTile(
                    dense: true,
                    title: Text(reason),
                    leading: const Icon(Icons.error_outline),
                  ),
                for (final path in preview.unmappedPaths)
                  ListTile(
                    dense: true,
                    title: Text(path),
                    leading: const Icon(Icons.help_outline),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _entry(FhirR4MedicationStatementImportEntryPreview entry, int index) {
    final theme = Theme.of(context);
    String time(FhirR4MedicationStatementTimePreview? value) => value == null
        ? _text('Not supplied', '未提供')
        : '${value.lexical} (${value.precision.name})';
    final medication =
        entry.medicationConceptText ??
        entry.medicationReferenceDisplay ??
        entry.medicationReference ??
        _text('Identity unavailable', '药品标识不可用');
    return Column(
      key: ValueKey('fhir-med-statement-entry-$index'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_text('MedicationStatement', 'MedicationStatement')} ${entry.resourceId ?? '#${index + 1}'}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (entry.bundleEntryFullUrl != null)
          Text(
            '${_text('Bundle full URL', 'Bundle full URL')}: ${entry.bundleEntryFullUrl}',
          ),
        Text(
          '${_text('FHIR status (source-reported)', 'FHIR 状态（来源声明）')}: ${entry.status ?? _text('Missing', '缺失')}',
        ),
        Text(
          '${_text('Medication identity (unresolved)', '药品标识（未解析）')}: $medication',
        ),
        for (final coding in entry.medicationCodings)
          Text(
            '${coding.system ?? '?'} | ${coding.version ?? '?'} | ${coding.code ?? '?'} | ${coding.display ?? '?'}',
          ),
        Text(
          '${_text('Patient reference', 'Patient 引用')}: ${entry.subjectReference ?? _text('Missing', '缺失')}',
        ),
        if (entry.metaSource != null)
          Text(
            '${_text('Resource source claim', '资源来源声明')}: ${entry.metaSource}',
          ),
        if (entry.resourceVersionId != null)
          Text(
            '${_text('Resource version', '资源版本')}: ${entry.resourceVersionId}',
          ),
        if (entry.metaLastUpdated != null)
          Text(
            '${_text('Last updated', '最后更新')}: ${time(entry.metaLastUpdated)}',
          ),
        if (entry.effectiveDateTime != null)
          Text(
            '${_text('Effective time', '生效时间')}: ${time(entry.effectiveDateTime)}',
          ),
        if (entry.effectivePeriodStart != null ||
            entry.effectivePeriodEnd != null)
          Text(
            '${_text('Effective period', '生效区间')}: ${time(entry.effectivePeriodStart)} – ${time(entry.effectivePeriodEnd)}',
          ),
        if (entry.dateAsserted != null)
          Text(
            '${_text('Date asserted', '声明日期')}: ${time(entry.dateAsserted)}',
          ),
        if (entry.informationSourceReference != null)
          Text(
            '${_text('Information source reference (unverified)', '信息来源引用（未核实）')}: ${entry.informationSourceDisplay ?? entry.informationSourceReference}',
          ),
        for (final dosage in entry.dosageTexts)
          Text(
            '${_text('Source dosage text (not parsed)', '来源剂量文字（未解析）')}: $dosage',
          ),
        if (entry.reasonCodes.isNotEmpty)
          Text(
            '${_text('Entry held', '此条暂缓')}: ${entry.reasonCodes.join(', ')}',
          ),
        if (entry.unmappedPaths.isNotEmpty)
          Text(
            '${_text('Unprojected fields', '未投影字段')}: ${entry.unmappedPaths.join(', ')}',
          ),
      ],
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    int? maxLength,
    int minLines = 1,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: key,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      onChanged: _invalidate,
    ),
  );
}
