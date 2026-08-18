import 'medication_entry_validation.dart';

/// Exact, deterministic active-ingredient tokenization for mechanistic model
/// identity checks.
///
/// Only explicit combination separators are split. Tags, aliases, brands, and
/// substring matches are deliberately outside this boundary: `levodopaLike`
/// and `not-levodopa` are not the active ingredient `levodopa`.
abstract final class CanonicalMedicationIngredientTokenizer {
  static final RegExp _componentSeparator = RegExp(r'[/+,]');
  static final RegExp _whitespace = RegExp(r'\s+');

  static String canonicalizeToken(String value) =>
      value.trim().toLowerCase().replaceAll(_whitespace, ' ');

  static List<String> tokenize(Iterable<String> ingredientValues) {
    final tokens = <String>{};
    for (final value in ingredientValues) {
      for (final component in value.split(_componentSeparator)) {
        final token = canonicalizeToken(component);
        if (token.isNotEmpty) tokens.add(token);
      }
    }
    return List.unmodifiable(tokens);
  }

  static bool containsExact(
    Iterable<String> ingredientValues,
    String expectedIngredient,
  ) {
    final expected = canonicalizeToken(expectedIngredient);
    return tokenize(ingredientValues).contains(expected);
  }
}

enum MechanisticReleaseProfile { immediate }

enum MechanisticMedicationApplicabilityStatus {
  applicable,
  notApplicable,
  insufficient,
}

/// Stable reason codes emitted when the levodopa-specific mechanistic model
/// abstains. They describe model applicability, not whether a medication entry
/// is generally valid for storage or for unrelated rule engines.
abstract final class MechanisticMedicationApplicabilityReason {
  static const String activeIngredientNotLevodopa =
      'mechanistic_applicability.active_ingredient_not_levodopa';
  static const String carbidopaComponentRequired =
      'mechanistic_applicability.carbidopa_component_required';
  static const String activeIngredientCombinationNotSupported =
      'mechanistic_applicability.active_ingredient_combination_not_supported';
  static const String routeNotSupported =
      'mechanistic_applicability.route_not_supported';
  static const String dosageFormNotSupported =
      'mechanistic_applicability.dosage_form_not_supported';
  static const String releaseTypeNotSupported =
      'mechanistic_applicability.release_type_not_supported';
}

final class MechanisticMedicationApplicability {
  final MechanisticMedicationApplicabilityStatus status;
  final MechanisticReleaseProfile? releaseProfile;
  final List<String> reasonCodes;

  MechanisticMedicationApplicability({
    required this.status,
    required this.releaseProfile,
    required List<String> reasonCodes,
  }) : reasonCodes = List.unmodifiable(reasonCodes);

  bool get applicable =>
      status == MechanisticMedicationApplicabilityStatus.applicable;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'applicable': applicable,
    'release_profile': releaseProfile?.name,
    'reason_codes': reasonCodes,
  };
}

/// Narrow context-of-use policy for the current levodopa absorption proxy.
///
/// This is intentionally separate from [MedicationEntryValidator]. A route or
/// formulation can be a legitimate medication record while still falling
/// outside the educational model's supported input domain.
final class MechanisticMedicationApplicabilityPolicy {
  const MechanisticMedicationApplicabilityPolicy();

  static const Set<String> _supportedRoutes = {'oral'};
  static const Set<String> _knownUnsupportedRoutes = {
    'transdermal',
    'intravenous',
    'intramuscular',
    'subcutaneous',
    'sublingual',
    'inhaled',
    'rectal',
  };
  static const Set<String> _supportedDosageForms = {'tablet'};
  static const Set<String> _knownUnsupportedDosageForms = {
    'capsule',
    'patch',
    'injection',
    'solution',
    'suspension',
    'film',
    'powder_for_solution',
  };
  static const Set<String> _immediateReleaseTypes = {
    'immediate',
    'immediate_release',
  };
  static const Set<String> _knownUnsupportedReleaseTypes = {
    'extended',
    'extended_release',
    'controlled',
    'controlled_release',
    'delayed',
    'delayed_release',
    'continuous',
    'rescue',
  };

  bool hasExactLevodopa(NormalizedMedicationContext context) =>
      CanonicalMedicationIngredientTokenizer.containsExact(
        context.activeIngredients,
        'levodopa',
      );

  MechanisticMedicationApplicability evaluate(
    NormalizedMedicationContext context,
  ) {
    final reasons = <String>[];
    var hasNotApplicableReason = false;
    var hasInsufficientReason = false;
    void addNotApplicable(String reason) {
      reasons.add(reason);
      hasNotApplicableReason = true;
    }

    void addInsufficient(String reason) {
      reasons.add(reason);
      hasInsufficientReason = true;
    }

    final ingredientTokens = CanonicalMedicationIngredientTokenizer.tokenize(
      context.activeIngredients,
    );
    if (!hasExactLevodopa(context)) {
      addInsufficient(
        MechanisticMedicationApplicabilityReason.activeIngredientNotLevodopa,
      );
    }
    if (!CanonicalMedicationIngredientTokenizer.containsExact(
      context.activeIngredients,
      'carbidopa',
    )) {
      addInsufficient(
        MechanisticMedicationApplicabilityReason.carbidopaComponentRequired,
      );
    }
    final containsRequiredCombination =
        ingredientTokens.contains('carbidopa') &&
        ingredientTokens.contains('levodopa');
    if (containsRequiredCombination && ingredientTokens.length > 2) {
      addNotApplicable(
        MechanisticMedicationApplicabilityReason
            .activeIngredientCombinationNotSupported,
      );
    } else if (!containsRequiredCombination || ingredientTokens.length != 2) {
      addInsufficient(
        MechanisticMedicationApplicabilityReason
            .activeIngredientCombinationNotSupported,
      );
    }

    final route = _canonicalVocabularyToken(context.route);
    if (!_supportedRoutes.contains(route)) {
      if (_knownUnsupportedRoutes.contains(route)) {
        addNotApplicable(
          MechanisticMedicationApplicabilityReason.routeNotSupported,
        );
      } else {
        addInsufficient(
          MechanisticMedicationApplicabilityReason.routeNotSupported,
        );
      }
    }

    final form = _canonicalVocabularyToken(context.form);
    if (!_supportedDosageForms.contains(form)) {
      if (_knownUnsupportedDosageForms.contains(form)) {
        addNotApplicable(
          MechanisticMedicationApplicabilityReason.dosageFormNotSupported,
        );
      } else {
        addInsufficient(
          MechanisticMedicationApplicabilityReason.dosageFormNotSupported,
        );
      }
    }

    final releaseType = _canonicalVocabularyToken(context.releaseType);
    final releaseProfile = _releaseProfile(releaseType);
    if (releaseProfile == null) {
      if (_knownUnsupportedReleaseTypes.contains(releaseType)) {
        addNotApplicable(
          MechanisticMedicationApplicabilityReason.releaseTypeNotSupported,
        );
      } else {
        addInsufficient(
          MechanisticMedicationApplicabilityReason.releaseTypeNotSupported,
        );
      }
    }

    return MechanisticMedicationApplicability(
      status: hasInsufficientReason
          ? MechanisticMedicationApplicabilityStatus.insufficient
          : hasNotApplicableReason
          ? MechanisticMedicationApplicabilityStatus.notApplicable
          : MechanisticMedicationApplicabilityStatus.applicable,
      releaseProfile: releaseProfile,
      reasonCodes: reasons,
    );
  }

  /// Evaluates a mixed medication timeline.
  ///
  /// The current boundary has no governed terminology capable of proving that
  /// an arbitrary non-target ingredient string is truly unrelated. Therefore
  /// every context must either be an exact supported carbidopa/levodopa event
  /// or the whole provider abstains. The categorical rule engine can continue
  /// handling other medicines independently.
  MechanisticMedicationApplicability evaluateContexts(
    Iterable<NormalizedMedicationContext> contexts,
  ) {
    final allContexts = contexts.toList(growable: false);
    if (allContexts.isEmpty) {
      return MechanisticMedicationApplicability(
        status: MechanisticMedicationApplicabilityStatus.insufficient,
        releaseProfile: null,
        reasonCodes: const [
          MechanisticMedicationApplicabilityReason.activeIngredientNotLevodopa,
        ],
      );
    }

    final reasons = <String>{};
    var hasTargetContext = false;
    var hasInsufficient = false;
    var hasNotApplicable = false;
    for (final context in allContexts) {
      if (!hasExactLevodopa(context)) {
        reasons.add(
          MechanisticMedicationApplicabilityReason.activeIngredientNotLevodopa,
        );
        hasInsufficient = true;
        continue;
      }
      hasTargetContext = true;
      final result = evaluate(context);
      reasons.addAll(result.reasonCodes);
      if (result.status ==
          MechanisticMedicationApplicabilityStatus.notApplicable) {
        hasNotApplicable = true;
      } else if (result.status ==
          MechanisticMedicationApplicabilityStatus.insufficient) {
        hasInsufficient = true;
      }
    }
    if (!hasTargetContext) {
      hasInsufficient = true;
    }
    final status = hasInsufficient
        ? MechanisticMedicationApplicabilityStatus.insufficient
        : hasNotApplicable
        ? MechanisticMedicationApplicabilityStatus.notApplicable
        : MechanisticMedicationApplicabilityStatus.applicable;
    return MechanisticMedicationApplicability(
      status: status,
      releaseProfile: null,
      reasonCodes: reasons.toList(growable: false),
    );
  }

  static String _canonicalVocabularyToken(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');

  static MechanisticReleaseProfile? _releaseProfile(String releaseType) {
    if (_immediateReleaseTypes.contains(releaseType)) {
      return MechanisticReleaseProfile.immediate;
    }
    return null;
  }
}
