import '../entities/algorithm_component_identity_witness.dart';
import '../entities/gastric_emptying_parameters.dart';
import '../entities/gastric_emptying_profile.dart';
import '../entities/meal_composition.dart';
import '../entities/time_axis_events.dart';

/// Semi-mechanistic, deterministic gastric emptying model.
///
/// All numeric magnitudes are sourced from
/// `GastricEmptyingParameterSet.literatureInformedDefault()`, which tags
/// each value with provenance (literature-informed mechanism direction vs
/// prototype_heuristic magnitude). The *direction* of each effect (solids
/// lag, liquids fast, fat slows, large meals slow, fiber widens
/// uncertainty, mixed meals cumulate) is grounded in the cited literature;
/// exact magnitudes are illustrative and are not patient-calibrated.
class GastricEmptyingModel with RegisteredAlgorithmComponentIdentity {
  final GastricEmptyingParameterSet parameters;

  GastricEmptyingModel({GastricEmptyingParameterSet? parameters})
    : parameters =
          parameters ??
          GastricEmptyingParameterSet.literatureInformedDefault() {
    final parameterErrors = this.parameters.validationErrors;
    if (parameterErrors.isNotEmpty) {
      throw ArgumentError.value(
        this.parameters.id,
        'parameters',
        'Invalid gastric-emptying parameter set: '
            '${parameterErrors.join(', ')}.',
      );
    }
  }

  GastricEmptyingProfile build({
    required String mealId,
    required int mealStartMinute,
    required MealComposition composition,

    /// Optional cumulative load from earlier overlapping meals (0..1).
    /// Increases uncertainty and is recorded in assumptions.
    double overlappingResidualLoad = 0.0,
  }) {
    final assumptions = <String>[];
    // Normalized missingness affects this model's uncertainty even when a
    // field is not used by a numeric branch directly. Preserve the complete
    // upstream contract, then add model-specific derived missing inputs.
    final missingInputs = <String>{...composition.missingFields};
    final modifiers = <String>[];

    final hasAnyMealLevelEvidence =
        composition.totalCalories != null ||
        composition.proteinGrams != null ||
        composition.fatGrams != null ||
        composition.fiberGrams != null ||
        composition.carbohydrateGrams != null ||
        composition.liquidFraction != null ||
        composition.mealPhysicalForm != MealPhysicalForm.unknown;
    if (composition.foodComponents.isEmpty && !hasAnyMealLevelEvidence) {
      missingInputs.add('food_components');
      return GastricEmptyingProfile(
        mealId: mealId,
        availability: MechanisticProviderAvailability.insufficient,
        applicabilityReasons: const [
          'gastric_emptying.meal_composition_absent',
        ],
        componentProfiles: const [],
        uncertaintyBand: UncertaintyBand.veryWide,
        assumptions: const ['ge.model_not_applicable_no_meal_evidence'],
        missingInputs: List.unmodifiable(missingInputs),
        sourceRefs: parameters.unionSourceRefs,
        aggregateLagMinutes: 0,
        peakEmptyingWindow: TimelineWindow(
          startMinute: mealStartMinute,
          endMinute: mealStartMinute,
        ),
        mostlyEmptiedWindow: TimelineWindow(
          startMinute: mealStartMinute,
          endMinute: mealStartMinute,
        ),
        timeScaleSensitivityFraction:
            parameters.timeScaleSensitivityFraction.value,
      );
    }

    // Determine fat fraction.
    final fatFractionAvailable =
        composition.fatGrams != null && (composition.totalCalories ?? 0) > 0;
    final fatFraction = fatFractionAvailable
        ? (composition.fatGrams! * 9.0) / composition.totalCalories!
        : null;
    if (!fatFractionAvailable) missingInputs.add('fat_fraction_of_calories');

    final sizeAvailable = composition.totalCalories != null;
    if (!sizeAvailable) missingInputs.add('total_calories');

    double sizeMultiplier;
    if (sizeAvailable) {
      sizeMultiplier =
          0.6 +
          0.4 *
              (composition.totalCalories! /
                  parameters.referenceMealCalories.value);
      sizeMultiplier = sizeMultiplier.clamp(0.6, 2.0);
      assumptions.add(
        'ge.size.linear_scale (size multiplier ${sizeMultiplier.toStringAsFixed(2)})',
      );
    } else {
      sizeMultiplier = 1.0;
      assumptions.add(
        'ge.size.unknown_default (size multiplier 1.00, uncertainty widened)',
      );
    }

    double fatMultiplier;
    final highFat =
        fatFraction != null &&
        fatFraction >= parameters.fatFractionThreshold.value;
    if (highFat) {
      fatMultiplier = parameters.fatSlowdownMultiplier.value;
      modifiers.add('fat_slowdown_${fatMultiplier.toStringAsFixed(2)}x');
      assumptions.add(parameters.fatSlowdownMultiplier.id);
      assumptions.add(
        '${parameters.fatUncertaintyBoost.id} (high fat, uncertainty widened)',
      );
    } else {
      fatMultiplier = 1.0;
    }

    // High-calorie load: meals well above the reference size empty more slowly
    // and with greater inter-subject variance → widen uncertainty (in addition
    // to the size multiplier already applied to the emptying curve).
    final highCalorie =
        sizeAvailable &&
        composition.totalCalories! >=
            parameters.referenceMealCalories.value *
                parameters.highCalorieFractionThreshold.value;
    if (highCalorie) {
      assumptions.add(
        '${parameters.highCalorieUncertaintyBoost.id} (high calorie load, uncertainty widened)',
      );
    }

    // Fiber contribution: small slowdown if high, but mainly widens uncertainty.
    final highFiber = composition.fiberAmountBand == AmountBand.high;
    double fiberMultiplier = 1.0;
    if (highFiber) {
      fiberMultiplier = parameters.fiberSlowdownMultiplier.value;
      assumptions.add(
        '${parameters.fiberSlowdownMultiplier.id} (high fiber, slight slowdown)',
      );
      modifiers.add('fiber_uncertainty_widen');
    }
    if (composition.fiberAmountBand == AmountBand.unknown) {
      missingInputs.add('fiber_grams');
    }

    // Build per-component profiles. When component detail is absent but some
    // meal-level evidence is present, retain the existing disclosed central
    // sensitivity component. A completely empty composition already abstained
    // above and can never reach this fallback.
    final componentProfiles = <EmptyingComponentProfile>[];
    if (composition.foodComponents.isEmpty) {
      componentProfiles.add(
        _buildComponent(
          componentId: '${mealId}__synthesized',
          form: composition.mealPhysicalForm,
          sizeMultiplier: sizeMultiplier,
          fatMultiplier: fatMultiplier,
          fiberMultiplier: fiberMultiplier,
          fractionOfMeal: 1.0,
          modifiers: List<String>.unmodifiable(modifiers),
        ),
      );
      if (composition.mealPhysicalForm == MealPhysicalForm.unknown) {
        missingInputs.add('meal_physical_form');
      }
    } else {
      final knownPositiveMasses =
          composition.foodComponents
              .map((component) => component.portionGrams)
              .whereType<double>()
              .where((portion) => portion.isFinite && portion > 0)
              .toList(growable: false)
            ..sort();
      final unknownPortionCount = composition.foodComponents
          .where((component) => component.portionGrams == null)
          .length;
      final hasNonFinitePortion = composition.foodComponents.any((component) {
        final portion = component.portionGrams;
        return portion != null && !portion.isFinite;
      });
      final hasNegativePortion = composition.foodComponents.any((component) {
        final portion = component.portionGrams;
        return portion != null && portion.isFinite && portion < 0;
      });
      final hasNonPositivePortion = composition.foodComponents.any((component) {
        final portion = component.portionGrams;
        return portion != null && portion.isFinite && portion <= 0;
      });

      // A missing portion is not zero mass. For a partially observed meal, use
      // the arithmetic mean of the valid positive portions as a transparent
      // central sensitivity value. This is not a serving-size estimate: the
      // missing input remains explicit and composition incompleteness widens
      // the model uncertainty. If every portion is unknown, a neutral unit
      // mass gives equal weights without inventing an absolute meal size.
      var meanKnownPositiveMass = 1.0;
      if (knownPositiveMasses.isNotEmpty) {
        meanKnownPositiveMass = 0.0;
        for (var index = 0; index < knownPositiveMasses.length; index++) {
          meanKnownPositiveMass +=
              (knownPositiveMasses[index] - meanKnownPositiveMass) /
              (index + 1);
        }
      }
      final effectiveMasses = composition.foodComponents
          .map((component) {
            final portion = component.portionGrams;
            if (portion == null) return meanKnownPositiveMass;
            return portion.isFinite && portion > 0 ? portion : 0.0;
          })
          .toList(growable: false);

      if (unknownPortionCount > 0 ||
          hasNonFinitePortion ||
          hasNegativePortion) {
        missingInputs.add('portion_grams');
      }
      if (unknownPortionCount > 0) {
        if (knownPositiveMasses.isNotEmpty) {
          assumptions.add(
            'ge.component_portion.partial_mean_imputation '
            '($unknownPortionCount missing; central sensitivity only)',
          );
        } else if (unknownPortionCount == composition.foodComponents.length) {
          assumptions.add(
            'ge.component_portion.all_unknown_equal_weight '
            '(neutral unit masses; uncertainty widened)',
          );
        } else {
          assumptions.add(
            'ge.component_portion.unknown_unit_imputation '
            '($unknownPortionCount missing; no positive reference mass)',
          );
        }
      }
      if (hasNonPositivePortion) {
        assumptions.add('ge.component_portion.nonpositive_ignored');
      }
      if (hasNonFinitePortion) {
        assumptions.add('ge.component_portion.nonfinite_ignored');
      }

      // Normalize after scaling by the largest mass so even very large finite
      // inputs cannot overflow the denominator. When every supplied value is
      // unusable (for example all zero/negative), retain a finite structural
      // profile with equal weights and disclose that fallback explicitly.
      var maximumEffectiveMass = 0.0;
      for (final mass in effectiveMasses) {
        if (mass > maximumEffectiveMass) maximumEffectiveMass = mass;
      }
      final scaledMasses = maximumEffectiveMass > 0
          ? effectiveMasses
                .map((mass) => mass / maximumEffectiveMass)
                .toList(growable: false)
          : List<double>.filled(effectiveMasses.length, 1.0);
      if (maximumEffectiveMass <= 0) {
        assumptions.add(
          'ge.component_portion.no_usable_mass_equal_weight '
          '(structural fallback; uncertainty widened)',
        );
      }
      final totalScaledMass = scaledMasses.fold<double>(
        0,
        (total, mass) => total + mass,
      );
      for (var index = 0; index < composition.foodComponents.length; index++) {
        final c = composition.foodComponents[index];
        final fraction = scaledMasses[index] / totalScaledMass;
        componentProfiles.add(
          _buildComponent(
            componentId: c.id,
            form: c.physicalForm,
            sizeMultiplier: sizeMultiplier,
            fatMultiplier: fatMultiplier,
            fiberMultiplier: fiberMultiplier,
            fractionOfMeal: fraction,
            modifiers: List<String>.unmodifiable(modifiers),
          ),
        );
      }
    }

    if (overlappingResidualLoad > 0) {
      assumptions.add(
        'ge.overlap.cumulate (residual load ${overlappingResidualLoad.toStringAsFixed(2)}, uncertainty widened)',
      );
    }

    final uncertaintyBand = _uncertaintyBand(
      compositionCompleteness: composition.compositionCompleteness,
      overlappingResidualLoad: overlappingResidualLoad,
      highFiber: highFiber,
      highFat: highFat,
      highCalorie: highCalorie,
    );

    // Aggregate lag = mass-weighted lag across components.
    final aggregateLag = componentProfiles.fold<double>(
      0,
      (acc, c) => acc + c.fractionOfMeal * c.lagMinutes,
    );

    // Peak emptying window: from lag end to lag + half * 1.5 (heuristic).
    final aggregateHalf = componentProfiles.fold<double>(
      0,
      (acc, c) => acc + c.fractionOfMeal * c.halfEmptyingMinutes,
    );
    final peakStart = mealStartMinute + aggregateLag.round();
    final peakEnd = peakStart + (aggregateHalf * 1.5).round();
    final mostlyEmptiedEnd =
        mealStartMinute + aggregateLag.round() + (aggregateHalf * 4).round();

    return GastricEmptyingProfile(
      mealId: mealId,
      componentProfiles: List.unmodifiable(componentProfiles),
      uncertaintyBand: uncertaintyBand,
      assumptions: List.unmodifiable(assumptions),
      missingInputs: List.unmodifiable(missingInputs),
      sourceRefs: parameters.unionSourceRefs,
      aggregateLagMinutes: aggregateLag,
      peakEmptyingWindow: TimelineWindow(
        startMinute: peakStart,
        endMinute: peakEnd,
      ),
      mostlyEmptiedWindow: TimelineWindow(
        startMinute: peakStart,
        endMinute: mostlyEmptiedEnd,
      ),
      timeScaleSensitivityFraction:
          parameters.timeScaleSensitivityFraction.value,
    );
  }

  EmptyingComponentProfile _buildComponent({
    required String componentId,
    required MealPhysicalForm form,
    required double sizeMultiplier,
    required double fatMultiplier,
    required double fiberMultiplier,
    required double fractionOfMeal,
    required List<String> modifiers,
  }) {
    final isLiquid = form == MealPhysicalForm.liquid;
    final baseLag = isLiquid
        ? parameters.liquidLagMinutes.value
        : (form == MealPhysicalForm.unknown
              ? parameters.solidLagMinutes.value * 0.7
              : parameters.solidLagMinutes.value);
    final baseHalf = isLiquid
        ? parameters.liquidHalfMinutes.value
        : (form == MealPhysicalForm.unknown
              ? parameters.solidHalfMinutes.value * 0.9
              : parameters.solidHalfMinutes.value);

    return EmptyingComponentProfile(
      componentId: componentId,
      physicalForm: form,
      lagMinutes: baseLag * sizeMultiplier,
      halfEmptyingMinutes:
          baseHalf * sizeMultiplier * fatMultiplier * fiberMultiplier,
      fractionOfMeal: fractionOfMeal,
      appliedModifiers: modifiers,
    );
  }

  UncertaintyBand _uncertaintyBand({
    required double compositionCompleteness,
    required double overlappingResidualLoad,
    required bool highFiber,
    required bool highFat,
    required bool highCalorie,
  }) {
    var score = 0;
    if (compositionCompleteness < 0.99) score += 1;
    if (compositionCompleteness < 0.75) score += 1;
    if (compositionCompleteness < 0.5) score += 1;
    if (overlappingResidualLoad > 0.1) {
      score += parameters.overlapUncertaintyBoost.value;
    }
    if (overlappingResidualLoad > 0.3) {
      score += parameters.overlapUncertaintyBoost.value;
    }
    if (highFiber) score += parameters.mixedMealUncertaintyBoost.value;
    if (highFat) score += parameters.fatUncertaintyBoost.value;
    if (highCalorie) score += parameters.highCalorieUncertaintyBoost.value;
    switch (score) {
      case 0:
        return UncertaintyBand.narrow;
      case 1:
        return UncertaintyBand.moderate;
      case 2:
        return UncertaintyBand.wide;
      default:
        return UncertaintyBand.veryWide;
    }
  }
}
