import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'evidence_currency.dart';
import 'evidence_synthesis.dart';
import 'mechanistic_medication_applicability.dart';

enum CouChangeClass {
  initialGovernedBaseline,
  schemaOrIdentity,
  questionOfInterest,
  contextOfUse,
  observable,
  population,
  productIdentity,
  terminology,
  fedState,
  predicateContract,
  providerGraph,
  evidenceBase,
  reviewState,
  configurationIdentity,
}

enum CouModelRisk { low, moderate, high, critical }

enum CouEvidenceKind {
  implementationVerification,
  calculationVerification,
  uncertaintyAssessment,
  humanFactors,
  scientificValidation,
  modelQualification,
  independentReview,
  regulatoryReview,
  externalApproval,
}

enum CouEvidenceStatus {
  notRequired,
  planned,
  complete,
  missing,
  stale,
  conflicting,
  rejected,
}

enum CouReleaseDisposition {
  blockedPendingEvidence,
  approvedResearchTraceOnly,
  revoked,
  rolledBack,
}

final class CouSemanticChange {
  final String path;
  final Object? previousValue;
  final Object? currentValue;
  final CouChangeClass changeClass;

  const CouSemanticChange({
    required this.path,
    required this.previousValue,
    required this.currentValue,
    required this.changeClass,
  });

  Map<String, Object?> toJson() => {
    'path': path,
    'previous_value': previousValue,
    'current_value': currentValue,
    'change_class': changeClass.name,
  };
}

final class CouChangeImpact {
  final List<CouSemanticChange> changes;
  final Set<CouChangeClass> changeClasses;
  final Set<String> affectedProviderIds;
  final Set<String> affectedPredicateIds;
  final Set<CouEvidenceKind> requiredEvidence;
  final CouModelRisk modelRisk;

  CouChangeImpact({
    required List<CouSemanticChange> changes,
    required Set<CouChangeClass> changeClasses,
    required Set<String> affectedProviderIds,
    required Set<String> affectedPredicateIds,
    required Set<CouEvidenceKind> requiredEvidence,
    required this.modelRisk,
  }) : changes = List.unmodifiable(changes),
       changeClasses = Set.unmodifiable(changeClasses),
       affectedProviderIds = Set.unmodifiable(affectedProviderIds),
       affectedPredicateIds = Set.unmodifiable(affectedPredicateIds),
       requiredEvidence = Set.unmodifiable(requiredEvidence);

  String get semanticDiffSha256 => _sha256(<String, Object?>{
    'changes': changes.map((change) => change.toJson()).toList(growable: false),
  });

  Map<String, Object?> toJson() => {
    'semantic_diff_sha256': semanticDiffSha256,
    'model_risk': modelRisk.name,
    'change_classes': _sortedNames(changeClasses),
    'affected_provider_ids': _sortedStrings(affectedProviderIds),
    'affected_predicate_ids': _sortedStrings(affectedPredicateIds),
    'required_evidence': _sortedNames(requiredEvidence),
    'changes': changes.map((change) => change.toJson()).toList(growable: false),
  };
}

final class CouEvidenceDecision {
  final CouEvidenceKind kind;
  final CouEvidenceStatus status;
  final List<String> evidenceIds;
  final String? reviewer;
  final String? reviewedAtUtc;
  final String boundary;

  CouEvidenceDecision({
    required this.kind,
    required this.status,
    required List<String> evidenceIds,
    required this.reviewer,
    required this.reviewedAtUtc,
    required this.boundary,
  }) : evidenceIds = List.unmodifiable(evidenceIds);

  bool get completeForPromotion => status == CouEvidenceStatus.complete;

  List<String> get integrityReasons {
    final reasons = <String>[];
    if (boundary.trim().isEmpty) {
      reasons.add('evidence.${kind.name}.boundary_missing');
    }
    if (status == CouEvidenceStatus.complete) {
      if (evidenceIds.isEmpty) {
        reasons.add('evidence.${kind.name}.artifact_missing');
      }
      if (reviewer == null || reviewer!.trim().isEmpty) {
        reasons.add('evidence.${kind.name}.reviewer_missing');
      }
      if (!_isUtcTimestamp(reviewedAtUtc)) {
        reasons.add('evidence.${kind.name}.review_time_invalid');
      }
    } else if (status == CouEvidenceStatus.notRequired &&
        evidenceIds.isNotEmpty) {
      reasons.add('evidence.${kind.name}.not_required_has_artifacts');
    }
    return List.unmodifiable(reasons);
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'status': status.name,
    'evidence_ids': [...evidenceIds]..sort(),
    'reviewer': reviewer,
    'reviewed_at_utc': reviewedAtUtc,
    'boundary': boundary,
  };
}

final class ContextOfUseRequalificationRecord {
  final int sequence;
  final String changeKind;
  final String? previousManifestSha256;
  final String? previousConfigurationSha256;
  final String currentManifestSha256;
  final String currentConfigurationSha256;
  final String evidenceCurrencyRegistrySha256;
  final String evidenceSynthesisRegistrySha256;
  final String semanticDiffSha256;
  final List<String> affectedProviderIds;
  final List<String> affectedPredicateIds;
  final List<CouChangeClass> changeClasses;
  final CouModelRisk modelRisk;
  final String questionOfInterest;
  final String contextOfUse;
  final String author;
  final String recordedAtUtc;
  final String releaseArtifact;
  final List<CouEvidenceDecision> evidenceDecisions;
  final CouReleaseDisposition releaseDisposition;
  final String? approvalSignature;
  final String decisionBoundary;

  ContextOfUseRequalificationRecord({
    required this.sequence,
    required this.changeKind,
    required this.previousManifestSha256,
    required this.previousConfigurationSha256,
    required this.currentManifestSha256,
    required this.currentConfigurationSha256,
    required this.evidenceCurrencyRegistrySha256,
    required this.evidenceSynthesisRegistrySha256,
    required this.semanticDiffSha256,
    required List<String> affectedProviderIds,
    required List<String> affectedPredicateIds,
    required List<CouChangeClass> changeClasses,
    required this.modelRisk,
    required this.questionOfInterest,
    required this.contextOfUse,
    required this.author,
    required this.recordedAtUtc,
    required this.releaseArtifact,
    required List<CouEvidenceDecision> evidenceDecisions,
    required this.releaseDisposition,
    required this.approvalSignature,
    required this.decisionBoundary,
  }) : affectedProviderIds = List.unmodifiable(affectedProviderIds),
       affectedPredicateIds = List.unmodifiable(affectedPredicateIds),
       changeClasses = List.unmodifiable(changeClasses),
       evidenceDecisions = List.unmodifiable(evidenceDecisions);

  Map<String, Object?> get canonicalPayload => {
    'sequence': sequence,
    'change_kind': changeKind,
    'previous_manifest_sha256': previousManifestSha256,
    'previous_configuration_sha256': previousConfigurationSha256,
    'current_manifest_sha256': currentManifestSha256,
    'current_configuration_sha256': currentConfigurationSha256,
    'evidence_currency_registry_sha256': evidenceCurrencyRegistrySha256,
    'evidence_synthesis_registry_sha256': evidenceSynthesisRegistrySha256,
    'semantic_diff_sha256': semanticDiffSha256,
    'affected_provider_ids': [...affectedProviderIds]..sort(),
    'affected_predicate_ids': [...affectedPredicateIds]..sort(),
    'change_classes': _sortedNames(changeClasses),
    'model_risk': modelRisk.name,
    'question_of_interest': questionOfInterest,
    'context_of_use': contextOfUse,
    'author': author,
    'recorded_at_utc': recordedAtUtc,
    'release_artifact': releaseArtifact,
    'evidence_decisions':
        evidenceDecisions
            .map((decision) => decision.toJson())
            .toList(growable: false)
          ..sort(
            (a, b) => (a['kind']! as String).compareTo(b['kind']! as String),
          ),
    'release_disposition': releaseDisposition.name,
    'approval_signature': approvalSignature,
    'decision_boundary': decisionBoundary,
  };

  String get recordSha256 => _sha256(canonicalPayload);

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'record_sha256': recordSha256,
  };
}

/// Immutable governance record for the current context-of-use boundary.
///
/// This ledger deliberately does not infer scientific validation, regulatory
/// review, or external approval from tests or matching hashes. Its present
/// record is a blocked initial-baseline adoption; future manifest/configuration
/// changes must update the pinned semantic diff and evidence decision.
final class ContextOfUseRequalificationLedger {
  static const String schema =
      'parkinsum.context-of-use-requalification-ledger/1';
  static const int schemaVersion = 1;
  static const String ledgerVersion = '2026.10.20-v67';

  static const String expectedCurrentManifestSha256 =
      '3e560401c21a1fd3eec3ed75e24f8753797e7e8d14f70b495086bb5fe2db0dc7';
  static const String expectedCurrentConfigurationSha256 =
      '464d03611fef12cadf04504be650816be368e393d614fad4c836162a8010013f';
  static const String historicalV79ConfigurationSha256 =
      '9ccb403043d9b803653944779cfdac56d9810b0b77277c196ff3b139885568c2';
  static const String historicalV78ConfigurationSha256 =
      'cdc582bde5b6341add35c6c53098f800dce8715a0ddd3b42a44c88707faa813d';
  static const String historicalV77ConfigurationSha256 =
      '51c839f072a70582d34a5c55b38f45f2f657dec84f4ed01d139bedc3782bc82d';
  static const String historicalV76ConfigurationSha256 =
      '7954d51606b7e63acafba92884df6d69f61cebd1d5182093f158af6a75605028';
  static const String historicalV75ConfigurationSha256 =
      'bb7ce2ed3bbfbeaffdeff0ee7a24a054a6495b97247cc838f13c5e454bfe34fd';
  static const String historicalV74ConfigurationSha256 =
      'c0a34a359397ce0405474b1ca006067e58ecc7f0b7a13d65ca03c4df92ba5d40';
  static const String historicalV73ConfigurationSha256 =
      'eaca417fdd38ab1179050eb235a09f2d19b9ace0b7ee97fd5e3b1fd3a1a712ab';
  static const String historicalV69ConfigurationSha256 =
      '9d11461bbadee06329cc25c218306603bc392a8d2833cbe4eeaf3967ee7d183d';
  static const String historicalV68ConfigurationSha256 =
      '32b87336d8b3fbfc49b77a4ecaf091819ca22ce7e3a66e8bb835e24a61ebcba7';
  static const String historicalV67ConfigurationSha256 =
      'e5ad9319059abc7f3fd11e09c2b11a2daadde8dfd6610baea8891022a2725235';
  static const String historicalV66ConfigurationSha256 =
      '835f56e68a98a88bd7b56ab7a326fd91f6b27d8f97009ddbe9e7c4708758c3e0';
  static const String historicalV65ConfigurationSha256 =
      '148c3f53ec7f4b579e1f4a69070737349bcc1fb1afa9d2b1350b7c68abbc241b';
  static const String historicalV64ConfigurationSha256 =
      'a723a09fd0672358a043ffa2ef3341b6f10ea1f4ac3ee98dfc42f5c5d7ec304e';
  static const String historicalV63ConfigurationSha256 =
      '110c498e780ceceb457a97dc4840b27270a40968a92693e78831544bcbee2266';
  static const String historicalV62ConfigurationSha256 =
      'd98910fa013aab4c69d3b96f74ffd6e9cda4467aec3ce39d2884c2bc178aeef3';
  static const String historicalV61ConfigurationSha256 =
      '57c9393375e967f1c91c1e8361af2792e474c7bb565b2b0c375304c1c7940acb';
  static const String historicalV60ConfigurationSha256 =
      '6a31cb3854b8c49f1748d6125b2d754e7d5d99063ff9a27c8a9327d02b7377dc';
  static const String historicalV59ConfigurationSha256 =
      '966197e7ebba8d4d3370ff7c46e3cc4f1064e2a25e18fe79e8577df116fda920';
  static const String historicalV58ConfigurationSha256 =
      '58fcad8b624b5f53c6be47796847f3e7a82b23862f8afc2a6562c3c1939f68ac';
  static const String historicalV57ConfigurationSha256 =
      'f53b161810c90f8950ec2232dba34c912d78a34e7e8209429de08c0c05cc54e3';
  static const String historicalV56ConfigurationSha256 =
      '2d6030490162c52b16f609e5ec27d8d3ce98bd25977454966ed9615394b55a55';
  static const String historicalV55ConfigurationSha256 =
      '0a664d1ab3ed070b65c5bbdb3612ba4433428ad681422b338c5f813ed8c2740d';
  static const String historicalV54ConfigurationSha256 =
      'f2bf313f8b955efebd3f1ff1eaf1791783648b440ad96fddf54d190f198b7d42';
  static const String historicalV53ConfigurationSha256 =
      '31f0386b09f243fdc5bc275af3e6c4c33fbdedd77d648c71b1a168530d921642';
  static const String historicalV52ConfigurationSha256 =
      'e75f4fbe20af2cecb6da8e88034ca7a0da4958571a0cecdd8613a3236ceffe05';
  static const String expectedInitialSemanticDiffSha256 =
      '1a2047b215617d8b85cf57189de6b7a7aaa0706c27b0ff1ac1689a6bd68a4937';
  static const String expectedCurrentEvidenceCurrencyRegistrySha256 =
      '63ad0dd1543186d67d47499966ca4fa292c13ba7bfcab750813055e901d94c2e';
  static const String expectedCurrentEvidenceSynthesisRegistrySha256 =
      '3c64c10bc76d1307bf7bdaf16abf8e33b21028929c369cf660cb6296f3f9292c';
  static const String previousConfigurationSha256 =
      'd00e4d7ec8a5a91e2bf6b7abe53af20ecc1459cddd12aee3f8f6370b5cb0f0ba';

  final MechanisticApplicabilityManifest manifest;
  final String currentConfigurationSha256;
  final EvidenceCurrencyAssessment evidenceCurrencyAssessment;
  final EvidenceSynthesisAssessment evidenceSynthesisAssessment;
  final CouChangeImpact currentImpact;
  final List<ContextOfUseRequalificationRecord> records;

  ContextOfUseRequalificationLedger._({
    required this.manifest,
    required this.currentConfigurationSha256,
    required this.evidenceCurrencyAssessment,
    required this.evidenceSynthesisAssessment,
    required this.currentImpact,
    required List<ContextOfUseRequalificationRecord> records,
  }) : records = List.unmodifiable(records);

  factory ContextOfUseRequalificationLedger.current({
    required MechanisticApplicabilityManifest manifest,
    required String configurationSha256,
    required DateTime evidenceAsOfUtc,
    EvidenceCurrencyRegistry? evidenceCurrencyRegistry,
    EvidenceSynthesisRegistry? evidenceSynthesisRegistry,
  }) {
    final assessment =
        (evidenceCurrencyRegistry ?? EvidenceCurrencyRegistry.current).assess(
          asOfUtc: evidenceAsOfUtc.toUtc(),
        );
    final synthesisAssessment =
        (evidenceSynthesisRegistry ?? EvidenceSynthesisRegistry.current).assess(
          asOfUtc: evidenceAsOfUtc.toUtc(),
          currencyAssessment: assessment,
          manifest: manifest,
        );
    final impact = CouManifestSemanticDiff.initialBaseline(manifest);
    final record = ContextOfUseRequalificationRecord(
      sequence: 1,
      changeKind: 'initial_governed_baseline',
      previousManifestSha256: null,
      previousConfigurationSha256: previousConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV52ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          expectedCurrentEvidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          expectedCurrentEvidenceSynthesisRegistrySha256,
      semanticDiffSha256: expectedInitialSemanticDiffSha256,
      affectedProviderIds: const [
        'amino_acid_competition',
        'gastric_emptying',
        'levodopa_absorption_opportunity',
        'meal_composition_normalizer',
        'mechanistic_candidate_scorer',
        'mechanistic_conflict',
      ],
      affectedPredicateIds: const [
        'meal.protein_evidence',
        'meal.structured_composition',
        'medication.active_components',
        'medication.dosage_form',
        'medication.explicit_dose',
        'medication.release_type',
        'medication.route',
        'provider.upstream_availability',
        'timeline.dose_time_meal_context',
        'timeline.identity_integrity',
      ],
      changeClasses: CouChangeClass.values,
      modelRisk: CouModelRisk.critical,
      questionOfInterest: manifest.questionOfInterest,
      contextOfUse: manifest.contextOfUse,
      author: 'repository-maintainers',
      recordedAtUtc: '2026-08-18T00:00:00.000Z',
      releaseArtifact:
          'unreleased-worktree:agent/complete-app-upgrade-20260818',
      evidenceDecisions: _initialEvidenceDecisions(),
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'Implementation and calculation verification do not establish '
          'scientific validation, model qualification, regulatory review, or '
          'external approval. The changed capability remains unpromoted. '
          'The v52 release refresh binds the current configuration and '
          'evidence-synthesis registry identities only; retained synthetic '
          'fixture timestamps do not '
          'attest current-worktree review or evidence coverage.',
    );
    final candidateRecord = ContextOfUseRequalificationRecord(
      sequence: 2,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256: record.currentManifestSha256,
      previousConfigurationSha256: record.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV53ConfigurationSha256,
      evidenceCurrencyRegistrySha256: record.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256: record.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: record.semanticDiffSha256,
      affectedProviderIds: record.affectedProviderIds,
      affectedPredicateIds: record.affectedPredicateIds,
      changeClasses: record.changeClasses,
      modelRisk: record.modelRisk,
      questionOfInterest: record.questionOfInterest,
      contextOfUse: record.contextOfUse,
      author: record.author,
      recordedAtUtc: '2026-09-29T00:00:00.000Z',
      releaseArtifact: 'unreleased-worktree:next-upgrade-v53-candidate',
      evidenceDecisions: record.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v53 candidate rebind records exact software identity only. '
          'The prior v52 record is retained unchanged, and the full conservative '
          'initial-baseline evidence requirements remain open. Inherited '
          'engineering fixture decisions and the fixed synthetic timestamp '
          'do not attest a new external review, current-worktree evidence '
          'coverage, scientific validation, model qualification, regulatory '
          'review or approval. No missing evidence or release HOLD is cleared.',
    );
    final megaCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 3,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256: candidateRecord.currentManifestSha256,
      previousConfigurationSha256: candidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV54ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          candidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          candidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: candidateRecord.semanticDiffSha256,
      affectedProviderIds: candidateRecord.affectedProviderIds,
      affectedPredicateIds: candidateRecord.affectedPredicateIds,
      changeClasses: candidateRecord.changeClasses,
      modelRisk: candidateRecord.modelRisk,
      questionOfInterest: candidateRecord.questionOfInterest,
      contextOfUse: candidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-09-30T05:41:12.503Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v54-candidate',
      evidenceDecisions: candidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v54 local software candidate adds strict food-catalogue '
          'transaction/HOLD behavior, proven nutrient-evidence deduplication '
          'and display-only date projections. Both v52 and v53 records remain '
          'unchanged. This event binds software identity; inherited synthetic '
          'engineering decisions do not establish new external review, '
          'scientific validity, clinical calibration or approval. All open '
          'evidence requirements and release holds remain blocked.',
    );
    final productScopeCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 4,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256: megaCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          megaCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV55ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          megaCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          megaCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: megaCandidateRecord.semanticDiffSha256,
      affectedProviderIds: megaCandidateRecord.affectedProviderIds,
      affectedPredicateIds: megaCandidateRecord.affectedPredicateIds,
      changeClasses: megaCandidateRecord.changeClasses,
      modelRisk: megaCandidateRecord.modelRisk,
      questionOfInterest: megaCandidateRecord.questionOfInterest,
      contextOfUse: megaCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-09-30T19:17:10.000Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v55-candidate',
      evidenceDecisions: megaCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v55 software candidate isolates SPL product identity, source '
          'strength ratios and explicitly owned evidence. Shared narrative '
          'remains unassigned. App caches expose only completed checks for '
          'exact current inputs; missing checks present no numeric score. '
          'All three earlier records and their decisions remain unchanged. '
          'Actual engineering counterexamples and source-field comparisons '
          'do not establish scientific validation, clinical calibration, '
          'independent review or approval. Open evidence requirements and '
          'release holds remain blocked.',
    );
    final ingredientClassCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 5,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256: productScopeCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          productScopeCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV56ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          productScopeCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          productScopeCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: productScopeCandidateRecord.semanticDiffSha256,
      affectedProviderIds: productScopeCandidateRecord.affectedProviderIds,
      affectedPredicateIds: productScopeCandidateRecord.affectedPredicateIds,
      changeClasses: productScopeCandidateRecord.changeClasses,
      modelRisk: productScopeCandidateRecord.modelRisk,
      questionOfInterest: productScopeCandidateRecord.questionOfInterest,
      contextOfUse: productScopeCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-09-30T23:42:09.709Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v56-candidate',
      evidenceDecisions: productScopeCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v56 candidate requires exact SPL active-ingredient classes and retains unknown roles as source-only HOLD. Four historical records remain unchanged. Frozen synthetic counterexamples verify software behavior only; no scientific validation, clinical calibration, independent review, approval or missing evidence hold is cleared.',
    );
    final medicationContextCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 6,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          ingredientClassCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          ingredientClassCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV57ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          ingredientClassCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          ingredientClassCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: ingredientClassCandidateRecord.semanticDiffSha256,
      affectedProviderIds: ingredientClassCandidateRecord.affectedProviderIds,
      affectedPredicateIds: ingredientClassCandidateRecord.affectedPredicateIds,
      changeClasses: ingredientClassCandidateRecord.changeClasses,
      modelRisk: ingredientClassCandidateRecord.modelRisk,
      questionOfInterest: ingredientClassCandidateRecord.questionOfInterest,
      contextOfUse: ingredientClassCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-01T00:25:57.757Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v57-candidate',
      evidenceDecisions: ingredientClassCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v57 candidate preserves unresolved saved or selected medication references as unassessed input. Scores, severity, simulation traces, recommendation order and AI requests are withheld for that incomplete context. The result contract is source-bound. Five historical records remain unchanged. Independent synthetic counterexamples establish software behavior only; numerical model parameters, scientific validation, clinical calibration, independent review, approval and all missing evidence holds are unchanged.',
    );
    final foodEnergyMethodCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 7,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          medicationContextCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          medicationContextCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV58ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          medicationContextCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          medicationContextCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: medicationContextCandidateRecord.semanticDiffSha256,
      affectedProviderIds: medicationContextCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          medicationContextCandidateRecord.affectedPredicateIds,
      changeClasses: medicationContextCandidateRecord.changeClasses,
      modelRisk: medicationContextCandidateRecord.modelRisk,
      questionOfInterest: medicationContextCandidateRecord.questionOfInterest,
      contextOfUse: medicationContextCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-01T04:44:00.956Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v58-candidate',
      evidenceDecisions: medicationContextCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v58 candidate retains distinct source-reported USDA Atwater methods, conversion factors and original publication strings. Method-specific energy is not selected for generic energy arithmetic; factors trigger no new energy or protein calculation. Official archive null slots are retained as metadata, not fabricated foods. Six historical records remain unchanged. Source-field comparisons and software tests do not establish source truth, scientific validation, clinical calibration, independent approval or catalogue promotion. All missing evidence and release holds remain blocked.',
    );
    final searchSamplingCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 8,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          foodEnergyMethodCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          foodEnergyMethodCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV59ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          foodEnergyMethodCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          foodEnergyMethodCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: foodEnergyMethodCandidateRecord.semanticDiffSha256,
      affectedProviderIds: foodEnergyMethodCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          foodEnergyMethodCandidateRecord.affectedPredicateIds,
      changeClasses: foodEnergyMethodCandidateRecord.changeClasses,
      modelRisk: foodEnergyMethodCandidateRecord.modelRisk,
      questionOfInterest: foodEnergyMethodCandidateRecord.questionOfInterest,
      contextOfUse: foodEnergyMethodCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-01T07:10:55.926Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v59-candidate',
      evidenceDecisions: foodEnergyMethodCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v59 candidate repairs short multilingual catalog substrings and source-ordered limits. Source/revision queries retain their scientific-rank boundary. Two existing shadow-model families are compared with manufactured finite-grid sampling; wider equivalent parameter sets and off-grid recovery failures remain visible, synthetic fitting remains held and no production physiological parameter is changed. Seven historical records remain exact. CI layering retains required coverage and the protected preflight identity. Software checks and source-bound timing do not establish independent approval, continuous identifiability, clinical calibration or deployment. All missing qualification evidence remains blocked.',
    );
    final preferenceSessionCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 9,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          searchSamplingCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          searchSamplingCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV60ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          searchSamplingCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          searchSamplingCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: searchSamplingCandidateRecord.semanticDiffSha256,
      affectedProviderIds: searchSamplingCandidateRecord.affectedProviderIds,
      affectedPredicateIds: searchSamplingCandidateRecord.affectedPredicateIds,
      changeClasses: searchSamplingCandidateRecord.changeClasses,
      modelRisk: searchSamplingCandidateRecord.modelRisk,
      questionOfInterest: searchSamplingCandidateRecord.questionOfInterest,
      contextOfUse: searchSamplingCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-01T08:40:33.806Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v60-candidate',
      evidenceDecisions: searchSamplingCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v60 candidate guards preference persistence by owner and session epoch. Pre-dispatch rejection differs from acknowledged writes for a previous session; dispatched platform writes are not claimed to be cancelled. Real temporary SQLite rollback tests and offline Firestore call-shape tests establish their stated software scope only. Eight historical records and 22 numerical implementation fingerprints remain exact. No cross-tab compare-and-swap, real cloud qualification, native lifecycle qualification, clinical calibration, independent approval or release is established. All missing qualification evidence remains blocked.',
    );
    final originStorageCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 10,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          preferenceSessionCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          preferenceSessionCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV61ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          preferenceSessionCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          preferenceSessionCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: preferenceSessionCandidateRecord.semanticDiffSha256,
      affectedProviderIds: preferenceSessionCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          preferenceSessionCandidateRecord.affectedPredicateIds,
      changeClasses: preferenceSessionCandidateRecord.changeClasses,
      modelRisk: preferenceSessionCandidateRecord.modelRisk,
      questionOfInterest: preferenceSessionCandidateRecord.questionOfInterest,
      contextOfUse: preferenceSessionCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-01T11:36:24Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v61-candidate',
      evidenceDecisions: preferenceSessionCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v61 candidate coordinates participating same-origin Web writes with exclusive Web Locks, reloads the aggregate inside each lock and rejects stale source witnesses. Other-tab storage events invalidate derived results and require explicit reload. Same-process native coordination does not establish cross-process transactions. Older or nonparticipating writers remain outside this protocol; accepted platform writes are not claimed to be cancelled. Nine historical records and 22 numerical implementation fingerprints remain exact. These software boundaries do not establish real cloud qualification, native lifecycle qualification, clinical calibration, independent approval or release. All missing qualification evidence remains blocked.',
    );
    final foodQuantityMethodCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 11,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          originStorageCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          originStorageCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV62ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          originStorageCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          originStorageCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: originStorageCandidateRecord.semanticDiffSha256,
      affectedProviderIds: originStorageCandidateRecord.affectedProviderIds,
      affectedPredicateIds: originStorageCandidateRecord.affectedPredicateIds,
      changeClasses: originStorageCandidateRecord.changeClasses,
      modelRisk: originStorageCandidateRecord.modelRisk,
      questionOfInterest: originStorageCandidateRecord.questionOfInterest,
      contextOfUse: originStorageCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-01T13:08:36.508142Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v62-candidate',
      evidenceDecisions: originStorageCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v62 candidate separates source-identified carbohydrate by difference from summation and conventional total dietary fiber from the AOAC 2011.25 quantity. Supplied ID and number must agree; names cannot collapse distinct methods or repair conflicting identifiers. Six original public food objects support finite source-bound portions and explicitly manufactured alternative groups. Fixed injected heuristic weights and thresholds expose ties, top-K changes and pair reversals without changing production defaults. Original insufficient-context runs and source-content identity changes remain preserved. Ten historical records and all 22 numerical implementation fingerprints remain exact. This software research does not validate source matching, clinical usefulness, physiological calibration, independent approval or release; qualification remains blocked.',
    );
    final timezoneRulesCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 12,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          foodQuantityMethodCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          foodQuantityMethodCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV63ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          foodQuantityMethodCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          foodQuantityMethodCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: foodQuantityMethodCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          foodQuantityMethodCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          foodQuantityMethodCandidateRecord.affectedPredicateIds,
      changeClasses: foodQuantityMethodCandidateRecord.changeClasses,
      modelRisk: foodQuantityMethodCandidateRecord.modelRisk,
      questionOfInterest: foodQuantityMethodCandidateRecord.questionOfInterest,
      contextOfUse: foodQuantityMethodCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-01T16:39:24.252684Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v63-candidate',
      evidenceDecisions: foodQuantityMethodCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v63 candidate binds an exact offline IANA2026e artifact and immutable source snapshot to explicit calendar projection. The compiled interval is1900inclusive through2100exclusive; unsupported interpretations reject. Old2025c civil intent and whole receipts are retained rather than relabeled. Fixed14civil cases across both releases and40independent UTC projections verify their finite domain only; injected clock rollback differs from host clock manipulation. Actual source/table identity does not establish current device-zone detection, all-zone legal accuracy, native reminder delivery or clinical scheduling authority. Eleven historical governance records and all22numerical implementation fingerprints remain exact. No scientific or human qualification, independent approval, clinical calibration or release is granted; missing evidence remains blocked.',
    );
    final completeClusterNutrientCandidateRecord =
        ContextOfUseRequalificationRecord(
          sequence: 13,
          changeKind: 'software_identity_candidate_rebind',
          previousManifestSha256:
              timezoneRulesCandidateRecord.currentManifestSha256,
          previousConfigurationSha256:
              timezoneRulesCandidateRecord.currentConfigurationSha256,
          currentManifestSha256: expectedCurrentManifestSha256,
          currentConfigurationSha256: historicalV64ConfigurationSha256,
          evidenceCurrencyRegistrySha256:
              timezoneRulesCandidateRecord.evidenceCurrencyRegistrySha256,
          evidenceSynthesisRegistrySha256:
              timezoneRulesCandidateRecord.evidenceSynthesisRegistrySha256,
          semanticDiffSha256: timezoneRulesCandidateRecord.semanticDiffSha256,
          affectedProviderIds: timezoneRulesCandidateRecord.affectedProviderIds,
          affectedPredicateIds:
              timezoneRulesCandidateRecord.affectedPredicateIds,
          changeClasses: timezoneRulesCandidateRecord.changeClasses,
          modelRisk: timezoneRulesCandidateRecord.modelRisk,
          questionOfInterest: timezoneRulesCandidateRecord.questionOfInterest,
          contextOfUse: timezoneRulesCandidateRecord.contextOfUse,
          author: 'automated-local-software-integration',
          recordedAtUtc: '2026-10-02T05:23:14.895824Z',
          releaseArtifact: 'unreleased-worktree:mega-upgrade-v64-candidate',
          evidenceDecisions: timezoneRulesCandidateRecord.evidenceDecisions,
          releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
          approvalSignature: null,
          decisionBoundary:
              'The v64 candidate compares every eligible observation pair within a compatible cluster, distinguishes source-row duplicates from same-document contradictions and preserves differing measurement methods. It retains 62 source-identified FDC quantities, including 49 newly structured quantities, with microgram spelling normalization only. Source values, method-specific forms, censoring and audit provenance remain separate; no nutrient equivalence, density conversion, clinical threshold or dosage recommendation is introduced. The existing Foundation basis contract requires further qualification for dry-matter and branded volume contexts. Twelve historical records and all 22 numerical implementation fingerprints remain exact. Software counterexamples and finite archive field comparisons do not establish source truth, complete conflict workflow, scientific validation, clinical calibration, independent approval, catalogue promotion or release. All missing qualification evidence remains blocked.',
        );
    final incumbentActivationStrengthCandidateRecord =
        ContextOfUseRequalificationRecord(
          sequence: 14,
          changeKind: 'software_identity_candidate_rebind',
          previousManifestSha256:
              completeClusterNutrientCandidateRecord.currentManifestSha256,
          previousConfigurationSha256:
              completeClusterNutrientCandidateRecord.currentConfigurationSha256,
          currentManifestSha256: expectedCurrentManifestSha256,
          currentConfigurationSha256: historicalV65ConfigurationSha256,
          evidenceCurrencyRegistrySha256: completeClusterNutrientCandidateRecord
              .evidenceCurrencyRegistrySha256,
          evidenceSynthesisRegistrySha256:
              completeClusterNutrientCandidateRecord
                  .evidenceSynthesisRegistrySha256,
          semanticDiffSha256:
              completeClusterNutrientCandidateRecord.semanticDiffSha256,
          affectedProviderIds:
              completeClusterNutrientCandidateRecord.affectedProviderIds,
          affectedPredicateIds:
              completeClusterNutrientCandidateRecord.affectedPredicateIds,
          changeClasses: completeClusterNutrientCandidateRecord.changeClasses,
          modelRisk: completeClusterNutrientCandidateRecord.modelRisk,
          questionOfInterest:
              completeClusterNutrientCandidateRecord.questionOfInterest,
          contextOfUse: completeClusterNutrientCandidateRecord.contextOfUse,
          author: 'automated-local-software-integration',
          recordedAtUtc: '2026-10-02T06:27:38.245432Z',
          releaseArtifact: 'unreleased-worktree:mega-upgrade-v65-candidate',
          evidenceDecisions:
              completeClusterNutrientCandidateRecord.evidenceDecisions,
          releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
          approvalSignature: null,
          decisionBoundary:
              'The v65 candidate recovers incumbent observations before full cluster comparison, preserves manual choices and holds unresolved imports before live catalogue, label or snapshot activation. Incoming source content, scope dimensions and fact payloads cannot silently reuse inconsistent identities. Extended nutrients remain source evidence unless they actually feed a legacy numeric field. SPL active ingredients, active moieties, reference ingredients, inactive ingredient codes and strength denominators are preserved as source evidence without administered-dose conversion or chemical equivalence. Finite synthetic counterexamples and independent official source-field comparisons do not establish complete reviewer closure, concurrent backend transactionality, global catalogue truth, full label semantics or clinical scheduling authority. All thirteen historical records, all twenty-two numerical implementation fingerprints and numerical parameter objects remain exact. No clinical calibration, human approval, catalogue promotion or release is granted; qualification evidence remains blocked.',
        );
    final heldEvidenceReviewCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 15,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          incumbentActivationStrengthCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          incumbentActivationStrengthCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV66ConfigurationSha256,
      evidenceCurrencyRegistrySha256: incumbentActivationStrengthCandidateRecord
          .evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          incumbentActivationStrengthCandidateRecord
              .evidenceSynthesisRegistrySha256,
      semanticDiffSha256:
          incumbentActivationStrengthCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          incumbentActivationStrengthCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          incumbentActivationStrengthCandidateRecord.affectedPredicateIds,
      changeClasses: incumbentActivationStrengthCandidateRecord.changeClasses,
      modelRisk: incumbentActivationStrengthCandidateRecord.modelRisk,
      questionOfInterest:
          incumbentActivationStrengthCandidateRecord.questionOfInterest,
      contextOfUse: incumbentActivationStrengthCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-02T07:20:19.195837Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v66-candidate',
      evidenceDecisions:
          incumbentActivationStrengthCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v66 candidate stores complete typed held source evidence on the existing ingestion backend before optional artifact writes and verifies source packets against actual staged rows, original conflict audits and incumbent facts, observations, scopes and sources. Explicit local review decisions bind an open matching ticket, the immutable comparison graph and chosen original source evidence. Stale or missing evidence, ambiguous identities and closed tickets cannot supply a current numeric decision. Original conflicts remain unresolved; review decisions do not authorize activation, publication or clinical use. Backend write-protocol tests and actual Chrome execution do not qualify browser reload, OS-kill durability, concurrent atomic promotion, reviewer authentication or real-device persistence. All fourteen historical records, all twenty-two numerical fingerprints and numerical parameter objects remain exact. No clinical calibration, independent human approval, catalogue promotion or release is granted; qualification remains blocked.',
    );
    final foodBasisCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 16,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          heldEvidenceReviewCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          heldEvidenceReviewCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV67ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          heldEvidenceReviewCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          heldEvidenceReviewCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: heldEvidenceReviewCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          heldEvidenceReviewCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          heldEvidenceReviewCandidateRecord.affectedPredicateIds,
      changeClasses: heldEvidenceReviewCandidateRecord.changeClasses,
      modelRisk: heldEvidenceReviewCandidateRecord.modelRisk,
      questionOfInterest: heldEvidenceReviewCandidateRecord.questionOfInterest,
      contextOfUse: heldEvidenceReviewCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-02T08:16:05.827827Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v67-candidate',
      evidenceDecisions: heldEvidenceReviewCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v67 candidate qualifies explicitly declared USDA dry-matter and moisture-standardized bases, branded volume units and unproven branded bases before edible-weight use. Raw source numbers, units, methods, bounds and source documents remain evidence. It preserves the old parse identity and gives changed interpretations a distinct source document identity. Matching retained source fields and legacy explicit source descriptions qualify stored catalogue rows; unsupported cached bases cannot provide meal macros, energy or amino-acid inputs. Finite synthetic branded and legacy counterexamples and complete Foundation archive comparisons do not establish global catalogue truth, inferred moisture or density conversions, a verified branded corpus, complete historical metadata recovery, concurrent atomic activation or clinical scheduling authority. All fifteen whole historical records, all twenty-two numerical implementation fingerprints and parameter objects remain exact. No clinical calibration, human approval, catalogue promotion or release is granted; qualification evidence remains blocked.',
    );
    final cacheHeldResourcesCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 17,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256: foodBasisCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          foodBasisCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV68ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          foodBasisCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          foodBasisCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: foodBasisCandidateRecord.semanticDiffSha256,
      affectedProviderIds: foodBasisCandidateRecord.affectedProviderIds,
      affectedPredicateIds: foodBasisCandidateRecord.affectedPredicateIds,
      changeClasses: foodBasisCandidateRecord.changeClasses,
      modelRisk: foodBasisCandidateRecord.modelRisk,
      questionOfInterest: foodBasisCandidateRecord.questionOfInterest,
      contextOfUse: foodBasisCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-02T09:33:49.955021Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v68-candidate',
      evidenceDecisions: foodBasisCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v68 candidate qualifies legacy cache entries from original source identity and units rather than a disproven edible-mass label. It retains the complete held import catalogue resources and projections on the backend before optional sidecar writes, preserves version-1 packets as historical advisory evidence and records version-2 complete packets. Generic publish overrides, closed review tickets and advisory quantity choices cannot release original source holds. Product-scoped ingredient identity, active moieties, reference ingredients, inactive classes and original label strength denominators remain read-only source evidence. Two complete USDA branded API samples retain all thirty original nutrient quantities, units and derivation fields; volume and unqualified units never authorize edible-gram inputs. These finite software checks do not establish concurrent atomic activation, global catalogue truth, density or chemical conversions, clinical validation or scheduling authority. All sixteen historical whole records and digests, all twenty-two numerical fingerprints and parameter objects remain exact. No human approval, catalogue promotion or clinical release is granted; qualification evidence remains blocked.',
    );
    final atomicImportProductDetailsCandidateRecord =
        ContextOfUseRequalificationRecord(
          sequence: 18,
          changeKind: 'software_identity_candidate_rebind',
          previousManifestSha256:
              cacheHeldResourcesCandidateRecord.currentManifestSha256,
          previousConfigurationSha256:
              cacheHeldResourcesCandidateRecord.currentConfigurationSha256,
          currentManifestSha256: expectedCurrentManifestSha256,
          currentConfigurationSha256: historicalV69ConfigurationSha256,
          evidenceCurrencyRegistrySha256:
              cacheHeldResourcesCandidateRecord.evidenceCurrencyRegistrySha256,
          evidenceSynthesisRegistrySha256:
              cacheHeldResourcesCandidateRecord.evidenceSynthesisRegistrySha256,
          semanticDiffSha256:
              cacheHeldResourcesCandidateRecord.semanticDiffSha256,
          affectedProviderIds:
              cacheHeldResourcesCandidateRecord.affectedProviderIds,
          affectedPredicateIds:
              cacheHeldResourcesCandidateRecord.affectedPredicateIds,
          changeClasses: cacheHeldResourcesCandidateRecord.changeClasses,
          modelRisk: cacheHeldResourcesCandidateRecord.modelRisk,
          questionOfInterest:
              cacheHeldResourcesCandidateRecord.questionOfInterest,
          contextOfUse: cacheHeldResourcesCandidateRecord.contextOfUse,
          author: 'automated-local-software-integration',
          recordedAtUtc: '2026-10-02T10:41:17.743592Z',
          releaseArtifact: 'unreleased-worktree:mega-upgrade-v69-candidate',
          evidenceDecisions:
              cacheHeldResourcesCandidateRecord.evidenceDecisions,
          releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
          approvalSignature: null,
          decisionBoundary:
              'The v69 candidate commits all local import catalogue, staging, history, audit and activation rows atomically. Native operations share one SQLite transaction executor; Web operations use one complete document, a participating origin lock, unchanged-source checks and exact lost-acknowledgment recovery. Original legacy keys, source holds and review packets remain retained. JavaScript lock callbacks preserve the caller Dart error zone. Complete original Branded food objects retain product, date, ingredient, update-log and source fields under a distinct parser identity. Actual temporary SQLite connections and actual Chrome tests cover the stated software paths only; they do not qualify Flutter native plugins, OS-kill durability, uncooperative writers, global source currentness, reviewed activation, clinical use or independent human approval. All seventeen historical whole records and digests and all twenty-two numerical fingerprints and parameter objects remain exact. No approval, clinical release or whole-candidate completion is granted.',
        );
    final reviewedActivationCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 19,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          atomicImportProductDetailsCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          atomicImportProductDetailsCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256:
          '04c4fdaf52cf10a6380962b90c0fa3688919ca2a9a1c7835fe78970088c1f212',
      evidenceCurrencyRegistrySha256: atomicImportProductDetailsCandidateRecord
          .evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256: atomicImportProductDetailsCandidateRecord
          .evidenceSynthesisRegistrySha256,
      semanticDiffSha256:
          atomicImportProductDetailsCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          atomicImportProductDetailsCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          atomicImportProductDetailsCandidateRecord.affectedPredicateIds,
      changeClasses: atomicImportProductDetailsCandidateRecord.changeClasses,
      modelRisk: atomicImportProductDetailsCandidateRecord.modelRisk,
      questionOfInterest:
          atomicImportProductDetailsCandidateRecord.questionOfInterest,
      contextOfUse: atomicImportProductDetailsCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-02T11:26:41.474Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v70-candidate',
      evidenceDecisions:
          atomicImportProductDetailsCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v70 candidate adds a read-only complete-state-bound local review preview and an explicit atomic derived-snapshot activation. Every original unresolved numeric conflict needs one current matching original-evidence choice; incompatible scopes, deferred actions, missing history, stale state, inactive or future sources and mismatched content checksums remain blocked. The complete v2 packet reconstructs all eighteen original groups. The original held snapshot, staging, audits, decisions and historical source packet remain retained; the new receipt, derived facts and activation share one transaction. No original hold is released by a generic override. Actual SQLite and Chrome qualify declared software behavior only. Reviewer references are local assertions without authenticated reviewer authority; source status and date checks do not establish upstream currency. Clinical permission, independent human review, OS-kill durability, publication and whole-candidate completion remain unqualified. All eighteen historical records and twenty-two numerical implementations and parameter objects remain exact.',
    );
    final reviewedProductIntegrationCandidateRecord =
        ContextOfUseRequalificationRecord(
          sequence: 20,
          changeKind: 'software_identity_candidate_rebind',
          previousManifestSha256:
              reviewedActivationCandidateRecord.currentManifestSha256,
          previousConfigurationSha256:
              reviewedActivationCandidateRecord.currentConfigurationSha256,
          currentManifestSha256: expectedCurrentManifestSha256,
          currentConfigurationSha256:
              'bbb0c3c47e057c001a579357019ccba6a4831100672f76e53fa709597eed5d78',
          evidenceCurrencyRegistrySha256:
              reviewedActivationCandidateRecord.evidenceCurrencyRegistrySha256,
          evidenceSynthesisRegistrySha256:
              reviewedActivationCandidateRecord.evidenceSynthesisRegistrySha256,
          semanticDiffSha256:
              reviewedActivationCandidateRecord.semanticDiffSha256,
          affectedProviderIds:
              reviewedActivationCandidateRecord.affectedProviderIds,
          affectedPredicateIds:
              reviewedActivationCandidateRecord.affectedPredicateIds,
          changeClasses: reviewedActivationCandidateRecord.changeClasses,
          modelRisk: reviewedActivationCandidateRecord.modelRisk,
          questionOfInterest:
              reviewedActivationCandidateRecord.questionOfInterest,
          contextOfUse: reviewedActivationCandidateRecord.contextOfUse,
          author: 'automated-local-software-integration',
          recordedAtUtc: '2026-10-02T16:58:15.617656Z',
          releaseArtifact: 'unreleased-worktree:mega-upgrade-v71-candidate',
          evidenceDecisions:
              reviewedActivationCandidateRecord.evidenceDecisions,
          releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
          approvalSignature: null,
          decisionBoundary:
              'The v71 candidate connects local original-evidence review, immutable state-bound preview and explicit confirmation to the formal import UI. Reviewed quantities enter a complete native or Web catalogue capture only while the full original comparison graph, chosen and alternative observations, source contents, scopes, decision and activation receipt match. Changed evidence or a held catalogue disables stale imported cache arithmetic. Complete original branded product fields survive projection, caching and detail display without density, ingredient-quantity or currentness inference. Source status and local reviewer references do not establish authenticated authority, upstream currentness or clinical approval. All nineteen whole prior governance records and twenty-two numerical implementations and parameter objects remain exact. SQLite process and browser software checks do not replace native plugin, OS-kill, real-device notification, independent human or clinical evidence. No publication, calibration or release approval is granted.',
        );
    final ordinaryImportStatusCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 21,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          reviewedProductIntegrationCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          reviewedProductIntegrationCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256:
          '6b5354220771a6d8a8aeb561cb3cfebe026daf1bf479807ce1766caf95b6a64f',
      evidenceCurrencyRegistrySha256: reviewedProductIntegrationCandidateRecord
          .evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256: reviewedProductIntegrationCandidateRecord
          .evidenceSynthesisRegistrySha256,
      semanticDiffSha256:
          reviewedProductIntegrationCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          reviewedProductIntegrationCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          reviewedProductIntegrationCandidateRecord.affectedPredicateIds,
      changeClasses: reviewedProductIntegrationCandidateRecord.changeClasses,
      modelRisk: reviewedProductIntegrationCandidateRecord.modelRisk,
      questionOfInterest:
          reviewedProductIntegrationCandidateRecord.questionOfInterest,
      contextOfUse: reviewedProductIntegrationCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-02T20:30:32.422718Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v72-candidate',
      evidenceDecisions:
          reviewedProductIntegrationCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v72 candidate distinguishes the exact ingestion markers emitted by the existing FDC, CIQUAL, China CDC and verified-report seed paths from unavailable lifecycle states. Marker and provider-family pairings are checked against the captured current source; unknown, mismatched, retired, held and future states remain unavailable. Source values, scopes and provider fields are not rewritten. A genuine FDC mass-basis observation retains its original point after complete Web-document capture and actual SQLite close/reopen; volume, dry-matter and unqualified bases remain withheld. The source-review page delegates validation and activation to existing registered services and has an exact reviewed surface disposition. All twenty whole prior governance records and all twenty-two numerical implementation fingerprints and parameter objects remain exact. Known local ingestion and software tests do not establish upstream currentness, authenticated human review, clinical permission, native plugin or OS-kill durability, physical-device performance, signature or publication. No release approval is granted.',
    );
    final personalRecordCapacityCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 22,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          ordinaryImportStatusCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          ordinaryImportStatusCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV73ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          ordinaryImportStatusCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          ordinaryImportStatusCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256:
          ordinaryImportStatusCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          ordinaryImportStatusCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          ordinaryImportStatusCandidateRecord.affectedPredicateIds,
      changeClasses: ordinaryImportStatusCandidateRecord.changeClasses,
      modelRisk: ordinaryImportStatusCandidateRecord.modelRisk,
      questionOfInterest:
          ordinaryImportStatusCandidateRecord.questionOfInterest,
      contextOfUse: ordinaryImportStatusCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-08T00:33:38Z',
      releaseArtifact: 'unreleased-worktree:mega-upgrade-v73-candidate',
      evidenceDecisions: ordinaryImportStatusCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v73 candidate moves the complete Web personal-record aggregate into a separate versioned IndexedDB envelope with retained exact original legacy witnesses, transaction completion and full read-back. Participating readers and writers share the existing same-origin Web Lock and isolate queue. Optional portable schema-v5 shares whole captured food-item evidence while retaining original quantities, checksum binding, the unchanged wire budgets and a separate pre-expansion budget; default small export and legacy migration target remain v4. Late uncooperative legacy writes can be detected after an already committed value; localStorage and IndexedDB have no cross-store atomic transaction. Browser quota, storage eviction and OS-kill durability remain outside this engineering contract. All twenty-one prior whole governance records and twenty-two numerical implementation fingerprints and parameters remain exact. Exact software fixtures do not establish authenticated human review, upstream currency, clinical permission, physical-device performance, complete transitive algorithm closure, signature or publication. No release approval is granted.',
    );
    final publicNutritionIntegrationCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 23,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          personalRecordCapacityCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          personalRecordCapacityCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV74ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          personalRecordCapacityCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          personalRecordCapacityCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256:
          personalRecordCapacityCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          personalRecordCapacityCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          personalRecordCapacityCandidateRecord.affectedPredicateIds,
      changeClasses: personalRecordCapacityCandidateRecord.changeClasses,
      modelRisk: personalRecordCapacityCandidateRecord.modelRisk,
      questionOfInterest:
          personalRecordCapacityCandidateRecord.questionOfInterest,
      contextOfUse: personalRecordCapacityCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-15T17:26:53.000Z',
      releaseArtifact: 'unreleased-worktree:claude-nutrition-integration-v74',
      evidenceDecisions:
          personalRecordCapacityCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v74 candidate integrates the public Claude nutrition baseline '
          'from main af7ef6981dad160c222c398b4d44946b21c30f8c, whose '
          'separate 2026.10.08-v54 configuration was '
          '48b6ede1c08109c0a2b60af162ebe30fc5e35315257d0cb9999f3c31eacb1427, '
          'with the local v73 storage, provenance and held-evidence review '
          'boundaries. The original twenty-two ledger records remain exact. '
          'The food-composition interdependency and composition identity audit '
          'are source-bound engineering behavior; inherited synthetic evidence '
          'decisions and earlier branch tests do not qualify this merged source. '
          'This record binds a new software identity only. It supplies no '
          'new independent review, scientific validity, clinical calibration, '
          'authenticated approval, release signature or production acceptance. '
          'All required evidence holds and blocked promotion remain in force.',
    );
    final provenanceAwareNutritionCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 24,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          publicNutritionIntegrationCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          publicNutritionIntegrationCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV75ConfigurationSha256,
      evidenceCurrencyRegistrySha256: publicNutritionIntegrationCandidateRecord
          .evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256: publicNutritionIntegrationCandidateRecord
          .evidenceSynthesisRegistrySha256,
      semanticDiffSha256:
          publicNutritionIntegrationCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          publicNutritionIntegrationCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          publicNutritionIntegrationCandidateRecord.affectedPredicateIds,
      changeClasses: publicNutritionIntegrationCandidateRecord.changeClasses,
      modelRisk: publicNutritionIntegrationCandidateRecord.modelRisk,
      questionOfInterest:
          publicNutritionIntegrationCandidateRecord.questionOfInterest,
      contextOfUse: publicNutritionIntegrationCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-15T22:58:24.903Z',
      releaseArtifact:
          'unreleased-worktree:claude-reference-profile-integration-v75',
      evidenceDecisions:
          publicNutritionIntegrationCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v75 candidate integrates Claude PR147 from public main '
          'cb24f6eea06517cdb8ea3c2a0b42a4beb2f96c71, whose separate '
          '2026.10.15-v55 configuration was '
          'e2a18594d3a825ad0fe21e5f82996e31036a0f0498cb9d8faed85f517bbdd346. '
          'It binds provenance-aware composition audit behavior and retains '
          'the source-bound reference nutrient profiles, local unknown-value, '
          'LOQ, ambiguity and held-review boundaries. All twenty-three prior '
          'records remain exact. Prior branch tests and inherited synthetic '
          'decisions do not qualify this merged source or supply new review, '
          'scientific validity, clinical calibration, authenticated approval, '
          'release signature or production acceptance. All evidence holds '
          'and blocked promotion remain in force.',
    );
    final browserRestorePerformanceCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 25,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          provenanceAwareNutritionCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          provenanceAwareNutritionCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV76ConfigurationSha256,
      evidenceCurrencyRegistrySha256: provenanceAwareNutritionCandidateRecord
          .evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256: provenanceAwareNutritionCandidateRecord
          .evidenceSynthesisRegistrySha256,
      semanticDiffSha256:
          provenanceAwareNutritionCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          provenanceAwareNutritionCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          provenanceAwareNutritionCandidateRecord.affectedPredicateIds,
      changeClasses: provenanceAwareNutritionCandidateRecord.changeClasses,
      modelRisk: provenanceAwareNutritionCandidateRecord.modelRisk,
      questionOfInterest:
          provenanceAwareNutritionCandidateRecord.questionOfInterest,
      contextOfUse: provenanceAwareNutritionCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-15T23:54:44.000Z',
      releaseArtifact: 'unreleased-worktree:browser-restore-performance-v76',
      evidenceDecisions:
          provenanceAwareNutritionCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v76 candidate binds local browser personal-record restore '
          'performance work, including reuse of a SHA-256 digest only for '
          'the exact same canonical string. Canonical bytes, wire budgets, '
          'validation, owner checks and clinical calculations remain unchanged. '
          'All twenty-four prior whole records and their digests remain exact. '
          'Local synthetic browser tests establish only their observed '
          'engineering scope; retained evidence and historical timestamps do '
          'not supply new scientific evidence, independent review, clinical '
          'qualification, authenticated approval or release acceptance. All '
          'evidence holds and blocked promotion remain in force.',
    );
    final lnaaCalibrationCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 26,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          browserRestorePerformanceCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          browserRestorePerformanceCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV77ConfigurationSha256,
      evidenceCurrencyRegistrySha256: browserRestorePerformanceCandidateRecord
          .evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256: browserRestorePerformanceCandidateRecord
          .evidenceSynthesisRegistrySha256,
      semanticDiffSha256:
          browserRestorePerformanceCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          browserRestorePerformanceCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          browserRestorePerformanceCandidateRecord.affectedPredicateIds,
      changeClasses: browserRestorePerformanceCandidateRecord.changeClasses,
      modelRisk: browserRestorePerformanceCandidateRecord.modelRisk,
      questionOfInterest:
          browserRestorePerformanceCandidateRecord.questionOfInterest,
      contextOfUse: browserRestorePerformanceCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-16T01:30:36.000Z',
      releaseArtifact: 'unreleased-worktree:lnaa-load-calibration-v77',
      evidenceDecisions:
          browserRestorePerformanceCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v77 candidate binds the LNAA competition load calibration on '
          'official FoodData Central 2025-04-24 SR Legacy amino-acid rows: '
          'the all-food median competing-LNAA fraction of protein replaces an '
          'unsupported 0.45 reference, and protein-source load factors become '
          'calibrated medians. Modeled competition pressure and overlap '
          'change; the mapping from load to pressure remains a prototype '
          'heuristic. All twenty-five prior whole records and their digests '
          'remain exact. Composition statistics describe foods, not people, '
          'and supply no new scientific evidence, independent review, '
          'clinical qualification, authenticated approval or release '
          'acceptance. All evidence holds and blocked promotion remain in '
          'force.',
    );
    final referenceRecordIdentityCandidateRecord = ContextOfUseRequalificationRecord(
      sequence: 27,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          lnaaCalibrationCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          lnaaCalibrationCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: historicalV78ConfigurationSha256,
      evidenceCurrencyRegistrySha256:
          lnaaCalibrationCandidateRecord.evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          lnaaCalibrationCandidateRecord.evidenceSynthesisRegistrySha256,
      semanticDiffSha256: lnaaCalibrationCandidateRecord.semanticDiffSha256,
      affectedProviderIds: lnaaCalibrationCandidateRecord.affectedProviderIds,
      affectedPredicateIds: lnaaCalibrationCandidateRecord.affectedPredicateIds,
      changeClasses: lnaaCalibrationCandidateRecord.changeClasses,
      modelRisk: lnaaCalibrationCandidateRecord.modelRisk,
      questionOfInterest: lnaaCalibrationCandidateRecord.questionOfInterest,
      contextOfUse: lnaaCalibrationCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-19T00:00:00.000Z',
      releaseArtifact:
          'unreleased-worktree:reference-record-identities-lnaa-detail-v78',
      evidenceDecisions: lnaaCalibrationCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v78 candidate maps every nutrient in the committed official '
          'FoodData Central 2025-04-24 SR Legacy rows and audits more '
          'definitional identities of each record (fatty-acid chains within '
          'their class, trans closure, individual sugars, vitamin A RAE and '
          'IU, vitamin D, folate and fortification amounts). The conflict '
          'engine reads the energy, proximate, carbohydrate, lipid and '
          'nitrogen findings of a scored reference food as a confidence cap '
          'and uncertainty reason only, and the LNAA summary adds trace-only '
          'per-component contributions, an extended-LNAA sensitivity and a '
          'molar ratio to an explicit logged amount. Scores do not change. '
          'All twenty-six prior whole records and their digests remain '
          'exact. Composition identities describe source records, not '
          'people, and supply no new scientific evidence, independent '
          'review, clinical qualification, authenticated approval or release '
          'acceptance. All evidence holds and blocked promotion remain in '
          'force.',
    );
    final proteinArrivalCaloricLiquidCandidateRecord =
        ContextOfUseRequalificationRecord(
          sequence: 28,
          changeKind: 'software_identity_candidate_rebind',
          previousManifestSha256:
              referenceRecordIdentityCandidateRecord.currentManifestSha256,
          previousConfigurationSha256:
              referenceRecordIdentityCandidateRecord.currentConfigurationSha256,
          currentManifestSha256: expectedCurrentManifestSha256,
          currentConfigurationSha256: historicalV79ConfigurationSha256,
          evidenceCurrencyRegistrySha256: referenceRecordIdentityCandidateRecord
              .evidenceCurrencyRegistrySha256,
          evidenceSynthesisRegistrySha256:
              referenceRecordIdentityCandidateRecord
                  .evidenceSynthesisRegistrySha256,
          semanticDiffSha256:
              referenceRecordIdentityCandidateRecord.semanticDiffSha256,
          affectedProviderIds:
              referenceRecordIdentityCandidateRecord.affectedProviderIds,
          affectedPredicateIds:
              referenceRecordIdentityCandidateRecord.affectedPredicateIds,
          changeClasses: referenceRecordIdentityCandidateRecord.changeClasses,
          modelRisk: referenceRecordIdentityCandidateRecord.modelRisk,
          questionOfInterest:
              referenceRecordIdentityCandidateRecord.questionOfInterest,
          contextOfUse: referenceRecordIdentityCandidateRecord.contextOfUse,
          author: 'automated-local-software-integration',
          recordedAtUtc: '2026-10-20T00:00:00.000Z',
          releaseArtifact:
              'unreleased-worktree:protein-arrival-caloric-liquids-v79',
          evidenceDecisions:
              referenceRecordIdentityCandidateRecord.evidenceDecisions,
          releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
          approvalSignature: null,
          decisionBoundary:
              'The v79 candidate corrects two gastric-model physics errors. The '
              'competition layer now shapes pressure by the arrival of protein '
              '(competing-LNAA grams when complete amino-acid profiles exist) '
              'instead of meal mass, so a component without protein, such as '
              'water, no longer sets the protein timing; the mass-weighted '
              'residual still sets the dose-time absorption shift. A liquid that '
              'carries energy is now delivered at a calorie-regulated rate of '
              '2.13 kcal/min (literature range 1–4 kcal/min) instead of emptying '
              'like water, and a liquid of unknown energy is drawn on the '
              'energy-free bound with widened uncertainty. Modeled competition, '
              'residual load and scores change. All twenty-seven prior whole '
              'records and their digests remain exact. The rate comes from '
              'glucose solutions in adults and supplies no new scientific '
              'evidence, independent review, clinical qualification, '
              'authenticated approval or release acceptance. All evidence holds '
              'and blocked promotion remain in force.',
        );
    final candidateServingBasisRecord = ContextOfUseRequalificationRecord(
      sequence: 29,
      changeKind: 'software_identity_candidate_rebind',
      previousManifestSha256:
          proteinArrivalCaloricLiquidCandidateRecord.currentManifestSha256,
      previousConfigurationSha256:
          proteinArrivalCaloricLiquidCandidateRecord.currentConfigurationSha256,
      currentManifestSha256: expectedCurrentManifestSha256,
      currentConfigurationSha256: expectedCurrentConfigurationSha256,
      evidenceCurrencyRegistrySha256: proteinArrivalCaloricLiquidCandidateRecord
          .evidenceCurrencyRegistrySha256,
      evidenceSynthesisRegistrySha256:
          proteinArrivalCaloricLiquidCandidateRecord
              .evidenceSynthesisRegistrySha256,
      semanticDiffSha256:
          proteinArrivalCaloricLiquidCandidateRecord.semanticDiffSha256,
      affectedProviderIds:
          proteinArrivalCaloricLiquidCandidateRecord.affectedProviderIds,
      affectedPredicateIds:
          proteinArrivalCaloricLiquidCandidateRecord.affectedPredicateIds,
      changeClasses: proteinArrivalCaloricLiquidCandidateRecord.changeClasses,
      modelRisk: proteinArrivalCaloricLiquidCandidateRecord.modelRisk,
      questionOfInterest:
          proteinArrivalCaloricLiquidCandidateRecord.questionOfInterest,
      contextOfUse: proteinArrivalCaloricLiquidCandidateRecord.contextOfUse,
      author: 'automated-local-software-integration',
      recordedAtUtc: '2026-10-20T00:00:00.000Z',
      releaseArtifact: 'unreleased-worktree:candidate-serving-basis-v80',
      evidenceDecisions:
          proteinArrivalCaloricLiquidCandidateRecord.evidenceDecisions,
      releaseDisposition: CouReleaseDisposition.blockedPendingEvidence,
      approvalSignature: null,
      decisionBoundary:
          'The v80 candidate evaluates catalog next-meal candidates at a '
          'reference serving instead of per 100 g: a source-reported portion '
          'chosen by a documented rule, else the FDA/USDA reference amount of '
          'the food\'s product category, else per 100 g with that label. A '
          'category reference amount is recorded as an assumed portion and '
          'widens uncertainty, and the legacy ranker compares its meal-sized '
          'protein and fiber thresholds with the same evaluated amount. The '
          'mechanistic trace stays trace-only. All twenty-eight prior whole '
          'records and their digests remain exact. A serving is a comparison '
          'amount, not portion advice, and supplies no new scientific '
          'evidence, independent review, clinical qualification, '
          'authenticated approval or release acceptance. All evidence holds '
          'and blocked promotion remain in force.',
    );
    return ContextOfUseRequalificationLedger._(
      manifest: manifest,
      currentConfigurationSha256: configurationSha256,
      evidenceCurrencyAssessment: assessment,
      evidenceSynthesisAssessment: synthesisAssessment,
      currentImpact: impact,
      records: [
        record,
        candidateRecord,
        megaCandidateRecord,
        productScopeCandidateRecord,
        ingredientClassCandidateRecord,
        medicationContextCandidateRecord,
        foodEnergyMethodCandidateRecord,
        searchSamplingCandidateRecord,
        preferenceSessionCandidateRecord,
        originStorageCandidateRecord,
        foodQuantityMethodCandidateRecord,
        timezoneRulesCandidateRecord,
        completeClusterNutrientCandidateRecord,
        incumbentActivationStrengthCandidateRecord,
        heldEvidenceReviewCandidateRecord,
        foodBasisCandidateRecord,
        cacheHeldResourcesCandidateRecord,
        atomicImportProductDetailsCandidateRecord,
        reviewedActivationCandidateRecord,
        reviewedProductIntegrationCandidateRecord,
        ordinaryImportStatusCandidateRecord,
        personalRecordCapacityCandidateRecord,
        publicNutritionIntegrationCandidateRecord,
        provenanceAwareNutritionCandidateRecord,
        browserRestorePerformanceCandidateRecord,
        lnaaCalibrationCandidateRecord,
        referenceRecordIdentityCandidateRecord,
        proteinArrivalCaloricLiquidCandidateRecord,
        candidateServingBasisRecord,
      ],
    );
  }

  ContextOfUseRequalificationRecord get latest => records.last;

  List<String> get integrityReasons {
    final reasons = <String>{};
    if (manifest.sha256Digest != expectedCurrentManifestSha256) {
      reasons.add('ledger.current_manifest_identity_mismatch');
    }
    if (currentConfigurationSha256 != expectedCurrentConfigurationSha256) {
      reasons.add('ledger.current_configuration_identity_mismatch');
    }
    if (evidenceCurrencyAssessment.registrySha256 !=
        expectedCurrentEvidenceCurrencyRegistrySha256) {
      reasons.add('ledger.evidence_currency_registry_identity_mismatch');
    }
    if (evidenceSynthesisAssessment.registrySha256 !=
        expectedCurrentEvidenceSynthesisRegistrySha256) {
      reasons.add('ledger.evidence_synthesis_registry_identity_mismatch');
    }
    reasons.addAll(
      evidenceCurrencyAssessment.integrityReasons.map(
        (reason) => 'ledger.evidence_currency_integrity:$reason',
      ),
    );
    for (final record in evidenceCurrencyAssessment.heldRecords) {
      reasons.add('ledger.evidence_currency_review_required:${record.claimId}');
    }
    for (final record in evidenceCurrencyAssessment.blockedRecords) {
      reasons.add('ledger.evidence_currency_blocked:${record.claimId}');
    }
    reasons.addAll(
      evidenceSynthesisAssessment.integrityReasons.map(
        (reason) => 'ledger.evidence_synthesis_integrity:$reason',
      ),
    );
    for (final adjudication in evidenceSynthesisAssessment.blockedBodies) {
      reasons.add(
        'ledger.evidence_synthesis_blocked:${adjudication.body.claimId}',
      );
    }
    if (records.isEmpty) reasons.add('ledger.records_empty');
    for (var index = 0; index < records.length; index += 1) {
      final record = records[index];
      if (record.sequence != index + 1) {
        reasons.add('ledger.sequence_noncontiguous');
      }
      if (!_isSha256(record.currentManifestSha256) ||
          !_isSha256(record.currentConfigurationSha256) ||
          !_isSha256(record.evidenceCurrencyRegistrySha256) ||
          !_isSha256(record.evidenceSynthesisRegistrySha256) ||
          !_isSha256(record.semanticDiffSha256)) {
        reasons.add('ledger.record_identity_invalid');
      }
      if (!_isUtcTimestamp(record.recordedAtUtc)) {
        reasons.add('ledger.record_time_invalid');
      }
      if (record.author.trim().isEmpty ||
          record.releaseArtifact.trim().isEmpty ||
          record.decisionBoundary.trim().isEmpty) {
        reasons.add('ledger.record_metadata_missing');
      }
      final evidenceKinds = <CouEvidenceKind>{};
      for (final decision in record.evidenceDecisions) {
        if (!evidenceKinds.add(decision.kind)) {
          reasons.add('ledger.evidence_kind_duplicate');
        }
        reasons.addAll(decision.integrityReasons);
      }
      if (evidenceKinds.length != CouEvidenceKind.values.length) {
        reasons.add('ledger.evidence_matrix_incomplete');
      }
    }
    if (records.isNotEmpty) {
      final record = latest;
      if (record.currentManifestSha256 != manifest.sha256Digest) {
        reasons.add('ledger.latest_manifest_mismatch');
      }
      if (record.currentConfigurationSha256 != currentConfigurationSha256) {
        reasons.add('ledger.latest_configuration_mismatch');
      }
      if (record.evidenceCurrencyRegistrySha256 !=
          evidenceCurrencyAssessment.registrySha256) {
        reasons.add('ledger.latest_evidence_currency_registry_mismatch');
      }
      if (record.evidenceSynthesisRegistrySha256 !=
          evidenceSynthesisAssessment.registrySha256) {
        reasons.add('ledger.latest_evidence_synthesis_registry_mismatch');
      }
      if (record.semanticDiffSha256 != currentImpact.semanticDiffSha256) {
        reasons.add('ledger.semantic_diff_mismatch');
      }
      if (!_sameStrings(
        record.affectedProviderIds,
        currentImpact.affectedProviderIds,
      )) {
        reasons.add('ledger.affected_providers_mismatch');
      }
      if (!_sameStrings(
        record.affectedPredicateIds,
        currentImpact.affectedPredicateIds,
      )) {
        reasons.add('ledger.affected_predicates_mismatch');
      }
      if (!_sameNames(record.changeClasses, currentImpact.changeClasses)) {
        reasons.add('ledger.change_classes_mismatch');
      }
      final evidence = {
        for (final decision in record.evidenceDecisions)
          decision.kind: decision,
      };
      final incompleteRequired = currentImpact.requiredEvidence.where(
        (kind) => evidence[kind]?.completeForPromotion != true,
      );
      if (record.releaseDisposition ==
              CouReleaseDisposition.approvedResearchTraceOnly &&
          (incompleteRequired.isNotEmpty ||
              record.approvalSignature == null ||
              record.approvalSignature!.trim().isEmpty)) {
        reasons.add('ledger.unsafe_approval');
      }
    }
    return List.unmodifiable(reasons);
  }

  List<CouEvidenceKind> get incompleteRequiredEvidence {
    final evidence = {
      for (final decision in latest.evidenceDecisions) decision.kind: decision,
    };
    return currentImpact.requiredEvidence
        .where((kind) => evidence[kind]?.completeForPromotion != true)
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Whether the immutable record still matches the exact governed runtime.
  ///
  /// This is deliberately independent from [canPromoteResearchTraceOnly]: a
  /// structurally valid ledger can and should remain fail-closed while
  /// scientific, human-factors, qualification, or independent-review evidence
  /// is incomplete.
  bool get integrityVerified => integrityReasons.isEmpty;

  bool get canPromoteResearchTraceOnly =>
      integrityVerified &&
      !evidenceSynthesisAssessment.requiresRequalification &&
      incompleteRequiredEvidence.isEmpty &&
      latest.releaseDisposition ==
          CouReleaseDisposition.approvedResearchTraceOnly &&
      latest.approvalSignature != null &&
      latest.approvalSignature!.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'ledger_version': ledgerVersion,
    'current_manifest_sha256': manifest.sha256Digest,
    'current_configuration_sha256': currentConfigurationSha256,
    'evidence_currency_assessment': evidenceCurrencyAssessment.toJson(),
    'evidence_synthesis_assessment': evidenceSynthesisAssessment.toJson(),
    'current_impact': currentImpact.toJson(),
    'can_promote_research_trace_only': canPromoteResearchTraceOnly,
    'incomplete_required_evidence': _sortedNames(incompleteRequiredEvidence),
    'integrity_reasons': integrityReasons,
    'records': records.map((record) => record.toJson()).toList(growable: false),
    'boundary':
        'A matching ledger proves an explicit change-control decision only. '
        'It is not scientific validation, model qualification, regulatory '
        'review, external approval, or medical advice.',
  };
}

final class CouManifestSemanticDiff {
  const CouManifestSemanticDiff._();

  static CouChangeImpact initialBaseline(
    MechanisticApplicabilityManifest manifest,
  ) {
    final changes = <CouSemanticChange>[];
    _diffValue('', null, manifest.canonicalPayload, changes);
    changes.sort((a, b) => a.path.compareTo(b.path));
    final classes = changes.map((change) => change.changeClass).toSet()
      ..add(CouChangeClass.initialGovernedBaseline)
      ..add(CouChangeClass.configurationIdentity);
    return CouChangeImpact(
      changes: changes,
      changeClasses: classes,
      affectedProviderIds: manifest.providers
          .map((provider) => provider.providerId)
          .toSet(),
      affectedPredicateIds: manifest.predicates
          .map((predicate) => predicate.id)
          .toSet(),
      requiredEvidence: const {
        CouEvidenceKind.implementationVerification,
        CouEvidenceKind.calculationVerification,
        CouEvidenceKind.uncertaintyAssessment,
        CouEvidenceKind.humanFactors,
        CouEvidenceKind.scientificValidation,
        CouEvidenceKind.modelQualification,
        CouEvidenceKind.independentReview,
      },
      modelRisk: CouModelRisk.critical,
    );
  }

  static CouChangeImpact between({
    required Map<String, Object?> previous,
    required Map<String, Object?> current,
    required Iterable<String> currentProviderIds,
    required Iterable<String> currentPredicateIds,
    bool configurationChanged = false,
  }) {
    final changes = <CouSemanticChange>[];
    _diffValue('', previous, current, changes);
    changes.sort((a, b) => a.path.compareTo(b.path));
    final classes = changes.map((change) => change.changeClass).toSet();
    if (configurationChanged) {
      classes.add(CouChangeClass.configurationIdentity);
    }
    final highImpact = classes.intersection(const {
      CouChangeClass.questionOfInterest,
      CouChangeClass.contextOfUse,
      CouChangeClass.observable,
      CouChangeClass.population,
      CouChangeClass.productIdentity,
      CouChangeClass.terminology,
      CouChangeClass.fedState,
      CouChangeClass.predicateContract,
      CouChangeClass.providerGraph,
      CouChangeClass.evidenceBase,
    });
    final required = <CouEvidenceKind>{
      CouEvidenceKind.implementationVerification,
      CouEvidenceKind.calculationVerification,
      CouEvidenceKind.independentReview,
      if (highImpact.isNotEmpty) ...const {
        CouEvidenceKind.uncertaintyAssessment,
        CouEvidenceKind.humanFactors,
        CouEvidenceKind.scientificValidation,
        CouEvidenceKind.modelQualification,
      },
    };
    return CouChangeImpact(
      changes: changes,
      changeClasses: classes,
      affectedProviderIds: Set.of(currentProviderIds),
      affectedPredicateIds: Set.of(currentPredicateIds),
      requiredEvidence: required,
      modelRisk: highImpact.isEmpty
          ? CouModelRisk.moderate
          : CouModelRisk.critical,
    );
  }

  static void _diffValue(
    String path,
    Object? previous,
    Object? current,
    List<CouSemanticChange> changes,
  ) {
    if (previous is Map && current is Map) {
      final keys = <String>{
        ...previous.keys.map((key) => '$key'),
        ...current.keys.map((key) => '$key'),
      }.toList(growable: false)..sort();
      for (final key in keys) {
        _diffValue(
          path.isEmpty ? key : '$path.$key',
          previous[key],
          current[key],
          changes,
        );
      }
      return;
    }
    if (previous is List && current is List) {
      final maxLength = previous.length > current.length
          ? previous.length
          : current.length;
      for (var index = 0; index < maxLength; index += 1) {
        _diffValue(
          '$path[$index]',
          index < previous.length ? previous[index] : null,
          index < current.length ? current[index] : null,
          changes,
        );
      }
      return;
    }
    if (previous == null && current is Map) {
      _diffValue(path, const <String, Object?>{}, current, changes);
      return;
    }
    if (previous == null && current is List) {
      _diffValue(path, const <Object?>[], current, changes);
      return;
    }
    if (_canonicalJson(previous) == _canonicalJson(current)) return;
    changes.add(
      CouSemanticChange(
        path: path,
        previousValue: previous,
        currentValue: current,
        changeClass: _classForPath(path),
      ),
    );
  }

  static CouChangeClass _classForPath(String path) {
    if (path == 'question_of_interest') {
      return CouChangeClass.questionOfInterest;
    }
    if (path == 'context_of_use') return CouChangeClass.contextOfUse;
    if (path == 'observable_boundary') return CouChangeClass.observable;
    if (path == 'population_boundary') return CouChangeClass.population;
    if (path == 'product_identity_boundary') {
      return CouChangeClass.productIdentity;
    }
    if (path == 'terminology_identity') return CouChangeClass.terminology;
    if (path == 'fed_state_boundary') return CouChangeClass.fedState;
    if (path.startsWith('predicates[')) {
      return CouChangeClass.predicateContract;
    }
    if (path.startsWith('providers[')) return CouChangeClass.providerGraph;
    if (path.startsWith('evidence_source_ids[')) {
      return CouChangeClass.evidenceBase;
    }
    if (path == 'review_state' || path == 'reviewed_at') {
      return CouChangeClass.reviewState;
    }
    return CouChangeClass.schemaOrIdentity;
  }
}

List<CouEvidenceDecision> _initialEvidenceDecisions() => [
  CouEvidenceDecision(
    kind: CouEvidenceKind.implementationVerification,
    status: CouEvidenceStatus.complete,
    evidenceIds: const [
      'gate.flutter_analyze',
      'gate.flutter_test',
      'gate.verify_all',
    ],
    reviewer: 'repository-maintainers',
    reviewedAtUtc: '2026-08-18T00:00:00.000Z',
    boundary:
        'Static analysis and automated tests verify implementation behavior; '
        'they do not validate biological truth.',
  ),
  CouEvidenceDecision(
    kind: CouEvidenceKind.calculationVerification,
    status: CouEvidenceStatus.complete,
    evidenceIds: const [
      'artifact.mechanistic_numerical_oracle.v1',
      'artifact.mechanistic_replay.v3',
    ],
    reviewer: 'repository-maintainers',
    reviewedAtUtc: '2026-08-18T00:00:00.000Z',
    boundary:
        'Manufactured vectors and replay verify reviewed calculations only; '
        'they do not establish scientific validity.',
  ),
  CouEvidenceDecision(
    kind: CouEvidenceKind.uncertaintyAssessment,
    status: CouEvidenceStatus.planned,
    evidenceIds: const [],
    reviewer: null,
    reviewedAtUtc: null,
    boundary:
        'Structural alternatives, parameter uncertainty, and applicability '
        'uncertainty remain incomplete.',
  ),
  CouEvidenceDecision(
    kind: CouEvidenceKind.humanFactors,
    status: CouEvidenceStatus.missing,
    evidenceIds: const [],
    reviewer: null,
    reviewedAtUtc: null,
    boundary:
        'No intended-user comprehension or misuse study establishes safe '
        'interpretation of the trace.',
  ),
  CouEvidenceDecision(
    kind: CouEvidenceKind.scientificValidation,
    status: CouEvidenceStatus.missing,
    evidenceIds: const [],
    reviewer: null,
    reviewedAtUtc: null,
    boundary:
        'No prospective patient-level biological or clinical validation '
        'supports the timing-overlap proxy.',
  ),
  CouEvidenceDecision(
    kind: CouEvidenceKind.modelQualification,
    status: CouEvidenceStatus.missing,
    evidenceIds: const [],
    reviewer: null,
    reviewedAtUtc: null,
    boundary:
        'No platform or model qualification exists for a clinical context of '
        'use, population, or product family.',
  ),
  CouEvidenceDecision(
    kind: CouEvidenceKind.independentReview,
    status: CouEvidenceStatus.missing,
    evidenceIds: const [],
    reviewer: null,
    reviewedAtUtc: null,
    boundary:
        'No independent domain reviewer has approved evidence relevance or '
        'adequacy for promotion.',
  ),
  CouEvidenceDecision(
    kind: CouEvidenceKind.regulatoryReview,
    status: CouEvidenceStatus.notRequired,
    evidenceIds: const [],
    reviewer: null,
    reviewedAtUtc: null,
    boundary:
        'The repository does not claim a regulatory submission or review.',
  ),
  CouEvidenceDecision(
    kind: CouEvidenceKind.externalApproval,
    status: CouEvidenceStatus.notRequired,
    evidenceIds: const [],
    reviewer: null,
    reviewedAtUtc: null,
    boundary:
        'The repository does not claim approval, clearance, certification, or '
        'clinical qualification by an external authority.',
  ),
];

bool _sameStrings(Iterable<String> left, Iterable<String> right) =>
    _sortedStrings(left).join('\u0000') == _sortedStrings(right).join('\u0000');

bool _sameNames(Iterable<Enum> left, Iterable<Enum> right) =>
    _sortedNames(left).join('\u0000') == _sortedNames(right).join('\u0000');

List<String> _sortedStrings(Iterable<String> values) =>
    values.toSet().toList(growable: false)..sort();

List<String> _sortedNames(Iterable<Enum> values) =>
    values.map((value) => value.name).toSet().toList(growable: false)..sort();

bool _isSha256(String? value) =>
    value != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

bool _isUtcTimestamp(String? value) {
  if (value == null || !value.endsWith('Z')) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.isUtc;
}

String _sha256(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList(growable: false)
      ..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList(growable: false);
  return value;
}
