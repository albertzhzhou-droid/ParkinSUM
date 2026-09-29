import 'package:flutter/material.dart';

import '../../core/constants/clinical_evidence_source_seed.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/cdss_records.dart';
import '../../domain/entities/evidence_currency.dart';
import '../../domain/usecases/evidence_source_currency_lookup.dart';
import '../../domain/usecases/evidence_source_metadata_search.dart';

/// Searches only the locally registered evidence-source metadata.
///
/// Queries are kept in widget memory and are not logged, persisted, or sent.
/// Results do not enter a rule or recommendation path.
class EvidenceSourceMetadataSearchPage extends StatefulWidget {
  const EvidenceSourceMetadataSearchPage({
    super.key,
    required this.localeTag,
    this.sources,
    this.currencyRegistry,
    this.asOfUtc,
  });

  final String localeTag;
  final Iterable<SourceDocumentRecord>? sources;
  final EvidenceCurrencyRegistry? currencyRegistry;
  final DateTime? asOfUtc;

  @override
  State<EvidenceSourceMetadataSearchPage> createState() =>
      _EvidenceSourceMetadataSearchPageState();
}

class _EvidenceSourceMetadataSearchPageState
    extends State<EvidenceSourceMetadataSearchPage> {
  final TextEditingController _query = TextEditingController();
  late final EvidenceSourceMetadataSearch _search;
  late final EvidenceSourceCurrencyLookupService _currencyLookup;
  late final int _sourceCount;
  List<EvidenceSourceMetadataSearchHit> _hits =
      const <EvidenceSourceMetadataSearchHit>[];
  bool _queryLimitExceeded = false;

  bool get _chinese => widget.localeTag.toLowerCase().startsWith('zh');

  @override
  void initState() {
    super.initState();
    final sources = List<SourceDocumentRecord>.unmodifiable(
      widget.sources ?? clinicalEvidenceSourceDocuments,
    );
    _sourceCount = sources.length;
    _search = EvidenceSourceMetadataSearch(sources: sources);
    _currencyLookup = EvidenceSourceCurrencyLookupService(
      registry: widget.currencyRegistry ?? EvidenceCurrencyRegistry.current,
      asOfUtc: widget.asOfUtc ?? DateTime.now().toUtc(),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _searchChanged(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _hits = const <EvidenceSourceMetadataSearchHit>[];
        _queryLimitExceeded = false;
        return;
      }
      try {
        _hits = _search.search(query);
        _queryLimitExceeded = false;
      } on ArgumentError {
        _hits = const <EvidenceSourceMetadataSearchHit>[];
        _queryLimitExceeded = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: PaperAppBar(
        title: Text(
          _chinese ? '证据来源检索' : 'Evidence source search',
          key: const Key('evidence-source-search-title'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _chinese
                      ? '本地来源元数据 · $_sourceCount 条记录'
                      : 'Local source metadata · $_sourceCount records',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _chinese
                      ? '按标题、机构、来源类型、文档类型、辖区、语言和许可说明进行本地 BM25 排序。不会检索原始载荷全文，也不会保存、记录或发送查询。精确来源 ID 匹配时会另行显示本地登记的声明状态；未登记不代表当前、已撤回或安全。排序和登记状态均不代表证据质量、适用性或结论；无匹配不表示证据不存在。'
                      : 'Local BM25 ordering uses titles, organizations, source and document types, jurisdiction, language, and license notes. It does not search raw payloads or save, log, or send queries. An exact source-ID match may show separately recorded claim status; no registry entry does not establish current, withdrawn, or safe status. Neither order nor recorded status measures evidence quality, applicability, or conclusions. No match does not mean evidence is absent.',
                  key: const Key('evidence-source-search-boundary'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('evidence-source-search-input'),
            controller: _query,
            maxLength: 120,
            textInputAction: TextInputAction.search,
            onChanged: _searchChanged,
            decoration: InputDecoration(
              labelText: _chinese ? '检索来源元数据' : 'Search source metadata',
              hintText: _chinese
                  ? '例如：levodopa、FDA、Canada'
                  : 'For example: levodopa, FDA, Canada',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('clear-evidence-source-search'),
                      tooltip: _chinese ? '清除检索词' : 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _query.clear();
                        _searchChanged('');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_query.text.trim().isEmpty)
            _StatusCard(
              key: const Key('evidence-source-search-idle'),
              text: _chinese
                  ? '输入关键词后查看匹配的来源记录。'
                  : 'Enter terms to find matching source records.',
            )
          else if (_queryLimitExceeded)
            _StatusCard(
              key: const Key('evidence-source-search-query-limit'),
              text: _chinese
                  ? '检索词过长或不同关键词超过 16 个。请缩短查询后重试。'
                  : 'The query is too long or has more than 16 distinct terms. Shorten it and try again.',
            )
          else if (_hits.isEmpty)
            _StatusCard(
              key: const Key('evidence-source-search-no-match'),
              text: _chinese
                  ? '没有元数据匹配。这不表示相关来源或证据不存在。'
                  : 'No metadata match. This does not show that a source or evidence is absent.',
            )
          else ...[
            Text(
              _chinese
                  ? '检索顺序 · ${_hits.length} 条来源记录'
                  : 'Retrieval order · ${_hits.length} source records',
              key: const Key('evidence-source-search-result-count'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _hits.length; index++) ...[
              _EvidenceSourceHitCard(
                hit: _hits[index],
                currencyStatus: _currencyLookup.lookup(_hits[index].source),
                rank: index + 1,
                chinese: _chinese,
              ),
              if (index + 1 < _hits.length) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _EvidenceSourceHitCard extends StatelessWidget {
  const _EvidenceSourceHitCard({
    required this.hit,
    required this.currencyStatus,
    required this.rank,
    required this.chinese,
  });

  final EvidenceSourceMetadataSearchHit hit;
  final EvidenceSourceCurrencyStatusLookup currencyStatus;
  final int rank;
  final bool chinese;

  @override
  Widget build(BuildContext context) {
    final source = hit.source;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$rank. ${source.title}',
            key: Key('evidence-source-hit-title-$rank'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text('${source.organization} · ${source.sourceFamily}'),
          Text(
            '${chinese ? '辖区' : 'Jurisdiction'}: ${source.jurisdiction} · '
            '${chinese ? '类型' : 'Type'}: ${source.docType} · ${source.language}',
          ),
          Text(
            '${chinese ? '来源记录 ID' : 'Source record ID'}: ${source.sourceDocId}',
            key: Key('evidence-source-hit-id-${source.sourceDocId}'),
          ),
          if (source.publishedAt case final publishedAt?)
            Text(
              '${chinese ? '发布日期' : 'Published'}: '
              '${publishedAt.toIso8601String().split('T').first}',
            ),
          const SizedBox(height: 6),
          Text(
            '${chinese ? '许可说明' : 'License note'}: ${source.licenseNote}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _EvidenceCurrencyStatusPanel(
            lookup: currencyStatus,
            chinese: chinese,
          ),
          const SizedBox(height: 8),
          Text(
            chinese ? '匹配元数据词' : 'Matched metadata terms',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final term in hit.matchedTerms)
                Chip(
                  key: Key(
                    'evidence-source-hit-term-${source.sourceDocId}-$term',
                  ),
                  label: Text(term),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceCurrencyStatusPanel extends StatelessWidget {
  const _EvidenceCurrencyStatusPanel({
    required this.lookup,
    required this.chinese,
  });

  final EvidenceSourceCurrencyStatusLookup lookup;
  final bool chinese;

  String _statusLabel(EvidenceCurrencyStatus status) => switch (status) {
    EvidenceCurrencyStatus.current =>
      chinese ? '登记为 current' : 'Current (recorded)',
    EvidenceCurrencyStatus.corrected =>
      chinese ? '已更正 · 需复核' : 'Corrected · review held',
    EvidenceCurrencyStatus.superseded => chinese ? '已被替代' : 'Superseded',
    EvidenceCurrencyStatus.retracted => chinese ? '已撤稿' : 'Retracted',
    EvidenceCurrencyStatus.withdrawn => chinese ? '已撤回' : 'Withdrawn',
    EvidenceCurrencyStatus.expressionOfConcern =>
      chinese ? '存在关注声明' : 'Expression of concern',
    EvidenceCurrencyStatus.expired => chinese ? '复核期限已过' : 'Review expired',
    EvidenceCurrencyStatus.unavailable =>
      chinese ? '状态不可用' : 'Status unavailable',
    EvidenceCurrencyStatus.unknown => chinese ? '状态未知' : 'Status unknown',
  };

  String _methodLabel(EvidenceStatusMethod method) => switch (method) {
    EvidenceStatusMethod.nlmLinkedCitationReview =>
      chinese ? 'NLM 关联引文人工复核' : 'NLM linked-citation review',
    EvidenceStatusMethod.crossmarkMetadataReview =>
      chinese ? 'Crossmark 元数据复核' : 'Crossmark metadata review',
    EvidenceStatusMethod.regulatoryPublisherReview =>
      chinese ? '监管发布方复核' : 'Regulatory publisher review',
    EvidenceStatusMethod.sourceOwnerRevisionReview =>
      chinese ? '来源方版本复核' : 'Source-owner revision review',
  };

  @override
  Widget build(BuildContext context) {
    final title = chinese ? '声明级状态登记' : 'Claim-level status registry';
    final detail = switch (lookup.state) {
      EvidenceSourceCurrencyLookupState.registryIntegrityHold =>
        chinese
            ? '状态登记表完整性未通过；本来源的声明状态不显示。'
            : 'Registry integrity did not pass; claim status is withheld.',
      EvidenceSourceCurrencyLookupState.noRegisteredClaimRecord =>
        chinese
            ? '此精确来源 ID 没有关联的声明状态记录。'
            : 'No claim-status record is linked to this exact source ID.',
      EvidenceSourceCurrencyLookupState.linkedClaimRecords => null,
    };
    return Container(
      key: Key('evidence-source-hit-currency-${lookup.sourceDocId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          if (detail != null) Text(detail),
          for (final claimStatus in lookup.claimStatuses) ...[
            Text(
              '${claimStatus.record.claimId} · '
              '${_statusLabel(claimStatus.effectiveStatus)}',
              key: Key(
                'evidence-source-currency-status-'
                '${lookup.sourceDocId}-${claimStatus.record.claimId}',
              ),
            ),
            Text(
              '${chinese ? '来源修订' : 'Source revision'}: '
              '${claimStatus.record.sourceRevision}',
            ),
            Text(
              '${chinese ? '复核方法' : 'Review method'}: '
              '${_methodLabel(claimStatus.record.statusMethod)} · '
              '${chinese ? '观察' : 'observed'} '
              '${claimStatus.record.observedAtUtc} · '
              '${chinese ? '复核期限' : 'review by'} '
              '${claimStatus.record.reviewByUtc}',
            ),
            if (claimStatus.record.updateNoticeId case final noticeId?)
              Text('${chinese ? '更新通知 ID' : 'Update notice ID'}: $noticeId'),
          ],
          const SizedBox(height: 4),
          Text(
            '${lookup.registryVersion} · ${lookup.asOfUtc.toIso8601String()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            chinese
                ? '离线快照记录，不是实时查询；缺少记录不证明无更正或撤稿。current 不代表科学有效、适用或有临床获益。'
                : 'Offline recorded status, not a live lookup; a missing row does not prove no correction or retraction. “Current” does not establish scientific validity, applicability, or clinical benefit.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => PaperCard(child: Text(text));
}
