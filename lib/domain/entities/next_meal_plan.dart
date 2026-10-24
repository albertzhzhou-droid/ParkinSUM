/// Value types of the Next-meal planner (`next_meal_planner`).
///
/// Everything here describes foods at a reference serving and a modeled
/// comparison with "no meal" for a time the user picked. Nothing is a
/// recommendation, a target, a ranking the user did not choose, or a
/// prediction for any person.
library;

import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../usecases/physiology_reference_trace_provider.dart';
import 'food_serving_reference.dart';
import 'meal_composition.dart';
import 'time_axis_events.dart';

/// Whether a modeled value can be shown.
enum NextMealModelAvailability {
  /// Every input the model needs is present.
  available,

  /// At least one food has no recorded physical form; the value is the range
  /// between modeling those foods as solid and as liquid.
  bracketed,

  /// An input is missing or the context is outside the model; see reasons.
  unavailable,
}

/// Why the planner cannot show a modeled value. Wire names are stable.
enum NextMealUnavailableReason {
  noLevodopaMedication('no_levodopa_medication'),
  noLoggedDose('no_logged_dose'),
  doseNotConfirmed('dose_not_confirmed'),
  formulationUnknown('formulation_unknown'),
  notOralImmediateRelease('not_oral_immediate_release'),
  outsideModeledRange('outside_modeled_range'),
  missingProtein('missing_protein'),
  missingEnergy('missing_energy'),
  emptyPlate('empty_plate');

  const NextMealUnavailableReason(this.wireName);
  final String wireName;
}

/// How the per-serving LNAA value was obtained.
enum NextMealLnaaBasis {
  /// From the food's measured amino-acid profile (all six present).
  measured,

  /// Protein × the physiology model's mixed-protein composition.
  estimatedFromProtein,

  /// Protein is unknown.
  unknown,
}

/// The fields counted by the data-completeness indicator.
abstract final class NextMealDataFields {
  static const protein = 'protein';
  static const carbohydrate = 'carbohydrate';
  static const fat = 'fat';
  static const energy = 'energy';
  static const serving = 'serving';
  static const texture = 'texture';

  static const all = [protein, carbohydrate, fat, energy, serving, texture];
}

/// One catalog food at its reference serving.
final class NextMealCandidate {
  const NextMealCandidate({
    required this.food,
    required this.serving,
    required this.component,
    required this.proteinG,
    required this.carbohydrateG,
    required this.fatG,
    required this.energyKcal,
    required this.energyDerived,
    required this.lnaaG,
    required this.lnaaBasis,
    required this.physicalForm,
    required this.missingFields,
    required this.timesLogged,
    required this.lastLoggedAt,
  });

  final FoodItem food;
  final FoodServingReference serving;

  /// The food at one serving as the physiology model reads it.
  final FoodComponent component;

  /// Per serving; null when the source has no value (never 0 for unknown).
  final double? proteinG;
  final double? carbohydrateG;
  final double? fatG;
  final double? energyKcal;

  /// Energy computed as 4/4/9 kcal per gram of protein, carbohydrate and fat
  /// because the source gives none.
  final bool energyDerived;

  /// Leucine, isoleucine, valine, phenylalanine, tyrosine and tryptophan.
  final double? lnaaG;
  final NextMealLnaaBasis lnaaBasis;
  final MealPhysicalForm physicalForm;

  /// Members of [NextMealDataFields.all] the source does not provide.
  final List<String> missingFields;

  /// How often the food appears in the user's own logged meals.
  final int timesLogged;
  final DateTime? lastLoggedAt;

  String get id => food.id;
  bool get familiar => timesLogged > 0;
  bool get completeData => missingFields.isEmpty;
  int get presentFieldCount =>
      NextMealDataFields.all.length - missingFields.length;
}

/// One food on the plate, in servings (0.5 steps).
final class NextMealPlateItem {
  const NextMealPlateItem(this.candidate, this.servings);

  final NextMealCandidate candidate;
  final double servings;

  NextMealPlateItem withServings(double value) =>
      NextMealPlateItem(candidate, value);
}

/// A sum over plate items. Unknown parts are counted, not added as zero.
final class NextMealNutrientTotal {
  const NextMealNutrientTotal(this.known, this.unknownItemCount);

  /// Sum of the items whose value is known.
  final double known;

  /// Items whose value is unknown and therefore not in [known].
  final int unknownItemCount;

  bool get complete => unknownItemCount == 0;
}

/// Running totals of a plate.
final class NextMealPlateTotals {
  const NextMealPlateTotals({
    required this.itemCount,
    required this.protein,
    required this.carbohydrate,
    required this.fat,
    required this.energy,
    required this.lnaa,
  });

  final int itemCount;
  final NextMealNutrientTotal protein;
  final NextMealNutrientTotal carbohydrate;
  final NextMealNutrientTotal fat;
  final NextMealNutrientTotal energy;
  final NextMealNutrientTotal lnaa;
}

/// The logged dose a planned meal is compared against.
final class NextMealDoseContext {
  const NextMealDoseContext({
    required this.plannedAt,
    required this.reasons,
    this.intake,
    this.drug,
  });

  final DateTime plannedAt;

  /// Empty when the model applies.
  final List<NextMealUnavailableReason> reasons;

  /// The levodopa intake nearest to [plannedAt] (the later one on a tie),
  /// when one is logged.
  final Intake? intake;
  final DrugDefinition? drug;

  bool get applicable => reasons.isEmpty;
  DateTime? get doseAt => intake?.takenAt;

  /// Meal start minus dose time in whole minutes.
  int? get offsetMinutes => intake == null
      ? null
      : (plannedAt.difference(intake!.takenAt).inSeconds / 60.0).round();
}

/// Modeled brain delivery (0–4 h area of plasma levodopa × brain-entry
/// index) and plasma levodopa area relative to no meal, as fractions.
final class NextMealModeledEffect {
  const NextMealModeledEffect._({
    required this.availability,
    required this.reasons,
    required this.offsetMinutes,
    required this.centralLow,
    required this.centralHigh,
    required this.band,
    required this.plasmaLow,
    required this.plasmaHigh,
    required this.plasmaBand,
  });

  factory NextMealModeledEffect.unavailable(
    List<NextMealUnavailableReason> reasons, {
    int? offsetMinutes,
  }) => NextMealModeledEffect._(
    availability: NextMealModelAvailability.unavailable,
    reasons: List.unmodifiable(reasons),
    offsetMinutes: offsetMinutes,
    centralLow: null,
    centralHigh: null,
    band: null,
    plasmaLow: null,
    plasmaHigh: null,
    plasmaBand: null,
  );

  /// [centralLow] equals [centralHigh] unless [bracketed].
  factory NextMealModeledEffect.modeled({
    required bool bracketed,
    required int offsetMinutes,
    required double centralLow,
    required double centralHigh,
    PhysiologyBand? band,
    double? plasmaLow,
    double? plasmaHigh,
    PhysiologyBand? plasmaBand,
  }) => NextMealModeledEffect._(
    availability: bracketed
        ? NextMealModelAvailability.bracketed
        : NextMealModelAvailability.available,
    reasons: const [],
    offsetMinutes: offsetMinutes,
    centralLow: centralLow,
    centralHigh: centralHigh,
    band: band,
    plasmaLow: plasmaLow,
    plasmaHigh: plasmaHigh,
    plasmaBand: plasmaBand,
  );

  final NextMealModelAvailability availability;
  final List<NextMealUnavailableReason> reasons;
  final int? offsetMinutes;

  /// Central-parameter brain delivery relative to no meal. A bracketed value
  /// spans the solid and the liquid assumption.
  final double? centralLow;
  final double? centralHigh;

  /// 5th–95th percentile of the seeded draws; for a bracketed value, the
  /// lowest 5th and the highest 95th percentile of both assumptions. Null
  /// when only central values were computed.
  final PhysiologyBand? band;

  /// Plasma levodopa area relative to no meal; null when not computed.
  final double? plasmaLow;
  final double? plasmaHigh;
  final PhysiologyBand? plasmaBand;

  bool get modeled => availability != NextMealModelAvailability.unavailable;
  bool get bracketed => availability == NextMealModelAvailability.bracketed;

  /// Midpoint used when the user sorts by the modeled effect.
  double? get sortValue => centralLow == null || centralHigh == null
      ? null
      : (centralLow! + centralHigh!) / 2;
}

/// Plate curves against no meal: one scenario, or two (unknown forms as
/// solid, then as liquid) when bracketed.
final class NextMealPlateCurves {
  const NextMealPlateCurves({
    required this.effect,
    required this.scenarios,
    required this.doseAt,
  });

  final NextMealModeledEffect effect;
  final List<PhysiologyCurveComparison> scenarios;
  final DateTime? doseAt;
}

/// User-chosen order. The default is neutral: foods the user has logged
/// before, then the rest, each by name.
enum NextMealSortKey {
  familiarThenName,
  name,
  proteinPerServing,
  modeledBrainEntry,
  energy,
}

/// Texture filter values; `unknown` is a food without a recorded texture.
abstract final class NextMealTextureFilter {
  static const liquid = 'liquid';
  static const soft = 'soft';
  static const regular = 'regular';
  static const unknown = 'unknown';
}

/// User-chosen filters. Empty sets mean "all".
final class NextMealFilter {
  const NextMealFilter({
    this.groups = const {},
    this.textures = const {},
    this.regions = const {},
    this.matchTextureProfile = false,
    this.completeDataOnly = false,
    this.query = '',
    this.includeOtherRegions = false,
    this.seenInMyMealsOnly = false,
    this.hideUsedWithinDays = 0,
  });

  final Set<FoodCategory> groups;
  final Set<String> textures;
  final Set<String> regions;

  /// Hide foods whose recorded texture the profile's swallowing-texture
  /// setting excludes. Foods without a recorded texture stay visible.
  final bool matchTextureProfile;
  final bool completeDataOnly;
  final String query;

  /// Show foods without regional evidence (see
  /// `NextMealPlanner.hasRegionalEvidence`). Off by default; the page states
  /// how many foods it leaves out.
  final bool includeOtherRegions;

  /// "Available in my region": only foods seen in the user's own logged or
  /// imported meals.
  final bool seenInMyMealsOnly;

  /// Hide foods eaten within this many days; 0 is off.
  final int hideUsedWithinDays;

  bool get active =>
      groups.isNotEmpty ||
      textures.isNotEmpty ||
      regions.isNotEmpty ||
      matchTextureProfile ||
      completeDataOnly ||
      query.trim().isNotEmpty ||
      includeOtherRegions ||
      seenInMyMealsOnly ||
      hideUsedWithinDays > 0;

  NextMealFilter copyWith({
    Set<FoodCategory>? groups,
    Set<String>? textures,
    Set<String>? regions,
    bool? matchTextureProfile,
    bool? completeDataOnly,
    String? query,
    bool? includeOtherRegions,
    bool? seenInMyMealsOnly,
    int? hideUsedWithinDays,
  }) => NextMealFilter(
    groups: groups ?? this.groups,
    textures: textures ?? this.textures,
    regions: regions ?? this.regions,
    matchTextureProfile: matchTextureProfile ?? this.matchTextureProfile,
    completeDataOnly: completeDataOnly ?? this.completeDataOnly,
    query: query ?? this.query,
    includeOtherRegions: includeOtherRegions ?? this.includeOtherRegions,
    seenInMyMealsOnly: seenInMyMealsOnly ?? this.seenInMyMealsOnly,
    hideUsedWithinDays: hideUsedWithinDays ?? this.hideUsedWithinDays,
  );
}

/// Quick anchors for the planned time, taken from logged doses only.
final class NextMealTimeAnchors {
  const NextMealTimeAnchors({this.lastDoseAt, this.nextDoseAt});

  /// The latest levodopa intake at or before now.
  final DateTime? lastDoseAt;

  /// The earliest levodopa intake logged after now.
  final DateTime? nextDoseAt;
}

/// One food in the same nutritional position as another, with the
/// differences per serving (alternative minus original). Nutrition only.
final class NextMealAlternative {
  const NextMealAlternative({
    required this.candidate,
    required this.closeness,
    required this.proteinDeltaG,
    required this.energyDeltaKcal,
    required this.lnaaDeltaG,
    required this.sameTexture,
    required this.completenessDelta,
    required this.regionalEvidence,
  });

  final NextMealCandidate candidate;

  /// 0–1; see `NextMealPlanner.alternativeCloseness`. A similarity to the
  /// original, not a ranking of better foods.
  final double closeness;
  final double proteinDeltaG;
  final double energyDeltaKcal;

  /// Null when either LNAA value is unknown.
  final double? lnaaDeltaG;
  final bool sameTexture;

  /// Present data fields of the alternative minus those of the original.
  final int completenessDelta;
  final bool regionalEvidence;
}
