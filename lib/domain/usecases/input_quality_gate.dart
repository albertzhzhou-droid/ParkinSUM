/// P1 — InputQualityGate / MealMedicationEntryQualityScorer.
///
/// Educational/research prototype only. A pure, deterministic **aggregator and
/// interpreter** of existing completeness signals (medication validation, meal
/// composition completeness, source/provenance quality, timing-window presence,
/// localization readiness). It decides whether a meal + medication context is
/// complete / sufficient / partial / insufficient / invalid for entering
/// mechanistic scoring, and whether it is eligible for mechanistic-primary
/// ranking.
///
/// It is an input/context-completeness gate, **NOT** a recommendation engine. It
/// never tells the user what to eat, when to eat, when to take medication, how
/// to dose, or what is safe. It does not validate clinical correctness, does not
/// fabricate missing values (missing nutrient is never treated as a true zero;
/// product strength is never read as a user intake dose), and is not clinically
/// calibrated. No PHI / patient / subject / encounter semantics.
library;

import 'dart:convert';

import '../entities/input_quality.dart';
import '../entities/meal_composition.dart';
import '../entities/medication_entry_validation.dart';
import '../entities/nutrient_derivation.dart';
import '../entities/rule_explanation.dart';
import '../entities/source_metadata.dart';
import '../entities/time_axis_events.dart';
import 'medication_entry_validator.dart';

/// Lightweight, UI-free input bundle for the gate. Every field is optional so
/// callers can pass exactly the signals they have; absent signals lower
/// completeness rather than fabricate values.
class InputQualityGateInput {
  /// Raw, structured medication entry. When [medicationValidation] is null the
  /// gate runs [MedicationEntryValidator] internally.
  final RawMedicationEntry? medicationEntry;

  /// Pre-computed medication validation (optional; avoids re-running).
  final MedicationContextValidationResult? medicationValidation;

  /// When true, any numeric strength on the entry represents *product strength
  /// metadata*, not a user-entered intake dose — so it must NOT rescue a
  /// missing user dosage.
  final bool productStrengthMetadataOnly;

  /// Normalized meal composition (missing-vs-zero already encoded).
  final MealComposition? mealComposition;

  /// Food provenance/source metadata for the candidate.
  final FoodVariantMetadata? foodMetadata;

  /// Optional authority tier for the food source (synthetic/seed never reaches
  /// official-level confidence). When null it is inferred from the food
  /// metadata `sourceSystem`.
  final SourceAuthorityTier? foodSourceAuthorityTier;

  /// Whether candidate metadata was available to the ranker at all.
  final bool candidateMetadataPresent;

  /// User-defined meal window (mechanistic-primary requires a valid one).
  final UserDefinedMealWindow? userDefinedWindow;

  /// Optional localization readiness status.
  final LocalizationReadinessStatus localizationStatus;

  const InputQualityGateInput({
    this.medicationEntry,
    this.medicationValidation,
    this.productStrengthMetadataOnly = false,
    this.mealComposition,
    this.foodMetadata,
    this.foodSourceAuthorityTier,
    this.candidateMetadataPresent = true,
    this.userDefinedWindow,
    this.localizationStatus = LocalizationReadinessStatus.notProvided,
  });
}

class InputQualityGate {
  final MedicationEntryValidator _medValidator;

  InputQualityGate({MedicationEntryValidator? medicationValidator})
      : _medValidator = medicationValidator ?? MedicationEntryValidator();

  static const List<String> _limitations = [
    'Input/context-completeness assessment only; not medical advice and not a recommendation.',
    'Does not validate clinical correctness and is not clinically calibrated.',
    'Does not recommend dose, timing, or meal choices, and never fabricates missing values.',
    'Product strength is product metadata, not a user intake dose; missing nutrient is not a true zero.',
    'Aggregates existing validators; it does not replace clinician judgement.',
  ];

  MealMedicationInputQualityResult evaluate(
    InputQualityGateInput input, {
    InputQualityGateConfig config = const InputQualityGateConfig(),
  }) {
    final dims = <InputQualityDimensionScore>[];
    final fallback = <String>[];

    final med = input.medicationValidation ??
        (input.medicationEntry != null
            ? _medValidator.validate(input.medicationEntry!)
            : null);
    final issueCodes = med?.issues.map((i) => i.code).toSet() ?? <String>{};

    dims.add(_dosage(med, issueCodes, input.productStrengthMetadataOnly));
    dims.add(_identity(med, issueCodes, config));
    dims.add(_medicationMetadata(med, issueCodes));
    dims.add(_mealComposition(input.mealComposition));
    dims.add(
        _foodSourceQuality(input.foodMetadata, input.foodSourceAuthorityTier));
    dims.add(_nutrientProvenance(input.foodMetadata));
    dims.add(_timingWindow(input.userDefinedWindow, fallback));
    dims.add(_localization(input.localizationStatus));

    // Candidate-metadata fallback signal.
    if (!input.candidateMetadataPresent) {
      fallback.add('missing_candidate_metadata');
    }

    // Flatten findings deterministically (dimension order, then within).
    final findings = <InputQualityFinding>[
      for (final d in dims) ...d.findings,
    ];

    // Overall context status = weakest of the context dimensions.
    var overall = InputQualityStatus.complete;
    for (final d in dims) {
      if (InputQualityDimension.contextDimensions.contains(d.dimension)) {
        overall = InputQualityStatus.weaker(overall, d.status);
      }
    }
    // An unsafe-localization blocker also caps the overall context.
    final localizationBlocker = dims
        .firstWhere(
            (d) => d.dimension == InputQualityDimension.localizationReadiness)
        .findings
        .any((f) => f.severity == InputQualitySeverity.blocker);
    if (localizationBlocker) {
      overall =
          InputQualityStatus.weaker(overall, InputQualityStatus.insufficient);
    }

    final overallScore = _avg([
      for (final d in dims)
        if (InputQualityDimension.contextDimensions.contains(d.dimension))
          d.score,
    ]);

    // Blocking reasons: every blocker finding (deterministic order).
    final blocking = <String>[
      for (final f in findings)
        if (f.severity == InputQualitySeverity.blocker)
          '${f.dimension}: ${f.findingId}',
    ];

    // Mechanistic-primary eligibility.
    final windowDim = dims.firstWhere(
        (d) => d.dimension == InputQualityDimension.mealTimingWindow);
    final windowOk = windowDim.status == InputQualityStatus.complete ||
        windowDim.status == InputQualityStatus.sufficient;
    if (!windowOk) fallback.add('mechanistic_primary_window_unavailable');

    final eligible = blocking.isEmpty &&
        windowOk &&
        input.candidateMetadataPresent &&
        overall != InputQualityStatus.invalid &&
        overall != InputQualityStatus.insufficient;

    if (!eligible && blocking.isNotEmpty) {
      fallback.add('input_quality_blocking_findings');
    }

    final sourceRefs = <String>{
      ...?input.foodMetadata?.sourceRefs,
      if (med?.normalized?.sourceDocId != null &&
          med!.normalized!.sourceDocId.isNotEmpty)
        med.normalized!.sourceDocId,
    }.toList()
      ..sort();

    return MealMedicationInputQualityResult(
      overallStatus: overall,
      overallScore: overallScore,
      dimensionScores: dims,
      findings: findings,
      mechanisticPrimaryEligible: eligible,
      blockingReasons: blocking,
      fallbackReasons: fallback,
      sourceRefs: sourceRefs,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      notClinicallyCalibrated: true,
      limitations: _limitations,
    );
  }

  // --- Dimension evaluators -------------------------------------------------

  InputQualityDimensionScore _dosage(
    MedicationContextValidationResult? med,
    Set<String> codes,
    bool productStrengthMetadataOnly,
  ) {
    const dim = InputQualityDimension.medicationDosage;
    final findings = <InputQualityFinding>[];

    if (med == null) {
      findings.add(_f('dosage_no_entry', InputQualitySeverity.blocker, dim,
          'No medication entry was provided; dosage cannot be assessed.',
          missing: 'medication_entry',
          expected:
              'A catalog-backed entry with explicit numeric strength and unit.'));
      return _dimScore(dim, InputQualityStatus.insufficient, findings);
    }

    if (productStrengthMetadataOnly) {
      findings.add(_f(
          'dosage_product_strength_only',
          InputQualitySeverity.blocker,
          dim,
          'Only product strength metadata is present; product strength is '
              'product metadata, not a user intake dose, and does not satisfy the '
              'dosage requirement.',
          missing: 'user_intake_dose',
          expected: 'An explicitly entered intake dose (value + unit).'));
      return _dimScore(dim, InputQualityStatus.insufficient, findings);
    }

    // Hard-invalid dose shapes (bare numeric, slash-format, unknown unit, etc.).
    final invalidating = codes.intersection({
      'BARE_NUMERIC_DOSE',
      'UNSTRUCTURED_FREE_TEXT',
      'UNKNOWN_UNIT',
      'NON_POSITIVE_STRENGTH',
    });
    if (invalidating.isNotEmpty) {
      findings.add(_f(
          'dosage_invalid_shape',
          InputQualitySeverity.blocker,
          dim,
          'Dosage is structurally invalid (e.g. unitless, slash-format, or an '
              'unrecognized unit). A bare number is not a dose.',
          observed: invalidating.join(', '),
          expected:
              'A positive numeric strength with an allowed unit (e.g. 100 mg).'));
      return _dimScore(dim, InputQualityStatus.invalid, findings);
    }

    final missingDose =
        codes.intersection({'MISSING_UNIT', 'MISSING_STRENGTH'});
    if (missingDose.isNotEmpty) {
      findings.add(_f(
          'dosage_missing',
          InputQualitySeverity.blocker,
          dim,
          'An explicit numeric strength and unit are required; a missing value '
              'is not auto-filled.',
          missing: missingDose.join(', '),
          expected: 'Both an explicit strength value and an explicit unit.'));
      return _dimScore(dim, InputQualityStatus.insufficient, findings);
    }

    // Strength + unit present and not flagged → complete.
    return _dimScore(dim, InputQualityStatus.complete, findings);
  }

  InputQualityDimensionScore _identity(
    MedicationContextValidationResult? med,
    Set<String> codes,
    InputQualityGateConfig config,
  ) {
    const dim = InputQualityDimension.medicationIdentity;
    final findings = <InputQualityFinding>[];
    if (med == null) {
      findings.add(_f(
          'identity_no_entry',
          InputQualitySeverity.blocker,
          dim,
          'No medication entry was provided; active ingredient identity is '
              'unknown.',
          missing: 'active_ingredient'));
      return _dimScore(dim, InputQualityStatus.insufficient, findings);
    }
    if (codes.contains('MISSING_ACTIVE_INGREDIENT')) {
      findings.add(_f(
          'identity_missing_ingredient',
          InputQualitySeverity.blocker,
          dim,
          'No active ingredient was provided; identity is blocked.',
          missing: 'active_ingredient',
          expected: 'At least one explicit active ingredient.'));
      return _dimScore(dim, InputQualityStatus.invalid, findings);
    }
    var status = InputQualityStatus.complete;
    if (codes.contains('MISSING_DRUG_PRODUCT_VARIANT')) {
      findings.add(_f('identity_missing_variant', InputQualitySeverity.warn,
          dim, 'No catalog-backed product variant; identity is partial.',
          missing: 'drug_product_variant'));
      status = InputQualityStatus.weaker(status, InputQualityStatus.partial);
    }
    // Levodopa-specific scoring expectation (combination products preserved).
    final ingredients = med.normalized?.activeIngredients ?? const <String>[];
    if (config.expectsLevodopaContext) {
      final hasLevodopa = ingredients.any((i) => i.toLowerCase() == 'levodopa');
      if (!hasLevodopa) {
        findings.add(_f(
            'identity_no_levodopa',
            InputQualitySeverity.warn,
            dim,
            'Levodopa-specific scoring was expected but no levodopa component '
                'is present in the preserved ingredient list.',
            missing: 'levodopa_component'));
        status = InputQualityStatus.weaker(status, InputQualityStatus.partial);
      }
    }
    return _dimScore(dim, status, findings);
  }

  InputQualityDimensionScore _medicationMetadata(
    MedicationContextValidationResult? med,
    Set<String> codes,
  ) {
    const dim = InputQualityDimension.medicationMetadata;
    final findings = <InputQualityFinding>[];
    if (med == null) {
      findings.add(_f(
          'metadata_no_entry',
          InputQualitySeverity.warn,
          dim,
          'No medication entry; form/release/route/provenance metadata is '
              'unknown.'));
      return _dimScore(dim, InputQualityStatus.insufficient, findings);
    }
    final missing = <String>[];
    void note(String code, String field, String id, String msg) {
      if (codes.contains(code)) {
        missing.add(field);
        findings
            .add(_f(id, InputQualitySeverity.warn, dim, msg, missing: field));
      }
    }

    note('MISSING_FORM', 'dose_form', 'metadata_missing_form',
        'Dose form is missing; metadata quality is lowered (no value fabricated).');
    note(
        'MISSING_RELEASE_TYPE',
        'release_type',
        'metadata_missing_release_type',
        'Release type is missing/unknown; this lowers metadata quality but is '
            'not fabricated as immediate-release.');
    note('MISSING_ROUTE', 'route', 'metadata_missing_route',
        'Administration route is missing; metadata quality is lowered.');
    note(
        'MISSING_PROVENANCE',
        'source_refs',
        'metadata_missing_sourcerefs',
        'No source document reference (sourceRefs); evidence-linkage quality is '
            'lowered.');
    note(
        'MISSING_JURISDICTION',
        'jurisdiction',
        'metadata_missing_jurisdiction',
        'Jurisdiction is missing; rule-applicability metadata is lowered.');

    final n = missing.length;
    final status = n == 0
        ? InputQualityStatus.complete
        : n == 1
            ? InputQualityStatus.sufficient
            : n <= 3
                ? InputQualityStatus.partial
                : InputQualityStatus.insufficient;
    return _dimScore(dim, status, findings);
  }

  InputQualityDimensionScore _mealComposition(MealComposition? meal) {
    const dim = InputQualityDimension.mealComposition;
    final findings = <InputQualityFinding>[];
    if (meal == null || meal.foodComponents.isEmpty) {
      findings.add(_f('meal_empty', InputQualitySeverity.blocker, dim,
          'No food components were provided; meal composition is invalid.',
          missing: 'food_components'));
      return _dimScore(dim, InputQualityStatus.invalid, findings);
    }

    // Missing-vs-zero: a field in missingFields is unknown (not zero). A true
    // 0 g value is present (AmountBand.none) and is NOT a missing field.
    final missing = meal.missingFields;
    if (missing.contains('protein_grams')) {
      findings.add(_f('meal_missing_protein', InputQualitySeverity.warn, dim,
          'Protein is missing and is treated as unknown — NOT as 0 g.',
          missing: 'protein_grams'));
    } else if (meal.proteinGrams == 0) {
      findings.add(_f('meal_protein_true_zero', InputQualitySeverity.info, dim,
          'Protein is an explicit 0 g (a valid zero, not a missing value).',
          observed: '0'));
    }
    if (missing.contains('total_calories')) {
      findings.add(_f('meal_missing_calories', InputQualitySeverity.warn, dim,
          'Calories are missing; completeness is lowered (not fabricated).',
          missing: 'total_calories'));
    }
    final missingPortion =
        meal.foodComponents.any((c) => c.portionGrams == null);
    if (missingPortion) {
      findings.add(_f(
          'meal_missing_portion',
          InputQualitySeverity.warn,
          dim,
          'At least one component is missing a portion amount; completeness is '
              'lowered.',
          missing: 'portion_grams'));
    }

    final c = meal.compositionCompleteness;
    final hasPortionPenalty = missingPortion;
    final status = (c >= 0.99 && !hasPortionPenalty)
        ? InputQualityStatus.complete
        : c >= 0.66
            ? InputQualityStatus.sufficient
            : c >= 0.34
                ? InputQualityStatus.partial
                : InputQualityStatus.insufficient;
    return _dimScore(dim, status, findings);
  }

  InputQualityDimensionScore _foodSourceQuality(
    FoodVariantMetadata? meta,
    SourceAuthorityTier? tier,
  ) {
    const dim = InputQualityDimension.foodSourceQuality;
    final findings = <InputQualityFinding>[];
    if (meta == null) {
      findings.add(_f('food_no_metadata', InputQualitySeverity.warn, dim,
          'No food source/provenance metadata; source quality is unknown.',
          missing: 'food_variant_metadata'));
      return _dimScore(dim, InputQualityStatus.insufficient, findings);
    }

    var status = InputQualityStatus.complete;
    if (meta.sourceRefs.isEmpty) {
      findings.add(_f('food_missing_sourcerefs', InputQualitySeverity.warn, dim,
          'No sourceRefs on the food metadata; source quality is lowered.',
          missing: 'source_refs'));
      status = InputQualityStatus.weaker(status, InputQualityStatus.partial);
    }

    final effectiveTier = tier ?? _inferTier(meta.sourceSystem);
    final isSyntheticOrSeed =
        effectiveTier == SourceAuthorityTier.syntheticDemo ||
            effectiveTier == SourceAuthorityTier.seedOrManualDemo;
    if (isSyntheticOrSeed) {
      findings.add(_f(
          'food_synthetic_source',
          InputQualitySeverity.warn,
          dim,
          'Synthetic/seed source does not receive official-level confidence; '
              'source quality is capped below official.',
          observed: effectiveTier.name));
      // Cap below official confidence.
      status = InputQualityStatus.weaker(status, InputQualityStatus.partial);
    } else if (effectiveTier == SourceAuthorityTier.unknown) {
      findings.add(_f('food_unknown_authority', InputQualitySeverity.warn, dim,
          'Food source authority is unknown; source quality is lowered.',
          observed: 'unknown'));
      status = InputQualityStatus.weaker(status, InputQualityStatus.partial);
    }
    return _dimScore(dim, status, findings);
  }

  InputQualityDimensionScore _nutrientProvenance(FoodVariantMetadata? meta) {
    const dim = InputQualityDimension.nutrientProvenance;
    final findings = <InputQualityFinding>[];
    final tierName = meta?.nutrientConfidenceTier;
    if (tierName == null) {
      findings.add(_f(
          'provenance_unknown',
          InputQualitySeverity.warn,
          dim,
          'No nutrient derivation provenance; provenance is unknown (this never '
              'raises confidence).',
          missing: 'nutrient_confidence_tier'));
      return _dimScore(dim, InputQualityStatus.partial, findings);
    }
    final tier = _tierFromName(tierName);
    switch (tier) {
      case NutrientConfidenceTier.analytical:
        findings.add(_f('provenance_analytical', InputQualitySeverity.info, dim,
            'Nutrient values are analytically derived; no provenance downgrade.',
            observed: 'analytical'));
        return _dimScore(dim, InputQualityStatus.complete, findings);
      case NutrientConfidenceTier.calculated:
        findings.add(_f(
            'provenance_calculated',
            InputQualitySeverity.warn,
            dim,
            'Nutrient values are calculated (not directly measured); a small '
                'source-quality downgrade applies.',
            observed: 'calculated'));
        return _dimScore(dim, InputQualityStatus.sufficient, findings);
      case NutrientConfidenceTier.imputedOrAssumed:
        findings.add(_f(
            'provenance_imputed',
            InputQualitySeverity.warn,
            dim,
            'Nutrient values are imputed/assumed; a clearer source-quality '
                'downgrade applies.',
            observed: 'imputedOrAssumed'));
        return _dimScore(dim, InputQualityStatus.partial, findings);
      case NutrientConfidenceTier.unknown:
        findings.add(_f(
            'provenance_tier_unknown',
            InputQualitySeverity.warn,
            dim,
            'Nutrient derivation provenance is unknown; provenance quality is '
                'lowered.',
            observed: 'unknown'));
        return _dimScore(dim, InputQualityStatus.insufficient, findings);
    }
  }

  InputQualityDimensionScore _timingWindow(
    UserDefinedMealWindow? window,
    List<String> fallback,
  ) {
    const dim = InputQualityDimension.mealTimingWindow;
    final findings = <InputQualityFinding>[];
    if (window == null) {
      // Not invalid — just not eligible for mechanistic-primary. No advice.
      findings.add(_f(
          'window_missing',
          InputQualitySeverity.warn,
          dim,
          'No user-defined meal window is present, so mechanistic-primary '
              'ranking is not eligible. This is a context note, not a suggested '
              'meal time.',
          missing: 'user_defined_meal_window'));
      return _dimScore(dim, InputQualityStatus.partial, findings);
    }
    final duration = window.window.durationMinutes;
    if (duration <= 0) {
      findings.add(_f(
          'window_invalid_duration',
          InputQualitySeverity.blocker,
          dim,
          'The meal window duration is non-positive; the window is invalid.',
          observed: '$duration'));
      return _dimScore(dim, InputQualityStatus.invalid, findings);
    }
    return _dimScore(dim, InputQualityStatus.complete, findings);
  }

  InputQualityDimensionScore _localization(LocalizationReadinessStatus s) {
    const dim = InputQualityDimension.localizationReadiness;
    final findings = <InputQualityFinding>[];
    if (!s.provided) {
      findings.add(_f(
          'localization_not_provided',
          InputQualitySeverity.info,
          dim,
          'No localization readiness status was provided; treated as '
              'informational only (never a blocker).'));
      return _dimScore(dim, InputQualityStatus.partial, findings);
    }
    if (s.hasUnsafeLocalizedCopy) {
      findings.add(_f(
          'localization_unsafe',
          InputQualitySeverity.blocker,
          dim,
          'An unsafe localized copy finding was reported; localized output is '
              'not ready.'));
      return _dimScore(dim, InputQualityStatus.invalid, findings);
    }
    if (s.missingLocalizedSafetyCopy) {
      findings.add(_f(
          'localization_missing_safety_copy',
          InputQualitySeverity.warn,
          dim,
          'Required localized safety/boundary copy is missing for a locale.'));
      return _dimScore(dim, InputQualityStatus.partial, findings);
    }
    return _dimScore(dim, InputQualityStatus.complete, findings);
  }

  // --- helpers --------------------------------------------------------------

  InputQualityFinding _f(
    String id,
    String severity,
    String dimension,
    String message, {
    String missing = '',
    String observed = '',
    String expected = '',
    List<String> sourceRefs = const [],
  }) =>
      InputQualityFinding(
        findingId: id,
        severity: severity,
        dimension: dimension,
        message: message,
        missingField: missing,
        observedValue: observed,
        expectedRequirement: expected,
        sourceRefs: sourceRefs,
      );

  InputQualityDimensionScore _dimScore(
          String dim, String status, List<InputQualityFinding> findings) =>
      InputQualityDimensionScore(
        dimension: dim,
        status: status,
        score: InputQualityStatus.score(status),
        findings: List.unmodifiable(findings),
      );

  double _avg(List<double> xs) {
    if (xs.isEmpty) return 0.0;
    final total = xs.fold<double>(0, (a, b) => a + b);
    return total / xs.length;
  }

  SourceAuthorityTier _inferTier(String sourceSystem) {
    final s = sourceSystem.toLowerCase();
    if (s.contains('synthetic')) return SourceAuthorityTier.syntheticDemo;
    if (s.contains('seed') || s.contains('app_seed')) {
      return SourceAuthorityTier.seedOrManualDemo;
    }
    return SourceAuthorityTier.unknown;
  }

  NutrientConfidenceTier _tierFromName(String name) {
    switch (name) {
      case 'analytical':
        return NutrientConfidenceTier.analytical;
      case 'calculated':
        return NutrientConfidenceTier.calculated;
      case 'imputedOrAssumed':
        return NutrientConfidenceTier.imputedOrAssumed;
      default:
        return NutrientConfidenceTier.unknown;
    }
  }
}

/// Deterministic JSON encoder for the input-quality result.
String encodeInputQualityResult(MealMedicationInputQualityResult r) =>
    const JsonEncoder.withIndent('  ').convert(r.toJson());
