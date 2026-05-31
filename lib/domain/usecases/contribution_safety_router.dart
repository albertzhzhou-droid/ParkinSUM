/// P11 — ContributionSafetyRouter.
///
/// Educational/research prototype only. Pure, deterministic repository-governance
/// helper that classifies pull-request / diff risk from changed file paths,
/// source references, and safety-sensitive keywords, then emits a structured
/// risk report, suggested labels, and a recommended reviewer checklist. Diff/file
/// parsing lives in the CLI tool; this usecase is pure over `ContributionChange`s.
///
/// It is **NOT** an AI code reviewer, **NOT** a medical reviewer, **NOT** a
/// legal/compliance tool, and does **NOT** replace human review or judge clinical
/// correctness. No PHI / patient / subject / encounter semantics.
library;

import 'dart:convert';

import '../entities/contribution_safety_router.dart';

class ContributionSafetyRouter {
  const ContributionSafetyRouter();

  static const String _safetyBoundary =
      'Deterministic repository-governance routing only. It is not AI code '
      'review, not a medical or legal reviewer, does not judge clinical '
      'correctness, and does not replace human review. It helps avoid '
      'unsupported claims, PHI, secrets, and source-governance mistakes.';

  static const List<String> _limitations = [
    'Deterministic path/keyword routing; not AI code review and not exhaustive.',
    'Does not judge clinical correctness or provide legal/compliance approval.',
    'Does not replace human review; it suggests attention, labels, and commands.',
    'Keyword matching is conservative; allowlisted detector/scanner files are downgraded.',
    'Synthetic/demo data only; not clinically calibrated.',
  ];

  // --- Keyword groups (scanner-safe; matched case-insensitively) ------------
  static const List<String> _clinicalAdvicePhrases = [
    'adjust your dose',
    'take medication',
    'avoid protein',
    'recommended dose',
    'recommended timing',
  ];
  static const List<String> _medicalClaimPhrases = [
    'safe for you',
    'confirmed safe',
    'clinically validated',
    'clinical validation claim',
    'patient-calibrated',
  ];
  static const List<String> _secretPhrases = [
    'begin private key',
    'private_key',
    'service account',
    'service_account',
    'oauth token',
    'oauth_token',
    'bearer token',
  ];
  static const List<String> _phiPhrases = [
    'patient name',
    'patient_name',
    'date of birth',
    'symptom log',
    'symptom_log',
    'medication schedule',
    'medication_schedule',
    'mrn',
  ];
  static const List<String> _sourceAccessPhrases = [
    'production-ready',
    'production ingestion',
    'license cleared',
    'legal approval',
    'live ingestion',
  ];

  ContributionSafetyReport route(
    List<ContributionChange> changes,
    ContributionSafetyRouterConfig config,
  ) {
    final findings = <ContributionRiskFinding>[];
    final categories = <String>{};

    for (final c in changes) {
      final pathCats = _categoriesForPath(c.path, c);
      categories.addAll(pathCats);

      // Generated build output committed.
      if (c.isGenerated || c.path.startsWith('build/')) {
        categories.add(ContributionRiskCategory.generatedOutput);
        findings.add(_f(
          ContributionRiskSeverity.warn,
          ContributionRiskCategory.generatedOutput,
          c.path,
          'Generated build output appears in the diff; confirm it should be '
          'committed and contains no sensitive content.',
          review: 'Generated artifacts are usually not committed.',
        ));
      }

      // Keyword risk scanning over added content + pre-matched keywords.
      final hay =
          ('${c.addedContent}\n${c.matchedKeywords.join('\n')}').toLowerCase();
      _scan(
          c,
          hay,
          _clinicalAdvicePhrases,
          ContributionRiskCategory.clinicalAdviceRisk,
          categories,
          findings,
          'Possible clinical-advice phrasing.',
          'Replace with non-prescriptive, scanner-safe boundary text.');
      _scan(
          c,
          hay,
          _medicalClaimPhrases,
          ContributionRiskCategory.medicalClaimRisk,
          categories,
          findings,
          'Possible unsupported medical/clinical claim.',
          'Use "not clinically calibrated" / "carries no clinical-validation '
              'claim" instead.');
      _scan(
          c,
          hay,
          _secretPhrases,
          ContributionRiskCategory.secretRisk,
          categories,
          findings,
          'Possible secret/credential material.',
          'Remove the secret; never commit credentials.');
      _scan(
          c,
          hay,
          _phiPhrases,
          ContributionRiskCategory.phiRisk,
          categories,
          findings,
          'Possible PHI-like field/value.',
          'Use synthetic/demo data only; never commit patient data.');
      _scanSourceAccess(c, hay, categories, findings);
    }

    if (categories.isEmpty && changes.isNotEmpty) {
      categories.add(ContributionRiskCategory.unknown);
    }

    // Apply strict escalation (WARN → BLOCKER) deterministically.
    final escalated = config.strictMode
        ? findings
            .map((f) => f.severity == ContributionRiskSeverity.warn
                ? _f(ContributionRiskSeverity.blocker, f.category, f.path,
                    f.message,
                    line: f.line,
                    matched: f.matchedText,
                    review: f.suggestedReview,
                    command: f.requiredCommand)
                : f)
            .toList()
        : findings;

    final counts = <String, int>{
      ContributionRiskSeverity.info: 0,
      ContributionRiskSeverity.warn: 0,
      ContributionRiskSeverity.blocker: 0,
    };
    for (final f in escalated) {
      counts[f.severity] = (counts[f.severity] ?? 0) + 1;
    }

    final riskLevel = _riskLevel(categories, escalated);
    final checklist = _checklist(categories);
    final requiredCommands = <String>{
      for (final item in checklist)
        if (item.required) ...item.relatedCommands,
    }.toList()
      ..sort();
    final labels = _labels(categories)..sort();

    return ContributionSafetyReport(
      generatedAt: config.deterministicTimestamp,
      changeCount: changes.length,
      categories: categories.toList()..sort(),
      riskLevel: riskLevel,
      counts: counts,
      findings: escalated,
      checklist: checklist,
      suggestedLabels: labels,
      requiredCommands: requiredCommands,
      pass: (counts[ContributionRiskSeverity.blocker] ?? 0) == 0,
      safetyBoundary: _safetyBoundary,
      notClinicallyCalibrated: true,
      limitations: _limitations,
    );
  }

  // --- path classification --------------------------------------------------

  Set<String> _categoriesForPath(String path, ContributionChange c) {
    final p = path;
    final cats = <String>{};

    // Firebase / security (highest path priority).
    if (p == 'firestore.rules' ||
        p == 'firebase.json' ||
        p == 'lib/firebase_options.dart' ||
        p == 'android/app/google-services.json' ||
        p == 'ios/Runner/GoogleService-Info.plist' ||
        p == 'macos/Runner/GoogleService-Info.plist' ||
        (p.startsWith('tool/') &&
            (p.contains('preflight') || p.contains('security')))) {
      cats.add(ContributionRiskCategory.firebaseRules);
      cats.add(ContributionRiskCategory.securitySensitive);
      return cats;
    }

    // Importer.
    if (p.startsWith('lib/data/datasources/remote/') ||
        p.startsWith('test/fixtures/importers/')) {
      cats.add(ContributionRiskCategory.importer);
      if (p.contains('source_adapter_registry')) {
        cats.add(ContributionRiskCategory.sourceMetadata);
      }
      return cats;
    }

    // Mechanistic model.
    if (RegExp(r'lib/domain/usecases/mechanistic_').hasMatch(p) ||
        p == 'lib/domain/usecases/gastric_emptying_model.dart' ||
        p == 'lib/domain/usecases/amino_acid_competition_model.dart' ||
        p == 'lib/domain/usecases/levodopa_absorption_opportunity_model.dart' ||
        RegExp(r'lib/domain/entities/(gastric_|amino_acid_|absorption_)')
            .hasMatch(p)) {
      cats.add(ContributionRiskCategory.mechanisticModel);
      // Replay runner / source-quality report also tagged below.
      if (p.contains('replay')) {
        cats.add(ContributionRiskCategory.replayScenario);
      }
      return cats;
    }

    // Replay / evidence / report artifacts + generator tools.
    if (p == 'lib/core/constants/mechanistic_replay_scenarios.dart' ||
        p.contains('replay')) {
      cats.add(ContributionRiskCategory.replayScenario);
    }
    if (RegExp(r'lib/domain/(entities|usecases)/evidence_').hasMatch(p) ||
        p == 'lib/domain/usecases/source_quality_perturbation_report.dart') {
      cats.add(ContributionRiskCategory.evidenceArtifact);
    }
    if (p.startsWith('tool/generate_') || p.startsWith('tool/run_')) {
      cats.add(ContributionRiskCategory.releaseGovernance);
    }

    // Source metadata / source access.
    if (p == 'lib/domain/entities/source_metadata.dart' ||
        p == 'lib/domain/usecases/source_authority_scorer.dart' ||
        p == 'lib/domain/usecases/metadata_completeness_gate.dart' ||
        p == 'config/source_access_registry.json' ||
        p == 'lib/data/datasources/remote/source_adapter_registry.dart' ||
        p.contains('source_access') ||
        p.contains('source_version_drift')) {
      cats.add(ContributionRiskCategory.sourceMetadata);
    }

    // Localization.
    if (p.contains('localization') ||
        p.contains('safe_copy_template') ||
        p.contains('app_i18n')) {
      cats.add(ContributionRiskCategory.localizationCopy);
    }

    // Rule explanation.
    if (p.contains('rule_explanation')) {
      cats.add(ContributionRiskCategory.ruleExplanation);
    }

    // Docs.
    if (c.isDocs ||
        p == 'README.md' ||
        p == 'Bibliographies.md' ||
        p.startsWith('docs/') ||
        p.startsWith('.github/')) {
      cats.add(ContributionRiskCategory.docsOnly);
    }

    // Tests.
    if (c.isTest || p.startsWith('test/')) {
      cats.add(ContributionRiskCategory.testOnly);
    }

    return cats;
  }

  // --- keyword scanning -----------------------------------------------------

  void _scan(
    ContributionChange c,
    String hay,
    List<String> phrases,
    String category,
    Set<String> categories,
    List<ContributionRiskFinding> findings,
    String message,
    String review,
  ) {
    for (final phrase in phrases) {
      if (hay.contains(phrase)) {
        categories.add(category);
        findings.add(_f(
          c.allowlisted
              ? ContributionRiskSeverity.info
              : ContributionRiskSeverity.blocker,
          category,
          c.path,
          c.allowlisted
              ? '$message (allowlisted detector/scanner file — informational).'
              : message,
          matched: phrase,
          review: review,
        ));
        return; // one finding per category per change is enough.
      }
    }
  }

  void _scanSourceAccess(
    ContributionChange c,
    String hay,
    Set<String> categories,
    List<ContributionRiskFinding> findings,
  ) {
    for (final phrase in _sourceAccessPhrases) {
      if (hay.contains(phrase)) {
        categories.add(ContributionRiskCategory.sourceAccessRisk);
        findings.add(_f(
          ContributionRiskSeverity.warn,
          ContributionRiskCategory.sourceAccessRisk,
          c.path,
          c.allowlisted
              ? 'Possible source-access claim (allowlisted file — informational).'
              : 'Possible source-access / production-readiness claim; confirm '
                  'it matches the source-access registry.',
          matched: phrase,
          review: 'Fixture-only sources must not be described as '
              'production-ready.',
          command: 'npm run source:access',
        ));
        return;
      }
    }
  }

  // --- risk level -----------------------------------------------------------

  String _riskLevel(
      Set<String> categories, List<ContributionRiskFinding> findings) {
    var level = ContributionRiskLevel.low;
    if (findings.any((f) => f.severity == ContributionRiskSeverity.blocker)) {
      return ContributionRiskLevel.blocker;
    }
    for (final cat in categories) {
      level = ContributionRiskLevel.higher(level, _categoryRisk(cat));
    }
    if (findings.any((f) => f.severity == ContributionRiskSeverity.warn)) {
      level = ContributionRiskLevel.higher(level, ContributionRiskLevel.medium);
    }
    return level;
  }

  String _categoryRisk(String category) {
    switch (category) {
      case ContributionRiskCategory.docsOnly:
      case ContributionRiskCategory.testOnly:
        return ContributionRiskLevel.low;
      case ContributionRiskCategory.sourceMetadata:
      case ContributionRiskCategory.localizationCopy:
      case ContributionRiskCategory.evidenceArtifact:
      case ContributionRiskCategory.replayScenario:
      case ContributionRiskCategory.ruleExplanation:
      case ContributionRiskCategory.releaseGovernance:
      case ContributionRiskCategory.sourceAccessRisk:
      case ContributionRiskCategory.generatedOutput:
      case ContributionRiskCategory.unknown:
        return ContributionRiskLevel.medium;
      case ContributionRiskCategory.importer:
      case ContributionRiskCategory.mechanisticModel:
      case ContributionRiskCategory.firebaseRules:
      case ContributionRiskCategory.securitySensitive:
        return ContributionRiskLevel.high;
      case ContributionRiskCategory.medicalClaimRisk:
      case ContributionRiskCategory.clinicalAdviceRisk:
      case ContributionRiskCategory.secretRisk:
      case ContributionRiskCategory.phiRisk:
        // These categories are driven by their FINDINGS' severity (a real
        // blocker finding sets the overall risk to blocker; an allowlisted
        // info finding must not, by category presence alone, force blocker).
        return ContributionRiskLevel.low;
      default:
        return ContributionRiskLevel.low;
    }
  }

  // --- checklist ------------------------------------------------------------

  List<ContributionReviewChecklistItem> _checklist(Set<String> categories) {
    final items = <String, ContributionReviewChecklistItem>{};
    void add(ContributionReviewChecklistItem i) => items[i.id] = i;

    // Universal boundary item.
    add(const ContributionReviewChecklistItem(
      id: 'boundary_no_phi_no_advice',
      category: 'all',
      required: true,
      text: 'Confirm no PHI, no real patient data, no medical advice, and no '
          'clinical-calibration claim.',
      blockingIfMissing: true,
      relatedCommands: [
        'npm run public:preflight',
        'npm run privacy:preflight'
      ],
    ));

    for (final cat in categories) {
      switch (cat) {
        case ContributionRiskCategory.docsOnly:
          add(const ContributionReviewChecklistItem(
            id: 'docs_no_unsupported_claim',
            category: ContributionRiskCategory.docsOnly,
            required: true,
            text:
                'Confirm no unsupported medical/clinical claim and that links '
                'are accurate.',
            relatedCommands: ['npm run public:preflight'],
          ));
          break;
        case ContributionRiskCategory.testOnly:
          add(const ContributionReviewChecklistItem(
            id: 'tests_synthetic_only',
            category: ContributionRiskCategory.testOnly,
            required: true,
            text: 'Confirm fixtures are synthetic only (no PHI, no secrets).',
            relatedCommands: ['flutter test --concurrency=1'],
          ));
          break;
        case ContributionRiskCategory.mechanisticModel:
          add(const ContributionReviewChecklistItem(
            id: 'mechanistic_assumptions_sourced',
            category: ContributionRiskCategory.mechanisticModel,
            required: true,
            text: 'Confirm no clinical-calibration claim and that all '
                'assumptions carry sourceRefs / limitations.',
            blockingIfMissing: true,
            relatedCommands: [
              'flutter test --concurrency=1',
              'dart run tool/run_mechanistic_replay.dart',
              'npm run scenario:fuzz',
            ],
          ));
          break;
        case ContributionRiskCategory.importer:
          add(const ContributionReviewChecklistItem(
            id: 'importer_status_honest',
            category: ContributionRiskCategory.importer,
            required: true,
            text: 'Confirm fixture/live/production status is honest and no raw '
                'private export is committed.',
            relatedCommands: [
              'npm run source:access',
              'npm run privacy:preflight',
            ],
          ));
          break;
        case ContributionRiskCategory.localizationCopy:
          add(const ContributionReviewChecklistItem(
            id: 'localization_non_prescriptive',
            category: ContributionRiskCategory.localizationCopy,
            required: true,
            text: 'Confirm localized text stays non-prescriptive and keeps the '
                'safety meaning.',
            relatedCommands: ['npm run localization:lint'],
          ));
          break;
        case ContributionRiskCategory.firebaseRules:
        case ContributionRiskCategory.securitySensitive:
          add(const ContributionReviewChecklistItem(
            id: 'security_gates',
            category: ContributionRiskCategory.securitySensitive,
            required: true,
            text: 'Run the public + privacy preflights and the Firestore rules '
                'contract.',
            blockingIfMissing: true,
            relatedCommands: [
              'npm run public:preflight',
              'npm run privacy:preflight',
              'node tool/firestore_rules_contract_check.mjs',
            ],
          ));
          break;
        case ContributionRiskCategory.sourceMetadata:
          add(const ContributionReviewChecklistItem(
            id: 'source_metadata_checks',
            category: ContributionRiskCategory.sourceMetadata,
            required: true,
            text: 'Confirm sourceRefs resolve; run source-quality and '
                'source-access/drift checks.',
            relatedCommands: [
              'npm run source:quality',
              'npm run source:access',
              'npm run source:drift',
            ],
          ));
          break;
        case ContributionRiskCategory.evidenceArtifact:
        case ContributionRiskCategory.replayScenario:
        case ContributionRiskCategory.releaseGovernance:
          add(const ContributionReviewChecklistItem(
            id: 'evidence_artifacts_regenerated',
            category: ContributionRiskCategory.evidenceArtifact,
            required: true,
            text: 'Regenerate the release snapshot / evidence graph / demo '
                'walkthrough as needed.',
            relatedCommands: [
              'npm run release:snapshot',
              'npm run evidence:graph',
              'npm run demo:walkthrough',
            ],
          ));
          break;
        case ContributionRiskCategory.secretRisk:
          add(const ContributionReviewChecklistItem(
            id: 'remove_secrets',
            category: ContributionRiskCategory.secretRisk,
            required: true,
            text: 'Remove any secret/credential material before merge.',
            blockingIfMissing: true,
            relatedCommands: ['npm run privacy:preflight'],
          ));
          break;
        case ContributionRiskCategory.phiRisk:
          add(const ContributionReviewChecklistItem(
            id: 'remove_phi',
            category: ContributionRiskCategory.phiRisk,
            required: true,
            text: 'Remove any PHI-like fixture data; use synthetic data only.',
            blockingIfMissing: true,
            relatedCommands: ['npm run privacy:preflight'],
          ));
          break;
        case ContributionRiskCategory.medicalClaimRisk:
        case ContributionRiskCategory.clinicalAdviceRisk:
          add(const ContributionReviewChecklistItem(
            id: 'remove_clinical_advice',
            category: ContributionRiskCategory.clinicalAdviceRisk,
            required: true,
            text: 'Replace clinical-advice/claim phrasing with scanner-safe '
                'boundary text.',
            blockingIfMissing: true,
            relatedCommands: ['npm run public:preflight'],
          ));
          break;
        default:
          break;
      }
    }

    return items.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  // --- labels ---------------------------------------------------------------

  List<String> _labels(Set<String> categories) {
    final labels = <String>{};
    for (final cat in categories) {
      switch (cat) {
        case ContributionRiskCategory.docsOnly:
          labels.add('docs');
          break;
        case ContributionRiskCategory.testOnly:
          labels.add('tests');
          break;
        case ContributionRiskCategory.sourceMetadata:
          labels.addAll(['source-metadata', 'needs-source-review']);
          break;
        case ContributionRiskCategory.replayScenario:
          labels.add('replay');
          break;
        case ContributionRiskCategory.mechanisticModel:
          labels.addAll(['mechanistic-model', 'safety-review']);
          break;
        case ContributionRiskCategory.importer:
          labels.addAll(['importer', 'needs-source-review']);
          break;
        case ContributionRiskCategory.firebaseRules:
          labels.add('firebase-rules');
          break;
        case ContributionRiskCategory.securitySensitive:
          labels.add('security-sensitive');
          break;
        case ContributionRiskCategory.localizationCopy:
          labels.add('localization');
          break;
        case ContributionRiskCategory.evidenceArtifact:
        case ContributionRiskCategory.releaseGovernance:
          labels.add('needs-release-gates');
          break;
        case ContributionRiskCategory.medicalClaimRisk:
          labels.addAll(['medical-claim-risk', 'safety-review']);
          break;
        case ContributionRiskCategory.clinicalAdviceRisk:
          labels.addAll(['medical-claim-risk', 'safety-review']);
          break;
        case ContributionRiskCategory.secretRisk:
          labels.add('secret-risk');
          break;
        case ContributionRiskCategory.phiRisk:
          labels.add('phi-risk');
          break;
        case ContributionRiskCategory.sourceAccessRisk:
          labels.add('needs-source-review');
          break;
        default:
          break;
      }
    }
    return labels.toList();
  }

  ContributionRiskFinding _f(
    String severity,
    String category,
    String path,
    String message, {
    int line = 0,
    String matched = '',
    String review = '',
    String command = '',
  }) =>
      ContributionRiskFinding(
        severity: severity,
        category: category,
        path: path,
        line: line,
        message: message,
        matchedText: matched,
        suggestedReview: review,
        requiredCommand: command,
        safetyBoundary: _safetyBoundary,
      );
}

/// Deterministic JSON encoder.
String encodeContributionSafetyReport(ContributionSafetyReport r) =>
    const JsonEncoder.withIndent('  ').convert(r.toJson());

/// Deterministic markdown renderer.
String renderContributionSafetyMarkdown(ContributionSafetyReport r) {
  final b = StringBuffer()
    ..writeln('# ParkinSUM Contribution Safety Router')
    ..writeln()
    ..writeln('Educational/research prototype. **Deterministic '
        'repository-governance routing only — not AI code review, not a '
        'medical/legal reviewer, and does not replace human review.**')
    ..writeln()
    ..writeln('- changed files: ${r.changeCount}')
    ..writeln('- risk level: ${r.riskLevel}')
    ..writeln('- categories: ${r.categories.join(', ')}')
    ..writeln('- info: ${r.counts['info'] ?? 0} · '
        'warn: ${r.counts['warn'] ?? 0} · '
        'blocker: ${r.blockerCount}')
    ..writeln('- pass (0 blocker): ${r.pass}')
    ..writeln('- suggested labels: ${r.suggestedLabels.join(', ')}')
    ..writeln();
  if (r.findings.isNotEmpty) {
    b
      ..writeln('## Findings')
      ..writeln()
      ..writeln('| severity | category | path | message |')
      ..writeln('| --- | --- | --- | --- |');
    for (final f in r.findings) {
      b.writeln('| ${f.severity} | ${f.category} | ${f.path} | ${f.message} |');
    }
    b.writeln();
  }
  b
    ..writeln('## Reviewer checklist')
    ..writeln();
  for (final item in r.checklist) {
    final cmds = item.relatedCommands.isEmpty
        ? ''
        : ' _(${item.relatedCommands.join('; ')})_';
    b.writeln('- [ ] ${item.text}$cmds');
  }
  if (r.requiredCommands.isNotEmpty) {
    b
      ..writeln()
      ..writeln('## Suggested commands')
      ..writeln();
    for (final cmd in r.requiredCommands) {
      b.writeln('- `$cmd`');
    }
  }
  b
    ..writeln()
    ..writeln('## Limitations')
    ..writeln();
  for (final l in r.limitations) {
    b.writeln('- $l');
  }
  b
    ..writeln()
    ..writeln('## Safety boundary')
    ..writeln()
    ..writeln(r.safetyBoundary);
  return b.toString();
}
