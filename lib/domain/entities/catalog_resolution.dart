/// P2 — CatalogResolution entities.
///
/// Educational/research prototype only. The CatalogResolutionEngine resolves a
/// user-facing food/drug string into ranked, source-backed candidate records
/// with confidence, provenance, ambiguity handling, and unresolved reasons.
///
/// It is **NOT** a recommendation engine. It never tells the user what to eat,
/// what medication to take, when to take it, or how to dose. It does not infer
/// a user intake dose, does not silently guess, and is not clinically
/// calibrated. Dose-like text in a query is QUERY EVIDENCE only. No PHI /
/// patient / subject / encounter semantics.
library;

import 'rule_explanation.dart';

class CatalogResolutionDomain {
  static const String food = 'food';
  static const String drug = 'drug';
  static const String mixed = 'mixed';
  static const String unknown = 'unknown';
}

class CatalogResolutionStatus {
  static const String resolved = 'resolved';
  static const String ambiguous = 'ambiguous';
  static const String partial = 'partial';
  static const String unresolved = 'unresolved';
  static const String invalid = 'invalid';
}

class CatalogResolutionMatchType {
  static const String exactName = 'exact_name';
  static const String normalizedName = 'normalized_name';
  static const String synonym = 'synonym';
  static const String localizedName = 'localized_name';
  static const String brandName = 'brand_name';
  static const String genericName = 'generic_name';
  static const String activeIngredient = 'active_ingredient';
  static const String combinationProduct = 'combination_product';
  static const String releaseTypeHint = 'release_type_hint';
  static const String sourceIdentifier = 'source_identifier';
  static const String fuzzyToken = 'fuzzy_token';
  static const String category = 'category';
  static const String unknown = 'unknown';
}

class CatalogResolutionConfidenceBand {
  static const String high = 'high';
  static const String medium = 'medium';
  static const String low = 'low';
  static const String unknown = 'unknown';
}

class CatalogResolutionSeverity {
  static const String info = 'info';
  static const String warn = 'warn';
  static const String blocker = 'blocker';
}

class CatalogResolutionCandidate {
  final String candidateId;
  final String domain;
  final String displayName;
  final String canonicalName;
  final String matchType;
  final double confidence;
  final String confidenceBand;
  final int rank;
  final String sourceSystem;
  final String jurisdiction;
  final String locale;
  final List<String> sourceRefs;
  final double metadataCompleteness;
  final double? sourceAuthorityScore;
  final List<String> unresolvedReasons;
  final List<String> ambiguityWarnings;
  final String safetyBoundary;
  final String notAdviceText;

  // --- Food-only (null/empty for drug candidates) ---------------------------
  final String? foodItemId;
  final String? category;
  final String? portionBasis;
  final double? nutrientCompleteness;
  final String? nutrientProvenanceTier;

  // --- Drug-only (null/empty for food candidates) ---------------------------
  final String? drugProductId;
  final String? brandName;
  final String? genericName;
  final List<String> activeIngredients;
  final List<String> combinationComponents;
  final List<String> strengths;
  final String? doseForm;
  final String? route;
  final String? releaseType;
  final String? releaseTypeSource;
  final List<String> labelSectionRefs;

  const CatalogResolutionCandidate({
    required this.candidateId,
    required this.domain,
    required this.displayName,
    required this.canonicalName,
    required this.matchType,
    required this.confidence,
    required this.confidenceBand,
    required this.rank,
    this.sourceSystem = '',
    this.jurisdiction = '',
    this.locale = '',
    this.sourceRefs = const [],
    this.metadataCompleteness = 0.0,
    this.sourceAuthorityScore,
    this.unresolvedReasons = const [],
    this.ambiguityWarnings = const [],
    this.safetyBoundary = RuleExplanation.defaultSafetyBoundary,
    this.notAdviceText = RuleExplanation.defaultNotAdvice,
    this.foodItemId,
    this.category,
    this.portionBasis,
    this.nutrientCompleteness,
    this.nutrientProvenanceTier,
    this.drugProductId,
    this.brandName,
    this.genericName,
    this.activeIngredients = const [],
    this.combinationComponents = const [],
    this.strengths = const [],
    this.doseForm,
    this.route,
    this.releaseType,
    this.releaseTypeSource,
    this.labelSectionRefs = const [],
  });

  CatalogResolutionCandidate copyWith({int? rank, double? confidence}) =>
      CatalogResolutionCandidate(
        candidateId: candidateId,
        domain: domain,
        displayName: displayName,
        canonicalName: canonicalName,
        matchType: matchType,
        confidence: confidence ?? this.confidence,
        confidenceBand: confidenceBand,
        rank: rank ?? this.rank,
        sourceSystem: sourceSystem,
        jurisdiction: jurisdiction,
        locale: locale,
        sourceRefs: sourceRefs,
        metadataCompleteness: metadataCompleteness,
        sourceAuthorityScore: sourceAuthorityScore,
        unresolvedReasons: unresolvedReasons,
        ambiguityWarnings: ambiguityWarnings,
        safetyBoundary: safetyBoundary,
        notAdviceText: notAdviceText,
        foodItemId: foodItemId,
        category: category,
        portionBasis: portionBasis,
        nutrientCompleteness: nutrientCompleteness,
        nutrientProvenanceTier: nutrientProvenanceTier,
        drugProductId: drugProductId,
        brandName: brandName,
        genericName: genericName,
        activeIngredients: activeIngredients,
        combinationComponents: combinationComponents,
        strengths: strengths,
        doseForm: doseForm,
        route: route,
        releaseType: releaseType,
        releaseTypeSource: releaseTypeSource,
        labelSectionRefs: labelSectionRefs,
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'candidate_id': candidateId,
      'domain': domain,
      'display_name': displayName,
      'canonical_name': canonicalName,
      'match_type': matchType,
      'confidence': confidence,
      'confidence_band': confidenceBand,
      'rank': rank,
      'source_system': sourceSystem,
      'jurisdiction': jurisdiction,
      'locale': locale,
      'source_refs': sourceRefs,
      'metadata_completeness': metadataCompleteness,
      'source_authority_score': sourceAuthorityScore,
      'unresolved_reasons': unresolvedReasons,
      'ambiguity_warnings': ambiguityWarnings,
      'safety_boundary': safetyBoundary,
      'not_advice_text': notAdviceText,
    };
    if (domain == CatalogResolutionDomain.food) {
      m.addAll({
        'food_item_id': foodItemId,
        'category': category,
        'portion_basis': portionBasis,
        'nutrient_completeness': nutrientCompleteness,
        'nutrient_provenance_tier': nutrientProvenanceTier,
      });
    } else if (domain == CatalogResolutionDomain.drug) {
      m.addAll({
        'drug_product_id': drugProductId,
        'brand_name': brandName,
        'generic_name': genericName,
        'active_ingredients': activeIngredients,
        'combination_components': combinationComponents,
        'strengths': strengths,
        'dose_form': doseForm,
        'route': route,
        'release_type': releaseType,
        'release_type_source': releaseTypeSource,
        'label_section_refs': labelSectionRefs,
      });
    }
    return m;
  }
}

class CatalogResolutionIssue {
  final String severity;
  final String issueType;
  final String message;
  final String field;
  final String suggestedNextStep;
  final String safetyBoundary;

  const CatalogResolutionIssue({
    required this.severity,
    required this.issueType,
    required this.message,
    this.field = '',
    this.suggestedNextStep = '',
    this.safetyBoundary = RuleExplanation.defaultSafetyBoundary,
  });

  Map<String, dynamic> toJson() => {
        'severity': severity,
        'issue_type': issueType,
        'message': message,
        'field': field,
        'suggested_next_step': suggestedNextStep,
        'safety_boundary': safetyBoundary,
      };
}

class CatalogResolutionResult {
  static const String kReportType = 'catalog_resolution';

  final String query;
  final String normalizedQuery;
  final String domain;
  final String status;
  final CatalogResolutionCandidate? bestCandidate;
  final List<CatalogResolutionCandidate> candidates;
  final List<CatalogResolutionIssue> issues;
  final List<String> sourceRefs;
  final String safetyBoundary;
  final String notAdviceText;
  final bool notClinicallyCalibrated;
  final List<String> limitations;

  const CatalogResolutionResult({
    required this.query,
    required this.normalizedQuery,
    required this.domain,
    required this.status,
    required this.bestCandidate,
    required this.candidates,
    required this.issues,
    required this.sourceRefs,
    required this.safetyBoundary,
    required this.notAdviceText,
    required this.notClinicallyCalibrated,
    required this.limitations,
  });

  /// Whether the best candidate is safe to pass downstream as a structured
  /// catalog item (resolved, source-backed, unambiguous). This NEVER implies a
  /// dose or a recommendation.
  bool get safeToPassDownstream =>
      status == CatalogResolutionStatus.resolved &&
      bestCandidate != null &&
      bestCandidate!.sourceRefs.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'report_type': kReportType,
        'not_clinically_calibrated': notClinicallyCalibrated,
        'not_medical_advice': true,
        'no_dose_inference': true,
        'query': query,
        'normalized_query': normalizedQuery,
        'domain': domain,
        'status': status,
        'safe_to_pass_downstream': safeToPassDownstream,
        'best_candidate': bestCandidate?.toJson(),
        'candidates': candidates.map((c) => c.toJson()).toList(growable: false),
        'issues': issues.map((i) => i.toJson()).toList(growable: false),
        'source_refs': sourceRefs,
        'limitations': limitations,
        'safety_boundary': safetyBoundary,
        'not_advice_text': notAdviceText,
      };
}
