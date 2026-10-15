import 'package:flutter/material.dart';

import '../../core/theme/paper_theme.dart';
import '../../domain/entities/evidence_currency.dart';
import '../../domain/usecases/evidence_currency_candidate_comparison.dart';

/// Offline diagnostic example. Historical receipts are partitioned by owner,
/// and every asynchronous operation is bound to the current session lease.
class EvidenceCurrencyCandidatePanel extends StatefulWidget {
  const EvidenceCurrencyCandidatePanel({
    super.key,
    required this.localeTag,
    required this.registry,
    required this.asOfUtc,
    this.currentOwner,
    this.ownerChanges,
    this.sessionAuthorized,
    this.storeFactory,
  });

  final String localeTag;
  final EvidenceCurrencyRegistry registry;
  final DateTime asOfUtc;
  final String? Function()? currentOwner;
  final Listenable? ownerChanges;
  final bool Function()? sessionAuthorized;
  final EvidenceCurrencyComparisonReceiptStore Function(String owner)?
  storeFactory;

  @override
  State<EvidenceCurrencyCandidatePanel> createState() =>
      _EvidenceCurrencyCandidatePanelState();
}

class _EvidenceCurrencyCandidatePanelState
    extends State<EvidenceCurrencyCandidatePanel> {
  String? _owner;
  int _epoch = 0;
  bool _authorized = false;
  bool _busy = false;
  String? _status;
  EvidenceCurrencyComparisonReceipt? _preview;
  List<EvidenceCurrencyComparisonReceipt> _history = const [];

  bool get _chinese => widget.localeTag.startsWith('zh');
  String _copy(String zh, String en) => _chinese ? zh : en;
  bool get _sessionReady =>
      (widget.currentOwner?.call()?.trim().isNotEmpty ?? false) &&
      (widget.sessionAuthorized?.call() ?? true);

  @override
  void initState() {
    super.initState();
    widget.ownerChanges?.addListener(_ownerChanged);
    _synchronizeOwner();
  }

  @override
  void didUpdateWidget(EvidenceCurrencyCandidatePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerChanges != widget.ownerChanges) {
      oldWidget.ownerChanges?.removeListener(_ownerChanged);
      widget.ownerChanges?.addListener(_ownerChanged);
    }
    _synchronizeOwner();
  }

  @override
  void dispose() {
    ++_epoch;
    widget.ownerChanges?.removeListener(_ownerChanged);
    super.dispose();
  }

  void _ownerChanged() {
    if (!mounted) return;
    setState(_synchronizeOwner);
  }

  void _synchronizeOwner() {
    final owner = widget.currentOwner?.call();
    final authorized = _sessionReady;
    if (owner == _owner && authorized == _authorized) return;
    _owner = owner;
    _authorized = authorized;
    ++_epoch;
    _preview = null;
    _history = const [];
    _busy = false;
    _status = null;
    if (authorized && owner != null) {
      _loadHistory(owner, _epoch);
    }
  }

  bool _leaseCurrent(String owner, int epoch) =>
      mounted &&
      epoch == _epoch &&
      owner == _owner &&
      widget.currentOwner?.call() == owner &&
      _sessionReady;

  EvidenceCurrencyComparisonReceiptStore _store(String owner) =>
      widget.storeFactory?.call(owner) ??
      LocalEvidenceCurrencyComparisonReceiptStore(ownerId: owner);

  Future<void> _loadHistory(String owner, int epoch) async {
    try {
      final history = await _store(
        owner,
      ).load(authorize: () => _leaseCurrent(owner, epoch));
      if (!_leaseCurrent(owner, epoch)) return;
      setState(() => _history = List.unmodifiable(history.reversed));
    } catch (_) {
      if (!_leaseCurrent(owner, epoch)) return;
      setState(() {
        _status = _copy(
          '历史回执暂不可读取；已保存的数据保留。',
          'History could not be read; saved data is preserved.',
        );
      });
    }
  }

  void _compare() {
    if (widget.registry.records.isEmpty) return;
    final candidate = EvidenceCurrencyRegistry(
      records: [
        widget.registry.records.first.copyWith(
          status: EvidenceCurrencyStatus.retracted,
          updateNoticeId: 'synthetic_demo_candidate_retraction',
        ),
        ...widget.registry.records.skip(1),
      ],
    );
    setState(() {
      _preview = const EvidenceCurrencyCandidateComparisonService().compare(
        baseline: widget.registry,
        candidate: candidate,
        asOfUtc: widget.asOfUtc,
      );
      _status = null;
    });
  }

  Future<void> _save() async {
    final owner = _owner;
    final receipt = _preview;
    final epoch = _epoch;
    if (owner == null || receipt == null || !_leaseCurrent(owner, epoch)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _store(
        owner,
      ).retain(receipt, authorize: () => _leaseCurrent(owner, epoch));
      if (!_leaseCurrent(owner, epoch)) return;
      await _loadHistory(owner, epoch);
      if (!_leaseCurrent(owner, epoch)) return;
      setState(() => _status = _copy('已保存本地回执。', 'Local receipt saved.'));
    } catch (_) {
      if (!_leaseCurrent(owner, epoch)) return;
      setState(() {
        _status = _copy(
          '未能保存回执；现有历史记录保留。',
          'Receipt could not be saved; existing history is preserved.',
        );
      });
    } finally {
      if (_leaseCurrent(owner, epoch)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      key: const Key('evidence-currency-candidate-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _copy('离线证据候选对比', 'Offline evidence candidate comparison'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _copy(
              '固定合成示例：将第一条声明设为“已撤回”，与当前本地登记对比。这不是发现真实撤回。两侧使用同一检查时间和现有证据门槛；不会联网、激活候选或更改结果。回执仅证明内部一致性，不证明来源真实性或临床有效性。',
              'Fixed synthetic example: mark the first claim as retracted and compare it with the local registry. This is not a real retraction finding. Both lanes use the same check time and existing evidence gate. No network request, candidate activation, or runtime result change occurs. Receipts establish internal consistency, not source authenticity or clinical validity.',
            ),
            key: const Key('evidence-currency-candidate-boundary'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('compare-synthetic-evidence-candidate'),
            onPressed: widget.registry.records.isEmpty ? null : _compare,
            child: Text(_copy('查看合成候选', 'Compare synthetic candidate')),
          ),
          if (_preview case final receipt?) ...[
            _ReceiptSummary(receipt: receipt, chinese: _chinese),
            FilledButton(
              key: const Key('save-evidence-comparison-receipt'),
              onPressed: _authorized && !_busy ? _save : null,
              child: Text(_copy('保存本地回执', 'Save local receipt')),
            ),
          ],
          if (!_authorized)
            Text(
              _copy(
                '需要当前账户会话才能保存或查看本地历史。',
                'An active account session is required to save or view local history.',
              ),
            ),
          if (_status != null)
            Text(_status!, key: const Key('evidence-comparison-status')),
          const SizedBox(height: 8),
          Text(
            _copy(
              '已保存的历史回执 · ${_history.length}',
              'Saved historical receipts · ${_history.length}',
            ),
            key: const Key('evidence-comparison-history-count'),
          ),
          for (final receipt in _history)
            ExpansionTile(
              key: Key('evidence-receipt-${receipt.receiptSha256}'),
              title: Text(receipt.toJson()['as_of_utc'] as String),
              subtitle: Text(
                _copy('合成候选 · 未激活', 'Synthetic candidate · not activated'),
              ),
              children: [
                _ReceiptSummary(receipt: receipt, chinese: _chinese),
                for (final lane in ['baseline_snapshot', 'candidate_snapshot'])
                  _SnapshotDetails(
                    snapshot: receipt.toJson()[lane] as Map,
                    chinese: _chinese,
                    baseline: lane == 'baseline_snapshot',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReceiptSummary extends StatelessWidget {
  const _ReceiptSummary({required this.receipt, required this.chinese});
  final EvidenceCurrencyComparisonReceipt receipt;
  final bool chinese;

  @override
  Widget build(BuildContext context) {
    final json = receipt.toJson();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${chinese ? '检查时间' : 'Check time'}: ${json['as_of_utc']}'),
        for (final change in json['claim_changes'] as List)
          Text(
            '${change['claim_id']}: ${change['before_recorded_status']} → '
            '${change['candidate_recorded_status']} '
            '(${chinese ? '有效状态' : 'effective status'}: '
            '${change['before_effective_status']} → ${change['candidate_effective_status']})',
          ),
        for (final disposition in json['provider_dispositions'] as List)
          Text(
            '${disposition['provider_id']}: '
            '${_disposition(disposition['baseline'] as String)} → '
            '${_disposition(disposition['candidate'] as String)}',
          ),
      ],
    );
  }

  String _disposition(String value) => switch (value) {
    'allowResearchTraceOnly' => chinese ? '仅研究轨迹' : 'research trace only',
    'holdForReview' => chinese ? '待复核' : 'held for review',
    'blockAffectedProviders' =>
      chinese ? '受影响计算暂停' : 'affected calculation withheld',
    _ => chinese ? '登记完整性不足，暂停' : 'registry integrity block',
  };
}

class _SnapshotDetails extends StatelessWidget {
  const _SnapshotDetails({
    required this.snapshot,
    required this.chinese,
    required this.baseline,
  });
  final Map snapshot;
  final bool chinese;
  final bool baseline;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chinese
              ? (baseline ? '历史基线快照' : '历史候选快照')
              : (baseline
                    ? 'Historical baseline snapshot'
                    : 'Historical candidate snapshot'),
        ),
        Text(
          '${chinese ? '待复核声明' : 'Held claims'}: ${snapshot['held_claim_ids']}',
        ),
        Text(
          '${chinese ? '暂停声明' : 'Blocked claims'}: ${snapshot['blocked_claim_ids']}',
        ),
        for (final record in snapshot['records'] as List)
          Text(
            '${record['claim_id']} · ${record['status']} / ${record['effective_status']}\n'
            '${record['claim']}\n${record['source_id']} · ${record['source_revision']}',
          ),
      ],
    ),
  );
}
