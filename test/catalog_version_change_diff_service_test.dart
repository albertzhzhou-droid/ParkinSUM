import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/catalog_version_change_diff.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_version_change_diff_service.dart';

void main() {
  const service = CatalogVersionChangeDiffService();

  test('same source identity is unchanged and a new code is added', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[('A', 'Alpha')]);
    final current = snapshot('2026-02', 2, <(String, String)>[
      ('A', 'Alpha'),
      ('B', 'Beta'),
    ]);

    final diff = service.compare(
      previous: previous,
      current: current,
      mappingEvidence: const <CatalogMappingEvidence>[],
    );

    expect(diff.entries.map((entry) => entry.kind), <CatalogVersionChangeKind>[
      CatalogVersionChangeKind.unchanged,
      CatalogVersionChangeKind.added,
    ]);
    expect(diff.entries.first.requiresOwnerDecision, isFalse);
    expect(diff.toJson()['signature_status'], 'not_signed');
    expect(diff.toJson()['application_status'], 'preview_only');
  });

  test('JSON capture import verifies digests and rejects unknown fields', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[
      ('OLD', 'Old display'),
    ]);
    final current = snapshot('2026-02', 2, <(String, String)>[
      ('NEW', 'New display'),
    ]);
    final transition = evidence(
      'OLD',
      <String>['NEW'],
      CatalogTransitionRelationship.replacedBy,
      previous,
      current,
    );

    final diff = service.compareJsonCaptures(
      previousCaptureJson: jsonEncode(previous.toJson()),
      currentCaptureJson: jsonEncode(current.toJson()),
      mappingEvidenceJson: jsonEncode(<Map<String, Object?>>[
        transition.toJson(),
      ]),
    );
    expect(diff.entries.single.kind, CatalogVersionChangeKind.remapped);
    expect(diff.entries.single.holdBeforeApplying, isTrue);

    final tamperedCapture = <String, Object?>{
      ...previous.toJson(),
      'record_set_sha256': List<String>.filled(64, '0').join(),
    };
    expect(
      () => service.compareJsonCaptures(
        previousCaptureJson: jsonEncode(tamperedCapture),
        currentCaptureJson: jsonEncode(current.toJson()),
        mappingEvidenceJson: '[]',
      ),
      throwsFormatException,
    );

    final unknownFieldCapture = <String, Object?>{
      ...previous.toJson(),
      'patient_id': 'must-not-be-accepted',
    };
    expect(
      () => service.compareJsonCaptures(
        previousCaptureJson: jsonEncode(unknownFieldCapture),
        currentCaptureJson: jsonEncode(current.toJson()),
        mappingEvidenceJson: '[]',
      ),
      throwsFormatException,
    );
  });

  test('explicit reviewed one-to-one replacement remains owner-gated', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[
      ('OLD', 'Old display'),
    ]);
    final current = snapshot('2026-02', 2, <(String, String)>[
      ('NEW', 'New display'),
    ]);
    final diff = service.compare(
      previous: previous,
      current: current,
      mappingEvidence: <CatalogMappingEvidence>[
        evidence(
          'OLD',
          <String>['NEW'],
          CatalogTransitionRelationship.replacedBy,
          previous,
          current,
        ),
      ],
    );

    final entry = diff.entries.single;
    expect(entry.kind, CatalogVersionChangeKind.remapped);
    expect(entry.previousConcept?.code, 'OLD');
    expect(entry.previousConcept?.display, 'Old display');
    expect(entry.candidates.single.code, 'NEW');
    expect(entry.requiresOwnerDecision, isTrue);
    expect(entry.holdBeforeApplying, isTrue);
  });

  test('reviewed retirement is distinct from an absent unresolved code', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[
      ('RETIRED', 'Retired'),
      ('MISSING', 'No retirement evidence'),
    ]);
    final current = snapshot('2026-02', 2, const <(String, String)>[]);
    final diff = service.compare(
      previous: previous,
      current: current,
      mappingEvidence: <CatalogMappingEvidence>[
        evidence(
          'RETIRED',
          const <String>[],
          CatalogTransitionRelationship.retired,
          previous,
          current,
        ),
      ],
    );

    final retired = diff.entries.singleWhere(
      (entry) => entry.previousConcept?.code == 'RETIRED',
    );
    final missing = diff.entries.singleWhere(
      (entry) => entry.previousConcept?.code == 'MISSING',
    );
    expect(retired.kind, CatalogVersionChangeKind.deprecated);
    expect(missing.kind, CatalogVersionChangeKind.unresolved);
    expect(missing.reasons, contains('no_explicit_mapping_evidence'));
  });

  test(
    'explicit one-to-many relationship is shown as a split, not applied',
    () {
      final previous = snapshot('2026-01', 1, <(String, String)>[
        ('OLD', 'Combined concept'),
      ]);
      final current = snapshot('2026-02', 2, <(String, String)>[
        ('PART-A', 'Part A'),
        ('PART-B', 'Part B'),
      ]);
      final diff = service.compare(
        previous: previous,
        current: current,
        mappingEvidence: <CatalogMappingEvidence>[
          evidence(
            'OLD',
            <String>['PART-B', 'PART-A'],
            CatalogTransitionRelationship.splitInto,
            previous,
            current,
          ),
        ],
      );

      expect(diff.entries.single.kind, CatalogVersionChangeKind.split);
      expect(diff.entries.single.candidates.map((item) => item.code), <String>[
        'PART-A',
        'PART-B',
      ]);
      expect(diff.entries.single.holdBeforeApplying, isTrue);
    },
  );

  test('many-to-one merge requires matching evidence from both old codes', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[
      ('OLD-A', 'Old A'),
      ('OLD-B', 'Old B'),
    ]);
    final current = snapshot('2026-02', 2, <(String, String)>[
      ('NEW', 'New merged concept'),
    ]);
    final diff = service.compare(
      previous: previous,
      current: current,
      mappingEvidence: <CatalogMappingEvidence>[
        evidence(
          'OLD-A',
          <String>['NEW'],
          CatalogTransitionRelationship.mergedInto,
          previous,
          current,
          evidenceId: 'merge-a',
        ),
        evidence(
          'OLD-B',
          <String>['NEW'],
          CatalogTransitionRelationship.mergedInto,
          previous,
          current,
          evidenceId: 'merge-b',
        ),
      ],
    );

    expect(
      diff.entries.map((entry) => entry.kind),
      everyElement(CatalogVersionChangeKind.merged),
    );
    expect(diff.entries.every((entry) => entry.holdBeforeApplying), isTrue);
  });

  test('multiple candidate targets remain ambiguous', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[
      ('OLD', 'Medication name'),
    ]);
    final current = snapshot('2026-02', 2, <(String, String)>[
      ('A', 'Medication name A'),
      ('B', 'Medication name B'),
    ]);
    final diff = service.compare(
      previous: previous,
      current: current,
      mappingEvidence: <CatalogMappingEvidence>[
        evidence(
          'OLD',
          <String>['A', 'B'],
          CatalogTransitionRelationship.candidateSet,
          previous,
          current,
        ),
      ],
    );

    expect(diff.entries.single.kind, CatalogVersionChangeKind.ambiguous);
    expect(diff.entries.single.currentConcept, isNull);
    expect(diff.entries.single.requiresOwnerDecision, isTrue);
  });

  test('similar display names never create a mapping', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[
      ('OLD', 'levodopa tablet'),
    ]);
    final current = snapshot('2026-02', 2, <(String, String)>[
      ('NEW', 'levodopa tablets'),
    ]);
    final diff = service.compare(
      previous: previous,
      current: current,
      mappingEvidence: const <CatalogMappingEvidence>[],
    );

    final old = diff.entries.singleWhere(
      (entry) => entry.previousConcept != null,
    );
    expect(old.kind, CatalogVersionChangeKind.unresolved);
    expect(old.candidates, isEmpty);
    expect(
      diff.entries.any((entry) => entry.kind == CatalogVersionChangeKind.added),
      isTrue,
    );
  });

  test('unreviewed, stale, or unlicensed evidence stays unresolved', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[('OLD', 'Old')]);
    final current = snapshot('2026-02', 2, <(String, String)>[('NEW', 'New')]);
    final unreviewed = evidence(
      'OLD',
      <String>['NEW'],
      CatalogTransitionRelationship.replacedBy,
      previous,
      current,
      review: CatalogMappingEvidenceReview.unreviewed,
    );
    final stale = evidence(
      'OLD',
      <String>['NEW'],
      CatalogTransitionRelationship.replacedBy,
      previous,
      current,
      evidenceId: 'stale',
      previousDigest: digest('stale previous'),
    );
    final unlicensed = evidence(
      'OLD',
      <String>['NEW'],
      CatalogTransitionRelationship.replacedBy,
      previous,
      current,
      evidenceId: 'unlicensed',
      license: CatalogMappingEvidenceLicense.unknown,
    );

    for (final item in <CatalogMappingEvidence>[
      unreviewed,
      stale,
      unlicensed,
    ]) {
      final result = service.compare(
        previous: previous,
        current: current,
        mappingEvidence: <CatalogMappingEvidence>[item],
      );
      expect(result.entries.single.kind, CatalogVersionChangeKind.unresolved);
      expect(result.entries.single.holdBeforeApplying, isTrue);
    }
  });

  test('same code with changed display is held without explicit evidence', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[
      ('A', 'Old display'),
    ]);
    final current = snapshot('2026-02', 2, <(String, String)>[
      ('A', 'New display'),
    ]);
    final diff = service.compare(
      previous: previous,
      current: current,
      mappingEvidence: const <CatalogMappingEvidence>[],
    );

    expect(diff.entries.single.kind, CatalogVersionChangeKind.unresolved);
    expect(diff.entries.single.candidates.single.display, 'New display');
    expect(
      diff.entries.single.reasons,
      contains('same_code_display_changed_without_mapping_evidence'),
    );
  });

  test('record ordering does not change snapshot or diff digest', () {
    final previous = snapshot('2026-01', 1, <(String, String)>[
      ('B', 'Beta'),
      ('A', 'Alpha'),
    ]);
    final previousReordered = snapshot('2026-01', 1, <(String, String)>[
      ('A', 'Alpha'),
      ('B', 'Beta'),
    ]);
    final current = snapshot('2026-02', 2, <(String, String)>[
      ('B', 'Beta'),
      ('A', 'Alpha'),
    ]);
    final currentReordered = snapshot('2026-02', 2, <(String, String)>[
      ('A', 'Alpha'),
      ('B', 'Beta'),
    ]);

    final first = service.compare(
      previous: previous,
      current: current,
      mappingEvidence: const <CatalogMappingEvidence>[],
    );
    final second = service.compare(
      previous: previousReordered,
      current: currentReordered,
      mappingEvidence: const <CatalogMappingEvidence>[],
    );

    expect(previous.recordSetSha256, previousReordered.recordSetSha256);
    expect(first.sha256Digest, second.sha256Digest);
  });

  test('stale release ordering and cross-catalog comparison are rejected', () {
    final previous = snapshot('2026-02', 2, <(String, String)>[('A', 'Alpha')]);
    final older = snapshot('2026-01', 1, <(String, String)>[('A', 'Alpha')]);
    expect(
      () => service.compare(
        previous: previous,
        current: older,
        mappingEvidence: const <CatalogMappingEvidence>[],
      ),
      throwsArgumentError,
    );
    expect(
      () => service.compare(
        previous: previous,
        current: CatalogReleaseSnapshot(
          catalogId: 'another-catalog',
          sourceSystem: 'RXNORM',
          jurisdiction: 'US',
          releaseId: '2026-03',
          releaseSequence: 3,
          concepts: <CatalogConceptIdentity>[concept('2026-03', 'A', 'Alpha')],
        ),
        mappingEvidence: const <CatalogMappingEvidence>[],
      ),
      throwsArgumentError,
    );
  });
}

CatalogReleaseSnapshot snapshot(
  String releaseId,
  int sequence,
  List<(String, String)> values,
) => CatalogReleaseSnapshot(
  catalogId: 'medication-catalog',
  sourceSystem: 'RXNORM',
  jurisdiction: 'US',
  releaseId: releaseId,
  releaseSequence: sequence,
  concepts: <CatalogConceptIdentity>[
    for (final (code, display) in values) concept(releaseId, code, display),
  ],
);

CatalogConceptIdentity concept(String releaseId, String code, String display) =>
    CatalogConceptIdentity(
      sourceSystem: 'RXNORM',
      jurisdiction: 'US',
      releaseId: releaseId,
      code: code,
      display: display,
    );

CatalogMappingEvidence evidence(
  String sourceCode,
  List<String> targets,
  CatalogTransitionRelationship relationship,
  CatalogReleaseSnapshot previous,
  CatalogReleaseSnapshot current, {
  String? evidenceId,
  String? previousDigest,
  CatalogMappingEvidenceReview review = CatalogMappingEvidenceReview.reviewed,
  CatalogMappingEvidenceLicense license =
      CatalogMappingEvidenceLicense.clearedForLocalReview,
}) => CatalogMappingEvidence(
  evidenceId: evidenceId ?? 'evidence-$sourceCode',
  sourceCode: sourceCode,
  targetCodes: targets,
  relationship: relationship,
  sourceReference: 'https://example.org/evidence/$sourceCode',
  evidenceSha256: digest('evidence-$sourceCode'),
  previousRecordSetSha256: previousDigest ?? previous.recordSetSha256,
  currentRecordSetSha256: current.recordSetSha256,
  review: review,
  license: license,
);

String digest(String value) =>
    value.codeUnits.map((_) => 'a').join().padRight(64, 'a').substring(0, 64);
