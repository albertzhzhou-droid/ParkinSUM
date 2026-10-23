import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/credibility_evidence_execution_attestation.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  const verifier = CredibilityEvidenceIndependenceVerifier();

  CredibilityEvidenceExecutionAttestation current() {
    final configuration = AlgorithmConfigurationIdentity.defaults();
    final plan = ProspectiveModelCredibilityPlan.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256: configuration.sha256Digest,
    );
    return CredibilityEvidenceExecutionAttestation.syntheticCurrent(
      prospectivePlanSha256: plan.planSha256,
      manifestSha256: MechanisticApplicabilityManifest.current.sha256Digest,
      configurationSha256: configuration.sha256Digest,
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
  }

  test(
    'synthetic fixture pins exact v84 software identity without qualification',
    () {
      const expectedConfiguration =
          '63bb983915c2f6517878da99ecd497f4990dda44f9718ed77cc956046de1de5f';
      const expectedSourceBundle =
          'f080610fb9b7959b3a691ca4fddddd77b7b51466211722b41a4ec20100362e44';
      final fixture = current();

      expect(AlgorithmConfigurationIdentity.defaultVersion, '2026.10.20-v84');
      expect(fixture.configurationSha256, expectedConfiguration);
      expect(fixture.algorithmSourceBundleSha256, expectedSourceBundle);
      expect(
        CredibilityEvidenceExecutionAttestation.expectedConfigurationSha256,
        expectedConfiguration,
      );
      expect(
        CredibilityEvidenceExecutionAttestation
            .expectedAlgorithmSourceBundleSha256,
        expectedSourceBundle,
      );
      expect(fixture.integrityReasons, isEmpty);
      expect(fixture.independentReviewer, isNull);
      expect(fixture.independentReviewArtifactIds, isEmpty);
      expect(verifier.verify(fixture).canSupportScientificCredibility, isFalse);
    },
  );

  test('historical v52 software identities remain rejected independently', () {
    final fixture = current();
    final mutations = <String, CredibilityEvidenceExecutionAttestation>{
      'attestation.configuration_identity_mismatch':
          CredibilityEvidenceExecutionAttestation.syntheticCurrent(
            prospectivePlanSha256: fixture.prospectivePlanSha256,
            manifestSha256: fixture.manifestSha256,
            configurationSha256:
                'e75f4fbe20af2cecb6da8e88034ca7a0da4958571a0cecdd8613a3236ceffe05',
            algorithmSourceBundleSha256: fixture.algorithmSourceBundleSha256,
          ),
      'attestation.algorithm_source_bundle_identity_mismatch':
          CredibilityEvidenceExecutionAttestation.syntheticCurrent(
            prospectivePlanSha256: fixture.prospectivePlanSha256,
            manifestSha256: fixture.manifestSha256,
            configurationSha256: fixture.configurationSha256,
            algorithmSourceBundleSha256:
                '8f05e6ff6ad02ace71b621ea840cb795831d63562ebd91b54ae8139ab999dcc2',
          ),
    };

    for (final mutation in mutations.entries) {
      expect(mutation.value.integrityReasons, [mutation.key]);
      final assessment = verifier.verify(mutation.value);
      expect(assessment.integrityVerified, isFalse);
      expect(assessment.status, EvidenceIndependenceStatus.unknown);
      expect(assessment.canSupportScientificCredibility, isFalse);
    }
  });

  test(
    'synthetic execution is mechanically observed but cannot qualify data',
    () {
      final assessment = verifier.verify(current());

      expect(assessment.integrityVerified, isTrue);
      expect(assessment.findings, isEmpty);
      expect(
        assessment.status,
        EvidenceIndependenceStatus.mechanicallyObserved,
      );
      expect(
        assessment.dimensionStatuses.values,
        everyElement(EvidenceIndependenceStatus.mechanicallyObserved),
      );
      expect(assessment.canSupportScientificCredibility, isFalse);
      expect(assessment.attestation.syntheticDemoOnly, isTrue);
    },
  );

  test(
    'subject, relation, site, acquisition, device, and row overlap fail',
    () {
      final base = current();
      final first = base.records.first;
      final last = base.records.last;
      final forged = base.copyWith(
        records: [
          ...base.records.take(base.records.length - 1),
          last.copyWith(
            subjectGroupId: first.subjectGroupId,
            relatedSubjectGroupId: first.relatedSubjectGroupId,
            siteId: first.siteId,
            acquisitionId: first.acquisitionId,
            deviceId: first.deviceId,
            sourceRowSha256: first.sourceRowSha256,
          ),
        ],
      );

      final kinds = verifier
          .verify(forged)
          .findings
          .map((finding) => finding.kind);
      expect(
        kinds,
        containsAll(const [
          EvidenceLeakageKind.duplicateSubject,
          EvidenceLeakageKind.relatedSubjectAcrossSplits,
          EvidenceLeakageKind.siteAcrossSplits,
          EvidenceLeakageKind.acquisitionAcrossSplits,
          EvidenceLeakageKind.deviceAcrossSplits,
          EvidenceLeakageKind.sourceRowAcrossSplits,
        ]),
      );
    },
  );

  test('target, future, and non-development preprocessing all fail', () {
    final base = current();
    final forged = base.copyWith(
      transformations: [
        base.transformations.first.copyWith(
          fittedOnSplits: const [
            EvidenceSplitRole.fit,
            EvidenceSplitRole.lockedTest,
          ],
          usesTarget: true,
          usesFutureInformation: true,
        ),
      ],
    );

    final kinds = verifier
        .verify(forged)
        .findings
        .map((finding) => finding.kind);
    expect(
      kinds,
      containsAll(const [
        EvidenceLeakageKind.targetDerivedFeature,
        EvidenceLeakageKind.futureDerivedFeature,
        EvidenceLeakageKind.preprocessingFitOutsideDevelopment,
      ]),
    );
  });

  test('holdout access before plan freeze and unauthorized access fail', () {
    final base = current();
    final access = base.accessEvents.map((event) {
      if (event.action == EvidenceAccessAction.lockedHoldoutRead) {
        return event.copyWith(
          occurredAtUtc: '2026-08-18T00:01:00.000Z',
          authorized: false,
        );
      }
      return event;
    }).toList();

    final kinds = verifier
        .verify(base.copyWith(accessEvents: access))
        .findings
        .map((finding) => finding.kind);
    expect(
      kinds,
      containsAll(const [
        EvidenceLeakageKind.accessBeforePlanFreeze,
        EvidenceLeakageKind.unauthorizedAccess,
      ]),
    );
  });

  test('result-aware plan amendment and selective omission remain visible', () {
    final base = current();
    final amendment = EvidenceAccessEvent(
      sequence: base.accessEvents.length + 1,
      actorId: 'synthetic-governance-runner',
      role: 'plan-owner',
      action: EvidenceAccessAction.planAmendment,
      split: null,
      occurredAtUtc: '2026-08-18T00:30:00.000Z',
      authorized: true,
    );
    final assessment = verifier.verify(
      base.copyWith(
        accessEvents: [...base.accessEvents, amendment],
        reportedOutcomeIds: base.reportedOutcomeIds.take(1).toList(),
      ),
    );

    expect(assessment.status, EvidenceIndependenceStatus.violated);
    expect(
      assessment.findings.map((finding) => finding.kind),
      containsAll(const [
        EvidenceLeakageKind.resultAwarePlanAmendment,
        EvidenceLeakageKind.selectiveOutcomeOmission,
      ]),
    );
  });

  test('configuration drift and revocation fail closed', () {
    final configuration = AlgorithmConfigurationIdentity.defaults();
    final plan = ProspectiveModelCredibilityPlan.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256: configuration.sha256Digest,
    );
    final drifted = CredibilityEvidenceExecutionAttestation.syntheticCurrent(
      prospectivePlanSha256: plan.planSha256,
      manifestSha256: MechanisticApplicabilityManifest.current.sha256Digest,
      configurationSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      algorithmSourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
    );
    final driftedAssessment = verifier.verify(drifted);

    expect(
      drifted.integrityReasons,
      contains('attestation.configuration_identity_mismatch'),
    );
    expect(driftedAssessment.status, EvidenceIndependenceStatus.unknown);
    expect(
      verifier.verify(current().copyWith(revoked: true)).status,
      EvidenceIndependenceStatus.revoked,
    );
  });

  test(
    'missing split identity remains unknown instead of fabricated clean',
    () {
      final base = current();
      final assessment = verifier.verify(
        base.copyWith(
          records: base.records
              .where((record) => record.split != EvidenceSplitRole.lockedTest)
              .toList(),
        ),
      );

      expect(assessment.status, EvidenceIndependenceStatus.unknown);
      expect(
        assessment.dimensionStatuses.values,
        everyElement(EvidenceIndependenceStatus.unknown),
      );
      expect(assessment.canSupportScientificCredibility, isFalse);
    },
  );

  test('collections are immutable and JSON is deterministic and bounded', () {
    final attestation = current();
    final first = jsonEncode(verifier.verify(attestation).toJson());
    final second = jsonEncode(verifier.verify(current()).toJson());

    expect(() => attestation.records.clear(), throwsUnsupportedError);
    expect(() => attestation.accessEvents.clear(), throwsUnsupportedError);
    expect(first, second);
    expect(first, contains('mechanicallyObserved'));
    expect(first, contains('lockedTest'));
    expect(first, contains('synthetic_demo_only'));
    expect(first, isNot(contains('patient_id')));
  });
}
