import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/smart_sandbox_discovery_client.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/fhir_r4_observation_import_preview.dart';
import '../../domain/usecases/fhir_r4_blood_pressure_import_mapper.dart';

/// A diagnostic surface for the local FHIR mapper and bounded SMART discovery.
///
/// The Observation preview is local-only. A separate, explicit debug-only
/// action may fetch public SMART server metadata; it never sends pasted data.
class FhirR4ObservationPreviewPage extends StatefulWidget {
  const FhirR4ObservationPreviewPage({
    super.key,
    required this.localeTag,
    this.discoveryLoader,
  });

  final String localeTag;
  final Future<SmartSandboxDiscoveryReport> Function()? discoveryLoader;

  @override
  State<FhirR4ObservationPreviewPage> createState() =>
      _FhirR4ObservationPreviewPageState();
}

class _FhirR4ObservationPreviewPageState
    extends State<FhirR4ObservationPreviewPage> {
  static const _maxResourceCharacters = 65536;
  static const _maxResourceBytes = 64 * 1024;

  final _sourceBase = TextEditingController();
  final _fhirVersion = TextEditingController(text: '4.0.1');
  final _jurisdiction = TextEditingController();
  final _patientReference = TextEditingController();
  final _resourceJson = TextEditingController();
  late final SmartSandboxDiscoveryClient _discoveryClient;
  bool _discovering = false;
  String? _discoveryError;
  SmartSandboxDiscoveryReport? _discoveryReport;
  FhirR4ObservationImportPreview? _preview;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _discoveryClient = SmartSandboxDiscoveryClient();
  }

  bool get _isChinese => widget.localeTag.toLowerCase().startsWith('zh');

  String _text(String english, String chinese) =>
      _isChinese ? chinese : english;

  @override
  void dispose() {
    _sourceBase.dispose();
    _fhirVersion.dispose();
    _jurisdiction.dispose();
    _patientReference.dispose();
    _resourceJson.dispose();
    _discoveryClient.close();
    super.dispose();
  }

  Future<void> _discoverSmartSandbox() async {
    setState(() {
      _discovering = true;
      _discoveryError = null;
      _discoveryReport = null;
    });
    try {
      final report =
          await (widget.discoveryLoader ?? _discoveryClient.discover)();
      if (!mounted) return;
      setState(() {
        _discovering = false;
        _discoveryReport = report;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _discovering = false;
        _discoveryError = _text(
          'The sandbox metadata could not be validated. Check the connection and try again.',
          '无法验证沙箱元数据。请检查网络连接后重试。',
        );
      });
    }
  }

  void _invalidatePreview(String _) {
    if (_preview == null && _inputError == null) return;
    setState(() {
      _preview = null;
      _inputError = null;
    });
  }

  void _loadSyntheticExample() {
    _sourceBase.text = 'https://ehr.example.org/fhir';
    _fhirVersion.text = '4.0.1';
    _jurisdiction.text = 'CA';
    _patientReference.text = 'Patient/synthetic-1';
    _resourceJson.text = const JsonEncoder.withIndent('  ').convert({
      'resourceType': 'Observation',
      'id': 'synthetic-bp-1',
      'meta': {
        'versionId': '1',
        'source': 'https://ehr.example.org/fhir/Observation/synthetic-bp-1',
        'lastUpdated': '2026-09-24T12:00:05Z',
      },
      'status': 'final',
      'code': {
        'coding': [
          {
            'system': FhirR4ObservationImportPreview.loincSystem,
            'version': '2.83',
            'code': FhirR4ObservationImportPreview.bloodPressurePanelCode,
            'display': 'Blood pressure panel',
          },
        ],
        'text': 'Synthetic blood pressure',
      },
      'subject': {'reference': 'Patient/synthetic-1'},
      'effectiveDateTime': '2026-09-24T12:00:00Z',
      'issued': '2026-09-24T12:00:05Z',
      'component': [
        _syntheticComponent(
          FhirR4ObservationImportPreview.systolicCode,
          'Systolic blood pressure',
          120,
        ),
        _syntheticComponent(
          FhirR4ObservationImportPreview.diastolicCode,
          'Diastolic blood pressure',
          80,
        ),
      ],
    });
    setState(() {
      _preview = null;
      _inputError = null;
    });
  }

  static Map<String, Object?> _syntheticComponent(
    String code,
    String display,
    int value,
  ) => {
    'code': {
      'coding': [
        {
          'system': FhirR4ObservationImportPreview.loincSystem,
          'version': '2.83',
          'code': code,
          'display': display,
        },
      ],
    },
    'valueQuantity': {
      'value': value,
      'unit': 'mmHg',
      'system': FhirR4ObservationImportPreview.ucumSystem,
      'code': FhirR4ObservationImportPreview.bloodPressureUnitCode,
    },
  };

  void _clear() {
    _sourceBase.clear();
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
    final raw = _resourceJson.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _preview = null;
        _inputError = _text(
          'Enter a FHIR Observation JSON object.',
          '请输入 FHIR Observation JSON 对象。',
        );
      });
      return;
    }
    if (utf8.encode(raw).length > _maxResourceBytes) {
      setState(() {
        _preview = null;
        _inputError = _text(
          'This preview accepts resources up to 64 KiB.',
          '此预览最多接受 64 KiB 的资源。',
        );
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _preview = null;
          _inputError = _text(
            'The JSON must contain one resource object.',
            'JSON 必须包含一个资源对象。',
          );
        });
        return;
      }
      final preview = const FhirR4BloodPressureImportMapper()
          .previewObservation(
            resource: decoded,
            context: FhirR4ObservationImportContext(
              sourceFhirBase: _sourceBase.text.trim(),
              fhirVersion: _fhirVersion.text.trim(),
              jurisdiction: _jurisdiction.text.trim(),
              expectedPatientReference: _patientReference.text.trim(),
            ),
          );
      setState(() {
        _preview = preview;
        _inputError = null;
      });
    } on FormatException {
      setState(() {
        _preview = null;
        _inputError = _text(
          'The JSON could not be parsed. Check its structure and try again.',
          '无法解析 JSON。请检查结构后重试。',
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
        title: Text(_text('FHIR R4 Observation preview', 'FHIR R4 观察资源预览')),
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
                    'Use fabricated or de-identified data only. This screen keeps input in memory while open; it does not save, send, export, or use the resource in a CDSS rule. Leaving the page clears its fields.',
                    '仅使用虚构或去标识化数据。页面打开期间，输入只保留在内存中；不会保存、发送、导出，也不会用于 CDSS 规则。离开页面后字段会清空。',
                  ),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[const SizedBox(height: 12), _smartSandboxCard()],
          const SizedBox(height: 12),
          PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  key: const Key('fhir-preview-source-base'),
                  controller: _sourceBase,
                  label: _text('Source FHIR base URL', '来源 FHIR 基础 URL'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('fhir-preview-release'),
                  controller: _fhirVersion,
                  label: _text('FHIR release', 'FHIR 版本'),
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('fhir-preview-jurisdiction'),
                  controller: _jurisdiction,
                  label: _text('Jurisdiction code', '辖区代码'),
                  hint: 'CA',
                ),
                const SizedBox(height: 12),
                _field(
                  key: const Key('fhir-preview-patient-reference'),
                  controller: _patientReference,
                  label: _text('Expected Patient reference', '预期 Patient 引用'),
                  hint: 'Patient/example',
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('fhir-preview-resource-json'),
                  controller: _resourceJson,
                  minLines: 9,
                  maxLines: 16,
                  maxLength: _maxResourceCharacters,
                  autocorrect: false,
                  enableSuggestions: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: _text(
                      'One Observation JSON resource',
                      '一个 Observation JSON 资源',
                    ),
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _invalidatePreview,
                ),
                if (_inputError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _inputError!,
                    key: const Key('fhir-preview-input-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('fhir-preview-fill-example'),
                      onPressed: _loadSyntheticExample,
                      icon: const Icon(Icons.science_outlined),
                      label: Text(_text('Fill synthetic example', '填写合成示例')),
                    ),
                    TextButton(
                      key: const Key('fhir-preview-clear'),
                      onPressed: _clear,
                      child: Text(_text('Clear', '清除')),
                    ),
                    FilledButton.icon(
                      key: const Key('fhir-preview-run'),
                      onPressed: _runPreview,
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(_text('Preview', '预览')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: 12),
            _PreviewResult(preview: preview, isChinese: _isChinese),
          ],
        ],
      ),
    );
  }

  Widget _smartSandboxCard() {
    final report = _discoveryReport;
    return PaperCard(
      key: const Key('smart-sandbox-discovery-card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _text('Live SMART sandbox discovery', '实时 SMART 沙箱发现'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _text(
              'On tap, this development-only check sends one bounded HTTPS GET to the public SMART Health IT R4 sandbox. It reads server metadata only: no account, Patient, FHIR resource, or authorization token is sent. The server and network still receive ordinary connection metadata. No login, launch, or resource read occurs.',
              '点击后，此开发专用检查会向 SMART Health IT 的公开 R4 沙箱发送一次有大小限制的 HTTPS GET，只读取服务器元数据：不会发送账号、Patient、FHIR 资源或授权令牌。服务器和网络仍会收到常规连接元数据。本检查不会登录、启动授权流程或读取资源。',
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            SmartSandboxDiscoveryClient.fhirBaseUrl,
            key: const Key('smart-sandbox-fhir-base'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('smart-sandbox-discover'),
              onPressed: _discovering ? null : _discoverSmartSandbox,
              icon: _discovering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore_outlined),
              label: Text(
                _discovering
                    ? _text('Checking…', '正在检查…')
                    : _text('Check live metadata', '检查实时元数据'),
              ),
            ),
          ),
          if (_discoveryError != null) ...[
            const SizedBox(height: 8),
            Text(
              _discoveryError!,
              key: const Key('smart-sandbox-discovery-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (report != null) ...[
            const SizedBox(height: 12),
            Text(
              _text('Metadata received; compatibility details', '已收到元数据；兼容性检查'),
              key: const Key('smart-sandbox-discovery-result'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            _discoveryCheck(
              _text('HTTP 200 with JSON', 'HTTP 200，JSON 格式'),
              report.status200 && report.jsonContentType,
            ),
            _discoveryCheck(
              _text(
                'Authorization endpoint is on the sandbox host',
                '授权端点位于沙箱主机',
              ),
              report.authorizationEndpointOnSandbox,
            ),
            _discoveryCheck(
              _text('Token endpoint is on the sandbox host', '令牌端点位于沙箱主机'),
              report.tokenEndpointOnSandbox,
            ),
            _discoveryCheck(
              _text('Standalone launch is advertised', '已公布独立启动能力'),
              report.standaloneLaunchAdvertised,
            ),
            _discoveryCheck(
              _text('Standalone patient context is advertised', '已公布独立启动患者上下文'),
              report.standalonePatientContextAdvertised,
            ),
            _discoveryCheck(
              _text('Public-client capability is advertised', '已公布公共客户端能力'),
              report.publicClientAdvertised,
            ),
            _discoveryCheck(
              _text('Patient permission is advertised', '已公布患者权限'),
              report.patientPermissionAdvertised,
            ),
            _discoveryCheck(
              _text('SMART v2 permission is advertised', '已公布 SMART v2 权限'),
              report.permissionV2Advertised,
            ),
            _discoveryCheck(
              _text('PKCE S256 is advertised', '已公布 PKCE S256'),
              report.pkceS256Advertised,
            ),
            _discoveryCheck(
              _text('PKCE plain is not advertised', '未公布 PKCE plain'),
              !report.pkcePlainAdvertised,
            ),
            _discoveryCheck(
              _text('Observation read scope is listed', '已列出 Observation 只读范围'),
              report.observationReadScopeAdvertised,
            ),
            _discoveryCheck(
              _text('Authorization-code grant is listed', '已列出授权码许可'),
              report.authorizationCodeGrantAdvertised,
            ),
            if (report.authorizationCodeResponseTypeAdvertised != null)
              _discoveryCheck(
                _text(
                  'Authorization-code response type is listed',
                  '已列出授权码响应类型',
                ),
                report.authorizationCodeResponseTypeAdvertised!,
              ),
            const SizedBox(height: 8),
            Text(
              _text(
                'This is one live metadata response, not SMART certification or evidence of an authorization or FHIR exchange.',
                '这只代表一次实时元数据响应，不构成 SMART 认证，也不证明授权或 FHIR 数据交换可用。',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _discoveryCheck(String label, bool passed) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(
          passed ? Icons.check_circle_outline : Icons.info_outline,
          size: 18,
          color: passed
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.tertiary,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(passed ? _text('listed', '已列出') : _text('no', '否')),
      ],
    ),
  );

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
  }) => TextField(
    key: key,
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
    keyboardType: keyboardType,
    autocorrect: false,
    enableSuggestions: false,
    onChanged: _invalidatePreview,
  );
}

class _PreviewResult extends StatelessWidget {
  const _PreviewResult({required this.preview, required this.isChinese});

  final FhirR4ObservationImportPreview preview;
  final bool isChinese;

  String _text(String english, String chinese) => isChinese ? chinese : english;

  @override
  Widget build(BuildContext context) {
    final color = preview.previewable
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return PaperCard(
      key: const Key('fhir-preview-result'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                preview.previewable
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: color,
                semanticLabel: _text('Preview status', '预览状态'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  preview.previewable
                      ? _text('Ready for local review', '可供本地查看')
                      : _text('Needs review', '需要检查'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            preview.previewable
                ? _text(
                    'This is a preview only. Nothing was imported or saved.',
                    '这只是预览，没有导入或保存任何内容。',
                  )
                : _text(
                    'The resource did not pass the exact-subset checks. Nothing was imported or saved.',
                    '资源未通过限定范围检查，没有导入或保存任何内容。',
                  ),
          ),
          const SizedBox(height: 12),
          _detail(
            context,
            _text('FHIR release', 'FHIR 版本'),
            preview.context.fhirVersion,
          ),
          _detail(
            context,
            _text('Source FHIR base', '来源 FHIR 基础 URL'),
            preview.context.sourceFhirBase,
          ),
          _detail(
            context,
            _text('Jurisdiction', '辖区'),
            preview.context.jurisdiction,
          ),
          _detail(
            context,
            _text('Patient reference', 'Patient 引用'),
            preview.subjectReference ?? '—',
          ),
          if (preview.resourceId != null)
            _detail(
              context,
              _text('Observation ID', 'Observation ID'),
              preview.resourceId!,
            ),
          if (preview.resourceVersionId != null)
            _detail(
              context,
              _text('Resource version', '资源版本'),
              preview.resourceVersionId!,
            ),
          if (preview.metaSource != null)
            _detail(
              context,
              _text('Resource source', '资源来源'),
              preview.metaSource!,
            ),
          if (preview.observationCodeVersion != null)
            _detail(
              context,
              _text('Panel code version', '面板代码版本'),
              preview.observationCodeVersion!,
            ),
          if (preview.effectiveDateTimeLexical != null)
            _detail(
              context,
              _text('Observed at', '观察时间'),
              preview.effectiveDateTimeLexical!,
            ),
          const SizedBox(height: 8),
          for (final component in preview.components)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(component.codeDisplay ?? component.code),
              subtitle: Text(component.code),
              trailing: Text(
                component.value == null
                    ? component.dataAbsentReasonCode ?? '—'
                    : '${component.value} ${component.unitDisplay ?? component.unitCode ?? ''}',
              ),
            ),
          if (!preview.previewable)
            ExpansionTile(
              key: const Key('fhir-preview-diagnostic-details'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                _text(
                  'Engineering details (${preview.reasonCodes.length})',
                  '工程检查详情（${preview.reasonCodes.length}）',
                ),
              ),
              children: [
                for (final reason in preview.reasonCodes)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(reason, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                for (final path in preview.unmappedPaths)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        _text('Unmapped: ', '未映射字段：') + path,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Paper.inkMuted),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
