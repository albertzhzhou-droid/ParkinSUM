import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import 'dosage_note_parser.dart';

typedef IntakeMechanisticFormulationContext = ({
  String dosageForm,
  String route,
  String releaseType,
});

/// Resolves only formulation evidence that can be bound to this exact intake.
///
/// The current [MedicationProductSelection] snapshot intentionally contains
/// package identity and strength display, but it does not yet carry governed
/// ingredient/route/form/release metadata. Once a concrete package has been
/// selected, catalog-level formulation fields can therefore no longer prove
/// the selected package's model applicability. Keep all three predicates
/// unknown until a versioned product-formulation snapshot is implemented.
IntakeMechanisticFormulationContext resolveIntakeMechanisticFormulation({
  required Intake intake,
  required DrugDefinition drug,
}) {
  if (intake.productSelection != null) {
    return (
      dosageForm: 'unspecified',
      route: 'unspecified',
      releaseType: 'unspecified',
    );
  }
  return (
    dosageForm: intake.dosageForm ?? drug.dosageForm,
    route: intake.route ?? drug.route,
    releaseType: intake.releaseType ?? drug.releaseType,
  );
}

/// Builds an intake event with a conservative snapshot of dose/formulation.
///
/// Free text remains the source record for backward compatibility. Structured
/// amount/unit fields are populated only for one explicit, unambiguous token;
/// product context is snapshotted from the selected catalog entry so later
/// catalog changes do not silently rewrite the historical event.
class IntakeDoseContextBuilder {
  IntakeDoseContextBuilder({DosageNoteParser? dosageNoteParser})
    : _dosageNoteParser = dosageNoteParser ?? DosageNoteParser();

  final DosageNoteParser _dosageNoteParser;

  Intake build({
    required String id,
    required String drugId,
    required DateTime takenAt,
    required String dosageNote,
    DrugDefinition? drug,
  }) {
    final normalizedNote = dosageNote.trim();
    final parsed = _dosageNoteParser.parse(normalizedNote);
    return Intake(
      id: id,
      drugId: drugId,
      takenAt: takenAt,
      dosageNote: normalizedNote,
      doseAmount: parsed.explicit ? parsed.value : null,
      doseUnit: parsed.explicit ? parsed.unit : null,
      dosageForm: _knownContext(drug?.dosageForm),
      route: _knownContext(drug?.route),
      releaseType: _knownContext(drug?.releaseType),
    );
  }

  String? _knownContext(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty || value == 'unspecified') return null;
    return value;
  }
}
