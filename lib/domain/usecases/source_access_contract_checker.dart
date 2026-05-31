/// P9 — SourceAccessContractChecker.
///
/// Pure, deterministic source-governance checker. File discovery and I/O live
/// in the tool wrapper. This is not legal advice, license clearance, clinical
/// validation, or a production-readiness certification.
library;

import 'dart:convert';

import '../entities/source_access_contract.dart';
import '../entities/rule_explanation.dart';

class SourceAccessContractChecker {
  const SourceAccessContractChecker();

  static const List<String> limitations = [
    'Source governance and release hygiene only; not legal advice or license clearance.',
    'Does not fetch live data and does not make fixture-tested sources production-ready.',
    'Does not prove clinical correctness, source completeness, or production readiness.',
    'Collector classification is conservative; ambiguous usages remain warnings for human review.',
  ];

  SourceAccessContractReport check({
    required SourceAccessContract contract,
    required List<ObservedSourceRef> references,
    String registryPath = 'config/source_access_registry.json',
    bool strictMode = false,
    String deterministicTimestamp = '1970-01-01T00:00:00.000Z',
  }) {
    final findings = <SourceAccessFinding>[];

    void add({
      required String severity,
      required String type,
      required String sourceId,
      required String file,
      required String message,
      String suggestedFix = '',
    }) {
      findings.add(SourceAccessFinding(
        severity: severity,
        findingType: type,
        sourceId: sourceId,
        file: file,
        message: message,
        suggestedFix: suggestedFix,
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      ));
    }

    for (final record in contract.records.values) {
      if (record.isFixtureOnly && record.allowedForProduction) {
        add(
          severity: SourceAccessSeverity.blocker,
          type: 'fixture_only_marked_production',
          sourceId: record.sourceId,
          file: registryPath,
          message:
              'Fixture-tested source is marked allowed_for_production=true.',
          suggestedFix:
              'Keep fixture-tested sources non-production until access, license, and implementation reviews are recorded.',
        );
      }
      if (record.isProductionReady && !record.allowedForProduction) {
        add(
          severity: SourceAccessSeverity.blocker,
          type: 'production_status_contract_mismatch',
          sourceId: record.sourceId,
          file: registryPath,
          message:
              'Production-ready status conflicts with allowed_for_production=false.',
        );
      }
    }

    for (final ref in references) {
      final record = contract[ref.sourceId];
      if (record == null) {
        add(
          severity: ref.isDoc
              ? SourceAccessSeverity.warn
              : SourceAccessSeverity.blocker,
          type: 'unknown_source_id',
          sourceId: ref.sourceId,
          file: ref.file,
          message: 'Observed source ID is missing from the access registry.',
          suggestedFix:
              'Add an explicit registry record or correct the source reference.',
        );
        continue;
      }

      if (ref.usageType == SourceUsageType.production &&
          !record.allowedForProduction) {
        add(
          severity: SourceAccessSeverity.blocker,
          type: 'source_not_allowed_for_production',
          sourceId: ref.sourceId,
          file: ref.file,
          message:
              'Usage claims production but the registry does not allow production use.',
        );
      }
      if (ref.usageType == SourceUsageType.mechanismEvidence &&
          !record.canSupportMechanismEvidenceAlone) {
        add(
          severity: SourceAccessSeverity.blocker,
          type: 'unsupported_mechanism_evidence_role',
          sourceId: ref.sourceId,
          file: ref.file,
          message:
              'Source cannot support mechanism evidence alone under the registry contract.',
        );
      }
      if (ref.usageType == SourceUsageType.sourceQuality &&
          !record.canSupportSourceQualityScoring) {
        add(
          severity: SourceAccessSeverity.warn,
          type: 'unsupported_source_quality_role',
          sourceId: ref.sourceId,
          file: ref.file,
          message:
              'Source-quality usage needs review because the source is not enabled for source-quality scoring.',
        );
      }
      if (record.requiresApiKey) {
        add(
          severity: SourceAccessSeverity.warn,
          type: 'api_key_required',
          sourceId: ref.sourceId,
          file: ref.file,
          message:
              'Source requires an API key for live access; no secret may be committed.',
        );
      }
      if (record.requiresAccount) {
        add(
          severity: SourceAccessSeverity.warn,
          type: 'account_required',
          sourceId: ref.sourceId,
          file: ref.file,
          message:
              'Source requires an account or accepted access terms for live access.',
        );
      }
      if (record.licenseReviewNeeded || record.legalReviewNeeded) {
        add(
          severity: SourceAccessSeverity.warn,
          type: 'license_or_legal_review_needed',
          sourceId: ref.sourceId,
          file: ref.file,
          message:
              'License or legal review is required before any production use.',
        );
      }
      if (record.hasUnknownAccess) {
        add(
          severity: strictMode
              ? SourceAccessSeverity.blocker
              : SourceAccessSeverity.warn,
          type: 'unknown_access_status',
          sourceId: ref.sourceId,
          file: ref.file,
          message: 'Source has unknown access or implementation status.',
        );
      }
      if (record.isDeprecated) {
        add(
          severity: ref.usageType == SourceUsageType.production
              ? SourceAccessSeverity.blocker
              : SourceAccessSeverity.warn,
          type: 'deprecated_source',
          sourceId: ref.sourceId,
          file: ref.file,
          message: 'Deprecated source reference requires replacement.',
        );
      }
    }

    findings.sort((a, b) {
      int rank(String severity) => switch (severity) {
            SourceAccessSeverity.blocker => 0,
            SourceAccessSeverity.warn => 1,
            _ => 2,
          };
      final bySeverity = rank(a.severity).compareTo(rank(b.severity));
      if (bySeverity != 0) return bySeverity;
      final byType = a.findingType.compareTo(b.findingType);
      if (byType != 0) return byType;
      final bySource = a.sourceId.compareTo(b.sourceId);
      if (bySource != 0) return bySource;
      return a.file.compareTo(b.file);
    });

    final counts = <String, int>{'info': 0, 'warn': 0, 'blocker': 0};
    for (final finding in findings) {
      counts[finding.severity] = (counts[finding.severity] ?? 0) + 1;
    }
    return SourceAccessContractReport(
      generatedAt: deterministicTimestamp,
      registryPath: registryPath,
      sourceCount: contract.sourceCount,
      referenceCount: references.length,
      counts: counts,
      pass: (counts[SourceAccessSeverity.blocker] ?? 0) == 0,
      findings: List.unmodifiable(findings),
      safetyBoundary: contract.safetyBoundary.isEmpty
          ? RuleExplanation.defaultSafetyBoundary
          : contract.safetyBoundary,
      notClinicallyCalibrated: true,
      limitations: limitations,
    );
  }
}

String encodeSourceAccessReport(SourceAccessContractReport report) =>
    const JsonEncoder.withIndent('  ').convert(report.toJson());

String renderSourceAccessMarkdown(SourceAccessContractReport report) {
  final b = StringBuffer()
    ..writeln('# Source Access Contract Report')
    ..writeln()
    ..writeln('Source governance / release hygiene only. Not legal advice, '
        'not license clearance, and not clinical validation.')
    ..writeln()
    ..writeln('- Registry: `${report.registryPath}`')
    ..writeln('- Sources: ${report.sourceCount}')
    ..writeln('- Observed references: ${report.referenceCount}')
    ..writeln('- Pass: `${report.pass}`')
    ..writeln('- Findings: blocker=${report.counts['blocker'] ?? 0}, '
        'warn=${report.counts['warn'] ?? 0}, '
        'info=${report.counts['info'] ?? 0}')
    ..writeln()
    ..writeln('## Findings')
    ..writeln();
  if (report.findings.isEmpty) {
    b.writeln('No findings.');
  } else {
    for (final finding in report.findings) {
      b.writeln('- **${finding.severity.toUpperCase()}** '
          '`${finding.findingType}` `${finding.sourceId}` '
          'in `${finding.file}`: ${finding.message}');
    }
  }
  b
    ..writeln()
    ..writeln('## Limitations')
    ..writeln();
  for (final limitation in report.limitations) {
    b.writeln('- $limitation');
  }
  b
    ..writeln()
    ..writeln('## Safety Boundary')
    ..writeln()
    ..writeln(report.safetyBoundary);
  return b.toString();
}
