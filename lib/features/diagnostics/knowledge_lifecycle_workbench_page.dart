import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/services.dart';
import '../../domain/entities/knowledge_approval_envelope.dart';
import '../../domain/entities/knowledge_governance_state.dart';
import '../../domain/entities/knowledge_pack.dart';
import '../../domain/usecases/knowledge_governance_service.dart';

/// A local lifecycle console for complete, synthetic-only knowledge packs.
/// Signatures are verified against externally configured trust roots; this
/// page never creates private keys or treats typed names as approval.
class KnowledgeLifecycleWorkbenchPage extends StatefulWidget {
  const KnowledgeLifecycleWorkbenchPage({
    super.key,
    required this.services,
    this.localeTag = 'en-US',
  });

  final Services services;
  final String localeTag;

  @override
  State<KnowledgeLifecycleWorkbenchPage> createState() =>
      _KnowledgeLifecycleWorkbenchPageState();
}

class _KnowledgeLifecycleWorkbenchPageState
    extends State<KnowledgeLifecycleWorkbenchPage> {
  late final TextEditingController _packJson;
  late final TextEditingController _approvalJson;
  KnowledgeGovernanceState? _state;
  KnowledgePack? _candidate;
  String? _selectedDigest;
  String? _selectedRuleId;
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _busy = false;

  bool get _chinese => widget.localeTag.toLowerCase().startsWith('zh');
  String _copy(String en, String zh) => _chinese ? zh : en;
  KnowledgeGovernanceService get _governance =>
      widget.services.knowledgeGovernanceService;
  KnowledgePackRecord? get _selectedRecord => _state?.packages[_selectedDigest];

  @override
  void initState() {
    super.initState();
    _packJson = TextEditingController();
    _approvalJson = TextEditingController();
    _refresh();
  }

  @override
  void dispose() {
    _packJson.dispose();
    _approvalJson.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await _governance.loadState();
      if (!mounted) return;
      final selected =
          state.activePack?.pack.digest ??
          (_selectedDigest != null &&
                  state.packages.containsKey(_selectedDigest)
              ? _selectedDigest
              : state.packages.keys.lastOrNull);
      setState(() {
        _state = state;
        _selectedDigest = selected;
        _selectedRuleId =
            _selectedRecord?.pack.ruleSet.ruleVersions.keys.firstOrNull;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = null;
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _notice = _copy('Lifecycle state updated.', '治理状态已更新。'));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is FormatException
            ? error.message
            : error.toString(),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _authorized() => widget.services.authService.currentUserId != null;

  void _importPack() {
    try {
      final pack = KnowledgePack.decode(_packJson.text);
      setState(() {
        _candidate = pack;
        _error = null;
        _notice = _copy(
          'Pack validated. It remains a draft until saved and separately approved.',
          '规则包结构有效；保存后仍为草稿，须另行审批。',
        );
      });
    } catch (error) {
      setState(() {
        _candidate = null;
        _error = error is FormatException ? error.message : error.toString();
      });
    }
  }

  Future<void> _saveDraft() async {
    final pack = _candidate;
    if (pack == null) return;
    await _perform(() async {
      await _governance.saveDraft(
        pack,
        actorId: pack.authorId,
        authorize: _authorized,
      );
      _selectedDigest = pack.digest;
    });
  }

  Future<KnowledgeApprovalEnvelope> _readEnvelope() async =>
      KnowledgeApprovalEnvelope.parseJson(_approvalJson.text);

  Future<void> _submit() async {
    final digest = _selectedDigest;
    if (digest == null) return;
    await _perform(() async {
      await _governance.submit(
        digest,
        authorApproval: await _readEnvelope(),
        authorize: _authorized,
      );
    });
  }

  Future<void> _review() async {
    final digest = _selectedDigest;
    if (digest == null) return;
    await _perform(() async {
      await _governance.acceptReview(
        digest,
        review: await _readEnvelope(),
        authorize: _authorized,
      );
    });
  }

  Future<void> _activate() async {
    final digest = _selectedDigest;
    if (digest == null) return;
    await _perform(() async {
      await _governance.activate(
        digest,
        publisherApproval: await _readEnvelope(),
        authorize: _authorized,
      );
    });
  }

  Future<void> _withdraw() async {
    final digest = _selectedDigest;
    if (digest == null) return;
    await _perform(() async {
      await _governance.withdraw(
        digest,
        publisherApproval: await _readEnvelope(),
        authorize: _authorized,
      );
    });
  }

  Future<void> _copyNextBinding() async {
    final state = _state;
    final record = _selectedRecord;
    if (state == null || record == null) return;
    final ruleId = switch (record.status) {
      KnowledgePackStatus.submitted => _selectedRuleId,
      _ => null,
    };
    try {
      final binding = _governance.bindingForNext(
        state,
        record.pack,
        ruleId: ruleId,
      );
      await Clipboard.setData(
        ClipboardData(
          text: const JsonEncoder.withIndent('  ').convert(binding.toJson()),
        ),
      );
      if (mounted) {
        setState(() {
          _error = null;
          _notice = _copy(
            'Next approval binding copied. A trusted external signer must create the envelope.',
            '已复制下一步审批绑定；签名信封须由受信任的外部签署方生成。',
          );
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  String _status(KnowledgePackStatus status) => status.name;

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final record = _selectedRecord;
    final policy = _governance.verifier.trustPolicy;
    final rules =
        record?.pack.ruleSet.ruleVersions.keys.toList(growable: false) ??
        const <String>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(_copy('Knowledge pack lifecycle', '知识规则包生命周期')),
        actions: [
          IconButton(
            tooltip: _copy('Refresh', '刷新'),
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section(_copy('Authority and active state', '审批信任与活动状态'), [
                        Text(
                          _copy(
                            'Trusted signing keys: ${policy.trustedKeys.length}. The app creates no signing keys. Authorship, per-rule review, and publisher approval are accepted only when signed envelopes verify under an externally configured trust policy.',
                            '受信任签名密钥：${policy.trustedKeys.length}。应用不会创建签名密钥。作者声明、逐规则审阅和发布批准都必须通过外部配置的信任策略验证。',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _copy(
                            state == null
                                ? 'Governance state is unreadable; clinical rules are held.'
                                : state.everManaged
                                ? 'Managed lifecycle has started. Without an active authorized pack, runtime stays held.'
                                : 'Only the exact bundled prototype baseline is currently authorized.',
                            state == null
                                ? '治理状态不可读；临床规则保持暂停。'
                                : state.everManaged
                                ? '托管生命周期已启动。没有活动且获授权的规则包时，运行时将保持暂停。'
                                : '当前仅授权精确匹配的内置原型基线。',
                          ),
                        ),
                        if (state?.activePack != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${state!.activePack!.pack.packId} · ${state.activePack!.pack.version} · ${state.activePack!.pack.digest}',
                            key: const ValueKey('knowledge-active-pack'),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 12),
                      _section(_copy('Import a complete pack', '导入完整规则包'), [
                        Text(
                          _copy(
                            'The pack must include pinned HTTPS sources and independent positive, negative, missing-input, and boundary cases for each rule. Cases are fixed synthetic contexts only; a passing suite is not clinical validation.',
                            '规则包须包含固定 HTTPS 来源，以及每条规则独立的正例、负例、缺失输入和边界案例。案例仅使用固定合成上下文；测试通过不代表临床验证。',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _editor(
                          key: const ValueKey('knowledge-pack-json'),
                          controller: _packJson,
                          label: _copy('Knowledge pack JSON', '知识规则包 JSON'),
                          onChanged: (_) => setState(() => _candidate = null),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              key: const ValueKey('knowledge-import-pack'),
                              onPressed: _busy ? null : _importPack,
                              child: Text(_copy('Validate JSON', '校验 JSON')),
                            ),
                            FilledButton(
                              key: const ValueKey('knowledge-save-draft'),
                              onPressed: _busy || _candidate == null
                                  ? null
                                  : _saveDraft,
                              child: Text(_copy('Save draft', '保存草稿')),
                            ),
                            if (_candidate != null)
                              Text(
                                '${_candidate!.packId} · ${_candidate!.version} · ${_candidate!.digest}',
                              ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _section(_copy('Review and release', '审阅与发布'), [
                        if (state?.packages.isNotEmpty ?? false)
                          DropdownButtonFormField<String>(
                            key: const ValueKey('knowledge-pack-selector'),
                            initialValue: _selectedDigest,
                            decoration: InputDecoration(
                              labelText: _copy('Saved pack', '已保存规则包'),
                            ),
                            items: [
                              for (final entry in state!.packages.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    '${entry.value.pack.packId} · ${entry.value.pack.version} · ${_status(entry.value.status)}',
                                  ),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => setState(() {
                                    _selectedDigest = value;
                                    _selectedRuleId = _selectedRecord
                                        ?.pack
                                        .ruleSet
                                        .ruleVersions
                                        .keys
                                        .firstOrNull;
                                  }),
                          )
                        else
                          Text(_copy('No saved packs.', '尚无已保存规则包。')),
                        if (record != null) ...[
                          const SizedBox(height: 8),
                          SelectableText(
                            '${record.pack.digest}\n${record.pack.ruleSet.ruleVersions.keys.join(', ')}',
                          ),
                          if (record.status ==
                              KnowledgePackStatus.submitted) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('knowledge-review-rule'),
                              initialValue: _selectedRuleId,
                              decoration: InputDecoration(
                                labelText: _copy('Rule to review', '选择审阅规则'),
                              ),
                              items: [
                                for (final ruleId in rules)
                                  DropdownMenuItem(
                                    value: ruleId,
                                    child: Text(ruleId),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                        setState(() => _selectedRuleId = value),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextField(
                            key: const ValueKey('knowledge-approval-envelope'),
                            controller: _approvalJson,
                            minLines: 4,
                            maxLines: 12,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: _copy(
                                'Signed approval envelope JSON',
                                '签名审批信封 JSON',
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                key: const ValueKey('knowledge-copy-binding'),
                                onPressed: _busy ? null : _copyNextBinding,
                                child: Text(
                                  _copy('Copy next binding', '复制下一步绑定'),
                                ),
                              ),
                              if (record.status == KnowledgePackStatus.draft)
                                FilledButton(
                                  key: const ValueKey('knowledge-submit'),
                                  onPressed: _busy ? null : _submit,
                                  child: Text(
                                    _copy(
                                      'Submit with author signature',
                                      '使用作者签名提交',
                                    ),
                                  ),
                                ),
                              if (record.status ==
                                  KnowledgePackStatus.submitted)
                                FilledButton(
                                  key: const ValueKey('knowledge-review'),
                                  onPressed: _busy || _selectedRuleId == null
                                      ? null
                                      : _review,
                                  child: Text(
                                    _copy('Record this rule review', '记录此规则审阅'),
                                  ),
                                ),
                              if (record.status == KnowledgePackStatus.reviewed)
                                FilledButton(
                                  key: const ValueKey('knowledge-activate'),
                                  onPressed: _busy ? null : _activate,
                                  child: Text(
                                    _copy('Activate signed pack', '激活已签名规则包'),
                                  ),
                                ),
                              if (record.status == KnowledgePackStatus.active)
                                OutlinedButton(
                                  key: const ValueKey('knowledge-withdraw'),
                                  onPressed: _busy ? null : _withdraw,
                                  child: Text(
                                    _copy('Withdraw active pack', '撤回活动规则包'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ]),
                      if (_busy) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ],
                      if (_notice != null) ...[
                        const SizedBox(height: 12),
                        Text(_notice!, key: const ValueKey('knowledge-notice')),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        SelectableText(
                          _error!,
                          key: const ValueKey('knowledge-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        _copy(
                          'Runtime remains held on malformed state, missing or expired signatures, rejected review, incomplete coverage, withdrawn packs, suite drift, engine drift, or state changes during evaluation.',
                          '状态损坏、签名缺失或过期、审阅拒绝、覆盖不完整、规则包撤回、测试套件或引擎变化，以及评估期间状态变化，都会暂停运行时判断。',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );

  Widget _editor({
    required Key key,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) => TextField(
    key: key,
    controller: controller,
    minLines: 5,
    maxLines: 14,
    autocorrect: false,
    enableSuggestions: false,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}
