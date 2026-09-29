import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/entities/rule_test_case.dart';
import 'package:parkinsum_companion/domain/entities/rule_test_suite.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_rule_test_runner.dart';
import 'package:parkinsum_companion/features/diagnostics/rule_test_workbench_page.dart';

const _ruleId = 'pd.ldopa.protein.window.v1';

RuleTestRuleSet _pack({int priority = 70, String status = 'active'}) {
  final rule =
      jsonDecode(jsonEncode(baselineCdssRules.first)) as Map<String, dynamic>;
  rule['priority_band'] = priority;
  rule['status'] = status;
  return RuleTestRuleSet(
    source: 'synthetic_widget_fixture',
    bundleVersion: 'fixture-v1',
    rawRules: [rule],
  );
}

RuleTestCase _positiveCase(RuleTestRuleSet pack) =>
    RuleTestCase.seed(ruleSet: pack).copyWith(
      expected: RuleTestExpectations(
        targets: [
          RuleTestTargetExpectation(
            target: 'drug-meal',
            decision: RuntimeDecisionType.warn,
            winningRuleIds: [_ruleId],
          ),
        ],
        missingFieldsByRule: const {_ruleId: []},
      ),
    );

Future<void> _pump(
  WidgetTester tester, {
  RuleTestRuleSet? pack,
  RuleTestCase? testCase,
  RuleTestWorkbenchRun? runCase,
  String locale = 'en-US',
  double width = 360,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
      // Deliberately no account provider or service graph: the workspace
      // must operate entirely from its explicit synthetic inputs.
      home: RuleTestWorkbenchPage(
        initialRuleSet: pack ?? _pack(),
        initialTestCase: testCase,
        localeTag: locale,
        runCase: runCase,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor?.a, 1);
}

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(Duration.zero);
  });
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

String _caseText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('rule-test-case-json')))
    .controller!
    .text;

Future<void> _editCase(WidgetTester tester, Map<String, dynamic> value) async {
  final field = find.byKey(const ValueKey('rule-test-case-json'));
  await tester.ensureVisible(field);
  await tester.enterText(field, jsonEncode(value));
  await tester.pump();
}

Future<void> _editPack(WidgetTester tester, String text) async {
  await _tap(tester, 'rule-test-pack-editor-toggle');
  final field = find.byKey(const ValueKey('rule-test-pack-json'));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _editSuite(WidgetTester tester, String text) async {
  final field = find.byKey(const ValueKey('rule-test-suite-json'));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

void main() {
  testWidgets('large valid pack remains importable after editor formatting', (
    tester,
  ) async {
    RuleTestRuleSet? largePack;
    final template = _pack().rawRules.single;
    for (var count = 1; count <= 128; count++) {
      final rules = [
        for (var i = 0; i < count; i++)
          <String, dynamic>{...template, 'rule_id': 'synthetic-large-$i'},
      ];
      try {
        final candidate = RuleTestRuleSet(
          source: 'synthetic_large_fixture',
          bundleVersion: 'fixture-v1',
          rawRules: rules,
        );
        final compact = candidate.encode();
        final pretty = const JsonEncoder.withIndent(
          '  ',
        ).convert(candidate.toJson());
        if (utf8.encode(compact).length <= ruleTestMaxJsonBytes &&
            utf8.encode(pretty).length > ruleTestMaxJsonBytes) {
          largePack = candidate;
          break;
        }
      } on FormatException {
        break;
      }
    }
    expect(
      largePack,
      isNotNull,
      reason: 'Fixture must exercise the byte boundary.',
    );
    await _pump(tester, pack: largePack);
    final text = tester
        .widget<TextField>(
          find.byKey(
            const ValueKey('rule-test-pack-json'),
            skipOffstage: false,
          ),
        )
        .controller!
        .text;
    expect(utf8.encode(text).length, lessThanOrEqualTo(ruleTestMaxJsonBytes));
    expect(
      RuleTestRuleSet.decode(text).contentDigest,
      largePack!.contentDigest,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real run displays assertions and editing preserves expected results',
    (tester) async {
      final pack = _pack();
      final testCase = _positiveCase(pack);
      await _pump(tester, pack: pack, testCase: testCase);
      await _tap(tester, 'rule-test-run');
      expect(find.text('Passed'), findsOneWidget);
      expect(
        find.textContaining('PASS · targets.drug-meal.decision'),
        findsOneWidget,
      );
      expect(find.text(_ruleId), findsOneWidget);
      final originalExpected = jsonDecode(_caseText(tester))['expected'];

      final edited = testCase.toJson();
      (edited['context']['meal'] as Map<String, dynamic>)['protein_g'] = 0;
      await _editCase(tester, edited);
      expect(find.byKey(const ValueKey('rule-test-status')), findsNothing);
      await _tap(tester, 'rule-test-run');
      expect(find.text('Failed'), findsOneWidget);
      expect(jsonDecode(_caseText(tester))['expected'], originalExpected);
      expect(find.textContaining('FAIL · targets'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom synthetic rule run previews its exact information-only card envelope',
    (tester) async {
      final pack = _pack();
      await _pump(tester, pack: pack, testCase: _positiveCase(pack));
      await _tap(tester, 'rule-test-run');

      final explanation = find.byKey(
        const ValueKey('rule-test-explanation-$_ruleId'),
      );
      await tester.ensureVisible(explanation);
      await tester.tap(explanation);
      await tester.pumpAndSettle();

      final preview = find.byKey(
        const ValueKey('rule-test-card-preview-$_ruleId'),
      );
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();

      final json = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('rule-test-card-json-$_ruleId')),
          )
          .data!;
      final envelope = jsonDecode(json) as Map<String, dynamic>;
      final cards = (envelope['cards'] as List).cast<Map<String, dynamic>>();
      expect(cards, hasLength(1));
      expect(cards.single['indicator'], 'info');
      expect(
        ((cards.single['extension'] as Map<String, dynamic>).values.single
            as Map<String, dynamic>)['rulePackVersion'],
        pack.bundleVersion,
      );
      expect(json, contains('missingOrUncertainInputs'));
      expect(
        find.text(
          'Synthetic preview only. This response is not sent to an EHR and does not activate rules.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unset expectations are unverified and explicit empty is an assertion',
    (tester) async {
      final pack = RuleTestRuleSet(
        source: 'synthetic_empty',
        bundleVersion: 'empty-v1',
        rawRules: [],
      );
      await _pump(tester, pack: pack);
      await _tap(tester, 'rule-test-run');
      expect(find.text('Not verified'), findsOneWidget);
      expect(find.textContaining('No expectations were set.'), findsOneWidget);
      final value = jsonDecode(_caseText(tester)) as Map<String, dynamic>;
      expect(value['expected']['targets'], isNull);
      value['expected']['targets'] = <Object>[];
      await _editCase(tester, value);
      await _tap(tester, 'rule-test-import-case');
      await _tap(tester, 'rule-test-run');
      // The engine emits its runtime-context fallback even for an empty pack.
      // Explicit [] must fail, rather than silently becoming unset.
      expect(find.text('Failed'), findsOneWidget);
      expect(find.textContaining('0 of 1 assertions passed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real patient IDs and broken content bindings are rejected visibly',
    (tester) async {
      final pack = _pack();
      await _pump(tester, pack: pack, testCase: _positiveCase(pack));
      await _tap(tester, 'rule-test-run');
      final invalid = _positiveCase(pack).toJson();
      invalid['context']['user_profile']['patient_id'] = 'actual-patient-42';
      await _editCase(tester, invalid);
      await _tap(tester, 'rule-test-import-case');
      expect(find.byKey(const ValueKey('rule-test-error')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const ValueKey('rule-test-status')), findsNothing);

      final tamperedPack = pack.toJson();
      tamperedPack['rules'][0]['priority_band'] = 71;
      await _editPack(tester, jsonEncode(tamperedPack));
      await _tap(tester, 'rule-test-import-pack');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('rule-test-error'))).data,
        contains('does not match its binding'),
      );
      expect(find.byKey(const ValueKey('rule-test-diff')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pack import shows field diff and requires explicit case rebinding',
    (tester) async {
      final before = _pack();
      final after = _pack(priority: 71);
      await _pump(tester, pack: before, testCase: _positiveCase(before));
      final expected = jsonDecode(_caseText(tester))['expected'];
      await _editPack(tester, after.encode());
      await _tap(tester, 'rule-test-import-pack');
      expect(find.textContaining('1 changed'), findsOneWidget);
      expect(
        find.textContaining('same_version_different_content'),
        findsOneWidget,
      );
      final change = find.text('$_ruleId · changed');
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(find.textContaining('/priority_band'), findsOneWidget);
      await _tap(tester, 'rule-test-run');
      expect(find.text('Binding mismatch'), findsOneWidget);
      expect(
        jsonDecode(_caseText(tester))['binding']['content_digest'],
        before.contentDigest,
      );
      await _tap(tester, 'rule-test-bind-case');
      expect(find.byKey(const ValueKey('rule-test-status')), findsNothing);
      expect(
        jsonDecode(_caseText(tester))['binding']['content_digest'],
        after.contentDigest,
      );
      expect(jsonDecode(_caseText(tester))['expected'], expected);
      await _tap(tester, 'rule-test-run');
      expect(find.text('Passed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clipboard exports require clicks and contain case, pack or full report',
    (tester) async {
      final clipboard = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final pack = _pack();
      await _pump(tester, pack: pack, testCase: _positiveCase(pack));
      await _tap(tester, 'rule-test-run');
      expect(clipboard, isEmpty);
      await _tap(tester, 'rule-test-copy-case');
      expect(
        RuleTestCase.decode(clipboard.last).expected.targets,
        hasLength(1),
      );
      await _tap(tester, 'rule-test-copy-pack');
      expect(
        RuleTestRuleSet.decode(clipboard.last).contentDigest,
        pack.contentDigest,
      );
      await _tap(tester, 'rule-test-copy-report');
      final report = jsonDecode(clipboard.last) as Map<String, dynamic>;
      expect(clipboard, hasLength(3));
      expect(report['status'], 'passed');
      expect(report['rules_digest'], pack.contentDigest);
      expect(report['assertions'], isNotEmpty);
      expect(report['boundaries']['historical_executable_replay'], isFalse);
    },
  );

  testWidgets('edits and mode changes invalidate pending success and failure', (
    tester,
  ) async {
    final pack = _pack();
    final testCase = _positiveCase(pack);
    final realReport = await tester.runAsync(
      () => const SyntheticRuleTestRunner().run(
        testCase: testCase,
        ruleSet: pack,
      ),
    );
    final pending = <Completer<RuleTestRunReport>>[];
    await _pump(
      tester,
      pack: pack,
      testCase: testCase,
      runCase: ({required testCase, required ruleSet, required mode}) {
        final completer = Completer<RuleTestRunReport>();
        pending.add(completer);
        return completer.future;
      },
    );
    await _tap(tester, 'rule-test-run', settle: false);
    final edited = testCase.toJson()..['title'] = 'Edited synthetic case';
    await _editCase(tester, edited);
    pending.first.complete(realReport!);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rule-test-status')), findsNothing);

    await _tap(tester, 'rule-test-run', settle: false);
    final mode = find.byKey(const ValueKey('rule-test-mode'));
    await tester.ensureVisible(mode);
    await tester.tap(mode);
    await tester.pump();
    await tester.tap(find.text('Active and draft rules').last);
    await tester.pump();
    pending.last.completeError(StateError('stale failure'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rule-test-error')), findsNothing);
    expect(find.byKey(const ValueKey('rule-test-status')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese narrow page runs draft scope without overflow', (
    tester,
  ) async {
    final pack = _pack(status: 'draft');
    final testCase = RuleTestCase.seed(ruleSet: pack).copyWith(
      expected: RuleTestExpectations(
        targets: [
          RuleTestTargetExpectation(
            target: 'runtime-context',
            decision: RuntimeDecisionType.allow,
            winningRuleIds: [],
          ),
        ],
      ),
    );
    await _pump(
      tester,
      pack: pack,
      testCase: testCase,
      locale: 'zh-CN',
      width: 320,
    );
    expect(find.text('规则测试工作台'), findsOneWidget);
    await _tap(tester, 'rule-test-run');
    expect(find.text('通过'), findsOneWidget);
    final mode = find.byKey(const ValueKey('rule-test-mode'));
    await tester.ensureVisible(mode);
    await tester.tap(mode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('活动与草稿规则').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rule-test-status')), findsNothing);
    await _tap(tester, 'rule-test-run');
    expect(find.text('未通过'), findsOneWidget);
    expect(find.text(_ruleId), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'suite reports pass, unverified and binding mismatch separately',
    (tester) async {
      final pack = _pack();
      final otherPack = _pack(priority: 71);
      final suite = RuleTestSuite(
        suiteId: 'synthetic-mixed-suite',
        title: 'Synthetic mixed outcomes',
        cases: [
          _positiveCase(
            pack,
          ).copyWith(caseId: 'synthetic-suite-pass', title: 'Expected warning'),
          RuleTestCase.seed(ruleSet: pack).copyWith(
            caseId: 'synthetic-suite-unverified',
            title: 'No expected result',
          ),
          _positiveCase(otherPack).copyWith(
            caseId: 'synthetic-suite-mismatch',
            title: 'Pinned to another pack',
          ),
        ],
      );

      await _pump(tester, pack: pack);
      await _editSuite(
        tester,
        const JsonEncoder.withIndent('  ').convert(suite.toJson()),
      );
      await _tap(tester, 'rule-test-import-suite');
      expect(find.textContaining('Suite imported.'), findsOneWidget);

      await _tap(tester, 'rule-test-run-suite');

      expect(
        find.text(
          '1 passed · 0 failed · 1 not verified · 1 binding mismatches',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('The suite is not fully verified.'),
        findsOneWidget,
      );
      expect(find.textContaining('Expected warning · Passed'), findsOneWidget);
      expect(
        find.textContaining('No expected result · Not verified'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Pinned to another pack · Binding mismatch'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rule-test-suite-report')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completed suite exposes a portable replay checkpoint', (
    tester,
  ) async {
    final pack = _pack();
    final suite = RuleTestSuite(
      suiteId: 'synthetic-checkpoint-suite',
      title: 'Synthetic checkpoint workflow',
      cases: [
        _positiveCase(pack).copyWith(
          caseId: 'synthetic-checkpoint-case-1',
          title: 'First synthetic case',
        ),
        _positiveCase(pack).copyWith(
          caseId: 'synthetic-checkpoint-case-2',
          title: 'Second synthetic case',
        ),
      ],
    );
    await _pump(tester, pack: pack);
    await _editSuite(tester, suite.encode());
    await _tap(tester, 'rule-test-import-suite');
    await _tap(tester, 'rule-test-run-suite');
    expect(
      find.byKey(const ValueKey('rule-test-suite-report')),
      findsOneWidget,
    );
    final checkpoint = RuleTestSuiteCheckpoint.decode(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('rule-test-suite-checkpoint-json')),
          )
          .controller!
          .text,
    );
    expect(checkpoint.suiteId, suite.suiteId);
    expect(checkpoint.completedCases.map((item) => item.caseId), [
      'synthetic-checkpoint-case-1',
      'synthetic-checkpoint-case-2',
    ]);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('rule-test-copy-suite-checkpoint')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
