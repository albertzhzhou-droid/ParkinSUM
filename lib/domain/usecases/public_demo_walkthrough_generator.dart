/// P10 — PublicDemoWalkthroughGenerator.
///
/// Educational/research prototype only. Synthetic/demo data only. Not medical
/// advice, not clinically calibrated, and carries no clinical-validation claim.
///
/// Composes existing synthetic artifacts (mechanistic replay, source-quality
/// perturbation report, release snapshot, an EvidenceTraceBundle sample, and a
/// capability-matrix summary) into one reviewer-facing Markdown walkthrough. It
/// is a **pure** transform: missing artifacts are reported as `missing_artifact`
/// and never fabricated. It must not emit medication/diet/dose/timing advice,
/// patient-specific interpretation, clinical-validation claims, PHI, or
/// patient/subject/encounter fields.
library;

import 'dart:convert';

import '../entities/rule_explanation.dart';
import 'release_snapshot_generator.dart' show kMissingArtifact;

/// Inputs are already-parsed artifact maps (all optional).
class PublicDemoWalkthroughInputs {
  /// Parsed `build/mechanistic_replay/latest.json`.
  final Map<String, dynamic>? replayReport;

  /// Parsed `build/source_quality_perturbation/latest.json`.
  final Map<String, dynamic>? sourceQualityReport;

  /// Parsed `build/release_snapshot/latest.json` (P12 output).
  final Map<String, dynamic>? releaseSnapshot;

  /// A synthetic EvidenceTraceBundle sample (`EvidenceTraceBundle.toJson()`).
  final Map<String, dynamic>? evidenceBundle;

  /// One-line capability-matrix summary, when available.
  final String? capabilityMatrixSummary;

  const PublicDemoWalkthroughInputs({
    this.replayReport,
    this.sourceQualityReport,
    this.releaseSnapshot,
    this.evidenceBundle,
    this.capabilityMatrixSummary,
  });
}

class PublicDemoWalkthrough {
  static const String kDocType = 'parkinsum_public_demo_walkthrough';

  final String syntheticInputSummary;
  final String sourceQualitySummary;
  final String missingnessSummary;
  final String replaySummary;
  final String evidenceBundleSummary;

  const PublicDemoWalkthrough({
    required this.syntheticInputSummary,
    required this.sourceQualitySummary,
    required this.missingnessSummary,
    required this.replaySummary,
    required this.evidenceBundleSummary,
  });

  static const List<String> whatItProves = [
    'Outputs are deterministic and reproducible from synthetic inputs.',
    'Provenance and missingness are preserved (missing is recorded, not coerced to zero).',
    'Source quality affects modeled confidence and tie-breaking only.',
    'Safety copy is scanned so educational text cannot drift into advice.',
  ];

  static const List<String> whatItDoesNotProve = [
    'Any clinical accuracy, patient-outcome validity, or regulatory approval.',
    'Any individual plasma-levodopa prediction.',
    'That the model is clinically calibrated (it is not).',
    'Anything about a specific person — there is no patient data.',
  ];

  Map<String, dynamic> toJson() => {
        'doc_type': kDocType,
        'not_clinically_calibrated': true,
        'synthetic_demo_data_only': true,
        'no_medical_advice': true,
        'synthetic_input_summary': syntheticInputSummary,
        'source_quality_summary': sourceQualitySummary,
        'missingness_summary': missingnessSummary,
        'replay_summary': replaySummary,
        'evidence_bundle_summary': evidenceBundleSummary,
        'what_it_proves': whatItProves,
        'what_it_does_not_prove': whatItDoesNotProve,
        'safety_boundary': RuleExplanation.defaultSafetyBoundary,
        'not_advice_text': RuleExplanation.defaultNotAdvice,
      };

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# ParkinSUM Public Demo Walkthrough')
      ..writeln()
      ..writeln('Educational/research prototype. Synthetic/demo data only. '
          '**Not medical advice, not clinically calibrated, and carries no '
          'clinical-validation claim.** No patient data is used or shown.')
      ..writeln()
      ..writeln('Composed from existing synthetic artifacts. Missing artifacts '
          'are reported as `missing_artifact` — never fabricated.')
      ..writeln()
      ..writeln('## 1. Synthetic input summary')
      ..writeln()
      ..writeln(syntheticInputSummary)
      ..writeln()
      ..writeln('## 2. Source quality summary')
      ..writeln()
      ..writeln(sourceQualitySummary)
      ..writeln()
      ..writeln('## 3. Missingness summary')
      ..writeln()
      ..writeln(missingnessSummary)
      ..writeln()
      ..writeln('## 4. Mechanistic replay summary')
      ..writeln()
      ..writeln(replaySummary)
      ..writeln()
      ..writeln('## 5. Evidence trace / bundle summary')
      ..writeln()
      ..writeln(evidenceBundleSummary)
      ..writeln()
      ..writeln('## 6. What this demo proves')
      ..writeln();
    for (final l in whatItProves) {
      b.writeln('- $l');
    }
    b
      ..writeln()
      ..writeln('## 7. What this demo does NOT prove')
      ..writeln();
    for (final l in whatItDoesNotProve) {
      b.writeln('- $l');
    }
    b
      ..writeln()
      ..writeln('## 8. Safety boundary')
      ..writeln()
      ..writeln(RuleExplanation.defaultSafetyBoundary)
      ..writeln()
      ..writeln('## 9. Not clinically calibrated')
      ..writeln()
      ..writeln('The mechanistic model is **not clinically calibrated**; '
          'numeric magnitudes are literature-informed prototype parameters.')
      ..writeln()
      ..writeln('## 10. Not medical advice')
      ..writeln()
      ..writeln(RuleExplanation.defaultNotAdvice);
    return b.toString();
  }
}

class PublicDemoWalkthroughGenerator {
  const PublicDemoWalkthroughGenerator();

  PublicDemoWalkthrough build(PublicDemoWalkthroughInputs inputs) {
    return PublicDemoWalkthrough(
      syntheticInputSummary: _syntheticInput(inputs),
      sourceQualitySummary: _sourceQuality(inputs.sourceQualityReport),
      missingnessSummary: _missingness(inputs.replayReport),
      replaySummary: _replay(inputs.replayReport),
      evidenceBundleSummary: _evidenceBundle(inputs.evidenceBundle),
    );
  }

  String _syntheticInput(PublicDemoWalkthroughInputs i) {
    final replay = i.replayReport;
    final scenarios = replay != null && replay['cases'] is List
        ? (replay['cases'] as List).length
        : null;
    final cap = i.capabilityMatrixSummary ?? kMissingArtifact;
    final scenarioText = scenarios == null
        ? kMissingArtifact
        : '$scenarios synthetic replay scenarios';
    return 'All inputs are synthetic/demo only (no patient data). '
        'Scenarios: $scenarioText. Capability matrix: $cap.';
  }

  String _sourceQuality(Map<String, dynamic>? report) {
    if (report == null) return kMissingArtifact;
    final rows = report['rows'];
    if (rows is! List) return kMissingArtifact;
    return 'Source-quality perturbation report: ${rows.length} rows showing how '
        'modeled scoring moves when only source/provenance quality changes '
        '(conflict overlap stays dominant; provenance is a source-quality '
        'signal, not clinical accuracy).';
  }

  String _missingness(Map<String, dynamic>? report) {
    if (report == null) return kMissingArtifact;
    final cases = report['cases'];
    if (cases is! List) return kMissingArtifact;
    var incomplete = 0;
    for (final c in cases) {
      if (c is Map &&
          c['meal_context_completeness'] is num &&
          (c['meal_context_completeness'] as num) < 1.0) {
        incomplete += 1;
      }
    }
    return 'Missing nutrient/medication fields are recorded as missing (never '
        'coerced to a true 0 g), which lowers completeness and widens '
        'uncertainty. $incomplete of ${cases.length} replay scenarios model '
        'reduced meal-context completeness.';
  }

  String _replay(Map<String, dynamic>? report) {
    if (report == null) return kMissingArtifact;
    final passed = report['passed'];
    final total = report['total'];
    if (passed is! int || total is! int) return kMissingArtifact;
    return 'Mechanistic replay: $passed/$total deterministic synthetic '
        'scenarios passed, each scanned for banned prescriptive phrasing. '
        'This is synthetic regression testing, not clinical validation.';
  }

  String _evidenceBundle(Map<String, dynamic>? bundle) {
    if (bundle == null) return kMissingArtifact;
    final type = bundle['bundle_type'];
    final conformance = bundle['conformance_status'];
    final phi = bundle['phi_policy'];
    if (type == null || conformance == null) return kMissingArtifact;
    return 'A local EvidenceTraceBundle (`$type`, `$conformance`, `$phi`) pairs '
        'the FHIR-inspired views for review. It is explicitly NOT a FHIR Bundle '
        'and contains no patient/subject/encounter linkage.';
  }
}

/// Deterministic JSON encoder (stable key order via the model's `toJson`).
String encodePublicDemoWalkthrough(PublicDemoWalkthrough doc) =>
    const JsonEncoder.withIndent('  ').convert(doc.toJson());
