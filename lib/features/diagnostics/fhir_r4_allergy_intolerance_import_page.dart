import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/paper_theme.dart';
import '../../domain/entities/fhir_r4_allergy_intolerance_import_preview.dart';
import '../../domain/usecases/fhir_r4_allergy_intolerance_import_mapper.dart';

/// Local, in-memory projection of FHIR R4 AllergyIntolerance source fields.
/// It never persists, transmits, resolves, reconciles, or activates a record.
class FhirR4AllergyIntoleranceImportPage extends StatefulWidget {
  const FhirR4AllergyIntoleranceImportPage({
    super.key,
    required this.localeTag,
  });

  final String localeTag;

  @override
  State<FhirR4AllergyIntoleranceImportPage> createState() =>
      _FhirR4AllergyIntoleranceImportPageState();
}

class _FhirR4AllergyIntoleranceImportPageState
    extends State<FhirR4AllergyIntoleranceImportPage> {
  final _fhirVersion = TextEditingController(text: '4.0.1');
  final _jurisdiction = TextEditingController();
  final _patientReference = TextEditingController();
  final _resourceJson = TextEditingController();
  FhirR4AllergyIntoleranceImportPreview? _preview;
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

  Map<String, Object?> _status(String system, String code, String display) => {
    'coding': [
      {'system': system, 'code': code, 'display': display},
    ],
  };

  void _loadExample() {
    _fhirVersion.text = '4.0.1';
    _jurisdiction.text = 'CA';
    _patientReference.text = 'Patient/synthetic-1';
    _resourceJson.text = const JsonEncoder.withIndent('  ').convert({
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': [
        {
          'fullUrl': 'urn:uuid:synthetic-allergy-intolerance-1',
          'resource': {
            'resourceType': 'AllergyIntolerance',
            'id': 'synthetic-allergy-intolerance-1',
            'meta': {
              'versionId': '1',
              'source': 'https://ehr.example.org/fhir/demo',
              'lastUpdated': '2026-09-20T12:05:00Z',
            },
            'clinicalStatus': _status(
              'http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical',
              'active',
              'Active',
            ),
            'verificationStatus': _status(
              'http://terminology.hl7.org/CodeSystem/allergyintolerance-verification',
              'unconfirmed',
              'Unconfirmed',
            ),
            'type': 'allergy',
            'category': ['medication'],
            'criticality': 'unable-to-assess',
            'code': {
              'coding': [
                {
                  'system': 'https://example.org/synthetic-substances',
                  'code': 'demo-substance',
                  'display': 'Synthetic substance',
                },
              ],
            },
            'patient': {'reference': 'Patient/synthetic-1'},
            'onsetDateTime': '2026-09',
            'recordedDate': '2026-09-20',
            'reaction': [
              {
                'manifestation': [
                  {
                    'coding': [
                      {
                        'system': 'https://example.org/synthetic-findings',
                        'code': 'demo-manifestation',
                        'display': 'Synthetic manifestation',
                      },
                    ],
                  },
                ],
                'severity': 'mild',
              },
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
          'Enter one AllergyIntolerance or a collection Bundle.',
          '请输入一个 AllergyIntolerance 或 collection Bundle。',
        );
      });
      return;
    }
    if (utf8.encode(input).length >
        FhirR4AllergyIntoleranceImportPreview.maximumInputBytes) {
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
      final preview = const FhirR4AllergyIntoleranceImportMapper().previewJson(
        input: input,
        context: FhirR4AllergyPreviewContext(
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
        '[FhirR4AllergyIntoleranceImport] preview_complete '
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
            'FHIR R4 AllergyIntolerance preview',
            'FHIR R4 AllergyIntolerance 预览',
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
                    'Use fabricated or de-identified data only. Input stays in memory while this page is open; it is not saved, sent, or used by a CDSS rule. This screen displays source-reported fields only. It does not conclude that an allergy is present or absent, assess causality or safety, or validate FHIR conformance. Type, category, criticality, reaction severity, clinical status, and verification status stay separate.',
                    '仅使用虚构或去标识化数据。页面打开期间输入只保留在内存中；不会保存、发送或用于 CDSS 规则。此页面只显示来源字段，不判断是否存在或不存在过敏，不评估因果关系或安全性，也不验证 FHIR 一致性。type、category、criticality、反应严重程度、临床状态与核实状态分别保留。',
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
                  key: const Key('fhir-allergy-version'),
                  controller: _fhirVersion,
                  label: _text('FHIR release', 'FHIR 版本'),
                ),
                _field(
                  key: const Key('fhir-allergy-jurisdiction'),
                  controller: _jurisdiction,
                  label: _text(
                    'Declared jurisdiction (ISO code)',
                    '声明的辖区（ISO 代码）',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                _field(
                  key: const Key('fhir-allergy-patient'),
                  controller: _patientReference,
                  label: _text('Expected Patient reference', '预期 Patient 引用'),
                ),
                _field(
                  key: const Key('fhir-allergy-json'),
                  controller: _resourceJson,
                  label: _text(
                    'AllergyIntolerance JSON or collection Bundle',
                    'AllergyIntolerance JSON 或 collection Bundle',
                  ),
                  maxLength:
                      FhirR4AllergyIntoleranceImportPreview.maximumInputBytes,
                  minLines: 8,
                  maxLines: 20,
                ),
                if (_inputError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _inputError!,
                      key: const Key('fhir-allergy-input-error'),
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
                      key: const Key('fhir-allergy-fill-example'),
                      onPressed: _loadExample,
                      icon: const Icon(Icons.science_outlined),
                      label: Text(_text('Load synthetic example', '载入合成示例')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('fhir-allergy-clear'),
                      onPressed: _clear,
                      icon: const Icon(Icons.clear),
                      label: Text(_text('Clear', '清除')),
                    ),
                    FilledButton.icon(
                      key: const Key('fhir-allergy-run'),
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

  Widget _previewCard(FhirR4AllergyIntoleranceImportPreview preview) {
    final ready = preview.previewable;
    final patientScopeMatched =
        preview.entries.isNotEmpty &&
        preview.entries.every((entry) => entry.patientReferenceMatched);
    final theme = Theme.of(context);
    return PaperCard(
      key: const Key('fhir-allergy-result'),
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
              'Nothing was imported or saved. A previewable entry means only that this limited projection accepted its shape; it is not an allergy conclusion or a FHIR conformance result.',
              '没有导入或保存任何记录。“可预览”仅表示此有限投影接受了资源结构；不代表过敏结论或 FHIR 一致性结果。',
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
            '${_text('Patient scope', 'Patient 范围')}: ${_text(patientScopeMatched ? 'expected Patient reference matched exactly' : 'Patient reference match not confirmed for every entry', patientScopeMatched ? '预期 Patient 引用精确匹配' : '并非所有记录都确认了 Patient 引用匹配')}',
          ),
          Text(
            '${_text('Container', '容器')}: ${preview.containerType ?? _text('Unknown', '未知')}',
          ),
          Text(
            '${_text('Entries', '记录数')}: ${preview.entries.length} · ${_text('held', '暂缓')} ${preview.heldEntryCount}',
          ),
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
              key: const Key('fhir-allergy-diagnostics'),
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

  Widget _entry(FhirR4AllergyIntoleranceEntryPreview entry, int index) {
    final theme = Theme.of(context);
    String time(FhirR4AllergyTimePreview? value) => value == null
        ? _text('Not supplied', '未提供')
        : '${value.lexical} (${value.precision.name})';
    return Column(
      key: ValueKey('fhir-allergy-entry-$index'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_text('AllergyIntolerance entry', 'AllergyIntolerance 记录')} #${index + 1}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '${_text('Patient reference scope', 'Patient 引用范围')}: ${_text(entry.patientReferenceMatched ? 'exact match' : 'not confirmed', entry.patientReferenceMatched ? '精确匹配' : '未确认')}',
        ),
        _conceptRow(
          _text('Clinical status (source-reported)', '临床状态（来源声明）'),
          entry.clinicalStatus,
        ),
        _conceptRow(
          _text('Verification status (source-reported)', '核实状态（来源声明）'),
          entry.verificationStatus,
        ),
        if (entry.type != null)
          Text('${_text('Type (source-reported)', '类型（来源声明）')}: ${entry.type}'),
        if (entry.category.isNotEmpty)
          Text(
            '${_text('Category (source-reported)', '类别（来源声明）')}: ${entry.category.join(', ')}',
          ),
        if (entry.criticality != null)
          Text(
            '${_text('Criticality (source-reported)', '临界性（来源声明）')}: ${entry.criticality}',
          ),
        _conceptRow(_text('Code (unresolved)', '代码（未解析）'), entry.code),
        if (entry.onset != null)
          Text('${_text('Onset', '起始时间')}: ${time(entry.onset)}'),
        if (entry.recordedDate != null)
          Text(
            '${_text('Recorded date', '记录日期')}: ${time(entry.recordedDate)}',
          ),
        if (entry.lastOccurrence != null)
          Text(
            '${_text('Last occurrence', '最近一次发生时间')}: ${time(entry.lastOccurrence)}',
          ),
        for (
          var reactionIndex = 0;
          reactionIndex < entry.reactions.length;
          reactionIndex++
        ) ...[
          const SizedBox(height: 8),
          Text(
            '${_text('Reaction source fields', '反应来源字段')} #${reactionIndex + 1}',
            style: theme.textTheme.labelLarge,
          ),
          _conceptRow(
            _text('Substance (unresolved)', '物质（未解析）'),
            entry.reactions[reactionIndex].substance,
          ),
          for (final manifestation
              in entry.reactions[reactionIndex].manifestations)
            _conceptRow(
              _text('Manifestation (source-reported)', '表现（来源声明）'),
              manifestation,
            ),
          if (entry.reactions[reactionIndex].severity != null)
            Text(
              '${_text('Reaction severity (source-reported)', '反应严重程度（来源声明）')}: ${entry.reactions[reactionIndex].severity}',
            ),
          if (entry.reactions[reactionIndex].onset != null)
            Text(
              '${_text('Reaction onset', '反应起始时间')}: ${time(entry.reactions[reactionIndex].onset)}',
            ),
          _conceptRow(
            _text('Exposure route (unresolved)', '暴露途径（未解析）'),
            entry.reactions[reactionIndex].exposureRoute,
          ),
        ],
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

  Widget _conceptRow(String label, FhirR4AllergyConceptPreview? concept) {
    if (concept == null) return const SizedBox.shrink();
    final codingText = concept.codings
        .map(
          (coding) =>
              '${coding.system ?? '?'} | ${coding.version ?? '?'} | ${coding.code ?? '?'} | ${coding.display ?? '?'}',
        )
        .join('; ');
    final value = [
      if (concept.text != null) concept.text!,
      if (codingText.isNotEmpty) codingText,
      if (concept.text == null && codingText.isEmpty)
        _text('No text or coding supplied', '未提供文本或编码'),
    ].join(' · ');
    return Text('$label: $value');
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
