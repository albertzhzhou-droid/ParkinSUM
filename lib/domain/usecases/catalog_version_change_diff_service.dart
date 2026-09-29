import 'dart:convert';

import '../entities/catalog_version_change_diff.dart';

/// Builds a fail-closed, offline catalog record-set comparison.
///
/// Only explicit source-code transition evidence can classify a changed
/// concept. Display-name similarity and transitive guesses are never used.
class CatalogVersionChangeDiffService {
  const CatalogVersionChangeDiffService();

  static const int maxCaptureJsonBytes = 2 * 1024 * 1024;
  static const int maxEvidenceJsonBytes = 1024 * 1024;

  /// Parses two exact [CatalogReleaseSnapshot.toJson] captures and optional
  /// [CatalogMappingEvidence.toJson] rows before comparing them offline.
  ///
  /// Exact-key checks and recomputed capture digests make this an import
  /// boundary, not a signature, source-authenticity, or completeness check.
  CatalogVersionChangeDiff compareJsonCaptures({
    required String previousCaptureJson,
    required String currentCaptureJson,
    required String mappingEvidenceJson,
  }) {
    final previous = _decodeSnapshot(previousCaptureJson);
    final current = _decodeSnapshot(currentCaptureJson);
    final mappingEvidence = _decodeMappingEvidence(mappingEvidenceJson);
    return compare(
      previous: previous,
      current: current,
      mappingEvidence: mappingEvidence,
    );
  }

  CatalogVersionChangeDiff compare({
    required CatalogReleaseSnapshot previous,
    required CatalogReleaseSnapshot current,
    required List<CatalogMappingEvidence> mappingEvidence,
  }) {
    if (previous.catalogId != current.catalogId ||
        previous.sourceSystem != current.sourceSystem ||
        previous.jurisdiction != current.jurisdiction) {
      throw ArgumentError(
        'Snapshots must identify the same catalog, source system, and jurisdiction.',
      );
    }
    if (current.releaseSequence <= previous.releaseSequence) {
      throw ArgumentError('Current release must follow the previous release.');
    }

    final previousByCode = <String, CatalogConceptIdentity>{
      for (final concept in previous.concepts) concept.code: concept,
    };
    final currentByCode = <String, CatalogConceptIdentity>{
      for (final concept in current.concepts) concept.code: concept,
    };
    final evidenceIds = <String>{};
    final evidenceBySource = <String, List<CatalogMappingEvidence>>{};
    for (final evidence in mappingEvidence) {
      if (!evidenceIds.add(evidence.evidenceId)) {
        throw ArgumentError('Duplicate mapping evidence id.');
      }
      if (!previousByCode.containsKey(evidence.sourceCode)) {
        throw ArgumentError(
          'Mapping evidence references an unknown source code.',
        );
      }
      for (final targetCode in evidence.targetCodes) {
        if (!currentByCode.containsKey(targetCode)) {
          throw ArgumentError(
            'Mapping evidence references an unknown target code.',
          );
        }
      }
      evidenceBySource
          .putIfAbsent(evidence.sourceCode, () => <CatalogMappingEvidence>[])
          .add(evidence);
    }

    final evidenceValidity = <String, List<String>>{
      for (final item in mappingEvidence)
        item.evidenceId: _evidenceProblems(
          item,
          previous: previous,
          current: current,
        ),
    };
    final mergedSourcesByTarget = <String, Set<String>>{};
    for (final item in mappingEvidence) {
      if (evidenceValidity[item.evidenceId]!.isEmpty &&
          item.relationship == CatalogTransitionRelationship.mergedInto &&
          item.targetCodes.length == 1) {
        mergedSourcesByTarget
            .putIfAbsent(item.targetCodes.single, () => <String>{})
            .add(item.sourceCode);
      }
    }

    final entries = <CatalogVersionChangeEntry>[];
    for (final source in previous.concepts) {
      final evidence = List<CatalogMappingEvidence>.of(
        evidenceBySource[source.code] ?? const <CatalogMappingEvidence>[],
      )..sort((left, right) => left.evidenceId.compareTo(right.evidenceId));
      final candidates = _candidateIdentities(evidence, currentByCode);
      final problems = <String>{
        for (final item in evidence) ...evidenceValidity[item.evidenceId]!,
      }.toList()..sort();

      if (evidence.isEmpty) {
        final sameCode = currentByCode[source.code];
        if (sameCode != null && source.display == sameCode.display) {
          entries.add(
            CatalogVersionChangeEntry(
              kind: CatalogVersionChangeKind.unchanged,
              previousConcept: source,
              currentConcept: sameCode,
              candidates: <CatalogConceptIdentity>[sameCode],
              evidence: evidence,
              reasons: const <String>['same_source_code_and_display'],
            ),
          );
        } else {
          entries.add(
            CatalogVersionChangeEntry(
              kind: CatalogVersionChangeKind.unresolved,
              previousConcept: source,
              currentConcept: null,
              candidates: sameCode == null
                  ? const <CatalogConceptIdentity>[]
                  : <CatalogConceptIdentity>[sameCode],
              evidence: evidence,
              reasons: <String>[
                sameCode == null
                    ? 'no_explicit_mapping_evidence'
                    : 'same_code_display_changed_without_mapping_evidence',
              ],
            ),
          );
        }
        continue;
      }

      if (problems.isNotEmpty) {
        entries.add(
          CatalogVersionChangeEntry(
            kind: CatalogVersionChangeKind.unresolved,
            previousConcept: source,
            currentConcept: null,
            candidates: candidates,
            evidence: evidence,
            reasons: problems,
          ),
        );
        continue;
      }

      final signatures = evidence.map(_transitionSignature).toSet();
      final targets =
          evidence.expand((item) => item.targetCodes).toSet().toList()..sort();
      if (signatures.length != 1) {
        entries.add(
          _entry(
            CatalogVersionChangeKind.ambiguous,
            source,
            candidates,
            evidence,
            const <String>['conflicting_mapping_evidence'],
          ),
        );
        continue;
      }

      final relationship = evidence.first.relationship;
      final CatalogVersionChangeKind kind;
      final List<String> reasons;
      switch (relationship) {
        case CatalogTransitionRelationship.retired:
          kind = CatalogVersionChangeKind.deprecated;
          reasons = const <String>['explicit_reviewed_retirement_evidence'];
        case CatalogTransitionRelationship.sameConcept:
          if (targets.length != 1) {
            kind = CatalogVersionChangeKind.ambiguous;
            reasons = const <String>['same_concept_has_multiple_targets'];
          } else {
            final target = currentByCode[targets.single]!;
            final unchanged = source.hasSameIdentifierAndDisplay(target);
            kind = unchanged
                ? CatalogVersionChangeKind.unchanged
                : CatalogVersionChangeKind.remapped;
            reasons = unchanged
                ? const <String>['explicit_same_concept_evidence']
                : const <String>[
                    'explicit_same_concept_code_or_display_change',
                  ];
          }
        case CatalogTransitionRelationship.replacedBy:
          if (targets.length == 1) {
            kind = CatalogVersionChangeKind.remapped;
            reasons = const <String>[
              'explicit_one_to_one_replacement_evidence',
            ];
          } else {
            kind = CatalogVersionChangeKind.ambiguous;
            reasons = const <String>[
              'replacement_evidence_has_multiple_targets',
            ];
          }
        case CatalogTransitionRelationship.splitInto:
          if (targets.length > 1) {
            kind = CatalogVersionChangeKind.split;
            reasons = const <String>['explicit_split_evidence'];
          } else {
            kind = CatalogVersionChangeKind.unresolved;
            reasons = const <String>['split_evidence_has_no_split_targets'];
          }
        case CatalogTransitionRelationship.mergedInto:
          if (targets.length == 1 &&
              (mergedSourcesByTarget[targets.single]?.length ?? 0) > 1) {
            kind = CatalogVersionChangeKind.merged;
            reasons = const <String>['explicit_many_to_one_merge_evidence'];
          } else {
            kind = CatalogVersionChangeKind.unresolved;
            reasons = const <String>[
              'merge_counterpart_not_present_in_capture',
            ];
          }
        case CatalogTransitionRelationship.candidateSet:
          if (targets.length > 1) {
            kind = CatalogVersionChangeKind.ambiguous;
            reasons = const <String>[
              'source_evidence_declares_multiple_candidates',
            ];
          } else {
            kind = CatalogVersionChangeKind.unresolved;
            reasons = const <String>[
              'candidate_only_evidence_is_not_a_mapping',
            ];
          }
      }
      entries.add(_entry(kind, source, candidates, evidence, reasons));
    }

    final targetCodesAlreadyAccountedFor = <String>{
      for (final entry in entries)
        ...entry.candidates.map((candidate) => candidate.code),
    };
    for (final target in current.concepts) {
      if (!previousByCode.containsKey(target.code) &&
          !targetCodesAlreadyAccountedFor.contains(target.code)) {
        entries.add(
          CatalogVersionChangeEntry(
            kind: CatalogVersionChangeKind.added,
            previousConcept: null,
            currentConcept: target,
            candidates: const <CatalogConceptIdentity>[],
            evidence: const <CatalogMappingEvidence>[],
            reasons: const <String>['new_code_in_supplied_current_capture'],
          ),
        );
      }
    }
    entries.sort(_compareEntries);

    return CatalogVersionChangeDiff(
      previousSnapshot: previous,
      currentSnapshot: current,
      entries: entries,
    );
  }

  CatalogVersionChangeEntry _entry(
    CatalogVersionChangeKind kind,
    CatalogConceptIdentity source,
    List<CatalogConceptIdentity> candidates,
    List<CatalogMappingEvidence> evidence,
    List<String> reasons,
  ) => CatalogVersionChangeEntry(
    kind: kind,
    previousConcept: source,
    currentConcept:
        kind == CatalogVersionChangeKind.unchanged && candidates.length == 1
        ? candidates.single
        : null,
    candidates: candidates,
    evidence: evidence,
    reasons: reasons,
  );

  List<String> _evidenceProblems(
    CatalogMappingEvidence evidence, {
    required CatalogReleaseSnapshot previous,
    required CatalogReleaseSnapshot current,
  }) {
    final problems = <String>[];
    if (evidence.previousRecordSetSha256 != previous.recordSetSha256 ||
        evidence.currentRecordSetSha256 != current.recordSetSha256) {
      problems.add('mapping_evidence_snapshot_binding_mismatch');
    }
    if (!_isSha256(evidence.evidenceSha256)) {
      problems.add('mapping_evidence_digest_invalid');
    }
    if (evidence.review != CatalogMappingEvidenceReview.reviewed) {
      problems.add('mapping_evidence_not_reviewed');
    }
    if (evidence.license !=
        CatalogMappingEvidenceLicense.clearedForLocalReview) {
      problems.add('mapping_evidence_license_not_cleared');
    }
    return problems;
  }

  List<CatalogConceptIdentity> _candidateIdentities(
    List<CatalogMappingEvidence> evidence,
    Map<String, CatalogConceptIdentity> currentByCode,
  ) {
    final codes = evidence.expand((item) => item.targetCodes).toSet().toList()
      ..sort();
    return <CatalogConceptIdentity>[
      for (final code in codes) currentByCode[code]!,
    ];
  }

  String _transitionSignature(CatalogMappingEvidence evidence) =>
      '${evidence.relationship.name}:${(evidence.targetCodes.toList()..sort()).join(',')}';

  int _compareEntries(
    CatalogVersionChangeEntry left,
    CatalogVersionChangeEntry right,
  ) {
    final leftCode = left.previousConcept?.code ?? left.currentConcept!.code;
    final rightCode = right.previousConcept?.code ?? right.currentConcept!.code;
    final codeOrder = leftCode.compareTo(rightCode);
    if (codeOrder != 0) return codeOrder;
    return left.kind.name.compareTo(right.kind.name);
  }

  bool _isSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  CatalogReleaseSnapshot _decodeSnapshot(String raw) {
    _checkJsonSize(raw, maxCaptureJsonBytes, 'catalog_capture_too_large');
    final json = _decodeObject(raw, 'catalog_capture_invalid_json');
    _requireExactKeys(json, const <String>{
      'catalog_id',
      'source_system',
      'jurisdiction',
      'release_id',
      'release_sequence',
      'concepts',
      'record_set_sha256',
    }, 'catalog_capture_fields_invalid');
    final rawConcepts = json['concepts'];
    if (rawConcepts is! List || rawConcepts.length > 100000) {
      throw const FormatException('catalog_capture_concepts_invalid');
    }
    final concepts = <CatalogConceptIdentity>[
      for (final rawConcept in rawConcepts) _decodeConcept(rawConcept),
    ];
    final snapshot = CatalogReleaseSnapshot(
      catalogId: _stringField(json, 'catalog_id'),
      sourceSystem: _stringField(json, 'source_system'),
      jurisdiction: _stringField(json, 'jurisdiction'),
      releaseId: _stringField(json, 'release_id'),
      releaseSequence: _integerField(json, 'release_sequence'),
      concepts: concepts,
    );
    if (_stringField(json, 'record_set_sha256') != snapshot.recordSetSha256) {
      throw const FormatException('catalog_capture_digest_mismatch');
    }
    return snapshot;
  }

  CatalogConceptIdentity _decodeConcept(Object? raw) {
    final json = _object(raw, 'catalog_concept_invalid');
    _requireExactKeys(json, const <String>{
      'source_system',
      'jurisdiction',
      'release_id',
      'code',
      'display',
    }, 'catalog_concept_fields_invalid');
    return CatalogConceptIdentity(
      sourceSystem: _stringField(json, 'source_system'),
      jurisdiction: _stringField(json, 'jurisdiction'),
      releaseId: _stringField(json, 'release_id'),
      code: _stringField(json, 'code'),
      display: _stringField(json, 'display'),
    );
  }

  List<CatalogMappingEvidence> _decodeMappingEvidence(String raw) {
    _checkJsonSize(raw, maxEvidenceJsonBytes, 'mapping_evidence_too_large');
    final decoded = _decodeValue(raw, 'mapping_evidence_invalid_json');
    if (decoded is! List || decoded.length > 100000) {
      throw const FormatException('mapping_evidence_rows_invalid');
    }
    return <CatalogMappingEvidence>[
      for (final rawEvidence in decoded) _decodeEvidence(rawEvidence),
    ];
  }

  CatalogMappingEvidence _decodeEvidence(Object? raw) {
    final json = _object(raw, 'mapping_evidence_row_invalid');
    _requireExactKeys(json, const <String>{
      'evidence_id',
      'source_code',
      'target_codes',
      'relationship',
      'source_reference',
      'evidence_sha256',
      'previous_record_set_sha256',
      'current_record_set_sha256',
      'review',
      'license',
    }, 'mapping_evidence_fields_invalid');
    final rawTargets = json['target_codes'];
    if (rawTargets is! List || rawTargets.any((value) => value is! String)) {
      throw const FormatException('mapping_evidence_targets_invalid');
    }
    return CatalogMappingEvidence(
      evidenceId: _stringField(json, 'evidence_id'),
      sourceCode: _stringField(json, 'source_code'),
      targetCodes: rawTargets.cast<String>(),
      relationship: _enumField(
        CatalogTransitionRelationship.values,
        _stringField(json, 'relationship'),
        'relationship',
      ),
      sourceReference: _stringField(json, 'source_reference'),
      evidenceSha256: _stringField(json, 'evidence_sha256'),
      previousRecordSetSha256: _stringField(json, 'previous_record_set_sha256'),
      currentRecordSetSha256: _stringField(json, 'current_record_set_sha256'),
      review: _enumField(
        CatalogMappingEvidenceReview.values,
        _stringField(json, 'review'),
        'review',
      ),
      license: _enumField(
        CatalogMappingEvidenceLicense.values,
        _stringField(json, 'license'),
        'license',
      ),
    );
  }

  Object? _decodeValue(String raw, String errorCode) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      throw FormatException(errorCode);
    }
  }

  Map<String, Object?> _decodeObject(String raw, String errorCode) {
    final value = _decodeValue(raw, errorCode);
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException(errorCode);
    }
    return value.cast<String, Object?>();
  }

  Map<String, Object?> _object(Object? value, String errorCode) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException(errorCode);
    }
    return value.cast<String, Object?>();
  }

  void _requireExactKeys(
    Map<String, Object?> value,
    Set<String> required,
    String errorCode,
  ) {
    if (value.length != required.length ||
        required.any((key) => !value.containsKey(key))) {
      throw FormatException(errorCode);
    }
  }

  String _stringField(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! String) {
      throw FormatException('catalog_input_${key}_invalid');
    }
    return field;
  }

  int _integerField(Map<String, Object?> value, String key) {
    final field = value[key];
    if (field is! int) {
      throw FormatException('catalog_input_${key}_invalid');
    }
    return field;
  }

  T _enumField<T extends Enum>(List<T> values, String raw, String fieldName) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw FormatException('catalog_input_${fieldName}_unknown');
  }

  void _checkJsonSize(String raw, int maximum, String errorCode) {
    if (utf8.encode(raw).length > maximum) {
      throw FormatException(errorCode);
    }
  }
}
