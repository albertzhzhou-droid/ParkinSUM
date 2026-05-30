import '../entities/cdss_records.dart';
import '../entities/medication_source_metadata.dart';
import '../entities/source_metadata.dart';
import 'metadata_completeness_gate.dart';

/// Bridges the already-extracted CDSS drug metadata (a canonical
/// `DrugProductVariantMetadata` plus any `DrugLabelSectionRecord`s the live
/// importers produced) into the engine-facing `MechanisticMedicationMetadata`.
///
/// Educational/research prototype only. This adapter does **no** parsing or
/// ingestion — it maps existing structured records. It NEVER produces an intake
/// dose: product/component strength is carried as identity/provenance only.
/// Missing provenance (no sections, unknown release type, no per-component
/// strength) is recorded as missing — never fabricated and never a fake
/// official trace.
class MedicationContextMetadataAdapter {
  final MetadataCompletenessGate completenessGate;

  MedicationContextMetadataAdapter({MetadataCompletenessGate? completenessGate})
      : completenessGate = completenessGate ?? MetadataCompletenessGate();

  MechanisticMedicationMetadata fromCdssMetadata({
    required DrugProductVariantMetadata variant,
    List<DrugLabelSectionRecord> sections = const [],
    String? sourceDocVersion,
    String? effectiveDate,
    String releaseTypeSource = 'structured_variant_metadata',
  }) {
    final releaseKnown = _releaseTypeKnown(variant.releaseType);
    final resolvedReleaseSource = releaseKnown ? releaseTypeSource : 'unknown';

    final components = _components(variant);

    final labelSectionRefs = sections
        .map((s) => LabelSectionRef(
              sourceSystem: variant.sourceSystem,
              sourceDocId: s.sourceDocId,
              sourceDocVersion: sourceDocVersion,
              jurisdiction: variant.jurisdiction,
              language: variant.language,
              sectionId: s.sectionId,
              sectionKey: s.sectionKey,
              sectionTitle: s.sectionTitle,
              effectiveDate: effectiveDate,
              parserName: 'cdss_drug_label_section_record',
              sourceRefs: variant.sourceRefs,
              limitationText: variant.limitationText,
            ))
        .toList(growable: false);

    final completeness = completenessGate
        .scoreMedicationContext(variant,
            hasLabelSectionProvenance: labelSectionRefs.isNotEmpty)
        .name;

    return MechanisticMedicationMetadata(
      sourceSystem: variant.sourceSystem,
      sourceDocId: variant.productIdentifier ?? variant.drugProductVariantId,
      sourceDocVersion: sourceDocVersion,
      effectiveDate: effectiveDate,
      jurisdiction: variant.jurisdiction,
      language: variant.language,
      drugProductVariantId: variant.drugProductVariantId,
      doseForm: variant.doseForm,
      route: variant.route,
      releaseType: variant.releaseType,
      releaseTypeSource: resolvedReleaseSource,
      components: components,
      labelSectionRefs: labelSectionRefs,
      sourceRefs: variant.sourceRefs,
      limitationText: variant.limitationText,
      metadataCompleteness: completeness,
    );
  }

  /// Build component identities from the variant's active-ingredient list.
  /// Per-component strength is only assigned for a single-ingredient product
  /// (where the single product strength is unambiguous); for a combination
  /// product the per-component split is generally not in the record, so
  /// per-component strength is left null (recorded as missing, never guessed).
  List<MedicationComponent> _components(DrugProductVariantMetadata variant) {
    final names = variant.activeIngredients
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList(growable: false);
    final singleIngredient = names.length == 1;
    return names
        .map((name) => MedicationComponent(
              ingredientName: name,
              role: _roleFor(name),
              strengthValue: singleIngredient ? variant.strengthValue : null,
              strengthUnit: singleIngredient ? variant.strengthUnit : null,
              sourceRefs: variant.sourceRefs,
              extractionConfidence: variant.extractionConfidence,
            ))
        .toList(growable: false);
  }

  String _roleFor(String ingredientName) {
    final n = ingredientName.toLowerCase();
    if (n == 'levodopa' || n == 'l-dopa') return 'active';
    if (n == 'carbidopa' || n == 'benserazide') {
      return 'decarboxylase_inhibitor';
    }
    if (n == 'entacapone' || n == 'opicapone' || n == 'tolcapone') {
      return 'comt_inhibitor';
    }
    return 'adjunct';
  }

  bool _releaseTypeKnown(String releaseType) {
    final r = releaseType.trim().toLowerCase();
    return r.isNotEmpty && r != 'unknown' && r != 'unspecified';
  }
}
