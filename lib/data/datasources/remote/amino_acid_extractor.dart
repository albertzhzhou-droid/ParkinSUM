import '../../../domain/entities/amino_acid_profile.dart';

/// Deterministic extractor for per-food amino-acid nutrients from an
/// FDC-style payload (`foodNutrients` list with nutrient number/name/unit +
/// amount). Preserves accepted nutrient ids and source refs. Recognized rows
/// with ambiguous units/values or duplicate fields are held (left null) and
/// mark the returned profile partial; they are never coerced into grams.
/// Returns null only when no valid or held competing-LNAA field was observed;
/// a recognized-but-held competing field remains auditable as a partial
/// profile instead of becoming indistinguishable from source absence.
/// No network.
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

  /// Stable FDC-number order. Assignment, nutrient ids and derivation maps use
  /// this order so semantically identical payload permutations serialize the
  /// same way.
  static const List<String> _canonicalFieldOrder = [
    'tryptophan',
    'threonine',
    'isoleucine',
    'leucine',
    'lysine',
    'methionine',
    'cystine',
    'phenylalanine',
    'tyrosine',
    'valine',
    'arginine',
    'histidine',
  ];

  static const Set<String> _competingFields = {
    'leucine',
    'isoleucine',
    'valine',
    'phenylalanine',
    'tyrosine',
    'tryptophan',
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
    final declaredBasis = payload['basisType'] is String
        ? (payload['basisType'] as String).trim()
        : '';
    final basis = declaredBasis.isEmpty ? 'per_100g' : declaredBasis;
    // Optional FDC food data type (Foundation / SR Legacy / Survey / Branded).
    final declaredDataType = payload['dataType'] is String
        ? (payload['dataType'] as String).trim()
        : '';
    final fdcDataType = declaredDataType.isEmpty ? null : declaredDataType;
    // After normalization all values are expressed in grams.
    const unit = 'g';
    var partial = false;
    final derivations = <String, NutrientDerivation>{};
    final candidates = <String, _AminoAcidCandidate>{};
    final rowCountByField = <String, int>{};
    var heldCompetingField = false;

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
      final number = (nutrient['number'] ?? '').toString().trim();
      final name = (nutrient['name'] ?? '').toString().trim().toLowerCase();
      final field = _numberToField[number] ?? _nameToField(name);
      if (field == null) continue;

      final rowCount = (rowCountByField[field] ?? 0) + 1;
      rowCountByField[field] = rowCount;
      if (rowCount > 1) {
        // Multiple upstream rows for one semantic field are ambiguous without
        // an explicit selection policy. Hold the field rather than making the
        // result depend on source ordering (even if two rows happen to agree).
        partial = true;
        if (_competingFields.contains(field)) heldCompetingField = true;
        candidates.remove(field);
        continue;
      }

      final amount = _finiteNonNegativeAmount(raw['amount']);
      final unitName = (nutrient['unitName'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final normalized = amount == null ? null : _toGrams(amount, unitName);
      if (normalized == null) {
        // Missing/non-numeric/non-finite/negative amount or a missing/unknown
        // unit is a typed missing value. Never write the raw number into a
        // profile whose declared unit is grams.
        partial = true;
        if (_competingFields.contains(field)) heldCompetingField = true;
        continue;
      }

      candidates[field] = _AminoAcidCandidate(
        valueG: normalized,
        nutrientId: _numberToField.containsKey(number) ? number : 'name:$field',
        derivation: _extractDerivation(raw),
      );
    }

    for (final field in _canonicalFieldOrder) {
      final candidate = candidates[field];
      if (candidate == null || (rowCountByField[field] ?? 0) != 1) continue;
      assign(field, candidate.valueG, candidate.nutrientId);
      final derivation = candidate.derivation;
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
    return profile.competingLnaaGrams == null && !heldCompetingField
        ? null
        : profile;
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
    final hasAny =
        code != null ||
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

  /// Accept native JSON numbers and canonical numeric strings emitted by FDC
  /// CSV archives. Invalid, non-finite and negative values remain missing;
  /// zero is a valid measured value and is deliberately preserved.
  double? _finiteNonNegativeAmount(Object? raw) {
    final double? value;
    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String && raw.trim().isNotEmpty) {
      value = double.tryParse(raw.trim());
    } else {
      value = null;
    }
    if (value == null || !value.isFinite || value < 0) return null;
    return value;
  }

  /// Normalize an amino-acid amount to grams. Returns null when the trimmed
  /// unit is missing/unrecognized so the caller can hold the field as missing.
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

final class _AminoAcidCandidate {
  final double valueG;
  final String nutrientId;
  final NutrientDerivation? derivation;

  const _AminoAcidCandidate({
    required this.valueG,
    required this.nutrientId,
    required this.derivation,
  });
}
