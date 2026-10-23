/// Next-meal planner (`next_meal_planner`).
///
/// Builds the food set the Next-meal page browses (one entry per food, at its
/// reference serving), the descriptive per-serving and per-plate values, and
/// the physiology reference model's comparison with "no meal" for the time
/// the user picked. Every value carries an availability state and reasons.
///
/// It orders nothing on its own: the default order is neutral (foods the user
/// logged before, then the rest, each by name) and any other order is the
/// user's sort choice. It names no best food or time. Deterministic: the
/// physiology bands use the provider's fixed seed and draw count, and values
/// are cached per food, serving and minute offset.
///
/// Educational research prototype; population-typical modeled values, not a
/// prediction for any person and not timing, dosing or dietary advice.
library;

import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../../core/models/user_profile.dart';
import '../entities/meal_composition.dart';
import '../entities/next_meal_plan.dart';
import '../entities/time_axis_events.dart';
import 'administration_dose_confirmation_coordinator.dart';
import 'catalog_food_to_candidate.dart';
import 'food_serving_reference_resolver.dart';
import 'intake_dose_context_builder.dart';
import 'physiology_reference_model.dart';
import 'physiology_reference_trace_provider.dart';

final class NextMealPlanner {
  NextMealPlanner({
    PhysiologyReferenceTraceProvider? physiology,
    AdministrationDoseConfirmationCoordinator? doseConfirmation,
  }) : physiology = physiology ?? PhysiologyReferenceTraceProvider.shared,
       _doseConfirmation =
           doseConfirmation ?? AdministrationDoseConfirmationCoordinator();

  final PhysiologyReferenceTraceProvider physiology;
  final AdministrationDoseConfirmationCoordinator _doseConfirmation;

  /// Plate servings move in these steps, from [minServings] to [maxServings].
  static const double servingStep = 0.5;
  static const double minServings = 0.5;
  static const double maxServings = 6.0;

  static const int _cacheLimit = 4096;
  final Map<String, double?> _centralCache = {};
  final Map<String, PhysiologyMealTimingComparison?> _bandCache = {};
  final Map<String, PhysiologyCurveComparison?> _curveCache = {};

  static final Map<String, double> _mixedProteinLnaaShare = () {
    final composition = PhysiologyParameterValues.central().map(
      'aa.mixed_protein_composition_g_per_g',
    );
    return {for (final a in physiologyLnaaSix) a: composition[a]!};
  }();

  // ---------------------------------------------------------------------------
  // Candidate set.
  // ---------------------------------------------------------------------------

  /// One candidate per food: duplicate ids and duplicate (source, code)
  /// records keep their first occurrence. Values are per reference serving.
  List<NextMealCandidate> buildCandidates({
    required List<FoodItem> foods,
    required List<Meal> history,
  }) {
    final timesLogged = <String, int>{};
    final lastLogged = <String, DateTime>{};
    for (final meal in history) {
      final at = meal.effectiveOccurredAt;
      for (final foodId in {for (final item in meal.items) item.foodId}) {
        timesLogged[foodId] = (timesLogged[foodId] ?? 0) + 1;
        final previous = lastLogged[foodId];
        if (previous == null || at.isAfter(previous)) lastLogged[foodId] = at;
      }
    }
    final seenIds = <String>{};
    final seenSources = <String>{};
    final candidates = <NextMealCandidate>[];
    for (final food in foods) {
      if (!seenIds.add(food.id)) continue;
      final code = food.sourceFoodCode?.trim() ?? '';
      if (code.isNotEmpty &&
          !seenSources.add('${food.sourceSystem.toUpperCase()}|$code')) {
        continue;
      }
      candidates.add(
        candidateFor(
          food,
          timesLogged: timesLogged[food.id] ?? 0,
          lastLoggedAt: lastLogged[food.id],
        ),
      );
    }
    return List.unmodifiable(candidates);
  }

  NextMealCandidate candidateFor(
    FoodItem food, {
    int timesLogged = 0,
    DateTime? lastLoggedAt,
  }) {
    final serving = foodServingReferenceFor(food);
    final component = foodItemToCandidateFood(
      food,
      servingReference: serving,
    ).components.single;
    final protein = component.proteinGrams;
    final energy = physiologyEnergyKcal(component);
    final profile = component.aminoAcidProfile;
    final double? lnaa;
    final NextMealLnaaBasis lnaaBasis;
    if (profile != null &&
        !profile.partial &&
        profile.presentLnaaFieldCount == 6) {
      lnaa = profile.competingLnaaGrams;
      lnaaBasis = NextMealLnaaBasis.measured;
    } else if (protein != null) {
      lnaa = _mixedProteinLnaaShare.values.fold<double>(
        0,
        (sum, share) => sum + protein * share,
      );
      lnaaBasis = NextMealLnaaBasis.estimatedFromProtein;
    } else {
      lnaa = null;
      lnaaBasis = NextMealLnaaBasis.unknown;
    }
    return NextMealCandidate(
      food: food,
      serving: serving,
      component: component,
      proteinG: protein,
      carbohydrateG: component.carbohydrateGrams,
      fatG: component.fatGrams,
      energyKcal: energy,
      energyDerived: component.calories == null && energy != null,
      lnaaG: lnaa,
      lnaaBasis: lnaaBasis,
      physicalForm: component.physicalForm,
      missingFields: [
        if (protein == null) NextMealDataFields.protein,
        if (component.carbohydrateGrams == null)
          NextMealDataFields.carbohydrate,
        if (component.fatGrams == null) NextMealDataFields.fat,
        if (energy == null) NextMealDataFields.energy,
        if (!serving.hasServing) NextMealDataFields.serving,
        if (food.textureClass == null) NextMealDataFields.texture,
      ],
      timesLogged: timesLogged,
      lastLoggedAt: lastLoggedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Dose context and time anchors.
  // ---------------------------------------------------------------------------

  static bool isLevodopaLike(DrugDefinition drug) =>
      drug.genericName.toLowerCase().contains('levodopa') ||
      drug.tags.contains(DrugTag.levodopaLike);

  List<Intake> _levodopaIntakes(
    List<DrugDefinition> drugs,
    List<Intake> intakes,
  ) {
    final ids = {
      for (final drug in drugs)
        if (isLevodopaLike(drug)) drug.id,
    };
    return [
      for (final intake in intakes)
        if (ids.contains(intake.drugId)) intake,
    ];
  }

  /// Logged levodopa intakes around [now], for the planned-time anchors.
  NextMealTimeAnchors anchors({
    required DateTime now,
    required List<DrugDefinition> drugs,
    required List<Intake> intakes,
  }) {
    DateTime? last;
    DateTime? next;
    for (final intake in _levodopaIntakes(drugs, intakes)) {
      final at = intake.takenAt;
      if (!at.isAfter(now)) {
        if (last == null || at.isAfter(last)) last = at;
      } else if (next == null || at.isBefore(next)) {
        next = at;
      }
    }
    return NextMealTimeAnchors(lastDoseAt: last, nextDoseAt: next);
  }

  /// The logged levodopa intake nearest to [plannedAt] (the later one on a
  /// tie, as in the meal check) and whether the model applies to it: oral immediate release, a
  /// confirmed dose bound to that intake, and a meal-to-dose offset inside the
  /// modeled range. The modeled ratios do not depend on the dose amount.
  NextMealDoseContext doseContext({
    required DateTime plannedAt,
    required List<DrugDefinition> drugs,
    required List<Intake> intakes,
    required String ownerScope,
    required DateTime observedAt,
  }) {
    if (!drugs.any(isLevodopaLike)) {
      return NextMealDoseContext(
        plannedAt: plannedAt,
        reasons: const [NextMealUnavailableReason.noLevodopaMedication],
      );
    }
    final candidates = _levodopaIntakes(drugs, intakes);
    if (candidates.isEmpty) {
      return NextMealDoseContext(
        plannedAt: plannedAt,
        reasons: const [NextMealUnavailableReason.noLoggedDose],
      );
    }
    Intake? nearest;
    var best = 0;
    for (final intake in candidates) {
      final distance = plannedAt.difference(intake.takenAt).inSeconds.abs();
      if (nearest == null ||
          distance < best ||
          (distance == best && intake.takenAt.isAfter(nearest.takenAt))) {
        nearest = intake;
        best = distance;
      }
    }
    final intake = nearest!;
    final drug = drugs.firstWhere((d) => d.id == intake.drugId);
    final reasons = <NextMealUnavailableReason>[];
    final formulation = resolveIntakeMechanisticFormulation(
      intake: intake,
      drug: drug,
    );
    if (formulation.route == 'unspecified' ||
        formulation.releaseType == 'unspecified') {
      reasons.add(NextMealUnavailableReason.formulationUnknown);
    } else if (formulation.route != 'oral' ||
        !const {
          'immediate',
          'immediate_release',
        }.contains(formulation.releaseType)) {
      reasons.add(NextMealUnavailableReason.notOralImmediateRelease);
    }
    final dose = _doseConfirmation.evaluateForResultUse(
      intake,
      ownerScope: ownerScope,
      observedAt: observedAt,
    );
    if (!dose.eligible) {
      reasons.add(NextMealUnavailableReason.doseNotConfirmed);
    }
    final offset = plannedAt.difference(intake.takenAt).inSeconds / 60.0;
    if (!PhysiologyReferenceTraceProvider.offsetInModeledRange(
      offset.roundToDouble(),
    )) {
      reasons.add(NextMealUnavailableReason.outsideModeledRange);
    }
    return NextMealDoseContext(
      plannedAt: plannedAt,
      reasons: List.unmodifiable(reasons),
      intake: intake,
      drug: drug,
    );
  }

  // ---------------------------------------------------------------------------
  // Totals and modeled effects.
  // ---------------------------------------------------------------------------

  /// Sums of the known values; an unknown value is counted, never added as 0.
  /// Totals are additive in servings.
  NextMealPlateTotals plateTotals(List<NextMealPlateItem> items) {
    NextMealNutrientTotal total(double? Function(NextMealCandidate) pick) {
      var known = 0.0;
      var unknown = 0;
      for (final item in items) {
        final value = pick(item.candidate);
        if (value == null) {
          unknown++;
        } else {
          known += value * item.servings;
        }
      }
      return NextMealNutrientTotal(known, unknown);
    }

    return NextMealPlateTotals(
      itemCount: items.length,
      protein: total((c) => c.proteinG),
      carbohydrate: total((c) => c.carbohydrateG),
      fat: total((c) => c.fatG),
      energy: total((c) => c.energyKcal),
      lnaa: total((c) => c.lnaaG),
    );
  }

  /// One food at one serving; central values only unless [withBand].
  NextMealModeledEffect candidateEffect(
    NextMealCandidate candidate,
    NextMealDoseContext context, {
    bool withBand = false,
  }) => plateEffect(
    [NextMealPlateItem(candidate, 1)],
    context,
    withBand: withBand,
  );

  /// Brain delivery of the whole plate relative to no meal. Foods without a
  /// recorded form are modeled as solid and as liquid and the value is the
  /// range between the two.
  NextMealModeledEffect plateEffect(
    List<NextMealPlateItem> items,
    NextMealDoseContext context, {
    bool withBand = true,
  }) {
    final prepared = _prepare(items, context);
    if (prepared.unavailable != null) return prepared.unavailable!;
    final offset = prepared.offset!;
    if (!withBand) {
      final values = [
        for (final scenario in prepared.scenarios)
          _cached(
            _centralCache,
            '${scenario.key}@$offset',
            () => physiology.centralBrainDeliveryRelative(
              scenario.components,
              offset.toDouble(),
            ),
          )!,
      ];
      return NextMealModeledEffect.modeled(
        bracketed: prepared.scenarios.length > 1,
        offsetMinutes: offset,
        centralLow: _min(values),
        centralHigh: _max(values),
      );
    }
    final comparisons = [
      for (final scenario in prepared.scenarios)
        _cached(
          _bandCache,
          '${scenario.key}@$offset',
          () => physiology.mealTimingComparison(
            scenario.components,
            offset.toDouble(),
          ),
        )!,
    ];
    return _effectOf(comparisons, offset);
  }

  /// Plasma levodopa and brain-entry index of the plate and of no meal over
  /// time relative to the dose, with population bands.
  NextMealPlateCurves plateCurves(
    List<NextMealPlateItem> items,
    NextMealDoseContext context,
  ) {
    final prepared = _prepare(items, context);
    if (prepared.unavailable != null) {
      return NextMealPlateCurves(
        effect: prepared.unavailable!,
        scenarios: const [],
        doseAt: context.doseAt,
      );
    }
    final offset = prepared.offset!;
    final scenarios = [
      for (final scenario in prepared.scenarios)
        _cached(
          _curveCache,
          '${scenario.key}@$offset',
          () =>
              physiology.compareCurves(scenario.components, offset.toDouble()),
        )!,
    ];
    return NextMealPlateCurves(
      effect: _effectOf([for (final s in scenarios) s.summary], offset),
      scenarios: List.unmodifiable(scenarios),
      doseAt: context.doseAt,
    );
  }

  NextMealModeledEffect _effectOf(
    List<PhysiologyMealTimingComparison> comparisons,
    int offset,
  ) {
    final central = [for (final c in comparisons) c.brainDeliveryCentral];
    final plasma = [for (final c in comparisons) c.plasmaCentral];
    return NextMealModeledEffect.modeled(
      bracketed: comparisons.length > 1,
      offsetMinutes: offset,
      centralLow: _min(central),
      centralHigh: _max(central),
      band: _envelope([for (final c in comparisons) c.brainDeliveryBand]),
      plasmaLow: _min(plasma),
      plasmaHigh: _max(plasma),
      plasmaBand: _envelope([for (final c in comparisons) c.plasmaBand]),
    );
  }

  _PreparedPlate _prepare(
    List<NextMealPlateItem> items,
    NextMealDoseContext context,
  ) {
    final offset = context.offsetMinutes;
    final eaten = [
      for (final item in items)
        if (item.servings > 0) item,
    ];
    if (eaten.isEmpty) {
      return _PreparedPlate.unavailable(
        NextMealModeledEffect.unavailable(const [
          NextMealUnavailableReason.emptyPlate,
        ], offsetMinutes: offset),
      );
    }
    if (!context.applicable) {
      return _PreparedPlate.unavailable(
        NextMealModeledEffect.unavailable(
          context.reasons,
          offsetMinutes: offset,
        ),
      );
    }
    final reasons = <NextMealUnavailableReason>[
      if (eaten.any((i) => i.candidate.proteinG == null))
        NextMealUnavailableReason.missingProtein,
      if (eaten.any((i) => i.candidate.energyKcal == null))
        NextMealUnavailableReason.missingEnergy,
    ];
    if (reasons.isNotEmpty) {
      return _PreparedPlate.unavailable(
        NextMealModeledEffect.unavailable(reasons, offsetMinutes: offset),
      );
    }
    final hasUnknownForm = eaten.any(
      (i) => i.candidate.physicalForm == MealPhysicalForm.unknown,
    );
    final assumptions = hasUnknownForm
        ? const [MealPhysicalForm.solid, MealPhysicalForm.liquid]
        : const [MealPhysicalForm.unknown];
    final ordered = [...eaten]
      ..sort((a, b) => a.candidate.id.compareTo(b.candidate.id));
    return _PreparedPlate(
      offset: offset!,
      scenarios: [
        for (final assumed in assumptions)
          _Scenario(
            key: [
              assumed.name,
              for (final item in ordered)
                '${_componentKey(item.candidate.component)}'
                    'x${item.servings}',
            ].join('|'),
            components: [
              for (final item in ordered)
                _scaled(
                  physiologyComponentFromFood(
                    item.candidate.component,
                    assumedForm: assumed,
                  )!,
                  item.servings,
                ),
            ],
          ),
      ],
    );
  }

  static String _componentKey(FoodComponent c) => [
    c.id,
    c.physicalForm.name,
    c.proteinGrams,
    c.carbohydrateGrams,
    c.fatGrams,
    c.calories,
    c.portionGrams,
    c.aminoAcidProfile == null ? 'mixed' : 'profile',
  ].join(':');

  static PhysiologyComponent _scaled(PhysiologyComponent c, double servings) =>
      servings == 1
      ? c
      : PhysiologyComponent(
          c.name,
          c.form,
          kcal: c.kcal * servings,
          proteinG: c.proteinG * servings,
          aminoAcidsG: c.aminoAcidsG == null
              ? null
              : {
                  for (final e in c.aminoAcidsG!.entries)
                    e.key: e.value * servings,
                },
          waterMl: c.waterMl * servings,
        );

  T? _cached<T>(Map<String, T?> cache, String key, T? Function() compute) {
    if (cache.containsKey(key)) return cache[key];
    if (cache.length >= _cacheLimit) cache.clear();
    return cache[key] = compute();
  }

  static double _min(List<double> xs) => xs.reduce((a, b) => a < b ? a : b);
  static double _max(List<double> xs) => xs.reduce((a, b) => a > b ? a : b);

  static PhysiologyBand _envelope(List<PhysiologyBand> bands) =>
      bands.length == 1
      ? bands.single
      : PhysiologyBand(
          _min([for (final b in bands) b.p05]),
          (_min([for (final b in bands) b.p50]) +
                  _max([for (final b in bands) b.p50])) /
              2,
          _max([for (final b in bands) b.p95]),
        );

  // ---------------------------------------------------------------------------
  // User-chosen filters and order.
  // ---------------------------------------------------------------------------

  static String textureFilterValue(FoodItem food) =>
      switch (food.textureClass) {
        null => NextMealTextureFilter.unknown,
        NextMealTextureFilter.liquid => NextMealTextureFilter.liquid,
        NextMealTextureFilter.soft => NextMealTextureFilter.soft,
        _ => NextMealTextureFilter.regular,
      };

  /// Whether the profile's swallowing-texture setting excludes [food]. A
  /// food without a recorded texture is never excluded.
  static bool excludedByTextureProfile(FoodItem food, String textureMode) {
    final texture = food.textureClass;
    if (texture == null) return false;
    return switch (textureMode) {
      'soft_or_liquid' => texture != 'soft' && texture != 'liquid',
      'liquid_only' => texture != 'liquid',
      _ => false,
    };
  }

  // ---------------------------------------------------------------------------
  // Region, availability and variety (nutrition only).
  // ---------------------------------------------------------------------------

  /// The user's regions: the content-jurisdiction override when set, else
  /// the registration and diet-profile regions from onboarding.
  static Set<String> userRegions(UserProfile profile) {
    final override = [
      for (final code in profile.contentJurisdictionOverride)
        if (code.trim().isNotEmpty) code.trim().toUpperCase(),
    ];
    if (override.isNotEmpty) return override.toSet();
    return {
      profile.registrationRegion.trim().toUpperCase(),
      if (profile.dietProfileRegion != null &&
          profile.dietProfileRegion!.trim().isNotEmpty)
        profile.dietProfileRegion!.trim().toUpperCase(),
    }..remove('');
  }

  /// The food's catalog source covers one of [regions].
  static bool listedInRegion(NextMealCandidate c, Set<String> regions) =>
      regions.contains(c.food.jurisdiction.toUpperCase());

  /// Regional evidence: listed in a source for one of [regions], or seen in
  /// the user's own logged or imported meals.
  static bool hasRegionalEvidence(NextMealCandidate c, Set<String> regions) =>
      c.familiar || listedInRegion(c, regions);

  /// Whole days between the last meal with this food and [now] (0 = today),
  /// or null when the food is not in the user's meals.
  static int? daysSinceLastEaten(NextMealCandidate c, DateTime now) {
    final last = c.lastLoggedAt;
    if (last == null) return null;
    final days = now.difference(last).inHours ~/ 24;
    return days < 0 ? 0 : days;
  }

  /// Protein tolerance for the same nutritional position: max(3 g, 30 %).
  static double proteinTolerance(double proteinG) =>
      (proteinG * 0.30) > 3.0 ? proteinG * 0.30 : 3.0;

  /// Energy tolerance: max(60 kcal, 30 %).
  static double energyTolerance(double energyKcal) =>
      (energyKcal * 0.30) > 60.0 ? energyKcal * 0.30 : 60.0;

  /// LNAA scale for closeness: max(0.3 g, 30 %).
  static double lnaaTolerance(double lnaaG) =>
      (lnaaG * 0.30) > 0.3 ? lnaaG * 0.30 : 0.3;

  /// Closeness of [alternative] to [original], 0–1:
  ///
  ///   1 − 0.5·|Δprotein|/tolP − 0.3·|Δenergy|/tolE − 0.2·min(1, |ΔLNAA|/tolL)
  ///
  /// with the tolerances of the original; an unknown LNAA counts as the
  /// full 0.2. A similarity, not a judgement that one food is better.
  static double alternativeCloseness(
    NextMealCandidate original,
    NextMealCandidate alternative,
  ) {
    final p0 = original.proteinG!;
    final e0 = original.energyKcal!;
    final dp = (alternative.proteinG! - p0).abs() / proteinTolerance(p0);
    final de = (alternative.energyKcal! - e0).abs() / energyTolerance(e0);
    final l0 = original.lnaaG;
    final l1 = alternative.lnaaG;
    final dl = l0 == null || l1 == null
        ? 1.0
        : ((l1 - l0).abs() / lnaaTolerance(l0)).clamp(0.0, 1.0);
    final score = 1.0 - 0.5 * dp - 0.3 * de - 0.2 * dl;
    return score.clamp(0.0, 1.0).toDouble();
  }

  /// Foods in the same nutritional position as [original]: the same food
  /// group, protein and energy per serving within [proteinTolerance] and
  /// [energyTolerance], and a texture the profile's setting does not
  /// exclude. Ordered by regional evidence, then closeness, then name and id.
  /// Empty when the original's protein or energy is unknown.
  List<NextMealAlternative> alternativesFor(
    NextMealCandidate original,
    List<NextMealCandidate> pool, {
    required String textureMode,
    required Set<String> regions,
    required String Function(NextMealCandidate) nameOf,
    int limit = 8,
  }) {
    final p0 = original.proteinG;
    final e0 = original.energyKcal;
    if (p0 == null || e0 == null) return const [];
    final originalName = nameOf(original).toLowerCase();
    final found = <NextMealAlternative>[];
    for (final c in pool) {
      final p = c.proteinG;
      final e = c.energyKcal;
      if (c.id == original.id ||
          c.food.category != original.food.category ||
          p == null ||
          e == null ||
          nameOf(c).toLowerCase() == originalName ||
          (p - p0).abs() > proteinTolerance(p0) ||
          (e - e0).abs() > energyTolerance(e0) ||
          excludedByTextureProfile(c.food, textureMode)) {
        continue;
      }
      final l0 = original.lnaaG;
      final l1 = c.lnaaG;
      found.add(
        NextMealAlternative(
          candidate: c,
          closeness: alternativeCloseness(original, c),
          proteinDeltaG: p - p0,
          energyDeltaKcal: e - e0,
          lnaaDeltaG: l0 == null || l1 == null ? null : l1 - l0,
          sameTexture:
              textureFilterValue(c.food) == textureFilterValue(original.food) &&
              c.food.iddsiLevel == original.food.iddsiLevel,
          completenessDelta: c.presentFieldCount - original.presentFieldCount,
          regionalEvidence: hasRegionalEvidence(c, regions),
        ),
      );
    }
    final names = {for (final a in found) a.candidate.id: nameOf(a.candidate)};
    found.sort((a, b) {
      if (a.regionalEvidence != b.regionalEvidence) {
        return a.regionalEvidence ? -1 : 1;
      }
      final c = b.closeness.compareTo(a.closeness);
      if (c != 0) return c;
      final n = names[a.candidate.id]!.toLowerCase().compareTo(
        names[b.candidate.id]!.toLowerCase(),
      );
      return n != 0 ? n : a.candidate.id.compareTo(b.candidate.id);
    });
    return List.unmodifiable(found.take(limit));
  }

  /// Filters, then orders by [sort] (ties by name, then id). [nameOf] gives
  /// the display name; [effectOf] the modeled effect for that sort.
  List<NextMealCandidate> arrange(
    List<NextMealCandidate> candidates, {
    required NextMealFilter filter,
    required NextMealSortKey sort,
    required bool descending,
    required String textureMode,
    required String Function(NextMealCandidate) nameOf,
    NextMealModeledEffect? Function(NextMealCandidate)? effectOf,
    Set<String> regions = const {},
    DateTime? now,
    int rotateUsedWithinDays = 0,
  }) {
    final query = filter.query.trim().toLowerCase();
    bool usedWithin(NextMealCandidate c, int days) {
      final days0 = now == null ? null : daysSinceLastEaten(c, now);
      return days > 0 && days0 != null && days0 < days;
    }

    final kept = [
      for (final c in candidates)
        if ((filter.groups.isEmpty ||
                filter.groups.contains(c.food.category)) &&
            (filter.textures.isEmpty ||
                filter.textures.contains(textureFilterValue(c.food))) &&
            (filter.regions.isEmpty ||
                filter.regions.contains(c.food.jurisdiction.toUpperCase())) &&
            (!filter.matchTextureProfile ||
                !excludedByTextureProfile(c.food, textureMode)) &&
            (!filter.completeDataOnly || c.completeData) &&
            (regions.isEmpty ||
                filter.includeOtherRegions ||
                hasRegionalEvidence(c, regions)) &&
            (!filter.seenInMyMealsOnly || c.familiar) &&
            !usedWithin(c, filter.hideUsedWithinDays) &&
            (query.isEmpty ||
                nameOf(c).toLowerCase().contains(query) ||
                c.food.searchableText.toLowerCase().contains(query)))
          c,
    ];
    final names = {for (final c in kept) c.id: nameOf(c).toLowerCase()};
    int byName(NextMealCandidate a, NextMealCandidate b) {
      final n = names[a.id]!.compareTo(names[b.id]!);
      return n != 0 ? n : a.id.compareTo(b.id);
    }

    // Unknown values sort last in either direction.
    final values = <String, double?>{};
    final double? Function(NextMealCandidate)? pick = switch (sort) {
      NextMealSortKey.proteinPerServing => (c) => c.proteinG,
      NextMealSortKey.energy => (c) => c.energyKcal,
      NextMealSortKey.modeledBrainEntry => (c) => effectOf?.call(c)?.sortValue,
      _ => null,
    };
    if (pick != null) {
      for (final c in kept) {
        values[c.id] = pick(c);
      }
    }
    final inRegion = {
      for (final c in kept) c.id: hasRegionalEvidence(c, regions),
    };
    final recent = {
      for (final c in kept) c.id: usedWithin(c, rotateUsedWithinDays),
    };
    kept.sort((a, b) {
      // "Vary my meals", when the user turns it on: foods eaten within the
      // chosen days go after the others, in any sort.
      if (recent[a.id] != recent[b.id]) return recent[a.id]! ? 1 : -1;
      switch (sort) {
        case NextMealSortKey.familiarThenName:
          if (a.familiar != b.familiar) return a.familiar ? -1 : 1;
          // The user's onboarding region comes next in the default order.
          if (regions.isNotEmpty && inRegion[a.id] != inRegion[b.id]) {
            return inRegion[a.id]! ? -1 : 1;
          }
          final n = byName(a, b);
          return descending ? -n : n;
        case NextMealSortKey.name:
          final n = byName(a, b);
          return descending ? -n : n;
        case NextMealSortKey.proteinPerServing:
        case NextMealSortKey.energy:
        case NextMealSortKey.modeledBrainEntry:
          final va = values[a.id];
          final vb = values[b.id];
          if (va == null || vb == null) {
            if (va == null && vb == null) return byName(a, b);
            return va == null ? 1 : -1;
          }
          final c = descending ? vb.compareTo(va) : va.compareTo(vb);
          return c != 0 ? c : byName(a, b);
      }
    });
    return kept;
  }
}

final class _Scenario {
  const _Scenario({required this.key, required this.components});
  final String key;
  final List<PhysiologyComponent> components;
}

final class _PreparedPlate {
  const _PreparedPlate({required this.offset, required this.scenarios})
    : unavailable = null;
  const _PreparedPlate.unavailable(NextMealModeledEffect this.unavailable)
    : offset = null,
      scenarios = const [];

  final int? offset;
  final List<_Scenario> scenarios;
  final NextMealModeledEffect? unavailable;
}
