import '../../core/models/intake.dart';
import '../entities/fhir_r5_dose_quantity_preview.dart';
import '../entities/versioned_dose_unit_mapping.dart';
import 'administration_dose_confirmation_coordinator.dart';

/// Projects one currently confirmed local administration quantity into a
/// FHIR R5 Dosage fragment for offline inspection only.
final class FhirR5DoseQuantityPreviewService {
  FhirR5DoseQuantityPreviewService({
    AdministrationDoseConfirmationCoordinator? coordinator,
  }) : _coordinator =
           coordinator ?? AdministrationDoseConfirmationCoordinator();

  final AdministrationDoseConfirmationCoordinator _coordinator;

  FhirR5DoseQuantityPreview project(
    Intake intake, {
    required String ownerScope,
    required DateTime observedAt,
  }) {
    final gate = _coordinator.evaluateForResultUse(
      intake,
      ownerScope: ownerScope,
      observedAt: observedAt,
    );
    final unmappedLocalFields = <String>[
      if ((intake.route ?? '').trim().isNotEmpty) 'Intake.route',
      if ((intake.dosageForm ?? '').trim().isNotEmpty) 'Intake.dosageForm',
      if ((intake.releaseType ?? '').trim().isNotEmpty) 'Intake.releaseType',
      if (intake.productSelection != null) 'Intake.productSelection',
      if (intake.medicationAssertions.isNotEmpty) 'Intake.medicationAssertions',
      if (intake.medicationReconciliationDecisions.isNotEmpty)
        'Intake.medicationReconciliationDecisions',
    ];
    if (!gate.eligible || !gate.confirmation.confirmed) {
      return FhirR5DoseQuantityPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: gate.reasonCodes.isEmpty
            ? const <String>['dose.fhir_r5.confirmed_dose_required']
            : gate.reasonCodes,
        unmappedLocalFields: unmappedLocalFields,
      );
    }

    final value = gate.value;
    final unitMapping = gate.confirmation.unitMappingEvidence;
    if (value == null || !value.isFinite || value <= 0 || unitMapping == null) {
      return FhirR5DoseQuantityPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'dose.fhir_r5.quantity_mapping_unavailable',
        ],
        unmappedLocalFields: unmappedLocalFields,
      );
    }

    final binding = FhirR5DoseQuantityPreview.unitCodeBindings
        .where((candidate) => candidate.localCode == unitMapping.canonicalCode)
        .firstOrNull;
    if (binding == null ||
        unitMapping.sourceDimension != unitMapping.targetDimension ||
        unitMapping.canonicalSystemUri !=
            VersionedDoseUnitMapping.localUnitSystemUri ||
        unitMapping.canonicalTerminologyVersion !=
            VersionedDoseUnitMapping.terminologyVersion) {
      return FhirR5DoseQuantityPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'dose.fhir_r5.quantity_mapping_unavailable',
        ],
        unmappedLocalFields: unmappedLocalFields,
      );
    }

    final receipt = gate.confirmation.receipt;
    if (receipt == null || receipt.rawExpression.trim().isEmpty) {
      return FhirR5DoseQuantityPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'dose.fhir_r5.source_expression_unavailable',
        ],
        unmappedLocalFields: unmappedLocalFields,
      );
    }

    return FhirR5DoseQuantityPreview.projected(
      evaluatedAt: observedAt,
      dosageFragment: <String, Object?>{
        'text': receipt.rawExpression,
        'doseAndRate': <Map<String, Object?>>[
          <String, Object?>{
            'doseQuantity': <String, Object?>{
              'value': value,
              'unit': unitMapping.canonicalDisplay,
              'system': FhirR5DoseQuantityPreview.ucumSystem,
              'code': binding.ucumCode,
            },
          },
        ],
      },
      sourceUnitMapping: unitMapping.toJson(),
      unmappedLocalFields: unmappedLocalFields,
    );
  }
}
