import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/entities/rule_test_case.dart';
import 'package:parkinsum_companion/domain/entities/rule_test_suite.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_rule_test_runner.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_rule_test_suite_runner.dart';

RuleTestRuleSet _pack({int priority = 70}) {
  final rule =
      jsonDecode(jsonEncode(baselineCdssRules.first)) as Map<String, dynamic>;
  rule['priority_band'] = priority;
  return RuleTestRuleSet(
    source: 'synthetic_suite_test',
    bundleVersion: 'suite-fixture-v1',
    rawRules: [rule],
  );
}

RuleTestCase _positiveCase(
  RuleTestRuleSet pack, {
  String caseId = 'synthetic-positive-001',
}) {
  final ruleId = pack.rawRules.single['rule_id'] as String;
  return RuleTestCase.seed(ruleSet: pack).copyWith(
    caseId: caseId,
    title: caseId,
    expected: RuleTestExpectations(
      targets: [
        RuleTestTargetExpectation(
          target: 'drug-meal',
          decision: RuntimeDecisionType.warn,
          winningRuleIds: [ruleId],
        ),
      ],
      missingFieldsByRule: {ruleId: const <String>[]},
    ),
  );
}

void main() {
  test('suite round-trips with a stable digest and immutable cases', () {
    final pack = _pack();
    final suite = RuleTestSuite(
      suiteId: 'protein-window-suite',
      title: 'Synthetic protein-window cases',
      cases: [
        _positiveCase(pack),
        _positiveCase(pack, caseId: 'synthetic-positive-002'),
      ],
    );

    final decoded = RuleTestSuite.decode(suite.encode());
    expect(decoded.suiteId, suite.suiteId);
    expect(decoded.title, suite.title);
    expect(decoded.cases.map((testCase) => testCase.caseId), [
      'synthetic-positive-001',
      'synthetic-positive-002',
    ]);
    expect(decoded.contentDigest, suite.contentDigest);
    expect(
      () => decoded.cases.add(_positiveCase(pack)),
      throwsUnsupportedError,
    );
  });

  test('suite rejects duplicate IDs, unknown fields, and oversized suites', () {
    final pack = _pack();
    final duplicate = RuleTestSuite(
      suiteId: 'duplicate-suite',
      title: 'Duplicate IDs',
      cases: [
        _positiveCase(pack),
        _positiveCase(pack, caseId: 'synthetic-positive-002'),
      ],
    ).toJson();
    duplicate['cases'] = [
      _positiveCase(pack).toJson(),
      _positiveCase(pack).toJson(),
    ];
    expect(
      () => RuleTestSuite.fromJson(duplicate),
      throwsA(isA<FormatException>()),
    );

    final unknown = RuleTestSuite(
      suiteId: 'unknown-suite',
      title: 'Unknown key',
      cases: [_positiveCase(pack)],
    ).toJson()..['patient_id'] = 'synthetic_test_case';
    expect(
      () => RuleTestSuite.fromJson(unknown),
      throwsA(isA<FormatException>()),
    );

    final tooManyCases = <String, dynamic>{
      'schema_version': ruleTestSuiteSchemaVersion,
      'synthetic_only': true,
      'suite_id': 'large-suite',
      'title': 'Too many cases',
      'cases': [
        for (var i = 0; i < ruleTestSuiteMaxCases + 1; i++)
          _positiveCase(pack, caseId: 'synthetic-case-$i').toJson(),
      ],
    };
    expect(
      () => RuleTestSuite.fromJson(tooManyCases),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'suite runner reports each case in order and keeps unknown states visible',
    () async {
      final pack = _pack();
      final positive = _positiveCase(pack);
      final unverified = RuleTestCase.seed(ruleSet: pack).copyWith(
        caseId: 'synthetic-unverified-001',
        title: 'No expected results',
      );
      final suite = RuleTestSuite(
        suiteId: 'mixed-suite',
        title: 'Synthetic pass and unverified cases',
        cases: [positive, unverified],
      );
      final progress = <int>[];

      final report = await SyntheticRuleTestSuiteRunner().run(
        suite: suite,
        ruleSet: pack,
        onProgress: ({required completed, required total, required latest}) {
          expect(total, 2);
          expect(latest.testCase.caseId, suite.cases[completed - 1].caseId);
          progress.add(completed);
        },
      );

      expect(progress, [1, 2]);
      expect(report.caseReports.map((item) => item.status), [
        RuleTestRunStatus.passed,
        RuleTestRunStatus.notVerified,
      ]);
      expect(report.passedCount, 1);
      expect(report.notVerifiedCount, 1);
      expect(report.failedCount, 0);
      expect(report.allCasesPassed, isFalse);
      expect(
        report.toJson()['boundaries']['patient_rule_activation_changed'],
        isFalse,
      );
    },
  );

  test(
    'suite runner preserves per-case binding mismatches without rebinding',
    () async {
      final original = _pack();
      final changed = _pack(priority: 71);
      final boundCase = _positiveCase(original);
      final suite = RuleTestSuite(
        suiteId: 'pinned-suite',
        title: 'Case stays pinned',
        cases: [boundCase],
      );

      final report = await SyntheticRuleTestSuiteRunner().run(
        suite: suite,
        ruleSet: changed,
      );

      expect(
        report.caseReports.single.status,
        RuleTestRunStatus.bindingMismatch,
      );
      expect(report.bindingMismatchCount, 1);
      expect(report.caseReports.single.output, isNull);
      expect(
        report.caseReports.single.testCase.binding.contentDigest,
        original.contentDigest,
      );
      expect(report.selectedRuleBinding.contentDigest, changed.contentDigest);
    },
  );

  test(
    'suite checkpoint round-trips and resumes only after replay checks',
    () async {
      final pack = _pack();
      final suite = RuleTestSuite(
        suiteId: 'resumable-suite',
        title: 'Synthetic resumable suite',
        cases: [
          _positiveCase(pack),
          _positiveCase(pack, caseId: 'synthetic-positive-002'),
        ],
      );
      RuleTestSuiteCheckpoint? captured;
      final firstRun = await SyntheticRuleTestSuiteRunner().runResumable(
        suite: suite,
        ruleSet: pack,
        shouldPause: () => true,
        onCheckpointProgress:
            ({
              required completed,
              required total,
              required latest,
              required checkpoint,
              required replayingCheckpoint,
            }) {
              expect(total, 2);
              expect(completed, 1);
              expect(latest.testCase.caseId, suite.cases.first.caseId);
              expect(replayingCheckpoint, isFalse);
              captured = checkpoint;
            },
      );

      expect(firstRun.isComplete, isFalse);
      expect(firstRun.paused, isTrue);
      expect(firstRun.report, isNull);
      expect(captured, isNotNull);
      final restored = RuleTestSuiteCheckpoint.decode(captured!.encode());
      expect(restored.suiteDigest, suite.contentDigest);
      expect(restored.selectedRuleBinding.contentDigest, pack.contentDigest);
      expect(restored.executionMode, RuleTestExecutionMode.activeOnly.name);
      expect(restored.completedCases.map((item) => item.caseId), [
        suite.cases.first.caseId,
      ]);

      final replayPhases = <bool>[];
      final resumed = await SyntheticRuleTestSuiteRunner().runResumable(
        suite: suite,
        ruleSet: pack,
        checkpoint: restored,
        onCheckpointProgress:
            ({
              required completed,
              required total,
              required latest,
              required checkpoint,
              required replayingCheckpoint,
            }) {
              replayPhases.add(replayingCheckpoint);
            },
      );
      expect(resumed.isComplete, isTrue);
      expect(resumed.paused, isFalse);
      expect(replayPhases, [true, false]);
      expect(resumed.report!.caseReports, hasLength(2));
      expect(resumed.report!.caseReports.map((item) => item.testCase.caseId), [
        'synthetic-positive-001',
        'synthetic-positive-002',
      ]);
      expect(resumed.checkpoint.completedCases, hasLength(2));
      expect(resumed.report!.allCasesPassed, isTrue);
    },
  );

  test(
    'suite checkpoint rejects changed identity, prefix, and replay result',
    () async {
      final pack = _pack();
      final changedPack = _pack(priority: 71);
      final suite = RuleTestSuite(
        suiteId: 'checkpoint-identity-suite',
        title: 'Synthetic checkpoint identity',
        cases: [
          _positiveCase(pack),
          _positiveCase(pack, caseId: 'synthetic-positive-002'),
        ],
      );
      final paused = await SyntheticRuleTestSuiteRunner().runResumable(
        suite: suite,
        ruleSet: pack,
        shouldPause: () => true,
      );
      final checkpoint = paused.checkpoint;

      await expectLater(
        SyntheticRuleTestSuiteRunner().runResumable(
          suite: suite,
          ruleSet: changedPack,
          checkpoint: checkpoint,
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        SyntheticRuleTestSuiteRunner().runResumable(
          suite: suite,
          ruleSet: pack,
          mode: RuleTestExecutionMode.includeDraft,
          checkpoint: checkpoint,
        ),
        throwsA(isA<FormatException>()),
      );

      final changedPrefix = checkpoint.toJson();
      final completed = (changedPrefix['completed_cases'] as List)
          .cast<Map<String, dynamic>>();
      completed.first['case_id'] = suite.cases.last.caseId;
      final unordered = RuleTestSuiteCheckpoint.fromJson(changedPrefix);
      await expectLater(
        SyntheticRuleTestSuiteRunner().runResumable(
          suite: suite,
          ruleSet: pack,
          checkpoint: unordered,
        ),
        throwsA(isA<FormatException>()),
      );

      final changedDigest = checkpoint.toJson();
      final digestEntries = (changedDigest['completed_cases'] as List)
          .cast<Map<String, dynamic>>();
      digestEntries.first['report_digest'] = List.filled(64, '0').join();
      final forgedDigest = RuleTestSuiteCheckpoint.fromJson(changedDigest);
      await expectLater(
        SyntheticRuleTestSuiteRunner().runResumable(
          suite: suite,
          ruleSet: pack,
          checkpoint: forgedDigest,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('suite checkpoint parser fails closed on malformed metadata', () {
    final pack = _pack();
    final checkpoint = RuleTestSuiteCheckpoint(
      suiteId: 'checkpoint-parser-suite',
      suiteDigest: 'a' * 64,
      selectedRuleBinding: pack.binding,
      executionMode: RuleTestExecutionMode.activeOnly.name,
      completedCases: const [],
    );
    final extra = checkpoint.toJson()..['patient_id'] = 'synthetic_test_case';
    expect(
      () => RuleTestSuiteCheckpoint.fromJson(extra),
      throwsA(isA<FormatException>()),
    );
    final duplicate = checkpoint.toJson()
      ..['completed_cases'] = [
        {'case_id': 'synthetic-001', 'report_digest': 'b' * 64},
        {'case_id': 'synthetic-001', 'report_digest': 'c' * 64},
      ];
    expect(
      () => RuleTestSuiteCheckpoint.fromJson(duplicate),
      throwsA(isA<FormatException>()),
    );
  });
}
