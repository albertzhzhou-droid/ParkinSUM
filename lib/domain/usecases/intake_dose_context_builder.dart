import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../../core/models/medication_product_pack.dart';
import 'dosage_note_parser.dart';

typedef IntakeMechanisticFormulationContext = ({
  String dosageForm,
  String route,
  String releaseType,
});

/// Prefix of an intake's `dosageForm` when it holds the selected product
/// record's own dosage-form term (an FDA SPL term such as `TABLET` or
/// `TABLET, EXTENDED RELEASE`) rather than the generic medication's catalog
/// form. Only such an intake can show a selected product's formulation.
const String productDosageFormTermPrefix = 'spl:';

/// SPL dosage-form terms that name a conventional (immediate-release) solid
/// form. Modified-release forms carry their own modifier in the term.
const Set<String> conventionalReleaseSplDosageForms = {
  'TABLET',
  'TABLET, FILM COATED',
  'TABLET, COATED',
  'TABLET, CHEWABLE',
  'TABLET, ORALLY DISINTEGRATING',
  'CAPSULE',
};

/// Release type stated by an SPL dosage-form term: `extended_release` or
/// `delayed_release` when the term carries that modifier, `immediate` for a
/// term in [conventionalReleaseSplDosageForms], otherwise `unspecified`.
/// Never inferred from a medication or product name.
String releaseTypeForSplDosageForm(String term) {
  final normalized = term.trim().toUpperCase();
  if (normalized.contains('EXTENDED RELEASE')) return 'extended_release';
  if (normalized.contains('DELAYED RELEASE')) return 'delayed_release';
  return conventionalReleaseSplDosageForms.contains(normalized)
      ? 'immediate'
      : 'unspecified';
}

/// The formulation stated by the product record [pack]: its dosage-form term
/// (prefixed with [productDosageFormTermPrefix]), its route when it lists
/// exactly one, and the release type that term states.
IntakeMechanisticFormulationContext productFormulationFromPack(
  MedicationProductPack pack,
) {
  final term = pack.dosageForm.trim().toUpperCase();
  final routes = {
    for (final route in pack.routes)
      if (route.trim().isNotEmpty) route.trim().toLowerCase(),
  };
  return (
    dosageForm: term.isEmpty || term == 'UNSPECIFIED'
        ? 'unspecified'
        : '$productDosageFormTermPrefix$term',
    route: routes.length == 1 ? routes.single : 'unspecified',
    releaseType: releaseTypeForSplDosageForm(term),
  );
}

/// [intake] carrying the formulation of the product record it was entered
/// with; fields the record does not state stay unspecified.
Intake withProductFormulation(Intake intake, MedicationProductPack pack) {
  final formulation = productFormulationFromPack(pack);
  return intake.copyWith(
    dosageForm: formulation.dosageForm,
    route: formulation.route,
    releaseType: formulation.releaseType,
  );
}

/// Resolves only formulation evidence that can be bound to this exact intake.
///
/// Without a selected product, the intake's own fields (else the catalog
/// medication's) apply. With a selected product, catalog-level fields cannot
/// prove the package's formulation, so only a formulation copied from that
/// product record (marked by [productDosageFormTermPrefix]) applies: its
/// release type is re-derived from the stored SPL term. Intakes saved before
/// the product formulation was carried keep all three predicates unknown.
IntakeMechanisticFormulationContext resolveIntakeMechanisticFormulation({
  required Intake intake,
  required DrugDefinition drug,
}) {
  if (intake.productSelection != null) {
    final form = intake.dosageForm;
    if (form != null && form.startsWith(productDosageFormTermPrefix)) {
      final term = form.substring(productDosageFormTermPrefix.length);
      return (
        dosageForm: term.split(',').first.trim().toLowerCase(),
        route: intake.route ?? 'unspecified',
        releaseType: releaseTypeForSplDosageForm(term),
      );
    }
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
