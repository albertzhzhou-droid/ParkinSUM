import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import 'dosage_note_parser.dart';

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
