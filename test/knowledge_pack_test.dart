import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/entities/knowledge_pack.dart';
import 'package:parkinsum_companion/domain/entities/rule_test_case.dart';
import 'package:parkinsum_companion/domain/usecases/knowledge_governance_service.dart';

// Shared synthetic fixture. This is authored test evidence, never a clinical
// validation or a trusted production knowledge package.
KnowledgePack createKnowledgeTestPack({
  String version = '1',
  int ruleCount = 1,
  List<KnowledgeTestCase> Function(List<KnowledgeTestCase>)? changeCases,
  String? engineDigest,
}) {
  final base =
      jsonDecode(jsonEncode(RuleTestRuleSet.baseline().rawRules.first))
          as Map<String, dynamic>;
  final raw = <Map<String, dynamic>>[
    base,
    if (ruleCount == 2)
      {...base, 'rule_id': 'synthetic.secondary', 'priority_band': 69},
  ];
  final rules = RuleTestRuleSet(
    source: 'synthetic-governance-fixture',
    bundleVersion: version,
    rawRules: raw,
  );
  final seed = RuleTestCase.seed(ruleSet: rules);
  final cases = <KnowledgeTestCase>[];
  for (final ruleId in rules.ruleVersions.keys) {
    for (final category in [
      KnowledgeCaseCategory.positive,
      KnowledgeCaseCategory.negative,
      KnowledgeCaseCategory.missingInput,
      KnowledgeCaseCategory.boundary,
    ]) {
      final json = seed.toJson();
      final negative = category == KnowledgeCaseCategory.negative;
      final missing = category == KnowledgeCaseCategory.missingInput;
      json['case_id'] = '$ruleId-${category.name}';
      json['title'] = 'Authored synthetic ${category.name} example';
      json['context']['meal']['protein_g'] = negative
          ? 5
          : category == KnowledgeCaseCategory.boundary
          ? 10
          : 25;
      if (missing) json['context']['timestamps']['drug_time'] = null;
      json['expected'] = RuleTestExpectations(
        targets: [
          RuleTestTargetExpectation(
            target: negative || missing ? 'runtime-context' : 'drug-meal',
            decision: negative
                ? RuntimeDecisionType.allow
                : missing
                ? RuntimeDecisionType.requireReview
                : RuntimeDecisionType.warn,
            winningRuleIds: negative || missing
                ? []
                : [base['rule_id'] as String],
          ),
        ],
        missingFieldsByRule: {
          ruleId: missing ? ['time'] : [],
        },
      ).toJson();
      cases.add(
        KnowledgeTestCase(
          category: category,
          targetRuleId: ruleId,
          expectedMatch: negative
              ? KnowledgeRuleMatch.notMatched
              : missing
              ? KnowledgeRuleMatch.unknown
              : KnowledgeRuleMatch.matched,
          rationale:
              'Synthetic ${category.name}; boundary uses the authored 10 g threshold.',
          testCase: RuleTestCase.fromJson(json),
        ),
      );
    }
  }
  return KnowledgePack(
    packId: 'synthetic-pack',
    version: version,
    authorId: 'subject-author',
    engineDigest: engineDigest ?? knowledgeCurrentEngineDigest(rules),
    ruleSet: rules,
    sources: [
      KnowledgeSource(
        sourceId: 'fda-dhivy-high-protein',
        title: 'Synthetic test provenance',
        uri: 'https://example.test/source',
        revision: 'fixture-1',
        excerpt: 'Authored test-only excerpt; no clinical approval.',
      ),
    ],
    cases: changeCases == null ? cases : changeCases(cases),
  );
}

void main() {
  test(
    'complete pack round trips exact immutable content and authored suite',
    () {
      final pack = createKnowledgeTestPack();
      pack.requireCompleteSuite();
      final restored = KnowledgePack.decode(pack.encode());
      expect(restored.digest, pack.digest);
      expect(restored.suiteDigest, pack.suiteDigest);
      expect(restored.ruleSet.contentDigest, pack.ruleSet.contentDigest);
      expect(() => pack.cases.clear(), throwsUnsupportedError);
      expect(() => pack.sources.clear(), throwsUnsupportedError);
      final export = pack.toJson();
      export['sources'][0]['excerpt'] = 'changed';
      expect(pack.sources.single.excerpt, contains('test-only'));
      expect(() => KnowledgePack.fromJson(export), throwsFormatException);
    },
  );

  test(
    'missing category and repeated input do not qualify as a complete suite',
    () {
      final missing = createKnowledgeTestPack(
        changeCases: (c) => c.take(3).toList(),
      );
      expect(missing.requireCompleteSuite, throwsFormatException);
      final repeated = createKnowledgeTestPack(
        changeCases: (c) => [
          ...c.take(3),
          KnowledgeTestCase(
            category: c.last.category,
            targetRuleId: c.last.targetRuleId,
            expectedMatch: c.last.expectedMatch,
            rationale: c.last.rationale,
            testCase: c.first.testCase.copyWith(caseId: 'repeated-input'),
          ),
        ],
      );
      expect(repeated.requireCompleteSuite, throwsFormatException);
    },
  );

  test(
    'unknown keys, duplicate IDs, broken source pins and digest tamper reject',
    () {
      final pack = createKnowledgeTestPack();
      final unknown = pack.toJson()..['unexpected'] = true;
      expect(() => KnowledgePack.fromJson(unknown), throwsFormatException);
      final duplicate = pack.toJson();
      duplicate['cases'].add(duplicate['cases'][0]);
      expect(() => KnowledgePack.fromJson(duplicate), throwsFormatException);
      final source = pack.toJson();
      source['sources'][0]['source_id'] = 'unrelated';
      expect(() => KnowledgePack.fromJson(source), throwsFormatException);
      final digest = pack.toJson()..['digest'] = '0' * 64;
      expect(() => KnowledgePack.fromJson(digest), throwsFormatException);
      final realPatient = pack.toJson();
      realPatient['cases'][0]['case']['context']['user_profile']['patient_id'] =
          'patient-123';
      expect(() => KnowledgePack.fromJson(realPatient), throwsFormatException);
    },
  );

  test(
    'category expectations are explicit and unset assertions cannot pass',
    () {
      final pack = createKnowledgeTestPack();
      final positive = pack.cases.first;
      expect(
        () => KnowledgeTestCase(
          category: KnowledgeCaseCategory.positive,
          targetRuleId: positive.targetRuleId,
          expectedMatch: KnowledgeRuleMatch.notMatched,
          rationale: 'wrong category',
          testCase: positive.testCase,
        ),
        throwsFormatException,
      );
      final unset = createKnowledgeTestPack(
        changeCases: (cases) => [
          for (final c in cases)
            KnowledgeTestCase(
              category: c.category,
              targetRuleId: c.targetRuleId,
              expectedMatch: c.expectedMatch,
              rationale: c.rationale,
              testCase: c.testCase.copyWith(expected: RuleTestExpectations()),
            ),
        ],
      );
      expect(unset.requireCompleteSuite, throwsFormatException);
    },
  );

  test('JSON bounds, Unicode, strict timestamp and source URI fail closed', () {
    expect(
      () => KnowledgePack.decode(' ' * (knowledgePackMaxBytes + 1)),
      throwsFormatException,
    );
    expect(
      () => KnowledgePack.decode('${'[' * 41}0${']' * 41}'),
      throwsFormatException,
    );
    expect(
      () => knowledgeText(String.fromCharCode(0xd800), 'text'),
      throwsFormatException,
    );
    expect(
      () => knowledgeUtc('9999-12-31T23:59:59-14:00'),
      throwsFormatException,
    );
    expect(
      () => knowledgeCheckJson({'number': double.nan}, maxBytes: 1024),
      throwsFormatException,
    );
    expect(
      () => KnowledgeSource(
        sourceId: 'a',
        title: 'b',
        uri: 'http://example.test',
        revision: '1',
        excerpt: 'e',
      ),
      throwsFormatException,
    );
  });

  test(
    'governance suite requires final output and target-specific missing assertions',
    () {
      final noFinalOutput = createKnowledgeTestPack(
        changeCases: (cases) => [
          for (final c in cases)
            KnowledgeTestCase(
              category: c.category,
              targetRuleId: c.targetRuleId,
              expectedMatch: c.expectedMatch,
              rationale: c.rationale,
              testCase: c.testCase.copyWith(
                expected: RuleTestExpectations(
                  missingFieldsByRule: c.testCase.expected.missingFieldsByRule,
                ),
              ),
            ),
        ],
      );
      expect(noFinalOutput.requireCompleteSuite, throwsFormatException);
      final noMissingInput = createKnowledgeTestPack(
        changeCases: (cases) => [
          for (final c in cases)
            KnowledgeTestCase(
              category: c.category,
              targetRuleId: c.targetRuleId,
              expectedMatch: c.expectedMatch,
              rationale: c.rationale,
              testCase: c.testCase.copyWith(
                expected: RuleTestExpectations(
                  targets: c.testCase.expected.targets,
                ),
              ),
            ),
        ],
      );
      expect(noMissingInput.requireCompleteSuite, throwsFormatException);
    },
  );
}
