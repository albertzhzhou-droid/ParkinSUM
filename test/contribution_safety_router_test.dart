import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/contribution_safety_router.dart';
import 'package:parkinsum_companion/domain/usecases/contribution_safety_router.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P11 — ContributionSafetyRouter. Pure, deterministic governance routing over
/// in-memory ContributionChange objects (no git). Not AI code review, not a
/// medical/legal reviewer. No PHI / patient / subject / encounter semantics.
void main() {
  const router = ContributionSafetyRouter();
  const config = ContributionSafetyRouterConfig();

  ContributionChange change(
    String path, {
    String added = '',
    bool isDocs = false,
    bool isTest = false,
    bool isGenerated = false,
    bool allowlisted = false,
    List<String> keywords = const [],
  }) =>
      ContributionChange(
        path: path,
        changeType: 'modified',
        addedLines: 1,
        addedContent: added,
        matchedKeywords: keywords,
        isDocs: isDocs,
        isTest: isTest,
        isGenerated: isGenerated,
        allowlisted: allowlisted,
      );

  ContributionSafetyReport route(List<ContributionChange> changes) =>
      router.route(changes, config);

  bool hasCategory(ContributionSafetyReport r, String c) =>
      r.categories.contains(c);
  bool checklistHasCommand(ContributionSafetyReport r, String cmd) =>
      r.checklist.any((i) => i.relatedCommands.contains(cmd));

  // 1 — docs-only change → low risk.
  test('docs-only change is low risk', () {
    final r = route([change('docs/GUIDE.md', isDocs: true, added: 'A note.')]);
    expect(r.riskLevel, ContributionRiskLevel.low);
    expect(hasCategory(r, ContributionRiskCategory.docsOnly), isTrue);
    expect(r.pass, isTrue);
  });

  // 2 — test-only change → low/medium risk.
  test('test-only change is low/medium risk', () {
    final r = route(
        [change('test/foo_test.dart', isTest: true, added: 'expect(1,1);')]);
    expect(
        [ContributionRiskLevel.low, ContributionRiskLevel.medium]
            .contains(r.riskLevel),
        isTrue);
    expect(hasCategory(r, ContributionRiskCategory.testOnly), isTrue);
  });

  // 3 — mechanistic model file → high risk.
  test('mechanistic model file is high risk', () {
    final r =
        route([change('lib/domain/usecases/mechanistic_conflict_engine.dart')]);
    expect(r.riskLevel, ContributionRiskLevel.high);
    expect(hasCategory(r, ContributionRiskCategory.mechanisticModel), isTrue);
  });

  // 4 — importer file → high risk.
  test('importer file is high risk', () {
    final r = route(
        [change('lib/data/datasources/remote/dailymed_p0_importer.dart')]);
    expect(r.riskLevel, ContributionRiskLevel.high);
    expect(hasCategory(r, ContributionRiskCategory.importer), isTrue);
  });

  // 5 — Firebase rules file → high risk.
  test('firebase rules file is high risk', () {
    final r = route([change('firestore.rules')]);
    expect(r.riskLevel, ContributionRiskLevel.high);
    expect(hasCategory(r, ContributionRiskCategory.firebaseRules), isTrue);
    expect(hasCategory(r, ContributionRiskCategory.securitySensitive), isTrue);
  });

  // 6 — localization copy → medium risk + localization lint command.
  test('localization copy is medium and requires localization lint', () {
    final r = route([change('lib/core/i18n/app_i18n_full_translations.dart')]);
    expect(r.riskLevel, ContributionRiskLevel.medium);
    expect(hasCategory(r, ContributionRiskCategory.localizationCopy), isTrue);
    expect(checklistHasCommand(r, 'npm run localization:lint'), isTrue);
  });

  // 7 — source metadata file → medium + source-quality/source-access checks.
  test('source metadata file is medium and requires source checks', () {
    final r = route([change('config/source_access_registry.json')]);
    expect(r.riskLevel, ContributionRiskLevel.medium);
    expect(hasCategory(r, ContributionRiskCategory.sourceMetadata), isTrue);
    expect(checklistHasCommand(r, 'npm run source:quality'), isTrue);
    expect(checklistHasCommand(r, 'npm run source:access'), isTrue);
  });

  // 8 — medical advice phrase → blocker.
  test('medical advice phrase produces blocker', () {
    final r = route([
      change('docs/x.md',
          isDocs: true, added: 'You should adjust your dose at noon.'),
    ]);
    expect(r.riskLevel, ContributionRiskLevel.blocker);
    expect(r.blockerCount, greaterThan(0));
    expect(r.pass, isFalse);
  });

  // 9 — secret-like phrase → blocker.
  test('secret-like phrase produces blocker', () {
    final r = route([
      change('config/x.json',
          added: '"type": "service account", "private_key": "..."'),
    ]);
    expect(hasCategory(r, ContributionRiskCategory.secretRisk), isTrue);
    expect(r.pass, isFalse);
  });

  // 10 — PHI-like fixture phrase → blocker.
  test('PHI-like fixture phrase produces blocker', () {
    final r = route([
      change('test/fixtures/x.json',
          isTest: true, added: '{"patient name": "Jane Real", "mrn": "123"}'),
    ]);
    expect(hasCategory(r, ContributionRiskCategory.phiRisk), isTrue);
    expect(r.pass, isFalse);
  });

  // 11 — allowlisted detector/scanner file downgrades keyword findings.
  test('allowlisted detector file downgrades keyword findings to info', () {
    final r = route([
      change('lib/domain/usecases/local_privacy_preflight.dart',
          allowlisted: true,
          added: 'detect "begin private key" and "patient name"'),
    ]);
    expect(r.pass, isTrue);
    expect(
        r.findings.every((f) => f.severity != ContributionRiskSeverity.blocker),
        isTrue);
    expect(r.findings.any((f) => f.severity == ContributionRiskSeverity.info),
        isTrue);
  });

  // 12 — checklist includes mechanistic commands for a mechanistic change.
  test('checklist includes mechanistic commands', () {
    final r = route(
        [change('lib/domain/usecases/mechanistic_next_meal_scorer.dart')]);
    expect(checklistHasCommand(r, 'dart run tool/run_mechanistic_replay.dart'),
        isTrue);
    expect(checklistHasCommand(r, 'npm run scenario:fuzz'), isTrue);
  });

  // 13 — checklist includes privacy/preflight for security-sensitive change.
  test('checklist includes preflight commands for security change', () {
    final r = route([change('tool/run_local_privacy_preflight.dart')]);
    expect(checklistHasCommand(r, 'npm run public:preflight'), isTrue);
    expect(checklistHasCommand(r, 'npm run privacy:preflight'), isTrue);
    expect(
        checklistHasCommand(r, 'node tool/firestore_rules_contract_check.mjs'),
        isTrue);
  });

  // 14 — suggested labels are deterministic.
  test('suggested labels are deterministic', () {
    final a =
        route([change('lib/domain/usecases/mechanistic_conflict_engine.dart')]);
    final b =
        route([change('lib/domain/usecases/mechanistic_conflict_engine.dart')]);
    expect(a.suggestedLabels, equals(b.suggestedLabels));
    expect(a.suggestedLabels.contains('mechanistic-model'), isTrue);
    expect(a.suggestedLabels.contains('safety-review'), isTrue);
  });

  // 15 — report JSON deterministic.
  test('report JSON is deterministic', () {
    final changes = [
      change('docs/a.md', isDocs: true),
      change('test/b_test.dart', isTest: true)
    ];
    final j1 = encodeContributionSafetyReport(route(changes));
    final j2 = encodeContributionSafetyReport(route(changes));
    expect(j1, equals(j2));
    final decoded = jsonDecode(j1) as Map<String, dynamic>;
    expect(decoded['report_type'], 'contribution_safety_router');
    expect(decoded['not_ai_code_review'], isTrue);
    expect(decoded['does_not_replace_human_review'], isTrue);
  });

  // 16 — markdown includes categories / labels / checklist.
  test('markdown includes categories, labels, and checklist', () {
    final md = renderContributionSafetyMarkdown(
        route([change('config/source_access_registry.json')]));
    expect(md, contains('Contribution Safety Router'));
    expect(md, contains('categories:'));
    expect(md, contains('suggested labels:'));
    expect(md, contains('Reviewer checklist'));
  });

  // 17 — empty diff → low risk, no findings.
  test('empty diff is low risk with no findings', () {
    final r = route(const []);
    expect(r.riskLevel, ContributionRiskLevel.low);
    expect(r.findings, isEmpty);
    expect(r.pass, isTrue);
    expect(r.changeCount, 0);
  });

  // 18 — unknown file → unknown category, no crash.
  test('unknown file routes to unknown category', () {
    final r = route([change('some/weird/path.bin')]);
    expect(hasCategory(r, ContributionRiskCategory.unknown), isTrue);
    expect(r.pass, isTrue);
  });

  // 19 — generated build output change → warning.
  test('generated build output produces warning', () {
    final r = route(
        [change('build/mechanistic_replay/latest.json', isGenerated: true)]);
    expect(hasCategory(r, ContributionRiskCategory.generatedOutput), isTrue);
    expect(r.counts['warn'], greaterThan(0));
  });

  // 20 — no patient / subject / encounter keys emitted by the report.
  test('no PHI/patient/subject/encounter keys emitted', () {
    final decoded = jsonDecode(encodeContributionSafetyReport(route([
      change('test/fixtures/x.json',
          isTest: true, added: '{"patient name": "Jane"}'),
      change('lib/domain/usecases/mechanistic_conflict_engine.dart'),
    ]))) as Map<String, dynamic>;
    scanNoPhiKeys(decoded);
  });
}
