import '../../../domain/entities/amino_acid_profile.dart';

/// Deterministic extractor for per-food amino-acid nutrients from an
/// FDC-style payload (`foodNutrients` list with nutrient number/name/unit +
/// amount). Preserves nutrient ids and source refs. Returns null when no
/// amino-acid fields are present so the LNAA layer can fall back to the
/// protein-source proxy. No network. Educational prototype; synthetic only.
class AminoAcidExtractor {
  /// USDA FoodData Central amino-acid nutrient numbers (verified):
  /// 501 Tryptophan, 502 Threonine, 503 Isoleucine, 504 Leucine,
  /// 505 Lysine, 506 Methionine, 507 Cystine, 508 Phenylalanine,
  /// 509 Tyrosine, 510 Valine, 511 Arginine, 512 Histidine.
  /// Number mapping takes priority over name fallback.
  static const Map<String, String> _numberToField = {
    '501': 'tryptophan',
    '502': 'threonine',
    '503': 'isoleucine',
    '504': 'leucine',
    '505': 'lysine',
    '506': 'methionine',
    '507': 'cystine',
    '508': 'phenylalanine',
    '509': 'tyrosine',
    '510': 'valine',
    '511': 'arginine',
    '512': 'histidine',
  };

  AminoAcidProfile? extractFromFdcStyle(
    Map<String, dynamic> payload, {
    List<String> sourceRefs = const ['src.fdc.api.amino_acid_fields'],
  }) {
    final nutrients = payload['foodNutrients'];
    if (nutrients is! List) return null;

    double? leucine,
        isoleucine,
        valine,
        phenylalanine,
        tyrosine,
        tryptophan,
        histidine,
        methionine,
        threonine,
        lysine,
        cystine,
        arginine;
    final ids = <String>[];
    // Basis follows the payload when present (FDC Foundation/SR are per_100g);
    // defaults to per_100g only when the payload does not declare one.
    final basis = (payload['basisType'] is String &&
            (payload['basisType'] as String).trim().isNotEmpty)
        ? payload['basisType'] as String
        : 'per_100g';
    // Optional FDC food data type (Foundation / SR Legacy / Survey / Branded).
    final fdcDataType = (payload['dataType'] is String &&
            (payload['dataType'] as String).trim().isNotEmpty)
        ? payload['dataType'] as String
        : null;
    // After normalization all values are expressed in grams.
    const unit = 'g';
    var partial = false;
    final derivations = <String, NutrientDerivation>{};

    void assign(String field, double valueG, String number) {
      switch (field) {
        case 'leucine':
          leucine = valueG;
          break;
        case 'isoleucine':
          isoleucine = valueG;
          break;
        case 'valine':
          valine = valueG;
          break;
        case 'phenylalanine':
          phenylalanine = valueG;
          break;
        case 'tyrosine':
          tyrosine = valueG;
          break;
        case 'tryptophan':
          tryptophan = valueG;
          break;
        case 'histidine':
          histidine = valueG;
          break;
        case 'methionine':
          methionine = valueG;
          break;
        case 'threonine':
          threonine = valueG;
          break;
        case 'lysine':
          lysine = valueG;
          break;
        case 'cystine':
          cystine = valueG;
          break;
        case 'arginine':
          arginine = valueG;
          break;
        default:
          return;
      }
      ids.add(number.isEmpty ? 'name:$field' : number);
    }

    for (final raw in nutrients) {
      if (raw is! Map) continue;
      final nutrient = raw['nutrient'];
      if (nutrient is! Map) continue;
      final number = (nutrient['number'] ?? '').toString();
      final name = (nutrient['name'] ?? '').toString().toLowerCase();
      final amount = raw['amount'];
      if (amount is! num) continue;
      final field = _numberToField[number] ?? _nameToField(name);
      if (field == null) continue;

      final unitName = (nutrient['unitName'] ?? '').toString().toLowerCase();
      final normalized = _toGrams(amount.toDouble(), unitName);
      if (normalized == null) {
        // No / unrecognized unit: accept the raw value provisionally but mark
        // the whole profile partial (lower confidence; never trusted as exact).
        partial = true;
        assign(field, amount.toDouble(), number);
      } else {
        assign(field, normalized, number);
      }

      // Capture FDC per-nutrient provenance when present (additive; missing
      // stays missing — never fabricated). Keyed by amino-acid field name.
      final derivation = _extractDerivation(raw);
      if (derivation != null) derivations[field] = derivation;
    }

    final profile = AminoAcidProfile(
      leucine: leucine,
      isoleucine: isoleucine,
      valine: valine,
      phenylalanine: phenylalanine,
      tyrosine: tyrosine,
      tryptophan: tryptophan,
      histidine: histidine,
      methionine: methionine,
      threonine: threonine,
      lysine: lysine,
      cystine: cystine,
      arginine: arginine,
      unit: unit,
      basis: basis,
      nutrientIds: List.unmodifiable(ids),
      sourceRefs: sourceRefs,
      partial: partial,
      derivations: Map.unmodifiable(derivations),
      fdcDataType: fdcDataType,
    );
    return profile.competingLnaaGrams == null ? null : profile;
  }

  /// Extract an FDC `foodNutrientDerivation` / `dataPoints` / `foodNutrientSource`
  /// block from a single `foodNutrients` entry. Returns null when no provenance
  /// fields are present (missing ≠ fabricated). Field names follow the FDC
  /// OpenAPI `FoodNutrient` family.
  NutrientDerivation? _extractDerivation(Map raw) {
    final derivation = raw['foodNutrientDerivation'];
    final dataPoints = raw['dataPoints'];
    final min = raw['min'];
    final max = raw['max'];
    final median = raw['median'];
    String? code;
    String? description;
    String? sourceCode;
    if (derivation is Map) {
      code = derivation['code']?.toString();
      description = derivation['description']?.toString();
      final source = derivation['foodNutrientSource'];
      if (source is Map) sourceCode = source['code']?.toString();
    }
    final hasAny = code != null ||
        description != null ||
        sourceCode != null ||
        dataPoints is num ||
        min is num ||
        max is num ||
        median is num;
    if (!hasAny) return null;
    return NutrientDerivation(
      derivationCode: code,
      derivationDescription: description,
      sourceCode: sourceCode,
      dataPoints: dataPoints is num ? dataPoints.toInt() : null,
      min: min is num ? min.toDouble() : null,
      max: max is num ? max.toDouble() : null,
      median: median is num ? median.toDouble() : null,
    );
  }

  /// Normalize an amino-acid amount to grams. Returns null when the unit is
  /// missing/unrecognized so the caller can mark the profile partial.
  double? _toGrams(double amount, String unitName) {
    switch (unitName) {
      case 'g':
      case 'gram':
      case 'grams':
        return amount;
      case 'mg':
      case 'milligram':
      case 'milligrams':
        return amount / 1000.0;
      default:
        return null;
    }
  }

  String? _nameToField(String name) {
    if (name.contains('leucine') && !name.contains('iso')) return 'leucine';
    if (name.contains('isoleucine')) return 'isoleucine';
    if (name.contains('valine')) return 'valine';
    if (name.contains('phenylalanine')) return 'phenylalanine';
    if (name.contains('tyrosine')) return 'tyrosine';
    if (name.contains('tryptophan')) return 'tryptophan';
    if (name.contains('histidine')) return 'histidine';
    if (name.contains('methionine')) return 'methionine';
    if (name.contains('threonine')) return 'threonine';
    if (name.contains('lysine')) return 'lysine';
    // Match cystine (the 507 dimer); avoid matching "cysteine".
    if (name.contains('cystine')) return 'cystine';
    if (name.contains('arginine')) return 'arginine';
    return null;
  }
}
