import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/entities/rule_test_case.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_rule_test_runner.dart';

void main() {
  const runner = SyntheticRuleTestRunner();
  late RuleTestRuleSet rules;
  late RuleTestCase seed;
  setUp(() {
    rules = RuleTestRuleSet.baseline();
    seed = RuleTestCase.seed(ruleSet: rules);
  });

  test(
    'real baseline evaluation passes explicitly authored assertions',
    () async {
      final testCase = seed.copyWith(expected: _proteinExpected());
      final report = await runner.run(testCase: testCase, ruleSet: rules);
      expect(report.status, RuleTestRunStatus.passed);
      expect(report.assertions, hasLength(4));
      expect(report.assertions.every((a) => a.passed), isTrue);
      expect(report.output!.auditEntries.single.winningRuleIds, [
        'pd.ldopa.protein.window.v1',
      ]);
      expect(
        report.output!.alertsJson['compiled_rule_source'],
        'caller_supplied_rules',
      );
      expect(
        report.output!.auditEntries.single.inputHash,
        report.nativeEngineInputDigest,
      );
      expect(report.rulesDigest, rules.contentDigest);
      expect(report.inMemoryAuditRecordCount, greaterThan(0));
      expect(report.ruleExecution.every((r) => r['executed'] == true), isTrue);
    },
  );

  test(
    'no expectations is not verified while explicit empty targets fails',
    () async {
      final unverified = await runner.run(testCase: seed, ruleSet: rules);
      expect(unverified.status, RuleTestRunStatus.notVerified);
      expect(unverified.assertions, isEmpty);
      expect(unverified.output, isNotNull);
      final empty = await runner.run(
        testCase: seed.copyWith(expected: RuleTestExpectations(targets: [])),
        ruleSet: rules,
      );
      expect(empty.status, RuleTestRunStatus.failed);
      expect(empty.assertions.single.path, 'targets');
      expect(empty.assertions.single.expected, isEmpty);
      expect(empty.assertions.single.actual, ['drug-meal']);
    },
  );

  test('wrong winner and final decision fail independently', () async {
    final testCase = seed.copyWith(
      expected: RuleTestExpectations(
        targets: [
          RuleTestTargetExpectation(
            target: 'drug-meal',
            decision: RuntimeDecisionType.allow,
            winningRuleIds: ['pd.ldopa.iron.v1'],
          ),
        ],
      ),
    );
    final report = await runner.run(testCase: testCase, ruleSet: rules);
    expect(report.status, RuleTestRunStatus.failed);
    expect(report.assertions.where((a) => !a.passed).map((a) => a.path), [
      'targets.drug-meal.decision',
      'targets.drug-meal.winning_rule_ids',
    ]);
  });

  test('missing inputs compare each rule rather than a global union', () async {
    final expected = RuleTestExpectations(
      missingFieldsByRule: {
        'pd.ldopa.protein.window.v1': [],
        'pd.rasagiline.tyramine.us.v1': ['dose'],
      },
    );
    final report = await runner.run(
      testCase: seed.copyWith(expected: expected),
      ruleSet: rules,
    );
    expect(report.status, RuleTestRunStatus.passed);
    expect(
      report.output!.auditEntries.single.decision,
      RuntimeDecisionType.warn,
    );
    final wrong = await runner.run(
      testCase: seed.copyWith(
        expected: RuleTestExpectations(
          missingFieldsByRule: {'pd.rasagiline.tyramine.us.v1': []},
        ),
      ),
      ruleSet: rules,
    );
    expect(wrong.status, RuleTestRunStatus.failed);
    expect(wrong.assertions.single.actual, ['dose']);
  });

  test('mismatched content binding never reaches the engine', () async {
    final raw = _raw(rules);
    raw.first['then']['severity'] = 'changed';
    final changed = RuleTestRuleSet(
      source: rules.source,
      bundleVersion: rules.bundleVersion,
      rawRules: raw,
    );
    final report = await runner.run(testCase: seed, ruleSet: changed);
    expect(report.status, RuleTestRunStatus.bindingMismatch);
    expect(report.output, isNull);
    expect(report.inMemoryAuditRecordCount, 0);
    expect(report.ruleExecution.every((r) => r['executed'] == false), isTrue);
    expect(report.assertions.single.passed, isFalse);
  });

  test(
    'explicit draft execution never silently activates draft or retired rules',
    () async {
      final draft = _raw(rules).first;
      draft['status'] = 'draft';
      draft['version'] = 'historical-0.3';
      final pack = RuleTestRuleSet(
        source: 'imported_draft',
        bundleVersion: 'historical',
        rawRules: [draft],
      );
      final testCase = seed.copyWith(
        binding: pack.binding,
        expected: _proteinExpected(),
      );
      final skipped = await runner.run(testCase: testCase, ruleSet: pack);
      expect(skipped.status, RuleTestRunStatus.failed);
      expect(skipped.ruleExecution.single['declared_status'], 'draft');
      expect(skipped.ruleExecution.single['executed'], isFalse);
      expect(
        skipped.assertions.last.actual,
        isNull,
        reason: 'An excluded rule has no evaluated missing-fields set.',
      );
      final included = await runner.run(
        testCase: testCase,
        ruleSet: pack,
        mode: RuleTestExecutionMode.includeDraft,
      );
      expect(included.status, RuleTestRunStatus.passed);
      expect(included.ruleExecution.single['executed'], isTrue);
      expect(included.executedRulesDigest, isNot(skipped.executedRulesDigest));
      expect(
        included.output!.alertsJson['rule_hit_trace'].single['rule_version'],
        'historical-0.3',
      );
      expect(pack.rawRules.single['status'], 'draft');
      for (final status in ['deprecated', 'disabled']) {
        final historicalRule = _raw(pack).single..['status'] = status;
        final historical = RuleTestRuleSet(
          source: 'archive',
          bundleVersion: status,
          rawRules: [historicalRule],
        );
        final c = testCase.copyWith(binding: historical.binding);
        expect(
          (await runner.run(
            testCase: c,
            ruleSet: historical,
            mode: RuleTestExecutionMode.includeDraft,
          )).status,
          RuleTestRunStatus.failed,
        );
        expect(
          (await runner.run(
            testCase: c,
            ruleSet: historical,
            mode: RuleTestExecutionMode.allStatuses,
          )).status,
          RuleTestRunStatus.passed,
        );
      }
    },
  );

  test(
    'assertions use final escalated audit decision and only the winner',
    () async {
      final first = _raw(rules).first;
      final second = _raw(rules).first;
      second['rule_id'] = 'synthetic.same-band-other';
      second['then']['decision'] = 'INFO';
      final pack = RuleTestRuleSet(
        source: 'conflict_fixture',
        bundleVersion: '1',
        rawRules: [first, second],
      );
      final c = seed.copyWith(
        binding: pack.binding,
        expected: RuleTestExpectations(
          targets: [
            RuleTestTargetExpectation(
              target: 'drug-meal',
              decision: RuntimeDecisionType.requireReview,
              winningRuleIds: [first['rule_id'] as String],
            ),
          ],
        ),
      );
      final report = await runner.run(testCase: c, ruleSet: pack);
      expect(report.status, RuleTestRunStatus.passed);
      expect(report.output!.alerts.single.ruleIds, hasLength(2));
      expect(report.output!.auditEntries.single.suppressedRuleIds, [
        'synthetic.same-band-other',
      ]);
      expect(
        report.output!.alertsJson['rule_hit_trace'].first['decision'],
        'WARN',
      );
    },
  );

  test(
    'each run is isolated and its complete report is deeply immutable',
    () async {
      final c = seed.copyWith(expected: _proteinExpected());
      final first = await runner.run(testCase: c, ruleSet: rules);
      final second = await runner.run(testCase: c, ruleSet: rules);
      expect(second.inMemoryAuditRecordCount, first.inMemoryAuditRecordCount);
      expect(
        second.assertions.map((a) => a.toJson()).toList(),
        first.assertions.map((a) => a.toJson()).toList(),
      );
      expect(second.caseDigest, first.caseDigest);
      expect(
        () => first.assertions.first.actual is List
            ? (first.assertions.first.actual as List).add('x')
            : throw StateError('fixture'),
        throwsUnsupportedError,
      );
      expect(
        () => first.output!.alertsJson['rule_hit_trace'].clear(),
        throwsUnsupportedError,
      );
      expect(
        () => first.output!.alerts.single.actions.first['type'] = 'mutated',
        throwsUnsupportedError,
      );
      expect(
        () => first.output!.auditEntries.single.winningRuleIds.add('mutated'),
        throwsUnsupportedError,
      );
      expect(
        () => first.ruleExecution.first['executed'] = false,
        throwsUnsupportedError,
      );
      final exported = first.toJson();
      exported['output']['alerts_json']['rule_hit_trace'].clear();
      expect(first.output!.alertsJson['rule_hit_trace'], isNotEmpty);
      expect(jsonDecode(first.encode())['status'], 'passed');
    },
  );

  test(
    'report states current-engine and source-reference-only replay boundaries',
    () async {
      final report = await runner.run(testCase: seed, ruleSet: rules);
      final json = report.toJson();
      expect(
        json['engine_identity']['version'],
        AlgorithmConfigurationIdentity.defaultVersion,
      );
      expect(
        json['engine_identity']['configuration_sha256'],
        matches(RegExp(r'^[a-f0-9]{64}$')),
      );
      expect(json['boundaries']['current_engine_execution'], isTrue);
      for (final key in [
        'historical_executable_replay',
        'historical_knowledge_base_restored',
        'source_documents_included',
        'baseline_source_metadata',
        'clinical_validation',
        'patient_rule_activation_changed',
      ]) {
        expect(json['boundaries'][key], isFalse, reason: key);
      }
      final reference = report.output!.alerts.single.evidenceRecords.single;
      expect(reference.title, reference.sourceRef);
      expect(reference.sourceUrl, isNull);
      expect(json['boundaries']['artifact_storage'], 'isolated_process_memory');
    },
  );

  test(
    'administration dose units are checked before the engine can reinterpret them',
    () async {
      final rule = _raw(rules).first;
      rule['when'] = {
        'dose_band': {
          'path': 'drug.administration_dose_value',
          'unit': 'mg',
          'op': 'gte',
          'threshold': 50,
        },
      };
      final pack = RuleTestRuleSet(
        source: 'dose_unit_fixture',
        bundleVersion: '1',
        rawRules: [rule],
      );
      final json = seed.copyWith(binding: pack.binding).toJson();
      json['context']['drug']['administration_dose_value'] = 0.1;
      json['context']['drug']['administration_dose_unit'] = 'g';
      await expectLater(
        runner.run(testCase: RuleTestCase.fromJson(json), ruleSet: pack),
        throwsFormatException,
      );
      json['context']['drug']['administration_dose_value'] = 100;
      json['context']['drug']['administration_dose_unit'] = 'mg';
      final supported = RuleTestCase.fromJson(
        json,
      ).copyWith(expected: _proteinExpected());
      expect(
        (await runner.run(testCase: supported, ruleSet: pack)).status,
        RuleTestRunStatus.passed,
      );
      json['context']['drug']['administration_dose_unit'] = null;
      final incomplete = RuleTestCase.fromJson(json).copyWith(
        expected: RuleTestExpectations(
          targets: [
            RuleTestTargetExpectation(
              target: 'drug-meal',
              decision: RuntimeDecisionType.requireReview,
              winningRuleIds: ['pd.ldopa.protein.window.v1'],
            ),
          ],
          missingFieldsByRule: {
            'pd.ldopa.protein.window.v1': ['administration_dose'],
          },
        ),
      );
      expect(
        (await runner.run(testCase: incomplete, ruleSet: pack)).status,
        RuleTestRunStatus.passed,
      );
    },
  );
}

RuleTestExpectations _proteinExpected() => RuleTestExpectations(
  targets: [
    RuleTestTargetExpectation(
      target: 'drug-meal',
      decision: RuntimeDecisionType.warn,
      winningRuleIds: ['pd.ldopa.protein.window.v1'],
    ),
  ],
  missingFieldsByRule: {'pd.ldopa.protein.window.v1': []},
);

List<Map<String, dynamic>> _raw(RuleTestRuleSet rules) =>
    (rules.toJson()['rules'] as List).cast<Map<String, dynamic>>();
