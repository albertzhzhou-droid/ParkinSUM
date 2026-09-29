import '../entities/cdss_records.dart';
import '../entities/evidence_currency.dart';

enum EvidenceSourceCurrencyLookupState {
  linkedClaimRecords,
  noRegisteredClaimRecord,
  registryIntegrityHold,
}

final class EvidenceSourceCurrencyClaimStatus {
  final EvidenceCurrencyRecord record;
  final EvidenceCurrencyStatus effectiveStatus;
  final EvidenceSunsetDisposition disposition;

  const EvidenceSourceCurrencyClaimStatus({
    required this.record,
    required this.effectiveStatus,
    required this.disposition,
  });
}

/// Exact-ID projection from a source record to the offline claim-status
/// snapshot. It never infers a status for an unregistered source.
final class EvidenceSourceCurrencyStatusLookup {
  final String sourceDocId;
  final EvidenceSourceCurrencyLookupState state;
  final DateTime asOfUtc;
  final String registrySchema;
  final String registryVersion;
  final String registrySha256;
  final String snapshotSha256;
  final List<EvidenceSourceCurrencyClaimStatus> claimStatuses;
  final List<String> integrityReasons;

  EvidenceSourceCurrencyStatusLookup({
    required this.sourceDocId,
    required this.state,
    required this.asOfUtc,
    required this.registrySchema,
    required this.registryVersion,
    required this.registrySha256,
    required this.snapshotSha256,
    required List<EvidenceSourceCurrencyClaimStatus> claimStatuses,
    required List<String> integrityReasons,
  }) : claimStatuses = List.unmodifiable(claimStatuses),
       integrityReasons = List.unmodifiable(integrityReasons);
}

final class EvidenceSourceCurrencyLookupService {
  final EvidenceCurrencyAssessment _assessment;

  EvidenceSourceCurrencyLookupService({
    required EvidenceCurrencyRegistry registry,
    required DateTime asOfUtc,
  }) : _assessment = registry.assess(asOfUtc: asOfUtc.toUtc());

  EvidenceSourceCurrencyStatusLookup lookup(SourceDocumentRecord source) {
    final reasons = _assessment.integrityReasons;
    if (reasons.isNotEmpty) {
      return EvidenceSourceCurrencyStatusLookup(
        sourceDocId: source.sourceDocId,
        state: EvidenceSourceCurrencyLookupState.registryIntegrityHold,
        asOfUtc: _assessment.asOfUtc,
        registrySchema: EvidenceCurrencyRegistry.schema,
        registryVersion: EvidenceCurrencyRegistry.registryVersion,
        registrySha256: _assessment.registrySha256,
        snapshotSha256: _assessment.snapshotSha256,
        claimStatuses: const <EvidenceSourceCurrencyClaimStatus>[],
        integrityReasons: reasons,
      );
    }

    final records =
        _assessment.records
            .where((record) => record.sourceId == source.sourceDocId)
            .toList(growable: false)
          ..sort((left, right) => left.claimId.compareTo(right.claimId));
    final statuses = records
        .map(
          (record) => EvidenceSourceCurrencyClaimStatus(
            record: record,
            effectiveStatus: record.effectiveStatusAt(_assessment.asOfUtc),
            disposition: record.dispositionAt(_assessment.asOfUtc),
          ),
        )
        .toList(growable: false);
    return EvidenceSourceCurrencyStatusLookup(
      sourceDocId: source.sourceDocId,
      state: statuses.isEmpty
          ? EvidenceSourceCurrencyLookupState.noRegisteredClaimRecord
          : EvidenceSourceCurrencyLookupState.linkedClaimRecords,
      asOfUtc: _assessment.asOfUtc,
      registrySchema: EvidenceCurrencyRegistry.schema,
      registryVersion: EvidenceCurrencyRegistry.registryVersion,
      registrySha256: _assessment.registrySha256,
      snapshotSha256: _assessment.snapshotSha256,
      claimStatuses: statuses,
      integrityReasons: const <String>[],
    );
  }
}
