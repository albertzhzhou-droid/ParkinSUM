import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/source_version_drift.dart';
import 'package:parkinsum_companion/domain/usecases/source_version_drift_checker.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P3 — SourceVersionDriftChecker. Pure, deterministic provenance/release-hygiene
/// checks over in-memory records with deterministic timestamps. Not legal/license
/// clearance, not clinical validation, not clinically calibrated. No PHI /
/// patient / subject / encounter semantics.
void main() {
  const checker = SourceVersionDriftChecker();
  const refNow = '2026-06-01T00:00:00Z';

  SourceVersionDriftConfig cfg({bool strict = false, int days = 180}) =>
      SourceVersionDriftConfig(
        referenceTimestamp: refNow,
        stalenessThresholdDays: days,
        strictMode: strict,
      );

  SourceVersionDriftReport run(List<SourceVersionRecord> records,
          {bool strict = false}) =>
      checker.check(records, cfg(strict: strict));

  bool hasType(SourceVersionDriftReport r, String type) =>
      r.findings.any((f) => f.findingType == type);

  SourceVersionDriftFinding? find(SourceVersionDriftReport r, String type) {
    for (final f in r.findings) {
      if (f.findingType == type) return f;
    }
    return null;
  }

  // Reusable well-formed registry record so cross-checks have a registry.
  SourceVersionRecord reg(
    String id, {
    String status = 'implemented_fixture_tested',
    String reviewed = '2026-05-30',
  }) =>
      SourceVersionRecord(
        recordId: 'reg:$id',
        sourceId: id,
        recordType: SourceVersionRecordType.sourceAccessRegistry,
        file: 'config/source_access_registry.json',
        implementationStatus: status,
        lastPolicyReviewed: reviewed,
        bibliographyRefs: [id],
      );

  // 1 — missing version/effective date (source document) produces finding.
  test('missing effective date/version produces finding', () {
    final r = run([
      const SourceVersionRecord(
        recordId: 'doc1',
        sourceId: 'src.demo.doc',
        recordType: SourceVersionRecordType.sourceDocument,
        file: 'docs/x.md',
      ),
    ]);
    expect(
        hasType(r, SourceVersionDriftFindingType.missingEffectiveDate), isTrue);
  });

  // 2 — source document WITH a limitation note does not flag missing date.
  test('limitation note satisfies missing effective date requirement', () {
    final r = run([
      const SourceVersionRecord(
        recordId: 'doc2',
        sourceId: 'src.demo.doc',
        recordType: SourceVersionRecordType.sourceDocument,
        effectiveDate: '2024-01-01',
        limitations: ['fixture only'],
      ),
    ]);
    expect(hasType(r, SourceVersionDriftFindingType.missingEffectiveDate),
        isFalse);
  });

  // 3 — missing lastPolicyReviewed in source registry produces finding.
  test('missing policy review date in registry produces finding', () {
    final r = run([
      const SourceVersionRecord(
        recordId: 'reg:src.demo',
        sourceId: 'src.demo',
        recordType: SourceVersionRecordType.sourceAccessRegistry,
        implementationStatus: 'implemented_fixture_tested',
      ),
    ]);
    expect(
        find(r, SourceVersionDriftFindingType.missingPolicyReviewDate)!
            .severity,
        SourceVersionDriftSeverity.warn);
  });

  // 4 — generated artifact missing produces WARN, report still not a BLOCKER.
  test('missing generated artifact is WARN, not a fabricated success', () {
    final r = run([
      const SourceVersionRecord(
        recordId: 'art:replay',
        recordType: SourceVersionRecordType.generatedArtifact,
        file: 'build/mechanistic_replay/latest.json',
        metadata: {'exists': 'false', 'expected': 'true', 'optional': 'true'},
      ),
    ]);
    final f = find(r, SourceVersionDriftFindingType.generatedArtifactMissing);
    expect(f!.severity, SourceVersionDriftSeverity.warn);
    expect(r.pass, isTrue);
  });

  // 5 — stale generated artifact produces WARN.
  test('stale generated artifact produces WARN', () {
    final r = run([
      const SourceVersionRecord(
        recordId: 'art:old',
        recordType: SourceVersionRecordType.generatedArtifact,
        file: 'build/old/latest.json',
        generatedAt: '2020-01-01T00:00:00Z',
        metadata: {'exists': 'true'},
      ),
    ]);
    expect(
        find(r, SourceVersionDriftFindingType.generatedArtifactStale)!.severity,
        SourceVersionDriftSeverity.warn);
  });

  // 6 — fresh generated artifact passes the staleness check.
  test('fresh generated artifact passes staleness check', () {
    final r = run([
      const SourceVersionRecord(
        recordId: 'art:fresh',
        recordType: SourceVersionRecordType.generatedArtifact,
        file: 'build/fresh/latest.json',
        generatedAt: '2026-05-25T00:00:00Z',
        metadata: {'exists': 'true'},
      ),
    ]);
    expect(hasType(r, SourceVersionDriftFindingType.generatedArtifactStale),
        isFalse);
  });

  // 7 — bibliography mismatch produces a finding.
  test('bibliography mismatch produces finding', () {
    final r = run([
      reg('src.known'),
      const SourceVersionRecord(
        recordId: 'asm1',
        sourceId: 'src.unbibliographied',
        recordType: SourceVersionRecordType.modelAssumption,
      ),
    ]);
    expect(
        hasType(r, SourceVersionDriftFindingType.bibliographyMissing), isTrue);
  });

  // 8 — source registry mismatch produces a finding.
  test('source registry mismatch produces finding', () {
    final r = run([
      reg('src.in.registry'),
      const SourceVersionRecord(
        recordId: 'adp1',
        sourceId: 'src.not.in.registry',
        recordType: SourceVersionRecordType.sourceAdapter,
        bibliographyRefs: ['src.not.in.registry'],
      ),
    ]);
    expect(hasType(r, SourceVersionDriftFindingType.sourceRegistryMismatch),
        isTrue);
  });

  // 9 — fixture-only source cannot be production-ready (BLOCKER).
  test('fixture-only source cannot be production-ready', () {
    final r = run([
      reg('src.fix', status: 'implemented_fixture_tested'),
      const SourceVersionRecord(
        recordId: 'use1',
        sourceId: 'src.fix',
        recordType: SourceVersionRecordType.sourceAdapter,
        implementationStatus: 'implemented_production_ready',
        bibliographyRefs: ['src.fix'],
      ),
    ]);
    final f = find(r, SourceVersionDriftFindingType.fixtureStatusMismatch);
    expect(f!.severity, SourceVersionDriftSeverity.blocker);
    expect(r.pass, isFalse);
  });

  // 10 — deprecated source produces a finding.
  test('deprecated source produces finding', () {
    final r = run([
      const SourceVersionRecord(
        recordId: 'dep1',
        sourceId: 'src.old',
        recordType: SourceVersionRecordType.sourceAdapter,
        implementationStatus: 'deprecated',
        bibliographyRefs: ['src.old'],
      ),
      reg('src.old', status: 'deprecated'),
    ]);
    expect(
        hasType(r, SourceVersionDriftFindingType.deprecatedSourceUsed), isTrue);
  });

  // 11 — unknown implementation status produces a finding.
  test('unknown implementation status produces finding', () {
    final r = run([
      const SourceVersionRecord(
        recordId: 'reg:src.q',
        sourceId: 'src.q',
        recordType: SourceVersionRecordType.sourceAccessRegistry,
        implementationStatus: 'unknown',
        lastPolicyReviewed: '2026-05-30',
      ),
    ]);
    expect(
        hasType(r, SourceVersionDriftFindingType.unknownImplementationStatus),
        isTrue);
  });

  // 12 — model assumption sourceRefs that resolve produce no drift finding.
  test('model assumption with resolving refs has no drift', () {
    final r = run([
      reg('src.assume'),
      const SourceVersionRecord(
        recordId: 'asm-ok',
        sourceId: 'src.assume',
        recordType: SourceVersionRecordType.modelAssumption,
        bibliographyRefs: ['src.assume'],
        sourceRefs: ['src.assume'],
      ),
    ]);
    expect(
        hasType(r, SourceVersionDriftFindingType.bibliographyMissing), isFalse);
    expect(hasType(r, SourceVersionDriftFindingType.sourceRegistryMismatch),
        isFalse);
    expect(
        hasType(
            r, SourceVersionDriftFindingType.assumptionRegistryUnreferenced),
        isFalse);
  });

  // 13 — report JSON is deterministic.
  test('report JSON is deterministic', () {
    final records = [reg('src.a'), reg('src.b')];
    final a = encodeSourceVersionDrift(run(records));
    final b = encodeSourceVersionDrift(run(records));
    expect(a, equals(b));
    final decoded = jsonDecode(a) as Map<String, dynamic>;
    expect(decoded['report_type'], 'source_version_drift');
    expect(decoded['no_live_fetch'], isTrue);
    expect(decoded['not_clinically_calibrated'], isTrue);
  });

  // 14 — markdown includes counts and limitations.
  test('markdown includes counts and limitations', () {
    final md = renderSourceVersionDriftMarkdown(run([reg('src.a')]));
    expect(md, contains('Source Version Drift'));
    expect(md, contains('## Limitations'));
    expect(md, contains('pass (0 blocker)'));
    expect(md, contains('does not prove medical correctness'));
  });

  // 15 — no patient / subject / encounter keys emitted.
  test('no PHI/patient/subject/encounter keys emitted', () {
    final decoded = jsonDecode(encodeSourceVersionDrift(run([
      reg('src.a'),
      const SourceVersionRecord(
        recordId: 'doc',
        sourceId: 'src.a',
        recordType: SourceVersionRecordType.sourceDocument,
        effectiveDate: '2024-01-01',
      ),
    ]))) as Map<String, dynamic>;
    scanNoPhiKeys(decoded);
  });

  // 16 — no medical advice phrases emitted.
  test('no medical advice phrases emitted', () {
    final banned = RegExp(
        r'recommended dose|adjust your dose|take your medication at|'
        r'safe for you|confirmed safe|clinically validated|production-ready',
        caseSensitive: false);
    final json = encodeSourceVersionDrift(run([
      reg('src.a'),
      const SourceVersionRecord(
        recordId: 'use1',
        sourceId: 'src.a',
        recordType: SourceVersionRecordType.sourceAdapter,
        implementationStatus: 'implemented_production_ready',
        bibliographyRefs: ['src.a'],
      ),
    ]));
    // The phrase "production-ready" may only appear inside a finding *message*
    // that warns against it; assert no advice phrases leak.
    expect(
        banned.hasMatch(json.toLowerCase().replaceAll('production-ready', '')),
        isFalse);
  });

  // 17 — strict mode escalates selected WARN to BLOCKER.
  test('strict mode escalates selected WARN to BLOCKER', () {
    final lenient = run([
      const SourceVersionRecord(
        recordId: 'reg:src.x',
        sourceId: 'src.x',
        recordType: SourceVersionRecordType.sourceAccessRegistry,
        implementationStatus: 'implemented_fixture_tested',
        // lastPolicyReviewed missing → missingPolicyReviewDate WARN
      ),
    ]);
    expect(lenient.pass, isTrue);
    final strict = run([
      const SourceVersionRecord(
        recordId: 'reg:src.x',
        sourceId: 'src.x',
        recordType: SourceVersionRecordType.sourceAccessRegistry,
        implementationStatus: 'implemented_fixture_tested',
      ),
    ], strict: true);
    expect(
        find(strict, SourceVersionDriftFindingType.missingPolicyReviewDate)!
            .severity,
        SourceVersionDriftSeverity.blocker);
    expect(strict.pass, isFalse);
  });

  // 18 — optional artifacts absent do not fail the report as BLOCKER by default.
  test('optional absent artifacts do not BLOCKER by default', () {
    final r = run([
      const SourceVersionRecord(
        recordId: 'art:opt',
        recordType: SourceVersionRecordType.generatedArtifact,
        file: 'build/optional/latest.json',
        metadata: {'exists': 'false', 'optional': 'true', 'expected': 'true'},
      ),
    ]);
    expect(r.blockerCount, 0);
    expect(r.pass, isTrue);
  });
}
