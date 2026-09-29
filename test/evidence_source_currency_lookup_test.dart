import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/evidence_currency.dart';
import 'package:parkinsum_companion/domain/usecases/evidence_source_currency_lookup.dart';

void main() {
  final asOfUtc = DateTime.parse('2026-09-27T12:00:00Z');

  test('links only exact source identity and retains claim review context', () {
    final service = EvidenceSourceCurrencyLookupService(
      registry: EvidenceCurrencyRegistry.current,
      asOfUtc: asOfUtc,
    );

    final lookup = service.lookup(_source('src.nutt.onoff.1984'));

    expect(lookup.state, EvidenceSourceCurrencyLookupState.linkedClaimRecords);
    expect(lookup.claimStatuses, hasLength(1));
    expect(
      lookup.claimStatuses.single.record.claimId,
      'claim.meal_delay_direction.nutt_1984',
    );
    expect(
      lookup.claimStatuses.single.record.sourceRevision,
      'pubmed-record-6694694',
    );
    expect(
      lookup.claimStatuses.single.effectiveStatus,
      EvidenceCurrencyStatus.current,
    );
    expect(
      lookup.claimStatuses.single.disposition,
      EvidenceSunsetDisposition.allowResearchTraceOnly,
    );
    expect(lookup.asOfUtc, asOfUtc);
    expect(lookup.registrySha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(lookup.snapshotSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(lookup.integrityReasons, isEmpty);
  });

  test(
    'an unregistered or near-matching source stays explicitly unassessed',
    () {
      final service = EvidenceSourceCurrencyLookupService(
        registry: EvidenceCurrencyRegistry.current,
        asOfUtc: asOfUtc,
      );

      final unregistered = service.lookup(_source('synthetic-source'));
      final nearMatch = service.lookup(_source('src.nutt.onoff.1984-copy'));

      expect(
        unregistered.state,
        EvidenceSourceCurrencyLookupState.noRegisteredClaimRecord,
      );
      expect(unregistered.claimStatuses, isEmpty);
      expect(
        nearMatch.state,
        EvidenceSourceCurrencyLookupState.noRegisteredClaimRecord,
      );
      expect(nearMatch.claimStatuses, isEmpty);
    },
  );

  test('future-observed claim status projects as unknown and blocked', () {
    final records = EvidenceCurrencyRegistry.current.records;
    final registry = EvidenceCurrencyRegistry(
      records: [
        records.first.copyWith(observedAtUtc: '2026-09-28T00:00:00Z'),
        ...records.skip(1),
      ],
    );
    final service = EvidenceSourceCurrencyLookupService(
      registry: registry,
      asOfUtc: asOfUtc,
    );

    final lookup = service.lookup(_source(records.first.sourceId));

    expect(lookup.state, EvidenceSourceCurrencyLookupState.linkedClaimRecords);
    expect(
      lookup.claimStatuses.single.effectiveStatus,
      EvidenceCurrencyStatus.unknown,
    );
    expect(
      lookup.claimStatuses.single.disposition,
      EvidenceSunsetDisposition.blockAffectedProviders,
    );
  });

  test('registry integrity failure withholds all linked claim statuses', () {
    final records = EvidenceCurrencyRegistry.current.records;
    final service = EvidenceSourceCurrencyLookupService(
      registry: EvidenceCurrencyRegistry(records: [...records, records.first]),
      asOfUtc: asOfUtc,
    );

    final lookup = service.lookup(_source(records.first.sourceId));

    expect(
      lookup.state,
      EvidenceSourceCurrencyLookupState.registryIntegrityHold,
    );
    expect(lookup.claimStatuses, isEmpty);
    expect(lookup.integrityReasons, isNotEmpty);
  });
}

SourceDocumentRecord _source(String id) => SourceDocumentRecord(
  sourceDocId: id,
  sourceFamily: 'SYNTHETIC',
  dataTier: KnowledgeDataTier.p4,
  ingestionStrategy: SourceIngestionStrategy.clinicalEvidenceCard,
  organization: 'Synthetic research group',
  jurisdiction: 'ZZ',
  docType: 'paper',
  title: 'Synthetic evidence record',
  originUrl: 'https://example.org/source',
  publishedAt: DateTime.utc(2026),
  effectiveAt: null,
  language: 'en',
  licenseNote: 'Synthetic fixture only',
  checksum: 'synthetic-checksum',
  sourceStatus: 'current',
  rawPayload: 'must not be inspected',
);
