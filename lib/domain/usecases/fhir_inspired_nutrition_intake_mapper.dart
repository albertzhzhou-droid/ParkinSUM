import '../entities/amino_acid_profile.dart';
import '../entities/fhir_inspired_nutrition_intake_view.dart';
import '../entities/meal_composition.dart';
import '../entities/nutrient_derivation.dart';
import '../entities/rule_explanation.dart';

/// Maps ParkinSUM's internal `MealComposition` into a local, **FHIR-inspired**
/// (NOT FHIR-conformant), PHI-free `FhirInspiredNutritionIntakeView`.
///
/// Educational/research prototype only. The mapper:
/// - preserves missingness (null stays null; never coerced to 0);
/// - preserves `sourceRefs` and FDC nutrient-derivation provenance/tier;
/// - preserves the nutrient basis;
/// - **omits** subject/patient/encounter/practitioner/diagnosis/treatment —
///   it never constructs a Patient/Reference/Encounter;
/// - marks the output `inspired_not_conformant` + `subject_omitted_no_phi`;
/// - reuses the shared non-prescriptive safety copy.
///
/// Pure and deterministic: no I/O, no clock. The caller passes an optional
/// `relativeTimeMinutes` (never an absolute/real timeline).
class FhirInspiredNutritionIntakeMapper {
  const FhirInspiredNutritionIntakeMapper();

  FhirInspiredNutritionIntakeView fromMealComposition(
    MealComposition composition, {
    String? demoMealId,
    int? relativeTimeMinutes,
  }) {
    final components = composition.foodComponents
        .map(_componentEntry)
        .toList(growable: false);

    final nutrientSummary = _nutrientSummary(composition);
    final aminoAcidSummary = _aminoAcidSummary(composition);

    // Union of component source refs (no new ref is minted by the view).
    final sourceRefs = <String>{
      for (final c in composition.foodComponents)
        ...?c.aminoAcidProfile?.sourceRefs,
    }.toList(growable: false)..sort();

    final provenanceSummary =
        'amino_acid_data_mode=${aminoAcidSummary.aminoAcidDataMode}; '
        'missing_fields=${composition.missingFields.length}; '
        'fdc_data_type=${aminoAcidSummary.fdcDataType ?? 'none'}; '
        'composition_completeness='
        '${composition.compositionCompleteness.toStringAsFixed(2)}';

    return FhirInspiredNutritionIntakeView(
      demoMealId: demoMealId ?? composition.id,
      relativeTimeMinutes: relativeTimeMinutes,
      foodComponents: components,
      nutrientSummary: nutrientSummary,
      aminoAcidSummary: aminoAcidSummary,
      missingFields: List<String>.unmodifiable(composition.missingFields),
      sourceRefs: sourceRefs,
      provenanceSummary: provenanceSummary,
      notClinicallyCalibrated: true,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
    );
  }

  FhirInspiredFoodComponentEntry _componentEntry(FoodComponent c) {
    final missing = <String>[
      if (c.proteinGrams == null) 'protein_grams',
      if (c.fatGrams == null) 'fat_grams',
      if (c.fiberGrams == null) 'fiber_grams',
      if (c.carbohydrateGrams == null) 'carbohydrate_grams',
      if (c.calories == null) 'calories',
      if (c.portionGrams == null) 'portion_grams',
    ];
    return FhirInspiredFoodComponentEntry(
      foodName: c.name,
      amount: c.portionGrams,
      amountUnit: c.portionGrams == null ? null : 'g',
      // preparationState lives on FoodItem, not FoodComponent — unavailable at
      // the composition level. Recorded as null rather than guessed.
      preparationState: null,
      basisType: c.aminoAcidProfile?.basis,
      sourceSystem: c.sourceDocId,
      sourceRefs: c.aminoAcidProfile?.sourceRefs ?? const [],
      missingFields: missing,
    );
  }

  FhirInspiredNutrientSummary _nutrientSummary(MealComposition comp) {
    return FhirInspiredNutrientSummary(
      energyKcal: comp.totalCalories,
      proteinG: comp.proteinGrams,
      fatG: comp.fatGrams,
      carbohydrateG: comp.carbohydrateGrams,
      fiberG: comp.fiberGrams,
      missingness: {
        'energy_kcal': comp.totalCalories == null,
        'protein_g': comp.proteinGrams == null,
        'fat_g': comp.fatGrams == null,
        'carbohydrate_g': comp.carbohydrateGrams == null,
        'fiber_g': comp.fiberGrams == null,
      },
      unit: const {'energy': 'kcal', 'macros': 'g'},
      basis: 'per_meal_aggregate',
    );
  }

  FhirInspiredAminoAcidSummary _aminoAcidSummary(MealComposition comp) {
    final proteinComponents = <FoodComponent>[];
    for (final component in comp.foodComponents) {
      final protein = component.proteinGrams;
      if (protein == null || !protein.isFinite || protein < 0) {
        // Unknown or invalid protein means the mapper cannot prove that every
        // positive-protein component has a usable amino-acid profile.
        return _emptyAminoAcidSummary;
      }
      if (protein > 0) proteinComponents.add(component);
    }
    final profiles = <AminoAcidProfile>[];
    for (final component in proteinComponents) {
      final profile = _completeServingProfile(component);
      if (profile == null) return _emptyAminoAcidSummary;
      profiles.add(profile);
    }

    if (profiles.isEmpty) {
      // No actual amino-acid fields → no static data mode (missing, not zero).
      return _emptyAminoAcidSummary;
    }

    final ids = <String>{};
    var competing = 0.0;
    // Summed per-acid; an acid stays null until at least one profile reports it.
    double? leu, ile, val, phe, tyr, trp;
    NutrientConfidenceTier? tier;
    String? fdcDataType;

    double? add(double? acc, double? v) => v == null ? acc : (acc ?? 0) + v;

    for (final p in profiles) {
      ids.addAll(p.nutrientIds);
      competing += p.competingLnaaGrams ?? 0;
      leu = add(leu, p.leucine);
      ile = add(ile, p.isoleucine);
      val = add(val, p.valine);
      phe = add(phe, p.phenylalanine);
      tyr = add(tyr, p.tyrosine);
      trp = add(trp, p.tryptophan);
      fdcDataType ??= p.fdcDataType;
      final t = p.aggregateConfidenceTier;
      if (t != null &&
          (tier == null ||
              nutrientConfidenceRank(t) > nutrientConfidenceRank(tier))) {
        tier = t; // weakest-wins
      }
    }

    return FhirInspiredAminoAcidSummary(
      aminoAcidDataMode: AminoAcidDataMode.actualAminoAcidFields.name,
      aminoAcidNutrientIds: (ids.toList(growable: false))..sort(),
      aminoAcidConfidenceTier: tier?.name,
      competingLnaaGrams: competing,
      lnaaValues: {
        'leucine': leu,
        'isoleucine': ile,
        'valine': val,
        'phenylalanine': phe,
        'tyrosine': tyr,
        'tryptophan': trp,
      },
      fdcDataType: fdcDataType,
    );
  }

  /// Mirrors the competition model's conservative admission boundary: actual
  /// amino-acid summaries require an unambiguous gram unit, a supported basis,
  /// all six competing LNAAs, finite non-negative values, and a total that does
  /// not exceed the component's declared protein. A partial/held profile is
  /// still preserved on the component, but must never be relabelled "actual".
  AminoAcidProfile? _completeServingProfile(FoodComponent component) {
    final raw = component.aminoAcidProfile;
    if (raw == null || raw.partial || raw.unit.trim().toLowerCase() != 'g') {
      return null;
    }

    final AminoAcidProfile profile;
    if (raw.basis == 'per_serving') {
      profile = raw;
    } else if (raw.basis == 'per_100g') {
      final portion = component.portionGrams;
      if (portion == null || !portion.isFinite || portion <= 0) return null;
      final scaled = raw.scaledToGrams(portion);
      if (scaled == null) return null;
      profile = scaled;
    } else {
      return null;
    }

    final values = [
      profile.leucine,
      profile.isoleucine,
      profile.valine,
      profile.phenylalanine,
      profile.tyrosine,
      profile.tryptophan,
    ];
    if (values.any((value) => value == null || !value.isFinite || value < 0)) {
      return null;
    }
    final total = profile.competingLnaaGrams!;
    final protein = component.proteinGrams!;
    if (!total.isFinite || total < 0 || total > protein) return null;
    return profile;
  }

  static const _emptyAminoAcidSummary = FhirInspiredAminoAcidSummary(
    aminoAcidDataMode: 'none',
    aminoAcidNutrientIds: [],
    aminoAcidConfidenceTier: null,
    competingLnaaGrams: null,
    lnaaValues: {},
    fdcDataType: null,
  );
}
