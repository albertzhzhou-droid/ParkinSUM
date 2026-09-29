import '../../core/models/administration_dose_confirmation.dart';
import '../../core/models/intake.dart';
import '../entities/dose_expression.dart';
import '../entities/medication_assertion_reconciliation.dart';
import '../entities/versioned_dose_unit_mapping.dart';
import 'dosage_note_parser.dart';
import 'medication_assertion_reconciliation_service.dart';

enum AdministrationDosePreparationStatus {
  confirmed,
  unconfirmed,
  heldExpression,
  staleRevision,
}

enum AdministrationDoseEvaluationStatus {
  confirmed,
  absent,
  invalidEvidence,
  ownerMismatch,
  grammarDrift,
  intakeMismatch,
  productMismatch,
  rawExpressionMismatch,
  expressionMismatch,
  structuredDoseMismatch,
  administrationTimeMismatch,
  recordBindingMismatch,
}

final class AdministrationDosePreparationResult {
  const AdministrationDosePreparationResult({
    required this.status,
    required this.reasonCode,
    required this.intake,
    required this.parseResult,
  });

  final AdministrationDosePreparationStatus status;
  final String reasonCode;
  final Intake? intake;
  final DoseExpressionParseResult parseResult;

  bool get canPersist =>
      status == AdministrationDosePreparationStatus.confirmed ||
      status == AdministrationDosePreparationStatus.unconfirmed;
}

final class AdministrationDoseEvaluation {
  const AdministrationDoseEvaluation({
    required this.status,
    required this.reasonCode,
    this.value,
    this.unit,
    this.unitMappingEvidence,
    this.receipt,
  });

  final AdministrationDoseEvaluationStatus status;
  final String reasonCode;
  final double? value;
  final String? unit;
  final VersionedDoseUnitMapping? unitMappingEvidence;
  final AdministrationDoseConfirmationReceipt? receipt;

  bool get confirmed =>
      status == AdministrationDoseEvaluationStatus.confirmed &&
      value != null &&
      unit != null;
}

/// Combined fail-closed decision for allowing one confirmed administration
/// dose to affect a result-producing algorithm.
///
/// Confirmation proves the local user action remains bound to this exact
/// Intake revision. The assertion graph separately proves there is no
/// unresolved source, time, product, status, or dose disagreement. Both are
/// required; neither establishes prescription correctness, adherence, or
/// clinical appropriateness.
final class AdministrationDoseResultUseEvaluation {
  const AdministrationDoseResultUseEvaluation({
    required this.confirmation,
    required this.assertionGraph,
    required this.eligible,
    required this.reasonCodes,
    required this.value,
    required this.unit,
    required this.milligrams,
  });

  final AdministrationDoseEvaluation confirmation;
  final MedicationAssertionGraph assertionGraph;
  final bool eligible;
  final List<String> reasonCodes;
  final double? value;
  final String? unit;

  /// Same mass quantity normalized to milligrams. Volume quantities remain
  /// eligible as confirmed typed observations but cannot become a mass dose
  /// without an explicit concentration bridge, so this field stays null.
  final double? milligrams;
}

/// Creates and re-evaluates user-confirmed administration-dose receipts.
///
/// The coordinator never evaluates whether a dose is prescribed, appropriate,
/// safe, or actually taken. It only proves that one explicit UI action bound
/// the exact accepted parser result to one account-scoped Intake revision.
final class AdministrationDoseConfirmationCoordinator {
  AdministrationDoseConfirmationCoordinator({
    DosageNoteParser? parser,
    MedicationAssertionReconciliationService? assertionReconciliationService,
  }) : _parser = parser ?? DosageNoteParser(),
       _assertionReconciliationService =
           assertionReconciliationService ??
           const MedicationAssertionReconciliationService();

  final DosageNoteParser _parser;
  final MedicationAssertionReconciliationService
  _assertionReconciliationService;

  AdministrationDosePreparationResult prepare({
    required Intake draft,
    required Intake? current,
    required String expectedRecordRevisionDigest,
    required String ownerScope,
    required String operationId,
    required bool confirmationRequested,
    required AdministrationDoseAssertionSource assertionSource,
    required String confirmationAction,
    required String uiContractVersion,
    required DateTime confirmedAt,
  }) {
    final actualRevisionDigest = revisionDigest(current);
    final parsed = _parser.inspect(draft.dosageNote);
    final priorAssertions =
        current?.medicationAssertions ?? draft.medicationAssertions;
    final priorDecisions =
        current?.medicationReconciliationDecisions ??
        draft.medicationReconciliationDecisions;
    if (actualRevisionDigest != expectedRecordRevisionDigest) {
      return AdministrationDosePreparationResult(
        status: AdministrationDosePreparationStatus.staleRevision,
        reasonCode: 'dose_confirmation.stale_revision',
        intake: null,
        parseResult: parsed,
      );
    }
    if (current?.invalidMedicationReconciliationEvidence != null ||
        draft.invalidMedicationReconciliationEvidence != null) {
      return AdministrationDosePreparationResult(
        status: AdministrationDosePreparationStatus.heldExpression,
        reasonCode: 'medication_reconciliation.invalid_evidence',
        intake: null,
        parseResult: parsed,
      );
    }
    if (!confirmationRequested) {
      return AdministrationDosePreparationResult(
        status: AdministrationDosePreparationStatus.unconfirmed,
        reasonCode: 'dose_confirmation.not_requested',
        intake: draft
            .copyWith(
              medicationAssertions: priorAssertions,
              medicationReconciliationDecisions: priorDecisions,
            )
            .withoutDoseConfirmation(clearStructuredDose: true),
        parseResult: parsed,
      );
    }
    final expression = parsed.expression;
    if (!parsed.accepted || expression == null) {
      return AdministrationDosePreparationResult(
        status: AdministrationDosePreparationStatus.heldExpression,
        reasonCode:
            parsed.primaryReasonCode ?? 'dose_confirmation.expression_held',
        intake: null,
        parseResult: parsed,
      );
    }
    final normalized = Intake(
      id: draft.id,
      drugId: draft.drugId,
      takenAt: draft.takenAt,
      dosageNote: draft.dosageNote,
      doseAmount: expression.value,
      doseUnit: expression.unit.code,
      dosageForm: draft.dosageForm,
      route: draft.route,
      releaseType: draft.releaseType,
      productSelection: draft.productSelection,
      medicationAssertions: priorAssertions,
      medicationReconciliationDecisions: priorDecisions,
    );
    final productSnapshot = normalized.productSelection?.toJson();
    final receipt = AdministrationDoseConfirmationReceipt.create(
      operationId: operationId,
      ownerScope: ownerScope,
      intakeId: normalized.id,
      expectedRecordRevisionDigest: expectedRecordRevisionDigest,
      recordBindingDigest: recordBindingDigest(normalized),
      medicationId: normalized.drugId,
      productSnapshotDigest:
          AdministrationDoseConfirmationReceipt.digestSnapshot(productSnapshot),
      rawExpression: normalized.dosageNote,
      parsedExpression: expression.toJson(),
      grammarId: parsed.grammarId,
      grammarVersion: parsed.grammarVersion,
      grammarDigest: parsed.grammarDigest,
      unitSystem: expression.unit.system,
      unitSystemVersion: expression.unit.version,
      structuredValue: expression.value,
      structuredUnit: expression.unit.code,
      administrationAt: normalized.takenAt,
      confirmedAt: confirmedAt,
      assertionSource: assertionSource,
      confirmationAction: confirmationAction,
      uiContractVersion: uiContractVersion,
    );
    final localAssertion = MedicationAssertionNode.fromLocalConfirmation(
      receipt: receipt,
      route: normalized.route,
      dosageForm: normalized.dosageForm,
      releaseType: normalized.releaseType,
      supersedesAssertionIds: priorAssertions
          .where((assertion) => assertion.isCurrentLocalConfirmation)
          .map((assertion) => assertion.assertionId)
          .toList(growable: false),
    );
    final confirmed = normalized
        .withDoseConfirmation(receipt)
        .withMedicationReconciliation(
          assertions: <MedicationAssertionNode>[
            ...priorAssertions,
            localAssertion,
          ],
          decisions: priorDecisions,
        );
    return AdministrationDosePreparationResult(
      status: AdministrationDosePreparationStatus.confirmed,
      reasonCode: 'dose_confirmation.confirmed',
      intake: confirmed,
      parseResult: parsed,
    );
  }

  AdministrationDoseEvaluation evaluate(
    Intake intake, {
    required String ownerScope,
  }) {
    if (intake.doseConfirmationIntegrity ==
        IntakeDoseConfirmationIntegrity.invalid) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.invalidEvidence,
        reasonCode: 'dose_confirmation.invalid_evidence',
      );
    }
    final receipt = intake.doseConfirmation;
    if (receipt == null) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.absent,
        reasonCode: 'dose_confirmation.absent',
      );
    }
    if (!receipt.belongsToScope(ownerScope)) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.ownerMismatch,
        reasonCode: 'dose_confirmation.owner_mismatch',
      );
    }
    if (receipt.grammarId != DosageNoteParser.grammarId ||
        receipt.grammarVersion != DosageNoteParser.grammarVersion ||
        receipt.grammarDigest != DosageNoteParser.grammarDigest ||
        receipt.unitSystem != DosageNoteParser.localUnitSystem ||
        receipt.unitSystemVersion != DosageNoteParser.localUnitVersion) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.grammarDrift,
        reasonCode: 'dose_confirmation.grammar_drift',
      );
    }
    if (receipt.intakeId != intake.id ||
        receipt.medicationId != intake.drugId) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.intakeMismatch,
        reasonCode: 'dose_confirmation.intake_mismatch',
      );
    }
    final productDigest = AdministrationDoseConfirmationReceipt.digestSnapshot(
      intake.productSelection?.toJson(),
    );
    if (receipt.productSnapshotDigest != productDigest) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.productMismatch,
        reasonCode: 'dose_confirmation.product_mismatch',
      );
    }
    if (receipt.rawExpression != intake.dosageNote) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.rawExpressionMismatch,
        reasonCode: 'dose_confirmation.raw_expression_mismatch',
      );
    }
    final parsed = _parser.inspect(intake.dosageNote);
    final expression = parsed.expression;
    if (!parsed.accepted ||
        expression == null ||
        AdministrationDoseConfirmationReceipt.digestSnapshot(
              receipt.parsedExpression,
            ) !=
            AdministrationDoseConfirmationReceipt.digestSnapshot(
              expression.toJson(),
            )) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.expressionMismatch,
        reasonCode: 'dose_confirmation.expression_mismatch',
      );
    }
    if (intake.doseAmount != receipt.structuredValue ||
        intake.doseUnit != receipt.structuredUnit ||
        expression.value != receipt.structuredValue ||
        expression.unit.code != receipt.structuredUnit) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.structuredDoseMismatch,
        reasonCode: 'dose_confirmation.structured_mismatch',
      );
    }
    if (receipt.administrationAtUtc != intake.takenAt.toUtc()) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.administrationTimeMismatch,
        reasonCode: 'dose_confirmation.time_mismatch',
      );
    }
    if (receipt.recordBindingDigest != recordBindingDigest(intake)) {
      return const AdministrationDoseEvaluation(
        status: AdministrationDoseEvaluationStatus.recordBindingMismatch,
        reasonCode: 'dose_confirmation.record_binding_mismatch',
      );
    }
    return AdministrationDoseEvaluation(
      status: AdministrationDoseEvaluationStatus.confirmed,
      reasonCode: 'dose_confirmation.confirmed',
      value: receipt.structuredValue,
      unit: receipt.structuredUnit,
      unitMappingEvidence: expression.unit.mappingEvidence,
      receipt: receipt,
    );
  }

  AdministrationDoseResultUseEvaluation evaluateForResultUse(
    Intake intake, {
    required String ownerScope,
    required DateTime observedAt,
  }) {
    final confirmation = evaluate(intake, ownerScope: ownerScope);
    final assertionGraph = _assertionReconciliationService.build(
      intake: intake,
      ownerScope: ownerScope,
      observedAt: observedAt,
    );
    final reasonCodes = <String>{};
    if (!confirmation.confirmed) {
      reasonCodes.add(confirmation.reasonCode);
    }
    if (!assertionGraph.resultAffectingDoseEligible) {
      reasonCodes.addAll(assertionGraph.resultGateReasons);
    }
    final observationUtc = observedAt.toUtc();
    if (confirmation.receipt?.confirmedAtUtc.isAfter(observationUtc) ?? false) {
      reasonCodes.add('dose_confirmation.confirmed_after_observation');
    }
    if (intake.medicationAssertions.any(
      (assertion) =>
          assertion.assertedAtUtc.isAfter(observationUtc) ||
          assertion.recordedAtUtc.isAfter(observationUtc) ||
          (assertion.importedAtUtc?.isAfter(observationUtc) ?? false),
    )) {
      reasonCodes.add('assertion_graph.evidence_after_observation');
    }
    if (intake.medicationReconciliationDecisions.any(
      (decision) => decision.decidedAtUtc.isAfter(observationUtc),
    )) {
      reasonCodes.add('assertion_graph.decision_after_observation');
    }

    var eligible = reasonCodes.isEmpty;
    var value = eligible ? confirmation.value : null;
    var unit = eligible ? confirmation.unit : null;
    var milligrams = eligible
        ? _milligrams(
            value,
            unit,
            confirmation.unitMappingEvidence,
            evaluatedAt: DateTime.now().toUtc(),
          )
        : null;
    if (eligible &&
        unit != 'mL' &&
        (milligrams == null || !milligrams.isFinite || milligrams <= 0)) {
      reasonCodes.add('dose_confirmation.mass_conversion_invalid');
      eligible = false;
      value = null;
      unit = null;
      milligrams = null;
    }
    final orderedReasons = reasonCodes.toList()..sort();
    // Critical, privacy-minimal gate telemetry is required by lib/AGENTS.md.
    // ignore: avoid_print
    print(
      '[AdministrationDoseResultGate] intake=${intake.id} '
      'eligible=$eligible confirmation=${confirmation.status.name} '
      'assertionEligible=${assertionGraph.resultAffectingDoseEligible} '
      'reasons=${orderedReasons.join(',')}',
    );
    return AdministrationDoseResultUseEvaluation(
      confirmation: confirmation,
      assertionGraph: assertionGraph,
      eligible: eligible,
      reasonCodes: List<String>.unmodifiable(orderedReasons),
      value: value,
      unit: unit,
      milligrams: milligrams,
    );
  }

  static double? _milligrams(
    double? value,
    String? unit,
    VersionedDoseUnitMapping? mapping, {
    required DateTime evaluatedAt,
  }) {
    if (value == null || !value.isFinite || value <= 0 || mapping == null) {
      return null;
    }
    if (unit != mapping.canonicalCode || mapping.baseUnitCode != 'mg') {
      return null;
    }
    return mapping.convertToBaseUnit(
      value,
      expectedSourceRevision: DosageNoteParser.grammarDigest,
      evaluatedAt: evaluatedAt,
    );
  }

  static String revisionDigest(Intake? intake) => intake == null
      ? administrationDoseConfirmationAbsentRevisionDigest
      : AdministrationDoseConfirmationReceipt.digestSnapshot(intake.toJson());

  static String recordBindingDigest(Intake intake) =>
      administrationDoseRecordBindingDigest(
        intakeId: intake.id,
        medicationId: intake.drugId,
        takenAt: intake.takenAt,
        dosageNote: intake.dosageNote,
        doseAmount: intake.doseAmount,
        doseUnit: intake.doseUnit,
        dosageForm: intake.dosageForm,
        route: intake.route,
        releaseType: intake.releaseType,
        productSelection: intake.productSelection?.toJson(),
      );
}
