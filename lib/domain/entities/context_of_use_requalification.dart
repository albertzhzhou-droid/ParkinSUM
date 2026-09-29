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
  static const String ledgerVersion = '2026.09.21-v38';

  static const String expectedCurrentManifestSha256 =
      '3e560401c21a1fd3eec3ed75e24f8753797e7e8d14f70b495086bb5fe2db0dc7';
  static const String expectedCurrentConfigurationSha256 =
      '918baef0e5864928bcd20b8e8e855280f8fc1a306b956110498f9d7b06997940';
  static const String expectedInitialSemanticDiffSha256 =
      '1a2047b215617d8b85cf57189de6b7a7aaa0706c27b0ff1ac1689a6bd68a4937';
  static const String expectedCurrentEvidenceCurrencyRegistrySha256 =
      '63ad0dd1543186d67d47499966ca4fa292c13ba7bfcab750813055e901d94c2e';
  static const String expectedCurrentEvidenceSynthesisRegistrySha256 =
      'b875cc6686bf56bb12822495ea538977304554d5044a7b83177198c215d431f7';
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
      currentConfigurationSha256: expectedCurrentConfigurationSha256,
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
          'The v41 refresh binds workflow/provenance/observation-timeline '
          'source changes only; retained synthetic fixture timestamps do not '
          'attest current-worktree review or evidence coverage.',
    );
    return ContextOfUseRequalificationLedger._(
      manifest: manifest,
      currentConfigurationSha256: configurationSha256,
      evidenceCurrencyAssessment: assessment,
      evidenceSynthesisAssessment: synthesisAssessment,
      currentImpact: impact,
      records: [record],
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
