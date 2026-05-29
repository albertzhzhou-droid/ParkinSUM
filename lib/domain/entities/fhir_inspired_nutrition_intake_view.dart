/// Local, **FHIR-inspired** (NOT FHIR-conformant) serialization view of meal
/// composition + nutrient/amino-acid provenance.
///
/// Educational/research prototype only. This view exists for local educational
/// traceability and reviewability; it does **not** claim HL7 FHIR conformance
/// or clinical interoperability, and it is **not** a clinical record.
///
/// HL7 FHIR `NutritionIntake` (R5) is patient-centric (`subject` → Patient).
/// This view DELIBERATELY OMITS `subject`, patient identifiers, encounter,
/// practitioner, care team, diagnosis, treatment, and any patient-record
/// semantics. It serializes only synthetic/demo meal data + provenance.
///
/// No PHI is ever emitted. The `phiPolicy` field names what is omitted; that is
/// evidence of compliance, not a violation — tests assert the absence of
/// patient-linkage *keys*, not the literal word in this policy string.
library;

/// A single food component, FHIR-inspired (≈ NutritionIntake.consumedItem),
/// PHI-free. Nutrient amounts are nullable (missing ≠ zero).
class FhirInspiredFoodComponentEntry {
  final String foodName;
  final double? amount; // portion grams when known
  final String? amountUnit; // 'g' when amount present, else null
  final String? preparationState; // null at composition level (see view doc)
  final String? basisType; // e.g. per_100g / per_serving (from amino profile)
  final String? sourceSystem; // component sourceDocId
  final List<String> sourceRefs;
  final List<String> missingFields;

  const FhirInspiredFoodComponentEntry({
    required this.foodName,
    required this.amount,
    required this.amountUnit,
    required this.preparationState,
    required this.basisType,
    required this.sourceSystem,
    required this.sourceRefs,
    required this.missingFields,
  });

  Map<String, dynamic> toJson() => {
        'food_name': foodName,
        'amount': amount,
        'amount_unit': amountUnit,
        'preparation_state': preparationState,
        'basis_type': basisType,
        'source_system': sourceSystem,
        'source_refs': sourceRefs,
        'missing_fields': missingFields,
      };
}

/// Meal-level nutrient summary (≈ NutritionIntake.ingredientLabel), PHI-free.
/// All values nullable; `missingness` records which were absent (never 0).
class FhirInspiredNutrientSummary {
  final double? energyKcal;
  final double? proteinG;
  final double? fatG;
  final double? carbohydrateG;
  final double? fiberG;
  final Map<String, bool> missingness;
  final Map<String, String> unit;
  final String basis;

  const FhirInspiredNutrientSummary({
    required this.energyKcal,
    required this.proteinG,
    required this.fatG,
    required this.carbohydrateG,
    required this.fiberG,
    required this.missingness,
    required this.unit,
    required this.basis,
  });

  Map<String, dynamic> toJson() => {
        'energy_kcal': energyKcal,
        'protein_g': proteinG,
        'fat_g': fatG,
        'carbohydrate_g': carbohydrateG,
        'fiber_g': fiberG,
        'missingness': missingness,
        'unit': unit,
        'basis': basis,
      };
}

/// Amino-acid provenance summary, PHI-free. Reflects the actual-fields LNAA
/// data and FDC derivation provenance when present; null/`none` otherwise
/// (missing ≠ a confident value).
class FhirInspiredAminoAcidSummary {
  final String aminoAcidDataMode; // e.g. actualAminoAcidFields / none
  final List<String> aminoAcidNutrientIds;
  final String? aminoAcidConfidenceTier; // weakest-wins tier name, or null
  final double? competingLnaaGrams; // summed across components, nullable
  final Map<String, double?> lnaaValues; // summed per-acid (nullable entries)
  final String? fdcDataType;

  const FhirInspiredAminoAcidSummary({
    required this.aminoAcidDataMode,
    required this.aminoAcidNutrientIds,
    required this.aminoAcidConfidenceTier,
    required this.competingLnaaGrams,
    required this.lnaaValues,
    required this.fdcDataType,
  });

  Map<String, dynamic> toJson() => {
        'amino_acid_data_mode': aminoAcidDataMode,
        'amino_acid_nutrient_ids': aminoAcidNutrientIds,
        'amino_acid_confidence_tier': aminoAcidConfidenceTier,
        'competing_lnaa_grams': competingLnaaGrams,
        'lnaa_values': lnaaValues,
        'fdc_data_type': fdcDataType,
      };
}

/// Top-level FHIR-inspired NutritionIntake view. Deterministic JSON; PHI-free.
class FhirInspiredNutritionIntakeView {
  /// Constant view-type marker.
  static const String kViewType = 'fhir_inspired_nutrition_intake';

  /// Constant conformance marker — inspired, NOT FHIR-conformant.
  static const String kConformanceStatus = 'inspired_not_conformant';

  /// Constant PHI policy — subject/patient linkage omitted, no PHI.
  static const String kPhiPolicy = 'subject_omitted_no_phi';

  final String demoMealId;
  final int? relativeTimeMinutes; // optional; no absolute/real timeline
  final List<FhirInspiredFoodComponentEntry> foodComponents;
  final FhirInspiredNutrientSummary nutrientSummary;
  final FhirInspiredAminoAcidSummary aminoAcidSummary;
  final List<String> missingFields;
  final List<String> sourceRefs;
  final String provenanceSummary;
  final bool notClinicallyCalibrated;
  final String notAdviceText;
  final String safetyBoundary;

  const FhirInspiredNutritionIntakeView({
    required this.demoMealId,
    required this.relativeTimeMinutes,
    required this.foodComponents,
    required this.nutrientSummary,
    required this.aminoAcidSummary,
    required this.missingFields,
    required this.sourceRefs,
    required this.provenanceSummary,
    required this.notClinicallyCalibrated,
    required this.notAdviceText,
    required this.safetyBoundary,
  });

  Map<String, dynamic> toJson() => {
        'view_type': kViewType,
        'conformance_status': kConformanceStatus,
        'phi_policy': kPhiPolicy,
        'demo_meal_id': demoMealId,
        'relative_time_minutes': relativeTimeMinutes,
        'food_components':
            foodComponents.map((e) => e.toJson()).toList(growable: false),
        'nutrient_summary': nutrientSummary.toJson(),
        'amino_acid_summary': aminoAcidSummary.toJson(),
        'missing_fields': missingFields,
        'source_refs': sourceRefs,
        'provenance_summary': provenanceSummary,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'not_advice_text': notAdviceText,
        'safety_boundary': safetyBoundary,
      };
}
