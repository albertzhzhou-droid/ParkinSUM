import '../entities/medication_entry_validation.dart';

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
  });
}

/// Deterministic, side-effect-free validator. No I/O, no LLM, no inference of
/// missing fields from free-text. If a field is missing the entry is rejected;
/// it is never auto-completed.
class MedicationEntryValidator {
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
  static final RegExp _slashedNumeric =
      RegExp(r'^\s*[0-9]+\s*[\/\-]\s*[0-9]+\s*$');
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
        issues.add(const MedicationContextIssue(
          code: 'BARE_NUMERIC_DOSE',
          message:
              'A numeric value without unit, ingredient, and formulation cannot '
              'represent an analyzable medication entry.',
        ));
      } else if (!_looksLikeStructuredText(raw)) {
        // Names like "levodopa 100" or "Sinemet 100" with no unit also fail.
        issues.add(const MedicationContextIssue(
          code: 'UNSTRUCTURED_FREE_TEXT',
          message: 'Free-text medication input is not promoted into rule '
              'evaluation. Use a catalog-backed entry.',
        ));
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
      issues.add(const MedicationContextIssue(
        code: 'MISSING_ACTIVE_INGREDIENT',
        message:
            'No active ingredient was provided. Food-medication rules require '
            'an explicit ingredient.',
      ));
    }

    if (entry.drugProductVariant == null ||
        entry.drugProductVariant!.trim().isEmpty) {
      issues.add(const MedicationContextIssue(
        code: 'MISSING_DRUG_PRODUCT_VARIANT',
        message:
            'No catalog-backed product variant. Bare names or free-text drug '
            'labels are not promoted to rule evaluation.',
      ));
    }

    if (entry.unit == null || entry.unit!.trim().isEmpty) {
      issues.add(const MedicationContextIssue(
        code: 'MISSING_UNIT',
        message: 'Unit is required. A bare number is not a dose.',
      ));
    } else if (!_allowedUnits.contains(entry.unit!.trim().toLowerCase())) {
      issues.add(MedicationContextIssue(
        code: 'UNKNOWN_UNIT',
        message:
            'Unit "${entry.unit}" is not in the allowed unit vocabulary for '
            'this prototype.',
      ));
    }

    if (entry.strength == null) {
      issues.add(const MedicationContextIssue(
        code: 'MISSING_STRENGTH',
        message: 'Numeric strength is required alongside an explicit unit.',
      ));
    } else if ((entry.strength as num) <= 0) {
      issues.add(const MedicationContextIssue(
        code: 'NON_POSITIVE_STRENGTH',
        message: 'Strength must be a positive number.',
      ));
    }

    // Formulation / release type may be downgraded to "insufficient" rather
    // than invalid, but they still block rule evaluation that depends on PK.
    final form = entry.form?.trim();
    final releaseType = entry.releaseType?.trim();
    final route = entry.route?.trim();
    if (form == null || form.isEmpty) {
      issues.add(const MedicationContextIssue(
        code: 'MISSING_FORM',
        message: 'Dosage form (e.g. tablet, capsule) is required.',
      ));
    }
    if (releaseType == null || releaseType.isEmpty) {
      issues.add(const MedicationContextIssue(
        code: 'MISSING_RELEASE_TYPE',
        message: 'Release type (immediate / extended / controlled) is required '
            'before pharmacokinetic-sensitive rules may be evaluated.',
      ));
    }
    if (route == null || route.isEmpty) {
      issues.add(const MedicationContextIssue(
        code: 'MISSING_ROUTE',
        message: 'Administration route is required.',
      ));
    }

    if (entry.sourceDocId == null || entry.sourceDocId!.trim().isEmpty) {
      issues.add(const MedicationContextIssue(
        code: 'MISSING_PROVENANCE',
        message: 'No source document reference. Without provenance the entry '
            'cannot be promoted into evidence-linked rule evaluation.',
      ));
    }

    if (entry.jurisdiction == null || entry.jurisdiction!.trim().isEmpty) {
      issues.add(const MedicationContextIssue(
        code: 'MISSING_JURISDICTION',
        message: 'Jurisdiction is required for rule applicability filtering.',
      ));
    }

    if (issues.isNotEmpty) {
      final hasInvalidatingIssue = issues.any((i) =>
          i.code == 'BARE_NUMERIC_DOSE' ||
          i.code == 'UNSTRUCTURED_FREE_TEXT' ||
          i.code == 'UNKNOWN_UNIT' ||
          i.code == 'NON_POSITIVE_STRENGTH');
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
      strength: (entry.strength as num).toDouble(),
      unit: entry.unit!.trim().toLowerCase(),
      jurisdiction: entry.jurisdiction!.trim(),
      sourceDocId: entry.sourceDocId!.trim(),
      labelSection: entry.labelSection?.trim(),
      extractionConfidence: entry.extractionConfidence,
      limitationText: defaultLimitationText,
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
}
