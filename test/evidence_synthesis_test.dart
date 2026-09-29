import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/evidence_currency.dart';
import 'package:parkinsum_companion/domain/entities/evidence_synthesis.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/source_access_contract.dart';

void main() {
  final asOfUtc = DateTime.parse('2026-08-19T00:00:00Z');

  EvidenceCurrencyAssessment currentCurrency() =>
      EvidenceCurrencyRegistry.current.assess(asOfUtc: asOfUtc);

  EvidenceStudyFinding finding({
    required String id,
    required String currencyClaimId,
    required String independenceGroupId,
    EvidenceFindingDirection direction = EvidenceFindingDirection.supports,
    String? outcomeId,
    String? measureId,
    EvidenceRiskOfBias riskOfBias = EvidenceRiskOfBias.low,
    EvidenceApplicability applicability = EvidenceApplicability.direct,
    EvidencePrecision precision = EvidencePrecision.precise,
    EvidenceReportingBias reportingBias = EvidenceReportingBias.unlikely,
  }) {
    final base = EvidenceSynthesisRegistry.current.bodies.first;
    final currencyRecord = EvidenceCurrencyRegistry.current.records.singleWhere(
      (record) => record.claimId == currencyClaimId,
    );
    return EvidenceStudyFinding(
      findingId: id,
      evidenceCurrencyClaimId: currencyClaimId,
      sourceRevision: currencyRecord.sourceRevision,
      independenceGroupId: independenceGroupId,
      studyDesign: EvidenceStudyDesign.observationalCohort,
      population: 'Synthetic bounded adjudicator fixture.',
      interventionOrExposure: 'Governed exposure fixture.',
      comparator: 'Governed comparator fixture.',
      outcomeId: outcomeId ?? base.expectedOutcomeId,
      measureId: measureId ?? base.expectedMeasureId,
      direction: direction,
      effectEstimate: null,
      lowerBound: null,
      upperBound: null,
      effectUnit: null,
      riskOfBias: riskOfBias,
      applicability: applicability,
      precision: precision,
      reportingBias: reportingBias,
      limitation: 'Synthetic test only; no clinical inference.',
    );
  }

  EvidenceFindingDependency dependency({
    required String firstFindingId,
    required String secondFindingId,
    EvidenceDependencyRelation relation = EvidenceDependencyRelation.sameCohort,
    EvidenceDependencyReviewState reviewState =
        EvidenceDependencyReviewState.confirmed,
  }) => EvidenceFindingDependency(
    firstFindingId: firstFindingId,
    secondFindingId: secondFindingId,
    relation: relation,
    reviewState: reviewState,
    sourceEvidenceIds: const ['artifact.dependency.review'],
    rationale: 'Synthetic source confirms or flags overlapping study data.',
  );

  EvidenceSynthesisBody reviewedBody({
    required List<EvidenceStudyFinding> findings,
    List<EvidenceFindingDependency> dependencies = const [],
    EvidenceSynthesisReviewState reviewState =
        EvidenceSynthesisReviewState.complete,
    EvidenceBodyCertainty certainty = EvidenceBodyCertainty.low,
    String reviewByUtc = '2027-02-18T22:00:00Z',
  }) {
    return EvidenceSynthesisRegistry.current.bodies.first.copyWith(
      findings: findings,
      dependencies: dependencies,
      declaredCertainty: certainty,
      reviewState: reviewState,
      reviewers: const ['reviewer.alpha', 'reviewer.beta'],
      reviewArtifactIds: const [
        'review.artifact.alpha',
        'review.artifact.beta',
      ],
      reviewedAtUtc: '2026-08-18T23:00:00Z',
      reviewByUtc: reviewByUtc,
      minimumIndependentFamilies: 2,
    );
  }

  EvidenceSynthesisRegistry replaceFirst(EvidenceSynthesisBody body) =>
      EvidenceSynthesisRegistry(
        bodies: [body, ...EvidenceSynthesisRegistry.current.bodies.skip(1)],
      );

  test(
    'current registry covers every provider and truthfully holds all bodies',
    () {
      final currency = currentCurrency();
      final registry = EvidenceSynthesisRegistry.current;
      final assessment = registry.assess(
        asOfUtc: asOfUtc,
        currencyAssessment: currency,
      );
      final providers = MechanisticApplicabilityManifest.current.providers
          .map((entry) => entry.providerId)
          .toSet();
      final covered = registry.bodies
          .expand((body) => body.providerIds)
          .toSet();

      expect(registry.integrityReasons(currencyAssessment: currency), isEmpty);
      expect(covered, containsAll(providers));
      expect(assessment.heldBodies, hasLength(registry.bodies.length));
      expect(assessment.blockedBodies, isEmpty);
      expect(assessment.requiresRequalification, isTrue);
      expect(
        jsonEncode(assessment.toJson()),
        contains('is not inferred from citation count'),
      );
    },
  );

  test(
    'review-method sources are explicit documentation-only registry entries',
    () {
      final sourceRegistry = SourceAccessContract.fromJson(
        jsonDecode(
              File('config/source_access_registry.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      for (final sourceId in const [
        'src.cochrane.handbook.chapter14',
        'src.ahrq.applicability.methods',
        'src.ahrq.strength-of-evidence.methods',
      ]) {
        final record = sourceRegistry.records[sourceId];
        expect(record, isNotNull, reason: sourceId);
        expect(record!.allowedForProduction, isFalse, reason: sourceId);
        expect(
          record.canSupportMechanismEvidenceAlone,
          isFalse,
          reason: sourceId,
        );
      }
    },
  );

  test('two independent reviewed findings can allow research trace only', () {
    final body = reviewedBody(
      findings: [
        finding(
          id: 'finding.synthetic.one',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[0].claimId,
          independenceGroupId: 'cohort.synthetic.one',
        ),
        finding(
          id: 'finding.synthetic.two',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[1].claimId,
          independenceGroupId: 'cohort.synthetic.two',
        ),
      ],
    );
    final assessment = replaceFirst(
      body,
    ).assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency());
    final adjudication = assessment.adjudications.first;

    expect(
      adjudication.disposition,
      EvidenceSynthesisDisposition.allowResearchTraceOnly,
    );
    expect(adjudication.independentFamilyCount, 2);
    expect(adjudication.reasons, isEmpty);
    expect(adjudication.body.declaredCertainty, EvidenceBodyCertainty.low);
  });

  test('directional contradiction blocks instead of averaging effects', () {
    final body = reviewedBody(
      findings: [
        finding(
          id: 'finding.synthetic.support',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[0].claimId,
          independenceGroupId: 'cohort.synthetic.support',
        ),
        finding(
          id: 'finding.synthetic.oppose',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[1].claimId,
          independenceGroupId: 'cohort.synthetic.oppose',
          direction: EvidenceFindingDirection.opposes,
        ),
      ],
    );
    final adjudication = replaceFirst(body)
        .assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency())
        .adjudications
        .first;

    expect(
      adjudication.disposition,
      EvidenceSynthesisDisposition.blockAffectedProviders,
    );
    expect(adjudication.reasons, contains('directional_conflict'));
    expect(adjudication.directionCounts[EvidenceFindingDirection.supports], 1);
    expect(adjudication.directionCounts[EvidenceFindingDirection.opposes], 1);
  });

  test('outcome and effect-measure mismatch block the body', () {
    final body = reviewedBody(
      findings: [
        finding(
          id: 'finding.synthetic.correct',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[0].claimId,
          independenceGroupId: 'cohort.synthetic.correct',
        ),
        finding(
          id: 'finding.synthetic.mismatch',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[1].claimId,
          independenceGroupId: 'cohort.synthetic.mismatch',
          outcomeId: 'different_outcome',
          measureId: 'different_measure',
        ),
      ],
    );
    final adjudication = replaceFirst(body)
        .assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency())
        .adjudications
        .first;

    expect(
      adjudication.disposition,
      EvidenceSynthesisDisposition.blockAffectedProviders,
    );
    expect(
      adjudication.reasons,
      containsAll(const [
        'outcome_mismatch:finding.synthetic.mismatch',
        'measure_mismatch:finding.synthetic.mismatch',
      ]),
    );
  });

  test('duplicate cohorts do not masquerade as independent consistency', () {
    final body = reviewedBody(
      findings: [
        finding(
          id: 'finding.synthetic.duplicate.one',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[0].claimId,
          independenceGroupId: 'cohort.synthetic.shared',
        ),
        finding(
          id: 'finding.synthetic.duplicate.two',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[1].claimId,
          independenceGroupId: 'cohort.synthetic.shared',
        ),
      ],
    );
    final adjudication = replaceFirst(body)
        .assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency())
        .adjudications
        .first;

    expect(
      adjudication.disposition,
      EvidenceSynthesisDisposition.holdForReview,
    );
    expect(adjudication.independentFamilyCount, 1);
    expect(adjudication.repeatedIndependenceGroupIds, [
      'cohort.synthetic.shared',
    ]);
    expect(adjudication.dependentFindingComponents, [
      ['finding.synthetic.duplicate.one', 'finding.synthetic.duplicate.two'],
    ]);
  });

  test('dependency edges coalesce cross-group findings transitively', () {
    final body = reviewedBody(
      findings: [
        finding(
          id: 'finding.synthetic.graph.a',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[0].claimId,
          independenceGroupId: 'cohort.synthetic.a',
        ),
        finding(
          id: 'finding.synthetic.graph.b',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[1].claimId,
          independenceGroupId: 'cohort.synthetic.b',
        ),
        finding(
          id: 'finding.synthetic.graph.c',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[2].claimId,
          independenceGroupId: 'cohort.synthetic.c',
        ),
      ],
      dependencies: [
        dependency(
          firstFindingId: 'finding.synthetic.graph.a',
          secondFindingId: 'finding.synthetic.graph.b',
        ),
        dependency(
          firstFindingId: 'finding.synthetic.graph.b',
          secondFindingId: 'finding.synthetic.graph.c',
          relation: EvidenceDependencyRelation.secondaryAnalysis,
        ),
      ],
    );
    final adjudication = replaceFirst(body)
        .assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency())
        .adjudications
        .first;

    expect(adjudication.independentFamilyCount, 1);
    expect(adjudication.dependentFindingComponents, [
      [
        'finding.synthetic.graph.a',
        'finding.synthetic.graph.b',
        'finding.synthetic.graph.c',
      ],
    ]);
    expect(
      adjudication.reasons,
      contains('independent_evidence_insufficient:1/2'),
    );
    expect(
      adjudication.disposition,
      EvidenceSynthesisDisposition.holdForReview,
    );
  });

  test('unresolved dependency links coalesce and hold the evidence body', () {
    final body = reviewedBody(
      findings: [
        finding(
          id: 'finding.synthetic.unresolved.a',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[0].claimId,
          independenceGroupId: 'cohort.synthetic.unresolved.a',
        ),
        finding(
          id: 'finding.synthetic.unresolved.b',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[1].claimId,
          independenceGroupId: 'cohort.synthetic.unresolved.b',
        ),
      ],
      dependencies: [
        dependency(
          firstFindingId: 'finding.synthetic.unresolved.a',
          secondFindingId: 'finding.synthetic.unresolved.b',
          reviewState: EvidenceDependencyReviewState.unresolved,
        ),
      ],
    );
    final adjudication = replaceFirst(body)
        .assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency())
        .adjudications
        .first;

    expect(adjudication.independentFamilyCount, 1);
    expect(
      adjudication.reasons,
      contains(
        'dependency_link_unresolved:finding.synthetic.unresolved.a|'
        'finding.synthetic.unresolved.b:sameCohort',
      ),
    );
    expect(
      adjudication.disposition,
      EvidenceSynthesisDisposition.holdForReview,
    );
  });

  test(
    'dependency identity is undirected while reversed duplicates and unknown endpoints block',
    () {
      final firstId = 'finding.synthetic.identity.a';
      final secondId = 'finding.synthetic.identity.b';
      EvidenceSynthesisBody bodyWith(EvidenceFindingDependency edge) =>
          reviewedBody(
            findings: [
              finding(
                id: firstId,
                currencyClaimId:
                    EvidenceCurrencyRegistry.current.records[0].claimId,
                independenceGroupId: 'cohort.synthetic.identity.a',
              ),
              finding(
                id: secondId,
                currencyClaimId:
                    EvidenceCurrencyRegistry.current.records[1].claimId,
                independenceGroupId: 'cohort.synthetic.identity.b',
              ),
            ],
            dependencies: [edge],
          );
      final forward = bodyWith(
        dependency(firstFindingId: firstId, secondFindingId: secondId),
      );
      final reverse = bodyWith(
        dependency(firstFindingId: secondId, secondFindingId: firstId),
      );
      final unknownEndpoint = bodyWith(
        dependency(firstFindingId: firstId, secondFindingId: 'finding.unknown'),
      );
      final duplicateReverse = forward.copyWith(
        dependencies: [
          forward.dependencies.single,
          dependency(firstFindingId: secondId, secondFindingId: firstId),
        ],
      );

      expect(forward.bodySha256, reverse.bodySha256);
      expect(
        replaceFirst(duplicateReverse)
            .assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency())
            .adjudications
            .first
            .reasons,
        contains(
          'body_dependency_duplicate:${forward.claimId}:$firstId|$secondId:sameCohort',
        ),
      );
      expect(
        replaceFirst(unknownEndpoint)
            .assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency())
            .adjudications
            .first
            .disposition,
        EvidenceSynthesisDisposition.blockAffectedProviders,
      );
    },
  );

  test(
    'indirect and very imprecise evidence is held, not upgraded by count',
    () {
      final body = reviewedBody(
        findings: [
          finding(
            id: 'finding.synthetic.indirect',
            currencyClaimId:
                EvidenceCurrencyRegistry.current.records[0].claimId,
            independenceGroupId: 'cohort.synthetic.indirect',
            applicability: EvidenceApplicability.indirect,
          ),
          finding(
            id: 'finding.synthetic.imprecise',
            currencyClaimId:
                EvidenceCurrencyRegistry.current.records[1].claimId,
            independenceGroupId: 'cohort.synthetic.imprecise',
            precision: EvidencePrecision.veryImprecise,
          ),
        ],
      );
      final adjudication = replaceFirst(body)
          .assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency())
          .adjudications
          .first;

      expect(
        adjudication.disposition,
        EvidenceSynthesisDisposition.holdForReview,
      );
      expect(
        adjudication.reasons,
        containsAll(const [
          'indirect_applicability:finding.synthetic.indirect',
          'very_imprecise:finding.synthetic.imprecise',
        ]),
      );
    },
  );

  test('null, opposing, and adverse findings remain separately observable', () {
    final body = reviewedBody(
      findings: [
        finding(
          id: 'finding.synthetic.null',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[0].claimId,
          independenceGroupId: 'cohort.synthetic.null',
          direction: EvidenceFindingDirection.nullFinding,
        ),
        finding(
          id: 'finding.synthetic.adverse',
          currencyClaimId: EvidenceCurrencyRegistry.current.records[1].claimId,
          independenceGroupId: 'cohort.synthetic.adverse',
          direction: EvidenceFindingDirection.adverse,
        ),
      ],
    );
    final adjudication = replaceFirst(body)
        .assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency())
        .adjudications
        .first;

    expect(
      adjudication.disposition,
      EvidenceSynthesisDisposition.blockAffectedProviders,
    );
    expect(adjudication.reasons, contains('adverse_finding_present'));
    expect(
      adjudication.directionCounts[EvidenceFindingDirection.nullFinding],
      1,
    );
    expect(adjudication.directionCounts[EvidenceFindingDirection.adverse], 1);
  });

  test('review disagreement and expiry hold an otherwise coherent body', () {
    final findings = [
      finding(
        id: 'finding.synthetic.review.one',
        currencyClaimId: EvidenceCurrencyRegistry.current.records[0].claimId,
        independenceGroupId: 'cohort.synthetic.review.one',
      ),
      finding(
        id: 'finding.synthetic.review.two',
        currencyClaimId: EvidenceCurrencyRegistry.current.records[1].claimId,
        independenceGroupId: 'cohort.synthetic.review.two',
      ),
    ];
    final disagreement = replaceFirst(
      reviewedBody(
        findings: findings,
        reviewState: EvidenceSynthesisReviewState.reviewerDisagreement,
      ),
    ).assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency());
    final expired = replaceFirst(
      reviewedBody(findings: findings, reviewByUtc: '2026-08-18T23:30:00Z'),
    ).assess(asOfUtc: asOfUtc, currencyAssessment: currentCurrency());

    expect(
      disagreement.adjudications.first.reasons,
      contains('review_state:reviewerDisagreement'),
    );
    expect(
      expired.adjudications.first.reasons,
      contains('body_review_expired'),
    );
  });

  test('withdrawn source blocks every synthesis body that consumes it', () {
    final base = EvidenceCurrencyRegistry.current.records.first;
    final currency = EvidenceCurrencyRegistry(
      records: [
        base.copyWith(
          status: EvidenceCurrencyStatus.withdrawn,
          updateNoticeId: 'pubmed:6694694:withdrawal:fixture',
        ),
        ...EvidenceCurrencyRegistry.current.records.skip(1),
      ],
    ).assess(asOfUtc: asOfUtc);
    final assessment = EvidenceSynthesisRegistry.current.assess(
      asOfUtc: asOfUtc,
      currencyAssessment: currency,
    );

    expect(
      assessment.adjudications.first.disposition,
      EvidenceSynthesisDisposition.blockAffectedProviders,
    );
    expect(
      assessment.adjudications.first.reasons,
      contains('currency_claim_blocked:${base.claimId}'),
    );
  });

  test(
    'collections and canonical snapshots are immutable and deterministic',
    () {
      final registry = EvidenceSynthesisRegistry.current;
      final first = registry.assess(
        asOfUtc: asOfUtc,
        currencyAssessment: currentCurrency(),
      );
      final second = registry.assess(
        asOfUtc: asOfUtc,
        currencyAssessment: currentCurrency(),
      );

      expect(first.snapshotSha256, second.snapshotSha256);
      expect(first.toJson(), second.toJson());
      expect(
        () => registry.bodies.add(registry.bodies.first),
        throwsUnsupportedError,
      );
      expect(
        () => registry.bodies.first.findings.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => first.adjudications.first.directionCounts.clear(),
        throwsUnsupportedError,
      );
    },
  );
}
