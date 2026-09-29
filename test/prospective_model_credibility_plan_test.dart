import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  ProspectiveModelCredibilityPlan currentPlan() =>
      ProspectiveModelCredibilityPlan.current(
        manifest: MechanisticApplicabilityManifest.current,
        configurationSha256:
            AlgorithmConfigurationIdentity.defaults().sha256Digest,
      );

  test('current plan is identity-bound and independently fail-closed', () {
    final plan = currentPlan();

    expect(plan.integrityVerified, isTrue);
    expect(plan.integrityReasons, isEmpty);
    expect(plan.goals, hasLength(CredibilityFactor.values.length));
    expect(
      plan.prospectiveDecision.disposition,
      CredibilityAdequacyDisposition.blocked,
    );
    expect(
      plan.postStudyDecision.disposition,
      CredibilityAdequacyDisposition.notAssessed,
    );
    expect(plan.incompleteGoals, hasLength(7));
    expect(plan.canExecuteGovernedStudy, isFalse);
    expect(plan.canPromoteResearchTraceOnly, isFalse);
    expect(plan.planSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
  });

  test('every factor exposes dataset and independence identity', () {
    final plan = currentPlan();

    for (final goal in plan.goals) {
      expect(goal.datasetManifestId, isNotEmpty, reason: goal.factor.name);
      expect(
        goal.datasetSha256,
        matches(RegExp(r'^[a-f0-9]{64}$')),
        reason: goal.factor.name,
      );
      expect(goal.independenceGroupId, isNotEmpty, reason: goal.factor.name);
      expect(goal.acceptanceCriterion, isNotEmpty, reason: goal.factor.name);
      expect(
        goal.failureDisposition.toLowerCase(),
        contains('block'),
        reason: goal.factor.name,
      );
    }
  });

  test('an executed pass without result evidence fails integrity', () {
    final plan = currentPlan();
    final original = plan.goals.first;
    final forged = CredibilityGoal(
      factor: original.factor,
      targetGradation: original.targetGradation,
      rationale: original.rationale,
      plannedActivity: original.plannedActivity,
      acceptanceCriterion: original.acceptanceCriterion,
      observableId: original.observableId,
      datasetManifestId: original.datasetManifestId,
      datasetSha256: original.datasetSha256,
      independenceGroupId: original.independenceGroupId,
      applicabilityBoundary: original.applicabilityBoundary,
      independentReviewerRequired: original.independentReviewerRequired,
      expiresAtUtc: original.expiresAtUtc,
      failureDisposition: original.failureDisposition,
      status: CredibilityActivityStatus.executedPassed,
      resultArtifactIds: const [],
      resultReviewer: null,
      resultRecordedAtUtc: null,
    );

    expect(
      forged.integrityReasons,
      containsAll([
        'goal.${original.factor.name}.result_artifact_missing',
        'goal.${original.factor.name}.result_reviewer_missing',
        'goal.${original.factor.name}.result_time_invalid',
      ]),
    );
  });

  test('an unexecuted activity cannot carry hidden result artifacts', () {
    final forged = CredibilityGoal(
      factor: CredibilityFactor.humanFactors,
      targetGradation: 'independent_evidence_required',
      rationale: 'rationale',
      plannedActivity: 'activity',
      acceptanceCriterion: 'criterion',
      observableId: 'observable',
      datasetManifestId: 'dataset',
      datasetSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      independenceGroupId: 'independent',
      applicabilityBoundary: 'boundary',
      independentReviewerRequired: true,
      expiresAtUtc: '2026-12-31T23:59:59.000Z',
      failureDisposition: 'Block promotion.',
      status: CredibilityActivityStatus.held,
      resultArtifactIds: const ['hidden-result'],
      resultReviewer: 'reviewer',
      resultRecordedAtUtc: '2026-08-26T00:00:00.000Z',
    );

    expect(
      forged.integrityReasons,
      contains('goal.humanFactors.unexecuted_has_result'),
    );
  });

  test('configuration drift fails closed and cannot promote', () {
    final plan = ProspectiveModelCredibilityPlan.current(
      manifest: MechanisticApplicabilityManifest.current,
      configurationSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

    expect(
      plan.integrityReasons,
      containsAll(const [
        'plan.configuration_identity_mismatch',
        'plan.prospective_decision_identity_mismatch',
      ]),
    );
    expect(plan.canExecuteGovernedStudy, isFalse);
    expect(plan.canPromoteResearchTraceOnly, isFalse);
  });

  test('collections are immutable and JSON is deterministic and bounded', () {
    final plan = currentPlan();
    final first = jsonEncode(plan.toJson());
    final second = jsonEncode(currentPlan().toJson());

    expect(() => plan.goals.clear(), throwsUnsupportedError);
    expect(
      () => plan.goals.first.resultArtifactIds.add('forged'),
      throwsUnsupportedError,
    );
    expect(first, second);
    expect(first, contains('prospective_decision'));
    expect(first, contains('post_study_decision'));
    expect(first, contains('comparatorOrValidationData'));
    expect(first, contains('external-independent-study-required'));
    expect(first, isNot(contains('patient_id')));
  });
}
