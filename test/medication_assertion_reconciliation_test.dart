import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/app_database_native.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/domain/entities/medication_assertion_reconciliation.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/medication_assertion_reconciliation_service.dart';

void main() {
  const owner = 'user_assertion_test';
  final eventTime = DateTime.utc(2026, 8, 27, 12);
  final observedAt = DateTime.utc(2026, 8, 27, 15);
  final coordinator = AdministrationDoseConfirmationCoordinator();
  const service = MedicationAssertionReconciliationService();

  Intake confirmed({Intake? current, String dose = '100 mg'}) {
    final draft = Intake(
      id: 'intake_1',
      drugId: 'drug_levodopa',
      takenAt: eventTime,
      dosageNote: dose,
      route: 'oral',
      dosageForm: 'tablet',
      releaseType: 'immediate',
    );
    return coordinator
        .prepare(
          draft: draft,
          current: current,
          expectedRecordRevisionDigest:
              AdministrationDoseConfirmationCoordinator.revisionDigest(current),
          ownerScope: owner,
          operationId: current == null ? 'event_create' : 'event_update',
          confirmationRequested: true,
          assertionSource: AdministrationDoseAssertionSource.typed,
          confirmationAction: 'test.explicit_confirmation',
          uiContractVersion: 'test-reconciliation:1',
          confirmedAt: eventTime.add(const Duration(minutes: 1)),
        )
        .intake!;
  }

  MedicationAssertionNode external({
    required Intake intake,
    String sourceId = 'external_source_a',
    String revision = 'revision_a',
    String? sourceDisplayLabel,
    List<String> supersedesAssertionIds = const <String>[],
    double? doseValue = 100,
    String? doseUnit = 'mg',
    MedicationAssertionStatus status = MedicationAssertionStatus.unknown,
    DateTime? effectiveStart,
    DateTime? effectiveEnd,
    MedicationAssertionTimePrecision precision =
        MedicationAssertionTimePrecision.exact,
    MedicationAssertionTimezoneSource timezoneSource =
        MedicationAssertionTimezoneSource.sourceDeclared,
    int timeUncertaintyMinutes = 0,
    DateTime? assertedAt,
    DateTime? importedAt,
    DateTime? recordedAt,
    bool omitImportTime = false,
  }) => MedicationAssertionNode.create(
    ownerScope: owner,
    intakeId: intake.id,
    medicationId: intake.drugId,
    productIdentityDigest:
        intake.medicationAssertions.first.productIdentityDigest,
    doseValue: doseValue,
    doseUnit: doseUnit,
    route: intake.route,
    dosageForm: intake.dosageForm,
    releaseType: intake.releaseType,
    evidenceClass: MedicationAssertionEvidenceClass.importedStatement,
    sourceDisplayLabel: sourceDisplayLabel,
    sourceArtifactId: sourceId,
    sourceArtifactDigest: medicationAssertionSnapshotDigest(sourceId),
    sourceRevisionDigest: medicationAssertionSnapshotDigest(revision),
    actorIdentity: 'importer_a',
    actorRole: MedicationAssertionActorRole.importer,
    supersedesAssertionIds: supersedesAssertionIds,
    effectiveStart: effectiveStart ?? eventTime,
    effectiveEnd: effectiveEnd ?? eventTime,
    timePrecision: precision,
    timeUncertaintyMinutes: timeUncertaintyMinutes,
    timezoneOffsetMinutes:
        timezoneSource == MedicationAssertionTimezoneSource.unknown ? null : 0,
    timezoneSource: timezoneSource,
    assertedAt: assertedAt ?? eventTime.add(const Duration(minutes: 2)),
    importedAt: omitImportTime
        ? null
        : importedAt ?? eventTime.add(const Duration(minutes: 3)),
    recordedAt: recordedAt ?? eventTime.add(const Duration(minutes: 4)),
    status: status,
  );

  test(
    'source display label is persisted and v1 assertion identity migrates',
    () {
      final base = confirmed();
      final labeled = external(
        intake: base,
        sourceDisplayLabel: '  Portal statement  ',
      );
      final labeledJson = labeled.toJson();

      expect(labeled.sourceDisplayLabel, 'Portal statement');
      expect(labeledJson['schema_version'], medicationAssertionSchemaVersion);
      expect(labeledJson['identity_schema_version'], 2);
      expect(labeledJson['source_display_label'], 'Portal statement');
      expect(
        MedicationAssertionNode.fromJson(
          Map<String, dynamic>.from(labeledJson),
        ).assertionId,
        labeled.assertionId,
      );
      final tampered = Map<String, dynamic>.from(labeledJson)
        ..['source_display_label'] = 'Another portal';
      expect(
        () => MedicationAssertionNode.fromJson(tampered),
        throwsFormatException,
      );

      final originalV1 = external(intake: base);
      final legacyJson = Map<String, Object?>.from(originalV1.toJson())
        ..remove('identity_schema_version')
        ..remove('source_display_label')
        ..['schema'] = 'parkinsum.medication-assertion/1'
        ..['schema_version'] = 1;
      final restoredV1 = MedicationAssertionNode.fromJson(
        Map<String, dynamic>.from(legacyJson),
      );

      expect(restoredV1.assertionId, originalV1.assertionId);
      expect(restoredV1.sourceDisplayLabel, isNull);
      expect(
        restoredV1.toJson()['schema_version'],
        medicationAssertionSchemaVersion,
      );
      expect(restoredV1.toJson()['identity_schema_version'], 1);
      expect(restoredV1.toJson()['source_display_label'], isNull);
    },
  );

  test('one exact local confirmation is result-eligible', () {
    final intake = confirmed();
    final graph = service.build(
      intake: intake,
      ownerScope: owner,
      observedAt: observedAt,
    );

    expect(graph.nodes, hasLength(1));
    expect(graph.edges, isEmpty);
    expect(graph.integrityFindings, isEmpty);
    expect(graph.resultAffectingDoseEligible, isTrue);
    expect(
      graph.toJson()['schema'],
      'parkinsum.medication-assertion-conflict-graph/1',
    );
  });

  test(
    'bitemporal projection keeps event time separate from knowledge time',
    () {
      final base = confirmed();
      final priorAssertionId = base.medicationAssertions.single.assertionId;
      final lateImport = external(
        intake: base,
        doseValue: 50,
        supersedesAssertionIds: [priorAssertionId],
      );
      final intake = base.copyWith(
        medicationAssertions: [...base.medicationAssertions, lateImport],
      );

      final beforeImport = service.projectBitemporal(
        intake: intake,
        ownerScope: owner,
        validAt: eventTime,
        knownAt: eventTime.add(const Duration(minutes: 2)),
      );
      final withheld = beforeImport.assertions.singleWhere(
        (entry) => entry.assertionId == lateImport.assertionId,
      );
      expect(beforeImport.assertionsAtValidTime, hasLength(1));
      expect(
        beforeImport.assertionsAtValidTime.single.assertionId,
        priorAssertionId,
      );
      expect(
        withheld.knowledgeStatus,
        MedicationAssertionKnowledgeStatus.afterKnowledgeCutoff,
      );
      expect(withheld.assertion, isNull);
      expect(
        withheld.reasonCodes,
        contains('projection.imported_after_known_at'),
      );
      expect(beforeImport.toJson()['result_affecting_dose_eligible'], isFalse);
      expect(
        service
            .projectBitemporal(
              intake: intake,
              ownerScope: owner,
              validAt: eventTime,
              knownAt: eventTime.add(const Duration(minutes: 2)),
            )
            .projectionDigest,
        beforeImport.projectionDigest,
      );

      final afterImport = service.projectBitemporal(
        intake: intake,
        ownerScope: owner,
        validAt: eventTime,
        knownAt: eventTime.add(const Duration(minutes: 5)),
      );
      expect(afterImport.assertionsAtValidTime, hasLength(2));
      expect(
        afterImport.projectionDigest,
        isNot(beforeImport.projectionDigest),
      );
    },
  );

  test(
    'historical conflict graph rebuilds from claims known by each cutoff',
    () {
      final base = confirmed();
      final lateConflict = external(
        intake: base,
        doseValue: 50,
        assertedAt: eventTime.add(const Duration(minutes: 12)),
        importedAt: eventTime.add(const Duration(minutes: 13)),
        recordedAt: eventTime.add(const Duration(minutes: 14)),
      );
      final intake = base.copyWith(
        medicationAssertions: [...base.medicationAssertions, lateConflict],
      );

      final beforeImport = service.projectBitemporal(
        intake: intake,
        ownerScope: owner,
        validAt: eventTime,
        knownAt: eventTime.add(const Duration(minutes: 10)),
      );
      final beforeGraph = beforeImport.historicalConflictGraph;
      expect(beforeGraph.nodes, hasLength(1));
      expect(
        beforeGraph.nodes.single.assertionId,
        isNot(lateConflict.assertionId),
      );
      expect(beforeGraph.edges, isEmpty);
      expect(beforeGraph.hasUnresolvedConflict, isFalse);
      expect(
        beforeImport.toJson()['schema'],
        'parkinsum.medication-assertion-bitemporal-projection/3',
      );
      expect(beforeImport.toJson()['schema_version'], 3);
      expect(
        beforeImport.aggregateIntegrityTemporalStatus,
        MedicationAggregateIntegrityTemporalStatus
            .noUntimedMarkerOnSourceSnapshot,
      );
      final serializedHistoricalGraph = beforeGraph.toJson();
      expect(
        serializedHistoricalGraph.containsKey('result_affecting_dose_eligible'),
        isFalse,
      );

      final afterImport = service.projectBitemporal(
        intake: intake,
        ownerScope: owner,
        validAt: eventTime,
        knownAt: eventTime.add(const Duration(minutes: 20)),
      );
      final afterGraph = afterImport.historicalConflictGraph;
      expect(afterGraph.nodes, hasLength(2));
      expect(
        afterGraph.blockingEdges.map((edge) => edge.relationship),
        contains(MedicationAssertionRelationship.doseConflict),
      );
      expect(afterGraph.hasUnresolvedConflict, isTrue);
      expect(afterImport.toJson()['result_affecting_dose_eligible'], isFalse);
      expect(afterGraph.graphDigest, isNot(beforeGraph.graphDigest));
      expect(
        service
            .projectBitemporal(
              intake: intake,
              ownerScope: owner,
              validAt: eventTime,
              knownAt: eventTime.add(const Duration(minutes: 20)),
            )
            .historicalConflictGraph
            .graphDigest,
        afterGraph.graphDigest,
      );
    },
  );

  test('every assertion clock bounds historical knowledge visibility', () {
    final base = confirmed();
    final afterCutoff = observedAt.add(const Duration(hours: 1));
    final cases = <({String reasonCode, MedicationAssertionNode assertion})>[
      (
        reasonCode: 'projection.asserted_after_known_at',
        assertion: external(
          intake: base,
          sourceId: 'asserted_late',
          assertedAt: afterCutoff,
          importedAt: eventTime.add(const Duration(minutes: 3)),
          recordedAt: eventTime.add(const Duration(minutes: 4)),
        ),
      ),
      (
        reasonCode: 'projection.imported_after_known_at',
        assertion: external(
          intake: base,
          sourceId: 'imported_late',
          assertedAt: eventTime.add(const Duration(minutes: 2)),
          importedAt: afterCutoff,
          recordedAt: eventTime.add(const Duration(minutes: 4)),
        ),
      ),
      (
        reasonCode: 'projection.recorded_after_known_at',
        assertion: external(
          intake: base,
          sourceId: 'recorded_late',
          assertedAt: eventTime.add(const Duration(minutes: 2)),
          importedAt: eventTime.add(const Duration(minutes: 3)),
          recordedAt: afterCutoff,
        ),
      ),
    ];

    for (final item in cases) {
      final projection = service.projectBitemporal(
        intake: base.copyWith(
          medicationAssertions: [...base.medicationAssertions, item.assertion],
        ),
        ownerScope: owner,
        validAt: eventTime,
        knownAt: observedAt,
      );
      final entry = projection.assertions.singleWhere(
        (candidate) => candidate.assertionId == item.assertion.assertionId,
      );
      expect(
        entry.knowledgeStatus,
        MedicationAssertionKnowledgeStatus.afterKnowledgeCutoff,
      );
      expect(entry.assertion, isNull);
      expect(entry.reasonCodes, contains(item.reasonCode));
    }

    final missingImportTime = external(
      intake: base,
      sourceId: 'missing_import_time',
      omitImportTime: true,
    );
    final unresolved = service.projectBitemporal(
      intake: base.copyWith(
        medicationAssertions: [...base.medicationAssertions, missingImportTime],
      ),
      ownerScope: owner,
      validAt: eventTime,
      knownAt: observedAt,
    );
    final unresolvedEntry = unresolved.assertions.singleWhere(
      (entry) => entry.assertionId == missingImportTime.assertionId,
    );
    expect(
      unresolvedEntry.knowledgeStatus,
      MedicationAssertionKnowledgeStatus.unresolvedKnowledgeTime,
    );
    expect(unresolvedEntry.assertion, isNull);
    expect(
      unresolved.integrityFindings,
      contains(
        'projection.import_time_missing:${missingImportTime.assertionId}',
      ),
    );
  });

  test('bitemporal projection retains outside and uncertain event times', () {
    final base = confirmed();
    final outside = external(
      intake: base,
      sourceId: 'earlier_source',
      effectiveStart: eventTime.subtract(const Duration(hours: 2)),
      effectiveEnd: eventTime.subtract(const Duration(hours: 1)),
    );
    final timezoneUncertain = external(
      intake: base,
      sourceId: 'timezone_uncertain_source',
      timezoneSource: MedicationAssertionTimezoneSource.unknown,
    );
    final uncertaintyBoundary = external(
      intake: base,
      sourceId: 'uncertainty_boundary_source',
      effectiveStart: eventTime.subtract(const Duration(minutes: 5)),
      effectiveEnd: eventTime.subtract(const Duration(minutes: 5)),
      timeUncertaintyMinutes: 10,
    );
    final projection = service.projectBitemporal(
      intake: base.copyWith(
        medicationAssertions: [
          ...base.medicationAssertions,
          outside,
          timezoneUncertain,
          uncertaintyBoundary,
        ],
      ),
      ownerScope: owner,
      validAt: eventTime,
      knownAt: observedAt,
    );

    final outsideEntry = projection.assertions.singleWhere(
      (entry) => entry.assertionId == outside.assertionId,
    );
    final uncertainEntry = projection.assertions.singleWhere(
      (entry) => entry.assertionId == timezoneUncertain.assertionId,
    );
    final boundaryEntry = projection.assertions.singleWhere(
      (entry) => entry.assertionId == uncertaintyBoundary.assertionId,
    );
    expect(
      outsideEntry.validTimeStatus,
      MedicationAssertionValidTimeStatus.outsideEffectiveInterval,
    );
    expect(
      uncertainEntry.validTimeStatus,
      MedicationAssertionValidTimeStatus.uncertainEffectiveTime,
    );
    expect(
      boundaryEntry.validTimeStatus,
      MedicationAssertionValidTimeStatus.uncertainEffectiveTime,
    );
    expect(projection.assertionsAtValidTime, hasLength(1));
    expect(projection.assertionsWithUncertainValidTime, hasLength(2));
    expect(outsideEntry.assertion, isNotNull);
  });

  test('bitemporal projection withholds later review decisions', () {
    final intake = confirmed();
    final graph = service.build(
      intake: intake,
      ownerScope: owner,
      observedAt: observedAt,
    );
    final laterDecision = MedicationReconciliationDecision.create(
      ownerScope: owner,
      intakeId: intake.id,
      graphDigest: graph.graphDigest,
      acknowledgedAssertionIds: graph.nodes
          .map((node) => node.assertionId)
          .toList(),
      acknowledgedBlockingEdgeIds: const <String>[],
      resolution: MedicationReconciliationResolution.heldForReview,
      reasonCode: 'user.held_for_review',
      decidedAt: observedAt.add(const Duration(hours: 1)),
    );
    final withDecision = intake.copyWith(
      medicationReconciliationDecisions: [laterDecision],
    );

    final beforeDecision = service.projectBitemporal(
      intake: withDecision,
      ownerScope: owner,
      validAt: eventTime,
      knownAt: observedAt,
    );
    expect(beforeDecision.decisionsAvailableAtCutoff, isEmpty);
    expect(beforeDecision.historicalConflictGraph.currentDecision, isNull);
    expect(
      beforeDecision.decisions.single.knowledgeStatus,
      MedicationAssertionKnowledgeStatus.afterKnowledgeCutoff,
    );
    expect(beforeDecision.decisions.single.decision, isNull);

    final afterDecision = service.projectBitemporal(
      intake: withDecision,
      ownerScope: owner,
      validAt: eventTime,
      knownAt: observedAt.add(const Duration(hours: 2)),
    );
    expect(afterDecision.decisionsAvailableAtCutoff, hasLength(1));
    expect(
      afterDecision.decisionsAvailableAtCutoff.single.decisionId,
      laterDecision.decisionId,
    );
    expect(
      afterDecision.historicalConflictGraph.currentDecision?.decisionId,
      laterDecision.decisionId,
    );
  });

  test(
    'dose disagreement is retained and acknowledgement cannot release it',
    () {
      final base = confirmed();
      final conflicting = external(intake: base, doseValue: 50);
      var intake = base.copyWith(
        medicationAssertions: [...base.medicationAssertions, conflicting],
      );
      final graph = service.build(
        intake: intake,
        ownerScope: owner,
        observedAt: observedAt,
      );
      expect(
        graph.blockingEdges.map((edge) => edge.relationship),
        contains(MedicationAssertionRelationship.doseConflict),
      );
      expect(graph.resultAffectingDoseEligible, isFalse);

      final decision = MedicationReconciliationDecision.create(
        ownerScope: owner,
        intakeId: intake.id,
        graphDigest: graph.graphDigest,
        acknowledgedAssertionIds: graph.nodes
            .map((node) => node.assertionId)
            .toList(),
        acknowledgedBlockingEdgeIds: graph.blockingEdges
            .map((edge) => edge.edgeId)
            .toList(),
        resolution: MedicationReconciliationResolution.acknowledgedUnresolved,
        reasonCode: 'user.acknowledged_unresolved',
        decidedAt: observedAt,
      );
      intake = intake.copyWith(medicationReconciliationDecisions: [decision]);
      final acknowledged = service.build(
        intake: intake,
        ownerScope: owner,
        observedAt: observedAt,
      );
      expect(acknowledged.currentDecision?.decisionId, decision.decisionId);
      expect(acknowledged.resultAffectingDoseEligible, isFalse);
    },
  );

  test('unknown event time stays an unresolved candidate match', () {
    final base = confirmed();
    final unknownTime = MedicationAssertionNode.create(
      ownerScope: owner,
      intakeId: base.id,
      medicationId: base.drugId,
      productIdentityDigest:
          base.medicationAssertions.first.productIdentityDigest,
      doseValue: 100,
      doseUnit: 'mg',
      route: base.route,
      dosageForm: base.dosageForm,
      releaseType: base.releaseType,
      evidenceClass: MedicationAssertionEvidenceClass.userStatement,
      sourceArtifactId: 'unknown_time_statement',
      sourceArtifactDigest: medicationAssertionSnapshotDigest('statement'),
      sourceRevisionDigest: medicationAssertionSnapshotDigest('statement:1'),
      actorIdentity: owner,
      actorRole: MedicationAssertionActorRole.user,
      effectiveStart: null,
      effectiveEnd: null,
      timePrecision: MedicationAssertionTimePrecision.unknown,
      timeUncertaintyMinutes: 0,
      timezoneOffsetMinutes: null,
      timezoneSource: MedicationAssertionTimezoneSource.unknown,
      assertedAt: eventTime,
      importedAt: null,
      recordedAt: eventTime,
      status: MedicationAssertionStatus.unknown,
    );
    final graph = service.build(
      intake: base.copyWith(
        medicationAssertions: [...base.medicationAssertions, unknownTime],
      ),
      ownerScope: owner,
      observedAt: observedAt,
    );
    expect(
      graph.blockingEdges.map((edge) => edge.relationship),
      contains(MedicationAssertionRelationship.unresolvedCandidateMatch),
    );
  });

  test(
    'future dates, clock skew, status inversion, and revision drift block',
    () {
      final base = confirmed();
      final future = external(
        intake: base,
        effectiveStart: observedAt.add(const Duration(days: 2)),
        effectiveEnd: observedAt.add(const Duration(days: 2)),
        status: MedicationAssertionStatus.notTaken,
        assertedAt: observedAt.add(const Duration(hours: 2)),
        recordedAt: observedAt,
      );
      final revisionDrift = external(
        intake: base,
        sourceId: future.sourceArtifactId,
        revision: 'revision_b',
      );
      final graph = service.build(
        intake: base.copyWith(
          medicationAssertions: [
            ...base.medicationAssertions,
            future,
            revisionDrift,
          ],
        ),
        ownerScope: owner,
        observedAt: observedAt,
      );
      final relationships = graph.blockingEdges
          .map((edge) => edge.relationship)
          .toSet();
      expect(
        relationships,
        contains(MedicationAssertionRelationship.futureDated),
      );
      expect(
        relationships,
        contains(MedicationAssertionRelationship.clockSkew),
      );
      expect(
        relationships,
        contains(MedicationAssertionRelationship.sourceRevisionConflict),
      );
      expect(
        relationships,
        contains(MedicationAssertionRelationship.statusConflict),
      );
    },
  );

  test('node and decision round-trip exactly and reject account replay', () {
    final intake = confirmed();
    final node = intake.medicationAssertions.single;
    expect(
      MedicationAssertionNode.fromJson(
        Map<String, dynamic>.from(node.toJson()),
      ).assertionDigest,
      node.assertionDigest,
    );
    final graph = service.build(
      intake: intake,
      ownerScope: owner,
      observedAt: observedAt,
    );
    final wrongOwner = service.build(
      intake: intake,
      ownerScope: 'another_user',
      observedAt: observedAt,
    );
    expect(graph.resultAffectingDoseEligible, isTrue);
    expect(wrongOwner.resultAffectingDoseEligible, isFalse);
    expect(wrongOwner.integrityFindings.single, contains('owner_mismatch'));
  });

  test(
    'a new local confirmation supersedes the prior receipt without erasure',
    () {
      final first = confirmed();
      final second = confirmed(current: first, dose: '50 mg');
      final graph = service.build(
        intake: second,
        ownerScope: owner,
        observedAt: observedAt,
      );

      expect(second.medicationAssertions, hasLength(2));
      expect(
        graph.edges.map((edge) => edge.relationship),
        contains(MedicationAssertionRelationship.supersedes),
      );
      expect(graph.blockingEdges, isEmpty);
      expect(graph.resultAffectingDoseEligible, isTrue);
    },
  );

  test('malformed reconciliation evidence is retained and blocks use', () {
    final valid = confirmed();
    final raw = Map<String, dynamic>.from(valid.toJson());
    raw['medicationReconciliation'] = <String, Object?>{
      'schema': 'parkinsum.medication-reconciliation-envelope/999',
      'schemaVersion': 999,
      'assertions': <Object?>[],
      'decisions': <Object?>[],
      'meaningBoundary': 'unsupported evidence',
    };

    final quarantined = Intake.fromJson(raw);
    final graph = service.build(
      intake: quarantined,
      ownerScope: owner,
      observedAt: observedAt,
    );

    expect(quarantined.medicationAssertions, isEmpty);
    expect(quarantined.invalidMedicationReconciliationEvidence, isNotNull);
    expect(
      quarantined.toJson()['medicationReconciliation'],
      raw['medicationReconciliation'],
    );
    expect(
      graph.integrityFindings,
      contains('reconciliation.invalid_evidence'),
    );
    expect(graph.resultAffectingDoseEligible, isFalse);

    final projection = service.projectBitemporal(
      intake: quarantined,
      ownerScope: owner,
      validAt: eventTime,
      knownAt: eventTime.subtract(const Duration(days: 1)),
    );
    expect(
      projection.aggregateIntegrityTemporalStatus,
      MedicationAggregateIntegrityTemporalStatus.knowledgeTimeUnresolved,
    );
    expect(
      projection.integrityFindings,
      contains('projection.aggregate_integrity_knowledge_time_unresolved'),
    );
    expect(projection.historicalConflictGraph.integrityFindings, isEmpty);
    expect(
      projection.toJson()['aggregate_integrity_temporal_status'],
      'knowledgeTimeUnresolved',
    );
    expect(
      projection.toJson()['schema'],
      'parkinsum.medication-assertion-bitemporal-projection/3',
    );
    expect(projection.toJson()['result_affecting_dose_eligible'], isFalse);
    expect(
      projection.toJson().toString(),
      isNot(contains('unsupported evidence')),
    );
  });

  test('native row projection preserves the exact reconciliation envelope', () {
    final intake = confirmed();
    final row = nativeIntakeToSqliteRow(intake);
    final restored = nativeIntakeFromSqliteRow(row);

    expect(
      restored.toJson()['medicationReconciliation'],
      intake.toJson()['medicationReconciliation'],
    );
    expect(
      restored.medicationAssertions.single.assertionDigest,
      intake.medicationAssertions.single.assertionDigest,
    );
    expect(
      service
          .build(intake: restored, ownerScope: owner, observedAt: observedAt)
          .resultAffectingDoseEligible,
      isTrue,
    );
  });
}
