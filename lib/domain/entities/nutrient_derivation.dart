/// Per-nutrient provenance derived from USDA FoodData Central (FDC) nutrient
/// metadata. Educational prototype only — this is a *provenance* signal, NOT a
/// measurement-uncertainty estimate and NOT a clinical-accuracy claim.
///
/// FDC publishes, per nutrient value, a derivation (`foodNutrientDerivation`
/// with `code`/`description` and a nested `foodNutrientSource`), a sample count
/// (`dataPoints`), and optional `min`/`max`/`median`; foods carry a `dataType`
/// (Foundation / SR Legacy / Survey (FNDDS) / Branded). ParkinSUM consumes this
/// only to expose how a value was derived and to widen uncertainty when a value
/// is calculated/imputed rather than analytically measured. Missing provenance
/// stays missing (null) and never raises confidence.
///
/// Field names follow the documented FDC OpenAPI `FoodNutrient` family and the
/// FDC CSV "Download Field Descriptions" (food_nutrient.data_points /
/// derivation_id; food_nutrient_derivation.code/description;
/// food_nutrient_source.code/description; food.data_type). They are re-verified
/// against the live spec before any live ingestion (none today).
library;

/// Ordinal provenance tier. Higher up the list = stronger provenance.
/// This is a prototype-heuristic mapping of FDC derivation provenance to an
/// ordinal signal; it is not a quantitative uncertainty.
enum NutrientConfidenceTier {
  /// Analytically/directly measured.
  analytical,

  /// Calculated from other components / recipe / conversion.
  calculated,

  /// Imputed, assumed, or borrowed from a similar food.
  imputedOrAssumed,

  /// Derivation missing or unrecognized — provenance unknown.
  unknown,
}

/// Rank used for the conservative "weakest-wins" aggregate. Lower number =
/// stronger provenance; `unknown` is treated as the weakest.
int nutrientConfidenceRank(NutrientConfidenceTier t) {
  switch (t) {
    case NutrientConfidenceTier.analytical:
      return 0;
    case NutrientConfidenceTier.calculated:
      return 1;
    case NutrientConfidenceTier.imputedOrAssumed:
      return 2;
    case NutrientConfidenceTier.unknown:
      return 3;
  }
}

/// True for tiers that should widen modeled uncertainty (calculated/imputed/
/// unknown are weaker than a direct analytical measurement).
bool tierWidensUncertainty(NutrientConfidenceTier t) =>
    t != NutrientConfidenceTier.analytical;

/// Deterministic 0..1 **source-quality** signal for a nutrient confidence tier.
/// This describes how the value was *derived*, NOT clinical/biological accuracy.
/// Used for reporting/visibility (e.g. `FoodVariantMetadata.nutrientProvenanceQuality`);
/// it does not, by itself, change candidate ranking.
double nutrientProvenanceQualityFor(NutrientConfidenceTier t) {
  switch (t) {
    case NutrientConfidenceTier.analytical:
      return 1.0;
    case NutrientConfidenceTier.calculated:
      return 0.7;
    case NutrientConfidenceTier.imputedOrAssumed:
      return 0.4;
    case NutrientConfidenceTier.unknown:
      return 0.2;
  }
}

/// Non-prescriptive source-quality caution for a weaker-than-analytical tier, or
/// null for analytical (no caution needed). Never a clinical claim.
String? nutrientProvenanceLimitationFor(NutrientConfidenceTier t) {
  if (t == NutrientConfidenceTier.analytical) return null;
  return 'Amino-acid/nutrient values are ${t.name}-derived (a source-quality '
      'signal, not clinical accuracy); modeled confidence is lowered, not the '
      'value itself.';
}

class NutrientDerivation {
  /// FDC `foodNutrientDerivation.code` (e.g. analytical / calculated codes).
  final String? derivationCode;

  /// Human-readable FDC derivation description.
  final String? derivationDescription;

  /// FDC `foodNutrientSource.code`.
  final String? sourceCode;

  /// FDC `dataPoints` — number of observations. Null = unknown (NOT zero;
  /// an unknown sample count never raises confidence).
  final int? dataPoints;

  final double? min;
  final double? max;
  final double? median;

  const NutrientDerivation({
    this.derivationCode,
    this.derivationDescription,
    this.sourceCode,
    this.dataPoints,
    this.min,
    this.max,
    this.median,
  });

  /// Map the FDC derivation code/description to an ordinal confidence tier.
  /// Deterministic and conservative: an unrecognized/absent code → `unknown`,
  /// and a missing `dataPoints` never raises the tier. Documented against
  /// `src.usda.fdc.foundation_docs`.
  NutrientConfidenceTier get tier {
    final code = (derivationCode ?? '').toUpperCase().trim();
    final desc = (derivationDescription ?? '').toLowerCase();

    // Analytical / directly measured.
    if (code == 'A' ||
        code == 'AR' ||
        code == 'BFFN' ||
        desc.contains('analy') ||
        desc.contains('measured') ||
        desc.contains('determined')) {
      return NutrientConfidenceTier.analytical;
    }
    // Calculated / derived from other components or recipe.
    if (code == 'NC' ||
        code == 'NR' ||
        code == 'CAL' ||
        code == 'LCCD' ||
        desc.contains('calculat') ||
        desc.contains('derived') ||
        desc.contains('recipe') ||
        desc.contains('summed')) {
      return NutrientConfidenceTier.calculated;
    }
    // Imputed / assumed / borrowed.
    if (code == 'I' ||
        code == 'BFZN' ||
        code == 'AS' ||
        desc.contains('impute') ||
        desc.contains('assumed') ||
        desc.contains('borrowed') ||
        desc.contains('similar')) {
      return NutrientConfidenceTier.imputedOrAssumed;
    }
    return NutrientConfidenceTier.unknown;
  }

  static NutrientDerivation fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    double? asDouble(Object? v) => v is num ? v.toDouble() : null;
    return NutrientDerivation(
      derivationCode: json['derivation_code'] as String?,
      derivationDescription: json['derivation_description'] as String?,
      sourceCode: json['source_code'] as String?,
      dataPoints: asInt(json['data_points']),
      min: asDouble(json['min']),
      max: asDouble(json['max']),
      median: asDouble(json['median']),
    );
  }

  Map<String, dynamic> toJson() => {
        'derivation_code': derivationCode,
        'derivation_description': derivationDescription,
        'source_code': sourceCode,
        'data_points': dataPoints,
        'min': min,
        'max': max,
        'median': median,
        'tier': tier.name,
      };
}

/// Conservative "weakest-wins" aggregate over a set of per-nutrient
/// derivations. Returns null when the set is empty (no provenance to report —
/// missing ≠ a confident value).
NutrientConfidenceTier? weakestConfidenceTier(
    Iterable<NutrientDerivation> derivations) {
  NutrientConfidenceTier? worst;
  for (final d in derivations) {
    final t = d.tier;
    if (worst == null ||
        nutrientConfidenceRank(t) > nutrientConfidenceRank(worst)) {
      worst = t;
    }
  }
  return worst;
}
