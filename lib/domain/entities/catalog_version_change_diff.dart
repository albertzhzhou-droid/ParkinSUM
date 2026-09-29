import 'dart:convert';

import 'package:crypto/crypto.dart';

const String catalogVersionChangeDiffSchemaUri =
    'parkinsum.catalog-version-change-diff/1';

enum CatalogVersionChangeKind {
  unchanged,
  added,
  deprecated,
  remapped,
  split,
  merged,
  ambiguous,
  unresolved,
}

enum CatalogTransitionRelationship {
  sameConcept,
  replacedBy,
  splitInto,
  mergedInto,
  candidateSet,
  retired,
}

enum CatalogMappingEvidenceReview { reviewed, unreviewed }

enum CatalogMappingEvidenceLicense {
  clearedForLocalReview,
  unknown,
  restricted,
}

/// One exact source code and display in a caller-supplied local catalog capture.
/// This is not an upstream terminology artifact or proof of release completeness.
class CatalogConceptIdentity {
  const CatalogConceptIdentity({
    required this.sourceSystem,
    required this.jurisdiction,
    required this.releaseId,
    required this.code,
    required this.display,
  });

  final String sourceSystem;
  final String jurisdiction;
  final String releaseId;
  final String code;
  final String display;

  Map<String, Object?> toJson() => <String, Object?>{
    'source_system': sourceSystem,
    'jurisdiction': jurisdiction,
    'release_id': releaseId,
    'code': code,
    'display': display,
  };

  bool hasSameIdentifier(CatalogConceptIdentity other) =>
      sourceSystem == other.sourceSystem &&
      jurisdiction == other.jurisdiction &&
      code == other.code;

  bool hasSameIdentifierAndDisplay(CatalogConceptIdentity other) =>
      hasSameIdentifier(other) && display == other.display;
}

/// An immutable, caller-supplied record-set snapshot for an explicit release.
/// [recordSetSha256] hashes only these supplied records and metadata. It does
/// not verify a publisher archive, catalog completeness, or source authority.
class CatalogReleaseSnapshot {
  CatalogReleaseSnapshot({
    required this.catalogId,
    required this.sourceSystem,
    required this.jurisdiction,
    required this.releaseId,
    required this.releaseSequence,
    required List<CatalogConceptIdentity> concepts,
  }) : concepts = List<CatalogConceptIdentity>.unmodifiable(concepts) {
    _requireToken(catalogId, 'catalogId');
    _requireToken(sourceSystem, 'sourceSystem');
    _requireToken(jurisdiction, 'jurisdiction');
    _requireToken(releaseId, 'releaseId');
    if (releaseSequence < 0) {
      throw ArgumentError.value(releaseSequence, 'releaseSequence');
    }
    if (this.concepts.length > 100000) {
      throw ArgumentError('A catalog snapshot cannot exceed 100000 concepts.');
    }
    final codes = <String>{};
    for (final concept in this.concepts) {
      _requireToken(concept.code, 'concept.code');
      _requireToken(concept.display, 'concept.display');
      if (concept.sourceSystem != sourceSystem ||
          concept.jurisdiction != jurisdiction ||
          concept.releaseId != releaseId) {
        throw ArgumentError('Concept identity must match its snapshot.');
      }
      if (!codes.add(concept.code)) {
        throw ArgumentError('Duplicate catalog code: ${concept.code}.');
      }
    }
  }

  final String catalogId;
  final String sourceSystem;
  final String jurisdiction;
  final String releaseId;
  final int releaseSequence;
  final List<CatalogConceptIdentity> concepts;

  late final String recordSetSha256 = _sha256(_canonicalJson(_bodyJson()));

  Map<String, Object?> _bodyJson() => <String, Object?>{
    'catalog_id': catalogId,
    'source_system': sourceSystem,
    'jurisdiction': jurisdiction,
    'release_id': releaseId,
    'release_sequence': releaseSequence,
    'concepts': concepts.map((concept) => concept.toJson()).toList()
      ..sort(_compareJsonIdentity),
  };

  Map<String, Object?> toJson() => <String, Object?>{
    ..._bodyJson(),
    'record_set_sha256': recordSetSha256,
  };
}

/// Explicit source-supplied mapping evidence. No name matching is performed.
/// Evidence is usable for classification only when its snapshot bindings match,
/// caller-declared review and license states are acceptable, and the evidence
/// digest is well-formed. Those declarations are not independently verified.
class CatalogMappingEvidence {
  CatalogMappingEvidence({
    required this.evidenceId,
    required this.sourceCode,
    required List<String> targetCodes,
    required this.relationship,
    required this.sourceReference,
    required this.evidenceSha256,
    required this.previousRecordSetSha256,
    required this.currentRecordSetSha256,
    required this.review,
    required this.license,
  }) : targetCodes = List<String>.unmodifiable(targetCodes) {
    _requireToken(evidenceId, 'evidenceId');
    _requireToken(sourceCode, 'sourceCode');
    _requireToken(sourceReference, 'sourceReference');
    if (this.targetCodes.length > 16 ||
        this.targetCodes.toSet().length != this.targetCodes.length) {
      throw ArgumentError('Target codes must be unique and at most 16.');
    }
    if (relationship == CatalogTransitionRelationship.retired &&
        this.targetCodes.isNotEmpty) {
      throw ArgumentError('Retirement evidence cannot have target codes.');
    }
    if (relationship != CatalogTransitionRelationship.retired &&
        this.targetCodes.isEmpty) {
      throw ArgumentError('Non-retirement evidence needs a target code.');
    }
  }

  final String evidenceId;
  final String sourceCode;
  final List<String> targetCodes;
  final CatalogTransitionRelationship relationship;
  final String sourceReference;
  final String evidenceSha256;
  final String previousRecordSetSha256;
  final String currentRecordSetSha256;
  final CatalogMappingEvidenceReview review;
  final CatalogMappingEvidenceLicense license;

  Map<String, Object?> toJson() => <String, Object?>{
    'evidence_id': evidenceId,
    'source_code': sourceCode,
    'target_codes': targetCodes.toList()..sort(),
    'relationship': relationship.name,
    'source_reference': sourceReference,
    'evidence_sha256': evidenceSha256,
    'previous_record_set_sha256': previousRecordSetSha256,
    'current_record_set_sha256': currentRecordSetSha256,
    'review': review.name,
    'license': license.name,
  };
}

class CatalogVersionChangeEntry {
  CatalogVersionChangeEntry({
    required this.kind,
    required this.previousConcept,
    required this.currentConcept,
    required List<CatalogConceptIdentity> candidates,
    required List<CatalogMappingEvidence> evidence,
    required List<String> reasons,
  }) : candidates = List<CatalogConceptIdentity>.unmodifiable(candidates),
       evidence = List<CatalogMappingEvidence>.unmodifiable(evidence),
       reasons = List<String>.unmodifiable(reasons);

  final CatalogVersionChangeKind kind;
  final CatalogConceptIdentity? previousConcept;
  final CatalogConceptIdentity? currentConcept;
  final List<CatalogConceptIdentity> candidates;
  final List<CatalogMappingEvidence> evidence;
  final List<String> reasons;

  /// Changed or unresolved old identities need an owner decision before any
  /// caller may apply a mapping. This preview does not mutate records.
  bool get requiresOwnerDecision =>
      previousConcept != null && kind != CatalogVersionChangeKind.unchanged;

  /// A preview signal only. No production algorithm is wired to this model.
  bool get holdBeforeApplying => requiresOwnerDecision;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'previous_concept': previousConcept?.toJson(),
    'current_concept': currentConcept?.toJson(),
    'candidates': candidates.map((concept) => concept.toJson()).toList(),
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'reasons': reasons,
    'requires_owner_decision': requiresOwnerDecision,
    'hold_before_applying': holdBeforeApplying,
  };
}

/// Deterministic preview of a comparison between two caller-supplied captures.
/// SHA-256 here provides content identity only; it is not a signature.
class CatalogVersionChangeDiff {
  CatalogVersionChangeDiff({
    required this.previousSnapshot,
    required this.currentSnapshot,
    required List<CatalogVersionChangeEntry> entries,
  }) : entries = List<CatalogVersionChangeEntry>.unmodifiable(entries);

  static const String schemaUri = catalogVersionChangeDiffSchemaUri;
  static const int schemaVersion = 1;

  final CatalogReleaseSnapshot previousSnapshot;
  final CatalogReleaseSnapshot currentSnapshot;
  final List<CatalogVersionChangeEntry> entries;

  Map<String, Object?> _bodyJson() => <String, Object?>{
    'schema_uri': schemaUri,
    'schema_version': schemaVersion,
    'previous_snapshot_sha256': previousSnapshot.recordSetSha256,
    'current_snapshot_sha256': currentSnapshot.recordSetSha256,
    'catalog_id': previousSnapshot.catalogId,
    'source_system': previousSnapshot.sourceSystem,
    'jurisdiction': previousSnapshot.jurisdiction,
    'previous_release_id': previousSnapshot.releaseId,
    'current_release_id': currentSnapshot.releaseId,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  late final String sha256Digest = _sha256(_canonicalJson(_bodyJson()));

  Map<String, Object?> toJson() => <String, Object?>{
    ..._bodyJson(),
    'sha256_digest': sha256Digest,
    'signature_status': 'not_signed',
    'application_status': 'preview_only',
    'clinical_or_terminology_conformance': false,
  };
}

void _requireToken(String value, String name) {
  if (value.isEmpty || value.trim() != value) {
    throw ArgumentError('$name must be non-empty and trimmed.');
  }
}

int _compareJsonIdentity(
  Map<String, Object?> left,
  Map<String, Object?> right,
) {
  final leftKey = '${left['code']}\u0000${left['display']}';
  final rightKey = '${right['code']}\u0000${right['display']}';
  return leftKey.compareTo(rightKey);
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList();
  return value;
}
