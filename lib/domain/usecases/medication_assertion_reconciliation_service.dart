import '../../core/models/intake.dart';
import '../entities/medication_assertion_reconciliation.dart';

enum MedicationAssertionRelationship {
  duplicate,
  corroborates,
  doseConflict,
  timeConflict,
  productConflict,
  statusConflict,
  partialOverlap,
  sourceRevisionConflict,
  supersedes,
  retracts,
  derivedFrom,
  futureDated,
  clockSkew,
  timezoneAmbiguous,
  unresolvedCandidateMatch,
}

final class MedicationAssertionEdge {
  const MedicationAssertionEdge({
    required this.edgeId,
    required this.fromAssertionId,
    required this.toAssertionId,
    required this.relationship,
    required this.blocking,
    required this.reasonCode,
  });

  final String edgeId;
  final String fromAssertionId;
  final String toAssertionId;
  final MedicationAssertionRelationship relationship;
  final bool blocking;
  final String reasonCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'edge_id': edgeId,
    'from_assertion_id': fromAssertionId,
    'to_assertion_id': toAssertionId,
    'relationship': relationship.name,
    'blocking': blocking,
    'reason_code': reasonCode,
  };
}

final class MedicationAssertionGraph {
  const MedicationAssertionGraph({
    required this.graphDigest,
    required this.intakeId,
    required this.nodes,
    required this.edges,
    required this.integrityFindings,
    required this.currentDecision,
    required this.staleDecisionCount,
    required this.resultAffectingDoseEligible,
    required this.resultGateReasons,
  });

  final String graphDigest;
  final String intakeId;
  final List<MedicationAssertionNode> nodes;
  final List<MedicationAssertionEdge> edges;
  final List<String> integrityFindings;
  final MedicationReconciliationDecision? currentDecision;
  final int staleDecisionCount;
  final bool resultAffectingDoseEligible;
  final List<String> resultGateReasons;

  List<MedicationAssertionEdge> get blockingEdges =>
      edges.where((edge) => edge.blocking).toList(growable: false);

  bool get hasUnresolvedConflict =>
      blockingEdges.isNotEmpty || integrityFindings.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 'parkinsum.medication-assertion-conflict-graph/1',
    'schema_version': 1,
    'graph_digest': graphDigest,
    'intake_id': intakeId,
    'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
    'edges': edges.map((edge) => edge.toJson()).toList(growable: false),
    'integrity_findings': integrityFindings,
    'current_decision': currentDecision?.toJson(),
    'stale_decision_count': staleDecisionCount,
    'result_affecting_dose_eligible': resultAffectingDoseEligible,
    'result_gate_reasons': resultGateReasons,
    'meaning_boundary':
        'Deterministic source-conflict trace only. It does not infer adherence, establish administration, or perform clinical medication reconciliation.',
  };
}

/// Conflict relationships rebuilt from only the claims and decisions known at
/// a historical cutoff. This view deliberately carries no dose-eligibility
/// field: it is an evidence review structure, not an algorithm gate result.
final class MedicationAssertionHistoricalConflictGraph {
  const MedicationAssertionHistoricalConflictGraph({
    required this.graphDigest,
    required this.intakeId,
    required this.validAtUtc,
    required this.knownAtUtc,
    required this.nodes,
    required this.edges,
    required this.integrityFindings,
    required this.currentDecision,
    required this.staleDecisionCount,
  });

  final String graphDigest;
  final String intakeId;
  final DateTime validAtUtc;
  final DateTime knownAtUtc;
  final List<MedicationAssertionNode> nodes;
  final List<MedicationAssertionEdge> edges;
  final List<String> integrityFindings;
  final MedicationReconciliationDecision? currentDecision;
  final int staleDecisionCount;

  List<MedicationAssertionEdge> get blockingEdges =>
      edges.where((edge) => edge.blocking).toList(growable: false);

  bool get hasUnresolvedConflict =>
      blockingEdges.isNotEmpty || integrityFindings.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'graph_digest': graphDigest,
    'intake_id': intakeId,
    'valid_at_utc': validAtUtc.toIso8601String(),
    'known_at_utc': knownAtUtc.toIso8601String(),
    'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
    'edges': edges.map((edge) => edge.toJson()).toList(growable: false),
    'integrity_findings': integrityFindings,
    'current_review_decision': currentDecision?.toJson(),
    'stale_decision_count': staleDecisionCount,
    'blocking_edge_count': blockingEdges.length,
    'has_unresolved_conflict': hasUnresolvedConflict,
    'meaning_boundary':
        'Historical source-conflict graph for evidence review only. It does not determine dose eligibility or establish clinical reconciliation.',
  };
}

enum MedicationAssertionKnowledgeStatus {
  availableAtCutoff,
  afterKnowledgeCutoff,
  unresolvedKnowledgeTime,
  invalidEvidence,
}

enum MedicationAggregateIntegrityTemporalStatus {
  noUntimedMarkerOnSourceSnapshot,
  knowledgeTimeUnresolved,
}

enum MedicationAssertionValidTimeStatus {
  inEffectiveInterval,
  outsideEffectiveInterval,
  uncertainEffectiveTime,
  notEvaluated,
}

/// One assertion's visibility in a two-clock, read-only evidence projection.
///
/// Assertions that were not knowable at the requested knowledge cutoff are
/// represented by ID and reason only; their medication details are withheld
/// from the historical view.
final class MedicationAssertionBitemporalEntry {
  const MedicationAssertionBitemporalEntry({
    required this.assertionId,
    required this.assertion,
    required this.knowledgeStatus,
    required this.validTimeStatus,
    required this.availableAtUtc,
    required this.reasonCodes,
  });

  final String assertionId;
  final MedicationAssertionNode? assertion;
  final MedicationAssertionKnowledgeStatus knowledgeStatus;
  final MedicationAssertionValidTimeStatus validTimeStatus;
  final DateTime? availableAtUtc;
  final List<String> reasonCodes;

  Map<String, Object?> toJson() => <String, Object?>{
    'assertion_id': assertionId,
    'knowledge_status': knowledgeStatus.name,
    'valid_time_status': validTimeStatus.name,
    'available_at_utc': availableAtUtc?.toIso8601String(),
    'reason_codes': reasonCodes,
    if (assertion != null) 'assertion': assertion!.toJson(),
  };
}

/// A reconciliation decision as visible at a historical knowledge cutoff.
final class MedicationDecisionBitemporalEntry {
  const MedicationDecisionBitemporalEntry({
    required this.decisionId,
    required this.decision,
    required this.knowledgeStatus,
    required this.availableAtUtc,
    required this.reasonCodes,
  });

  final String decisionId;
  final MedicationReconciliationDecision? decision;
  final MedicationAssertionKnowledgeStatus knowledgeStatus;
  final DateTime? availableAtUtc;
  final List<String> reasonCodes;

  Map<String, Object?> toJson() => <String, Object?>{
    'decision_id': decisionId,
    'knowledge_status': knowledgeStatus.name,
    'available_at_utc': availableAtUtc?.toIso8601String(),
    'reason_codes': reasonCodes,
    if (decision != null) 'decision': decision!.toJson(),
  };
}

/// Immutable answer to: what evidence covered a clinical time, using only
/// claims and decisions available by a separate knowledge-time cutoff?
///
/// This is an evidence projection, never a dose or clinical eligibility result.
final class MedicationAssertionBitemporalProjection {
  const MedicationAssertionBitemporalProjection({
    required this.projectionDigest,
    required this.intakeId,
    required this.validAtUtc,
    required this.knownAtUtc,
    required this.assertions,
    required this.decisions,
    required this.historicalConflictGraph,
    required this.aggregateIntegrityTemporalStatus,
    required this.integrityFindings,
  });

  final String projectionDigest;
  final String intakeId;
  final DateTime validAtUtc;
  final DateTime knownAtUtc;
  final List<MedicationAssertionBitemporalEntry> assertions;
  final List<MedicationDecisionBitemporalEntry> decisions;
  final MedicationAssertionHistoricalConflictGraph historicalConflictGraph;
  final MedicationAggregateIntegrityTemporalStatus
  aggregateIntegrityTemporalStatus;
  final List<String> integrityFindings;

  List<MedicationAssertionNode> get availableAssertions => assertions
      .where(
        (entry) =>
            entry.knowledgeStatus ==
                MedicationAssertionKnowledgeStatus.availableAtCutoff &&
            entry.assertion != null,
      )
      .map((entry) => entry.assertion!)
      .toList(growable: false);

  List<MedicationAssertionNode> get assertionsAtValidTime => assertions
      .where(
        (entry) =>
            entry.knowledgeStatus ==
                MedicationAssertionKnowledgeStatus.availableAtCutoff &&
            entry.validTimeStatus ==
                MedicationAssertionValidTimeStatus.inEffectiveInterval &&
            entry.assertion != null,
      )
      .map((entry) => entry.assertion!)
      .toList(growable: false);

  List<MedicationAssertionNode> get assertionsWithUncertainValidTime =>
      assertions
          .where(
            (entry) =>
                entry.knowledgeStatus ==
                    MedicationAssertionKnowledgeStatus.availableAtCutoff &&
                entry.validTimeStatus ==
                    MedicationAssertionValidTimeStatus.uncertainEffectiveTime &&
                entry.assertion != null,
          )
          .map((entry) => entry.assertion!)
          .toList(growable: false);

  List<MedicationReconciliationDecision> get decisionsAvailableAtCutoff =>
      decisions
          .where(
            (entry) =>
                entry.knowledgeStatus ==
                    MedicationAssertionKnowledgeStatus.availableAtCutoff &&
                entry.decision != null,
          )
          .map((entry) => entry.decision!)
          .toList(growable: false);

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 'parkinsum.medication-assertion-bitemporal-projection/3',
    'schema_version': 3,
    'projection_digest': projectionDigest,
    'intake_id': intakeId,
    'valid_at_utc': validAtUtc.toIso8601String(),
    'known_at_utc': knownAtUtc.toIso8601String(),
    'assertions': assertions
        .map((entry) => entry.toJson())
        .toList(growable: false),
    'decisions': decisions
        .map((entry) => entry.toJson())
        .toList(growable: false),
    'historical_conflict_graph': historicalConflictGraph.toJson(),
    'aggregate_integrity_temporal_status':
        aggregateIntegrityTemporalStatus.name,
    'integrity_findings': integrityFindings,
    'result_affecting_dose_eligible': false,
    'meaning_boundary':
        'Historical evidence projection only. It does not establish administration, adherence, clinical reconciliation, or dose eligibility.',
  };
}

/// Deterministically retains source and time disagreements without assigning a
/// universal source hierarchy. Any unresolved relationship in the source chain
/// holds numeric dose use even after the user acknowledges seeing it.
final class MedicationAssertionReconciliationService {
  const MedicationAssertionReconciliationService();

  MedicationAssertionBitemporalProjection projectBitemporal({
    required Intake intake,
    required String ownerScope,
    required DateTime validAt,
    required DateTime knownAt,
  }) {
    final validAtUtc = validAt.toUtc();
    final knownAtUtc = knownAt.toUtc();
    final findings = <String>{};
    final aggregateIntegrityTemporalStatus =
        intake.invalidMedicationReconciliationEvidence == null
        ? MedicationAggregateIntegrityTemporalStatus
              .noUntimedMarkerOnSourceSnapshot
        : MedicationAggregateIntegrityTemporalStatus.knowledgeTimeUnresolved;
    if (aggregateIntegrityTemporalStatus ==
        MedicationAggregateIntegrityTemporalStatus.knowledgeTimeUnresolved) {
      findings.add('projection.aggregate_integrity_knowledge_time_unresolved');
    }

    final assertionEntries = <MedicationAssertionBitemporalEntry>[];
    for (final node in intake.medicationAssertions) {
      final reasons = <String>{};
      final availableAtUtc = _latestKnowledgeClock(node);
      try {
        node.validate();
      } on Object {
        reasons.add('projection.assertion_invalid');
      }
      if (!node.belongsToScope(ownerScope)) {
        reasons.add('projection.owner_mismatch');
      }
      if (node.intakeId != intake.id) {
        reasons.add('projection.intake_mismatch');
      }

      var knowledgeStatus =
          MedicationAssertionKnowledgeStatus.availableAtCutoff;
      var validTimeStatus = MedicationAssertionValidTimeStatus.notEvaluated;
      MedicationAssertionNode? visibleNode = node;
      if (reasons.isNotEmpty) {
        knowledgeStatus = MedicationAssertionKnowledgeStatus.invalidEvidence;
        visibleNode = null;
        findings.addAll(reasons.map((reason) => '$reason:${node.assertionId}'));
      } else if (node.evidenceClass ==
              MedicationAssertionEvidenceClass.importedStatement &&
          node.importedAtUtc == null) {
        knowledgeStatus =
            MedicationAssertionKnowledgeStatus.unresolvedKnowledgeTime;
        visibleNode = null;
        reasons.add('projection.import_time_missing');
        findings.add('projection.import_time_missing:${node.assertionId}');
      } else {
        if (node.assertedAtUtc.isAfter(knownAtUtc)) {
          reasons.add('projection.asserted_after_known_at');
        }
        if (node.importedAtUtc?.isAfter(knownAtUtc) ?? false) {
          reasons.add('projection.imported_after_known_at');
        }
        if (node.recordedAtUtc.isAfter(knownAtUtc)) {
          reasons.add('projection.recorded_after_known_at');
        }
        if (reasons.isNotEmpty) {
          knowledgeStatus =
              MedicationAssertionKnowledgeStatus.afterKnowledgeCutoff;
          visibleNode = null;
        } else {
          validTimeStatus = _validTimeStatus(node, validAtUtc);
          if (validTimeStatus ==
              MedicationAssertionValidTimeStatus.uncertainEffectiveTime) {
            reasons.add('projection.effective_time_uncertain');
          }
          if (validTimeStatus ==
              MedicationAssertionValidTimeStatus.outsideEffectiveInterval) {
            reasons.add('projection.outside_effective_interval');
          }
        }
      }
      assertionEntries.add(
        MedicationAssertionBitemporalEntry(
          assertionId: node.assertionId,
          assertion: visibleNode,
          knowledgeStatus: knowledgeStatus,
          validTimeStatus: validTimeStatus,
          availableAtUtc: availableAtUtc,
          reasonCodes: List<String>.unmodifiable(reasons.toList()..sort()),
        ),
      );
    }
    assertionEntries.sort((left, right) {
      final byId = left.assertionId.compareTo(right.assertionId);
      if (byId != 0) return byId;
      return left.knowledgeStatus.name.compareTo(right.knowledgeStatus.name);
    });

    final decisionEntries = <MedicationDecisionBitemporalEntry>[];
    for (final decision in intake.medicationReconciliationDecisions) {
      final reasons = <String>{};
      try {
        decision.validate();
      } on Object {
        reasons.add('projection.decision_invalid');
      }
      if (decision.intakeId != intake.id ||
          decision.ownerScopeDigest !=
              digestMedicationAssertionIdentity(ownerScope)) {
        reasons.add('projection.decision_binding_mismatch');
      }
      var knowledgeStatus =
          MedicationAssertionKnowledgeStatus.availableAtCutoff;
      MedicationReconciliationDecision? visibleDecision = decision;
      if (reasons.isNotEmpty) {
        knowledgeStatus = MedicationAssertionKnowledgeStatus.invalidEvidence;
        visibleDecision = null;
        findings.addAll(
          reasons.map((reason) => '$reason:${decision.decisionId}'),
        );
      } else if (decision.decidedAtUtc.isAfter(knownAtUtc)) {
        knowledgeStatus =
            MedicationAssertionKnowledgeStatus.afterKnowledgeCutoff;
        visibleDecision = null;
        reasons.add('projection.decision_after_known_at');
      }
      decisionEntries.add(
        MedicationDecisionBitemporalEntry(
          decisionId: decision.decisionId,
          decision: visibleDecision,
          knowledgeStatus: knowledgeStatus,
          availableAtUtc: decision.decidedAtUtc,
          reasonCodes: List<String>.unmodifiable(reasons.toList()..sort()),
        ),
      );
    }
    decisionEntries.sort((left, right) {
      final byId = left.decisionId.compareTo(right.decisionId);
      if (byId != 0) return byId;
      return left.knowledgeStatus.name.compareTo(right.knowledgeStatus.name);
    });

    final historicallyVisibleIntake = intake.copyWith(
      medicationAssertions: assertionEntries
          .where(
            (entry) =>
                entry.knowledgeStatus ==
                    MedicationAssertionKnowledgeStatus.availableAtCutoff &&
                entry.assertion != null,
          )
          .map((entry) => entry.assertion!)
          .toList(growable: false),
      medicationReconciliationDecisions: decisionEntries
          .where(
            (entry) =>
                entry.knowledgeStatus ==
                    MedicationAssertionKnowledgeStatus.availableAtCutoff &&
                entry.decision != null,
          )
          .map((entry) => entry.decision!)
          .toList(growable: false),
    );
    final rebuiltGraph = _build(
      intake: historicallyVisibleIntake,
      ownerScope: ownerScope,
      observedAt: validAtUtc,
      includeUntimedAggregateIntegrityFinding: false,
    );
    final historicalConflictGraph = MedicationAssertionHistoricalConflictGraph(
      graphDigest: rebuiltGraph.graphDigest,
      intakeId: rebuiltGraph.intakeId,
      validAtUtc: validAtUtc,
      knownAtUtc: knownAtUtc,
      nodes: rebuiltGraph.nodes,
      edges: rebuiltGraph.edges,
      integrityFindings: rebuiltGraph.integrityFindings,
      currentDecision: rebuiltGraph.currentDecision,
      staleDecisionCount: rebuiltGraph.staleDecisionCount,
    );

    final orderedFindings = findings.toList()..sort();
    final identity = <String, Object?>{
      'schema': 'parkinsum.medication-assertion-bitemporal-projection/3',
      'intake_id': intake.id,
      'valid_at_utc': validAtUtc.toIso8601String(),
      'known_at_utc': knownAtUtc.toIso8601String(),
      'assertions': assertionEntries
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'decisions': decisionEntries
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'historical_conflict_graph': historicalConflictGraph.toJson(),
      'aggregate_integrity_temporal_status':
          aggregateIntegrityTemporalStatus.name,
      'integrity_findings': orderedFindings,
    };
    return MedicationAssertionBitemporalProjection(
      projectionDigest: medicationAssertionSnapshotDigest(identity),
      intakeId: intake.id,
      validAtUtc: validAtUtc,
      knownAtUtc: knownAtUtc,
      assertions: List<MedicationAssertionBitemporalEntry>.unmodifiable(
        assertionEntries,
      ),
      decisions: List<MedicationDecisionBitemporalEntry>.unmodifiable(
        decisionEntries,
      ),
      historicalConflictGraph: historicalConflictGraph,
      aggregateIntegrityTemporalStatus: aggregateIntegrityTemporalStatus,
      integrityFindings: List<String>.unmodifiable(orderedFindings),
    );
  }

  MedicationAssertionGraph build({
    required Intake intake,
    required String ownerScope,
    required DateTime observedAt,
  }) => _build(
    intake: intake,
    ownerScope: ownerScope,
    observedAt: observedAt,
    includeUntimedAggregateIntegrityFinding: true,
  );

  MedicationAssertionGraph _build({
    required Intake intake,
    required String ownerScope,
    required DateTime observedAt,
    required bool includeUntimedAggregateIntegrityFinding,
  }) {
    final nodes = List<MedicationAssertionNode>.from(
      intake.medicationAssertions,
    )..sort((left, right) => left.assertionId.compareTo(right.assertionId));
    final integrity = <String>{};
    if (intake.invalidMedicationReconciliationEvidence != null &&
        includeUntimedAggregateIntegrityFinding) {
      integrity.add('reconciliation.invalid_evidence');
    }
    final nodeById = <String, MedicationAssertionNode>{};
    for (final node in nodes) {
      try {
        node.validate();
      } on Object {
        integrity.add('assertion.invalid:${node.assertionId}');
      }
      if (!node.belongsToScope(ownerScope)) {
        integrity.add('assertion.owner_mismatch:${node.assertionId}');
      }
      if (node.intakeId != intake.id) {
        integrity.add('assertion.intake_mismatch:${node.assertionId}');
      }
      if (nodeById.putIfAbsent(node.assertionId, () => node) != node) {
        integrity.add('assertion.duplicate_id:${node.assertionId}');
      }
    }

    final edges = <MedicationAssertionEdge>[];
    final inactiveByRelation = <String>{};
    for (final node in nodes) {
      inactiveByRelation
        ..addAll(node.supersedesAssertionIds)
        ..addAll(node.retractsAssertionIds);
      _referenceEdges(
        node: node,
        targets: node.derivedFromAssertionIds,
        relationship: MedicationAssertionRelationship.derivedFrom,
        blocking: false,
        nodeById: nodeById,
        edges: edges,
        integrity: integrity,
      );
      _referenceEdges(
        node: node,
        targets: node.supersedesAssertionIds,
        relationship: MedicationAssertionRelationship.supersedes,
        blocking: false,
        nodeById: nodeById,
        edges: edges,
        integrity: integrity,
      );
      _referenceEdges(
        node: node,
        targets: node.retractsAssertionIds,
        relationship: MedicationAssertionRelationship.retracts,
        blocking: true,
        nodeById: nodeById,
        edges: edges,
        integrity: integrity,
      );
      _unaryTemporalEdges(node, observedAt.toUtc(), edges);
    }

    for (var leftIndex = 0; leftIndex < nodes.length; leftIndex++) {
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < nodes.length;
        rightIndex++
      ) {
        final left = nodes[leftIndex];
        final right = nodes[rightIndex];
        if (left.supersedesAssertionIds.contains(right.assertionId) ||
            right.supersedesAssertionIds.contains(left.assertionId) ||
            left.retractsAssertionIds.contains(right.assertionId) ||
            right.retractsAssertionIds.contains(left.assertionId)) {
          continue;
        }
        _pairEdges(left, right, edges);
      }
    }
    edges.sort((left, right) => left.edgeId.compareTo(right.edgeId));
    final orderedIntegrity = integrity.toList()..sort();
    final graphDigest = medicationAssertionSnapshotDigest(<String, Object?>{
      'schema': 'parkinsum.medication-assertion-conflict-graph/1',
      'intake_id': intake.id,
      'node_digests': nodes.map((node) => node.assertionDigest).toList(),
      'edges': edges.map((edge) => edge.toJson()).toList(),
      'integrity_findings': orderedIntegrity,
    });

    final matchingDecisions = <MedicationReconciliationDecision>[];
    var staleDecisionCount = 0;
    for (final decision in intake.medicationReconciliationDecisions) {
      try {
        decision.validate();
      } on Object {
        integrity.add('decision.invalid:${decision.decisionId}');
        continue;
      }
      if (decision.intakeId != intake.id ||
          decision.ownerScopeDigest !=
              digestMedicationAssertionIdentity(ownerScope)) {
        integrity.add('decision.binding_mismatch:${decision.decisionId}');
        continue;
      }
      if (decision.graphDigest == graphDigest) {
        matchingDecisions.add(decision);
      } else {
        staleDecisionCount++;
      }
    }
    matchingDecisions.sort(
      (left, right) => right.decidedAtUtc.compareTo(left.decidedAtUtc),
    );
    final currentDecision = matchingDecisions.firstOrNull;

    final gateReasons = <String>{};
    final receipt = intake.doseConfirmation;
    final localNodes = nodes
        .where(
          (node) =>
              node.isCurrentLocalConfirmation &&
              !inactiveByRelation.contains(node.assertionId) &&
              node.localConfirmationReceiptDigest == receipt?.receiptDigest,
        )
        .toList(growable: false);
    if (receipt == null) {
      gateReasons.add('assertion_graph.local_receipt_absent');
    }
    if (localNodes.length != 1) {
      gateReasons.add('assertion_graph.local_confirmation_not_unique');
    }
    if (orderedIntegrity.isNotEmpty || integrity.isNotEmpty) {
      gateReasons.add('assertion_graph.integrity_blocked');
    }
    if (edges.any((edge) => edge.blocking)) {
      gateReasons.add('assertion_graph.unresolved_conflict');
    }
    if (localNodes.length == 1) {
      final local = localNodes.single;
      if (local.medicationId != intake.drugId ||
          local.doseValue != intake.doseAmount ||
          local.doseUnit != intake.doseUnit ||
          local.effectiveStartUtc != intake.takenAt.toUtc() ||
          local.sourceArtifactDigest != receipt?.receiptDigest) {
        gateReasons.add('assertion_graph.local_confirmation_drift');
      }
    }
    if (currentDecision?.resolution ==
        MedicationReconciliationResolution.heldForReview) {
      gateReasons.add('assertion_graph.user_held_for_review');
    }
    final orderedGateReasons = gateReasons.toList()..sort();
    final finalIntegrity = integrity.toList()..sort();
    return MedicationAssertionGraph(
      graphDigest: graphDigest,
      intakeId: intake.id,
      nodes: List<MedicationAssertionNode>.unmodifiable(nodes),
      edges: List<MedicationAssertionEdge>.unmodifiable(edges),
      integrityFindings: List<String>.unmodifiable(finalIntegrity),
      currentDecision: currentDecision,
      staleDecisionCount: staleDecisionCount,
      resultAffectingDoseEligible: orderedGateReasons.isEmpty,
      resultGateReasons: List<String>.unmodifiable(orderedGateReasons),
    );
  }

  DateTime _latestKnowledgeClock(MedicationAssertionNode node) {
    var latest = node.recordedAtUtc;
    if (node.assertedAtUtc.isAfter(latest)) latest = node.assertedAtUtc;
    if (node.importedAtUtc?.isAfter(latest) ?? false) {
      latest = node.importedAtUtc!;
    }
    return latest;
  }

  MedicationAssertionValidTimeStatus _validTimeStatus(
    MedicationAssertionNode node,
    DateTime validAtUtc,
  ) {
    final start = node.effectiveStartUtc;
    final end = node.effectiveEndUtc;
    if (start == null ||
        end == null ||
        node.timePrecision == MedicationAssertionTimePrecision.unknown ||
        node.timezoneSource == MedicationAssertionTimezoneSource.unknown) {
      return MedicationAssertionValidTimeStatus.uncertainEffectiveTime;
    }
    final uncertainty = Duration(minutes: node.timeUncertaintyMinutes);
    final possibleStart = start.subtract(uncertainty);
    final possibleEnd = end.add(uncertainty);
    if (validAtUtc.isBefore(possibleStart) || validAtUtc.isAfter(possibleEnd)) {
      return MedicationAssertionValidTimeStatus.outsideEffectiveInterval;
    }
    if (validAtUtc.isBefore(start) || validAtUtc.isAfter(end)) {
      return MedicationAssertionValidTimeStatus.uncertainEffectiveTime;
    }
    return MedicationAssertionValidTimeStatus.inEffectiveInterval;
  }

  void _referenceEdges({
    required MedicationAssertionNode node,
    required List<String> targets,
    required MedicationAssertionRelationship relationship,
    required bool blocking,
    required Map<String, MedicationAssertionNode> nodeById,
    required List<MedicationAssertionEdge> edges,
    required Set<String> integrity,
  }) {
    for (final target in targets) {
      if (!nodeById.containsKey(target) || target == node.assertionId) {
        integrity.add(
          'assertion.dangling_${relationship.name}:${node.assertionId}:$target',
        );
        continue;
      }
      edges.add(
        _edge(
          node.assertionId,
          target,
          relationship,
          blocking,
          'assertion_graph.${relationship.name}',
        ),
      );
    }
  }

  void _unaryTemporalEdges(
    MedicationAssertionNode node,
    DateTime observedAtUtc,
    List<MedicationAssertionEdge> edges,
  ) {
    final uncertainty = Duration(minutes: node.timeUncertaintyMinutes);
    final futureBoundary = observedAtUtc.add(uncertainty);
    if (node.effectiveStartUtc?.isAfter(futureBoundary) ?? false) {
      edges.add(
        _edge(
          node.assertionId,
          node.assertionId,
          MedicationAssertionRelationship.futureDated,
          true,
          'assertion_graph.future_dated',
        ),
      );
    }
    if (node.assertedAtUtc.isAfter(node.recordedAtUtc.add(uncertainty)) ||
        (node.importedAtUtc?.isAfter(node.recordedAtUtc.add(uncertainty)) ??
            false)) {
      edges.add(
        _edge(
          node.assertionId,
          node.assertionId,
          MedicationAssertionRelationship.clockSkew,
          true,
          'assertion_graph.clock_skew',
        ),
      );
    }
    if (node.timePrecision != MedicationAssertionTimePrecision.unknown &&
        node.timezoneSource == MedicationAssertionTimezoneSource.unknown) {
      edges.add(
        _edge(
          node.assertionId,
          node.assertionId,
          MedicationAssertionRelationship.timezoneAmbiguous,
          true,
          'assertion_graph.timezone_ambiguous',
        ),
      );
    }
  }

  void _pairEdges(
    MedicationAssertionNode left,
    MedicationAssertionNode right,
    List<MedicationAssertionEdge> edges,
  ) {
    var hasBlockingDifference = false;
    if (left.sourceArtifactId == right.sourceArtifactId &&
        (left.sourceArtifactDigest != right.sourceArtifactDigest ||
            left.sourceRevisionDigest != right.sourceRevisionDigest)) {
      edges.add(
        _edge(
          left.assertionId,
          right.assertionId,
          MedicationAssertionRelationship.sourceRevisionConflict,
          true,
          'assertion_graph.source_revision_conflict',
        ),
      );
      hasBlockingDifference = true;
    }
    if (left.medicationId != right.medicationId) {
      edges.add(
        _edge(
          left.assertionId,
          right.assertionId,
          MedicationAssertionRelationship.unresolvedCandidateMatch,
          true,
          'assertion_graph.medication_identity_conflict',
        ),
      );
      return;
    }

    final temporal = _temporalRelationship(left, right);
    if (temporal != null) {
      final blocking =
          temporal != MedicationAssertionRelationship.partialOverlap;
      edges.add(
        _edge(
          left.assertionId,
          right.assertionId,
          temporal,
          blocking,
          'assertion_graph.${temporal.name}',
        ),
      );
      hasBlockingDifference = hasBlockingDifference || blocking;
    }

    final noProduct = medicationAssertionSnapshotDigest(null);
    if (left.productIdentityDigest != right.productIdentityDigest) {
      final bothKnown =
          left.productIdentityDigest != noProduct &&
          right.productIdentityDigest != noProduct;
      edges.add(
        _edge(
          left.assertionId,
          right.assertionId,
          bothKnown
              ? MedicationAssertionRelationship.productConflict
              : MedicationAssertionRelationship.unresolvedCandidateMatch,
          true,
          bothKnown
              ? 'assertion_graph.product_conflict'
              : 'assertion_graph.product_identity_incomplete',
        ),
      );
      hasBlockingDifference = true;
    }
    if (left.doseValue != null &&
        right.doseValue != null &&
        (left.doseUnit != right.doseUnit ||
            (left.doseValue! - right.doseValue!).abs() > 1e-9)) {
      edges.add(
        _edge(
          left.assertionId,
          right.assertionId,
          MedicationAssertionRelationship.doseConflict,
          true,
          'assertion_graph.dose_conflict',
        ),
      );
      hasBlockingDifference = true;
    }
    final statusConflict =
        left.status != MedicationAssertionStatus.unknown &&
        right.status != MedicationAssertionStatus.unknown &&
        left.status != right.status;
    if (statusConflict) {
      edges.add(
        _edge(
          left.assertionId,
          right.assertionId,
          MedicationAssertionRelationship.statusConflict,
          true,
          'assertion_graph.status_conflict',
        ),
      );
      hasBlockingDifference = true;
    }

    if (!hasBlockingDifference) {
      final duplicate =
          left.sourceArtifactDigest == right.sourceArtifactDigest &&
          left.sourceRevisionDigest == right.sourceRevisionDigest &&
          left.doseValue == right.doseValue &&
          left.doseUnit == right.doseUnit &&
          left.status == right.status &&
          left.effectiveStartUtc == right.effectiveStartUtc &&
          left.effectiveEndUtc == right.effectiveEndUtc;
      edges.add(
        _edge(
          left.assertionId,
          right.assertionId,
          duplicate
              ? MedicationAssertionRelationship.duplicate
              : MedicationAssertionRelationship.corroborates,
          false,
          duplicate
              ? 'assertion_graph.duplicate'
              : 'assertion_graph.corroborates',
        ),
      );
    }
  }

  MedicationAssertionRelationship? _temporalRelationship(
    MedicationAssertionNode left,
    MedicationAssertionNode right,
  ) {
    if (left.effectiveStartUtc == null ||
        left.effectiveEndUtc == null ||
        right.effectiveStartUtc == null ||
        right.effectiveEndUtc == null) {
      return MedicationAssertionRelationship.unresolvedCandidateMatch;
    }
    final leftStart = left.effectiveStartUtc!.subtract(
      Duration(minutes: left.timeUncertaintyMinutes),
    );
    final leftEnd = left.effectiveEndUtc!.add(
      Duration(minutes: left.timeUncertaintyMinutes),
    );
    final rightStart = right.effectiveStartUtc!.subtract(
      Duration(minutes: right.timeUncertaintyMinutes),
    );
    final rightEnd = right.effectiveEndUtc!.add(
      Duration(minutes: right.timeUncertaintyMinutes),
    );
    final overlaps =
        !leftEnd.isBefore(rightStart) && !rightEnd.isBefore(leftStart);
    if (!overlaps) return MedicationAssertionRelationship.timeConflict;
    if (leftStart != rightStart || leftEnd != rightEnd) {
      return MedicationAssertionRelationship.partialOverlap;
    }
    return null;
  }

  MedicationAssertionEdge _edge(
    String from,
    String to,
    MedicationAssertionRelationship relationship,
    bool blocking,
    String reasonCode,
  ) {
    final identity = <String, Object?>{
      'from': from,
      'to': to,
      'relationship': relationship.name,
      'blocking': blocking,
      'reason_code': reasonCode,
    };
    return MedicationAssertionEdge(
      edgeId: 'med_edge_${medicationAssertionSnapshotDigest(identity)}',
      fromAssertionId: from,
      toAssertionId: to,
      relationship: relationship,
      blocking: blocking,
      reasonCode: reasonCode,
    );
  }
}
