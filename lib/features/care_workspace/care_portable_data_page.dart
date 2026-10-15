import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/care_portable_data_service.dart';
import '../../core/services/portable_data_export_sink.dart';
import '../../core/state/app_state.dart';
import '../../domain/entities/visit_report_selection.dart';
import '../settings/portable_data_package_page.dart';

class CarePortableDataPage extends StatefulWidget {
  const CarePortableDataPage({super.key, this.clipboard, this.exportSink});
  final PortableDataClipboard? clipboard;
  final PortableDataExportSink? exportSink;

  @override
  State<CarePortableDataPage> createState() => _CarePortableDataPageState();
}

class _CarePortableDataPageState extends State<CarePortableDataPage> {
  final _input = TextEditingController();
  CarePortableDataArtifact? _artifact;
  VisitPreparationSourceLease? _artifactLease;
  CarePortableRestorePreview? _preview;
  AppState? _state;
  String? _owner;
  int? _session;
  bool _busy = false;
  String? _message;
  bool _expired = false;

  PortableDataClipboard get _clipboard =>
      widget.clipboard ?? const SystemPortableDataClipboard();
  String _t(String zh, String en) =>
      _state!.userProfile.displayLocale.startsWith('zh') ? zh : en;
  bool get _authorized =>
      mounted &&
      !_expired &&
      _owner != null &&
      _state!.currentUserId == _owner &&
      _state!.preferenceMutationSessionEpoch == _session &&
      !_state!.isAuthBusy &&
      _state!.isCareWorkspaceReady;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state != null) return;
    _state = context.read<AppState>();
    _owner = _state!.currentUserId;
    _session = _state!.preferenceMutationSessionEpoch;
    _state!.addListener(_checkScope);
  }

  void _checkScope() {
    if (_state!.currentUserId != _owner ||
        _state!.preferenceMutationSessionEpoch != _session) {
      _expired = true;
      _input.clear();
      _artifact = null;
      _preview = null;
    }
  }

  @override
  void dispose() {
    _state?.removeListener(_checkScope);
    _input.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_authorized || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (_authorized) {
        _message = _t(
          '未完成。请核对同一账号、数据包版本、容量和冲突，然后重新预览。已被设备接收的保存不会因会话退出而撤销。',
          'Not completed. Check the account, package version, capacity and conflicts, then preview again. A write already accepted by the device is not cancelled by ending a session.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final artifactCurrent =
        _artifact != null &&
        _artifactLease != null &&
        state.isVisitPreparationLeaseCurrent(_artifactLease!);
    final previewCurrent =
        _preview != null && state.isCarePortablePreviewCurrent(_preview!);
    return Scaffold(
      appBar: AppBar(title: Text(_t('Care 备份与恢复', 'Care backup & restore'))),
      body: !_authorized
          ? Center(
              child: Text(
                _t('会话已改变，请重新打开。', 'Session changed. Please reopen.'),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      _t(
                        '观察、问题、讨论记录与自查',
                        'Observations, questions, discussions & self-checks',
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        '这是独立的 Care 数据包，只恢复此设备上同一账号的 Care 记录。普通饮食/服药数据包不包含完整 Care 历史。恢复会合并新记录；相同编号内容不一致时拒绝。提醒、普通饮食及服药记录不会随本操作恢复。',
                        'This separate Care package restores only Care records for the same account on this device. The ordinary food/intake package does not include full Care history. Restore merges new records and rejects different content under the same identity. Reminders, ordinary meals and intakes are outside this operation.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        '包含敏感健康信息与可关联摘要，未加密、未签名。结构化账号字段被替换，自己输入的文字保持原样；分享前请检查。',
                        'Contains sensitive health information and linkable digests. Unencrypted and unsigned. Structured account fields are replaced; your own text is preserved. Review before sharing.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('care-backup-generate'),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final lease = state
                                  .captureVisitPreparationLease();
                              final artifact = state.exportCarePortableData();
                              if (!_authorized ||
                                  !state.isVisitPreparationLeaseCurrent(
                                    lease,
                                  )) {
                                return;
                              }
                              _artifact = artifact;
                              _artifactLease = lease;
                              _message = _t(
                                '已生成；请检查记录数量后复制或下载。',
                                'Generated. Review record counts before copying or downloading.',
                              );
                            }),
                      child: Text(_t('生成 Care 数据包', 'Generate Care package')),
                    ),
                    if (_artifact != null && !artifactCurrent)
                      Text(
                        _t(
                          '原备份已过期，请重新生成。',
                          'Previous backup is stale. Generate again.',
                        ),
                        key: const ValueKey('care-backup-stale'),
                      ),
                    if (artifactCurrent) ...[
                      _counts(_artifact!.counts),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            key: const ValueKey('care-backup-copy'),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    final artifact = _artifact!;
                                    final lease = _artifactLease!;
                                    bool valid() =>
                                        _authorized &&
                                        state.isVisitPreparationLeaseCurrent(
                                          lease,
                                        );
                                    await _clipboard.writeText(
                                      artifact.json,
                                      authorize: valid,
                                    );
                                    if (valid()) {
                                      _message = _t(
                                        '已复制 Care 数据包。',
                                        'Care package copied.',
                                      );
                                    }
                                  }),
                            child: Text(_t('复制 JSON', 'Copy JSON')),
                          ),
                          OutlinedButton(
                            key: const ValueKey('care-backup-download'),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    final artifact = _artifact!;
                                    final lease = _artifactLease!;
                                    bool valid() =>
                                        _authorized &&
                                        state.isVisitPreparationLeaseCurrent(
                                          lease,
                                        );
                                    final result =
                                        await (widget.exportSink ??
                                                const PortableDataExportSink())
                                            .save(
                                              fileName:
                                                  'parkinsum-user-data-care-${artifact.contentSha256}.parkinsum.json',
                                              contents: artifact.json,
                                              authorize: valid,
                                            );
                                    if (valid()) {
                                      _message =
                                          result.delivery == 'browser_download'
                                          ? _t(
                                              '浏览器已收到下载请求，请检查下载。',
                                              'Download requested. Check your browser downloads.',
                                            )
                                          : _t(
                                              '此平台请使用复制 JSON。',
                                              'Use Copy JSON on this platform.',
                                            );
                                    }
                                  }),
                            child: Text(_t('下载数据包', 'Download package')),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 32),
                    TextField(
                      key: const ValueKey('care-restore-input'),
                      controller: _input,
                      maxLines: 5,
                      maxLength: 8 * 1024 * 1024,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: _t('粘贴 Care 数据包', 'Paste Care package'),
                      ),
                      onChanged: (_) => setState(() {
                        _preview = null;
                        _message = null;
                      }),
                    ),
                    OutlinedButton(
                      key: const ValueKey('care-restore-paste'),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final text = await _clipboard.readText();
                              if (!_authorized || text == null) return;
                              if (text.length > 8 * 1024 * 1024 ||
                                  utf8.encode(text).length > 8 * 1024 * 1024) {
                                throw StateError('capacity');
                              }
                              _input.text = text;
                              _preview = null;
                            }),
                      child: Text(_t('读取剪贴板', 'Read clipboard')),
                    ),
                    OutlinedButton(
                      key: const ValueKey('care-restore-preview'),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              _preview = state.prepareCarePortableRestore(
                                _input.text,
                              );
                              _message = _t(
                                '预览不写入数据。请核对包内记录数量。',
                                'Preview writes no data. Review the package record counts.',
                              );
                            }),
                      child: Text(_t('检查并预览', 'Check & preview')),
                    ),
                    if (_preview != null && !previewCurrent)
                      Text(
                        _t('记录已改变，请重新预览。', 'Records changed. Preview again.'),
                        key: const ValueKey('care-restore-stale'),
                      ),
                    if (previewCurrent) ...[
                      _counts(_preview!.counts),
                      FilledButton(
                        key: const ValueKey('care-restore-confirm'),
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                final preview = _preview!;
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      _t('合并 Care 记录？', 'Merge Care records?'),
                                    ),
                                    content: Text(
                                      _t(
                                        '只合并上述 Care 记录。不激活提醒；不覆盖相同编号的不同内容。',
                                        'Merge only the Care records shown above. No reminder activation or replacement of conflicting records.',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        key: const ValueKey(
                                          'care-restore-dialog-cancel',
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(_t('取消', 'Cancel')),
                                      ),
                                      FilledButton(
                                        key: const ValueKey(
                                          'care-restore-dialog-confirm',
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(
                                          _t('确认合并', 'Confirm merge'),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true ||
                                    !_authorized ||
                                    !state.isCarePortablePreviewCurrent(
                                      preview,
                                    )) {
                                  return;
                                }
                                final ok = await state.restoreCarePortableData(
                                  preview,
                                  confirmed: true,
                                );
                                if (_authorized) {
                                  _preview = null;
                                  _message = ok
                                      ? _t('Care 记录已保存。', 'Care records saved.')
                                      : _t(
                                          '未收到当前会话的成功确认，请重新读取后检查。',
                                          'No success confirmation for this session. Reload and check.',
                                        );
                                }
                              }),
                        child: Text(_t('确认恢复 Care 记录', 'Confirm Care restore')),
                      ),
                    ],
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _message!,
                          key: const ValueKey('care-backup-message'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _counts(Map<String, int> counts) {
    const labels = {
      'observations': ('观察', 'Observations'),
      'notes': ('问题', 'Questions'),
      'medicationDiscussionEntries': ('药品讨论', 'Medication discussions'),
      'medicationDiscussionOutcomes': ('讨论更新', 'Discussion updates'),
      'medicationListReviews': ('自查', 'Self-checks'),
      'prompts': ('待核实事项', 'Follow-ups'),
      'feedback': ('反馈历史', 'Feedback history'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in counts.entries)
            Text(
              '${_t(labels[row.key]!.$1, labels[row.key]!.$2)}: ${row.value}',
            ),
        ],
      ),
    );
  }
}
