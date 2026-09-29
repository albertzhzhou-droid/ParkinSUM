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
  static const String configurationSchema =
      'parkinsum.gastric-emptying-configuration/1';
  static const String generatorStructureSchema =
      'parkinsum.gastric-emptying-generator-structure/1';
  static const double fatCaloriesPerGram = 9.0;
  static const double sizeScaleIntercept = 0.6;
  static const double sizeScaleSlope = 0.4;
  static const double sizeScaleMinimum = 0.6;
  static const double sizeScaleMaximum = 2.0;
  static const double unknownSizeMultiplier = 1.0;
  static const double neutralMultiplier = 1.0;
  static const double neutralUnitMass = 1.0;
  static const double unknownFormLagMultiplier = 0.7;
  static const double unknownFormHalfTimeMultiplier = 0.9;
  static const double completeCompositionThreshold = 0.99;
  static const double mostlyCompleteCompositionThreshold = 0.75;
  static const double partialCompositionThreshold = 0.5;
  static const double firstOverlapThreshold = 0.1;
  static const double secondOverlapThreshold = 0.3;
  static const double overlapDisclosureThreshold = 0.0;
  static const int assumptionNumericDecimalPlaces = 2;

  /// Canonical declaration of every result-affecting branch that is not an
  /// injectable numeric gastric parameter. This is an engineering review
  /// surface, not evidence that the model is physiologically calibrated.
  static const Map<String, Object> generatorStructure = <String, Object>{
    r'$schema': generatorStructureSchema,
    'meal_evidence_gate': <String, Object>{
      'meal_level_fields': <String>[
        'total_calories',
        'protein_grams',
        'fat_grams',
        'fiber_grams',
        'carbohydrate_grams',
        'liquid_fraction',
        'meal_physical_form_not_unknown',
      ],
      'requires_any_meal_level_or_component_evidence': true,
      'empty_result_availability': 'insufficient',
      'empty_result_reason': 'gastric_emptying.meal_composition_absent',
    },
    'fat_fraction': <String, Object>{
      'formula': 'fat_grams * calories_per_gram / total_calories',
      'calories_per_gram': fatCaloriesPerGram,
      'requires_total_calories_strictly_positive': true,
    },
    'size_multiplier': <String, Object>{
      'formula': 'intercept + slope * total_calories / reference_meal_calories',
      'intercept': sizeScaleIntercept,
      'slope': sizeScaleSlope,
      'clamp': <double>[sizeScaleMinimum, sizeScaleMaximum],
      'missing_default': unknownSizeMultiplier,
    },
    'modifier_comparators': <String, Object>{
      'high_fat': 'fat_fraction >= fat_fraction_threshold',
      'high_calorie':
          'total_calories >= reference_meal_calories * high_calorie_fraction_threshold',
      'high_fiber': 'fiber_amount_band == high',
    },
    'component_time_scale': <String, Object>{
      'lag_formula': 'base_lag * size_multiplier',
      'half_time_formula':
          'base_half_time * size_multiplier * fat_multiplier * fiber_multiplier',
      'neutral_modifier_multiplier': neutralMultiplier,
      'high_fat_multiplier_source': 'ge.fat.slowdown_multiplier',
      'high_fiber_multiplier_source': 'ge.fiber.slowdown_multiplier',
    },
    'component_form_branch': <String, Object>{
      'liquid': 'liquid_parameter_pair',
      'solid': 'solid_parameter_pair',
      'mixed': 'solid_parameter_pair',
      'unknown_lag_multiplier': unknownFormLagMultiplier,
      'unknown_half_time_multiplier': unknownFormHalfTimeMultiplier,
    },
    'component_fallback': <String, Object>{
      'when': 'no_food_components_and_any_meal_level_evidence',
      'component_id_suffix': '__synthesized',
      'physical_form_source': 'meal_physical_form',
      'fraction_of_meal': neutralUnitMass,
    },
    'component_weighting': <String, Object>{
      'known_positive_portions': 'mass_proportional_after_max_scaling',
      'partially_missing_portions': 'mean_known_positive_mass_imputation',
      'mean_accumulation': 'sorted_ascending_incremental_mean',
      'missing_without_positive_reference':
          'neutral_unit_for_missing_zero_for_observed_unusable',
      'all_unknown_or_no_usable_portions': 'equal_neutral_unit_mass',
      'neutral_unit_mass': neutralUnitMass,
      'nonfinite_or_nonpositive_portions': 'zero_then_equal_weight_if_all_zero',
      'output_component_order': 'input_order',
      'synthesized_component_fraction': neutralUnitMass,
    },
    'missing_input_policy': <String, Object>{
      'preserve_upstream_missing_fields': true,
      'fat_fraction_missing_unless':
          'fat_grams_present_and_total_calories_strictly_positive',
      'total_calories_missing_unless_present': true,
      'fiber_grams_missing_when_band_unknown': true,
      'meal_physical_form_missing_for_unknown_synthesized_component': true,
      'portion_grams_missing_for_null_nonfinite_or_negative_portions': true,
    },
    'assumption_and_modifier_policy': <String, Object>{
      'numeric_decimal_places': assumptionNumericDecimalPlaces,
      'overlap_disclosed_when_strictly_greater_than':
          overlapDisclosureThreshold,
      'high_fat_emits_parameter_and_uncertainty_ids': true,
      'high_calorie_emits_uncertainty_id': true,
      'high_fiber_emits_slowdown_id_and_modifier': true,
      'fallbacks_remain_explicit': true,
    },
    'uncertainty_ordinal_score': <String, Object>{
      'composition_completeness_strict_lt': <double>[
        completeCompositionThreshold,
        mostlyCompleteCompositionThreshold,
        partialCompositionThreshold,
      ],
      'overlap_residual_load_strict_gt': <double>[
        firstOverlapThreshold,
        secondOverlapThreshold,
      ],
      'each_composition_threshold_increment': 1,
      'each_overlap_threshold_increment_source': 'ge.overlap.uncertainty_boost',
      'high_fiber_increment_source': 'ge.mixed_meal.uncertainty_boost',
      'high_fat_increment_source': 'ge.fat.uncertainty_boost',
      'high_calorie_increment_source': 'ge.highcal.uncertainty_boost',
      'band_mapping': <String, String>{
        '0': 'narrow',
        '1': 'moderate',
        '2': 'wide',
        '3_or_more': 'veryWide',
      },
    },
    'aggregate_policy': 'component_fraction_weighted_lag_and_half_time',
    'window_and_curve_contract_schema': GastricEmptyingOutputContract.schema,
  };

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

  Map<String, dynamic> get configuration => <String, dynamic>{
    r'$schema': configurationSchema,
    'parameters': parameters.toJson(),
    'generator_structure': generatorStructure,
    'output_integrity_contract':
        GastricEmptyingOutputContract.integrityConfiguration,
  };

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
        ? (composition.fatGrams! * fatCaloriesPerGram) /
              composition.totalCalories!
        : null;
    if (!fatFractionAvailable) missingInputs.add('fat_fraction_of_calories');

    final sizeAvailable = composition.totalCalories != null;
    if (!sizeAvailable) missingInputs.add('total_calories');

    double sizeMultiplier;
    if (sizeAvailable) {
      sizeMultiplier =
          sizeScaleIntercept +
          sizeScaleSlope *
              (composition.totalCalories! /
                  parameters.referenceMealCalories.value);
      sizeMultiplier = sizeMultiplier.clamp(sizeScaleMinimum, sizeScaleMaximum);
      assumptions.add(
        'ge.size.linear_scale (size multiplier ${sizeMultiplier.toStringAsFixed(assumptionNumericDecimalPlaces)})',
      );
    } else {
      sizeMultiplier = unknownSizeMultiplier;
      assumptions.add(
        'ge.size.unknown_default (size multiplier ${unknownSizeMultiplier.toStringAsFixed(assumptionNumericDecimalPlaces)}, uncertainty widened)',
      );
    }

    double fatMultiplier;
    final highFat =
        fatFraction != null &&
        fatFraction >= parameters.fatFractionThreshold.value;
    if (highFat) {
      fatMultiplier = parameters.fatSlowdownMultiplier.value;
      modifiers.add(
        'fat_slowdown_${fatMultiplier.toStringAsFixed(assumptionNumericDecimalPlaces)}x',
      );
      assumptions.add(parameters.fatSlowdownMultiplier.id);
      assumptions.add(
        '${parameters.fatUncertaintyBoost.id} (high fat, uncertainty widened)',
      );
    } else {
      fatMultiplier = neutralMultiplier;
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
    double fiberMultiplier = neutralMultiplier;
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
          fractionOfMeal: neutralUnitMass,
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
      var meanKnownPositiveMass = neutralUnitMass;
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
          : List<double>.filled(effectiveMasses.length, neutralUnitMass);
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

    if (overlappingResidualLoad > overlapDisclosureThreshold) {
      assumptions.add(
        'ge.overlap.cumulate (residual load ${overlappingResidualLoad.toStringAsFixed(assumptionNumericDecimalPlaces)}, uncertainty widened)',
      );
    }

    final uncertaintyBand = _uncertaintyBand(
      compositionCompleteness: composition.compositionCompleteness,
      overlappingResidualLoad: overlappingResidualLoad,
      highFiber: highFiber,
      highFat: highFat,
      highCalorie: highCalorie,
    );

    final derivedShape = deriveGastricProfileShape(
      componentProfiles.map(
        (component) => (
          fractionOfMeal: component.fractionOfMeal,
          lagMinutes: component.lagMinutes,
          halfEmptyingMinutes: component.halfEmptyingMinutes,
        ),
      ),
    );
    final aggregateLag = derivedShape.aggregateLagMinutes;
    final peakStart = mealStartMinute + aggregateLag.round();
    final peakEnd = peakStart + derivedShape.peakWindowDurationMinutes!;
    final mostlyEmptiedEnd =
        mealStartMinute +
        aggregateLag.round() +
        derivedShape.mostlyEmptiedWindowDurationMinutes!;

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
              ? parameters.solidLagMinutes.value * unknownFormLagMultiplier
              : parameters.solidLagMinutes.value);
    final baseHalf = isLiquid
        ? parameters.liquidHalfMinutes.value
        : (form == MealPhysicalForm.unknown
              ? parameters.solidHalfMinutes.value *
                    unknownFormHalfTimeMultiplier
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
    if (compositionCompleteness < completeCompositionThreshold) score += 1;
    if (compositionCompleteness < mostlyCompleteCompositionThreshold) {
      score += 1;
    }
    if (compositionCompleteness < partialCompositionThreshold) score += 1;
    if (overlappingResidualLoad > firstOverlapThreshold) {
      score += parameters.overlapUncertaintyBoost.value;
    }
    if (overlappingResidualLoad > secondOverlapThreshold) {
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
