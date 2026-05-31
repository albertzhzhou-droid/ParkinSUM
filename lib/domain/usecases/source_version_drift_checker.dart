/// P3 — SourceVersionDriftChecker.
///
/// Educational/research prototype only. Pure, deterministic provenance /
/// release-hygiene checker over injectable `SourceVersionRecord`s (file/artifact
/// I/O lives in the CLI tool). It detects missing source/version/date metadata,
/// stale generated artifacts, bibliography/registry mismatches,
/// fixture-vs-production status inconsistencies, deprecated-source usage, and
/// assumption-registry drift.
///
/// It does **NOT** fetch or update live source data, is **NOT** legal/license
/// clearance, **NOT** clinical validation or calibration, and does **NOT** prove
/// medical correctness. It only reports drift from the local files available.
/// No PHI / patient / subject / encounter semantics.
library;

import 'dart:convert';

import '../entities/source_version_drift.dart';

class SourceVersionDriftChecker {
  const SourceVersionDriftChecker();

  static const String _safetyBoundary =
      'Provenance / release-hygiene drift checking only. It does not fetch or '
      'update live sources, is not legal/license clearance, not clinical '
      'validation, not clinically calibrated, and does not prove medical '
      'correctness. It only detects metadata/version drift from local files.';

  static const List<String> _limitations = [
    'Detects metadata/version drift from local files only; no network fetch.',
    'Not legal/license clearance; not clinical validation; not clinically calibrated.',
    'Optional build artifacts that are absent are WARN, never fabricated as present.',
    'Conservative documentation-claim checks only (no broad NLP); may miss subtle drift.',
    'Deterministic: staleness is computed against a supplied reference timestamp.',
  ];

  // WARN finding types that strict mode escalates to BLOCKER.
  static const Set<String> _strictEscalatable = {
    SourceVersionDriftFindingType.missingPolicyReviewDate,
    SourceVersionDriftFindingType.unknownImplementationStatus,
    SourceVersionDriftFindingType.bibliographyMissing,
    SourceVersionDriftFindingType.sourceRegistryMismatch,
    SourceVersionDriftFindingType.generatedArtifactStale,
    SourceVersionDriftFindingType.assumptionRegistryUnreferenced,
  };

  SourceVersionDriftReport check(
    List<SourceVersionRecord> records,
    SourceVersionDriftConfig config,
  ) {
    final findings = <SourceVersionDriftFinding>[];

    // Indexes for cross-record checks.
    final bibliographyIds = <String>{
      for (final r in records)
        if (r.recordType == SourceVersionRecordType.bibliographyEntry &&
            r.sourceId.isNotEmpty)
          r.sourceId,
    };
    final registryById = <String, SourceVersionRecord>{
      for (final r in records)
        if (r.recordType == SourceVersionRecordType.sourceAccessRegistry &&
            r.sourceId.isNotEmpty)
          r.sourceId: r,
    };
    final registryLoaded = registryById.isNotEmpty;

    final refTime = _parseDate(config.referenceTimestamp);

    SourceVersionDriftFinding f(
      String baseSeverity,
      String type,
      SourceVersionRecord r,
      String message, {
      String fix = '',
    }) {
      final severity = (config.strictMode &&
              baseSeverity == SourceVersionDriftSeverity.warn &&
              _strictEscalatable.contains(type))
          ? SourceVersionDriftSeverity.blocker
          : baseSeverity;
      return SourceVersionDriftFinding(
        severity: severity,
        findingType: type,
        sourceId: r.sourceId,
        recordId: r.recordId,
        file: r.file,
        message: message,
        suggestedFix: fix,
        safetyBoundary: _safetyBoundary,
      );
    }

    for (final r in records) {
      // A — missing source id.
      const idRequired = {
        SourceVersionRecordType.sourceAccessRegistry,
        SourceVersionRecordType.sourceDocument,
        SourceVersionRecordType.modelAssumption,
        SourceVersionRecordType.bibliographyEntry,
        SourceVersionRecordType.sourceAdapter,
      };
      if (idRequired.contains(r.recordType) && r.sourceId.isEmpty) {
        final sev =
            (r.recordType == SourceVersionRecordType.sourceAccessRegistry ||
                    r.recordType == SourceVersionRecordType.sourceDocument)
                ? SourceVersionDriftSeverity.blocker
                : SourceVersionDriftSeverity.warn;
        findings.add(f(sev, SourceVersionDriftFindingType.missingSourceId, r,
            'Record requires a source id but none is present.',
            fix: 'Add an explicit sourceId to this record.'));
        // Without a source id the cross-checks below are not meaningful.
        continue;
      }

      // B — required dates / version per record type.
      switch (r.recordType) {
        case SourceVersionRecordType.sourceAccessRegistry:
          if (r.lastPolicyReviewed.isEmpty) {
            findings.add(f(
                SourceVersionDriftSeverity.warn,
                SourceVersionDriftFindingType.missingPolicyReviewDate,
                r,
                'Source-access registry record lacks last_policy_reviewed.',
                fix: 'Record the date this source policy was last reviewed.'));
          }
          break;
        case SourceVersionRecordType.sourceDocument:
          if (r.effectiveDate.isEmpty &&
              r.version.isEmpty &&
              r.limitations.isEmpty) {
            findings.add(f(
                SourceVersionDriftSeverity.warn,
                SourceVersionDriftFindingType.missingEffectiveDate,
                r,
                'Source document lacks an effective date/version and has no '
                'stated limitation.',
                fix:
                    'Add effectiveDate/version or an explicit limitation note.'));
          }
          break;
        case SourceVersionRecordType.modelAssumption:
          // I — assumption registry drift.
          if (r.bibliographyRefs.isEmpty &&
              r.documentationRefs.isEmpty &&
              r.sourceRefs.isEmpty &&
              r.sourceId.isEmpty) {
            findings.add(f(
                SourceVersionDriftSeverity.warn,
                SourceVersionDriftFindingType.assumptionRegistryUnreferenced,
                r,
                'Model assumption has no bibliography/documentation/source '
                'reference.',
                fix: 'Link the assumption to a bibliography or source ref.'));
          }
          break;
        default:
          break;
      }

      // C/D — generated artifacts.
      if (r.recordType == SourceVersionRecordType.generatedArtifact) {
        if (!r.exists) {
          // Missing optional artifacts are WARN, never a fabricated success.
          findings.add(f(
              SourceVersionDriftSeverity.warn,
              SourceVersionDriftFindingType.generatedArtifactMissing,
              r,
              'Expected generated artifact is missing (not fabricated).',
              fix: 'Regenerate the artifact, or remove the expectation.'));
        } else if (r.generatedAt.isEmpty) {
          findings.add(f(
              SourceVersionDriftSeverity.warn,
              SourceVersionDriftFindingType.missingVersion,
              r,
              'Generated artifact is present but has no generated_at timestamp.',
              fix: 'Emit a deterministic generated_at in the artifact.'));
        } else if (refTime != null) {
          final gen = _parseDate(r.generatedAt);
          if (gen != null) {
            final ageDays = refTime.difference(gen).inDays;
            if (ageDays > config.stalenessThresholdDays) {
              findings.add(f(
                  SourceVersionDriftSeverity.warn,
                  SourceVersionDriftFindingType.generatedArtifactStale,
                  r,
                  'Generated artifact is stale ($ageDays days old; threshold '
                  '${config.stalenessThresholdDays}).',
                  fix: 'Regenerate the artifact from current inputs.'));
            }
          }
        }
        continue;
      }

      // E — bibliography linkage for mechanism/source roles.
      const needsBibliography = {
        SourceVersionRecordType.modelAssumption,
        SourceVersionRecordType.sourceAdapter,
      };
      // A source id counts as bibliography-linked when it appears in the
      // bibliography token set, OR is catalogued in the source-access registry
      // (the machine-readable source catalog, which itself carries
      // bibliography_refs / numbered citations), OR carries its own
      // bibliographyRefs.
      if (needsBibliography.contains(r.recordType) &&
          r.sourceId.isNotEmpty &&
          !bibliographyIds.contains(r.sourceId) &&
          !registryById.containsKey(r.sourceId) &&
          r.bibliographyRefs.isEmpty) {
        findings.add(f(
            SourceVersionDriftSeverity.warn,
            SourceVersionDriftFindingType.bibliographyMissing,
            r,
            'Source id is used but has no bibliography entry, registry record, '
            'or bibliography reference.',
            fix: 'Add a Bibliographies.md entry, a registry record, or a '
                'bibliographyRef.'));
      }

      // F — source-access registry membership.
      const needsRegistry = {
        SourceVersionRecordType.modelAssumption,
        SourceVersionRecordType.sourceAdapter,
        SourceVersionRecordType.sourceDocument,
      };
      if (registryLoaded &&
          needsRegistry.contains(r.recordType) &&
          r.sourceId.isNotEmpty &&
          !registryById.containsKey(r.sourceId)) {
        findings.add(f(
            SourceVersionDriftSeverity.warn,
            SourceVersionDriftFindingType.sourceRegistryMismatch,
            r,
            'Source id is referenced but absent from the source-access '
            'registry.',
            fix: 'Add the source to config/source_access_registry.json.'));
      }

      // G — fixture-vs-production status mismatch.
      if (r.claimsProductionReady) {
        final reg = registryById[r.sourceId];
        if (reg != null && reg.isFixtureOnly) {
          findings.add(f(
              SourceVersionDriftSeverity.blocker,
              SourceVersionDriftFindingType.fixtureStatusMismatch,
              r,
              'Record claims production-ready but the registry marks this '
              'source fixture-only.',
              fix: 'Do not claim production readiness for a fixture-only '
                  'source.'));
        } else if (reg == null && registryLoaded) {
          findings.add(f(
              SourceVersionDriftSeverity.blocker,
              SourceVersionDriftFindingType.fixtureStatusMismatch,
              r,
              'Record claims production-ready but no registry record supports '
              'that status.',
              fix: 'Record and review the source before claiming production '
                  'readiness.'));
        }
      }

      // J — documentation-claim mismatch (conservative).
      if (r.metadata['doc_says_production'] == 'true') {
        final reg = registryById[r.sourceId];
        if (reg != null && reg.isFixtureOnly) {
          findings.add(f(
              SourceVersionDriftSeverity.blocker,
              SourceVersionDriftFindingType.documentationClaimMismatch,
              r,
              'Documentation implies production readiness but the registry '
              'marks this source fixture-only.',
              fix: 'Align the documentation with the fixture-only status.'));
        }
      }

      // Unknown implementation status. Only records that are expected to DECLARE
      // a status are checked (the registry is the authoritative status holder;
      // source adapters describe wiring, not status, so they are excluded to
      // avoid noise).
      const statusBearing = {
        SourceVersionRecordType.sourceAccessRegistry,
        SourceVersionRecordType.sourceDocument,
      };
      if (statusBearing.contains(r.recordType) && r.hasUnknownStatus) {
        findings.add(f(
            SourceVersionDriftSeverity.warn,
            SourceVersionDriftFindingType.unknownImplementationStatus,
            r,
            'Implementation status is unknown/empty.',
            fix: 'Set an explicit implementation_status.'));
      }

      // H — deprecated source used.
      if (r.isDeprecated) {
        final mechanism = r.isMechanismRole;
        findings.add(f(
            mechanism
                ? SourceVersionDriftSeverity.blocker
                : SourceVersionDriftSeverity.warn,
            SourceVersionDriftFindingType.deprecatedSourceUsed,
            r,
            'Source is marked deprecated but is still referenced.',
            fix: 'Replace or retire the deprecated source reference.'));
      }
    }

    final counts = <String, int>{
      SourceVersionDriftSeverity.info: 0,
      SourceVersionDriftSeverity.warn: 0,
      SourceVersionDriftSeverity.blocker: 0,
    };
    for (final fnd in findings) {
      counts[fnd.severity] = (counts[fnd.severity] ?? 0) + 1;
    }

    return SourceVersionDriftReport(
      generatedAt: config.referenceTimestamp.isEmpty
          ? 'synthetic-demo'
          : config.referenceTimestamp,
      recordCount: records.length,
      findingCounts: counts,
      pass: (counts[SourceVersionDriftSeverity.blocker] ?? 0) == 0,
      records: records,
      findings: findings,
      safetyBoundary: _safetyBoundary,
      notClinicallyCalibrated: true,
      limitations: _limitations,
    );
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    // Accept full ISO-8601 or a bare YYYY-MM-DD date.
    final v = s.length == 10 ? '${s}T00:00:00Z' : s;
    return DateTime.tryParse(v)?.toUtc();
  }
}

/// Deterministic JSON encoder.
String encodeSourceVersionDrift(SourceVersionDriftReport r) =>
    const JsonEncoder.withIndent('  ').convert(r.toJson());

/// Deterministic markdown renderer.
String renderSourceVersionDriftMarkdown(SourceVersionDriftReport r) {
  final b = StringBuffer()
    ..writeln('# ParkinSUM Source Version Drift')
    ..writeln()
    ..writeln('Educational/research prototype. **Provenance / release-hygiene '
        'drift checking only — does not fetch or update live sources, is not '
        'legal/license clearance, not clinical validation, not clinically '
        'calibrated, and does not prove medical correctness.**')
    ..writeln()
    ..writeln('- records: ${r.recordCount}')
    ..writeln('- info: ${r.findingCounts['info'] ?? 0} · '
        'warn: ${r.findingCounts['warn'] ?? 0} · '
        'blocker: ${r.blockerCount}')
    ..writeln('- pass (0 blocker): ${r.pass}')
    ..writeln()
    ..writeln('| severity | type | source_id | file | message |')
    ..writeln('| --- | --- | --- | --- | --- |');
  for (final f in r.findings) {
    b.writeln('| ${f.severity} | ${f.findingType} | ${f.sourceId} | '
        '${f.file} | ${f.message} |');
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
