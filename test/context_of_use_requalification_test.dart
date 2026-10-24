import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/context_of_use_requalification.dart';
import 'package:parkinsum_companion/domain/entities/evidence_synthesis.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';

void main() {
  final evidenceAsOfUtc = DateTime.parse('2026-08-19T00:00:00Z');

  ContextOfUseRequalificationLedger currentLedger() {
    return ContextOfUseRequalificationLedger.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256:
          AlgorithmConfigurationIdentity.defaults().sha256Digest,
      evidenceAsOfUtc: evidenceAsOfUtc,
    );
  }

  test('bound configuration and evidence registry retain evidence holds', () {
    final ledger = currentLedger();

    expect(
      ledger.currentImpact.semanticDiffSha256,
      ContextOfUseRequalificationLedger.expectedInitialSemanticDiffSha256,
    );
    expect(
      ledger.currentConfigurationSha256,
      AlgorithmConfigurationIdentity.defaults().sha256Digest,
    );
    expect(
      ledger.currentConfigurationSha256,
      ContextOfUseRequalificationLedger.expectedCurrentConfigurationSha256,
    );
    expect(ledger.integrityReasons, isEmpty);
    expect(
      ledger.evidenceSynthesisAssessment.registrySha256,
      '3c64c10bc76d1307bf7bdaf16abf8e33b21028929c369cf660cb6296f3f9292c',
    );
    expect(ledger.integrityVerified, isTrue);
    expect(ledger.evidenceSynthesisAssessment.heldBodies, hasLength(5));
    expect(ledger.evidenceSynthesisAssessment.blockedBodies, isEmpty);
    expect(ledger.evidenceSynthesisAssessment.requiresRequalification, isTrue);
    expect(
      ledger.latest.releaseDisposition,
      CouReleaseDisposition.blockedPendingEvidence,
    );
    expect(ledger.canPromoteResearchTraceOnly, isFalse);
    expect(
      ledger.incompleteRequiredEvidence,
      containsAll(const [
        CouEvidenceKind.humanFactors,
        CouEvidenceKind.independentReview,
        CouEvidenceKind.modelQualification,
        CouEvidenceKind.scientificValidation,
        CouEvidenceKind.uncertaintyAssessment,
      ]),
    );
    expect(ledger.latest.recordSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(ledger.canPromoteResearchTraceOnly, isFalse);
  });

  test('status lanes never infer validation or approval from tests', () {
    final decisions = {
      for (final decision in currentLedger().latest.evidenceDecisions)
        decision.kind: decision.status,
    };

    expect(
      decisions[CouEvidenceKind.implementationVerification],
      CouEvidenceStatus.complete,
    );
    expect(
      decisions[CouEvidenceKind.calculationVerification],
      CouEvidenceStatus.complete,
    );
    expect(
      decisions[CouEvidenceKind.scientificValidation],
      CouEvidenceStatus.missing,
    );
    expect(
      decisions[CouEvidenceKind.modelQualification],
      CouEvidenceStatus.missing,
    );
    expect(
      decisions[CouEvidenceKind.regulatoryReview],
      CouEvidenceStatus.notRequired,
    );
    expect(
      decisions[CouEvidenceKind.externalApproval],
      CouEvidenceStatus.notRequired,
    );
  });

  test(
    'v84 candidate retains all thirty-two historical blocked records without new approval',
    () {
      final ledger = currentLedger();
      final historical = ledger.records.first;
      final candidate = ledger.latest;

      expect(ledger.records, hasLength(33));
      expect(historical.sequence, 1);
      expect(historical.changeKind, 'initial_governed_baseline');
      expect(
        historical.currentConfigurationSha256,
        'e75f4fbe20af2cecb6da8e88034ca7a0da4958571a0cecdd8613a3236ceffe05',
      );
      expect(historical.recordedAtUtc, '2026-08-18T00:00:00.000Z');
      expect(historical.decisionBoundary, contains('v52 release refresh'));
      expect(candidate.sequence, 33);
      expect(
        ledger.records[1].currentConfigurationSha256,
        ContextOfUseRequalificationLedger.historicalV53ConfigurationSha256,
      );
      expect(
        ledger.records[1].releaseArtifact,
        'unreleased-worktree:next-upgrade-v53-candidate',
      );
      expect(candidate.changeKind, 'software_identity_candidate_rebind');
      expect(ledger.records.take(10).map((r) => r.recordSha256).toList(), [
        'b8b6484c3b3a33d893878907db537fa29fbc4e0c6eb844ba8a5fe772fe346ae0',
        'b2993ef5f2308e192e4a73b92f80ee14612063df88591ea11147caf668845aa2',
        '3bebb51fb02349ce3f9db89826f453f4fddb163fb383ec3641a312b793ce6e52',
        '7537fd6d52b7a46ccfc801ee4078af3063838b8e94e4f27bd8d8b07158397a2f',
        '192a5e0694f6f99c08c531d24c45536575e1d2630932d1911e8e4d458c95c86e',
        '38ec4437d564fc29bfa76ea06de19fcb3496969562e193e8ceabcbb516ca0862',
        'f3956907bd3a8c3e7366fbdebff6c42288077c5345c753b56278c7d8585a0b5f',
        '288d50058d686d80b384f7765e8594feea4bb2e5cd5d2bde74054596c27a74cf',
        'ea0fd31ab95056be8b8e72667d75c6e581cb2d2a6aff52a8cf6010d926c4b219',
        '902fc543a2c0aa2502a42215e02cc74c07450030f7e25d4d1dbdd1f1182b0344',
      ], reason: 'Exact prior records were frozen before this forward rebind.');
      expect(
        candidate.previousConfigurationSha256,
        ledger.records[31].currentConfigurationSha256,
      );
      expect(
        candidate.currentConfigurationSha256,
        AlgorithmConfigurationIdentity.defaults().sha256Digest,
      );
      expect(candidate.evidenceDecisions, historical.evidenceDecisions);
      expect(candidate.approvalSignature, isNull);
      expect(
        candidate.releaseDisposition,
        CouReleaseDisposition.blockedPendingEvidence,
      );
      expect(ledger.canPromoteResearchTraceOnly, isFalse);
    },
  );

  test('historical v52 identity is not accepted as the current candidate', () {
    final ledger = ContextOfUseRequalificationLedger.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256:
          'e75f4fbe20af2cecb6da8e88034ca7a0da4958571a0cecdd8613a3236ceffe05',
      evidenceAsOfUtc: evidenceAsOfUtc,
    );

    expect(
      ledger.integrityReasons,
      containsAll(const [
        'ledger.current_configuration_identity_mismatch',
        'ledger.latest_configuration_mismatch',
      ]),
    );
    expect(ledger.integrityVerified, isFalse);
    expect(ledger.canPromoteResearchTraceOnly, isFalse);
  });

  test(
    'semantic changes require proportionate evidence without carry-over',
    () {
      final manifest = MechanisticApplicabilityManifest.current;
      final previous = Map<String, Object?>.from(manifest.canonicalPayload);
      final current = Map<String, Object?>.from(manifest.canonicalPayload)
        ..['observable_boundary'] =
            'A changed patient-specific concentration prediction.';

      final impact = CouManifestSemanticDiff.between(
        previous: previous,
        current: current,
        currentProviderIds: manifest.providers.map((entry) => entry.providerId),
        currentPredicateIds: manifest.predicates.map((entry) => entry.id),
      );

      expect(impact.changes, hasLength(1));
      expect(impact.changes.single.path, 'observable_boundary');
      expect(impact.changeClasses, contains(CouChangeClass.observable));
      expect(impact.modelRisk, CouModelRisk.critical);
      expect(
        impact.requiredEvidence,
        containsAll(const [
          CouEvidenceKind.calculationVerification,
          CouEvidenceKind.humanFactors,
          CouEvidenceKind.independentReview,
          CouEvidenceKind.modelQualification,
          CouEvidenceKind.scientificValidation,
          CouEvidenceKind.uncertaintyAssessment,
        ]),
      );
    },
  );

  test('configuration-only drift still requires reviewed verification', () {
    final manifest = MechanisticApplicabilityManifest.current;
    final payload = Map<String, Object?>.from(manifest.canonicalPayload);
    final impact = CouManifestSemanticDiff.between(
      previous: payload,
      current: payload,
      currentProviderIds: const [],
      currentPredicateIds: const [],
      configurationChanged: true,
    );

    expect(impact.changes, isEmpty);
    expect(impact.changeClasses, {CouChangeClass.configurationIdentity});
    expect(impact.modelRisk, CouModelRisk.moderate);
    expect(impact.requiredEvidence, {
      CouEvidenceKind.implementationVerification,
      CouEvidenceKind.calculationVerification,
      CouEvidenceKind.independentReview,
    });
  });

  test('unrecorded configuration drift fails closed before promotion', () {
    final ledger = ContextOfUseRequalificationLedger.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      evidenceAsOfUtc: evidenceAsOfUtc,
    );

    expect(
      ledger.integrityReasons,
      containsAll(const [
        'ledger.current_configuration_identity_mismatch',
        'ledger.latest_configuration_mismatch',
      ]),
    );
    expect(ledger.integrityVerified, isFalse);
    expect(ledger.canPromoteResearchTraceOnly, isFalse);
  });

  test('unrecorded evidence registry drift fails closed before promotion', () {
    final bodies = EvidenceSynthesisRegistry.current.bodies;
    final changedRegistry = EvidenceSynthesisRegistry(
      bodies: [
        bodies.first.copyWith(
          reviewArtifactIds: [
            ...bodies.first.reviewArtifactIds,
            'synthetic.unrecorded-review-artifact',
          ],
        ),
        ...bodies.skip(1),
      ],
    );
    final ledger = ContextOfUseRequalificationLedger.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256:
          AlgorithmConfigurationIdentity.defaults().sha256Digest,
      evidenceAsOfUtc: evidenceAsOfUtc,
      evidenceSynthesisRegistry: changedRegistry,
    );

    expect(
      ledger.integrityReasons,
      containsAll(const [
        'ledger.evidence_synthesis_registry_identity_mismatch',
        'ledger.latest_evidence_synthesis_registry_mismatch',
      ]),
    );
    expect(ledger.integrityVerified, isFalse);
    expect(ledger.canPromoteResearchTraceOnly, isFalse);
    expect(
      ledger.latest.releaseDisposition,
      CouReleaseDisposition.blockedPendingEvidence,
    );
  });

  test('committed record and evidence collections are immutable', () {
    final ledger = currentLedger();

    expect(() => ledger.records.add(ledger.latest), throwsUnsupportedError);
    expect(
      () => ledger.latest.evidenceDecisions.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => ledger.currentImpact.affectedProviderIds.add('forged-provider'),
      throwsUnsupportedError,
    );
  });

  test('ledger JSON is deterministic, bounded, and explicit about hold', () {
    final ledger = currentLedger();
    final first = jsonEncode(ledger.toJson());
    final second = jsonEncode(currentLedger().toJson());

    expect(second, first);
    expect(first, contains('blockedPendingEvidence'));
    expect(first, contains('scientificValidation'));
    expect(first, contains('modelQualification'));
    expect(first, contains('can_promote_research_trace_only'));
    expect(first, contains('evidence_synthesis_assessment'));
    expect(first, contains('body_certainty_not_assessed'));
    expect(first, isNot(contains('patient_id')));
  });
}
