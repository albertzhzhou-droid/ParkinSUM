/// P2 — CatalogResolutionEngine.
///
/// Educational/research prototype only. Deterministic, pure resolution of a
/// user-facing food/drug string into ranked, source-backed candidate records
/// with confidence, ambiguity handling, sourceRefs, jurisdiction/locale
/// context, and unresolved reasons.
///
/// It is **NOT** a recommendation engine. It never tells the user what to eat,
/// what medication to take, when to take it, or how to dose. It does not infer
/// a user intake dose (dose-like query text is QUERY EVIDENCE only), does not
/// silently guess (ambiguous input yields alternatives), does not fabricate
/// sourceRefs / completeness / authority, and is not clinically calibrated.
/// No PHI / patient / subject / encounter semantics.
library;

import 'dart:convert';

import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../entities/catalog_resolution.dart';
import '../entities/rule_explanation.dart';
import 'catalog_query_normalizer.dart';

/// Optional engine configuration (deterministic thresholds; no ML).
class CatalogResolutionConfig {
  /// Minimum confidence to keep a candidate at all.
  final double keepThreshold;

  /// Minimum confidence for the best candidate to be considered `resolved`.
  final double resolveThreshold;

  /// If the top two candidates are within this delta, the result is `ambiguous`.
  final double ambiguityDelta;

  const CatalogResolutionConfig({
    this.keepThreshold = 0.4,
    this.resolveThreshold = 0.8,
    this.ambiguityDelta = 0.08,
  });
}

class CatalogResolutionEngine {
  final CatalogQueryNormalizer _normalizer;

  const CatalogResolutionEngine({CatalogQueryNormalizer? normalizer})
      : _normalizer = normalizer ?? const CatalogQueryNormalizer();

  static const List<String> _limitations = [
    'Catalog resolution only; returns candidates + uncertainty, not a recommendation.',
    'Does not tell the user what to eat or what medication to take, and infers no user dose.',
    'Dose-like query text (e.g. 25/100) is query evidence, never a user intake dose.',
    'Does not silently guess; ambiguous input yields alternatives, not one overconfident answer.',
    'Synthetic/demo data only; sourceRefs/authority are read from catalogs, never fabricated; not clinically calibrated.',
  ];

  // Deterministic source-system → authority heuristic (NOT a trust certification;
  // seed/synthetic are intentionally capped well below official systems).
  static const Map<String, double> _authorityBySystem = {
    'dailymed': 0.95,
    'usda_fdc': 0.9,
    'ema': 0.9,
    'healthcanadadpd': 0.85,
    'pmda': 0.8,
    'ciqual': 0.8,
    'nhs_dmd': 0.8,
    'nmpa': 0.7,
    'china_food_composition': 0.7,
    'local_seed': 0.2,
    'app_seed': 0.2,
    'synthetic_demo': 0.1,
    'synthetic': 0.1,
  };

  CatalogResolutionResult resolve({
    required String query,
    List<FoodItem> foods = const [],
    List<DrugDefinition> drugs = const [],
    String locale = '',
    String jurisdiction = '',
    String? domainHint,
    Map<String, List<String>> synonyms = const {},
    Map<String, String> localizationDictionary = const {},
    CatalogResolutionConfig config = const CatalogResolutionConfig(),
  }) {
    final nq = _normalizer.normalize(query);
    final issues = <CatalogResolutionIssue>[];

    if (nq.isEmpty) {
      return _result(
        query: query,
        nq: nq,
        domain: CatalogResolutionDomain.unknown,
        status: CatalogResolutionStatus.invalid,
        candidates: const [],
        issues: [
          const CatalogResolutionIssue(
            severity: CatalogResolutionSeverity.blocker,
            issueType: 'empty_query',
            message: 'Empty query; nothing to resolve.',
            field: 'query',
            suggestedNextStep: 'Provide a non-empty food or drug name.',
          ),
        ],
      );
    }

    final q = nq.normalized;
    final raw = <CatalogResolutionCandidate>[];

    for (final f in foods) {
      final c = _matchFood(f, q, nq, locale, jurisdiction, synonyms,
          localizationDictionary, config);
      if (c != null) raw.add(c);
    }
    for (final d in drugs) {
      final c = _matchDrug(d, q, nq, locale, jurisdiction, synonyms,
          localizationDictionary, config);
      if (c != null) raw.add(c);
    }

    // Keep only candidates clearing the keep threshold.
    final kept = raw.where((c) => c.confidence >= config.keepThreshold).toList()
      ..sort((a, b) {
        final byConf = b.confidence.compareTo(a.confidence);
        if (byConf != 0) return byConf;
        return a.candidateId.compareTo(b.candidateId);
      });

    // Re-rank.
    final ranked = <CatalogResolutionCandidate>[];
    for (var i = 0; i < kept.length; i++) {
      ranked.add(kept[i].copyWith(rank: i + 1));
    }

    // Domain from matched candidates (final authority over the hint).
    final hasFood = ranked.any((c) => c.domain == CatalogResolutionDomain.food);
    final hasDrug = ranked.any((c) => c.domain == CatalogResolutionDomain.drug);
    final domain = (hasFood && hasDrug)
        ? CatalogResolutionDomain.mixed
        : hasFood
            ? CatalogResolutionDomain.food
            : hasDrug
                ? CatalogResolutionDomain.drug
                : (domainHint ?? CatalogResolutionDomain.unknown);

    // Status.
    String status;
    if (ranked.isEmpty) {
      status = CatalogResolutionStatus.unresolved;
      issues.add(const CatalogResolutionIssue(
        severity: CatalogResolutionSeverity.warn,
        issueType: 'no_catalog_match',
        message: 'No catalog candidate cleared the confidence threshold.',
        suggestedNextStep:
            'Refine the query or confirm a structured catalog item; this '
            'prototype does not guess.',
      ));
    } else {
      final best = ranked.first;
      final second = ranked.length > 1 ? ranked[1] : null;
      final close = second != null &&
          (best.confidence - second.confidence) <= config.ambiguityDelta;
      if (hasFood && hasDrug) {
        status = CatalogResolutionStatus.ambiguous;
        issues.add(const CatalogResolutionIssue(
          severity: CatalogResolutionSeverity.warn,
          issueType: 'mixed_domain',
          message: 'Query matched both food and drug catalogs (ambiguous '
              'domain).',
          suggestedNextStep: 'Disambiguate whether this is a food or a drug.',
        ));
      } else if (close) {
        status = CatalogResolutionStatus.ambiguous;
        issues.add(const CatalogResolutionIssue(
          severity: CatalogResolutionSeverity.warn,
          issueType: 'ambiguous_match',
          message: 'Multiple candidates have closely ranked confidence; '
              'resolution is ambiguous.',
          suggestedNextStep:
              'Present alternatives; do not auto-select one overconfident '
              'answer.',
        ));
      } else if (best.confidence < config.resolveThreshold ||
          best.matchType == CatalogResolutionMatchType.genericName ||
          best.matchType == CatalogResolutionMatchType.activeIngredient ||
          best.matchType == CatalogResolutionMatchType.fuzzyToken) {
        status = CatalogResolutionStatus.partial;
        issues.add(const CatalogResolutionIssue(
          severity: CatalogResolutionSeverity.info,
          issueType: 'partial_match',
          message: 'Best candidate is not a specific source-backed exact '
              'product/food match; treat as partial.',
          suggestedNextStep: 'Requires structured confirmation before use.',
        ));
      } else {
        status = CatalogResolutionStatus.resolved;
      }
    }

    return _result(
      query: query,
      nq: nq,
      domain: domain,
      status: status,
      candidates: ranked,
      issues: issues,
    );
  }

  // --- Food matching --------------------------------------------------------

  CatalogResolutionCandidate? _matchFood(
    FoodItem f,
    String q,
    NormalizedCatalogQuery nq,
    String locale,
    String jurisdiction,
    Map<String, List<String>> synonyms,
    Map<String, String> localizationDictionary,
    CatalogResolutionConfig config,
  ) {
    final cn = _normalizer.canonicalize(f.name);
    var matchType = CatalogResolutionMatchType.unknown;
    var base = 0.0;

    if (cn == q) {
      matchType = CatalogResolutionMatchType.exactName;
      base = 0.95;
    } else if (f.sourceFoodCode != null &&
        _normalizer.canonicalize(f.sourceFoodCode!) == q) {
      matchType = CatalogResolutionMatchType.sourceIdentifier;
      base = 0.9;
    } else {
      // Alias / localized / synonym matches.
      for (final a in f.aliases) {
        final na = _normalizer.canonicalize(a);
        if (na == q) {
          if (_hasCjk(a) || _hasCjk(q)) {
            matchType = CatalogResolutionMatchType.localizedName;
            base = 0.82;
          } else {
            matchType = CatalogResolutionMatchType.synonym;
            base = 0.78;
          }
          break;
        }
      }
      // Explicit localization dictionary (localized → canonical name/id).
      if (matchType == CatalogResolutionMatchType.unknown) {
        final mapped =
            localizationDictionary[nq.original] ?? localizationDictionary[q];
        if (mapped != null &&
            (mapped == f.id || _normalizer.canonicalize(mapped) == cn)) {
          matchType = CatalogResolutionMatchType.localizedName;
          base = 0.85;
        }
      }
      // Synonym map (canonical → synonyms).
      if (matchType == CatalogResolutionMatchType.unknown) {
        final syns = synonyms[cn] ?? synonyms[f.id] ?? const [];
        if (syns.map(_normalizer.canonicalize).contains(q)) {
          matchType = CatalogResolutionMatchType.synonym;
          base = 0.78;
        }
      }
      // Conservative fuzzy token overlap.
      if (matchType == CatalogResolutionMatchType.unknown) {
        final r = _tokenOverlap(nq.tokens, cn);
        if (r >= 0.5) {
          matchType = CatalogResolutionMatchType.fuzzyToken;
          base = 0.4 + 0.1 * r; // 0.45..0.5
        }
      }
    }

    if (matchType == CatalogResolutionMatchType.unknown) return null;

    final sourceRefs = _sourceRefs(f.sourceSystem, f.sourceFoodCode);
    final completeness = _foodCompleteness(f, sourceRefs);
    final warnings = <String>[];
    final unresolved = <String>[];
    var score = base;
    score = _applyCommonPenalties(
      score,
      jurisdiction: jurisdiction,
      candidateJurisdiction: f.jurisdiction,
      sourceRefs: sourceRefs,
      completeness: completeness,
      warnings: warnings,
      unresolved: unresolved,
    );

    return CatalogResolutionCandidate(
      candidateId: 'food:${f.id}',
      domain: CatalogResolutionDomain.food,
      displayName: f.name,
      canonicalName: cn,
      matchType: matchType,
      confidence: _clamp01(score),
      confidenceBand: _band(_clamp01(score)),
      rank: 0,
      sourceSystem: f.sourceSystem,
      jurisdiction: f.jurisdiction,
      locale: locale,
      sourceRefs: sourceRefs,
      metadataCompleteness: completeness,
      sourceAuthorityScore: _authority(f.sourceSystem),
      unresolvedReasons: unresolved,
      ambiguityWarnings: warnings,
      foodItemId: f.id,
      category: f.category.name,
      portionBasis: f.basisType,
      nutrientCompleteness: _nutrientCompleteness(f),
      nutrientProvenanceTier: f.qualifierKind,
    );
  }

  // --- Drug matching --------------------------------------------------------

  CatalogResolutionCandidate? _matchDrug(
    DrugDefinition d,
    String q,
    NormalizedCatalogQuery nq,
    String locale,
    String jurisdiction,
    Map<String, List<String>> synonyms,
    Map<String, String> localizationDictionary,
    CatalogResolutionConfig config,
  ) {
    final gn = _normalizer.canonicalize(d.genericName);
    final components = _splitComponents(d.genericName);
    var matchType = CatalogResolutionMatchType.unknown;
    var base = 0.0;
    String? matchedBrand;

    if (gn == q) {
      matchType = CatalogResolutionMatchType.exactName;
      base = 0.92;
    } else if (d.sourceProductCode != null &&
        _normalizer.canonicalize(d.sourceProductCode!) == q) {
      matchType = CatalogResolutionMatchType.sourceIdentifier;
      base = 0.9;
    } else {
      for (final b in d.brandNames) {
        if (_normalizer.canonicalize(b) == q) {
          matchType = CatalogResolutionMatchType.brandName;
          base = 0.88;
          matchedBrand = b;
          break;
        }
      }
      if (matchType == CatalogResolutionMatchType.unknown) {
        for (final a in d.aliases) {
          if (_normalizer.canonicalize(a) == q) {
            matchType = _hasCjk(a) || _hasCjk(q)
                ? CatalogResolutionMatchType.localizedName
                : CatalogResolutionMatchType.synonym;
            base = _hasCjk(a) || _hasCjk(q) ? 0.82 : 0.78;
            break;
          }
        }
      }
      // Combination: query mentions 2+ of the components.
      if (matchType == CatalogResolutionMatchType.unknown &&
          components.length > 1) {
        final qTokens = nq.tokens.toSet();
        final hit = components.where((c) => qTokens.contains(c)).length;
        if (hit >= 2) {
          matchType = CatalogResolutionMatchType.combinationProduct;
          base = 0.85;
        } else if (hit == 1) {
          matchType = CatalogResolutionMatchType.activeIngredient;
          base = 0.62;
        }
      }
      // Single active-ingredient match.
      if (matchType == CatalogResolutionMatchType.unknown &&
          components.contains(q)) {
        matchType = CatalogResolutionMatchType.activeIngredient;
        base = 0.62;
      }
      // Generic-name token containment (e.g. "levodopa" in "carbidopa/levodopa").
      if (matchType == CatalogResolutionMatchType.unknown &&
          nq.tokens.any((t) => components.contains(t))) {
        matchType = CatalogResolutionMatchType.activeIngredient;
        base = 0.6;
      }
      // Conservative fuzzy fallback.
      if (matchType == CatalogResolutionMatchType.unknown) {
        final r = _tokenOverlap(nq.tokens, gn);
        if (r >= 0.5) {
          matchType = CatalogResolutionMatchType.fuzzyToken;
          base = 0.4 + 0.1 * r;
        }
      }
    }

    if (matchType == CatalogResolutionMatchType.unknown) return null;

    // Release-type hint: reward a match, penalize a mismatch (deterministic).
    var releaseTypeSource = 'catalog';
    final hint = nq.releaseTypeHint;
    if (hint.isNotEmpty && d.releaseType.isNotEmpty) {
      final rt = d.releaseType.toLowerCase();
      if (rt == hint) {
        base += 0.08;
        releaseTypeSource = 'query_release_hint_match';
      } else {
        base -= 0.2;
        releaseTypeSource = 'query_release_hint_mismatch';
      }
    }

    final sourceRefs = _sourceRefs(d.sourceSystem, d.sourceProductCode);
    final completeness = _drugCompleteness(d, sourceRefs);
    final warnings = <String>[];
    final unresolved = <String>[];
    var score = _applyCommonPenalties(
      base,
      jurisdiction: jurisdiction,
      candidateJurisdiction: d.jurisdiction,
      sourceRefs: sourceRefs,
      completeness: completeness,
      warnings: warnings,
      unresolved: unresolved,
    );

    return CatalogResolutionCandidate(
      candidateId: 'drug:${d.id}',
      domain: CatalogResolutionDomain.drug,
      displayName: matchedBrand ?? d.genericName,
      canonicalName: gn,
      matchType: matchType,
      confidence: _clamp01(score),
      confidenceBand: _band(_clamp01(score)),
      rank: 0,
      sourceSystem: d.sourceSystem,
      jurisdiction: d.jurisdiction,
      locale: locale,
      sourceRefs: sourceRefs,
      metadataCompleteness: completeness,
      sourceAuthorityScore: _authority(d.sourceSystem),
      unresolvedReasons: unresolved,
      ambiguityWarnings: warnings,
      drugProductId: d.id,
      brandName: d.brandNames.isNotEmpty ? d.brandNames.first : null,
      genericName: d.genericName,
      activeIngredients: components,
      combinationComponents: components.length > 1 ? components : const [],
      // Strengths are NEVER inferred from the query's dose-like tokens; only a
      // structured catalog strength would populate this (none in this model).
      strengths: const [],
      doseForm: d.dosageForm.isEmpty ? null : d.dosageForm,
      route: d.route.isEmpty ? null : d.route,
      releaseType: d.releaseType.isEmpty ? null : d.releaseType,
      releaseTypeSource: releaseTypeSource,
      labelSectionRefs: const [],
    );
  }

  // --- helpers --------------------------------------------------------------

  double _applyCommonPenalties(
    double score, {
    required String jurisdiction,
    required String candidateJurisdiction,
    required List<String> sourceRefs,
    required double completeness,
    required List<String> warnings,
    required List<String> unresolved,
  }) {
    var s = score;
    final cj = candidateJurisdiction.toUpperCase();
    final rj = jurisdiction.toUpperCase();
    if (rj.isNotEmpty &&
        rj != 'GLOBAL' &&
        cj.isNotEmpty &&
        cj != 'GLOBAL' &&
        cj != rj) {
      s -= 0.2;
      warnings.add('jurisdiction_mismatch');
    }
    if (sourceRefs.isEmpty) {
      s -= 0.15;
      unresolved.add('missing_source_refs');
    }
    if (completeness < 0.5) {
      s -= 0.1;
      warnings.add('low_metadata_completeness');
    }
    return s;
  }

  List<String> _sourceRefs(String sourceSystem, String? code) {
    if (code == null || code.trim().isEmpty) return const [];
    return ['$sourceSystem:${code.trim()}'];
  }

  double _authority(String sourceSystem) =>
      _authorityBySystem[sourceSystem.toLowerCase()] ?? 0.3;

  double _foodCompleteness(FoodItem f, List<String> sourceRefs) {
    final present = <bool>[
      sourceRefs.isNotEmpty,
      f.jurisdiction.isNotEmpty && f.jurisdiction.toUpperCase() != 'GLOBAL',
      f.basisType != null && f.basisType!.isNotEmpty,
    ].where((b) => b).length;
    return present / 3.0;
  }

  double? _nutrientCompleteness(FoodItem f) {
    const fields = ['proteinG', 'carbsG', 'fatG', 'fiberG', 'sodiumMg'];
    final missing = f.missingNutrientFields.where(fields.contains).length;
    return (fields.length - missing) / fields.length;
  }

  double _drugCompleteness(DrugDefinition d, List<String> sourceRefs) {
    final present = <bool>[
      sourceRefs.isNotEmpty,
      d.jurisdiction.isNotEmpty && d.jurisdiction.toUpperCase() != 'GLOBAL',
      d.releaseType.isNotEmpty && d.releaseType.toLowerCase() != 'unknown',
      d.route.isNotEmpty,
    ].where((b) => b).length;
    return present / 4.0;
  }

  List<String> _splitComponents(String generic) => generic
      .toLowerCase()
      .split(RegExp(r'[\/+,]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  double _tokenOverlap(List<String> queryTokens, String candidateNorm) {
    if (queryTokens.isEmpty) return 0;
    final cTokens = candidateNorm.split(' ').where((t) => t.isNotEmpty).toSet();
    if (cTokens.isEmpty) return 0;
    final qSet = queryTokens.toSet();
    final shared = qSet.intersection(cTokens).length;
    final denom = qSet.length > cTokens.length ? qSet.length : cTokens.length;
    return shared / denom;
  }

  bool _hasCjk(String s) => s.runes.any((r) => r >= 0x3400);

  double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  String _band(double c) {
    if (c >= 0.8) return CatalogResolutionConfidenceBand.high;
    if (c >= 0.6) return CatalogResolutionConfidenceBand.medium;
    if (c >= 0.4) return CatalogResolutionConfidenceBand.low;
    return CatalogResolutionConfidenceBand.unknown;
  }

  CatalogResolutionResult _result({
    required String query,
    required NormalizedCatalogQuery nq,
    required String domain,
    required String status,
    required List<CatalogResolutionCandidate> candidates,
    required List<CatalogResolutionIssue> issues,
  }) {
    final allRefs = <String>{
      for (final c in candidates) ...c.sourceRefs,
    }.toList()
      ..sort();
    return CatalogResolutionResult(
      query: query,
      normalizedQuery: nq.normalized,
      domain: domain,
      status: status,
      bestCandidate: candidates.isEmpty ? null : candidates.first,
      candidates: candidates,
      issues: issues,
      sourceRefs: allRefs,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      notClinicallyCalibrated: true,
      limitations: _limitations,
    );
  }
}

/// Deterministic JSON encoder for a resolution result.
String encodeCatalogResolution(CatalogResolutionResult r) =>
    const JsonEncoder.withIndent('  ').convert(r.toJson());
