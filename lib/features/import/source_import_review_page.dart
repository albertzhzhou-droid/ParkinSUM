import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/usecases/clinical_decision_support_service.dart';
import '../../domain/usecases/knowledge_base_release_service.dart';

/// A local source decision and explicit activation, without clinical approval.
class SourceImportReviewPage extends StatefulWidget {
  const SourceImportReviewPage({
    super.key,
    required this.snapshotId,
    required this.releaseService,
    required this.isSessionCurrent,
    required this.onActivated,
    this.localeTag = 'en-US',
    this.sessionChanges,
  });
  final String snapshotId;
  final KnowledgeBaseReleaseService releaseService;
  final bool Function() isSessionCurrent;
  final Future<void> Function() onActivated;
  final String localeTag;
  final Listenable? sessionChanges;
  @override
  State<SourceImportReviewPage> createState() => _SourceImportReviewPageState();
}

class _SourceImportReviewPageState extends State<SourceImportReviewPage> {
  final _reviewer = TextEditingController(), _reason = TextEditingController();
  final _choices = <String, String>{};
  Map<String, dynamic>? _session;
  CdssReviewedImportPreview? _preview;
  String? _error, _notice;
  bool _busy = false, _confirmed = false, _activated = false;
  int _page = 0;
  bool get _zh => widget.localeTag.toLowerCase().startsWith('zh');
  String _t(String en, String zh) => _zh ? zh : en;
  List<Map> get _conflicts =>
      (_session?['conflicts'] as List? ?? []).cast<Map>();
  @override
  void initState() {
    super.initState();
    widget.sessionChanges?.addListener(_sessionChanged);
    _reload();
  }

  @override
  void dispose() {
    widget.sessionChanges?.removeListener(_sessionChanged);
    _reviewer.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool _validSession() => mounted && widget.isSessionCurrent();
  void _sessionChanged() {
    if (!mounted || widget.isSessionCurrent()) return;
    setState(() {
      _session = null;
      _choices.clear();
      _preview = null;
      _confirmed = false;
      _reviewer.clear();
      _reason.clear();
      _error = _t(
        'The local review session changed. Reopen the review.',
        '本地复核会话已改变，请重新打开复核。',
      );
    });
  }

  void _invalidate() {
    setState(() {
      _preview = null;
      _confirmed = false;
      _notice = null;
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy || _activated) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (!widget.isSessionCurrent()) {
        throw StateError('Review session changed.');
      }
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _preview = null;
          _confirmed = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() => _perform(() async {
    setState(() {
      _session = null;
      _choices.clear();
      _preview = null;
      _confirmed = false;
      _page = 0;
    });
    final session = await widget.releaseService.loadImportReviewSession(
      widget.snapshotId,
    );
    if (!widget.isSessionCurrent()) throw StateError('Review session changed.');
    if (mounted) setState(() => _session = session);
  });
  Future<void> _prepare() => _perform(() async {
    final session = await widget.releaseService.prepareImportReviewSession(
      snapshotId: widget.snapshotId,
      isSessionCurrent: _validSession,
    );
    if (mounted) setState(() => _session = session);
  });
  Future<void> _previewChoices() => _perform(() async {
    final preview = await widget.releaseService.recordImportChoicesAndPreview(
      snapshotId: widget.snapshotId,
      expectedEvidenceSha256:
          '${(_session!['evidence'] as Map)['input_sha256']}',
      observationIdsByAudit: Map.of(_choices),
      reviewerReference: _reviewer.text,
      reason: _reason.text,
      isSessionCurrent: _validSession,
    );
    if (mounted) {
      setState(() {
        _preview = preview;
        _confirmed = false;
      });
    }
  });
  Future<void> _activate() => _perform(() async {
    if (!_confirmed || _preview == null) return;
    await widget.releaseService.activateReviewedImportForSession(
      preview: _preview!,
      confirmationReference: _reviewer.text,
      confirmationReason: _reason.text,
      isSessionCurrent: _validSession,
    );
    if (!mounted) return;
    setState(() {
      _activated = true;
      _preview = null;
      _notice = _t(
        'New version enabled. The original held version and alternatives remain in history.',
        '新版本已启用。原待审版本和替代证据仍保留在历史中。',
      );
    });
    try {
      await widget.onActivated();
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = _t(
            'New version enabled. Reopen the catalogue to refresh the display.',
            '新版本已启用，请重新打开目录刷新展示。',
          ),
        );
      }
    }
  });
  Future<void> _recordAction(Map c, String action) => _perform(() async {
    final ticket = c['ticket_id'];
    if (ticket is! String) throw StateError('Open review ticket unavailable.');
    await widget.releaseService.recordImportReviewActionForSession(
      isSessionCurrent: _validSession,
      ticketId: ticket,
      conflictAuditId: '${(c['audit'] as Map)['audit_id']}',
      expectedEvidenceSha256:
          '${(_session!['evidence'] as Map)['input_sha256']}',
      action: action,
      reviewerReference: _reviewer.text,
      reason: _reason.text,
    );
    if (mounted) {
      setState(() {
        _preview = null;
        _confirmed = false;
        _notice = _t(
          'Action recorded. This import remains held.',
          '已记录处理意见，该导入继续待审。',
        );
      });
    }
  });
  @override
  Widget build(BuildContext context) {
    final validText =
        _reviewer.text.trim().isNotEmpty && _reason.text.trim().isNotEmpty;
    final enabled = !_busy && !_activated && widget.isSessionCurrent();
    return Scaffold(
      appBar: AppBar(title: Text(_t('Review source differences', '复核来源差异'))),
      body: ListView(
        key: const ValueKey('source-review-list'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _t(
              'Compare the original quantities, sources and methods. Record a reason before previewing a new version. This is a local data choice; clinical permission and source currency remain separate.',
              '比较原始数量、来源和方法，说明理由后预览新版本。这是本地数据选择；临床许可与来源当前性须另行核实。',
            ),
          ),
          if (_busy)
            const LinearProgressIndicator(key: ValueKey('source-review-busy')),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _notice!,
                key: const ValueKey('source-review-notice'),
              ),
            ),
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        'Review could not be completed. Read the evidence again before confirming.',
                        '未能完成复核，请重新读取证据后确认。',
                      ),
                      key: const ValueKey('source-review-error'),
                    ),
                    SelectableText(_error!),
                  ],
                ),
              ),
            ),
          TextButton(
            onPressed: enabled ? _reload : null,
            child: Text(_t('Read evidence again', '重新读取证据')),
          ),
          if (_session != null) ...[
            if (_conflicts.any((c) => c['ticket_id'] == null))
              TextButton(
                onPressed: enabled ? _prepare : null,
                child: Text(_t('Start source review', '开始来源复核')),
              ),
            TextField(
              key: const ValueKey('source-review-reference'),
              controller: _reviewer,
              enabled: enabled,
              onChanged: (_) => _invalidate(),
              decoration: InputDecoration(
                labelText: _t('Local review reference', '本地复核记录人或编号'),
              ),
            ),
            TextField(
              key: const ValueKey('source-review-reason'),
              controller: _reason,
              enabled: enabled,
              onChanged: (_) => _invalidate(),
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: _t('Reason for these choices', '选择这些来源的理由'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t(
                '${_choices.length}/${_conflicts.length} differences selected',
                '已选择 ${_choices.length}/${_conflicts.length} 项差异',
              ),
            ),
            for (final c in _conflicts.skip(_page * 20).take(20))
              _conflictCard(c, enabled, validText),
            if (_conflicts.length > 20)
              Wrap(
                children: [
                  TextButton(
                    onPressed: enabled && _page > 0
                        ? () => setState(() => _page--)
                        : null,
                    child: Text(_t('Previous', '上一页')),
                  ),
                  Text('${_page + 1}/${(_conflicts.length / 20).ceil()}'),
                  TextButton(
                    onPressed: enabled && (_page + 1) * 20 < _conflicts.length
                        ? () => setState(() => _page++)
                        : null,
                    child: Text(_t('Next', '下一页')),
                  ),
                ],
              ),
            if (_preview == null)
              FilledButton(
                key: const ValueKey('source-review-preview'),
                onPressed:
                    enabled &&
                        validText &&
                        _conflicts.isNotEmpty &&
                        _choices.length == _conflicts.length
                    ? _previewChoices
                    : null,
                child: Text(_t('Record choices and preview', '记录选择并预览')),
              ),
            if (_preview != null) ...[
              const SizedBox(height: 16),
              Text(
                _t('New version preview', '新版本预览'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final row in _preview!.selectedObservations)
                Text(
                  '${row['raw_value_text']} ${row['unit']} · ${row['basis_type']} · ${row['source_doc_id']}',
                ),
              CheckboxListTile(
                key: const ValueKey('source-review-confirm'),
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: enabled
                    ? (v) => setState(() => _confirmed = v ?? false)
                    : null,
                title: Text(
                  _t(
                    'Enable this new version using the displayed original quantities.',
                    '使用所展示的原始数量启用该新版本。',
                  ),
                ),
              ),
              FilledButton(
                key: const ValueKey('source-review-activate'),
                onPressed: enabled && _confirmed ? _activate : null,
                child: Text(_t('Confirm and enable', '确认并启用')),
              ),
              TextButton(
                onPressed: enabled ? _invalidate : null,
                child: Text(_t('Cancel preview', '取消预览')),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _conflictCard(Map c, bool enabled, bool validText) {
    final audit = c['audit'] as Map, id = '${audit['audit_id']}';
    final candidates = (c['candidates'] as List).cast<Map>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${audit['target']}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final candidate in candidates) ...[
              const SizedBox(height: 8),
              Text(
                '${(candidate['observation'] as Map)['raw_value_text']} ${(candidate['observation'] as Map)['unit']} · ${(candidate['observation'] as Map)['basis_type']}',
              ),
              Text(
                '${_t('Method', '方法')}: ${(candidate['observation'] as Map)['method_code'] ?? '—'} · ${(candidate['observation'] as Map)['record_locator'] ?? '—'}',
              ),
              for (final source
                  in (candidate['source_documents'] as List).cast<Map>())
                Text(
                  '${source['title']} · ${source['organization']} · ${source['origin_url']}',
                ),
              ExpansionTile(
                title: Text(_t('Original evidence', '原始证据')),
                children: [
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(candidate),
                  ),
                ],
              ),
            ],
            if (c['numeric_choice_available'] == true && c['ticket_id'] != null)
              DropdownButtonFormField<String>(
                key: ValueKey('source-review-choice-$id'),
                initialValue: _choices[id],
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _t('Choose an original quantity', '选择一项原始数量'),
                ),
                items: [
                  for (final candidate in candidates)
                    if (candidate['identity_unambiguous'] == true)
                      DropdownMenuItem(
                        value:
                            '${(candidate['observation'] as Map)['observation_id']}',
                        child: Text(
                          '${(candidate['observation'] as Map)['raw_value_text']} ${(candidate['observation'] as Map)['unit']} · ${(candidate['observation'] as Map)['source_doc_id']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: enabled
                    ? (v) {
                        if (v != null) {
                          setState(() {
                            _choices[id] = v;
                            _preview = null;
                            _confirmed = false;
                          });
                        }
                      }
                    : null,
              )
            else
              Text(
                _t(
                  'Corrected evidence is needed before a numeric choice can be enabled.',
                  '需更正证据后才能启用数量选择。',
                ),
              ),
            Wrap(
              children: [
                TextButton(
                  onPressed: enabled && validText && c['ticket_id'] != null
                      ? () => _recordAction(c, 'defer')
                      : null,
                  child: Text(_t('Defer', '延期处理')),
                ),
                TextButton(
                  onPressed: enabled && validText && c['ticket_id'] != null
                      ? () => _recordAction(c, 'request_corrected_evidence')
                      : null,
                  child: Text(_t('Request corrected evidence', '要求更正证据')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
