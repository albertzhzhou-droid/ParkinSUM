import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/context_of_use_requalification.dart';
import 'package:parkinsum_companion/domain/entities/evidence_currency.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/source_access_contract.dart';

void main() {
  final reviewTime = DateTime.parse('2026-08-19T00:00:00Z');

  test(
    'current registry covers every live provider and remains trace-only',
    () {
      final registry = EvidenceCurrencyRegistry.current;
      final assessment = registry.assess(asOfUtc: reviewTime);
      final manifestProviders = MechanisticApplicabilityManifest
          .current
          .providers
          .map((provider) => provider.providerId)
          .toSet();
      final coveredProviders = registry.records
          .expand((record) => record.providerIds)
          .toSet();

      expect(registry.integrityReasons(), isEmpty);
      expect(coveredProviders, containsAll(manifestProviders));
      expect(assessment.requiresRequalification, isFalse);
      expect(assessment.blockedRecords, isEmpty);
      expect(assessment.heldRecords, isEmpty);
      expect(
        jsonEncode(assessment.toJson()),
        contains('not a validity, certainty, causality'),
      );
    },
  );

  test(
    'claim and status-authority identities exist in the source registry',
    () {
      final sourceRegistry = SourceAccessContract.fromJson(
        jsonDecode(
              File('config/source_access_registry.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      for (final record in EvidenceCurrencyRegistry.current.records) {
        expect(sourceRegistry.records, contains(record.sourceId));
        expect(
          sourceRegistry.records,
          contains(record.statusAuthoritySourceId),
        );
        expect(
          sourceRegistry
              .records[record.statusAuthoritySourceId]!
              .allowedForProduction,
          isFalse,
          reason: record.claimId,
        );
      }
    },
  );

  test(
    'retraction blocks every affected provider and opens requalification',
    () {
      final changed = EvidenceCurrencyRegistry(
        records: [
          EvidenceCurrencyRegistry.current.records.first.copyWith(
            status: EvidenceCurrencyStatus.retracted,
            updateNoticeId: 'pubmed:6694694:retraction-notice:fixture',
          ),
          ...EvidenceCurrencyRegistry.current.records.skip(1),
        ],
      );

      final assessment = changed.assess(asOfUtc: reviewTime);
      expect(changed.integrityReasons(), isEmpty);
      expect(assessment.requiresRequalification, isTrue);
      expect(assessment.blockedRecords, hasLength(1));
      expect(
        assessment.affectedProviderIds,
        contains('levodopa_absorption_opportunity'),
      );
      expect(
        assessment.blockedRecords.single.dispositionAt(reviewTime),
        EvidenceSunsetDisposition.blockAffectedProviders,
      );
    },
  );

  test('correction is held for review instead of silently accepted', () {
    final changed = EvidenceCurrencyRegistry(
      records: [
        EvidenceCurrencyRegistry.current.records.first.copyWith(
          status: EvidenceCurrencyStatus.corrected,
          updateNoticeId: 'crossmark:10.1056/example:correction',
        ),
        ...EvidenceCurrencyRegistry.current.records.skip(1),
      ],
    );

    final assessment = changed.assess(asOfUtc: reviewTime);
    expect(assessment.requiresRequalification, isTrue);
    expect(assessment.heldRecords, hasLength(1));
    expect(assessment.blockedRecords, isEmpty);
  });

  test('review expiry blocks without any code or manifest change', () {
    final changed = EvidenceCurrencyRegistry(
      records: [
        EvidenceCurrencyRegistry.current.records.first.copyWith(
          reviewByUtc: '2026-08-18T22:30:00Z',
        ),
        ...EvidenceCurrencyRegistry.current.records.skip(1),
      ],
    );

    final assessment = changed.assess(asOfUtc: reviewTime);
    expect(
      assessment.blockedRecords.single.effectiveStatusAt(reviewTime),
      EvidenceCurrencyStatus.expired,
    );
    expect(assessment.requiresRequalification, isTrue);
  });

  test(
    'future-observed status remains unknown before its observation time',
    () {
      final changed = EvidenceCurrencyRegistry(
        records: [
          EvidenceCurrencyRegistry.current.records.first.copyWith(
            observedAtUtc: '2026-08-19T00:00:01Z',
          ),
          ...EvidenceCurrencyRegistry.current.records.skip(1),
        ],
      );

      final assessment = changed.assess(asOfUtc: reviewTime);

      expect(changed.integrityReasons(), isEmpty);
      expect(assessment.blockedRecords, hasLength(1));
      expect(
        assessment.blockedRecords.single.effectiveStatusAt(reviewTime),
        EvidenceCurrencyStatus.unknown,
      );
      expect(assessment.requiresRequalification, isTrue);
    },
  );

  test('adverse status opens the context-of-use requalification ledger', () {
    final changed = EvidenceCurrencyRegistry(
      records: [
        EvidenceCurrencyRegistry.current.records.first.copyWith(
          status: EvidenceCurrencyStatus.expressionOfConcern,
          updateNoticeId: 'pubmed:6694694:expression-of-concern:fixture',
        ),
        ...EvidenceCurrencyRegistry.current.records.skip(1),
      ],
    );
    final ledger = ContextOfUseRequalificationLedger.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256:
          ContextOfUseRequalificationLedger.expectedCurrentConfigurationSha256,
      evidenceCurrencyRegistry: changed,
      evidenceAsOfUtc: reviewTime,
    );

    expect(ledger.canPromoteResearchTraceOnly, isFalse);
    expect(
      ledger.integrityReasons,
      contains(
        'ledger.evidence_currency_blocked:'
        'claim.meal_delay_direction.nutt_1984',
      ),
    );
  });

  test('noncurrent evidence without an update notice fails integrity', () {
    final base = EvidenceCurrencyRegistry.current.records.first;
    final malformed = EvidenceCurrencyRecord(
      claimId: base.claimId,
      claim: base.claim,
      sourceId: base.sourceId,
      doi: base.doi,
      pmid: base.pmid,
      regulatoryDocumentId: base.regulatoryDocumentId,
      sourceRevision: base.sourceRevision,
      providerIds: base.providerIds,
      predicateIds: base.predicateIds,
      status: EvidenceCurrencyStatus.expressionOfConcern,
      statusMethod: base.statusMethod,
      statusAuthoritySourceId: base.statusAuthoritySourceId,
      statusCheckUri: base.statusCheckUri,
      statusEvidenceIds: base.statusEvidenceIds,
      observedAtUtc: base.observedAtUtc,
      reviewByUtc: base.reviewByUtc,
      reviewer: base.reviewer,
      updateNoticeId: null,
      applicabilityBoundary: base.applicabilityBoundary,
    );

    expect(
      malformed.integrityReasons,
      contains('noncurrent_status_notice_missing:${base.claimId}'),
    );
  });

  test('status method cannot be rebound to an arbitrary authority or host', () {
    final base = EvidenceCurrencyRegistry.current.records.first;
    final forgedAuthority = base.copyWith(
      statusAuthoritySourceId: 'src.crossref.crossmark',
    );
    final forgedHost = base.copyWith(
      statusCheckUri: 'https://example.invalid/current',
    );

    expect(
      forgedAuthority.integrityReasons,
      contains('status_authority_method_mismatch:${base.claimId}'),
    );
    expect(
      forgedHost.integrityReasons,
      contains('status_authority_method_mismatch:${base.claimId}'),
    );
  });

  test('unknown providers and missing provider coverage fail closed', () {
    final changed = EvidenceCurrencyRegistry(
      records: [
        EvidenceCurrencyRegistry.current.records.first.copyWith(
          providerIds: const ['provider.not_registered'],
        ),
      ],
    );

    expect(
      changed.integrityReasons(),
      contains('provider_unknown:provider.not_registered'),
    );
    expect(
      changed.integrityReasons(),
      contains('provider_evidence_currency_missing:gastric_emptying'),
    );
  });

  test(
    'registry and assessment collections are immutable and deterministic',
    () {
      final registry = EvidenceCurrencyRegistry.current;
      final first = registry.assess(asOfUtc: reviewTime);
      final second = registry.assess(asOfUtc: reviewTime);

      expect(first.snapshotSha256, second.snapshotSha256);
      expect(first.toJson(), second.toJson());
      expect(
        () => registry.records.add(registry.records.first),
        throwsUnsupportedError,
      );
      expect(
        () => registry.records.first.providerIds.add('gastric_emptying'),
        throwsUnsupportedError,
      );
      expect(
        () => first.blockedRecords.add(registry.records.first),
        throwsUnsupportedError,
      );
    },
  );
}
