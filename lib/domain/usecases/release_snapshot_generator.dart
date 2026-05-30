/// P12 — ReleaseSnapshotGenerator.
///
/// Educational/research prototype only. Synthetic/demo data only. Not medical
/// advice, not clinically calibrated, and carries no clinical-validation claim.
///
/// Composes **existing** verification artifacts into one reproducible release
/// evidence snapshot. It is a **pure** transform: it parses already-produced
/// report maps + injectable command results and emits deterministic JSON +
/// markdown. It never runs slow commands itself, and when an expected artifact
/// is missing it records `missing_artifact` rather than fabricating success.
library;

import 'dart:convert';

import '../entities/rule_explanation.dart';

/// Sentinel recorded when an expected artifact/result is absent.
const String kMissingArtifact = 'missing_artifact';

/// Inputs to the snapshot. Every field is optional; absent fields become
/// `missing_artifact` in the snapshot (never a fabricated success).
class ReleaseSnapshotInputs {
  /// `flutter analyze` status, e.g. `clean` (injected by the caller/CI).
  final String? analyzeStatus;

  /// `flutter test` count + status (injected; tests do not run the suite).
  final int? testCount;
  final String? testStatus;

  /// Parsed `build/mechanistic_replay/latest.json` (`passed`/`total`).
  final Map<String, dynamic>? replayReport;

  /// Parsed `build/source_quality_perturbation/latest.json` (`rows`).
  final Map<String, dynamic>? sourceQualityReport;

  /// Parsed `build/public_release_preflight/latest.json` (`counts.BLOCKER`).
  final Map<String, dynamic>? preflightReport;

  /// Firestore rules contract result, e.g. `13/13` (injected).
  final String? firestoreStatus;

  /// Optional live-smoke status; live smoke is opt-in and excluded by default.
  final String? liveSmokeStatus;

  /// Optional capability-matrix one-line summary (e.g. row counts by status).
  final String? capabilityMatrixSummary;

  const ReleaseSnapshotInputs({
    this.analyzeStatus,
    this.testCount,
    this.testStatus,
    this.replayReport,
    this.sourceQualityReport,
    this.preflightReport,
    this.firestoreStatus,
    this.liveSmokeStatus,
    this.capabilityMatrixSummary,
  });
}

/// A deterministic release-evidence snapshot. No timestamps are embedded so the
/// output is reproducible for identical inputs.
class ReleaseSnapshot {
  static const String kSnapshotType = 'parkinsum_release_snapshot';

  final String analyzeStatus;
  final String testStatus;
  final String replayStatus;
  final String sourceQualityStatus;
  final String preflightStatus;
  final String firestoreStatus;
  final String liveSmokeStatus;
  final String capabilityMatrixSummary;

  const ReleaseSnapshot({
    required this.analyzeStatus,
    required this.testStatus,
    required this.replayStatus,
    required this.sourceQualityStatus,
    required this.preflightStatus,
    required this.firestoreStatus,
    required this.liveSmokeStatus,
    required this.capabilityMatrixSummary,
  });

  /// True when every required section resolved (no `missing_artifact`).
  bool get complete => ![
        analyzeStatus,
        testStatus,
        replayStatus,
        sourceQualityStatus,
        preflightStatus,
        firestoreStatus,
      ].any((s) => s.contains(kMissingArtifact));

  static const List<String> knownLimitations = [
    'Deterministic synthetic-data regression + governance evidence only.',
    'Not clinical validation; the model is not clinically calibrated.',
    'Importer adapters are fixture-validated, not live production ingestion.',
    'Counts are composed from existing artifacts; missing inputs are recorded '
        'as missing_artifact, never fabricated.',
  ];

  Map<String, dynamic> toJson() => {
        'snapshot_type': kSnapshotType,
        'not_clinically_calibrated': true,
        'synthetic_demo_data_only': true,
        'no_medical_advice': true,
        'complete': complete,
        'checks': {
          'flutter_analyze': analyzeStatus,
          'flutter_test': testStatus,
          'mechanistic_replay': replayStatus,
          'source_quality_perturbation': sourceQualityStatus,
          'public_preflight': preflightStatus,
          'firestore_rules_contract': firestoreStatus,
          'live_source_smoke': liveSmokeStatus,
        },
        'capability_matrix_summary': capabilityMatrixSummary,
        'known_limitations': knownLimitations,
        'safety_boundary': RuleExplanation.defaultSafetyBoundary,
        'not_advice_text': RuleExplanation.defaultNotAdvice,
      };

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# ParkinSUM Release Snapshot')
      ..writeln()
      ..writeln('Educational/research prototype. Synthetic/demo data only. '
          '**Not medical advice, not clinically calibrated, and carries no '
          'clinical-validation claim.**')
      ..writeln()
      ..writeln('Composed from existing verification artifacts. Missing inputs '
          'are recorded as `missing_artifact` — never fabricated.')
      ..writeln()
      ..writeln('| Check | Status |')
      ..writeln('| --- | --- |')
      ..writeln('| flutter analyze | $analyzeStatus |')
      ..writeln('| flutter test | $testStatus |')
      ..writeln('| mechanistic replay | $replayStatus |')
      ..writeln('| source-quality perturbation | $sourceQualityStatus |')
      ..writeln('| public preflight | $preflightStatus |')
      ..writeln('| firestore rules contract | $firestoreStatus |')
      ..writeln('| live source smoke | $liveSmokeStatus |')
      ..writeln()
      ..writeln('Capability matrix: $capabilityMatrixSummary')
      ..writeln()
      ..writeln(
          'Overall: ${complete ? 'all required checks resolved' : 'incomplete (missing_artifact present)'}.')
      ..writeln()
      ..writeln('## Known limitations')
      ..writeln();
    for (final l in knownLimitations) {
      b.writeln('- $l');
    }
    b
      ..writeln()
      ..writeln('## Safety boundary')
      ..writeln()
      ..writeln(RuleExplanation.defaultSafetyBoundary)
      ..writeln()
      ..writeln(RuleExplanation.defaultNotAdvice);
    return b.toString();
  }
}

class ReleaseSnapshotGenerator {
  const ReleaseSnapshotGenerator();

  ReleaseSnapshot build(ReleaseSnapshotInputs inputs) {
    return ReleaseSnapshot(
      analyzeStatus: inputs.analyzeStatus ?? kMissingArtifact,
      testStatus: _testStatus(inputs),
      replayStatus: _replayStatus(inputs.replayReport),
      sourceQualityStatus: _sourceQualityStatus(inputs.sourceQualityReport),
      preflightStatus: _preflightStatus(inputs.preflightReport),
      firestoreStatus: inputs.firestoreStatus ?? kMissingArtifact,
      // Live smoke is opt-in and excluded from default runs; not a failure.
      liveSmokeStatus: inputs.liveSmokeStatus ?? 'skipped_opt_in',
      capabilityMatrixSummary:
          inputs.capabilityMatrixSummary ?? kMissingArtifact,
    );
  }

  String _testStatus(ReleaseSnapshotInputs i) {
    if (i.testCount == null || i.testStatus == null) return kMissingArtifact;
    return '${i.testStatus} (${i.testCount} tests)';
  }

  String _replayStatus(Map<String, dynamic>? report) {
    if (report == null) return kMissingArtifact;
    final passed = report['passed'];
    final total = report['total'];
    if (passed is! int || total is! int) return kMissingArtifact;
    return passed == total
        ? 'passed ($passed/$total scenarios)'
        : 'FAILED ($passed/$total scenarios)';
  }

  String _sourceQualityStatus(Map<String, dynamic>? report) {
    if (report == null) return kMissingArtifact;
    final rows = report['rows'];
    if (rows is! List) return kMissingArtifact;
    return 'generated (${rows.length} rows)';
  }

  String _preflightStatus(Map<String, dynamic>? report) {
    if (report == null) return kMissingArtifact;
    final counts = report['counts'];
    if (counts is! Map) return kMissingArtifact;
    final blocker = counts['BLOCKER'];
    if (blocker is! int) return kMissingArtifact;
    return blocker == 0 ? 'pass (0 BLOCKER)' : 'FAILED ($blocker BLOCKER)';
  }
}

/// Deterministic JSON encoder (stable key order via the model's `toJson`).
String encodeReleaseSnapshot(ReleaseSnapshot snapshot) =>
    const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
