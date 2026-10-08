import '../../core/constants/reference_food_composition_table.dart';
import '../entities/meal_composition.dart';
import '../entities/reference_food_composition.dart';

/// Deterministic food-composition interdependency layer.
///
/// Food composition values are not independent numbers. This layer makes the
/// dependencies explicit and inspectable:
///
/// 1. Definitional identities inside one record: energy follows from the
///    macronutrients (plus alcohol / organic acids when present), protein +
///    fat + carbohydrate by difference cannot exceed 100 g/100 g, fibre is a
///    part of carbohydrate by difference, salt is derived from sodium, and
///    "carbohydrate" means different things in different databases.
/// 2. Derivations between records: cooked foods are the raw food plus or minus
///    water, dried fruit is fresh fruit minus water, juice is fruit minus most
///    fibre, and a whole egg is its white plus its yolk. Protein is used as a
///    conserved tracer to infer the mass ratio and test the other nutrients.
/// 3. Meal-level co-consumption: food-borne L-dopa (Vicia faba, Mucuna) is a
///    second dopaminergic precursor exposure the levodopa model does not
///    represent; an unstated dry-versus-cooked state makes a logged protein
///    amount uncertain by a factor of 2–5; and co-consumed calcium,
///    polyphenol beverages, vitamin C and heme sources are documented
///    modulators of non-heme iron absorption.
///
/// Educational prototype only. Outputs are consistency findings and
/// uncertainty context. They never prescribe food choices, timing, or doses,
/// and food-borne L-dopa is never converted into a medicine-equivalent dose.
class FoodCompositionInterdependencyModel {
  const FoodCompositionInterdependencyModel();

  static const String modelVersion = 'food_composition_interdependency.v1';

  static const List<String> identitySourceRefs = [
    'src.fao.food_energy.2003',
    'src.usda.sr_legacy.2018',
    'src.eu.reg1169.salt_factor',
  ];

  static const List<String> intrinsicLevodopaSourceRefs = [
    'src.duan.faba_ldopa_thermal.2021',
    'src.tesoro.faba_pod_ldopa.2024',
    'src.aureli.mucuna_ldopa.2025',
    'src.contin.mucuna_pk.2015',
  ];

  static const List<String> preparationStateSourceRefs = [
    'src.usda.sr_legacy.2018',
  ];

  static const List<String> ironContextSourceRefs = [
    'src.hallberg.calcium_iron.1991',
    'src.zijp.tea_iron.2000',
    'src.cook_reddy.ascorbate_iron.2001',
    'src.campbell.ferrous_sulfate_levodopa.1989',
  ];

  /// Assess one normalized meal composition for interdependency findings
  /// that affect how far the mechanistic levodopa trace can be trusted.
  FoodInterdependencyAssessment assessMeal(MealComposition composition) {
    final components = [...composition.foodComponents]
      ..sort((a, b) => a.id.compareTo(b.id));
    final levodopa = <IntrinsicLevodopaMatch>[];
    final ambiguities = <PreparationStateAmbiguityMatch>[];
    final energyFindings = <ComponentEnergyFinding>[];
    for (final component in components) {
      final reference = resolveReferenceRow(
        componentId: component.id,
        name: component.name,
      );
      final source = matchIntrinsicLevodopaSource(
        name: component.name,
        componentId: component.id,
        reference: reference,
      );
      if (source != null) {
        levodopa.add(
          IntrinsicLevodopaMatch(
            componentId: component.id,
            componentName: component.name,
            source: source.source,
            matchedBy: source.matchedBy,
          ),
        );
      }
      final ambiguity = detectPreparationStateAmbiguity(component.name);
      if (ambiguity != null &&
          !ambiguity.isResolvedByProteinDensity(
            proteinGrams: component.proteinGrams,
            portionGrams: component.portionGrams,
          )) {
        ambiguities.add(
          PreparationStateAmbiguityMatch(
            componentId: component.id,
            componentName: component.name,
            ambiguity: ambiguity,
          ),
        );
      }
      final energy = reconcileEnergy(
        reportedKcal: component.calories,
        proteinG: component.proteinGrams,
        fatG: component.fatGrams,
        carbohydrateG: component.carbohydrateGrams,
        fiberG: component.fiberGrams,
        // FoodComponent carbohydrate follows the local catalog convention
        // (available carbohydrate); the reconciliation also tests the
        // by-difference reading so a mislabelled convention is not flagged.
        convention: CarbohydrateConvention.availableExcludingFiber,
        nonMacronutrientEnergyHint: nonMacronutrientEnergyHintFor(
          component.name,
          reference: reference,
        ),
        scaleGrams: component.portionGrams,
      );
      if (energy.status == EnergyReconciliationStatus.inconsistent) {
        energyFindings.add(
          ComponentEnergyFinding(
            componentId: component.id,
            componentName: component.name,
            reconciliation: energy,
          ),
        );
      }
    }
    return FoodInterdependencyAssessment(
      compositionId: composition.id,
      intrinsicLevodopaSources: List.unmodifiable(levodopa),
      preparationStateAmbiguities: List.unmodifiable(ambiguities),
      componentEnergyInconsistencies: List.unmodifiable(energyFindings),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Definitional identities
// ---------------------------------------------------------------------------

/// FAO Food and Nutrition Paper 77 general energy conversion factors.
const double kcalPerGramProtein = 4.0;
const double kcalPerGramFat = 9.0;
const double kcalPerGramAvailableCarbohydrate = 4.0;
const double kcalPerGramFiber = 2.0;
const double kcalPerGramAlcohol = 7.0;
const double kcalPerGramOrganicAcid = 3.0;

/// Tolerance for general-factor energy checks. Data sets use food-specific
/// factors, so the band is deliberately wide: max(15 kcal per 100 g, 12%).
const double energyToleranceAbsoluteKcalPer100g = 15.0;
const double energyToleranceRelative = 0.12;

/// Minimum absolute tolerance for any serving. Label values are rounded
/// (energy to 5–10 kcal, macronutrients to 0.5–1 g), which alone can move a
/// small serving's macronutrient energy by about 10 kcal.
const double energyToleranceLabelRoundingFloorKcal = 10.0;

/// EU Regulation (EU) No 1169/2011, Annex I(11): salt = sodium × 2.5.
const double sodiumToSaltFactor = 2.5;

double? saltEquivalentFromSodiumMg(double? sodiumMg) {
  if (sodiumMg == null || !sodiumMg.isFinite || sodiumMg < 0) return null;
  return sodiumMg * sodiumToSaltFactor / 1000.0;
}

/// Converts between carbohydrate conventions. Returns null (abstains) when the
/// conversion needs a fibre value that is missing, when either convention is
/// unverified, or when inputs are not finite non-negative numbers. A rounding
/// residue down to −0.05 g is clamped to zero; a materially negative
/// available carbohydrate returns null because the source data disagree.
double? convertCarbohydrate({
  required double? value,
  required double? fiberG,
  required CarbohydrateConvention from,
  required CarbohydrateConvention to,
}) {
  if (value == null || !value.isFinite || value < 0) return null;
  if (from == CarbohydrateConvention.unverified ||
      to == CarbohydrateConvention.unverified) {
    return null;
  }
  if (from == to) return value;
  if (fiberG == null || !fiberG.isFinite || fiberG < 0) return null;
  if (from == CarbohydrateConvention.byDifferenceIncludingFiber) {
    final available = value - fiberG;
    if (available < -0.05) return null;
    return available < 0 ? 0.0 : available;
  }
  return value + fiberG;
}

/// Available carbohydrate of a reference row, harmonised to the convention of
/// the local catalog (CIQUAL "Glucides").
double? availableCarbohydrateOf(ReferenceFoodCompositionRow row) =>
    convertCarbohydrate(
      value: row.carbohydrateByDifferenceG,
      fiberG: row.fiberG,
      from: ReferenceFoodCompositionRow.carbohydrateConvention,
      to: CarbohydrateConvention.availableExcludingFiber,
    );

enum NonMacronutrientEnergyHint { none, alcohol, organicAcids }

enum EnergyReconciliationStatus {
  consistent,
  explainedByAlcohol,
  explainedByOrganicAcids,
  inconsistent,
  insufficientData,
}

final class EnergyReconciliation {
  final EnergyReconciliationStatus status;
  final double? reportedKcal;

  /// 4/9/4 kcal/g with fibre counted as carbohydrate.
  final double? generalFactorKcal;

  /// 4/9/4 kcal/g on available carbohydrate plus 2 kcal/g fibre.
  final double? fiberAdjustedKcal;

  /// reported − closest macronutrient estimate.
  final double? residualKcal;
  final double toleranceKcal;

  /// Ethanol mass implied by the residual (7 kcal/g); set only when the
  /// residual is explained by alcohol.
  final double? impliedAlcoholG;

  /// Organic-acid mass implied by the residual (~3 kcal/g).
  final double? impliedOrganicAcidG;

  const EnergyReconciliation({
    required this.status,
    required this.reportedKcal,
    required this.generalFactorKcal,
    required this.fiberAdjustedKcal,
    required this.residualKcal,
    required this.toleranceKcal,
    this.impliedAlcoholG,
    this.impliedOrganicAcidG,
  });

  Map<String, Object?> toJson() => {
    'status': status.name,
    'reported_kcal': reportedKcal,
    'general_factor_kcal': generalFactorKcal,
    'fiber_adjusted_kcal': fiberAdjustedKcal,
    'residual_kcal': residualKcal,
    'tolerance_kcal': toleranceKcal,
    'implied_alcohol_g': impliedAlcoholG,
    'implied_organic_acid_g': impliedOrganicAcidG,
  };
}

/// Reconciles reported energy with the macronutrients that should produce it.
///
/// [scaleGrams] is the food mass the values refer to (100 for per-100 g
/// records, the portion for a serving); it scales the absolute tolerance.
/// When null the per-100 g absolute tolerance is used.
EnergyReconciliation reconcileEnergy({
  required double? reportedKcal,
  required double? proteinG,
  required double? fatG,
  required double? carbohydrateG,
  required double? fiberG,
  required CarbohydrateConvention convention,
  NonMacronutrientEnergyHint nonMacronutrientEnergyHint =
      NonMacronutrientEnergyHint.none,
  double? scaleGrams,
}) {
  bool valid(double? v) => v != null && v.isFinite && v >= 0;
  final scale = scaleGrams != null && scaleGrams.isFinite && scaleGrams > 0
      ? scaleGrams / 100.0
      : 1.0;
  final reported = reportedKcal;
  final absoluteFloor =
      energyToleranceAbsoluteKcalPer100g * scale >
          energyToleranceLabelRoundingFloorKcal
      ? energyToleranceAbsoluteKcalPer100g * scale
      : energyToleranceLabelRoundingFloorKcal;
  final tolerance = reported != null && reported.isFinite
      ? (energyToleranceRelative * reported > absoluteFloor
            ? energyToleranceRelative * reported
            : absoluteFloor)
      : absoluteFloor;
  if (!valid(reported) ||
      !valid(proteinG) ||
      !valid(fatG) ||
      !valid(carbohydrateG) ||
      convention == CarbohydrateConvention.unverified) {
    return EnergyReconciliation(
      status: EnergyReconciliationStatus.insufficientData,
      reportedKcal: reported,
      generalFactorKcal: null,
      fiberAdjustedKcal: null,
      residualKcal: null,
      toleranceKcal: tolerance,
    );
  }
  final fiber = valid(fiberG) ? fiberG! : null;
  final proteinFat = kcalPerGramProtein * proteinG! + kcalPerGramFat * fatG!;
  final candidates = <double>[];
  double? general;
  double? fiberAdjusted;
  if (convention == CarbohydrateConvention.byDifferenceIncludingFiber) {
    general = proteinFat + kcalPerGramAvailableCarbohydrate * carbohydrateG!;
    candidates.add(general);
    if (fiber != null) {
      final available = (carbohydrateG - fiber).clamp(0.0, double.infinity);
      fiberAdjusted =
          proteinFat +
          kcalPerGramAvailableCarbohydrate * available +
          kcalPerGramFiber * fiber;
      candidates.add(fiberAdjusted);
    }
  } else {
    // Available-carbohydrate convention; fibre (when present) adds 2 kcal/g.
    fiberAdjusted =
        proteinFat +
        kcalPerGramAvailableCarbohydrate * carbohydrateG! +
        kcalPerGramFiber * (fiber ?? 0.0);
    candidates.add(fiberAdjusted);
    if (fiber != null) {
      general =
          proteinFat +
          kcalPerGramAvailableCarbohydrate * (carbohydrateG + fiber);
      candidates.add(general);
    }
    // A source that actually reported by-difference carbohydrate under the
    // available label would double count fibre; accept that reading too so
    // the mislabel is not reported as an energy inconsistency.
    candidates.add(
      proteinFat + kcalPerGramAvailableCarbohydrate * carbohydrateG,
    );
  }
  var closest = candidates.first;
  for (final candidate in candidates) {
    if ((reported! - candidate).abs() < (reported - closest).abs()) {
      closest = candidate;
    }
  }
  final residual = reported! - closest;
  if (residual.abs() <= tolerance) {
    return EnergyReconciliation(
      status: EnergyReconciliationStatus.consistent,
      reportedKcal: reported,
      generalFactorKcal: general,
      fiberAdjustedKcal: fiberAdjusted,
      residualKcal: residual,
      toleranceKcal: tolerance,
    );
  }
  if (residual > 0 &&
      nonMacronutrientEnergyHint == NonMacronutrientEnergyHint.alcohol) {
    return EnergyReconciliation(
      status: EnergyReconciliationStatus.explainedByAlcohol,
      reportedKcal: reported,
      generalFactorKcal: general,
      fiberAdjustedKcal: fiberAdjusted,
      residualKcal: residual,
      toleranceKcal: tolerance,
      impliedAlcoholG: residual / kcalPerGramAlcohol,
    );
  }
  if (residual > 0 &&
      nonMacronutrientEnergyHint == NonMacronutrientEnergyHint.organicAcids) {
    return EnergyReconciliation(
      status: EnergyReconciliationStatus.explainedByOrganicAcids,
      reportedKcal: reported,
      generalFactorKcal: general,
      fiberAdjustedKcal: fiberAdjusted,
      residualKcal: residual,
      toleranceKcal: tolerance,
      impliedOrganicAcidG: residual / kcalPerGramOrganicAcid,
    );
  }
  return EnergyReconciliation(
    status: EnergyReconciliationStatus.inconsistent,
    reportedKcal: reported,
    generalFactorKcal: general,
    fiberAdjustedKcal: fiberAdjusted,
    residualKcal: residual,
    toleranceKcal: tolerance,
  );
}

final RegExp _alcoholCue = RegExp(
  r'(?<![a-z])(wine|beer|ale|lager|cider|sake|spirits?|vodka|whiske?y|rum|gin|brandy|liqueur|soju|baijiu|alcoholic)(?![a-z])',
);
const List<String> _alcoholCjkCues = ['酒', '啤酒', '清酒', '烧酒'];
final RegExp _organicAcidCue = RegExp(r'(?<![a-z])vinegar(?![a-z])');
const List<String> _organicAcidCjkCues = ['醋'];

/// Hint for energy that is not carried by protein, fat or carbohydrate.
NonMacronutrientEnergyHint nonMacronutrientEnergyHintFor(
  String name, {
  ReferenceFoodCompositionRow? reference,
}) {
  if (reference?.group == ReferenceFoodGroup.alcoholicBeverage) {
    return NonMacronutrientEnergyHint.alcohol;
  }
  final lower = name.toLowerCase();
  // "Vinegar" wins over "wine"/"cider" (wine vinegar, cider vinegar).
  if (_organicAcidCue.hasMatch(lower) ||
      _organicAcidCjkCues.any(name.contains)) {
    return NonMacronutrientEnergyHint.organicAcids;
  }
  if (_alcoholCue.hasMatch(lower) || _alcoholCjkCues.any(name.contains)) {
    return NonMacronutrientEnergyHint.alcohol;
  }
  return NonMacronutrientEnergyHint.none;
}

/// One identity finding for a reference record.
final class NutrientIdentityFinding {
  final String code;
  final String detail;

  const NutrientIdentityFinding(this.code, this.detail);

  Map<String, Object?> toJson() => {'code': code, 'detail': detail};
}

final class NutrientIdentityAudit {
  final int fdcId;
  final EnergyReconciliation energy;
  final List<NutrientIdentityFinding> findings;

  const NutrientIdentityAudit({
    required this.fdcId,
    required this.energy,
    required this.findings,
  });

  /// True when no identity is violated. Energy explained by alcohol or
  /// organic acids is consistent: the record carries energy that the
  /// macronutrient columns do not represent.
  bool get isConsistent => findings.isEmpty;
}

/// Audits the definitional identities of one reference record.
NutrientIdentityAudit auditReferenceRow(ReferenceFoodCompositionRow row) {
  final findings = <NutrientIdentityFinding>[];
  final energy = reconcileEnergy(
    reportedKcal: row.energyKcal,
    proteinG: row.proteinG,
    fatG: row.fatG,
    carbohydrateG: row.carbohydrateByDifferenceG,
    fiberG: row.fiberG,
    convention: ReferenceFoodCompositionRow.carbohydrateConvention,
    nonMacronutrientEnergyHint: nonMacronutrientEnergyHintFor(
      row.sourceDescription,
      reference: row,
    ),
  );
  if (energy.status == EnergyReconciliationStatus.inconsistent) {
    findings.add(
      NutrientIdentityFinding(
        'energy_macronutrient_residual',
        'reported ${row.energyKcal} kcal; residual '
            '${energy.residualKcal!.toStringAsFixed(1)} kcal exceeds '
            '${energy.toleranceKcal.toStringAsFixed(1)} kcal',
      ),
    );
  }
  final protein = row.proteinG;
  final fat = row.fatG;
  final carbohydrate = row.carbohydrateByDifferenceG;
  if (protein != null && fat != null && carbohydrate != null) {
    final total = protein + fat + carbohydrate;
    if (total > 100.5) {
      findings.add(
        NutrientIdentityFinding(
          'proximate_closure_exceeded',
          'protein + fat + carbohydrate = ${total.toStringAsFixed(2)} g/100 g',
        ),
      );
    }
  }
  final fiber = row.fiberG;
  if (fiber != null && carbohydrate != null && fiber > carbohydrate + 0.05) {
    findings.add(
      NutrientIdentityFinding(
        'fiber_exceeds_carbohydrate_by_difference',
        'fibre $fiber g > carbohydrate by difference $carbohydrate g',
      ),
    );
  }
  return NutrientIdentityAudit(
    fdcId: row.fdcId,
    energy: energy,
    findings: List.unmodifiable(findings),
  );
}

// ---------------------------------------------------------------------------
// Composition identity audit for imported records
// ---------------------------------------------------------------------------

/// Ethanol energy used by USDA food-specific energy calculations
/// (Merrill & Watt, Agriculture Handbook No. 74, 1973).
const double kcalPerGramAlcoholHandbook74 = 6.93;

/// kJ per thermochemical kcal.
const double kilojoulesPerKilocalorie = 4.184;

/// Atwater factors applied to one food (FDC `.CalorieConversionFactor`).
final class FoodSpecificCalorieFactors {
  final double? proteinKcalPerG;
  final double? fatKcalPerG;
  final double? carbohydrateKcalPerG;

  const FoodSpecificCalorieFactors({
    this.proteinKcalPerG,
    this.fatKcalPerG,
    this.carbohydrateKcalPerG,
  });

  Map<String, Object?> toJson() => {
    'protein_kcal_per_g': proteinKcalPerG,
    'fat_kcal_per_g': fatKcalPerG,
    'carbohydrate_kcal_per_g': carbohydrateKcalPerG,
  };
}

/// One imported food record, keyed by local attribute code
/// (`energy_kcal`, `protein_g`, `iron_heme_mg`, ...). Only exact, finite,
/// non-negative values belong here; unknown values are simply absent.
final class FoodCompositionIdentityInput {
  final String recordId;
  final String description;
  final Map<String, double> values;

  /// FDC `.ProteinConversionFactor` (nitrogen-to-protein), when reported.
  final double? nitrogenToProteinFactor;
  final FoodSpecificCalorieFactors? calorieFactors;

  const FoodCompositionIdentityInput({
    required this.recordId,
    required this.description,
    required this.values,
    this.nitrogenToProteinFactor,
    this.calorieFactors,
  });
}

final class CompositionIdentityAudit {
  final String recordId;

  /// Identity checks that had enough data to run.
  final List<String> checksRun;
  final List<NutrientIdentityFinding> findings;

  /// Energy reconciliation with general factors, when it could run.
  final EnergyReconciliation? generalEnergy;

  const CompositionIdentityAudit({
    required this.recordId,
    required this.checksRun,
    required this.findings,
    required this.generalEnergy,
  });

  bool get isConsistent => findings.isEmpty;

  Map<String, Object?> toJson() => {
    'record_id': recordId,
    'checks_run': checksRun,
    'findings': [for (final finding in findings) finding.toJson()],
    if (generalEnergy != null) 'general_energy': generalEnergy!.toJson(),
  };
}

double _tolerance(double reference, double absolute, double relative) {
  final relativeTolerance = reference.abs() * relative;
  return relativeTolerance > absolute ? relativeTolerance : absolute;
}

/// Audits the definitional identities among one record's nutrients.
///
/// Every identity below follows from how the values are defined, not from
/// typical composition, so a violation means a transcription, unit, basis or
/// definition error in the record (or a source-documented exception), never a
/// statement about a person. Findings are recorded; values are not changed.
///
/// - Energy with general factors (FAO 2003), and with food-specific
///   Atwater factors when the source reports them (Merrill & Watt 1973).
/// - kJ = 4.184 × kcal.
/// - Protein = nitrogen × the reported nitrogen-to-protein factor.
/// - Carbohydrate by difference = 100 − water − protein − fat − ash
///   (− alcohol).
/// - Parts never exceed their whole: fibre, sugars and starch within
///   carbohydrate by difference; added within total sugars; fatty-acid
///   classes within total lipid; NLEA fat within total lipid.
/// - Heme + non-heme iron = total iron.
/// - Vitamin A RAE ≥ retinol + β-carotene/12; folate DFE ≥ total folate.
CompositionIdentityAudit auditCompositionIdentities(
  FoodCompositionIdentityInput input,
) {
  final v = input.values;
  final checks = <String>[];
  final findings = <NutrientIdentityFinding>[];
  String fmt(double value) => value.toStringAsFixed(2);

  void finding(String code, String detail) =>
      findings.add(NutrientIdentityFinding(code, detail));

  // Energy with general factors (any reported energy must fall within the
  // general-factor tolerance; Foundation records may report only 2047/2048).
  final reportedKcal =
      v['energy_kcal'] ??
      v['energy_atwater_general_kcal'] ??
      v['energy_atwater_specific_kcal'];
  final byDifference = v['carbohydrate_by_difference_g'];
  final available = v['carbohydrate_g'];
  EnergyReconciliation? generalEnergy;
  if (reportedKcal != null && (byDifference != null || available != null)) {
    checks.add('energy_general_factors');
    generalEnergy = reconcileEnergy(
      reportedKcal: reportedKcal,
      proteinG: v['protein_g'],
      fatG: v['fat_g'],
      carbohydrateG: byDifference ?? available,
      fiberG: v['fiber_g'],
      convention: byDifference != null
          ? CarbohydrateConvention.byDifferenceIncludingFiber
          : CarbohydrateConvention.availableExcludingFiber,
      nonMacronutrientEnergyHint: (v['alcohol_g'] ?? 0) > 0
          ? NonMacronutrientEnergyHint.alcohol
          : nonMacronutrientEnergyHintFor(input.description),
    );
    if (generalEnergy.status == EnergyReconciliationStatus.inconsistent) {
      finding(
        'energy_general_factor_residual',
        'reported ${fmt(reportedKcal)} kcal; residual '
            '${fmt(generalEnergy.residualKcal!)} kcal exceeds '
            '${fmt(generalEnergy.toleranceKcal)} kcal',
      );
    }
  }

  // Energy with food-specific factors (applied to carbohydrate by
  // difference, as in USDA calculations).
  final factors = input.calorieFactors;
  final specificReported =
      v['energy_atwater_specific_kcal'] ?? v['energy_kcal'];
  if (factors != null && specificReported != null) {
    final protein = v['protein_g'];
    final fat = v['fat_g'];
    final carbohydrate = byDifference ?? 0.0;
    final carbohydrateFactor = factors.carbohydrateKcalPerG;
    final canRun =
        protein != null &&
        fat != null &&
        factors.proteinKcalPerG != null &&
        factors.fatKcalPerG != null &&
        (carbohydrate <= 0.0 || carbohydrateFactor != null);
    if (canRun) {
      checks.add('energy_specific_factors');
      final calculated =
          factors.proteinKcalPerG! * protein +
          factors.fatKcalPerG! * fat +
          (carbohydrate > 0 ? carbohydrateFactor! * carbohydrate : 0.0) +
          kcalPerGramAlcoholHandbook74 * (v['alcohol_g'] ?? 0.0);
      final residual = specificReported - calculated;
      final tolerance = _tolerance(specificReported, 2.0, 0.02);
      if (residual.abs() > tolerance) {
        finding(
          'energy_specific_factor_residual',
          'reported ${fmt(specificReported)} kcal; food-specific factors give '
              '${fmt(calculated)} kcal (tolerance ${fmt(tolerance)} kcal)',
        );
      }
    }
  }

  // kJ / kcal.
  final kj = v['energy_kj'];
  final kcal = v['energy_kcal'];
  if (kj != null && kcal != null) {
    checks.add('energy_kj_kcal');
    final expected = kilojoulesPerKilocalorie * kcal;
    final tolerance = _tolerance(expected, 3.0, 0.005);
    if ((kj - expected).abs() > tolerance) {
      finding(
        'energy_kj_kcal_mismatch',
        '${fmt(kj)} kJ vs ${fmt(kcal)} kcal × 4.184 = ${fmt(expected)} kJ',
      );
    }
  }

  // Nitrogen × factor = protein.
  final nitrogen = v['nitrogen_g'];
  final proteinFactor = input.nitrogenToProteinFactor;
  final protein = v['protein_g'];
  if (nitrogen != null &&
      protein != null &&
      proteinFactor != null &&
      proteinFactor > 0) {
    checks.add('nitrogen_protein_factor');
    final expected = nitrogen * proteinFactor;
    final tolerance = _tolerance(expected, 0.05, 0.015);
    if ((protein - expected).abs() > tolerance) {
      finding(
        'nitrogen_protein_factor_mismatch',
        'protein ${fmt(protein)} g vs nitrogen ${fmt(nitrogen)} g × '
            '$proteinFactor = ${fmt(expected)} g',
      );
    }
  }

  // Carbohydrate by difference closes the proximate composition.
  final water = v['water_g'];
  final fat = v['fat_g'];
  final ash = v['ash_g'];
  if (water != null &&
      protein != null &&
      fat != null &&
      ash != null &&
      byDifference != null) {
    checks.add('proximate_closure');
    final total =
        water + protein + fat + ash + byDifference + (v['alcohol_g'] ?? 0.0);
    if ((total - 100.0).abs() > 0.6) {
      finding(
        'proximate_closure_mismatch',
        'water + protein + fat + ash + carbohydrate by difference'
            '${v.containsKey('alcohol_g') ? ' + alcohol' : ''} = '
            '${fmt(total)} g/100 g',
      );
    }
  }

  void partWithinWhole(
    String check,
    String part,
    String whole, {
    double absolute = 0.05,
    double relative = 0.01,
  }) {
    final partValue = v[part];
    final wholeValue = v[whole];
    if (partValue == null || wholeValue == null) return;
    checks.add(check);
    if (partValue > wholeValue + _tolerance(wholeValue, absolute, relative)) {
      finding(
        '${check}_exceeded',
        '$part ${fmt(partValue)} > $whole ${fmt(wholeValue)}',
      );
    }
  }

  partWithinWhole(
    'fiber_within_carbohydrate',
    'fiber_g',
    'carbohydrate_by_difference_g',
  );
  partWithinWhole(
    'aoac_2011_25_fiber_within_carbohydrate',
    'fiber_aoac_2011_25_g',
    'carbohydrate_by_difference_g',
  );
  partWithinWhole(
    'sugars_within_carbohydrate',
    'sugars_total_g',
    'carbohydrate_by_difference_g',
  );
  partWithinWhole(
    'starch_within_carbohydrate',
    'starch_g',
    'carbohydrate_by_difference_g',
  );
  partWithinWhole(
    'added_within_total_sugars',
    'sugars_added_g',
    'sugars_total_g',
  );
  partWithinWhole('nlea_fat_within_total_lipid', 'fat_nlea_g', 'fat_g');

  final sugars = v['sugars_total_g'];
  final starch = v['starch_g'];
  final fiber = v['fiber_g'];
  if (sugars != null &&
      starch != null &&
      fiber != null &&
      byDifference != null) {
    checks.add('carbohydrate_fractions_within_total');
    final sum = sugars + starch + fiber;
    if (sum > byDifference + _tolerance(byDifference, 0.5, 0.03)) {
      finding(
        'carbohydrate_fractions_within_total_exceeded',
        'sugars + starch + fibre ${fmt(sum)} g > carbohydrate by difference '
            '${fmt(byDifference)} g',
      );
    }
  }

  final saturated = v['fatty_acids_saturated_g'];
  final mono = v['fatty_acids_monounsaturated_g'];
  final poly = v['fatty_acids_polyunsaturated_g'];
  if (saturated != null && mono != null && poly != null && fat != null) {
    checks.add('fatty_acids_within_total_lipid');
    final sum = saturated + mono + poly;
    if (sum > fat + _tolerance(fat, 0.1, 0.02)) {
      finding(
        'fatty_acids_within_total_lipid_exceeded',
        'saturated + monounsaturated + polyunsaturated ${fmt(sum)} g > total '
            'lipid ${fmt(fat)} g',
      );
    }
  }

  final iron = v['iron_mg'];
  final heme = v['iron_heme_mg'];
  final nonHeme = v['iron_non_heme_mg'];
  if (iron != null && heme != null && nonHeme != null) {
    checks.add('heme_plus_non_heme_iron');
    final sum = heme + nonHeme;
    if ((sum - iron).abs() > _tolerance(iron, 0.05, 0.03)) {
      finding(
        'heme_plus_non_heme_iron_mismatch',
        'heme ${fmt(heme)} + non-heme ${fmt(nonHeme)} mg ≠ total iron '
            '${fmt(iron)} mg',
      );
    }
  }

  final rae = v['vitamin_a_rae_ug'];
  final retinol = v['retinol_ug'];
  if (rae != null && retinol != null) {
    checks.add('vitamin_a_rae_lower_bound');
    final lowerBound = retinol + (v['beta_carotene_ug'] ?? 0.0) / 12.0;
    if (rae + _tolerance(lowerBound, 1.0, 0.02) < lowerBound) {
      finding(
        'vitamin_a_rae_below_components',
        'RAE ${fmt(rae)} µg < retinol + β-carotene/12 = ${fmt(lowerBound)} µg',
      );
    }
  }

  final dfe = v['folate_dfe_ug'];
  final folate = v['folate_total_ug'];
  if (dfe != null && folate != null) {
    checks.add('folate_dfe_lower_bound');
    if (dfe + _tolerance(folate, 1.0, 0.02) < folate) {
      finding(
        'folate_dfe_below_total_folate',
        'DFE ${fmt(dfe)} µg < total folate ${fmt(folate)} µg',
      );
    }
  }

  return CompositionIdentityAudit(
    recordId: input.recordId,
    checksRun: List.unmodifiable(checks),
    findings: List.unmodifiable(findings),
    generalEnergy: generalEnergy,
  );
}

// ---------------------------------------------------------------------------
// Cross-source comparison (definition-aware)
// ---------------------------------------------------------------------------

enum CrossSourceAgreement {
  agree,
  differWithinExpectedVariation,
  materialDifference,
  notComparable,
}

final class CrossSourceComparison {
  final String nutrient;
  final double? leftValue;
  final double? rightValue;
  final double? relativeDifference;
  final CrossSourceAgreement agreement;
  final String note;

  const CrossSourceComparison({
    required this.nutrient,
    required this.leftValue,
    required this.rightValue,
    required this.relativeDifference,
    required this.agreement,
    required this.note,
  });
}

/// Compares two observations of the same nutrient for nominally the same
/// food. Below [absoluteFloor] grams differences are treated as agreement
/// because rounding and detection limits dominate. Natural variation between
/// samples, cultivars and preparations is expected; only differences above
/// [materialRelative] are called material.
CrossSourceComparison compareCrossSource({
  required String nutrient,
  required double? left,
  required double? right,
  double absoluteFloor = 0.5,
  double expectedRelative = 0.15,
  double materialRelative = 0.35,
}) {
  if (left == null || right == null || !left.isFinite || !right.isFinite) {
    return CrossSourceComparison(
      nutrient: nutrient,
      leftValue: left,
      rightValue: right,
      relativeDifference: null,
      agreement: CrossSourceAgreement.notComparable,
      note: 'one side has no reported value',
    );
  }
  final diff = (left - right).abs();
  final base = left.abs() > right.abs() ? left.abs() : right.abs();
  final relative = base == 0 ? 0.0 : diff / base;
  final CrossSourceAgreement agreement;
  if (diff <= absoluteFloor || relative <= expectedRelative) {
    agreement = CrossSourceAgreement.agree;
  } else if (relative <= materialRelative) {
    agreement = CrossSourceAgreement.differWithinExpectedVariation;
  } else {
    agreement = CrossSourceAgreement.materialDifference;
  }
  return CrossSourceComparison(
    nutrient: nutrient,
    leftValue: left,
    rightValue: right,
    relativeDifference: relative,
    agreement: agreement,
    note: agreement == CrossSourceAgreement.materialDifference
        ? 'difference exceeds typical sample-to-sample variation; verify the '
              'record, its preparation state and its definitions'
        : 'within the comparison band',
  );
}

// ---------------------------------------------------------------------------
// 2. Derivations between foods
// ---------------------------------------------------------------------------

enum FoodDerivationKind {
  /// Dry grain/legume/pasta absorbs water during boiling.
  hydrationCooking,

  /// Meat, fish or tubers lose water (and sometimes fat) when cooked.
  moistureLossCooking,

  /// Leafy/green vegetables boiled and drained; mass roughly preserved.
  vegetableBoiling,

  /// Fresh fruit dried to a lower moisture content.
  dehydration,

  /// Juice pressed from whole fruit; most fibre stays in the pulp.
  juiceExtraction,

  /// Same food with added salt and nothing else changed.
  saltAddition,
}

final class FoodDerivationEdge {
  final String id;
  final int parentFdcId;
  final int childFdcId;
  final FoodDerivationKind kind;

  /// Nutrients expected to scale with the protein tracer within
  /// [relativeTolerance]. Nutrients not listed are reported but not tested.
  final List<String> coherentNutrients;
  final double relativeTolerance;
  final String note;

  const FoodDerivationEdge({
    required this.id,
    required this.parentFdcId,
    required this.childFdcId,
    required this.kind,
    required this.coherentNutrients,
    required this.relativeTolerance,
    required this.note,
  });
}

/// Derivation edges between records of the reference table. Each edge was
/// selected because both records describe the same food in two states.
const List<FoodDerivationEdge> foodDerivationEdges = [
  FoodDerivationEdge(
    id: 'white_rice_long_grain.dry_to_cooked',
    parentFdcId: 169756,
    childFdcId: 169757,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Unenriched white rice boiled without salt.',
  ),
  FoodDerivationEdge(
    id: 'brown_rice_long_grain.dry_to_cooked',
    parentFdcId: 169703,
    childFdcId: 169704,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Long-grain brown rice.',
  ),
  FoodDerivationEdge(
    id: 'pasta_enriched.dry_to_cooked',
    parentFdcId: 169736,
    childFdcId: 169737,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Enriched pasta boiled without salt.',
  ),
  FoodDerivationEdge(
    id: 'lentils.dry_to_cooked',
    parentFdcId: 172420,
    childFdcId: 172421,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Mature lentils boiled without salt.',
  ),
  FoodDerivationEdge(
    id: 'split_peas.dry_to_cooked',
    parentFdcId: 172428,
    childFdcId: 172429,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Split peas boiled without salt.',
  ),
  FoodDerivationEdge(
    id: 'black_beans.dry_to_cooked',
    parentFdcId: 173734,
    childFdcId: 173735,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Black turtle beans boiled without salt.',
  ),
  FoodDerivationEdge(
    id: 'soybeans.dry_to_cooked',
    parentFdcId: 174270,
    childFdcId: 174271,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy'],
    relativeTolerance: 0.35,
    note:
        'Carbohydrate does not follow the protein tracer in this pair (ratio '
        '≈1.8× the tracer); energy agrees only within a wide band.',
  ),
  FoodDerivationEdge(
    id: 'oats.dry_to_cooked_with_water',
    parentFdcId: 173904,
    childFdcId: 173905,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Rolled oats cooked with water.',
  ),
  FoodDerivationEdge(
    id: 'spelt.dry_to_cooked',
    parentFdcId: 169745,
    childFdcId: 169746,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Spelt grain.',
  ),
  FoodDerivationEdge(
    id: 'couscous.dry_to_cooked',
    parentFdcId: 169699,
    childFdcId: 169700,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Couscous.',
  ),
  FoodDerivationEdge(
    id: 'rice_noodles.dry_to_cooked',
    parentFdcId: 169742,
    childFdcId: 168914,
    kind: FoodDerivationKind.hydrationCooking,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Rice noodles.',
  ),
  FoodDerivationEdge(
    id: 'cod_atlantic.raw_to_cooked',
    parentFdcId: 171955,
    childFdcId: 171956,
    kind: FoodDerivationKind.moistureLossCooking,
    coherentNutrients: ['energy', 'fat'],
    relativeTolerance: 0.20,
    note: 'Lean fish, dry heat.',
  ),
  FoodDerivationEdge(
    id: 'salmon_atlantic_farmed.raw_to_cooked',
    parentFdcId: 175167,
    childFdcId: 175168,
    kind: FoodDerivationKind.moistureLossCooking,
    coherentNutrients: ['energy'],
    relativeTolerance: 0.20,
    note: 'Fatty fish, dry heat.',
  ),
  FoodDerivationEdge(
    id: 'turkey_meat.raw_to_roasted',
    parentFdcId: 171480,
    childFdcId: 171481,
    kind: FoodDerivationKind.moistureLossCooking,
    coherentNutrients: ['energy'],
    relativeTolerance: 0.20,
    note: 'Meat only, roasted.',
  ),
  FoodDerivationEdge(
    id: 'pork_loin.raw_to_pan_fried',
    parentFdcId: 167889,
    childFdcId: 167892,
    kind: FoodDerivationKind.moistureLossCooking,
    coherentNutrients: ['energy', 'fat'],
    relativeTolerance: 0.20,
    note: 'Lean and fat, pan-fried.',
  ),
  FoodDerivationEdge(
    id: 'chicken_dark_meat.raw_to_roasted',
    parentFdcId: 171067,
    childFdcId: 171069,
    kind: FoodDerivationKind.moistureLossCooking,
    coherentNutrients: [],
    relativeTolerance: 0.20,
    note:
        'Protein concentrates on cooking; fat does not follow the tracer in '
        'this pair, so only the direction is tested.',
  ),
  FoodDerivationEdge(
    id: 'lamb_composite.raw_to_cooked',
    parentFdcId: 172479,
    childFdcId: 172480,
    kind: FoodDerivationKind.moistureLossCooking,
    coherentNutrients: [],
    relativeTolerance: 0.20,
    note:
        'Lean-and-fat composite; fat does not follow the protein tracer, so '
        'only the direction is tested.',
  ),
  FoodDerivationEdge(
    id: 'spinach.raw_to_boiled',
    parentFdcId: 168462,
    childFdcId: 168463,
    kind: FoodDerivationKind.vegetableBoiling,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Boiled and drained without salt.',
  ),
  FoodDerivationEdge(
    id: 'green_peas.raw_to_boiled',
    parentFdcId: 170419,
    childFdcId: 170420,
    kind: FoodDerivationKind.vegetableBoiling,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Boiled and drained without salt.',
  ),
  FoodDerivationEdge(
    id: 'broad_beans_immature.raw_to_boiled',
    parentFdcId: 170377,
    childFdcId: 170378,
    kind: FoodDerivationKind.vegetableBoiling,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.20,
    note: 'Immature Vicia faba seeds boiled and drained without salt.',
  ),
  FoodDerivationEdge(
    id: 'grapes_to_raisins.dehydration',
    parentFdcId: 174683,
    childFdcId: 168165,
    kind: FoodDerivationKind.dehydration,
    coherentNutrients: ['energy', 'carbohydrate'],
    relativeTolerance: 0.15,
    note: 'Seedless grapes and dark seedless raisins.',
  ),
  FoodDerivationEdge(
    id: 'orange_to_juice.extraction',
    parentFdcId: 169097,
    childFdcId: 169098,
    kind: FoodDerivationKind.juiceExtraction,
    coherentNutrients: [],
    relativeTolerance: 0.20,
    note:
        'Tested on fibre retained per unit energy, not on the protein '
        'tracer: pressing leaves most fibre in the pulp.',
  ),
  FoodDerivationEdge(
    id: 'white_rice_cooked.salt_addition',
    parentFdcId: 169757,
    childFdcId: 169753,
    kind: FoodDerivationKind.saltAddition,
    coherentNutrients: ['energy', 'protein', 'fat', 'carbohydrate'],
    relativeTolerance: 0.02,
    note:
        'Same cooked rice with salt added (child is enriched; iron and B '
        'vitamins differ by fortification and are not tested).',
  ),
];

/// Maximum fibre retained per unit energy for a juice-extraction edge to be
/// treated as coherent ("most fibre removed").
const double juiceFiberRetentionCoherentMax = 0.25;

final class DerivationEdgeCheck {
  final FoodDerivationEdge edge;

  /// Child mass per unit parent mass implied by the protein tracer
  /// (parent protein / child protein). Null when protein is missing or zero.
  final double? impliedMassRatio;

  /// For each nutrient: (parent/child ratio) / impliedMassRatio − 1.
  final Map<String, double> tracerDeviations;

  /// Juice edges: fibre per kcal in the child divided by the parent's.
  final double? fiberRetainedPerEnergy;

  /// Salt edges: salt added per 100 g implied by the sodium change.
  final double? impliedAddedSaltGPer100g;

  final List<String> incoherentNutrients;
  final List<String> findings;

  const DerivationEdgeCheck({
    required this.edge,
    required this.impliedMassRatio,
    required this.tracerDeviations,
    required this.fiberRetainedPerEnergy,
    required this.impliedAddedSaltGPer100g,
    required this.incoherentNutrients,
    required this.findings,
  });

  bool get coherent => findings.isEmpty;
}

double? _nutrient(ReferenceFoodCompositionRow row, String nutrient) {
  switch (nutrient) {
    case 'energy':
      return row.energyKcal;
    case 'protein':
      return row.proteinG;
    case 'fat':
      return row.fatG;
    case 'carbohydrate':
      return row.carbohydrateByDifferenceG;
    case 'fiber':
      return row.fiberG;
    case 'sodium':
      return row.sodiumMg;
    case 'potassium':
      return row.potassiumMg;
    case 'iron':
      return row.ironMg;
    case 'calcium':
      return row.calciumMg;
  }
  throw ArgumentError.value(nutrient, 'nutrient', 'not a tracked nutrient');
}

const List<String> _reportedTracerNutrients = [
  'energy',
  'fat',
  'carbohydrate',
  'fiber',
  'potassium',
  'iron',
];

/// Checks one derivation edge against the reference table.
DerivationEdgeCheck checkDerivationEdge(
  FoodDerivationEdge edge, {
  Map<int, ReferenceFoodCompositionRow>? rowsById,
}) {
  final rows = rowsById ?? referenceRowsByFdcId;
  final parent = rows[edge.parentFdcId];
  final child = rows[edge.childFdcId];
  final findings = <String>[];
  if (parent == null || child == null) {
    return DerivationEdgeCheck(
      edge: edge,
      impliedMassRatio: null,
      tracerDeviations: const {},
      fiberRetainedPerEnergy: null,
      impliedAddedSaltGPer100g: null,
      incoherentNutrients: const [],
      findings: const ['reference_row_missing'],
    );
  }
  final parentProtein = parent.proteinG;
  final childProtein = child.proteinG;
  final ratio =
      parentProtein != null &&
          childProtein != null &&
          parentProtein > 0 &&
          childProtein > 0
      ? parentProtein / childProtein
      : null;
  final deviations = <String, double>{};
  final incoherent = <String>[];
  if (ratio != null) {
    for (final nutrient in {
      ..._reportedTracerNutrients,
      ...edge.coherentNutrients,
    }) {
      final p = _nutrient(parent, nutrient);
      final c = _nutrient(child, nutrient);
      if (p == null || c == null || p <= 0 || c <= 0) continue;
      final deviation = (p / c) / ratio - 1.0;
      deviations[nutrient] = deviation;
      if (edge.coherentNutrients.contains(nutrient) &&
          deviation.abs() > edge.relativeTolerance) {
        incoherent.add(nutrient);
      }
    }
    for (final nutrient in edge.coherentNutrients) {
      if (!deviations.containsKey(nutrient)) {
        findings.add('coherent_nutrient_unavailable:$nutrient');
      }
    }
  } else if (edge.kind != FoodDerivationKind.juiceExtraction) {
    findings.add('protein_tracer_unavailable');
  }
  if (incoherent.isNotEmpty) {
    findings.add('tracer_incoherent:${incoherent.join(',')}');
  }
  switch (edge.kind) {
    case FoodDerivationKind.hydrationCooking:
      if (ratio != null && ratio <= 1.0) {
        findings.add('hydration_expected_mass_gain');
      }
    case FoodDerivationKind.moistureLossCooking:
      if (ratio != null && ratio >= 1.0) {
        findings.add('moisture_loss_expected_mass_loss');
      }
    case FoodDerivationKind.dehydration:
      if (ratio != null && ratio >= 1.0) {
        findings.add('dehydration_expected_mass_loss');
      }
    case FoodDerivationKind.vegetableBoiling:
      if (ratio != null && (ratio < 0.7 || ratio > 1.4)) {
        findings.add('vegetable_boiling_mass_ratio_out_of_band');
      }
    case FoodDerivationKind.juiceExtraction:
    case FoodDerivationKind.saltAddition:
      break;
  }
  double? fiberRetained;
  if (edge.kind == FoodDerivationKind.juiceExtraction) {
    final pf = parent.fiberG;
    final cf = child.fiberG;
    final pe = parent.energyKcal;
    final ce = child.energyKcal;
    if (pf != null && cf != null && pe != null && ce != null && pf > 0) {
      fiberRetained = (cf / ce) / (pf / pe);
      if (fiberRetained > juiceFiberRetentionCoherentMax) {
        findings.add('juice_fiber_not_depleted');
      }
    } else {
      findings.add('juice_fiber_unavailable');
    }
  }
  double? addedSalt;
  if (edge.kind == FoodDerivationKind.saltAddition) {
    final pn = parent.sodiumMg;
    final cn = child.sodiumMg;
    if (pn != null && cn != null) {
      addedSalt = saltEquivalentFromSodiumMg(cn - pn < 0 ? 0 : cn - pn);
      if (cn <= pn) findings.add('salt_addition_without_sodium_increase');
    } else {
      findings.add('sodium_unavailable');
    }
  }
  return DerivationEdgeCheck(
    edge: edge,
    impliedMassRatio: ratio,
    tracerDeviations: Map.unmodifiable(deviations),
    fiberRetainedPerEnergy: fiberRetained,
    impliedAddedSaltGPer100g: addedSalt,
    incoherentNutrients: List.unmodifiable(incoherent),
    findings: List.unmodifiable(findings),
  );
}

/// Part–whole check: whole egg = white + yolk.
final class PartWholeCheck {
  final int wholeFdcId;
  final int firstPartFdcId;
  final int secondPartFdcId;

  /// Mass fraction of the second part solved from the protein tracer.
  final double? secondPartFraction;

  /// Predicted/observed − 1 for each nutrient.
  final Map<String, double> deviations;
  final List<String> coherentNutrients;
  final double relativeTolerance;

  const PartWholeCheck({
    required this.wholeFdcId,
    required this.firstPartFdcId,
    required this.secondPartFdcId,
    required this.secondPartFraction,
    required this.deviations,
    required this.coherentNutrients,
    required this.relativeTolerance,
  });

  List<String> get incoherentNutrients => [
    for (final n in coherentNutrients)
      if (!deviations.containsKey(n) ||
          deviations[n]!.abs() > relativeTolerance)
        n,
  ];
}

PartWholeCheck checkEggPartWhole({
  Map<int, ReferenceFoodCompositionRow>? rowsById,
}) => checkPartWhole(
  wholeFdcId: 171287,
  firstPartFdcId: 172183,
  secondPartFdcId: 172184,
  coherentNutrients: const ['energy', 'fat'],
  relativeTolerance: 0.10,
  rowsById: rowsById,
);

PartWholeCheck checkPartWhole({
  required int wholeFdcId,
  required int firstPartFdcId,
  required int secondPartFdcId,
  required List<String> coherentNutrients,
  required double relativeTolerance,
  Map<int, ReferenceFoodCompositionRow>? rowsById,
}) {
  final rows = rowsById ?? referenceRowsByFdcId;
  final whole = rows[wholeFdcId];
  final first = rows[firstPartFdcId];
  final second = rows[secondPartFdcId];
  double? fraction;
  final deviations = <String, double>{};
  if (whole != null && first != null && second != null) {
    final pw = whole.proteinG;
    final p1 = first.proteinG;
    final p2 = second.proteinG;
    if (pw != null && p1 != null && p2 != null && p2 != p1) {
      final f = (pw - p1) / (p2 - p1);
      if (f > 0 && f < 1) {
        fraction = f;
        for (final nutrient in const [
          'energy',
          'fat',
          'iron',
          'calcium',
          'sodium',
        ]) {
          final w = _nutrient(whole, nutrient);
          final a = _nutrient(first, nutrient);
          final b = _nutrient(second, nutrient);
          if (w == null || a == null || b == null || w <= 0) continue;
          deviations[nutrient] = (a * (1 - f) + b * f) / w - 1.0;
        }
      }
    }
  }
  return PartWholeCheck(
    wholeFdcId: wholeFdcId,
    firstPartFdcId: firstPartFdcId,
    secondPartFdcId: secondPartFdcId,
    secondPartFraction: fraction,
    deviations: Map.unmodifiable(deviations),
    coherentNutrients: coherentNutrients,
    relativeTolerance: relativeTolerance,
  );
}

// ---------------------------------------------------------------------------
// Reference resolution
// ---------------------------------------------------------------------------

final Map<int, ReferenceFoodCompositionRow> referenceRowsByFdcId = {
  for (final row in referenceFoodCompositionRows) row.fdcId: row,
};

final Map<String, ReferenceFoodCompositionRow> _referenceRowsByName = () {
  final map = <String, ReferenceFoodCompositionRow>{};
  for (final row in referenceFoodCompositionRows) {
    for (final key in [row.nameEn, row.nameZh, row.sourceDescription]) {
      map.putIfAbsent(key.trim().toLowerCase(), () => row);
    }
  }
  return map;
}();

final RegExp _referenceIdPattern = RegExp(r'^food_ref_usda_(\d+)$');

/// Resolves a component to a reference row by its catalog id
/// (`food_ref_usda_<fdcId>`) or by an exact (case-insensitive) reference
/// name. No fuzzy matching: a non-match returns null.
ReferenceFoodCompositionRow? resolveReferenceRow({
  required String componentId,
  required String name,
}) {
  final idMatch = _referenceIdPattern.firstMatch(componentId.trim());
  if (idMatch != null) {
    final row = referenceRowsByFdcId[int.parse(idMatch.group(1)!)];
    if (row != null) return row;
  }
  return _referenceRowsByName[name.trim().toLowerCase()];
}

// ---------------------------------------------------------------------------
// 3a. Food-borne L-dopa
// ---------------------------------------------------------------------------

final class LevodopaTissueRange {
  final String tissue;
  final double minMgPerGDryWeight;
  final double maxMgPerGDryWeight;
  final String note;
  final List<String> sourceRefs;

  const LevodopaTissueRange({
    required this.tissue,
    required this.minMgPerGDryWeight,
    required this.maxMgPerGDryWeight,
    required this.note,
    required this.sourceRefs,
  });
}

final class IntrinsicLevodopaSource {
  final String id;
  final String scientificName;
  final List<LevodopaTissueRange> tissueRanges;

  /// Whether published data allow a per-serving amount for edible
  /// preparations. False for every source here: values are dry-weight,
  /// tissue-, variety- and processing-dependent.
  final bool quantifiedForEdibleServing;
  final List<int> referenceFdcIds;
  final List<String> latinCues;
  final List<String> cjkCues;
  final List<String> sourceRefs;

  const IntrinsicLevodopaSource({
    required this.id,
    required this.scientificName,
    required this.tissueRanges,
    required this.quantifiedForEdibleServing,
    required this.referenceFdcIds,
    required this.latinCues,
    required this.cjkCues,
    required this.sourceRefs,
  });

  /// Ratio between the highest and lowest published tissue values; a direct
  /// measure of why a single per-food number would be false precision.
  double get publishedRangeSpanFactor {
    var low = double.infinity;
    var high = 0.0;
    for (final range in tissueRanges) {
      if (range.minMgPerGDryWeight < low) low = range.minMgPerGDryWeight;
      if (range.maxMgPerGDryWeight > high) high = range.maxMgPerGDryWeight;
    }
    return low > 0 ? high / low : double.infinity;
  }
}

const IntrinsicLevodopaSource viciaFabaLevodopaSource = IntrinsicLevodopaSource(
  id: 'vicia_faba',
  scientificName: 'Vicia faba L. (broad bean, fava bean)',
  tissueRanges: [
    LevodopaTissueRange(
      tissue: 'mature seed',
      minMgPerGDryWeight: 0.10,
      maxMgPerGDryWeight: 0.76,
      note:
          '0.15 mg/g in one accession (0.10–0.15 after up to 1 h of dry or wet '
          'heat); 0.76 mg/g in a second cultivar.',
      sourceRefs: [
        'src.duan.faba_ldopa_thermal.2021',
        'src.tesoro.faba_pod_ldopa.2024',
      ],
    ),
    LevodopaTissueRange(
      tissue: 'pod valve',
      minMgPerGDryWeight: 28.65,
      maxMgPerGDryWeight: 28.65,
      note: 'One cultivar; pods are eaten in some cuisines.',
      sourceRefs: ['src.tesoro.faba_pod_ldopa.2024'],
    ),
    LevodopaTissueRange(
      tissue: 'leaf',
      minMgPerGDryWeight: 8.52,
      maxMgPerGDryWeight: 24.44,
      note:
          'Young 24.44 and old 18.13 mg/g raw; steaming reduced leaves to '
          '8.52–10.88 mg/g.',
      sourceRefs: ['src.duan.faba_ldopa_thermal.2021'],
    ),
  ],
  quantifiedForEdibleServing: false,
  referenceFdcIds: [170377, 170378, 175205],
  latinCues: [
    'fava',
    'favas',
    'faba',
    'fabas',
    'broad bean',
    'broad beans',
    'broadbean',
    'broadbeans',
    'vicia faba',
    'fève',
    'fèves',
    'feve',
    'feves',
    'sora bean',
    'sora beans',
  ],
  cjkCues: ['蚕豆', '胡豆', '罗汉豆', 'そら豆', 'ソラマメ', '空豆'],
  sourceRefs: [
    'src.duan.faba_ldopa_thermal.2021',
    'src.tesoro.faba_pod_ldopa.2024',
  ],
);

const IntrinsicLevodopaSource mucunaPruriensLevodopaSource =
    IntrinsicLevodopaSource(
      id: 'mucuna_pruriens',
      scientificName: 'Mucuna pruriens (L.) DC. (velvet bean)',
      tissueRanges: [
        LevodopaTissueRange(
          tissue: 'seed or leaf',
          minMgPerGDryWeight: 10.0,
          maxMgPerGDryWeight: 70.0,
          note:
              'Reported natural range 1%–7%; plant L-dopa is not '
              'interchangeable with a formulated levodopa dose.',
          sourceRefs: [
            'src.aureli.mucuna_ldopa.2025',
            'src.contin.mucuna_pk.2015',
          ],
        ),
      ],
      quantifiedForEdibleServing: false,
      referenceFdcIds: [],
      latinCues: [
        'mucuna',
        'velvet bean',
        'velvet beans',
        'cowhage',
        'kapikachhu',
        'kapikacchu',
      ],
      cjkCues: ['刺毛黧豆', '黧豆', '狗爪豆'],
      sourceRefs: ['src.aureli.mucuna_ldopa.2025', 'src.contin.mucuna_pk.2015'],
    );

const List<IntrinsicLevodopaSource> intrinsicLevodopaSources = [
  viciaFabaLevodopaSource,
  mucunaPruriensLevodopaSource,
];

final class IntrinsicLevodopaSourceMatch {
  final IntrinsicLevodopaSource source;
  final String matchedBy;

  const IntrinsicLevodopaSourceMatch(this.source, this.matchedBy);
}

bool _latinCueMatches(String lower, String cue) {
  final escaped = RegExp.escape(cue);
  return RegExp('(?<![a-zà-ÿ])$escaped(?![a-zà-ÿ])').hasMatch(lower);
}

/// Matches a food to a documented food-borne L-dopa source by reference id,
/// whole-word Latin-script name cue, or CJK name cue. Deterministic; the
/// returned [IntrinsicLevodopaSourceMatch.matchedBy] records the evidence.
IntrinsicLevodopaSourceMatch? matchIntrinsicLevodopaSource({
  required String name,
  String componentId = '',
  ReferenceFoodCompositionRow? reference,
}) {
  final lower = '${name.toLowerCase()} ${componentId.toLowerCase()}'.replaceAll(
    '_',
    ' ',
  );
  for (final source in intrinsicLevodopaSources) {
    if (reference != null && source.referenceFdcIds.contains(reference.fdcId)) {
      return IntrinsicLevodopaSourceMatch(
        source,
        'reference_fdc_id:${reference.fdcId}',
      );
    }
    for (final cue in source.latinCues) {
      if (_latinCueMatches(lower, cue)) {
        return IntrinsicLevodopaSourceMatch(source, 'name_cue:$cue');
      }
    }
    for (final cue in source.cjkCues) {
      if (name.contains(cue)) {
        return IntrinsicLevodopaSourceMatch(source, 'name_cue:$cue');
      }
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// 3b. Preparation-state ambiguity (dry versus cooked)
// ---------------------------------------------------------------------------

final class PreparationStateFamily {
  final String id;
  final int dryFdcId;
  final int cookedFdcId;
  final List<String> latinCues;
  final List<String> cjkCues;

  /// Names containing one of these are a different product (flour, oil,
  /// milk, ...) and are not part of the family.
  final List<String> latinExclusions;
  final List<String> cjkExclusions;

  const PreparationStateFamily({
    required this.id,
    required this.dryFdcId,
    required this.cookedFdcId,
    required this.latinCues,
    required this.cjkCues,
    this.latinExclusions = const [],
    this.cjkExclusions = const [],
  });
}

const List<String> _sharedLatinExclusions = [
  'flour',
  'bran',
  'oil',
  'milk',
  'sauce',
  'cake',
  'cakes',
  'cracker',
  'crackers',
  'bread',
  'paste',
  'butter',
  'protein',
  'isolate',
  'sprout',
  'sprouts',
  'pudding',
  'vinegar',
  'syrup',
  'wine',
  'tofu',
  'miso',
  'natto',
  'tempeh',
];
const List<String> _sharedCjkExclusions = [
  '粉',
  '油',
  '奶',
  '浆',
  '酱',
  '糕',
  '饼',
  '面包',
  '醋',
  '酒',
  '豆腐',
  '芽',
];

const List<PreparationStateFamily> preparationStateFamilies = [
  PreparationStateFamily(
    id: 'white_rice',
    dryFdcId: 169756,
    cookedFdcId: 169757,
    latinCues: ['rice', 'white rice'],
    cjkCues: ['大米', '白米', '米'],
    latinExclusions: ['brown', 'wild', 'noodle', 'noodles', 'vermicelli'],
    cjkExclusions: ['糙米', '米粉', '米线', '小米', '玉米', '菰米', '紫米', '黑米'],
  ),
  PreparationStateFamily(
    id: 'brown_rice',
    dryFdcId: 169703,
    cookedFdcId: 169704,
    latinCues: ['brown rice'],
    cjkCues: ['糙米'],
  ),
  PreparationStateFamily(
    id: 'pasta',
    dryFdcId: 169736,
    cookedFdcId: 169737,
    latinCues: ['pasta', 'spaghetti', 'macaroni', 'penne', 'fusilli'],
    cjkCues: ['意大利面', '意面', '通心粉'],
  ),
  PreparationStateFamily(
    id: 'rice_noodles',
    dryFdcId: 169742,
    cookedFdcId: 168914,
    latinCues: ['rice noodle', 'rice noodles', 'rice vermicelli'],
    cjkCues: ['米粉', '米线', '河粉'],
  ),
  PreparationStateFamily(
    id: 'lentils',
    dryFdcId: 172420,
    cookedFdcId: 172421,
    latinCues: ['lentil', 'lentils'],
    cjkCues: ['小扁豆', '兵豆'],
  ),
  PreparationStateFamily(
    id: 'split_peas',
    dryFdcId: 172428,
    cookedFdcId: 172429,
    latinCues: ['split pea', 'split peas'],
    cjkCues: ['豌豆瓣'],
  ),
  PreparationStateFamily(
    id: 'black_beans',
    dryFdcId: 173734,
    cookedFdcId: 173735,
    latinCues: ['black bean', 'black beans'],
    cjkCues: ['黑豆', '黑龟豆'],
  ),
  PreparationStateFamily(
    id: 'soybeans',
    dryFdcId: 174270,
    cookedFdcId: 174271,
    latinCues: ['soybean', 'soybeans', 'soy bean', 'soy beans'],
    cjkCues: ['黄豆', '大豆'],
    latinExclusions: ['green', 'edamame'],
    cjkExclusions: ['毛豆'],
  ),
  PreparationStateFamily(
    id: 'oats',
    dryFdcId: 173904,
    cookedFdcId: 173905,
    latinCues: ['oat', 'oats', 'oatmeal', 'rolled oats'],
    cjkCues: ['燕麦'],
  ),
  PreparationStateFamily(
    id: 'couscous',
    dryFdcId: 169699,
    cookedFdcId: 169700,
    latinCues: ['couscous'],
    cjkCues: ['古斯米'],
  ),
  PreparationStateFamily(
    id: 'spelt',
    dryFdcId: 169745,
    cookedFdcId: 169746,
    latinCues: ['spelt'],
    cjkCues: ['斯佩尔特'],
  ),
];

const List<String> _stateLatinCues = [
  'cooked',
  'boiled',
  'steamed',
  'simmered',
  'raw',
  'dry',
  'dried',
  'uncooked',
  'prepared',
  'porridge',
  'baked',
  'fried',
  'roasted',
  'canned',
  'soaked',
  'instant',
];
const List<String> _stateCjkCues = [
  '饭',
  '粥',
  '熟',
  '煮',
  '蒸',
  '炒',
  '焖',
  '生',
  '干',
  '罐',
];

/// Relative band within which a serving's protein density identifies the
/// dry or cooked reference state.
const double stateMatchRelativeTolerance = 0.35;

final class PreparationStateAmbiguity {
  final PreparationStateFamily family;
  final double? dryProteinPer100g;
  final double? cookedProteinPer100g;

  const PreparationStateAmbiguity({
    required this.family,
    required this.dryProteinPer100g,
    required this.cookedProteinPer100g,
  });

  /// True when the logged serving's own protein density (g per 100 g) sits
  /// within [stateMatchRelativeTolerance] of the dry or the cooked reference
  /// value, so the data already identify the state despite the name. Missing
  /// protein or portion leaves the state unresolved.
  bool isResolvedByProteinDensity({
    required double? proteinGrams,
    required double? portionGrams,
  }) {
    final dry = dryProteinPer100g;
    final cooked = cookedProteinPer100g;
    if (proteinGrams == null ||
        portionGrams == null ||
        dry == null ||
        cooked == null ||
        !proteinGrams.isFinite ||
        !portionGrams.isFinite ||
        proteinGrams <= 0 ||
        portionGrams <= 0) {
      return false;
    }
    final density = proteinGrams / portionGrams * 100.0;
    bool near(double reference) =>
        (density - reference).abs() <= stateMatchRelativeTolerance * reference;
    return near(dry) || near(cooked);
  }

  /// How many times larger the protein per 100 g is if the logged food was
  /// dry rather than cooked.
  double? get proteinAmbiguityFactor {
    final dry = dryProteinPer100g;
    final cooked = cookedProteinPer100g;
    if (dry == null || cooked == null || cooked <= 0) return null;
    return dry / cooked;
  }
}

bool _containsLatinWord(String lower, String cue) =>
    _latinCueMatches(lower, cue);

/// Returns an ambiguity when [name] names a food whose composition per 100 g
/// changes 2–5× between dry and cooked states but gives no state. Matching is
/// deterministic (whole words for Latin script, substrings for CJK).
PreparationStateAmbiguity? detectPreparationStateAmbiguity(String name) {
  final lower = name.toLowerCase().replaceAll('_', ' ');
  if (_stateLatinCues.any((cue) => _containsLatinWord(lower, cue)) ||
      _stateCjkCues.any(name.contains)) {
    return null;
  }
  if (_sharedLatinExclusions.any((cue) => _containsLatinWord(lower, cue)) ||
      _sharedCjkExclusions.any(name.contains)) {
    return null;
  }
  for (final family in preparationStateFamilies) {
    if (family.latinExclusions.any((cue) => _containsLatinWord(lower, cue)) ||
        family.cjkExclusions.any(name.contains)) {
      continue;
    }
    final matches =
        family.latinCues.any((cue) => _containsLatinWord(lower, cue)) ||
        family.cjkCues.any(name.contains);
    if (!matches) continue;
    return PreparationStateAmbiguity(
      family: family,
      dryProteinPer100g: referenceRowsByFdcId[family.dryFdcId]?.proteinG,
      cookedProteinPer100g: referenceRowsByFdcId[family.cookedFdcId]?.proteinG,
    );
  }
  return null;
}

// ---------------------------------------------------------------------------
// 3c. Non-heme iron co-consumption context (educational, non-scoring)
// ---------------------------------------------------------------------------

/// Calcium amount (mg) given as milk, cheese or calcium chloride that reduced
/// single-meal iron absorption by 50–60% (Hallberg et al. 1991).
const double calciumCoConsumptionStudiedMg = 165.0;

final class MealItemReference {
  final String componentId;
  final String name;
  final double? portionGrams;
  final ReferenceFoodCompositionRow? reference;

  const MealItemReference({
    required this.componentId,
    required this.name,
    required this.portionGrams,
    required this.reference,
  });
}

enum IronCoConsumptionFactor {
  calciumAtOrAboveStudiedAmount,
  polyphenolBeverage,
  ascorbicAcidSource,
  hemeIronSource,
}

final class IronCoConsumptionContext {
  final Set<IronCoConsumptionFactor> factors;
  final double? quantifiedCalciumMg;
  final double? quantifiedVitaminCMg;
  final List<String> unquantifiedComponentIds;
  final List<String> sourceRefs;
  final String limitation;

  const IronCoConsumptionContext({
    required this.factors,
    required this.quantifiedCalciumMg,
    required this.quantifiedVitaminCMg,
    required this.unquantifiedComponentIds,
    required this.sourceRefs,
    required this.limitation,
  });
}

final RegExp _polyphenolBeverageCue = RegExp(
  r'(?<![a-z])(coffee|espresso|tea)(?![a-z])',
);
const List<String> _polyphenolBeverageCjkCues = ['咖啡', '茶'];

/// Describes documented modulators of non-heme iron absorption present in a
/// meal. Context only: no absorption percentage is predicted, food iron is
/// not linked to levodopa (the levodopa chelation study used a ferrous
/// sulfate tablet), and nothing here suggests changing a meal.
IronCoConsumptionContext assessIronCoConsumption(
  List<MealItemReference> items,
) {
  final factors = <IronCoConsumptionFactor>{};
  var calcium = 0.0;
  var vitaminC = 0.0;
  var calciumQuantified = false;
  var vitaminCQuantified = false;
  final unquantified = <String>[];
  for (final item in items) {
    final row = item.reference;
    final lower = item.name.toLowerCase();
    if (_polyphenolBeverageCue.hasMatch(lower) ||
        _polyphenolBeverageCjkCues.any(item.name.contains)) {
      factors.add(IronCoConsumptionFactor.polyphenolBeverage);
    }
    if (row == null) {
      unquantified.add(item.componentId);
      continue;
    }
    if (row.group == ReferenceFoodGroup.meat ||
        row.group == ReferenceFoodGroup.poultry ||
        row.group == ReferenceFoodGroup.fishSeafood) {
      factors.add(IronCoConsumptionFactor.hemeIronSource);
    }
    final portion = item.portionGrams;
    if (portion == null || !portion.isFinite || portion < 0) {
      unquantified.add(item.componentId);
      continue;
    }
    final ca = row.calciumMg;
    if (ca != null) {
      calcium += ca * portion / 100.0;
      calciumQuantified = true;
    }
    final c = row.vitaminCMg;
    if (c != null) {
      vitaminC += c * portion / 100.0;
      vitaminCQuantified = true;
    }
  }
  if (calciumQuantified && calcium >= calciumCoConsumptionStudiedMg) {
    factors.add(IronCoConsumptionFactor.calciumAtOrAboveStudiedAmount);
  }
  if (vitaminCQuantified && vitaminC > 0) {
    factors.add(IronCoConsumptionFactor.ascorbicAcidSource);
  }
  return IronCoConsumptionContext(
    factors: Set.unmodifiable(factors),
    quantifiedCalciumMg: calciumQuantified ? calcium : null,
    quantifiedVitaminCMg: vitaminCQuantified ? vitaminC : null,
    unquantifiedComponentIds: List.unmodifiable(unquantified..sort()),
    sourceRefs: FoodCompositionInterdependencyModel.ironContextSourceRefs,
    limitation:
        'Single-meal studies show these modulators; whole-diet effects are '
        'smaller and individual. This prototype can show an educational '
        'context note only. Food iron is not the iron-salt tablet studied '
        'with levodopa. Review questions about iron or medicines with a '
        'qualified clinician.',
  );
}

// ---------------------------------------------------------------------------
// Meal assessment result
// ---------------------------------------------------------------------------

final class IntrinsicLevodopaMatch {
  final String componentId;
  final String componentName;
  final IntrinsicLevodopaSource source;
  final String matchedBy;

  const IntrinsicLevodopaMatch({
    required this.componentId,
    required this.componentName,
    required this.source,
    required this.matchedBy,
  });
}

final class PreparationStateAmbiguityMatch {
  final String componentId;
  final String componentName;
  final PreparationStateAmbiguity ambiguity;

  const PreparationStateAmbiguityMatch({
    required this.componentId,
    required this.componentName,
    required this.ambiguity,
  });
}

final class ComponentEnergyFinding {
  final String componentId;
  final String componentName;
  final EnergyReconciliation reconciliation;

  const ComponentEnergyFinding({
    required this.componentId,
    required this.componentName,
    required this.reconciliation,
  });
}

final class FoodInterdependencyAssessment {
  final String compositionId;
  final List<IntrinsicLevodopaMatch> intrinsicLevodopaSources;
  final List<PreparationStateAmbiguityMatch> preparationStateAmbiguities;
  final List<ComponentEnergyFinding> componentEnergyInconsistencies;

  const FoodInterdependencyAssessment({
    required this.compositionId,
    required this.intrinsicLevodopaSources,
    required this.preparationStateAmbiguities,
    required this.componentEnergyInconsistencies,
  });

  bool get hasFindings =>
      intrinsicLevodopaSources.isNotEmpty ||
      preparationStateAmbiguities.isNotEmpty ||
      componentEnergyInconsistencies.isNotEmpty;

  /// Deterministic, machine-readable uncertainty reasons.
  List<String> get uncertaintyReasons => [
    for (final match in intrinsicLevodopaSources)
      'food_intrinsic_levodopa_unquantified('
          '$compositionId:${match.componentId}:${match.source.id})',
    for (final match in preparationStateAmbiguities)
      'food_preparation_state_ambiguous('
          '$compositionId:${match.componentId}:${match.ambiguity.family.id}'
          '${_factorSuffix(match.ambiguity.proteinAmbiguityFactor)})',
    for (final finding in componentEnergyInconsistencies)
      'food_component_energy_inconsistent('
          '$compositionId:${finding.componentId})',
  ];

  List<String> get sourceRefs => <String>{
    if (intrinsicLevodopaSources.isNotEmpty)
      ...FoodCompositionInterdependencyModel.intrinsicLevodopaSourceRefs,
    if (preparationStateAmbiguities.isNotEmpty)
      ...FoodCompositionInterdependencyModel.preparationStateSourceRefs,
    if (componentEnergyInconsistencies.isNotEmpty)
      ...FoodCompositionInterdependencyModel.identitySourceRefs,
  }.toList(growable: false)..sort();

  static String _factorSuffix(double? factor) =>
      factor == null ? '' : ':protein_x${factor.toStringAsFixed(2)}';
}
