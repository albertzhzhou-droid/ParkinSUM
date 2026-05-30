/// Engine-facing medication provenance metadata: the bridge between the rich
/// CDSS importer layer (drug product variant + label sections, already
/// extracted by the live importers) and the mechanistic medication context.
///
/// Educational/research prototype only. This metadata is **provenance**: it
/// describes which official source/section a product attribute came from and
/// what the product's structured attributes are. It is **never** read as an
/// intake dose — the intake dose comes only from the user-facing dosage path.
/// Product/component strength may identify a variant but must not become a
/// fabricated intake amount. Missing fields stay missing (never fabricated).
library;

/// One active/adjunct component of a (possibly combination) drug product, e.g.
/// carbidopa + levodopa. Per-component strength is nullable: when a product
/// reports only a single product-level strength, per-component strength is left
/// null and recorded as missing rather than guessed.
class MedicationComponent {
  final String ingredientName;

  /// Coarse role, e.g. 'active' / 'decarboxylase_inhibitor' / 'adjunct'.
  final String role;
  final double? strengthValue;
  final String? strengthUnit;
  final List<String> sourceRefs;
  final double? extractionConfidence;

  const MedicationComponent({
    required this.ingredientName,
    required this.role,
    this.strengthValue,
    this.strengthUnit,
    this.sourceRefs = const [],
    this.extractionConfidence,
  });

  bool get isLevodopa => ingredientName.toLowerCase() == 'levodopa';

  /// True when the component lacks an explicit strength + unit (recorded as
  /// missing, not fabricated).
  bool get hasMissingStrength =>
      strengthValue == null || (strengthUnit ?? '').isEmpty;

  Map<String, dynamic> toJson() => {
        'ingredient_name': ingredientName,
        'role': role,
        'strength_value': strengthValue,
        'strength_unit': strengthUnit,
        'source_refs': sourceRefs,
        'extraction_confidence': extractionConfidence,
      };
}

/// A reference to a specific labeled section of an official product-information
/// document (SPL / SmPC / monograph / package insert) that backs a product
/// attribute. Multiple refs per product are expected (e.g. ingredient from a
/// composition section, dose form from an identity section). This is
/// provenance/traceability — it does not assert clinical validity, and a
/// section is only listed when the source record actually carries it.
class LabelSectionRef {
  final String sourceSystem;
  final String sourceDocId;
  final String? sourceDocVersion;
  final String jurisdiction;
  final String language;
  final String sectionId;
  final String sectionKey;
  final String sectionTitle;
  final String? sectionPath;
  final String? effectiveDate;
  final String? extractedField;
  final String? extractedValue;
  final double? extractionConfidence;
  final String? parserName;
  final List<String> sourceRefs;
  final String? limitationText;

  const LabelSectionRef({
    required this.sourceSystem,
    required this.sourceDocId,
    this.sourceDocVersion,
    required this.jurisdiction,
    required this.language,
    required this.sectionId,
    required this.sectionKey,
    required this.sectionTitle,
    this.sectionPath,
    this.effectiveDate,
    this.extractedField,
    this.extractedValue,
    this.extractionConfidence,
    this.parserName,
    this.sourceRefs = const [],
    this.limitationText,
  });

  Map<String, dynamic> toJson() => {
        'source_system': sourceSystem,
        'source_doc_id': sourceDocId,
        'source_doc_version': sourceDocVersion,
        'jurisdiction': jurisdiction,
        'language': language,
        'section_id': sectionId,
        'section_key': sectionKey,
        'section_title': sectionTitle,
        'section_path': sectionPath,
        'effective_date': effectiveDate,
        'extracted_field': extractedField,
        'extracted_value': extractedValue,
        'extraction_confidence': extractionConfidence,
        'parser_name': parserName,
        'source_refs': sourceRefs,
        'limitation_text': limitationText,
      };
}

/// Engine-facing medication provenance attached to a normalized medication
/// context. Provenance only — never a dose source.
class MechanisticMedicationMetadata {
  final String sourceSystem;
  final String sourceDocId;
  final String? sourceDocVersion;
  final String? effectiveDate;
  final String jurisdiction;
  final String language;
  final String? drugProductVariantId;
  final String doseForm;
  final String route;

  /// Product release type string (e.g. immediate / extended / controlled /
  /// delayed / unknown), as carried by the source variant.
  final String releaseType;

  /// Where the release type came from, e.g. 'structured_variant_metadata' or
  /// 'unknown' (never inferred from dose).
  final String releaseTypeSource;

  final List<MedicationComponent> components;
  final List<LabelSectionRef> labelSectionRefs;
  final List<String> sourceRefs;
  final String limitationText;

  /// Metadata-completeness grade name (from `MetadataCompletenessGate`).
  final String metadataCompleteness;

  const MechanisticMedicationMetadata({
    required this.sourceSystem,
    required this.sourceDocId,
    this.sourceDocVersion,
    this.effectiveDate,
    required this.jurisdiction,
    required this.language,
    this.drugProductVariantId,
    required this.doseForm,
    required this.route,
    required this.releaseType,
    required this.releaseTypeSource,
    required this.components,
    required this.labelSectionRefs,
    required this.sourceRefs,
    required this.limitationText,
    required this.metadataCompleteness,
  });

  /// The levodopa component, if this product contains one. Levodopa-specific
  /// scoring should use this identity; other components are preserved but not
  /// used for levodopa-specific food-interaction scoring.
  MedicationComponent? get levodopaComponent {
    for (final c in components) {
      if (c.isLevodopa) return c;
    }
    return null;
  }

  /// All components (combination products preserve every component).
  List<MedicationComponent> get combinationComponents => components;

  bool get hasLabelSectionProvenance => labelSectionRefs.isNotEmpty;

  bool get releaseTypeKnown {
    final r = releaseType.trim().toLowerCase();
    return r.isNotEmpty && r != 'unknown' && r != 'unspecified';
  }

  /// Provenance fields that are absent (recorded as missing, never fabricated).
  List<String> get missingFields => <String>[
        if (!releaseTypeKnown) 'release_type',
        if (labelSectionRefs.isEmpty) 'label_section_provenance',
        if (sourceRefs.isEmpty) 'source_refs',
        if ((sourceDocVersion ?? '').isEmpty) 'source_doc_version',
        if (components.any((c) => c.hasMissingStrength))
          'component_strength_unit',
      ];

  Map<String, dynamic> toJson() => {
        'source_system': sourceSystem,
        'source_doc_id': sourceDocId,
        'source_doc_version': sourceDocVersion,
        'effective_date': effectiveDate,
        'jurisdiction': jurisdiction,
        'language': language,
        'drug_product_variant_id': drugProductVariantId,
        'dose_form': doseForm,
        'route': route,
        'release_type': releaseType,
        'release_type_source': releaseTypeSource,
        'components': components.map((c) => c.toJson()).toList(growable: false),
        'label_section_refs':
            labelSectionRefs.map((s) => s.toJson()).toList(growable: false),
        'source_refs': sourceRefs,
        'limitation_text': limitationText,
        'metadata_completeness': metadataCompleteness,
        'missing_fields': missingFields,
      };
}
