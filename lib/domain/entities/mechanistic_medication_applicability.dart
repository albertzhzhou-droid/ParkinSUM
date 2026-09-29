import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'medication_entry_validation.dart';

enum MechanisticApplicabilityDisposition {
  supported,
  notApplicable,
  insufficient,
  blockedIntegrity,
}

enum MechanisticApplicabilityOutcomeStatus {
  satisfied,
  notApplicable,
  insufficient,
  blockedIntegrity,
}

/// One versioned predicate in the model's declared context of use.
final class MechanisticApplicabilityPredicateDefinition {
  final String id;
  final String label;
  final String inputField;
  final String supportedRule;
  final List<String> supportedValues;
  final String canonicalUnit;
  final MechanisticApplicabilityDisposition unknownDisposition;
  final MechanisticApplicabilityDisposition outsideDisposition;
  final MechanisticApplicabilityDisposition integrityDisposition;

  const MechanisticApplicabilityPredicateDefinition({
    required this.id,
    required this.label,
    required this.inputField,
    required this.supportedRule,
    this.supportedValues = const [],
    this.canonicalUnit = 'not_applicable',
    required this.unknownDisposition,
    required this.outsideDisposition,
    required this.integrityDisposition,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'input_field': inputField,
    'supported_rule': supportedRule,
    'supported_values': [...supportedValues]..sort(),
    'canonical_unit': canonicalUnit,
    'unknown_disposition': unknownDisposition.name,
    'outside_disposition': outsideDisposition.name,
    'integrity_disposition': integrityDisposition.name,
  };
}

/// Provider-level applicability declaration. A provider may consume only the
/// predicates listed here; adding or removing one changes the manifest digest.
final class MechanisticProviderApplicabilityDefinition {
  final String providerId;
  final String observable;
  final String claimClass;
  final String decisionInfluence;
  final List<String> predicateIds;
  final List<String> evidenceSourceIds;
  final String limitation;

  const MechanisticProviderApplicabilityDefinition({
    required this.providerId,
    required this.observable,
    required this.claimClass,
    required this.decisionInfluence,
    required this.predicateIds,
    required this.evidenceSourceIds,
    required this.limitation,
  });

  Map<String, dynamic> toJson() => {
    'provider_id': providerId,
    'observable': observable,
    'claim_class': claimClass,
    'decision_influence': decisionInfluence,
    'predicate_ids': [...predicateIds]..sort(),
    'evidence_source_ids': [...evidenceSourceIds]..sort(),
    'limitation': limitation,
  };
}

/// Immutable, digest-bound context-of-use declaration for the mechanistic
/// stack. It is intentionally a narrow engineering boundary, not a claim that
/// the model is clinically qualified or patient-specific.
final class MechanisticApplicabilityManifest {
  static const String schema = 'parkinsum.mechanistic-applicability-manifest/1';
  static const int schemaVersion = 1;
  static const String manifestId =
      'parkinsum.mechanistic-educational-timing-overlap';
  static const String manifestVersion = '2026.08.18-v1';

  final String questionOfInterest;
  final String contextOfUse;
  final String observableBoundary;
  final String populationBoundary;
  final String productIdentityBoundary;
  final String terminologyIdentity;
  final String fedStateBoundary;
  final String reviewState;
  final String reviewedAt;
  final List<MechanisticApplicabilityPredicateDefinition> predicates;
  final List<MechanisticProviderApplicabilityDefinition> providers;
  final List<String> evidenceSourceIds;

  MechanisticApplicabilityManifest._({
    required this.questionOfInterest,
    required this.contextOfUse,
    required this.observableBoundary,
    required this.populationBoundary,
    required this.productIdentityBoundary,
    required this.terminologyIdentity,
    required this.fedStateBoundary,
    required this.reviewState,
    required this.reviewedAt,
    required List<MechanisticApplicabilityPredicateDefinition> predicates,
    required List<MechanisticProviderApplicabilityDefinition> providers,
    required List<String> evidenceSourceIds,
  }) : predicates = List.unmodifiable(predicates),
       providers = List.unmodifiable(providers),
       evidenceSourceIds = List.unmodifiable(evidenceSourceIds) {
    _validate();
  }

  static final MechanisticApplicabilityManifest
  current = MechanisticApplicabilityManifest._(
    questionOfInterest:
        'For a synthetic or structurally verified narrow IR '
        'carbidopa/levodopa context, what unitless timing-overlap trace '
        'does the current engineering model produce?',
    contextOfUse:
        'Read-only educational sensitivity and explanation trace. The '
        'output must not prescribe timing, dose, diet, treatment, or '
        'reorder production recommendations.',
    observableBoundary:
        'Unitless timing-overlap proxy only; not absorbed fraction, plasma '
        'concentration, symptom response, efficacy, or safety.',
    populationBoundary:
        'No patient population is calibrated or predicted. Synthetic '
        'fixtures and structurally verified inputs only.',
    productIdentityBoundary:
        'Exact carbidopa plus levodopa, oral swallowed tablet, immediate '
        'release. Concrete product execution additionally requires '
        'internally consistent product/source/jurisdiction metadata; a '
        'governed external terminology and label-revision registry remains open.',
    terminologyIdentity:
        'parkinsum.local-mechanistic-vocabulary/1; exact canonical strings '
        'only, not RxNorm, ATC, UCUM, or regulatory equivalence.',
    fedStateBoundary:
        'A recorded causally prior meal still inside its explicit gastric '
        'residence horizon is required. Absence of a meal record is not '
        'interpreted as fasting.',
    reviewState: 'engineering_research_only_not_clinically_validated',
    reviewedAt: '2026-08-18',
    evidenceSourceIds: const [
      'src.dailymed.sinemet.label',
      'src.ema.pbpk.reporting.guideline',
      'src.fda.cms.credibility.guidance',
      'src.fda.pbpk.guidance',
      'src.hens.foodphysical.2024',
      'src.internal.prototype.heuristic',
    ],
    predicates: const [
      MechanisticApplicabilityPredicateDefinition(
        id: 'medication.active_components',
        label: 'Exact active-component set',
        inputField: 'medication.active_ingredients',
        supportedRule: 'exact_set',
        supportedValues: ['carbidopa', 'levodopa'],
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition: MechanisticApplicabilityDisposition.notApplicable,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
      MechanisticApplicabilityPredicateDefinition(
        id: 'medication.route',
        label: 'Administration route',
        inputField: 'medication.route',
        supportedRule: 'allowed_value',
        supportedValues: ['oral'],
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition: MechanisticApplicabilityDisposition.notApplicable,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
      MechanisticApplicabilityPredicateDefinition(
        id: 'medication.dosage_form',
        label: 'Dosage form',
        inputField: 'medication.form',
        supportedRule: 'allowed_value',
        supportedValues: ['tablet'],
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition: MechanisticApplicabilityDisposition.notApplicable,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
      MechanisticApplicabilityPredicateDefinition(
        id: 'medication.release_type',
        label: 'Release formulation',
        inputField: 'medication.release_type',
        supportedRule: 'canonical_equivalence_set',
        supportedValues: ['immediate', 'immediate_release'],
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition: MechanisticApplicabilityDisposition.notApplicable,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
      MechanisticApplicabilityPredicateDefinition(
        id: 'medication.explicit_dose',
        label: 'Explicit finite positive dose',
        inputField: 'medication.strength_and_unit',
        supportedRule: 'finite_positive_mass',
        canonicalUnit: 'mg',
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition: MechanisticApplicabilityDisposition.notApplicable,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
      MechanisticApplicabilityPredicateDefinition(
        id: 'meal.structured_composition',
        label: 'Structured non-empty meal composition',
        inputField: 'meal.composition',
        supportedRule: 'schema_valid_non_empty',
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition: MechanisticApplicabilityDisposition.insufficient,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
      MechanisticApplicabilityPredicateDefinition(
        id: 'meal.protein_evidence',
        label: 'Known finite meal protein',
        inputField: 'meal.composition.protein_g',
        supportedRule: 'finite_non_negative',
        canonicalUnit: 'g',
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition: MechanisticApplicabilityDisposition.notApplicable,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
      MechanisticApplicabilityPredicateDefinition(
        id: 'timeline.dose_time_meal_context',
        label: 'Causally prior dose-time meal context',
        inputField: 'timeline.meal_before_or_at_dose',
        supportedRule: 'recorded_and_within_residence_horizon',
        canonicalUnit: 'minute',
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition: MechanisticApplicabilityDisposition.insufficient,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
      MechanisticApplicabilityPredicateDefinition(
        id: 'timeline.identity_integrity',
        label: 'Canonical unique event and composition identity',
        inputField: 'timeline.ids',
        supportedRule: 'non_empty_unique_canonical',
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
      MechanisticApplicabilityPredicateDefinition(
        id: 'provider.upstream_availability',
        label: 'Complete typed upstream provider chain',
        inputField: 'provider.availability',
        supportedRule: 'all_upstream_available_and_structurally_coherent',
        unknownDisposition: MechanisticApplicabilityDisposition.insufficient,
        outsideDisposition: MechanisticApplicabilityDisposition.notApplicable,
        integrityDisposition:
            MechanisticApplicabilityDisposition.blockedIntegrity,
      ),
    ],
    providers: const [
      MechanisticProviderApplicabilityDefinition(
        providerId: 'meal_composition_normalizer',
        observable: 'structured composition with explicit missingness',
        claimClass: 'normalization',
        decisionInfluence: 'trace_only',
        predicateIds: ['meal.structured_composition'],
        evidenceSourceIds: ['src.hens.foodphysical.2024'],
        limitation:
            'Normalization preserves supplied structure and missingness; '
            'it is not a nutrient measurement.',
      ),
      MechanisticProviderApplicabilityDefinition(
        providerId: 'gastric_emptying',
        observable: 'unitless remaining and arrival sensitivity curves',
        claimClass: 'prototype_mechanistic_sensitivity',
        decisionInfluence: 'trace_only',
        predicateIds: [
          'meal.structured_composition',
          'timeline.identity_integrity',
        ],
        evidenceSourceIds: [
          'src.hens.foodphysical.2024',
          'src.internal.prototype.heuristic',
        ],
        limitation:
            'Not an individual gastric-emptying measurement or prediction.',
      ),
      MechanisticProviderApplicabilityDefinition(
        providerId: 'levodopa_absorption_opportunity',
        observable: 'unitless relative openness sensitivity curve',
        claimClass: 'prototype_timing_opportunity',
        decisionInfluence: 'trace_only',
        predicateIds: [
          'medication.active_components',
          'medication.dosage_form',
          'medication.explicit_dose',
          'medication.release_type',
          'medication.route',
          'provider.upstream_availability',
          'timeline.dose_time_meal_context',
          'timeline.identity_integrity',
        ],
        evidenceSourceIds: [
          'src.dailymed.sinemet.label',
          'src.fda.cms.credibility.guidance',
          'src.internal.prototype.heuristic',
        ],
        limitation:
            'Openness is not absorbed fraction, plasma concentration, or response.',
      ),
      MechanisticProviderApplicabilityDefinition(
        providerId: 'amino_acid_competition',
        observable: 'unitless timing-overlap pressure proxy',
        claimClass: 'prototype_competition_proxy',
        decisionInfluence: 'trace_only',
        predicateIds: [
          'meal.protein_evidence',
          'meal.structured_composition',
          'provider.upstream_availability',
          'timeline.identity_integrity',
        ],
        evidenceSourceIds: [
          'src.dailymed.sinemet.label',
          'src.internal.prototype.heuristic',
        ],
        limitation:
            'The proxy is not transporter occupancy or clinical response.',
      ),
      MechanisticProviderApplicabilityDefinition(
        providerId: 'mechanistic_conflict',
        observable: 'bounded unitless composite timing-overlap trace',
        claimClass: 'prototype_composite_trace',
        decisionInfluence: 'trace_only',
        predicateIds: [
          'meal.protein_evidence',
          'meal.structured_composition',
          'medication.active_components',
          'medication.dosage_form',
          'medication.explicit_dose',
          'medication.release_type',
          'medication.route',
          'provider.upstream_availability',
          'timeline.dose_time_meal_context',
          'timeline.identity_integrity',
        ],
        evidenceSourceIds: [
          'src.fda.cms.credibility.guidance',
          'src.internal.prototype.heuristic',
        ],
        limitation:
            'Composite output is not a patient-specific risk or treatment recommendation.',
      ),
      MechanisticProviderApplicabilityDefinition(
        providerId: 'mechanistic_candidate_scorer',
        observable: 'analysis-only candidate compatibility trace',
        claimClass: 'prototype_comparison_trace',
        decisionInfluence: 'analysis_only_no_production_reorder',
        predicateIds: [
          'meal.protein_evidence',
          'meal.structured_composition',
          'medication.active_components',
          'medication.dosage_form',
          'medication.explicit_dose',
          'medication.release_type',
          'medication.route',
          'provider.upstream_availability',
          'timeline.dose_time_meal_context',
          'timeline.identity_integrity',
        ],
        evidenceSourceIds: [
          'src.fda.cms.credibility.guidance',
          'src.internal.prototype.heuristic',
        ],
        limitation:
            'Diagnostic comparison only; it cannot reorder recommendations.',
      ),
    ],
  );

  Map<String, dynamic> get canonicalPayload => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'manifest_id': manifestId,
    'manifest_version': manifestVersion,
    'question_of_interest': questionOfInterest,
    'context_of_use': contextOfUse,
    'observable_boundary': observableBoundary,
    'population_boundary': populationBoundary,
    'product_identity_boundary': productIdentityBoundary,
    'terminology_identity': terminologyIdentity,
    'fed_state_boundary': fedStateBoundary,
    'review_state': reviewState,
    'reviewed_at': reviewedAt,
    'evidence_source_ids': [...evidenceSourceIds]..sort(),
    'predicates': (predicates.map((entry) => entry.toJson()).toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String))),
    'providers': (providers.map((entry) => entry.toJson()).toList()
      ..sort(
        (a, b) =>
            (a['provider_id'] as String).compareTo(b['provider_id'] as String),
      )),
  };

  String get canonicalJson => jsonEncode(_canonicalizeJson(canonicalPayload));

  String get sha256Digest =>
      sha256.convert(utf8.encode(canonicalJson)).toString();

  String get sourceRef => '$manifestId@$manifestVersion#sha256:$sha256Digest';

  Map<String, dynamic> toJson() => {
    ...canonicalPayload,
    'sha256': sha256Digest,
  };

  void _validate() {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(reviewedAt)) {
      throw ArgumentError.value(reviewedAt, 'reviewedAt');
    }
    final predicateIds = <String>{};
    for (final predicate in predicates) {
      if (predicate.id.trim() != predicate.id ||
          predicate.id.isEmpty ||
          !predicateIds.add(predicate.id)) {
        throw ArgumentError.value(predicate.id, 'predicates');
      }
    }
    final providerIds = <String>{};
    for (final provider in providers) {
      if (provider.providerId.trim() != provider.providerId ||
          provider.providerId.isEmpty ||
          !providerIds.add(provider.providerId)) {
        throw ArgumentError.value(provider.providerId, 'providers');
      }
      if (provider.predicateIds.isEmpty ||
          provider.predicateIds.any((id) => !predicateIds.contains(id)) ||
          provider.evidenceSourceIds.isEmpty) {
        throw ArgumentError.value(provider.providerId, 'providerContract');
      }
    }
    if (providers.isEmpty || predicates.isEmpty || evidenceSourceIds.isEmpty) {
      throw ArgumentError('Applicability manifest cannot be empty.');
    }
  }
}

final class MechanisticApplicabilityPredicateOutcome {
  final String predicateId;
  final MechanisticApplicabilityOutcomeStatus status;
  final String observedValue;
  final List<String> reasonCodes;

  MechanisticApplicabilityPredicateOutcome({
    required this.predicateId,
    required this.status,
    required this.observedValue,
    required List<String> reasonCodes,
  }) : reasonCodes = List.unmodifiable(reasonCodes);

  Map<String, dynamic> toJson() => {
    'predicate_id': predicateId,
    'status': status.name,
    'observed_value': observedValue,
    'reason_codes': reasonCodes,
  };
}

dynamic _canonicalizeJson(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalizeJson(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalizeJson).toList(growable: false);
  }
  if (value is num && !value.isFinite) {
    throw ArgumentError.value(value, 'manifest', 'Must be finite.');
  }
  return value;
}

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
  final List<MechanisticApplicabilityPredicateOutcome> predicateOutcomes;

  MechanisticMedicationApplicability({
    required this.status,
    required this.releaseProfile,
    required List<String> reasonCodes,
    required List<MechanisticApplicabilityPredicateOutcome> predicateOutcomes,
  }) : reasonCodes = List.unmodifiable(reasonCodes),
       predicateOutcomes = List.unmodifiable(predicateOutcomes);

  bool get applicable =>
      status == MechanisticMedicationApplicabilityStatus.applicable;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'applicable': applicable,
    'release_profile': releaseProfile?.name,
    'reason_codes': reasonCodes,
    'applicability_manifest_id': MechanisticApplicabilityManifest.manifestId,
    'applicability_manifest_version':
        MechanisticApplicabilityManifest.manifestVersion,
    'applicability_manifest_sha256':
        MechanisticApplicabilityManifest.current.sha256Digest,
    'predicate_outcomes': predicateOutcomes
        .map((outcome) => outcome.toJson())
        .toList(growable: false),
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
    final outcomes = <MechanisticApplicabilityPredicateOutcome>[];
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
    final hasLevodopa = hasExactLevodopa(context);
    final hasCarbidopa = CanonicalMedicationIngredientTokenizer.containsExact(
      context.activeIngredients,
      'carbidopa',
    );
    if (!hasLevodopa) {
      addInsufficient(
        MechanisticMedicationApplicabilityReason.activeIngredientNotLevodopa,
      );
    }
    if (!hasCarbidopa) {
      addInsufficient(
        MechanisticMedicationApplicabilityReason.carbidopaComponentRequired,
      );
    }
    final containsRequiredCombination = hasCarbidopa && hasLevodopa;
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
    final ingredientReasons = reasons
        .where(
          (reason) =>
              reason ==
                  MechanisticMedicationApplicabilityReason
                      .activeIngredientNotLevodopa ||
              reason ==
                  MechanisticMedicationApplicabilityReason
                      .carbidopaComponentRequired ||
              reason ==
                  MechanisticMedicationApplicabilityReason
                      .activeIngredientCombinationNotSupported,
        )
        .toList(growable: false);
    outcomes.add(
      MechanisticApplicabilityPredicateOutcome(
        predicateId: 'medication.active_components',
        status: ingredientReasons.isEmpty
            ? MechanisticApplicabilityOutcomeStatus.satisfied
            : containsRequiredCombination && ingredientTokens.length > 2
            ? MechanisticApplicabilityOutcomeStatus.notApplicable
            : MechanisticApplicabilityOutcomeStatus.insufficient,
        observedValue: ingredientTokens.isEmpty
            ? 'missing'
            : (ingredientTokens.toList()..sort()).join('+'),
        reasonCodes: ingredientReasons,
      ),
    );

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
    outcomes.add(
      MechanisticApplicabilityPredicateOutcome(
        predicateId: 'medication.route',
        status: _supportedRoutes.contains(route)
            ? MechanisticApplicabilityOutcomeStatus.satisfied
            : _knownUnsupportedRoutes.contains(route)
            ? MechanisticApplicabilityOutcomeStatus.notApplicable
            : MechanisticApplicabilityOutcomeStatus.insufficient,
        observedValue: route.isEmpty ? 'missing' : route,
        reasonCodes: _supportedRoutes.contains(route)
            ? const []
            : const [
                MechanisticMedicationApplicabilityReason.routeNotSupported,
              ],
      ),
    );

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
    outcomes.add(
      MechanisticApplicabilityPredicateOutcome(
        predicateId: 'medication.dosage_form',
        status: _supportedDosageForms.contains(form)
            ? MechanisticApplicabilityOutcomeStatus.satisfied
            : _knownUnsupportedDosageForms.contains(form)
            ? MechanisticApplicabilityOutcomeStatus.notApplicable
            : MechanisticApplicabilityOutcomeStatus.insufficient,
        observedValue: form.isEmpty ? 'missing' : form,
        reasonCodes: _supportedDosageForms.contains(form)
            ? const []
            : const [
                MechanisticMedicationApplicabilityReason.dosageFormNotSupported,
              ],
      ),
    );

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
    outcomes.add(
      MechanisticApplicabilityPredicateOutcome(
        predicateId: 'medication.release_type',
        status: releaseProfile != null
            ? MechanisticApplicabilityOutcomeStatus.satisfied
            : _knownUnsupportedReleaseTypes.contains(releaseType)
            ? MechanisticApplicabilityOutcomeStatus.notApplicable
            : MechanisticApplicabilityOutcomeStatus.insufficient,
        observedValue: releaseType.isEmpty ? 'missing' : releaseType,
        reasonCodes: releaseProfile != null
            ? const []
            : const [
                MechanisticMedicationApplicabilityReason
                    .releaseTypeNotSupported,
              ],
      ),
    );

    return MechanisticMedicationApplicability(
      status: hasInsufficientReason
          ? MechanisticMedicationApplicabilityStatus.insufficient
          : hasNotApplicableReason
          ? MechanisticMedicationApplicabilityStatus.notApplicable
          : MechanisticMedicationApplicabilityStatus.applicable,
      releaseProfile: releaseProfile,
      reasonCodes: reasons,
      predicateOutcomes: outcomes,
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
        predicateOutcomes: [
          MechanisticApplicabilityPredicateOutcome(
            predicateId: 'medication.active_components',
            status: MechanisticApplicabilityOutcomeStatus.insufficient,
            observedValue: 'missing',
            reasonCodes: const [
              MechanisticMedicationApplicabilityReason
                  .activeIngredientNotLevodopa,
            ],
          ),
        ],
      );
    }

    final reasons = <String>{};
    var hasTargetContext = false;
    var hasInsufficient = false;
    var hasNotApplicable = false;
    final outcomesByPredicate =
        <String, List<MechanisticApplicabilityPredicateOutcome>>{};
    for (final context in allContexts) {
      final result = evaluate(context);
      if (hasExactLevodopa(context)) hasTargetContext = true;
      reasons.addAll(result.reasonCodes);
      for (final outcome in result.predicateOutcomes) {
        (outcomesByPredicate[outcome.predicateId] ??= []).add(outcome);
      }
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
      predicateOutcomes:
          outcomesByPredicate.entries
              .map((entry) {
                final outcomes = entry.value;
                final statuses = outcomes
                    .map((outcome) => outcome.status)
                    .toSet();
                final status =
                    statuses.contains(
                      MechanisticApplicabilityOutcomeStatus.blockedIntegrity,
                    )
                    ? MechanisticApplicabilityOutcomeStatus.blockedIntegrity
                    : statuses.contains(
                        MechanisticApplicabilityOutcomeStatus.insufficient,
                      )
                    ? MechanisticApplicabilityOutcomeStatus.insufficient
                    : statuses.contains(
                        MechanisticApplicabilityOutcomeStatus.notApplicable,
                      )
                    ? MechanisticApplicabilityOutcomeStatus.notApplicable
                    : MechanisticApplicabilityOutcomeStatus.satisfied;
                final observed =
                    outcomes.map((outcome) => outcome.observedValue).toSet()
                      ..remove('');
                final outcomeReasons =
                    outcomes
                        .expand((outcome) => outcome.reasonCodes)
                        .toSet()
                        .toList()
                      ..sort();
                return MechanisticApplicabilityPredicateOutcome(
                  predicateId: entry.key,
                  status: status,
                  observedValue: (observed.toList()..sort()).join('|'),
                  reasonCodes: outcomeReasons,
                );
              })
              .toList(growable: false)
            ..sort(
              (left, right) => left.predicateId.compareTo(right.predicateId),
            ),
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
