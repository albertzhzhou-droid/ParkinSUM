import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/context_of_use_requalification.dart';
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

  test('unrecorded configuration and evidence registry drift fails closed', () {
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
      isNot(
        ContextOfUseRequalificationLedger.expectedCurrentConfigurationSha256,
      ),
    );
    expect(
      ledger.integrityReasons,
      containsAll(const [
        'ledger.current_configuration_identity_mismatch',
        'ledger.evidence_synthesis_registry_identity_mismatch',
        'ledger.latest_configuration_mismatch',
        'ledger.latest_evidence_synthesis_registry_mismatch',
      ]),
    );
    expect(
      ledger.evidenceSynthesisAssessment.registrySha256,
      '3c64c10bc76d1307bf7bdaf16abf8e33b21028929c369cf660cb6296f3f9292c',
    );
    expect(ledger.integrityVerified, isFalse);
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
