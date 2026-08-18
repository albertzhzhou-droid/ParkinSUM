import '../entities/algorithm_component_identity_witness.dart';
import '../entities/medication_entry_validation.dart';
import '../entities/medication_source_metadata.dart';

/// Raw structured medication-entry input as it would arrive from a form,
/// importer row, or test fixture.
///
/// Every field is intentionally nullable. Free-text dose strings are accepted
/// only so the validator can *reject* them clearly — they are never parsed
/// into a usable mg quantity.
class RawMedicationEntry {
  final String? freeText; // e.g. "100", "100 tablets", "levodopa 100"
  final String? activeIngredient;
  final List<String>? activeIngredients;
  final String? drugProductVariant;
  final String? form;
  final String? route;
  final String? releaseType;
  final num? strength;
  final String? unit;
  final String? jurisdiction;
  final String? sourceDocId;
  final String? labelSection;
  final double? extractionConfidence;

  /// Optional engine-facing medication provenance bridged from the CDSS layer.
  /// PROVENANCE ONLY — NEVER read as a dose source. When present, its governed
  /// product identity fields must agree with the top-level structured entry;
  /// contradictions fail validation instead of letting one representation
  /// disguise another formulation or ingredient set.
  final MechanisticMedicationMetadata? medicationMetadata;

  const RawMedicationEntry({
    this.freeText,
    this.activeIngredient,
    this.activeIngredients,
    this.drugProductVariant,
    this.form,
    this.route,
    this.releaseType,
    this.strength,
    this.unit,
    this.jurisdiction,
    this.sourceDocId,
    this.labelSection,
    this.extractionConfidence,
    this.medicationMetadata,
  });
}

/// Deterministic, side-effect-free validator. No I/O, no LLM, no inference of
/// missing fields from free-text. If a field is missing the entry is rejected;
/// it is never auto-completed.
class MedicationEntryValidator with RegisteredAlgorithmComponentIdentity {
  static const String defaultLimitationText =
      'Synthetic catalog-backed metadata. Educational prototype only. '
      'Not medical advice. Do not use for medication decisions.';

  static const String _safeInvalidCopy =
      'Medication context is incomplete. ParkinSUM could not evaluate '
      'food-medication education rules for this entry. Please use a '
      'synthetic catalog-backed medication entry with ingredient, unit, '
      'formulation, and source metadata. This prototype does not provide '
      'medication dosing or timing advice.';

  static final RegExp _bareNumeric = RegExp(r'^\s*[0-9]+(?:[.,][0-9]+)?\s*$');
  static final RegExp _slashedNumeric = RegExp(
    r'^\s*[0-9]+\s*[\/\-]\s*[0-9]+\s*$',
  );
  static final RegExp _wordCountish = RegExp(
    r'^\s*(one|two|three|four|five|a|an)\s+(pill|tablet|capsule|dose)s?\s*$',
    caseSensitive: false,
  );

  /// Allowed normalized unit tokens. Strength is *not* converted; rule layer
  /// already handles mg/g/mcg conversion, but the *unit must be declared*.
  static const Set<String> _allowedUnits = {
    'mg',
    'milligram',
    'milligrams',
    'g',
    'gram',
    'grams',
    'mcg',
    'ug',
    'µg',
    'μg',
    'microgram',
    'micrograms',
    'ml',
    'milliliter',
    'milliliters',
  };

  MedicationContextValidationResult validate(RawMedicationEntry entry) {
    final issues = <MedicationContextIssue>[];

    // Rule 1: free-text dose strings are never parsed into structured fields.
    final raw = entry.freeText?.trim();
    if (raw != null && raw.isNotEmpty) {
      if (_bareNumeric.hasMatch(raw) ||
          _slashedNumeric.hasMatch(raw) ||
          _wordCountish.hasMatch(raw)) {
        issues.add(
          const MedicationContextIssue(
            code: 'BARE_NUMERIC_DOSE',
            message:
                'A numeric value without unit, ingredient, and formulation cannot '
                'represent an analyzable medication entry.',
          ),
        );
      } else if (!_looksLikeStructuredText(raw)) {
        // Names like "levodopa 100" or "Sinemet 100" with no unit also fail.
        issues.add(
          const MedicationContextIssue(
            code: 'UNSTRUCTURED_FREE_TEXT',
            message:
                'Free-text medication input is not promoted into rule '
                'evaluation. Use a catalog-backed entry.',
          ),
        );
      }
    }

    final ingredients = <String>[
      if (entry.activeIngredient != null &&
          entry.activeIngredient!.trim().isNotEmpty)
        entry.activeIngredient!.trim(),
      ...?entry.activeIngredients
          ?.map((e) => e.trim())
          .where((e) => e.isNotEmpty),
    ];

    if (ingredients.isEmpty) {
      issues.add(
        const MedicationContextIssue(
          code: 'MISSING_ACTIVE_INGREDIENT',
          message:
              'No active ingredient was provided. Food-medication rules require '
              'an explicit ingredient.',
        ),
      );
    }

    if (entry.drugProductVariant == null ||
        entry.drugProductVariant!.trim().isEmpty) {
      issues.add(
        const MedicationContextIssue(
          code: 'MISSING_DRUG_PRODUCT_VARIANT',
          message:
              'No catalog-backed product variant. Bare names or free-text drug '
              'labels are not promoted to rule evaluation.',
        ),
      );
    }

    if (entry.unit == null || entry.unit!.trim().isEmpty) {
      issues.add(
        const MedicationContextIssue(
          code: 'MISSING_UNIT',
          message: 'Unit is required. A bare number is not a dose.',
        ),
      );
    } else if (!_allowedUnits.contains(entry.unit!.trim().toLowerCase())) {
      issues.add(
        MedicationContextIssue(
          code: 'UNKNOWN_UNIT',
          message:
              'Unit "${entry.unit}" is not in the allowed unit vocabulary for '
              'this prototype.',
        ),
      );
    }

    if (entry.strength == null) {
      issues.add(
        const MedicationContextIssue(
          code: 'MISSING_STRENGTH',
          message: 'Numeric strength is required alongside an explicit unit.',
        ),
      );
    } else if (!entry.strength!.isFinite) {
      issues.add(
        const MedicationContextIssue(
          code: 'NON_FINITE_STRENGTH',
          message: 'Strength must be a finite numeric value.',
        ),
      );
    } else if (entry.strength! <= 0) {
      issues.add(
        const MedicationContextIssue(
          code: 'NON_POSITIVE_STRENGTH',
          message: 'Strength must be a positive number.',
        ),
      );
    }

    // Formulation / release type may be downgraded to "insufficient" rather
    // than invalid, but they still block rule evaluation that depends on PK.
    final form = entry.form?.trim();
    final releaseType = entry.releaseType?.trim();
    final route = entry.route?.trim();
    if (form == null || form.isEmpty) {
      issues.add(
        const MedicationContextIssue(
          code: 'MISSING_FORM',
          message: 'Dosage form (e.g. tablet, capsule) is required.',
        ),
      );
    }
    if (releaseType == null || releaseType.isEmpty) {
      issues.add(
        const MedicationContextIssue(
          code: 'MISSING_RELEASE_TYPE',
          message:
              'Release type (immediate / extended / controlled) is required '
              'before pharmacokinetic-sensitive rules may be evaluated.',
        ),
      );
    }
    if (route == null || route.isEmpty) {
      issues.add(
        const MedicationContextIssue(
          code: 'MISSING_ROUTE',
          message: 'Administration route is required.',
        ),
      );
    }

    if (entry.sourceDocId == null || entry.sourceDocId!.trim().isEmpty) {
      issues.add(
        const MedicationContextIssue(
          code: 'MISSING_PROVENANCE',
          message:
              'No source document reference. Without provenance the entry '
              'cannot be promoted into evidence-linked rule evaluation.',
        ),
      );
    }

    if (entry.jurisdiction == null || entry.jurisdiction!.trim().isEmpty) {
      issues.add(
        const MedicationContextIssue(
          code: 'MISSING_JURISDICTION',
          message: 'Jurisdiction is required for rule applicability filtering.',
        ),
      );
    }

    final extractionConfidence = entry.extractionConfidence;
    if (extractionConfidence != null &&
        (!extractionConfidence.isFinite ||
            extractionConfidence < 0 ||
            extractionConfidence > 1)) {
      issues.add(
        const MedicationContextIssue(
          code: 'INVALID_EXTRACTION_CONFIDENCE',
          message: 'Extraction confidence must be finite and within 0 to 1.',
        ),
      );
    }

    final metadata = entry.medicationMetadata;
    if (metadata != null) {
      final metadataConfidenceInvalid =
          metadata.components.any(
            (component) => _invalidConfidence(component.extractionConfidence),
          ) ||
          metadata.labelSectionRefs.any(
            (section) => _invalidConfidence(section.extractionConfidence),
          );
      if (metadataConfidenceInvalid) {
        issues.add(
          const MedicationContextIssue(
            code: 'INVALID_METADATA_EXTRACTION_CONFIDENCE',
            message:
                'Medication metadata extraction confidence must be finite '
                'and within 0 to 1.',
          ),
        );
      }

      final topIngredientTokens = _canonicalIngredientTokens(ingredients);
      final metadataIngredientTokens = _canonicalIngredientTokens(
        metadata.components.map((component) => component.ingredientName),
      );
      final metadataIngredientsKnown =
          metadataIngredientTokens.isNotEmpty &&
          !metadataIngredientTokens.any(_isUnknownVocabularyToken);
      if (metadataIngredientsKnown &&
          !_sameTokenSet(topIngredientTokens, metadataIngredientTokens)) {
        issues.add(
          const MedicationContextIssue(
            code: 'METADATA_ACTIVE_INGREDIENT_MISMATCH',
            message:
                'Medication metadata components contradict the structured '
                'active-ingredient list.',
          ),
        );
      }

      _addIdentityMismatch(
        issues: issues,
        topLevelValue: entry.drugProductVariant,
        metadataValue: metadata.drugProductVariantId,
        fieldLabel: 'drug product variant',
        codePrefix: 'METADATA_DRUG_PRODUCT_VARIANT',
      );
      _addIdentityMismatch(
        issues: issues,
        topLevelValue: entry.sourceDocId,
        metadataValue: metadata.sourceDocId,
        fieldLabel: 'source document',
        codePrefix: 'METADATA_SOURCE_DOC',
      );
      _addIdentityMismatch(
        issues: issues,
        topLevelValue: entry.jurisdiction,
        metadataValue: metadata.jurisdiction,
        fieldLabel: 'jurisdiction',
        codePrefix: 'METADATA_JURISDICTION',
        canonicalize: _canonicalVocabularyToken,
      );

      _addVocabularyMismatch(
        issues: issues,
        topLevelValue: route,
        metadataValue: metadata.route,
        code: 'METADATA_ROUTE_MISMATCH',
        message: 'Medication metadata route contradicts the structured route.',
      );
      _addVocabularyMismatch(
        issues: issues,
        topLevelValue: form,
        metadataValue: metadata.doseForm,
        code: 'METADATA_FORM_MISMATCH',
        message:
            'Medication metadata dosage form contradicts the structured form.',
      );
      _addVocabularyMismatch(
        issues: issues,
        topLevelValue: releaseType,
        metadataValue: metadata.releaseType,
        code: 'METADATA_RELEASE_TYPE_MISMATCH',
        message:
            'Medication metadata release type contradicts the structured '
            'release type.',
        canonicalize: _canonicalReleaseType,
      );
    }

    if (issues.isNotEmpty) {
      final hasInvalidatingIssue = issues.any(
        (i) =>
            i.code == 'BARE_NUMERIC_DOSE' ||
            i.code == 'UNSTRUCTURED_FREE_TEXT' ||
            i.code == 'UNKNOWN_UNIT' ||
            i.code == 'NON_FINITE_STRENGTH' ||
            i.code == 'NON_POSITIVE_STRENGTH' ||
            i.code == 'INVALID_EXTRACTION_CONFIDENCE' ||
            i.code == 'INVALID_METADATA_EXTRACTION_CONFIDENCE' ||
            i.code.startsWith('METADATA_'),
      );
      return MedicationContextValidationResult(
        validity: hasInvalidatingIssue
            ? MedicationContextValidity.invalid
            : MedicationContextValidity.insufficient,
        issues: List.unmodifiable(issues),
        normalized: null,
        safeUserCopy: _safeInvalidCopy,
      );
    }

    final normalized = NormalizedMedicationContext(
      drugProductVariant: entry.drugProductVariant!.trim(),
      activeIngredients: List.unmodifiable(ingredients),
      form: form!,
      route: route!,
      releaseType: releaseType!,
      strength: entry.strength!.toDouble(),
      unit: entry.unit!.trim().toLowerCase(),
      jurisdiction: entry.jurisdiction!.trim(),
      sourceDocId: entry.sourceDocId!.trim(),
      labelSection: entry.labelSection?.trim(),
      extractionConfidence: entry.extractionConfidence,
      limitationText: defaultLimitationText,
      // Pass CDSS provenance through untouched — it is never read for dose.
      metadata: entry.medicationMetadata,
    );

    return MedicationContextValidationResult(
      validity: MedicationContextValidity.valid,
      issues: const [],
      normalized: normalized,
      safeUserCopy:
          'Synthetic medication context accepted for educational rule '
          'evaluation. This is not medical advice.',
    );
  }

  bool _looksLikeStructuredText(String raw) {
    // Heuristic only used to classify input rejection reasons. Even when this
    // returns true the entry still must pass the structured-field checks; this
    // function never grants validity on its own.
    final lower = raw.toLowerCase();
    return _allowedUnits.any((u) => lower.contains(' $u') || lower.endsWith(u));
  }

  static bool _invalidConfidence(double? value) =>
      value != null && (!value.isFinite || value < 0 || value > 1);

  static final RegExp _ingredientSeparator = RegExp(r'[/+,]');
  static final RegExp _canonicalWhitespace = RegExp(r'\s+');

  static Set<String> _canonicalIngredientTokens(Iterable<String> values) =>
      values
          .expand((value) => value.split(_ingredientSeparator))
          .map(
            (value) => value.trim().toLowerCase().replaceAll(
              _canonicalWhitespace,
              ' ',
            ),
          )
          .where((value) => value.isNotEmpty)
          .toSet();

  static bool _sameTokenSet(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);

  static String _canonicalVocabularyToken(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');

  static bool _isUnknownVocabularyToken(String value) {
    final canonical = _canonicalVocabularyToken(value);
    return canonical.isEmpty ||
        canonical == 'unknown' ||
        canonical == 'unspecified' ||
        canonical == 'not_reported' ||
        canonical == 'n/a' ||
        canonical == 'na';
  }

  static String _canonicalReleaseType(String value) {
    final canonical = _canonicalVocabularyToken(value);
    return switch (canonical) {
      'immediate_release' => 'immediate',
      'extended_release' => 'extended',
      'controlled_release' => 'controlled',
      'delayed_release' => 'delayed',
      _ => canonical,
    };
  }

  static void _addVocabularyMismatch({
    required List<MedicationContextIssue> issues,
    required String? topLevelValue,
    required String metadataValue,
    required String code,
    required String message,
    String Function(String) canonicalize = _canonicalVocabularyToken,
  }) {
    if (topLevelValue == null || topLevelValue.trim().isEmpty) return;
    if (_isUnknownVocabularyToken(metadataValue)) return;
    if (canonicalize(topLevelValue) == canonicalize(metadataValue)) return;
    issues.add(MedicationContextIssue(code: code, message: message));
  }

  static void _addIdentityMismatch({
    required List<MedicationContextIssue> issues,
    required String? topLevelValue,
    required String? metadataValue,
    required String fieldLabel,
    required String codePrefix,
    String Function(String) canonicalize = _canonicalIdentity,
  }) {
    if (metadataValue == null ||
        _isUnknownVocabularyToken(metadataValue) ||
        metadataValue.trim().isEmpty) {
      issues.add(
        MedicationContextIssue(
          code: '${codePrefix}_UNBOUND',
          message:
              'Medication metadata does not identify the governed $fieldLabel '
              'needed to bind it to the structured entry.',
        ),
      );
      return;
    }
    if (topLevelValue == null || topLevelValue.trim().isEmpty) return;
    if (canonicalize(topLevelValue) == canonicalize(metadataValue)) return;
    issues.add(
      MedicationContextIssue(
        code: '${codePrefix}_MISMATCH',
        message:
            'Medication metadata $fieldLabel contradicts the structured '
            '$fieldLabel.',
      ),
    );
  }

  static String _canonicalIdentity(String value) => value.trim();
}
