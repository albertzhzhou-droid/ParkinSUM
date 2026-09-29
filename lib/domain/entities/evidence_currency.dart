import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'mechanistic_medication_applicability.dart';

enum EvidenceCurrencyStatus {
  current,
  corrected,
  superseded,
  retracted,
  withdrawn,
  expressionOfConcern,
  expired,
  unavailable,
  unknown,
}

enum EvidenceStatusMethod {
  nlmLinkedCitationReview,
  crossmarkMetadataReview,
  regulatoryPublisherReview,
  sourceOwnerRevisionReview,
}

enum EvidenceSunsetDisposition {
  allowResearchTraceOnly,
  holdForReview,
  blockAffectedProviders,
}

enum EvidenceCurrencyRuntimeDisposition {
  allowResearchTraceOnly,
  holdForReview,
  blockAffectedProviders,
  blockRegistryIntegrity,
}

final class EvidenceCurrencyRecord {
  final String claimId;
  final String claim;
  final String sourceId;
  final String? doi;
  final String? pmid;
  final String? regulatoryDocumentId;
  final String sourceRevision;
  final List<String> providerIds;
  final List<String> predicateIds;
  final EvidenceCurrencyStatus status;
  final EvidenceStatusMethod statusMethod;
  final String statusAuthoritySourceId;
  final String statusCheckUri;
  final List<String> statusEvidenceIds;
  final String observedAtUtc;
  final String reviewByUtc;
  final String reviewer;
  final String? updateNoticeId;
  final String applicabilityBoundary;

  EvidenceCurrencyRecord({
    required this.claimId,
    required this.claim,
    required this.sourceId,
    required this.doi,
    required this.pmid,
    required this.regulatoryDocumentId,
    required this.sourceRevision,
    required List<String> providerIds,
    required List<String> predicateIds,
    required this.status,
    required this.statusMethod,
    required this.statusAuthoritySourceId,
    required this.statusCheckUri,
    required List<String> statusEvidenceIds,
    required this.observedAtUtc,
    required this.reviewByUtc,
    required this.reviewer,
    required this.updateNoticeId,
    required this.applicabilityBoundary,
  }) : providerIds = List.unmodifiable(providerIds),
       predicateIds = List.unmodifiable(predicateIds),
       statusEvidenceIds = List.unmodifiable(statusEvidenceIds);

  EvidenceCurrencyStatus effectiveStatusAt(DateTime asOfUtc) {
    final asOf = asOfUtc.toUtc();
    final observedAt = DateTime.tryParse(observedAtUtc);
    final reviewBy = DateTime.tryParse(reviewByUtc);
    if (observedAt == null || !observedAt.isUtc || observedAt.isAfter(asOf)) {
      return EvidenceCurrencyStatus.unknown;
    }
    if (reviewBy == null || !reviewBy.isUtc || asOf.isAfter(reviewBy)) {
      return EvidenceCurrencyStatus.expired;
    }
    return status;
  }

  EvidenceSunsetDisposition dispositionAt(DateTime asOfUtc) {
    return switch (effectiveStatusAt(asOfUtc)) {
      EvidenceCurrencyStatus.current =>
        EvidenceSunsetDisposition.allowResearchTraceOnly,
      EvidenceCurrencyStatus.corrected =>
        EvidenceSunsetDisposition.holdForReview,
      EvidenceCurrencyStatus.superseded ||
      EvidenceCurrencyStatus.retracted ||
      EvidenceCurrencyStatus.withdrawn ||
      EvidenceCurrencyStatus.expressionOfConcern ||
      EvidenceCurrencyStatus.expired ||
      EvidenceCurrencyStatus.unavailable ||
      EvidenceCurrencyStatus.unknown =>
        EvidenceSunsetDisposition.blockAffectedProviders,
    };
  }

  List<String> get integrityReasons {
    final reasons = <String>[];
    if (!_isSafeId(claimId)) reasons.add('claim_id_invalid:$claimId');
    if (claim.trim().isEmpty) reasons.add('claim_text_missing:$claimId');
    if (!_isSafeId(sourceId)) reasons.add('source_id_invalid:$claimId');
    if (sourceRevision.trim().isEmpty) {
      reasons.add('source_revision_missing:$claimId');
    }
    if (doi == null && pmid == null && regulatoryDocumentId == null) {
      reasons.add('persistent_source_identity_missing:$claimId');
    }
    if (doi != null && !_isDoi(doi!)) reasons.add('doi_invalid:$claimId');
    if (pmid != null && !RegExp(r'^\d{1,9}$').hasMatch(pmid!)) {
      reasons.add('pmid_invalid:$claimId');
    }
    if (regulatoryDocumentId != null && !_isSafeId(regulatoryDocumentId!)) {
      reasons.add('regulatory_document_id_invalid:$claimId');
    }
    if (providerIds.isEmpty ||
        providerIds.any((id) => !_isSafeId(id)) ||
        providerIds.toSet().length != providerIds.length) {
      reasons.add('provider_ids_invalid:$claimId');
    }
    if (predicateIds.any((id) => !_isSafeId(id)) ||
        predicateIds.toSet().length != predicateIds.length) {
      reasons.add('predicate_ids_invalid:$claimId');
    }
    if (!_isHttpsUri(statusCheckUri)) {
      reasons.add('status_check_uri_invalid:$claimId');
    }
    if (!_isSafeId(statusAuthoritySourceId)) {
      reasons.add('status_authority_source_id_invalid:$claimId');
    }
    if (!_statusAuthorityMatchesMethod(
      method: statusMethod,
      authoritySourceId: statusAuthoritySourceId,
      statusCheckUri: statusCheckUri,
    )) {
      reasons.add('status_authority_method_mismatch:$claimId');
    }
    if (statusEvidenceIds.isEmpty ||
        statusEvidenceIds.any((id) => id.trim().isEmpty) ||
        statusEvidenceIds.toSet().length != statusEvidenceIds.length) {
      reasons.add('status_evidence_invalid:$claimId');
    }
    final observedAt = DateTime.tryParse(observedAtUtc);
    final reviewBy = DateTime.tryParse(reviewByUtc);
    if (observedAt == null || !observedAt.isUtc) {
      reasons.add('observed_at_invalid:$claimId');
    }
    if (reviewBy == null || !reviewBy.isUtc) {
      reasons.add('review_by_invalid:$claimId');
    }
    if (observedAt != null &&
        reviewBy != null &&
        !reviewBy.isAfter(observedAt)) {
      reasons.add('review_window_invalid:$claimId');
    }
    if (reviewer.trim().isEmpty) reasons.add('reviewer_missing:$claimId');
    if (applicabilityBoundary.trim().isEmpty) {
      reasons.add('applicability_boundary_missing:$claimId');
    }
    if (status == EvidenceCurrencyStatus.current && updateNoticeId != null) {
      reasons.add('current_status_has_update_notice:$claimId');
    }
    if (status != EvidenceCurrencyStatus.current &&
        (updateNoticeId == null || updateNoticeId!.trim().isEmpty)) {
      reasons.add('noncurrent_status_notice_missing:$claimId');
    }
    return List.unmodifiable(reasons);
  }

  String get claimFingerprintSha256 => _sha256(<String, Object?>{
    'claim_id': claimId,
    'claim': claim,
    'source_id': sourceId,
    'doi': doi,
    'pmid': pmid,
    'regulatory_document_id': regulatoryDocumentId,
    'source_revision': sourceRevision,
    'provider_ids': _sorted(providerIds),
    'predicate_ids': _sorted(predicateIds),
    'applicability_boundary': applicabilityBoundary,
  });

  String get recordSha256 => _sha256(canonicalPayload);

  Map<String, Object?> get canonicalPayload => {
    'claim_id': claimId,
    'claim_fingerprint_sha256': claimFingerprintSha256,
    'claim': claim,
    'source_id': sourceId,
    'doi': doi,
    'pmid': pmid,
    'regulatory_document_id': regulatoryDocumentId,
    'source_revision': sourceRevision,
    'provider_ids': _sorted(providerIds),
    'predicate_ids': _sorted(predicateIds),
    'status': status.name,
    'status_method': statusMethod.name,
    'status_authority_source_id': statusAuthoritySourceId,
    'status_check_uri': statusCheckUri,
    'status_evidence_ids': _sorted(statusEvidenceIds),
    'observed_at_utc': observedAtUtc,
    'review_by_utc': reviewByUtc,
    'reviewer': reviewer,
    'update_notice_id': updateNoticeId,
    'applicability_boundary': applicabilityBoundary,
  };

  Map<String, Object?> toJson({required DateTime asOfUtc}) => {
    ...canonicalPayload,
    'record_sha256': recordSha256,
    'effective_status': effectiveStatusAt(asOfUtc).name,
    'sunset_disposition': dispositionAt(asOfUtc).name,
  };

  EvidenceCurrencyRecord copyWith({
    EvidenceCurrencyStatus? status,
    String? updateNoticeId,
    String? observedAtUtc,
    String? reviewByUtc,
    List<String>? providerIds,
    String? statusAuthoritySourceId,
    String? statusCheckUri,
  }) {
    return EvidenceCurrencyRecord(
      claimId: claimId,
      claim: claim,
      sourceId: sourceId,
      doi: doi,
      pmid: pmid,
      regulatoryDocumentId: regulatoryDocumentId,
      sourceRevision: sourceRevision,
      providerIds: providerIds ?? this.providerIds,
      predicateIds: predicateIds,
      status: status ?? this.status,
      statusMethod: statusMethod,
      statusAuthoritySourceId:
          statusAuthoritySourceId ?? this.statusAuthoritySourceId,
      statusCheckUri: statusCheckUri ?? this.statusCheckUri,
      statusEvidenceIds: statusEvidenceIds,
      observedAtUtc: observedAtUtc ?? this.observedAtUtc,
      reviewByUtc: reviewByUtc ?? this.reviewByUtc,
      reviewer: reviewer,
      updateNoticeId: updateNoticeId ?? this.updateNoticeId,
      applicabilityBoundary: applicabilityBoundary,
    );
  }
}

final class EvidenceCurrencyAssessment {
  final DateTime asOfUtc;
  final String registrySha256;
  final List<EvidenceCurrencyRecord> records;
  final List<EvidenceCurrencyRecord> heldRecords;
  final List<EvidenceCurrencyRecord> blockedRecords;
  final Set<String> affectedProviderIds;
  final Set<String> affectedPredicateIds;
  final List<String> integrityReasons;

  EvidenceCurrencyAssessment({
    required this.asOfUtc,
    required this.registrySha256,
    required List<EvidenceCurrencyRecord> records,
    required List<EvidenceCurrencyRecord> heldRecords,
    required List<EvidenceCurrencyRecord> blockedRecords,
    required Set<String> affectedProviderIds,
    required Set<String> affectedPredicateIds,
    required List<String> integrityReasons,
  }) : records = List.unmodifiable(records),
       heldRecords = List.unmodifiable(heldRecords),
       blockedRecords = List.unmodifiable(blockedRecords),
       affectedProviderIds = Set.unmodifiable(affectedProviderIds),
       affectedPredicateIds = Set.unmodifiable(affectedPredicateIds),
       integrityReasons = List.unmodifiable(integrityReasons);

  bool get requiresRequalification =>
      integrityReasons.isNotEmpty ||
      heldRecords.isNotEmpty ||
      blockedRecords.isNotEmpty;

  EvidenceCurrencyRuntimeDisposition runtimeDispositionFor(
    Iterable<String> providerIds,
  ) {
    final requested = providerIds.toSet();
    final knownProviders = MechanisticApplicabilityManifest.current.providers
        .map((provider) => provider.providerId)
        .toSet();
    if (integrityReasons.isNotEmpty ||
        requested.isEmpty ||
        requested.difference(knownProviders).isNotEmpty) {
      return EvidenceCurrencyRuntimeDisposition.blockRegistryIntegrity;
    }
    final heldForRequestedProviders = heldRecords.any(
      (record) => record.providerIds.any(requested.contains),
    );
    final blockedForRequestedProviders = blockedRecords.any(
      (record) => record.providerIds.any(requested.contains),
    );
    if (blockedForRequestedProviders) {
      return EvidenceCurrencyRuntimeDisposition.blockAffectedProviders;
    }
    if (heldForRequestedProviders) {
      return EvidenceCurrencyRuntimeDisposition.holdForReview;
    }
    return EvidenceCurrencyRuntimeDisposition.allowResearchTraceOnly;
  }

  String get snapshotSha256 => _sha256(<String, Object?>{
    'registry_sha256': registrySha256,
    'as_of_utc': asOfUtc.toUtc().toIso8601String(),
    'records': records
        .map((record) => record.toJson(asOfUtc: asOfUtc))
        .toList(growable: false),
  });

  Map<String, Object?> toJson() => {
    'registry_sha256': registrySha256,
    'snapshot_sha256': snapshotSha256,
    'as_of_utc': asOfUtc.toUtc().toIso8601String(),
    'requires_requalification': requiresRequalification,
    'held_claim_ids': _sorted(heldRecords.map((record) => record.claimId)),
    'blocked_claim_ids': _sorted(
      blockedRecords.map((record) => record.claimId),
    ),
    'affected_provider_ids': _sorted(affectedProviderIds),
    'affected_predicate_ids': _sorted(affectedPredicateIds),
    'integrity_reasons': integrityReasons,
    'records': records
        .map((record) => record.toJson(asOfUtc: asOfUtc))
        .toList(growable: false),
    'boundary':
        'A current status means only that the recorded review found no '
        'governed adverse update. It is not a validity, certainty, causality, '
        'clinical-effectiveness, regulatory, or treatment claim.',
  };

  /// Returns fail-closed reasons when this assessment cannot support one or
  /// more requested research-trace providers. A registry integrity problem
  /// blocks every provider because the affected claim set is then unknown.
  List<String> runtimeBlockReasonsFor(Iterable<String> providerIds) {
    final requested = providerIds.toSet();
    final knownProviders = MechanisticApplicabilityManifest.current.providers
        .map((provider) => provider.providerId)
        .toSet();
    final reasons = <String>{
      ...integrityReasons.map(
        (reason) => 'evidence_currency.registry_integrity:$reason',
      ),
      ...requested
          .difference(knownProviders)
          .map(
            (provider) =>
                'evidence_currency.runtime_provider_unknown:$provider',
          ),
    };
    if (integrityReasons.isNotEmpty) {
      return List.unmodifiable(reasons.toList()..sort());
    }

    final affectedRecords = <EvidenceCurrencyRecord>{
      ...heldRecords,
      ...blockedRecords,
    };
    for (final record in affectedRecords) {
      final affectedProviders =
          record.providerIds.where(requested.contains).toList(growable: false)
            ..sort();
      if (affectedProviders.isEmpty) continue;
      final disposition = record.dispositionAt(asOfUtc);
      final status = record.effectiveStatusAt(asOfUtc);
      final action = disposition == EvidenceSunsetDisposition.holdForReview
          ? 'hold_for_review'
          : 'blocked';
      reasons.add(
        'evidence_currency.$action:${record.claimId}:'
        'status=${status.name}:'
        'providers=${affectedProviders.join(',')}',
      );
    }
    return List.unmodifiable(reasons.toList()..sort());
  }
}

/// Portable, tamper-evident binding between one runtime result and the exact
/// offline evidence-currency assessment used for its provider set.
///
/// The digest detects accidental or adversarial payload changes; it is not a
/// digital signature, reviewer credential, or proof that a source is valid.
final class EvidenceCurrencyRuntimeBinding {
  static const String schema = 'parkinsum.evidence-currency-runtime-binding/1';
  static const String boundary =
      'Binds this result to an offline reviewed status snapshot and provider '
      'set. It is not a signature, source-validity claim, clinical validation, '
      'or treatment recommendation.';

  final String registryVersion;
  final String registrySha256;
  final String snapshotSha256;
  final DateTime asOfUtc;
  final List<String> providerIds;
  final List<String> claimIds;
  final EvidenceCurrencyRuntimeDisposition disposition;

  EvidenceCurrencyRuntimeBinding._({
    required this.registryVersion,
    required this.registrySha256,
    required this.snapshotSha256,
    required this.asOfUtc,
    required List<String> providerIds,
    required List<String> claimIds,
    required this.disposition,
  }) : providerIds = List.unmodifiable(_sorted(providerIds)),
       claimIds = List.unmodifiable(_sorted(claimIds));

  factory EvidenceCurrencyRuntimeBinding.fromAssessment({
    required String registryVersion,
    required EvidenceCurrencyAssessment assessment,
    required Iterable<String> providerIds,
  }) {
    final providers = providerIds.toSet();
    final claimIds = assessment.records
        .where((record) => record.providerIds.any(providers.contains))
        .map((record) => record.claimId)
        .toSet();
    return EvidenceCurrencyRuntimeBinding._(
      registryVersion: registryVersion,
      registrySha256: assessment.registrySha256,
      snapshotSha256: assessment.snapshotSha256,
      asOfUtc: assessment.asOfUtc,
      providerIds: providers.toList(growable: false),
      claimIds: claimIds.toList(growable: false),
      disposition: assessment.runtimeDispositionFor(providers),
    );
  }

  Map<String, Object?> get canonicalPayload => {
    'schema': schema,
    'registry_version': registryVersion,
    'registry_sha256': registrySha256,
    'snapshot_sha256': snapshotSha256,
    'as_of_utc': asOfUtc.toUtc().toIso8601String(),
    'provider_ids': _sorted(providerIds),
    'claim_ids': _sorted(claimIds),
    'disposition': disposition.name,
    'boundary': boundary,
  };

  String get bindingSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'binding_sha256': bindingSha256,
  };

  List<String> get integrityReasons {
    final reasons = <String>[];
    if (!_isSafeId(registryVersion)) {
      reasons.add('evidence_currency_binding.registry_version_invalid');
    }
    if (!_isSha256(registrySha256)) {
      reasons.add('evidence_currency_binding.registry_sha256_invalid');
    }
    if (!_isSha256(snapshotSha256)) {
      reasons.add('evidence_currency_binding.snapshot_sha256_invalid');
    }
    if (!asOfUtc.isUtc) {
      reasons.add('evidence_currency_binding.as_of_not_utc');
    }
    if (providerIds.isEmpty ||
        providerIds.any((id) => !_isSafeId(id)) ||
        providerIds.toSet().length != providerIds.length ||
        !_isSortedUnique(providerIds)) {
      reasons.add('evidence_currency_binding.provider_ids_invalid');
    }
    if (claimIds.any((id) => !_isSafeId(id)) ||
        claimIds.toSet().length != claimIds.length ||
        !_isSortedUnique(claimIds) ||
        (claimIds.isEmpty &&
            disposition !=
                EvidenceCurrencyRuntimeDisposition.blockRegistryIntegrity)) {
      reasons.add('evidence_currency_binding.claim_ids_invalid');
    }
    if (bindingSha256 != _sha256(canonicalPayload)) {
      reasons.add('evidence_currency_binding.digest_mismatch');
    }
    return List.unmodifiable(reasons);
  }

  factory EvidenceCurrencyRuntimeBinding.fromJson(Map<String, Object?> json) {
    const requiredKeys = {
      'schema',
      'registry_version',
      'registry_sha256',
      'snapshot_sha256',
      'as_of_utc',
      'provider_ids',
      'claim_ids',
      'disposition',
      'boundary',
      'binding_sha256',
    };
    if (json.keys.toSet().difference(requiredKeys).isNotEmpty ||
        requiredKeys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException('evidence_currency_binding.fields_invalid');
    }
    if (json['schema'] != schema || json['boundary'] != boundary) {
      throw const FormatException('evidence_currency_binding.version_invalid');
    }
    final asOfText = json['as_of_utc'];
    final asOfUtc = asOfText is String ? DateTime.tryParse(asOfText) : null;
    final providers = _stringList(json['provider_ids']);
    final claims = _stringList(json['claim_ids']);
    final registryVersion = json['registry_version'];
    final registrySha256 = json['registry_sha256'];
    final snapshotSha256 = json['snapshot_sha256'];
    final bindingSha256 = json['binding_sha256'];
    final dispositionValue = json['disposition'];
    if (asOfUtc == null ||
        !asOfUtc.isUtc ||
        asOfUtc.toIso8601String() != asOfText ||
        providers == null ||
        !_isSortedUnique(providers) ||
        claims == null ||
        !_isSortedUnique(claims) ||
        registryVersion is! String ||
        registrySha256 is! String ||
        snapshotSha256 is! String ||
        bindingSha256 is! String ||
        dispositionValue is! String) {
      throw const FormatException('evidence_currency_binding.value_invalid');
    }
    EvidenceCurrencyRuntimeDisposition? disposition;
    for (final value in EvidenceCurrencyRuntimeDisposition.values) {
      if (value.name == dispositionValue) {
        disposition = value;
        break;
      }
    }
    if (disposition == null) {
      throw const FormatException(
        'evidence_currency_binding.disposition_invalid',
      );
    }
    final binding = EvidenceCurrencyRuntimeBinding._(
      registryVersion: registryVersion,
      registrySha256: registrySha256,
      snapshotSha256: snapshotSha256,
      asOfUtc: asOfUtc,
      providerIds: providers,
      claimIds: claims,
      disposition: disposition,
    );
    if (binding.bindingSha256 != bindingSha256 ||
        binding.integrityReasons.isNotEmpty) {
      throw const FormatException('evidence_currency_binding.digest_invalid');
    }
    return binding;
  }
}

List<String>? _stringList(Object? value) {
  if (value is! List || value.any((item) => item is! String)) return null;
  return List<String>.unmodifiable(value.cast<String>());
}

bool _isSha256(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

bool _isSortedUnique(List<String> values) {
  final sorted = _sorted(values);
  for (var index = 0; index < values.length; index++) {
    if (values[index] != sorted[index]) return false;
  }
  return true;
}

final class EvidenceCurrencyRegistry {
  static const String schema = 'parkinsum.evidence-currency-registry/1';
  static const String registryVersion = '2026.08.18-v1';

  final List<EvidenceCurrencyRecord> records;

  EvidenceCurrencyRegistry({required List<EvidenceCurrencyRecord> records})
    : records = List.unmodifiable(records);

  static final EvidenceCurrencyRegistry current = EvidenceCurrencyRegistry(
    records: [
      EvidenceCurrencyRecord(
        claimId: 'claim.meal_delay_direction.nutt_1984',
        claim:
            'A small selected human study supports meal-associated delay and '
            'LNAA competition direction, not an individual timing rule.',
        sourceId: 'src.nutt.onoff.1984',
        doi: '10.1056/NEJM198402233100802',
        pmid: '6694694',
        regulatoryDocumentId: null,
        sourceRevision: 'pubmed-record-6694694',
        providerIds: const [
          'levodopa_absorption_opportunity',
          'amino_acid_competition',
          'mechanistic_conflict',
          'mechanistic_candidate_scorer',
        ],
        predicateIds: const [
          'medication.explicit_dose',
          'meal.protein_evidence',
        ],
        status: EvidenceCurrencyStatus.current,
        statusMethod: EvidenceStatusMethod.nlmLinkedCitationReview,
        statusAuthoritySourceId: 'src.nlm.errata-retraction-policy',
        statusCheckUri: 'https://pubmed.ncbi.nlm.nih.gov/6694694/',
        statusEvidenceIds: const [
          'pubmed:6694694:linked-citation-review:2026-08-18',
        ],
        observedAtUtc: '2026-08-18T22:00:00Z',
        reviewByUtc: '2027-02-18T22:00:00Z',
        reviewer: 'parkinsum-evidence-review',
        updateNoticeId: null,
        applicabilityBoundary:
            'Nine selected participants and historical methods; direction and '
            'a reference observation only, never patient calibration.',
      ),
      EvidenceCurrencyRecord(
        claimId: 'claim.gastric_peak_association.doi_2012',
        claim:
            'A small observational Parkinson cohort associates delayed gastric '
            'emptying with later plasma levodopa peak.',
        sourceId: 'src.doi.ge.levodopa.2012',
        doi: '10.1016/j.jns.2012.05.010',
        pmid: '22632782',
        regulatoryDocumentId: null,
        sourceRevision: 'pubmed-record-22632782',
        providerIds: const [
          'gastric_emptying',
          'levodopa_absorption_opportunity',
          'mechanistic_conflict',
        ],
        predicateIds: const ['timeline.dose_time_meal_context'],
        status: EvidenceCurrencyStatus.current,
        statusMethod: EvidenceStatusMethod.nlmLinkedCitationReview,
        statusAuthoritySourceId: 'src.nlm.errata-retraction-policy',
        statusCheckUri: 'https://pubmed.ncbi.nlm.nih.gov/22632782/',
        statusEvidenceIds: const [
          'pubmed:22632782:linked-citation-review:2026-08-18',
        ],
        observedAtUtc: '2026-08-18T22:00:00Z',
        reviewByUtc: '2027-02-18T22:00:00Z',
        reviewer: 'parkinsum-evidence-review',
        updateNoticeId: null,
        applicabilityBoundary:
            'Association in 31 patients; not causal proof, a universal delay, '
            'or validation of ParkinSUM curve parameters.',
      ),
      EvidenceCurrencyRecord(
        claimId: 'claim.gastric_halftime_measurement.zinsmeister_2012',
        claim:
            'Hourly scintigraphic measurements can estimate solid gastric '
            'half-time over the studied measurement range.',
        sourceId: 'src.zinsmeister.ge.halftime.2012',
        doi: '10.1111/j.1365-2982.2012.01982.x',
        pmid: '22812490',
        regulatoryDocumentId: null,
        sourceRevision: 'pubmed-record-22812490',
        providerIds: const ['gastric_emptying'],
        predicateIds: const ['meal.structured_composition'],
        status: EvidenceCurrencyStatus.current,
        statusMethod: EvidenceStatusMethod.nlmLinkedCitationReview,
        statusAuthoritySourceId: 'src.nlm.errata-retraction-policy',
        statusCheckUri: 'https://pubmed.ncbi.nlm.nih.gov/22812490/',
        statusEvidenceIds: const [
          'pubmed:22812490:linked-citation-review:2026-08-18',
        ],
        observedAtUtc: '2026-08-18T22:00:00Z',
        reviewByUtc: '2027-02-18T22:00:00Z',
        reviewer: 'parkinsum-evidence-review',
        updateNoticeId: null,
        applicabilityBoundary:
            'Measurement-method evidence in 155 subjects; it does not supply '
            'ParkinSUM point values or individual Parkinson predictions.',
      ),
      EvidenceCurrencyRecord(
        claimId: 'claim.amino_acid_input_identity.fdc',
        claim:
            'FoodData Central exposes amino-acid nutrient fields that may be '
            'preserved as measured or missing composition inputs.',
        sourceId: 'src.fdc.api.amino_acid_fields',
        doi: null,
        pmid: null,
        regulatoryDocumentId: 'USDA-FDC-API',
        sourceRevision: 'api-spec-reviewed-2026-08-18',
        providerIds: const [
          'meal_composition_normalizer',
          'amino_acid_competition',
          'mechanistic_conflict',
          'mechanistic_candidate_scorer',
        ],
        predicateIds: const [
          'meal.structured_composition',
          'meal.protein_evidence',
        ],
        status: EvidenceCurrencyStatus.current,
        statusMethod: EvidenceStatusMethod.sourceOwnerRevisionReview,
        statusAuthoritySourceId: 'src.usda.fdc.api',
        statusCheckUri: 'https://fdc.nal.usda.gov/api-guide/',
        statusEvidenceIds: const [
          'usda-fdc:api-guide:manual-review:2026-08-18',
        ],
        observedAtUtc: '2026-08-18T22:00:00Z',
        reviewByUtc: '2027-02-18T22:00:00Z',
        reviewer: 'parkinsum-evidence-review',
        updateNoticeId: null,
        applicabilityBoundary:
            'Composition identity only. Sparse amino-acid fields remain '
            'missing and cannot establish levodopa-food mechanism magnitude.',
      ),
      EvidenceCurrencyRecord(
        claimId: 'claim.context_of_use_credibility.fda_2023',
        claim:
            'Computational-model credibility should be assessed against a '
            'defined question of interest, context of use, risk, and evidence.',
        sourceId: 'src.fda.cms.credibility.guidance',
        doi: null,
        pmid: null,
        regulatoryDocumentId: 'FDA-CMS-CREDIBILITY-GUIDANCE-2023',
        sourceRevision: 'final-guidance-2023-11',
        providerIds: const [
          'meal_composition_normalizer',
          'gastric_emptying',
          'levodopa_absorption_opportunity',
          'amino_acid_competition',
          'mechanistic_conflict',
          'mechanistic_candidate_scorer',
        ],
        predicateIds: const [
          'medication.active_components',
          'medication.route',
          'medication.dosage_form',
          'medication.release_type',
          'timeline.identity_integrity',
          'provider.upstream_availability',
        ],
        status: EvidenceCurrencyStatus.current,
        statusMethod: EvidenceStatusMethod.regulatoryPublisherReview,
        statusAuthoritySourceId: 'src.fda.cms.credibility.guidance',
        statusCheckUri:
            'https://www.fda.gov/regulatory-information/search-fda-guidance-documents/assessing-credibility-computational-modeling-and-simulation-medical-device-submissions',
        statusEvidenceIds: const [
          'fda:cms-credibility:final-guidance-page:2026-08-18',
        ],
        observedAtUtc: '2026-08-18T22:00:00Z',
        reviewByUtc: '2027-02-18T22:00:00Z',
        reviewer: 'parkinsum-evidence-review',
        updateNoticeId: null,
        applicabilityBoundary:
            'Governance method only; not FDA review, qualification, clearance, '
            'clinical validation, or evidence that ParkinSUM meets the guidance.',
      ),
    ],
  );

  List<String> integrityReasons({MechanisticApplicabilityManifest? manifest}) {
    final effectiveManifest =
        manifest ?? MechanisticApplicabilityManifest.current;
    final reasons = <String>[];
    final claimIds = <String>{};
    final recordHashes = <String>{};
    for (final record in records) {
      reasons.addAll(record.integrityReasons);
      if (!claimIds.add(record.claimId)) {
        reasons.add('claim_id_duplicate:${record.claimId}');
      }
      if (!recordHashes.add(record.recordSha256)) {
        reasons.add('record_duplicate:${record.claimId}');
      }
    }
    final knownProviders = effectiveManifest.providers
        .map((provider) => provider.providerId)
        .toSet();
    final knownPredicates = effectiveManifest.predicates
        .map((predicate) => predicate.id)
        .toSet();
    final coveredProviders = records
        .expand((record) => record.providerIds)
        .toSet();
    final referencedPredicates = records
        .expand((record) => record.predicateIds)
        .toSet();
    for (final provider in coveredProviders.difference(knownProviders)) {
      reasons.add('provider_unknown:$provider');
    }
    for (final provider in knownProviders.difference(coveredProviders)) {
      reasons.add('provider_evidence_currency_missing:$provider');
    }
    for (final predicate in referencedPredicates.difference(knownPredicates)) {
      reasons.add('predicate_unknown:$predicate');
    }
    return List.unmodifiable(reasons);
  }

  String get registrySha256 => _sha256(<String, Object?>{
    'schema': schema,
    'registry_version': registryVersion,
    'records': records.map((record) => record.canonicalPayload).toList(),
  });

  EvidenceCurrencyAssessment assess({required DateTime asOfUtc}) {
    final held = <EvidenceCurrencyRecord>[];
    final blocked = <EvidenceCurrencyRecord>[];
    for (final record in records) {
      switch (record.dispositionAt(asOfUtc)) {
        case EvidenceSunsetDisposition.allowResearchTraceOnly:
          break;
        case EvidenceSunsetDisposition.holdForReview:
          held.add(record);
        case EvidenceSunsetDisposition.blockAffectedProviders:
          blocked.add(record);
      }
    }
    final affected = <EvidenceCurrencyRecord>[...held, ...blocked];
    return EvidenceCurrencyAssessment(
      asOfUtc: asOfUtc.toUtc(),
      registrySha256: registrySha256,
      records: records,
      heldRecords: held,
      blockedRecords: blocked,
      affectedProviderIds: affected
          .expand((record) => record.providerIds)
          .toSet(),
      affectedPredicateIds: affected
          .expand((record) => record.predicateIds)
          .toSet(),
      integrityReasons: integrityReasons(),
    );
  }

  Map<String, Object?> toJson({required DateTime asOfUtc}) => {
    'schema': schema,
    'registry_version': registryVersion,
    ...assess(asOfUtc: asOfUtc).toJson(),
  };
}

bool _isSafeId(String value) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$').hasMatch(value);

bool _isDoi(String value) =>
    RegExp(r'^10\.\d{4,9}/\S+$', caseSensitive: false).hasMatch(value);

bool _isHttpsUri(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

bool _statusAuthorityMatchesMethod({
  required EvidenceStatusMethod method,
  required String authoritySourceId,
  required String statusCheckUri,
}) {
  final host = Uri.tryParse(statusCheckUri)?.host.toLowerCase();
  if (host == null || host.isEmpty) return false;
  bool hostIs(String expected) =>
      host == expected || host.endsWith('.$expected');
  return switch (method) {
    EvidenceStatusMethod.nlmLinkedCitationReview =>
      authoritySourceId == 'src.nlm.errata-retraction-policy' &&
          (hostIs('nih.gov') || hostIs('nlm.nih.gov')),
    EvidenceStatusMethod.crossmarkMetadataReview =>
      authoritySourceId == 'src.crossref.crossmark' && hostIs('crossref.org'),
    EvidenceStatusMethod.regulatoryPublisherReview =>
      authoritySourceId == 'src.fda.cms.credibility.guidance' &&
          hostIs('fda.gov'),
    EvidenceStatusMethod.sourceOwnerRevisionReview =>
      authoritySourceId == 'src.usda.fdc.api' && hostIs('usda.gov'),
  };
}

List<String> _sorted(Iterable<String> values) => values.toList()..sort();

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${_canonicalJson(entry.value)}').join(',')}}';
  }
  throw ArgumentError.value(value, 'value', 'Unsupported canonical JSON type');
}
