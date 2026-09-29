import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/paper_theme.dart';
import '../../data/datasources/remote/openfda_label_mention_search.dart';
import '../../data/datasources/remote/rxnorm_name_candidate_search.dart';
import '../../domain/entities/openfda_label_mention_search.dart';

/// Opt-in research view over public U.S. product-label text.
///
/// It accepts only manually entered generic names, never reads AppState, and
/// does not persist input or results. Literal section-text matches are not
/// clinical interaction findings.
class OpenFdaLabelMentionSearchPage extends StatefulWidget {
  const OpenFdaLabelMentionSearchPage({
    super.key,
    required this.localeTag,
    this.lookup,
    this.rxNormLookup,
    this.rxNormCandidateLookup,
  });

  final String localeTag;
  final OpenFdaLabelMentionSearch? lookup;
  final RxNormNameCandidateSearch? rxNormLookup;
  final OpenFdaLabelMentionSearch? rxNormCandidateLookup;

  @override
  State<OpenFdaLabelMentionSearchPage> createState() =>
      _OpenFdaLabelMentionSearchPageState();
}

class _OpenFdaLabelMentionSearchPageState
    extends State<OpenFdaLabelMentionSearchPage> {
  final _firstName = TextEditingController();
  final _secondName = TextEditingController();
  late final http.Client? _ownedClient;
  late final OpenFdaLabelMentionSearch _lookup;
  late final OpenFdaLabelMentionSearch _rxNormCandidateLookup;
  late final RxNormNameCandidateSearch _rxNormLookup;
  OpenFdaLabelMentionSearchResult? _result;
  OpenFdaLabelMentionSearchResult? _rxNormCandidateLabelResult;
  RxNormNameCandidateSearchResult? _rxNormResult;
  String? _error;
  String? _rxNormCandidateLabelError;
  String? _rxNormError;
  bool _consent = false;
  bool _rxNormCandidateLabelConsent = false;
  bool _rxNormConsent = false;
  bool _rxNormPropertiesConsent = false;
  bool _rxNormHistoryConsent = false;
  bool _searching = false;
  bool _rxNormCandidateLabelSearching = false;
  bool _rxNormSearching = false;
  String? _selectedFirstRxNormAui;
  String? _selectedSecondRxNormAui;
  int _inputGeneration = 0;
  int _fdaRunId = 0;
  int _rxNormCandidateLabelRunId = 0;
  int _rxNormRunId = 0;
  final Set<String> _rxNormPropertiesLoading = <String>{};
  final Map<String, RxNormConceptPropertiesResult> _rxNormConceptProperties =
      <String, RxNormConceptPropertiesResult>{};
  final Map<String, String> _rxNormPropertiesErrors = <String, String>{};
  final Set<String> _rxNormHistoryLoading = <String>{};
  final Map<String, RxNormConceptHistoryResult> _rxNormConceptHistory =
      <String, RxNormConceptHistoryResult>{};
  final Map<String, String> _rxNormHistoryErrors = <String, String>{};

  bool get _chinese => widget.localeTag.toLowerCase().startsWith('zh');

  bool get _canSearch {
    bool valid(String value) => RegExp(
      r"^[A-Za-z0-9][A-Za-z0-9 .'-]{1,79}$",
    ).hasMatch(value.trim().replaceAll(RegExp(r'\s+'), ' '));

    final first = _firstName.text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    final second = _secondName.text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    return _consent &&
        !_searching &&
        valid(first) &&
        valid(second) &&
        first != second;
  }

  bool get _canSearchRxNorm {
    bool valid(String value) => RegExp(
      r"^[A-Za-z0-9][A-Za-z0-9 .'-]{1,79}$",
    ).hasMatch(value.trim().replaceAll(RegExp(r'\s+'), ' '));

    final first = _firstName.text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    final second = _secondName.text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    return _rxNormConsent &&
        !_rxNormSearching &&
        valid(first) &&
        valid(second) &&
        first != second;
  }

  RxNormNameCandidate? _selectedCandidate({required bool first}) {
    final result = _rxNormResult;
    if (result == null) return null;
    final candidates = first
        ? result.firstTerm.candidates
        : result.secondTerm.candidates;
    final selectedAui = first
        ? _selectedFirstRxNormAui
        : _selectedSecondRxNormAui;
    if (selectedAui == null) return null;
    for (final candidate in candidates) {
      if (candidate.rxAui == selectedAui) return candidate;
    }
    return null;
  }

  bool get _hasUsableSelectedRxNormCandidatePair {
    final first = _selectedCandidate(first: true);
    final second = _selectedCandidate(first: false);
    return first != null &&
        second != null &&
        OpenFdaLabelMentionSearch.canSearchRxNormCandidateName(first.name) &&
        OpenFdaLabelMentionSearch.canSearchRxNormCandidateName(second.name) &&
        first.name.trim().toLowerCase() != second.name.trim().toLowerCase();
  }

  bool get _canSearchSelectedRxNormCandidates =>
      _rxNormCandidateLabelConsent &&
      !_rxNormCandidateLabelSearching &&
      _hasUsableSelectedRxNormCandidatePair;

  @override
  void initState() {
    super.initState();
    _ownedClient =
        widget.lookup == null ||
            widget.rxNormLookup == null ||
            widget.rxNormCandidateLookup == null
        ? http.Client()
        : null;
    _lookup =
        widget.lookup ?? OpenFdaLabelMentionSearch.live(client: _ownedClient);
    _rxNormCandidateLookup =
        widget.rxNormCandidateLookup ??
        OpenFdaLabelMentionSearch.liveForSelectedRxNormCandidates(
          client: _ownedClient,
        );
    _rxNormLookup =
        widget.rxNormLookup ??
        RxNormNameCandidateSearch.live(client: _ownedClient);
    _firstName.addListener(_inputChanged);
    _secondName.addListener(_inputChanged);
  }

  void _inputChanged() {
    if (!mounted) return;
    setState(() {
      _fdaRunId++;
      _rxNormRunId++;
      _rxNormCandidateLabelRunId++;
      _inputGeneration++;
      _result = null;
      _rxNormCandidateLabelResult = null;
      _rxNormResult = null;
      _error = null;
      _rxNormCandidateLabelError = null;
      _rxNormError = null;
      _consent = false;
      _rxNormCandidateLabelConsent = false;
      _rxNormConsent = false;
      _selectedFirstRxNormAui = null;
      _selectedSecondRxNormAui = null;
      _rxNormCandidateLabelSearching = false;
      _rxNormPropertiesConsent = false;
      _rxNormHistoryConsent = false;
      _rxNormPropertiesLoading.clear();
      _rxNormConceptProperties.clear();
      _rxNormPropertiesErrors.clear();
      _rxNormHistoryLoading.clear();
      _rxNormConceptHistory.clear();
      _rxNormHistoryErrors.clear();
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _secondName.dispose();
    _ownedClient?.close();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_canSearch) return;
    final runId = ++_fdaRunId;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _result = null;
      _error = null;
    });
    debugPrint('[OpenFdaLabelMentionSearch] request_started');
    try {
      final result = await _lookup.searchPair(
        firstGenericName: _firstName.text,
        secondGenericName: _secondName.text,
      );
      if (!mounted) return;
      if (runId != _fdaRunId) {
        setState(() => _searching = false);
        return;
      }
      setState(() {
        _result = result;
        _searching = false;
        _consent = false;
      });
      debugPrint(
        '[OpenFdaLabelMentionSearch] request_finished '
        'records=${result.firstLabels.records.length + result.secondLabels.records.length}',
      );
    } on ArgumentError catch (error) {
      if (!mounted) return;
      if (runId != _fdaRunId) {
        setState(() => _searching = false);
        return;
      }
      setState(() {
        _error = error.message.toString();
        _searching = false;
        _consent = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (runId != _fdaRunId) {
        setState(() => _searching = false);
        return;
      }
      setState(() {
        _error = _chinese
            ? '查询未完成，请稍后重试。'
            : 'Search did not complete. Please retry.';
        _searching = false;
        _consent = false;
      });
      debugPrint('[OpenFdaLabelMentionSearch] request_failed');
    }
  }

  Future<void> _searchRxNormCandidates() async {
    if (!_canSearchRxNorm) return;
    final runId = ++_rxNormRunId;
    _inputGeneration++;
    FocusScope.of(context).unfocus();
    setState(() {
      _rxNormSearching = true;
      _rxNormResult = null;
      _rxNormError = null;
      _rxNormCandidateLabelRunId++;
      _rxNormCandidateLabelSearching = false;
      _rxNormCandidateLabelResult = null;
      _rxNormCandidateLabelError = null;
      _rxNormCandidateLabelConsent = false;
      _selectedFirstRxNormAui = null;
      _selectedSecondRxNormAui = null;
      _rxNormPropertiesConsent = false;
      _rxNormHistoryConsent = false;
      _rxNormPropertiesLoading.clear();
      _rxNormConceptProperties.clear();
      _rxNormPropertiesErrors.clear();
      _rxNormHistoryLoading.clear();
      _rxNormConceptHistory.clear();
      _rxNormHistoryErrors.clear();
    });
    debugPrint('[RxNormNameCandidateSearch] request_started');
    try {
      final result = await _rxNormLookup.searchPair(
        firstGenericName: _firstName.text,
        secondGenericName: _secondName.text,
      );
      if (!mounted) return;
      if (runId != _rxNormRunId) {
        setState(() => _rxNormSearching = false);
        return;
      }
      setState(() {
        _rxNormResult = result;
        _rxNormSearching = false;
        _rxNormConsent = false;
      });
      debugPrint('[RxNormNameCandidateSearch] request_finished');
    } on RxNormNameCandidateRateLimitException {
      if (!mounted) return;
      if (runId != _rxNormRunId) {
        setState(() => _rxNormSearching = false);
        return;
      }
      setState(() {
        _rxNormError = _chinese
            ? '查询过于频繁，请稍后重试。'
            : 'Please wait before starting another RxNorm lookup.';
        _rxNormSearching = false;
        _rxNormConsent = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (runId != _rxNormRunId) {
        setState(() => _rxNormSearching = false);
        return;
      }
      setState(() {
        _rxNormError = _chinese
            ? 'RxNorm 候选查询未完成，请稍后重试。'
            : 'The RxNorm candidate lookup did not complete. Please retry.';
        _rxNormSearching = false;
        _rxNormConsent = false;
      });
      debugPrint('[RxNormNameCandidateSearch] request_failed');
    }
  }

  void _selectRxNormCandidate({required bool first, required String? rxAui}) {
    if (_rxNormCandidateLabelSearching) return;
    setState(() {
      _rxNormCandidateLabelRunId++;
      if (first) {
        _selectedFirstRxNormAui = rxAui;
      } else {
        _selectedSecondRxNormAui = rxAui;
      }
      _rxNormCandidateLabelResult = null;
      _rxNormCandidateLabelError = null;
      _rxNormCandidateLabelConsent = false;
    });
  }

  Future<void> _searchSelectedRxNormCandidates() async {
    if (!_canSearchSelectedRxNormCandidates) return;
    final first = _selectedCandidate(first: true)!;
    final second = _selectedCandidate(first: false)!;
    final generation = _inputGeneration;
    final runId = ++_rxNormCandidateLabelRunId;
    FocusScope.of(context).unfocus();
    setState(() {
      _rxNormCandidateLabelSearching = true;
      _rxNormCandidateLabelResult = null;
      _rxNormCandidateLabelError = null;
    });
    debugPrint('[OpenFdaSelectedRxNormCandidateLookup] request_started');
    try {
      final result = await _rxNormCandidateLookup
          .searchSelectedRxNormCandidatePair(
            firstCandidateDisplayName: first.name,
            secondCandidateDisplayName: second.name,
          );
      if (!mounted || generation != _inputGeneration) return;
      if (runId != _rxNormCandidateLabelRunId) {
        setState(() => _rxNormCandidateLabelSearching = false);
        return;
      }
      setState(() {
        _rxNormCandidateLabelResult = result;
        _rxNormCandidateLabelSearching = false;
        _rxNormCandidateLabelConsent = false;
      });
      debugPrint('[OpenFdaSelectedRxNormCandidateLookup] request_finished');
    } on ArgumentError catch (error) {
      if (!mounted || generation != _inputGeneration) return;
      if (runId != _rxNormCandidateLabelRunId) {
        setState(() => _rxNormCandidateLabelSearching = false);
        return;
      }
      setState(() {
        _rxNormCandidateLabelError = error.message.toString();
        _rxNormCandidateLabelSearching = false;
        _rxNormCandidateLabelConsent = false;
      });
    } catch (_) {
      if (!mounted || generation != _inputGeneration) return;
      if (runId != _rxNormCandidateLabelRunId) {
        setState(() => _rxNormCandidateLabelSearching = false);
        return;
      }
      setState(() {
        _rxNormCandidateLabelError = _chinese
            ? 'FDA 候选名称检索未完成，请稍后重试。'
            : 'The FDA candidate-name lookup did not complete. Please retry.';
        _rxNormCandidateLabelSearching = false;
        _rxNormCandidateLabelConsent = false;
      });
      debugPrint('[OpenFdaSelectedRxNormCandidateLookup] request_failed');
    }
  }

  Future<void> _inspectRxNormConcept(RxNormNameCandidate candidate) async {
    if (!_rxNormPropertiesConsent ||
        _rxNormPropertiesLoading.contains(candidate.rxCui) ||
        _rxNormConceptProperties.containsKey(candidate.rxCui)) {
      return;
    }
    final generation = _inputGeneration;
    setState(() {
      _rxNormPropertiesLoading.add(candidate.rxCui);
      _rxNormPropertiesErrors.remove(candidate.rxCui);
    });
    debugPrint('[RxNormConceptProperties] request_started');
    try {
      final result = await _rxNormLookup.lookupConceptProperties(candidate);
      if (!mounted || generation != _inputGeneration) return;
      setState(() {
        _rxNormPropertiesLoading.remove(candidate.rxCui);
        _rxNormConceptProperties[candidate.rxCui] = result;
      });
      debugPrint('[RxNormConceptProperties] request_finished');
    } on RxNormNameCandidateRateLimitException {
      if (!mounted || generation != _inputGeneration) return;
      setState(() {
        _rxNormPropertiesLoading.remove(candidate.rxCui);
        _rxNormPropertiesErrors[candidate.rxCui] = _chinese
            ? '查询过于频繁，请稍后再试。'
            : 'Please wait before inspecting another RxNorm concept.';
      });
    } catch (_) {
      if (!mounted || generation != _inputGeneration) return;
      setState(() {
        _rxNormPropertiesLoading.remove(candidate.rxCui);
        _rxNormPropertiesErrors[candidate.rxCui] = _chinese
            ? '概念详情暂不可用。'
            : 'Concept properties are unavailable.';
      });
      debugPrint('[RxNormConceptProperties] request_failed');
    } finally {
      if (mounted && generation == _inputGeneration) {
        setState(() => _rxNormPropertiesConsent = false);
      }
    }
  }

  Future<void> _inspectRxNormConceptHistory(
    RxNormNameCandidate candidate,
  ) async {
    if (!_rxNormHistoryConsent ||
        _rxNormHistoryLoading.contains(candidate.rxCui) ||
        _rxNormConceptHistory.containsKey(candidate.rxCui)) {
      return;
    }
    final generation = _inputGeneration;
    setState(() {
      _rxNormHistoryLoading.add(candidate.rxCui);
      _rxNormHistoryErrors.remove(candidate.rxCui);
    });
    debugPrint('[RxNormConceptHistory] request_started');
    try {
      final result = await _rxNormLookup.lookupConceptHistory(candidate);
      if (!mounted || generation != _inputGeneration) return;
      setState(() {
        _rxNormHistoryLoading.remove(candidate.rxCui);
        _rxNormConceptHistory[candidate.rxCui] = result;
      });
      debugPrint('[RxNormConceptHistory] request_finished');
    } on RxNormNameCandidateRateLimitException {
      if (!mounted || generation != _inputGeneration) return;
      setState(() {
        _rxNormHistoryLoading.remove(candidate.rxCui);
        _rxNormHistoryErrors[candidate.rxCui] = _chinese
            ? '查询过于频繁，请稍后再试。'
            : 'Please wait before inspecting another RxNorm detail.';
      });
    } catch (_) {
      if (!mounted || generation != _inputGeneration) return;
      setState(() {
        _rxNormHistoryLoading.remove(candidate.rxCui);
        _rxNormHistoryErrors[candidate.rxCui] = _chinese
            ? '概念历史状态暂不可用。'
            : 'Concept history status is unavailable.';
      });
      debugPrint('[RxNormConceptHistory] request_failed');
    } finally {
      if (mounted && generation == _inputGeneration) {
        setState(() => _rxNormHistoryConsent = false);
      }
    }
  }

  Future<void> _copyDailyMedReference(Uri uri) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _chinese ? '已复制 DailyMed 标签链接。' : 'DailyMed label link copied.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: PaperAppBar(
        title: Text(_chinese ? 'FDA 药品标签文字检索' : 'FDA drug-label text search'),
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
                      ? '仅供教育与研究。此工具展示公开标签原文，并在返回的相互作用、禁忌、黑框警告和警告字段中做字面药名匹配；不判定相互作用、严重程度、方向或个人适用性。'
                      : 'Education and research only. This tool displays public label text and performs literal name matching in returned drug-interaction, contraindication, boxed-warning, and warning fields. It does not determine an interaction, severity, direction, or personal applicability.',
                ),
                const SizedBox(height: 10),
                Text(
                  _chinese
                      ? 'openFDA 明确说明：其结果未经验证，不应依赖这些数据作医疗决策。未检索到文字不表示没有相互作用。'
                      : 'openFDA says its results are unvalidated and should not be used to make medical-care decisions. A missing text match does not mean there is no interaction.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const SelectableText('https://open.fda.gov/apis/drug/label/'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _chinese
                      ? '输入两个通用名 / 活性成分名'
                      : 'Enter two generic or active-ingredient names',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('openfda-label-first-name'),
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: _chinese ? '第一个药名' : 'First generic name',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('openfda-label-second-name'),
                  controller: _secondName,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: _chinese ? '第二个药名' : 'Second generic name',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _chinese
                      ? '仅限 2–80 个英文字母、数字、空格、连字符、撇号或句点。每个名称最多查询 5 条标签记录。'
                      : 'Use 2–80 ASCII letters, numbers, spaces, hyphens, apostrophes, or periods. At most five label records are requested for each name.',
                ),
                const SizedBox(height: 8),
                const Divider(),
                Text(
                  _chinese
                      ? '可选：查找 RxNorm 名称候选'
                      : 'Optional: find RxNorm name candidates',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _chinese
                      ? '这是独立的词法名称检索。候选和排序不确认药品身份，也不是临床置信度；候选不会自动选中，也不会自动发送给 FDA。'
                      : 'This is a separate lexical name search. Candidates and their ordering do not confirm medication identity or indicate clinical confidence. No candidate is selected or sent to FDA automatically.',
                ),
                CheckboxListTile(
                  key: const ValueKey('rxnorm-name-candidate-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: _rxNormConsent,
                  onChanged: _rxNormSearching
                      ? null
                      : (value) =>
                            setState(() => _rxNormConsent = value ?? false),
                  title: Text(
                    _chinese
                        ? '我了解：继续后，这两个手动输入的药名会分别发送到美国国家医学图书馆（NLM）的 RxNorm API；服务方也会收到网络地址。本应用不读取已保存用药、不保存或缓存查询，并只显示有名称的 RXNORM 来源候选。'
                        : 'I understand: continuing sends these two manually entered names in separate requests to the U.S. National Library of Medicine (NLM) RxNorm API, which also receives my network address. The app does not read saved medications, save or cache queries, and displays only named RXNORM-source candidates.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                Text(
                  _chinese
                      ? '本产品使用美国国立医学图书馆（NLM）、美国国立卫生研究院（NIH）和卫生与公众服务部（HHS）的公开数据；这些机构不对本产品负责，也不背书或推荐本产品。'
                      : 'This product uses public data from the U.S. National Library of Medicine (NLM), National Institutes of Health, and Department of Health and Human Services; these agencies are not responsible for, and do not endorse or recommend, this product.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  key: const ValueKey('rxnorm-name-candidate-search'),
                  onPressed: _canSearchRxNorm ? _searchRxNormCandidates : null,
                  icon: const Icon(Icons.manage_search),
                  label: Text(
                    _rxNormSearching
                        ? (_chinese ? '正在查找候选…' : 'Finding candidates…')
                        : (_chinese
                              ? '同意并查找 RxNorm 候选'
                              : 'Agree and find RxNorm candidates'),
                  ),
                ),
                if (_rxNormError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _rxNormError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Divider(),
                CheckboxListTile(
                  key: const ValueKey('openfda-label-external-query-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: _searching
                      ? null
                      : (value) => setState(() => _consent = value ?? false),
                  title: Text(
                    _chinese
                        ? '我了解：继续后，这两个手动输入的药名会分别发送到美国 FDA 的公开 API，服务方也会看到网络地址；本应用不会读取账户、已保存用药记录、症状或备注。'
                        : 'I understand: continuing sends these two manually entered names in separate requests to the public U.S. FDA API, which also receives my network address. The app will not read my account, saved medication records, symptoms, or notes.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  key: const ValueKey('openfda-label-search'),
                  onPressed: _canSearch ? _search : null,
                  icon: const Icon(Icons.search),
                  label: Text(
                    _searching
                        ? (_chinese ? '正在查询…' : 'Searching…')
                        : (_chinese ? '同意并查询标签' : 'Agree and search labels'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_rxNormSearching) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_rxNormResult case final result?) ...[
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chinese
                        ? '可选：查看所选候选的当前 RxNorm 属性'
                        : 'Optional: inspect current RxNorm properties for a selected candidate',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _chinese
                        ? '单独同意后，只有在你点击某个候选的“查看属性”时，该 RxCUI 才会发送至 NLM；这一步不会再发送原始药名。返回的名称、TTY 类型和同义词是当前 API 元数据，不确认该概念就是你要找的药品。'
                        : 'After separate consent, a candidate RxCUI is sent to NLM only when you press that candidate’s Inspect properties button. The original search term is not sent in this follow-up request. Returned name, TTY, and synonym are current API metadata; they do not confirm that the concept is your medication.',
                  ),
                  CheckboxListTile(
                    key: const ValueKey('rxnorm-concept-properties-consent'),
                    contentPadding: EdgeInsets.zero,
                    value: _rxNormPropertiesConsent,
                    onChanged: _rxNormPropertiesLoading.isNotEmpty
                        ? null
                        : (value) => setState(
                            () => _rxNormPropertiesConsent = value ?? false,
                          ),
                    title: Text(
                      _chinese
                          ? '我单独同意：仅在我点击候选详情按钮时发送该候选 RxCUI；NLM 也会收到网络地址。'
                          : 'I separately consent to sending a candidate RxCUI only when I press its details button; NLM also receives my network address.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chinese
                        ? '可选：查看单个 RxNorm 候选的历史状态'
                        : 'Optional: inspect history/status for one RxNorm candidate',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _chinese
                        ? '这是独立的 NLM 历史接口。只有点击候选按钮时才会发送一个 RxCUI 和网络地址。多个替代代码保持为未选候选；状态或替代码不确认药品身份、剂量或临床适用性。'
                        : 'This is a separate NLM history endpoint. One RxCUI and network metadata are sent only when you press a candidate button. Every replacement remains an unselected candidate; status and replacement codes do not confirm medication identity, dose, or clinical applicability.',
                  ),
                  CheckboxListTile(
                    key: const ValueKey('rxnorm-history-status-consent'),
                    contentPadding: EdgeInsets.zero,
                    value: _rxNormHistoryConsent,
                    onChanged: _rxNormHistoryLoading.isNotEmpty
                        ? null
                        : (value) => setState(
                            () => _rxNormHistoryConsent = value ?? false,
                          ),
                    title: Text(
                      _chinese
                          ? '我单独同意：仅在我点击候选按钮时向 NLM 发送该 RxCUI；NLM 也会收到网络地址。'
                          : 'I separately consent to sending this candidate RxCUI to NLM only when I press its button; NLM also receives my network address.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _rxNormCandidates(result.firstTerm, first: true),
            const SizedBox(height: 12),
            _rxNormCandidates(result.secondTerm, first: false),
            const SizedBox(height: 12),
            _selectedRxNormCandidateLabelSearch(),
            if (_rxNormCandidateLabelSearching) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_rxNormCandidateLabelResult
                case final selectedCandidateResult?) ...[
              const SizedBox(height: 12),
              _directionalResults(
                selectedCandidateResult.firstLabels,
                otherName: selectedCandidateResult.secondGenericName,
              ),
              const SizedBox(height: 12),
              _directionalResults(
                selectedCandidateResult.secondLabels,
                otherName: selectedCandidateResult.firstGenericName,
              ),
            ],
          ],
          if (_searching) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_result case final result?) ...[
            const SizedBox(height: 12),
            _directionalResults(
              result.firstLabels,
              otherName: result.secondGenericName,
            ),
            const SizedBox(height: 12),
            _directionalResults(
              result.secondLabels,
              otherName: result.firstGenericName,
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectedRxNormCandidateLabelSearch() {
    final first = _selectedCandidate(first: true);
    final second = _selectedCandidate(first: false);
    final hasBoth = first != null && second != null;
    final sameName =
        first != null &&
        second != null &&
        first.name.trim().toLowerCase() == second.name.trim().toLowerCase();
    final candidateNamesAreSafe =
        first != null &&
        second != null &&
        OpenFdaLabelMentionSearch.canSearchRxNormCandidateName(first.name) &&
        OpenFdaLabelMentionSearch.canSearchRxNormCandidateName(second.name);
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _chinese
                ? '可选：用你选择的 RxNorm 显示名称检索 FDA 标签'
                : 'Optional: search FDA labels using your selected RxNorm display names',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _chinese
                ? '必须分别为两项输入各选一个名称，并另行同意。FDA 只会收到下面显示的两个名称和网络地址，不会收到 RxCUI 或原始输入。候选选择只是检索词选择，不确认药品身份；检索到或未检索到标签都不是相互作用结论。'
                : 'Choose one display name for each input and give separate consent. FDA receives only the two names shown below and network metadata, not the RxCUIs or original typed terms. Selecting a candidate chooses search text only; it does not confirm medication identity. Returned or missing labels are not interaction conclusions.',
          ),
          if (first != null || second != null) ...[
            const SizedBox(height: 8),
            Text(
              _chinese
                  ? '第一个：${first?.name ?? '未选择'}'
                  : 'First: ${first?.name ?? 'not selected'}',
            ),
            Text(
              _chinese
                  ? '第二个：${second?.name ?? '未选择'}'
                  : 'Second: ${second?.name ?? 'not selected'}',
            ),
          ],
          if (hasBoth && !candidateNamesAreSafe)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _chinese
                    ? '所选名称含此检索路径不接受的字符；可改用上方手动输入框并重新同意 FDA 查询。'
                    : 'A selected name contains characters this lookup path does not accept. You can enter a name above and separately consent to the manual FDA search.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (sameName)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _chinese
                    ? '请为两项选择不同的显示名称。'
                    : 'Choose two different display names.',
              ),
            ),
          CheckboxListTile(
            key: const ValueKey('rxnorm-candidate-openfda-consent'),
            contentPadding: EdgeInsets.zero,
            value: _rxNormCandidateLabelConsent,
            onChanged:
                _rxNormCandidateLabelSearching ||
                    !_hasUsableSelectedRxNormCandidatePair
                ? null
                : (value) => setState(
                    () => _rxNormCandidateLabelConsent = value ?? false,
                  ),
            title: Text(
              _chinese
                  ? '我单独同意：把上面选定的两个 RxNorm 显示名称发送到美国 FDA 公共 API。'
                  : 'I separately consent to sending the two selected RxNorm display names to the public U.S. FDA API.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            key: const ValueKey('rxnorm-candidate-openfda-search'),
            onPressed: _canSearchSelectedRxNormCandidates
                ? _searchSelectedRxNormCandidates
                : null,
            icon: const Icon(Icons.search),
            label: Text(
              _rxNormCandidateLabelSearching
                  ? (_chinese ? '正在查询 FDA 标签…' : 'Searching FDA labels…')
                  : (_chinese
                        ? '同意并按所选名称查询 FDA 标签'
                        : 'Agree and search FDA labels by selected names'),
            ),
          ),
          if (_rxNormCandidateLabelError case final error?) ...[
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rxNormCandidates(
    RxNormNameCandidateTermResult result, {
    required bool first,
  }) {
    final summary = switch (result.state) {
      RxNormNameCandidateSearchState.unavailable =>
        _chinese
            ? 'RxNav 候选服务暂不可用。'
            : 'The RxNav candidate service is unavailable.',
      RxNormNameCandidateSearchState.noNamedRxNormCandidate =>
        _chinese
            ? '响应中没有可显示的 RXNORM 名称候选；这不表示该药名或药品不存在。'
            : 'The response contained no displayable RXNORM name candidate. This does not show that the term or medication is absent.',
      RxNormNameCandidateSearchState.candidatesReturned =>
        _chinese
            ? '以下是词法候选，需由你自行核对；这不构成身份确认。'
            : 'These are lexical candidates for you to inspect; they do not confirm identity.',
    };

    return PaperCard(
      child: RadioGroup<String>(
        groupValue: first ? _selectedFirstRxNormAui : _selectedSecondRxNormAui,
        onChanged: (value) =>
            _selectRxNormCandidate(first: first, rxAui: value),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chinese
                  ? 'RxNorm 候选：${result.term}'
                  : 'RxNorm candidates: ${result.term}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(summary),
            if (result.failureStatusCode != null)
              Text('HTTP ${result.failureStatusCode}'),
            for (final candidate in result.candidates) ...[
              const Divider(),
              RadioListTile<String>(
                key: ValueKey(
                  'rxnorm-candidate-select-${first ? 'first' : 'second'}-${candidate.rxAui}',
                ),
                contentPadding: EdgeInsets.zero,
                value: candidate.rxAui,
                enabled:
                    !_rxNormCandidateLabelSearching &&
                    OpenFdaLabelMentionSearch.canSearchRxNormCandidateName(
                      candidate.name,
                    ),
                title: Text(candidate.name),
                subtitle: Text(
                  _chinese
                      ? '选作 FDA 字面搜索词，不等于用药身份确认。'
                      : 'Select as FDA search text; this does not confirm medication identity.',
                ),
              ),
              if (!OpenFdaLabelMentionSearch.canSearchRxNormCandidateName(
                candidate.name,
              ))
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Text(
                    _chinese
                        ? '此名称含不支持的字符，不能用于这条 FDA 检索路径。'
                        : 'This name contains unsupported characters for the FDA lookup path.',
                  ),
                ),
              SelectableText('RxCUI: ${candidate.rxCui}'),
              Text(
                _chinese
                    ? 'RxNav 词法排序：${candidate.lexicalRank}（仅为检索排序）'
                    : 'RxNav lexical rank: ${candidate.lexicalRank} (search ordering only)',
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                key: ValueKey('rxnorm-properties-${candidate.rxCui}'),
                onPressed:
                    !_rxNormPropertiesConsent ||
                        _rxNormPropertiesLoading.contains(candidate.rxCui) ||
                        _rxNormConceptProperties.containsKey(candidate.rxCui)
                    ? null
                    : () => _inspectRxNormConcept(candidate),
                icon: const Icon(Icons.info_outline),
                label: Text(
                  _rxNormPropertiesLoading.contains(candidate.rxCui)
                      ? (_chinese ? '正在读取属性…' : 'Loading properties…')
                      : (_chinese ? '查看此候选属性' : 'Inspect properties'),
                ),
              ),
              if (_rxNormPropertiesErrors[candidate.rxCui] case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_rxNormConceptProperties[candidate.rxCui]
                  case final properties?) ...[
                const SizedBox(height: 6),
                _rxNormProperties(properties),
              ],
              OutlinedButton.icon(
                key: ValueKey('rxnorm-history-${candidate.rxCui}'),
                onPressed:
                    !_rxNormHistoryConsent ||
                        _rxNormHistoryLoading.contains(candidate.rxCui) ||
                        _rxNormConceptHistory.containsKey(candidate.rxCui)
                    ? null
                    : () => _inspectRxNormConceptHistory(candidate),
                icon: const Icon(Icons.history_outlined),
                label: Text(
                  _rxNormHistoryLoading.contains(candidate.rxCui)
                      ? (_chinese ? '正在读取历史…' : 'Loading history…')
                      : (_chinese ? '查看历史状态' : 'Inspect history/status'),
                ),
              ),
              if (_rxNormHistoryErrors[candidate.rxCui] case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_rxNormConceptHistory[candidate.rxCui]
                  case final history?) ...[
                const SizedBox(height: 6),
                _rxNormHistory(history),
              ],
            ],
            if (result.mayHaveMoreCandidates)
              Text(
                _chinese
                    ? '结果达到本页显示上限；可能还有候选未显示。'
                    : 'The display cap was reached; additional candidates may not be shown.',
              ),
            const SizedBox(height: 8),
            Text(
              'Source: NLM RxNav approximateTerm; named RXNORM entries only.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rxNormProperties(RxNormConceptPropertiesResult properties) {
    final summary = switch (properties.state) {
      RxNormConceptPropertiesState.activePropertiesReturned =>
        _chinese
            ? 'RxNav 返回了当前活动数据集中的概念属性。'
            : 'RxNav returned concept properties in its current active dataset.',
      RxNormConceptPropertiesState.notInCurrentActiveDataset =>
        _chinese
            ? '当前活动数据集没有返回此 RxCUI 的属性；这不能证明它已停用、已删除或药品不存在。'
            : 'The current active dataset returned no properties for this RxCUI. This does not establish that it is retired, deleted, or that the medication is absent.',
      RxNormConceptPropertiesState.unavailable =>
        _chinese
            ? 'RxNorm 属性服务暂不可用。'
            : 'The RxNorm properties service is unavailable.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary),
        if (properties.failureStatusCode != null)
          Text('HTTP ${properties.failureStatusCode}'),
        if (properties.conceptName != null)
          Text(
            _chinese
                ? 'NLM 概念名称：${properties.conceptName}'
                : 'NLM concept name: ${properties.conceptName}',
          ),
        if (properties.termTypeCode != null)
          Text('TTY: ${properties.termTypeCode}'),
        if (properties.synonym != null)
          Text(
            _chinese
                ? '同义词：${properties.synonym}'
                : 'Synonym: ${properties.synonym}',
          ),
        if (properties.language != null)
          Text('Language: ${properties.language}'),
        if (properties.suppress != null)
          Text('Suppress: ${properties.suppress}'),
        Text(
          _chinese
              ? '属性检索时间（UTC）：${properties.retrievedAt.toIso8601String()}'
              : 'Properties retrieved (UTC): ${properties.retrievedAt.toIso8601String()}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _rxNormHistory(RxNormConceptHistoryResult history) {
    final status = history.status;
    final statusLabel = switch (status) {
      RxNormConceptHistoryStatus.active => 'Active',
      RxNormConceptHistoryStatus.obsolete => 'Obsolete',
      RxNormConceptHistoryStatus.remapped => 'Remapped',
      RxNormConceptHistoryStatus.quantified => 'Quantified',
      RxNormConceptHistoryStatus.notCurrent => 'NotCurrent',
      RxNormConceptHistoryStatus.unknown => 'Unknown',
      RxNormConceptHistoryStatus.unavailable =>
        _chinese ? '暂不可用' : 'Unavailable',
    };
    final interpretation = switch (status) {
      RxNormConceptHistoryStatus.active =>
        _chinese
            ? 'RxNorm 将此概念标记为当前活动；这不是对个人用药身份的确认。'
            : 'RxNorm reports this concept as currently active; this does not confirm a person’s medication identity.',
      RxNormConceptHistoryStatus.obsolete =>
        _chinese
            ? 'RxNorm 将此概念标记为 obsolete；这不是药品不存在或停药的结论。'
            : 'RxNorm reports this concept as obsolete; this is not a conclusion that the medicine is absent or stopped.',
      RxNormConceptHistoryStatus.remapped =>
        _chinese
            ? 'RxNorm 报告了一个或多个替代概念；它们仍是候选项，可能包含 obsolete 概念。'
            : 'RxNorm reports one or more replacement concepts; they remain candidates and may include obsolete concepts.',
      RxNormConceptHistoryStatus.quantified =>
        _chinese
            ? 'RxNorm 报告此概念为 quantified；关联项不是给个人的剂量建议。'
            : 'RxNorm reports a quantified concept; related entries are not dose advice for a person.',
      RxNormConceptHistoryStatus.notCurrent =>
        _chinese
            ? 'NotCurrent 可表示当前无 RxNorm 词条，也可表示历史词条已移除；不能据此推断药品缺失。'
            : 'NotCurrent can mean no current RxNorm term or removal of a historical term; it does not show that a medicine is absent.',
      RxNormConceptHistoryStatus.unknown =>
        _chinese
            ? 'RxNorm 报告此 RxCUI 未出现在其月度版本中；这不是药品不存在的结论。'
            : 'RxNorm reports that this RxCUI has not appeared in its monthly releases; this does not show that a medicine is absent.',
      RxNormConceptHistoryStatus.unavailable =>
        _chinese ? 'RxNorm 历史状态暂不可用。' : 'RxNorm history/status is unavailable.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_chinese ? 'RxNorm 状态' : 'RxNorm status'}: $statusLabel'),
        Text(interpretation),
        if (history.failureStatusCode != null)
          Text('HTTP ${history.failureStatusCode}'),
        if (history.conceptName != null)
          Text(
            '${_chinese ? 'NLM 概念名称' : 'NLM concept name'}: ${history.conceptName}',
          ),
        if (history.termTypeCode != null) Text('TTY: ${history.termTypeCode}'),
        if (history.source != null)
          Text('Source vocabulary: ${history.source}'),
        if (history.releaseStartDate != null)
          Text('Release start (MMYYYY): ${history.releaseStartDate}'),
        if (history.releaseEndDate != null)
          Text('Release end (MMYYYY): ${history.releaseEndDate}'),
        if (history.isCurrent != null) Text('Is current: ${history.isCurrent}'),
        if (history.activeStartDate != null)
          Text('Active start (MMYYYY): ${history.activeStartDate}'),
        if (history.activeEndDate != null)
          Text('Active end (MMYYYY): ${history.activeEndDate}'),
        if (history.remappedDate != null)
          Text('Remapped date (MMYYYY): ${history.remappedDate}'),
        for (final candidate in history.remappedConcepts)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(candidate.name),
            subtitle: Text(
              'RxCUI ${candidate.rxCui} · TTY ${candidate.termTypeCode} · Active ${candidate.active}',
            ),
          ),
        if (history.mayHaveMoreRemappedConcepts)
          Text(
            _chinese
                ? '界面达到替代概念显示上限；可能还有项目未显示。'
                : 'The replacement display cap was reached; additional entries may not be shown.',
          ),
        Text(
          '${_chinese ? '历史状态检索时间（UTC）' : 'History status retrieved (UTC)'}: ${history.retrievedAt.toIso8601String()}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _directionalResults(
    OpenFdaLabelNameSearch search, {
    required String otherName,
  }) {
    final mentions = search.recordsMentioning(otherName);
    final hasText = search.recordsWithSearchedLabelText > 0;
    final summary = switch (search.state) {
      OpenFdaLabelSearchState.unavailable =>
        _chinese ? 'FDA 标签服务暂不可用。' : 'The FDA label service is unavailable.',
      OpenFdaLabelSearchState.noLabelsReturned =>
        _chinese
            ? '没有返回匹配的标签记录；这不表示药名无效或没有相互作用。'
            : 'No matching label records were returned. This does not show that the name is invalid or that no interaction exists.',
      OpenFdaLabelSearchState.labelsReturned =>
        mentions.isNotEmpty
            ? (_chinese
                  ? '在返回的所选标签字段中，${mentions.length} 条包含“$otherName”的字面文字。这不是临床结论。'
                  : '${mentions.length} returned label records contain the literal text “$otherName” in the selected fields. This is not a clinical conclusion.')
            : hasText
            ? (_chinese
                  ? '返回的所选标签字段中未找到“$otherName”的字面文字。这不证明没有相互作用。'
                  : 'No literal “$otherName” text match was found in the returned selected fields. This does not prove that no interaction exists.')
            : (_chinese
                  ? '返回了标签记录，但没有可检索的相互作用、禁忌或警告字段。'
                  : 'Label records were returned, but none contained a searchable interaction, contraindication, or warning field.'),
    };

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _chinese
                ? '检索标签：${search.genericName}'
                : 'Labels searched: ${search.genericName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(summary),
          if (search.state == OpenFdaLabelSearchState.unavailable &&
              search.failureStatusCode != null)
            Text(
              _chinese
                  ? 'HTTP ${search.failureStatusCode}'
                  : 'HTTP ${search.failureStatusCode}',
            ),
          if (search.state == OpenFdaLabelSearchState.labelsReturned) ...[
            const SizedBox(height: 4),
            Text(
              _chinese
                  ? '返回 ${search.records.length} 条；API 报告匹配 ${search.totalAvailable ?? '未知'} 条。最多请求 5 条。'
                  : '${search.records.length} returned; API reports ${search.totalAvailable ?? 'an unknown number'} matches. The request is capped at five records.',
            ),
            if (search.resultsAreSampled)
              Text(
                _chinese
                    ? '结果未穷尽；其他标签可能包含不同文字。'
                    : 'The result set is partial; other labels may contain different text.',
              ),
            if (search.datasetLastUpdated != null)
              Text(
                _chinese
                    ? '数据集更新时间：${search.datasetLastUpdated}'
                    : 'Dataset last updated: ${search.datasetLastUpdated}',
              ),
            const SizedBox(height: 8),
            for (final record in search.records) ...[
              const Divider(),
              _labelRecord(record, literalMatchName: otherName),
            ],
          ],
          const SizedBox(height: 8),
          Text(
            'Source: src.openfda.drug.label',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _labelRecord(
    OpenFdaLabelTextRecord record, {
    required String literalMatchName,
  }) {
    final identity = [
      if (record.genericNames.isNotEmpty) record.genericNames.join(', '),
      if (record.brandNames.isNotEmpty) record.brandNames.join(', '),
    ].join(' · ');
    final matchingFields = record
        .searchedSectionsMentioning(literalMatchName)
        .map((section) => section.field)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          identity.isEmpty
              ? (_chinese ? 'FDA 标签记录' : 'FDA label record')
              : identity,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (record.effectiveTime != null)
          Text(
            _chinese
                ? '标签生效日期：${record.effectiveTime}'
                : 'Label effective time: ${record.effectiveTime}',
          ),
        if (record.setId != null) SelectableText('SPL Set ID: ${record.setId}'),
        if (record.version != null)
          Text(
            _chinese
                ? '标签版本：${record.version}'
                : 'Label version: ${record.version}',
          ),
        if (record.dailymedExactVersionUri case final uri?) ...[
          const SizedBox(height: 4),
          Text(
            _chinese
                ? 'DailyMed 对应版本标签页'
                : 'DailyMed label page for this version',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          SelectableText(
            uri.toString(),
            key: ValueKey('dailymed-url-${record.setId}-${record.version}'),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              key: ValueKey('copy-dailymed-reference-${record.setId}'),
              tooltip: _chinese ? '复制 DailyMed 链接' : 'Copy DailyMed URL',
              onPressed: () => _copyDailyMedReference(uri),
              icon: const Icon(Icons.copy),
            ),
          ),
          Text(
            _chinese
                ? '复制只写入系统剪贴板，不会访问 DailyMed。若在应用外打开，DailyMed 会收到标签 ID 和网络地址。'
                : 'Copying writes only to the system clipboard; it does not contact DailyMed. Opening the URL outside this app sends the label ID and network address to DailyMed.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (record.id != null) SelectableText('Label record ID: ${record.id}'),
        if (matchingFields.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _chinese
                  ? '字面文字匹配字段：${matchingFields.join(', ')}'
                  : 'Literal text match in: ${matchingFields.join(', ')}',
              key: const ValueKey('openfda-literal-match-fields'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        if (record.searchedLabelSections.isEmpty)
          Text(
            _chinese
                ? '此记录未返回所选的相互作用、禁忌、黑框警告或警告字段。'
                : 'This record returned none of the selected interaction, contraindication, boxed-warning, or warning fields.',
          ),
        for (final section in record.searchedLabelSections) ...[
          const SizedBox(height: 8),
          Text(
            section.field,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          SelectableText(section.text),
        ],
      ],
    );
  }
}
