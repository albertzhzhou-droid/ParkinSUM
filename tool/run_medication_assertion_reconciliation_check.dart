import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/domain/entities/medication_assertion_reconciliation.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/medication_assertion_reconciliation_service.dart';

void main() {
  const owner = 'assertion_gate_owner';
  final eventTime = DateTime.utc(2026, 8, 27, 12);
  final observedAt = DateTime.utc(2026, 8, 27, 15);
  final coordinator = AdministrationDoseConfirmationCoordinator();
  const service = MedicationAssertionReconciliationService();

  Intake confirmed({Intake? current, String dose = '100 mg'}) {
    final draft = Intake(
      id: 'assertion_gate_intake',
      drugId: 'levodopa',
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
          operationId: current == null
              ? 'assertion_gate_create'
              : 'assertion_gate_update',
          confirmationRequested: true,
          assertionSource: AdministrationDoseAssertionSource.typed,
          confirmationAction: 'assertion_gate.explicit_confirmation',
          uiContractVersion: 'assertion-gate:1',
          confirmedAt: eventTime.add(const Duration(minutes: 1)),
        )
        .intake!;
  }

  MedicationAssertionNode external({
    required Intake intake,
    String sourceId = 'external_source_a',
    String revision = 'revision_a',
    double? doseValue = 100,
    MedicationAssertionStatus status = MedicationAssertionStatus.unknown,
    DateTime? effectiveStart,
    DateTime? effectiveEnd,
    DateTime? assertedAt,
    DateTime? recordedAt,
    List<String> derivedFrom = const <String>[],
  }) => MedicationAssertionNode.create(
    ownerScope: owner,
    intakeId: intake.id,
    medicationId: intake.drugId,
    productIdentityDigest:
        intake.medicationAssertions.first.productIdentityDigest,
    doseValue: doseValue,
    doseUnit: doseValue == null ? null : 'mg',
    route: intake.route,
    dosageForm: intake.dosageForm,
    releaseType: intake.releaseType,
    evidenceClass: MedicationAssertionEvidenceClass.importedStatement,
    sourceArtifactId: sourceId,
    sourceArtifactDigest: medicationAssertionSnapshotDigest(
      '$sourceId:$revision',
    ),
    sourceRevisionDigest: medicationAssertionSnapshotDigest(revision),
    actorIdentity: 'synthetic_importer',
    actorRole: MedicationAssertionActorRole.importer,
    derivedFromAssertionIds: derivedFrom,
    effectiveStart: effectiveStart ?? eventTime,
    effectiveEnd: effectiveEnd ?? eventTime,
    timePrecision: MedicationAssertionTimePrecision.exact,
    timeUncertaintyMinutes: 0,
    timezoneOffsetMinutes: 0,
    timezoneSource: MedicationAssertionTimezoneSource.sourceDeclared,
    assertedAt: assertedAt ?? eventTime.add(const Duration(minutes: 2)),
    importedAt: eventTime.add(const Duration(minutes: 3)),
    recordedAt: recordedAt ?? eventTime.add(const Duration(minutes: 4)),
    status: status,
  );

  final base = confirmed();
  final doseConflict = base.copyWith(
    medicationAssertions: <MedicationAssertionNode>[
      ...base.medicationAssertions,
      external(intake: base, doseValue: 50),
    ],
  );
  final statusConflict = base.copyWith(
    medicationAssertions: <MedicationAssertionNode>[
      ...base.medicationAssertions,
      external(intake: base, status: MedicationAssertionStatus.notTaken),
    ],
  );
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
    sourceArtifactDigest: medicationAssertionSnapshotDigest('unknown'),
    sourceRevisionDigest: medicationAssertionSnapshotDigest('unknown:1'),
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
  final revisionA = external(
    intake: base,
    sourceId: 'revision_source',
    revision: 'a',
  );
  final revisionB = external(
    intake: base,
    sourceId: 'revision_source',
    revision: 'b',
  );
  final initialConflictGraph = service.build(
    intake: doseConflict,
    ownerScope: owner,
    observedAt: observedAt,
  );
  final acknowledgedConflict = doseConflict.copyWith(
    medicationReconciliationDecisions: <MedicationReconciliationDecision>[
      MedicationReconciliationDecision.create(
        ownerScope: owner,
        intakeId: base.id,
        graphDigest: initialConflictGraph.graphDigest,
        acknowledgedAssertionIds: initialConflictGraph.nodes
            .map((node) => node.assertionId)
            .toList(growable: false),
        acknowledgedBlockingEdgeIds: initialConflictGraph.blockingEdges
            .map((edge) => edge.edgeId)
            .toList(growable: false),
        resolution: MedicationReconciliationResolution.acknowledgedUnresolved,
        reasonCode: 'synthetic.acknowledged_unresolved',
        decidedAt: observedAt,
      ),
    ],
  );
  final cleanGraph = service.build(
    intake: base,
    ownerScope: owner,
    observedAt: observedAt,
  );
  final staleDecision = MedicationReconciliationDecision.create(
    ownerScope: owner,
    intakeId: base.id,
    graphDigest: cleanGraph.graphDigest,
    acknowledgedAssertionIds: cleanGraph.nodes
        .map((node) => node.assertionId)
        .toList(growable: false),
    acknowledgedBlockingEdgeIds: const <String>[],
    resolution: MedicationReconciliationResolution.confirmedNoConflict,
    reasonCode: 'synthetic.reviewed_no_conflict',
    decidedAt: observedAt,
  );
  final staleDecisionIntake = doseConflict.copyWith(
    medicationReconciliationDecisions: <MedicationReconciliationDecision>[
      staleDecision,
    ],
  );
  final malformedJson = Map<String, dynamic>.from(base.toJson());
  malformedJson['medicationReconciliation'] = <String, Object?>{
    'schema': 'parkinsum.medication-reconciliation-envelope/999',
    'schemaVersion': 999,
    'assertions': <Object?>[],
    'decisions': <Object?>[],
    'meaningBoundary': 'synthetic invalid evidence',
  };

  final scenarios =
      <
        ({
          String name,
          Intake intake,
          String scope,
          bool eligible,
          MedicationAssertionRelationship? relationship,
          String? integrityPrefix,
          int staleDecisions,
        })
      >[
        (
          name: 'exact_local_confirmation',
          intake: base,
          scope: owner,
          eligible: true,
          relationship: null,
          integrityPrefix: null,
          staleDecisions: 0,
        ),
        (
          name: 'dose_conflict',
          intake: doseConflict,
          scope: owner,
          eligible: false,
          relationship: MedicationAssertionRelationship.doseConflict,
          integrityPrefix: null,
          staleDecisions: 0,
        ),
        (
          name: 'status_inversion',
          intake: statusConflict,
          scope: owner,
          eligible: false,
          relationship: MedicationAssertionRelationship.statusConflict,
          integrityPrefix: null,
          staleDecisions: 0,
        ),
        (
          name: 'unknown_event_time',
          intake: base.copyWith(
            medicationAssertions: <MedicationAssertionNode>[
              ...base.medicationAssertions,
              unknownTime,
            ],
          ),
          scope: owner,
          eligible: false,
          relationship:
              MedicationAssertionRelationship.unresolvedCandidateMatch,
          integrityPrefix: null,
          staleDecisions: 0,
        ),
        (
          name: 'future_dated',
          intake: base.copyWith(
            medicationAssertions: <MedicationAssertionNode>[
              ...base.medicationAssertions,
              external(
                intake: base,
                effectiveStart: observedAt.add(const Duration(days: 1)),
                effectiveEnd: observedAt.add(const Duration(days: 1)),
              ),
            ],
          ),
          scope: owner,
          eligible: false,
          relationship: MedicationAssertionRelationship.futureDated,
          integrityPrefix: null,
          staleDecisions: 0,
        ),
        (
          name: 'clock_skew',
          intake: base.copyWith(
            medicationAssertions: <MedicationAssertionNode>[
              ...base.medicationAssertions,
              external(
                intake: base,
                assertedAt: observedAt,
                recordedAt: observedAt.subtract(const Duration(hours: 1)),
              ),
            ],
          ),
          scope: owner,
          eligible: false,
          relationship: MedicationAssertionRelationship.clockSkew,
          integrityPrefix: null,
          staleDecisions: 0,
        ),
        (
          name: 'source_revision_drift',
          intake: base.copyWith(
            medicationAssertions: <MedicationAssertionNode>[
              ...base.medicationAssertions,
              revisionA,
              revisionB,
            ],
          ),
          scope: owner,
          eligible: false,
          relationship: MedicationAssertionRelationship.sourceRevisionConflict,
          integrityPrefix: null,
          staleDecisions: 0,
        ),
        (
          name: 'owner_replay',
          intake: base,
          scope: 'different_owner',
          eligible: false,
          relationship: null,
          integrityPrefix: 'assertion.owner_mismatch',
          staleDecisions: 0,
        ),
        (
          name: 'dangling_derivation',
          intake: base.copyWith(
            medicationAssertions: <MedicationAssertionNode>[
              ...base.medicationAssertions,
              external(
                intake: base,
                derivedFrom: <String>[
                  'med_assert_${List<String>.filled(64, 'a').join()}',
                ],
              ),
            ],
          ),
          scope: owner,
          eligible: false,
          relationship: null,
          integrityPrefix: 'assertion.dangling_derivedFrom',
          staleDecisions: 0,
        ),
        (
          name: 'acknowledgement_does_not_release',
          intake: acknowledgedConflict,
          scope: owner,
          eligible: false,
          relationship: MedicationAssertionRelationship.doseConflict,
          integrityPrefix: null,
          staleDecisions: 0,
        ),
        (
          name: 'stale_decision',
          intake: staleDecisionIntake,
          scope: owner,
          eligible: false,
          relationship: MedicationAssertionRelationship.doseConflict,
          integrityPrefix: null,
          staleDecisions: 1,
        ),
        (
          name: 'malformed_evidence_quarantine',
          intake: Intake.fromJson(malformedJson),
          scope: owner,
          eligible: false,
          relationship: null,
          integrityPrefix: 'reconciliation.invalid_evidence',
          staleDecisions: 0,
        ),
        (
          name: 'local_supersession',
          intake: confirmed(current: base, dose: '50 mg'),
          scope: owner,
          eligible: true,
          relationship: MedicationAssertionRelationship.supersedes,
          integrityPrefix: null,
          staleDecisions: 0,
        ),
      ];

  final failures = <Map<String, Object?>>[];
  final caseReports = <Map<String, Object?>>[];
  for (final scenario in scenarios) {
    final graph = service.build(
      intake: scenario.intake,
      ownerScope: scenario.scope,
      observedAt: observedAt,
    );
    final relationships = graph.edges.map((edge) => edge.relationship).toSet();
    final pass =
        graph.resultAffectingDoseEligible == scenario.eligible &&
        (scenario.relationship == null ||
            relationships.contains(scenario.relationship)) &&
        (scenario.integrityPrefix == null ||
            graph.integrityFindings.any(
              (finding) => finding.startsWith(scenario.integrityPrefix!),
            )) &&
        graph.staleDecisionCount == scenario.staleDecisions;
    if (!pass) {
      failures.add(<String, Object?>{
        'case': scenario.name,
        'expected_eligible': scenario.eligible,
        'actual_eligible': graph.resultAffectingDoseEligible,
        'expected_relationship': scenario.relationship?.name,
        'actual_relationships': relationships
            .map((value) => value.name)
            .toList(),
        'expected_integrity_prefix': scenario.integrityPrefix,
        'actual_integrity': graph.integrityFindings,
        'expected_stale_decisions': scenario.staleDecisions,
        'actual_stale_decisions': graph.staleDecisionCount,
      });
    }
    caseReports.add(<String, Object?>{
      'case': scenario.name,
      'pass': pass,
      'result_affecting_dose_eligible': graph.resultAffectingDoseEligible,
      'relationships': relationships.map((value) => value.name).toList()
        ..sort(),
      'integrity_findings': graph.integrityFindings,
      'stale_decision_count': graph.staleDecisionCount,
      'result_gate_reasons': graph.resultGateReasons,
    });
  }

  final pass = failures.isEmpty;
  final report = <String, Object?>{
    'report_type': 'parkinsum_medication_assertion_reconciliation',
    'schema_version': 1,
    'pass': pass,
    'case_count': caseReports.length,
    'cases': caseReports,
    'failures': failures,
    'synthetic_only': true,
    'not_fhir_conformance': true,
    'not_clinical_reconciliation': true,
    'safety_boundary':
        'This gate verifies deterministic retention, conflict enumeration, '
        'identity binding and fail-closed result gating. It does not establish '
        'administration, adherence, prescription validity, source authenticity '
        'or clinical medication reconciliation.',
  };
  final output = Directory('build/medication_assertion_reconciliation')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  final markdown = <String>[
    '# Medication assertion reconciliation check',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Synthetic cases:** ${caseReports.length}',
    '',
    '| Case | Pass | Result dose eligible | Relationships | Integrity |',
    '| --- | --- | --- | --- | --- |',
    for (final item in caseReports)
      '| ${item['case']} | ${item['pass']} | '
          '${item['result_affecting_dose_eligible']} | '
          '${(item['relationships'] as List).join(', ')} | '
          '${(item['integrity_findings'] as List).join(', ')} |',
    '',
    '## Boundary',
    '',
    report['safety_boundary']! as String,
    '',
  ].join('\n');
  File('${output.path}/latest.md').writeAsStringSync(markdown);

  stdout.writeln(
    'Medication assertion reconciliation: '
    '${pass ? 'pass' : 'FAILED'}; ${caseReports.length} synthetic cases; '
    'failures=${failures.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}
