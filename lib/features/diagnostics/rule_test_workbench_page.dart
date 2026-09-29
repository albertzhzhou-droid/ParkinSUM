import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/rule_set_diff.dart';
import '../../domain/entities/rule_test_case.dart';
import '../../domain/entities/rule_test_suite.dart';
import '../../domain/usecases/rule_explanation_projection.dart';
import '../../domain/usecases/rule_set_diff_service.dart';
import '../../domain/usecases/synthetic_cds_hooks_card_projector.dart';
import '../../domain/usecases/synthetic_rule_test_runner.dart';
import '../../domain/usecases/synthetic_rule_test_suite_runner.dart';

typedef RuleTestWorkbenchRun =
    FutureOr<RuleTestRunReport> Function({
      required RuleTestCase testCase,
      required RuleTestRuleSet ruleSet,
      required RuleTestExecutionMode mode,
    });

/// A disposable, synthetic-only workspace. It has no account or storage
/// dependency and never promotes an imported rule pack into the app.
class RuleTestWorkbenchPage extends StatefulWidget {
  const RuleTestWorkbenchPage({
    super.key,
    this.localeTag,
    this.initialRuleSet,
    this.initialTestCase,
    this.runCase,
  });

  final String? localeTag;
  final RuleTestRuleSet? initialRuleSet;
  final RuleTestCase? initialTestCase;
  final RuleTestWorkbenchRun? runCase;

  @override
  State<RuleTestWorkbenchPage> createState() => _RuleTestWorkbenchPageState();
}

class _RuleTestWorkbenchPageState extends State<RuleTestWorkbenchPage> {
  static const _json = JsonEncoder.withIndent('  ');
  late final TextEditingController _caseText;
  late final TextEditingController _packText;
  late final TextEditingController _suiteText;
  late final TextEditingController _suiteCheckpointText;
  late RuleTestRuleSet _ruleSet;
  late RuleTestCase _testCase;
  RuleTestRunReport? _report;
  RuleTestSuiteRunReport? _suiteReport;
  RuleSetDiffReport? _diff;
  String? _error;
  String? _notice;
  bool _packDirty = false;
  bool _running = false;
  bool _pauseSuiteRequested = false;
  bool _suitePaused = false;
  bool _suiteReplayingCheckpoint = false;
  int _suiteProgress = 0;
  int _runEpoch = 0;
  RuleTestExecutionMode _mode = RuleTestExecutionMode.activeOnly;

  bool get _chinese =>
      (widget.localeTag ?? Localizations.localeOf(context).toLanguageTag())
          .toLowerCase()
          .startsWith('zh');
  String _copy(String en, String zh) => _chinese ? zh : en;

  @override
  void initState() {
    super.initState();
    _ruleSet = widget.initialRuleSet ?? RuleTestRuleSet.baseline();
    _testCase = widget.initialTestCase ?? RuleTestCase.seed(ruleSet: _ruleSet);
    _caseText = TextEditingController(text: _editorJson(_testCase.toJson()));
    _packText = TextEditingController(text: _editorJson(_ruleSet.toJson()));
    _suiteText = TextEditingController(
      text: _editorJson(
        RuleTestSuite(
          suiteId: 'synthetic-rule-suite-001',
          title: 'Synthetic starter suite',
          cases: [_testCase],
        ).toJson(),
      ),
    );
    _suiteCheckpointText = TextEditingController();
  }

  // Pretty-print only when the result remains importable under the entity's
  // byte limit. A valid compact package must survive a display/export cycle.
  String _editorJson(Map<String, dynamic> value) {
    final pretty = _json.convert(value);
    return utf8.encode(pretty).length <= ruleTestMaxJsonBytes
        ? pretty
        : jsonEncode(value);
  }

  @override
  void dispose() {
    _runEpoch++;
    _caseText.dispose();
    _packText.dispose();
    _suiteText.dispose();
    _suiteCheckpointText.dispose();
    super.dispose();
  }

  void _invalidate() {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    _runEpoch++;
    _running = false;
    _report = null;
    _suiteReport = null;
    _suiteProgress = 0;
    _error = null;
    _notice = null;
  }

  void _edited({bool pack = false}) => setState(() {
    _invalidate();
    if (pack) {
      _packDirty = true;
      _diff = null;
    }
  });

  RuleTestCase _readCase() {
    return RuleTestCase.decode(_caseText.text);
  }

  RuleTestRuleSet _readPack() => RuleTestRuleSet.decode(_packText.text);

  void _showError(Object error) {
    if (!mounted) return;
    final message =
        _copy('Could not use this input: ', '无法使用此输入：') +
        (error is FormatException ? error.message : error.toString());
    setState(() {
      _error = message;
      _notice = null;
    });
    // Import actions can be above the report on a small screen. Keep failure
    // feedback visible at the action site as well as in the report area.
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.errorContainer.withAlpha(255),
        content: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }

  void _importCase() {
    setState(_invalidate);
    try {
      final testCase = _readCase();
      setState(() {
        _testCase = testCase;
        _caseText.text = _editorJson(testCase.toJson());
        _notice = _copy(
          'Case imported. Expectations preserved.',
          '案例已导入，预期值已保留。',
        );
      });
      debugPrint('[RuleTestWorkbench] synthetic case imported');
    } catch (error) {
      _showError(error);
    }
  }

  void _importSuite() {
    setState(_invalidate);
    try {
      final suite = RuleTestSuite.decode(_suiteText.text);
      setState(() {
        _suiteText.text = _editorJson(suite.toJson());
        _notice = _copy(
          'Suite imported. Case bindings and expectations are preserved.',
          '套件已导入。案例绑定和预期结果均已保留。',
        );
      });
      debugPrint(
        '[RuleTestWorkbench] synthetic suite imported: ${suite.cases.length} cases',
      );
    } catch (error) {
      _showError(error);
    }
  }

  void _comparePack() {
    setState(() {
      _invalidate();
      _diff = null;
    });
    try {
      final candidate = _readPack();
      final diff = const RuleSetDiffService().compare(
        beforeRules: _ruleSet.rawRules,
        afterRules: candidate.rawRules,
      );
      setState(() => _diff = diff);
    } catch (error) {
      _showError(error);
    }
  }

  void _importPack() {
    setState(() {
      _invalidate();
      _diff = null;
    });
    try {
      final candidate = _readPack();
      final diff = const RuleSetDiffService().compare(
        beforeRules: _ruleSet.rawRules,
        afterRules: candidate.rawRules,
      );
      setState(() {
        _ruleSet = candidate;
        _packText.text = _editorJson(candidate.toJson());
        _packDirty = false;
        _diff = diff;
        _notice = _copy(
          'Rule pack imported into this workspace. Case binding is unchanged.',
          '规则包已导入此工作区。案例绑定未更改。',
        );
      });
      debugPrint('[RuleTestWorkbench] synthetic rule pack imported');
    } catch (error) {
      _showError(error);
    }
  }

  void _bindCase() {
    setState(_invalidate);
    try {
      final testCase = _readCase().copyWith(binding: _ruleSet.binding);
      setState(() {
        _testCase = testCase;
        _caseText.text = _editorJson(testCase.toJson());
        _notice = _copy(
          'Case bound to the active pack. Expectations preserved; run again to check them.',
          '案例已绑定活动规则包。预期值已保留，请重新运行验证。',
        );
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _copyJson({required bool pack}) async {
    final epoch = _runEpoch;
    try {
      final value = pack ? _readPack().encode() : _readCase().encode();
      await Clipboard.setData(ClipboardData(text: value));
      if (!mounted || epoch != _runEpoch) return;
      setState(() {
        _error = null;
        _notice = _copy('JSON copied.', 'JSON 已复制。');
      });
    } catch (error) {
      if (epoch == _runEpoch) _showError(error);
    }
  }

  Future<void> _copyReport() async {
    final report = _report;
    if (report == null) return;
    final epoch = _runEpoch;
    try {
      await Clipboard.setData(
        ClipboardData(text: _json.convert(report.toJson())),
      );
      if (!mounted || epoch != _runEpoch) return;
      setState(() => _notice = _copy('Report JSON copied.', '报告 JSON 已复制。'));
    } catch (error) {
      if (epoch == _runEpoch) _showError(error);
    }
  }

  Future<void> _copySuite() async {
    final epoch = _runEpoch;
    try {
      final suite = RuleTestSuite.decode(_suiteText.text);
      await Clipboard.setData(ClipboardData(text: suite.encode()));
      if (!mounted || epoch != _runEpoch) return;
      setState(() {
        _error = null;
        _notice = _copy('Suite JSON copied.', '套件 JSON 已复制。');
      });
    } catch (error) {
      if (epoch == _runEpoch) _showError(error);
    }
  }

  Future<void> _copySuiteReport() async {
    final report = _suiteReport;
    if (report == null) return;
    final epoch = _runEpoch;
    try {
      await Clipboard.setData(
        ClipboardData(text: _json.convert(report.toJson())),
      );
      if (!mounted || epoch != _runEpoch) return;
      setState(() {
        _error = null;
        _notice = _copy('Suite report JSON copied.', '套件报告 JSON 已复制。');
      });
    } catch (error) {
      if (epoch == _runEpoch) _showError(error);
    }
  }

  Future<void> _copySuiteCheckpoint() async {
    final epoch = _runEpoch;
    try {
      final checkpoint = RuleTestSuiteCheckpoint.decode(
        _suiteCheckpointText.text,
      );
      await Clipboard.setData(ClipboardData(text: checkpoint.encode()));
      if (!mounted || epoch != _runEpoch) return;
      setState(() {
        _error = null;
        _notice = _copy('Suite checkpoint JSON copied.', '套件检查点 JSON 已复制。');
      });
    } catch (error) {
      if (epoch == _runEpoch) _showError(error);
    }
  }

  void _pauseSuite() {
    if (!_running) return;
    setState(() {
      _pauseSuiteRequested = true;
      _notice = _copy(
        'The suite will pause after the current case.',
        '套件将在当前案例完成后暂停。',
      );
    });
  }

  Future<void> _run() async {
    setState(_invalidate);
    final epoch = _runEpoch;
    if (_packDirty) {
      setState(
        () => _error = _copy(
          'Rule pack edits are pending. Import the pack before running.',
          '规则包有尚未导入的编辑，请先导入规则包。',
        ),
      );
      return;
    }
    try {
      final testCase = _readCase();
      final ruleSet = _ruleSet;
      setState(() {
        _testCase = testCase;
        _running = true;
      });
      debugPrint('[RuleTestWorkbench] synthetic run started');
      final report =
          await (widget.runCase ?? const SyntheticRuleTestRunner().run)(
            testCase: testCase,
            ruleSet: ruleSet,
            mode: _mode,
          );
      if (!mounted || epoch != _runEpoch) return;
      setState(() {
        _report = report;
        _running = false;
      });
      debugPrint('[RuleTestWorkbench] synthetic run finished');
    } catch (error) {
      if (!mounted || epoch != _runEpoch) return;
      setState(() => _running = false);
      _showError(error);
    }
  }

  Future<void> _runSuite() async {
    setState(_invalidate);
    final epoch = _runEpoch;
    if (_packDirty) {
      setState(
        () => _error = _copy(
          'Rule pack edits are pending. Import the pack before running.',
          '规则包有尚未导入的编辑，请先导入规则包。',
        ),
      );
      return;
    }
    try {
      final suite = RuleTestSuite.decode(_suiteText.text);
      final ruleSet = _ruleSet;
      final checkpointText = _suiteCheckpointText.text.trim();
      final checkpoint = checkpointText.isEmpty
          ? null
          : RuleTestSuiteCheckpoint.decode(checkpointText);
      setState(() {
        _running = true;
        _pauseSuiteRequested = false;
        _suitePaused = false;
        _suiteReplayingCheckpoint = checkpoint != null;
        _suiteProgress = 0;
      });
      debugPrint(
        '[RuleTestWorkbench] synthetic suite run started: ${suite.cases.length} cases',
      );
      final execution = await SyntheticRuleTestSuiteRunner().runResumable(
        suite: suite,
        ruleSet: ruleSet,
        mode: _mode,
        checkpoint: checkpoint,
        shouldPause: () => _pauseSuiteRequested,
        onCheckpointProgress:
            ({
              required completed,
              required total,
              required latest,
              required checkpoint,
              required replayingCheckpoint,
            }) {
              if (!mounted || epoch != _runEpoch) return;
              setState(() {
                _suiteProgress = completed;
                _suiteReplayingCheckpoint = replayingCheckpoint;
                _suiteCheckpointText.text = checkpoint.encode();
              });
            },
      );
      if (!mounted || epoch != _runEpoch) return;
      if (execution.paused) {
        setState(() {
          _suitePaused = true;
          _running = false;
          _suiteCheckpointText.text = execution.checkpoint.encode();
        });
        debugPrint(
          '[RuleTestWorkbench] synthetic suite paused: '
          '${execution.checkpoint.completedCases.length}/${suite.cases.length} cases',
        );
        return;
      }
      final report = execution.report!;
      setState(() {
        _suiteReport = report;
        _running = false;
        _suitePaused = false;
        _suiteProgress = report.caseReports.length;
        _suiteCheckpointText.text = execution.checkpoint.encode();
      });
      debugPrint(
        '[RuleTestWorkbench] synthetic suite run finished: '
        '${report.passedCount}/${report.caseReports.length} passed',
      );
    } catch (error) {
      if (!mounted || epoch != _runEpoch) return;
      setState(() => _running = false);
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: AppBar(title: Text(_copy('Rule test workbench', '规则测试工作台'))),
      body: SingleChildScrollView(
        key: const ValueKey('rule-test-scroll'),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _copy(
                    'Synthetic examples only. This workspace uses no account data and saves nothing. Test results describe software behavior and are not medical recommendations.',
                    '仅限合成案例。此工作区不使用账号数据，也不保存内容。结果仅说明软件行为，不是医疗建议。',
                  ),
                ),
                const SizedBox(height: 16),
                _section(_copy('Active rule pack', '活动规则包'), [
                  _binding(_ruleSet.binding),
                  Text(
                    _copy(
                      'The digest identifies content; it does not certify authorship or approval.',
                      '摘要用于识别内容，不代表作者身份认证或批准。',
                    ),
                  ),
                ]),
                _section(_copy('Case JSON', '案例 JSON'), [
                  Text(
                    _copy(
                      'Edit the typed context and expected results below. expected.targets: null means no target expectation; [] explicitly expects no targets. Context null values mean missing or unknown. Actual output never fills in expectations.',
                      '编辑下方有类型约束的上下文和预期结果。expected.targets: null 表示未设置目标预期，[] 明确预期没有目标。上下文中的 null 表示缺失或未知。实际输出不会填入预期值。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _editor(
                    keyName: 'rule-test-case-json',
                    label: _copy('Synthetic case JSON', '合成案例 JSON'),
                    controller: _caseText,
                    onChanged: (_) => _edited(),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        key: const ValueKey('rule-test-import-case'),
                        onPressed: _importCase,
                        child: Text(_copy('Import case JSON', '导入案例 JSON')),
                      ),
                      OutlinedButton(
                        key: const ValueKey('rule-test-copy-case'),
                        onPressed: () => _copyJson(pack: false),
                        child: Text(_copy('Copy case JSON', '复制案例 JSON')),
                      ),
                      TextButton(
                        key: const ValueKey('rule-test-bind-case'),
                        onPressed: _bindCase,
                        child: Text(
                          _copy('Bind case to active pack', '将案例绑定活动规则包'),
                        ),
                      ),
                    ],
                  ),
                ]),
                _section(_copy('Synthetic test suite', '合成测试套件'), [
                  Text(
                    _copy(
                      'Run up to 16 independent cases in order. Each case keeps its own rule-pack binding and expectations. Missing expectations and binding mismatches are never counted as passes.',
                      '按顺序运行最多 16 个独立案例。每个案例保留自己的规则包绑定和预期结果。未设置预期结果或绑定不匹配都不会计为通过。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _editor(
                    keyName: 'rule-test-suite-json',
                    label: _copy('Synthetic suite JSON', '合成套件 JSON'),
                    controller: _suiteText,
                    onChanged: (_) => setState(_invalidate),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        key: const ValueKey('rule-test-import-suite'),
                        onPressed: _importSuite,
                        child: Text(_copy('Import suite JSON', '导入套件 JSON')),
                      ),
                      OutlinedButton(
                        key: const ValueKey('rule-test-copy-suite'),
                        onPressed: _copySuite,
                        child: Text(_copy('Copy suite JSON', '复制套件 JSON')),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('rule-test-run-suite'),
                        onPressed: _running ? null : _runSuite,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          _running
                              ? _copy('Running suite…', '正在运行套件…')
                              : _suiteCheckpointText.text.trim().isEmpty
                              ? _copy('Run synthetic suite', '运行合成套件')
                              : _copy('Resume synthetic suite', '继续合成套件'),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('rule-test-pause-suite'),
                        onPressed: _running && !_pauseSuiteRequested
                            ? _pauseSuite
                            : null,
                        icon: const Icon(Icons.pause),
                        label: Text(
                          _pauseSuiteRequested
                              ? _copy('Pausing…', '正在暂停…')
                              : _copy('Pause after case', '完成当前案例后暂停'),
                        ),
                      ),
                    ],
                  ),
                  if (_running && _suiteProgress > 0)
                    Text(
                      _suiteReplayingCheckpoint
                          ? _copy(
                              'Verifying saved checkpoint case $_suiteProgress',
                              '正在校验检查点案例 $_suiteProgress',
                            )
                          : _copy(
                              'Completed $_suiteProgress cases',
                              '已完成 $_suiteProgress 个案例',
                            ),
                    ),
                  if (_suitePaused)
                    Text(
                      _copy(
                        'Paused at a case boundary. Resume replays completed cases and checks their report digests first.',
                        '已在案例边界暂停。继续时会先重放已完成案例并校验报告摘要。',
                      ),
                      key: const ValueKey('rule-test-suite-paused'),
                    ),
                  const SizedBox(height: 8),
                  _editor(
                    keyName: 'rule-test-suite-checkpoint-json',
                    label: _copy(
                      'Portable synthetic suite checkpoint JSON',
                      '可移植合成套件检查点 JSON',
                    ),
                    controller: _suiteCheckpointText,
                    onChanged: (_) => setState(_invalidate),
                  ),
                  Text(
                    _copy(
                      'Copy this text to resume later. Checkpoints are not saved by the app and cannot approve or activate rules.',
                      '可复制此文本以便稍后继续。应用不会保存检查点；检查点不能批准或启用规则。',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('rule-test-copy-suite-checkpoint'),
                      onPressed: _suiteCheckpointText.text.trim().isEmpty
                          ? null
                          : _copySuiteCheckpoint,
                      icon: const Icon(Icons.copy),
                      label: Text(_copy('Copy checkpoint JSON', '复制检查点 JSON')),
                    ),
                  ),
                  if (_suiteReport != null) _suiteReportView(_suiteReport!),
                ]),
                _section(
                  _copy('Historical or draft rule pack JSON', '历史或草稿规则包 JSON'),
                  [
                    Text(
                      _copy(
                        'Paste an exported, pinned rule pack. Editing its content invalidates its digest. Import affects only this synthetic workspace. Rule authoring is not available here.',
                        '粘贴已导出且带摘要的规则包。修改内容会使摘要失效。导入仅影响此合成工作区；这里不支持编写新规则。',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      key: const ValueKey('rule-test-pack-editor-toggle'),
                      title: Text(_copy('Show rule pack JSON', '显示规则包 JSON')),
                      maintainState: true,
                      children: [
                        _editor(
                          keyName: 'rule-test-pack-json',
                          label: _copy('Rule pack JSON', '规则包 JSON'),
                          controller: _packText,
                          onChanged: (_) => _edited(pack: true),
                        ),
                      ],
                    ),
                    if (_packDirty)
                      Text(
                        _copy(
                          'Rule pack edits are not imported.',
                          '规则包编辑尚未导入。',
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          key: const ValueKey('rule-test-compare-pack'),
                          onPressed: _comparePack,
                          child: Text(
                            _copy('Compare with active pack', '与活动规则包比较'),
                          ),
                        ),
                        OutlinedButton(
                          key: const ValueKey('rule-test-import-pack'),
                          onPressed: _importPack,
                          child: Text(_copy('Import rule pack', '导入规则包')),
                        ),
                        OutlinedButton(
                          key: const ValueKey('rule-test-copy-pack'),
                          onPressed: () => _copyJson(pack: true),
                          child: Text(
                            _copy('Copy rule pack JSON', '复制规则包 JSON'),
                          ),
                        ),
                      ],
                    ),
                    if (_diff != null) _diffView(_diff!),
                  ],
                ),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      key: const ValueKey('rule-test-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_notice != null)
                  Semantics(liveRegion: true, child: Text(_notice!)),
                const SizedBox(height: 8),
                DropdownButtonFormField<RuleTestExecutionMode>(
                  key: const ValueKey('rule-test-mode'),
                  initialValue: _mode,
                  isExpanded: true,
                  dropdownColor: Theme.of(
                    context,
                  ).colorScheme.surface.withAlpha(255),
                  decoration: InputDecoration(
                    labelText: _copy('Simulation scope', '模拟范围'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final mode in RuleTestExecutionMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(_modeLabel(mode)),
                      ),
                  ],
                  onChanged: (mode) {
                    if (mode == null) return;
                    setState(() {
                      _invalidate();
                      _mode = mode;
                    });
                  },
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('rule-test-run'),
                  onPressed: _running ? null : _run,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    _running
                        ? _copy('Running…', '正在运行…')
                        : _copy('Run synthetic case', '运行合成案例'),
                  ),
                ),
                if (_running) const LinearProgressIndicator(),
                if (_report != null) _reportView(_report!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  Widget _editor({
    required String keyName,
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) => TextField(
    key: ValueKey(keyName),
    controller: controller,
    onChanged: onChanged,
    minLines: 5,
    maxLines: 12,
    keyboardType: TextInputType.multiline,
    autocorrect: false,
    enableSuggestions: false,
    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _binding(RuleTestRuleBinding binding) => SelectableText(
    '${_copy('Source', '来源')}: ${binding.source}\n'
    '${_copy('Bundle version', '规则包版本')}: ${binding.bundleVersion}\n'
    'SHA-256: ${binding.contentDigest}\n'
    '${_copy('Rules', '规则数')}: ${binding.ruleVersions.length}',
    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
  );

  Widget _diffView(RuleSetDiffReport diff) => Column(
    key: const ValueKey('rule-test-diff'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(),
      Text(
        _copy('Rule content comparison', '规则内容比较'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text(
        _copy(
          '${diff.addedRuleIds.length} added · ${diff.removedRuleIds.length} removed · ${diff.changedRuleIds.length} changed',
          '新增 ${diff.addedRuleIds.length} · 删除 ${diff.removedRuleIds.length} · 修改 ${diff.changedRuleIds.length}',
        ),
      ),
      if (diff.ruleOrderChanged) Text(_copy('Rule order changed.', '规则顺序已更改。')),
      for (final warning in diff.warnings)
        Text('${warning.ruleId}: ${warning.code}\n${warning.message}'),
      for (final change in diff.changes)
        ExpansionTile(
          title: Text('${change.ruleId} · ${change.kind.name}'),
          children: [
            for (final field in change.fields)
              Padding(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  '${field.path.isEmpty ? '/' : field.path}\n'
                  '${_copy('Before', '之前')}: ${field.beforePresent ? _json.convert(field.beforeValue) : _copy('(absent)', '（缺失）')}\n'
                  '${_copy('After', '之后')}: ${field.afterPresent ? _json.convert(field.afterValue) : _copy('(absent)', '（缺失）')}',
                ),
              ),
          ],
        ),
      Text(
        _copy(
          'Structural changes only; this comparison does not approve rule meaning or clinical use.',
          '仅显示结构变化；此比较不批准规则含义或临床用途。',
        ),
      ),
    ],
  );

  Widget _reportView(
    RuleTestRunReport report,
  ) => _section(_copy('Run report', '运行报告'), [
    Semantics(
      liveRegion: true,
      child: Text(
        _statusLabel(report.status),
        key: const ValueKey('rule-test-status'),
      ),
    ),
    Text(_modeLabel(report.mode)),
    Text(
      _copy(
        '${report.assertions.where((a) => a.passed).length} of ${report.assertions.length} assertions passed',
        '${report.assertions.length} 项断言中 ${report.assertions.where((a) => a.passed).length} 项通过',
      ),
    ),
    if (report.status == RuleTestRunStatus.notVerified)
      Text(
        _copy(
          'No expectations were set. This run is not verified.',
          '未设置预期结果，此次运行未经验证。',
        ),
      ),
    if (report.status == RuleTestRunStatus.bindingMismatch)
      Text(
        _copy(
          'The case binding does not match the active rule pack. Import the matching pack or explicitly bind this case again.',
          '案例绑定与活动规则包不匹配。请导入匹配的规则包，或明确重新绑定此案例。',
        ),
      ),
    Text(_copy('Case binding', '案例绑定')),
    _binding(report.testCase.binding),
    ExpansionTile(
      title: Text(_copy('Bound rule versions', '绑定的规则版本')),
      children: [
        SelectableText(_json.convert(report.testCase.binding.ruleVersions)),
      ],
    ),
    Text(
      _copy(
        'Imported packs run on the current engine. Historical executables, source documents and knowledge-base facts are not restored.',
        '导入的规则包使用当前引擎运行，不会恢复历史程序、来源文档或知识库事实。',
      ),
    ),
    ExpansionTile(
      title: Text(_copy('Execution identity and rule status', '运行身份与规则状态')),
      children: [
        SelectableText(
          _json.convert({
            'case_digest': report.caseDigest,
            'input_digest': report.inputDigest,
            'rules_digest': report.rulesDigest,
            'executed_rules_digest': report.executedRulesDigest,
            'engine_identity': report.engineIdentity,
            'rule_execution': report.ruleExecution,
          }),
        ),
      ],
    ),
    OutlinedButton.icon(
      key: const ValueKey('rule-test-copy-report'),
      onPressed: _copyReport,
      icon: const Icon(Icons.copy),
      label: Text(_copy('Copy report JSON', '复制报告 JSON')),
    ),
    for (final assertion in report.assertions)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SelectableText(
          '${assertion.passed ? _copy('PASS', '通过') : _copy('FAIL', '未通过')} · ${assertion.path}\n'
          '${_copy('Expected', '预期')}: ${_json.convert(assertion.expected)}\n'
          '${_copy('Actual', '实际')}: ${_json.convert(assertion.actual)}',
        ),
      ),
    Text(
      _copy('Rule explanations', '规则解释'),
      style: Theme.of(context).textTheme.titleSmall,
    ),
    for (final row
        in report.output?.ruleExplanationsJson ?? <Map<String, dynamic>>[])
      ExpansionTile(
        key: ValueKey('rule-test-explanation-${row['rule_id']}'),
        title: Text('${row['rule_id']}'),
        subtitle: Text('${row['user_facing_decision']}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SelectableText(_json.convert(row)),
          ),
          _cardPreview(report, '${row['rule_id']}'),
        ],
      ),
  ]);

  Widget _cardPreview(RuleTestRunReport report, String ruleId) {
    Map<String, dynamic>? response;
    String? unavailableReason;
    final output = report.output;
    if (output == null) {
      unavailableReason = _copy(
        'This run has no engine output to project.',
        '此次运行没有可供投影的引擎输出。',
      );
    } else {
      try {
        final traces = (output.alertsJson['rule_hit_trace'] as List)
            .cast<Map<String, dynamic>>();
        final matchingTraces = traces
            .where((trace) => trace['rule_id'] == ruleId)
            .toList(growable: false);
        if (matchingTraces.length != 1) {
          throw const FormatException('Rule trace is missing or ambiguous.');
        }
        final explanations = projectRuleExplanations(
          auditEntries: output.auditEntries,
          ruleHitTrace: traces,
        );
        final matchingExplanations = explanations
            .where((explanation) => explanation.ruleId == ruleId)
            .toList(growable: false);
        if (matchingExplanations.length != 1) {
          throw const FormatException(
            'Rule explanation is missing or ambiguous.',
          );
        }
        response = projectSyntheticRuleExplanationCard(
          explanation: matchingExplanations.single,
          ruleTrace: matchingTraces.single,
          rulePackVersion: report.testCase.binding.bundleVersion,
          rulePackDigest: report.rulesDigest,
          inputDigest: report.inputDigest,
        );
      } on FormatException {
        unavailableReason = _copy(
          'This rule trace cannot be represented safely by the information-only card contract.',
          '此规则轨迹无法安全地表达为仅供信息参考的卡片。',
        );
      } on ArgumentError {
        unavailableReason = _copy(
          'This rule trace cannot be represented safely by the information-only card contract.',
          '此规则轨迹无法安全地表达为仅供信息参考的卡片。',
        );
      }
    }

    return ExpansionTile(
      key: ValueKey('rule-test-card-preview-$ruleId'),
      title: Text(_copy('CDS Hooks v2 card response', 'CDS Hooks v2 卡片响应')),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SelectableText(
            response == null ? unavailableReason! : _json.convert(response),
            key: ValueKey('rule-test-card-json-$ruleId'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            _copy(
              'Synthetic preview only. This response is not sent to an EHR and does not activate rules.',
              '仅为合成数据预览。此响应不会发送到 EHR，也不会启用规则。',
            ),
          ),
        ),
      ],
    );
  }

  Widget _suiteReportView(RuleTestSuiteRunReport report) => Column(
    key: const ValueKey('rule-test-suite-report'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(),
      Text(report.suite.title, style: Theme.of(context).textTheme.titleSmall),
      Semantics(
        liveRegion: true,
        child: Text(
          _copy(
            '${report.passedCount} passed · ${report.failedCount} failed · '
                '${report.notVerifiedCount} not verified · '
                '${report.bindingMismatchCount} binding mismatches',
            '${report.passedCount} 通过 · ${report.failedCount} 未通过 · '
                '${report.notVerifiedCount} 未验证 · '
                '${report.bindingMismatchCount} 绑定不匹配',
          ),
          key: const ValueKey('rule-test-suite-summary'),
        ),
      ),
      Text(
        report.allCasesPassed
            ? _copy('Every case passed.', '所有案例均通过。')
            : _copy(
                'The suite is not fully verified. Unset expectations and binding mismatches do not count as passes.',
                '套件尚未全部验证。未设置预期结果和绑定不匹配均不计为通过。',
              ),
        key: const ValueKey('rule-test-suite-verification'),
      ),
      for (final caseReport in report.caseReports)
        ExpansionTile(
          key: ValueKey('rule-test-suite-case-${caseReport.testCase.caseId}'),
          title: Text(
            '${caseReport.testCase.title} · ${_statusLabel(caseReport.status)}',
          ),
          subtitle: Text(
            _copy(
              '${caseReport.assertions.where((assertion) => assertion.passed).length} of ${caseReport.assertions.length} assertions passed',
              '${caseReport.assertions.length} 项断言中 ${caseReport.assertions.where((assertion) => assertion.passed).length} 项通过',
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: SelectableText(
                '${_copy('Case ID', '案例 ID')}: ${caseReport.testCase.caseId}\n'
                '${_copy('Binding', '绑定')}: ${caseReport.testCase.binding.contentDigest}\n'
                '${_copy('Case digest', '案例摘要')}: ${caseReport.caseDigest}',
              ),
            ),
            if (caseReport.status == RuleTestRunStatus.notVerified)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _copy(
                    'No expectations were set for this case.',
                    '此案例未设置预期结果。',
                  ),
                ),
              ),
            if (caseReport.status == RuleTestRunStatus.bindingMismatch)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _copy(
                    'The case remains bound to different rule content; it was not rebound.',
                    '此案例仍绑定到不同的规则内容，未被重新绑定。',
                  ),
                ),
              ),
            for (final assertion in caseReport.assertions)
              Padding(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  '${assertion.passed ? _copy('PASS', '通过') : _copy('FAIL', '未通过')} · ${assertion.path}\n'
                  '${_copy('Expected', '预期')}: ${_json.convert(assertion.expected)}\n'
                  '${_copy('Actual', '实际')}: ${_json.convert(assertion.actual)}',
                ),
              ),
          ],
        ),
      OutlinedButton.icon(
        key: const ValueKey('rule-test-copy-suite-report'),
        onPressed: _copySuiteReport,
        icon: const Icon(Icons.copy),
        label: Text(_copy('Copy suite report JSON', '复制套件报告 JSON')),
      ),
      Text(
        _copy(
          'In-memory synthetic execution only. No data is saved, no rule pack is activated, and this report is not clinical validation.',
          '仅在内存中运行合成案例，不保存数据、不激活规则包；此报告不构成临床验证。',
        ),
      ),
    ],
  );

  String _modeLabel(RuleTestExecutionMode mode) => switch (mode) {
    RuleTestExecutionMode.activeOnly => _copy('Active rules only', '仅活动规则'),
    RuleTestExecutionMode.includeDraft => _copy(
      'Active and draft rules',
      '活动与草稿规则',
    ),
    RuleTestExecutionMode.allStatuses => _copy(
      'Historical simulation: all statuses',
      '历史模拟：全部状态',
    ),
  };

  String _statusLabel(RuleTestRunStatus status) => switch (status) {
    RuleTestRunStatus.passed => _copy('Passed', '通过'),
    RuleTestRunStatus.failed => _copy('Failed', '未通过'),
    RuleTestRunStatus.notVerified => _copy('Not verified', '未验证'),
    RuleTestRunStatus.bindingMismatch => _copy('Binding mismatch', '绑定不匹配'),
  };
}
