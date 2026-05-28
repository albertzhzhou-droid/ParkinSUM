import '../../../domain/entities/amino_acid_profile.dart';

/// Deterministic extractor for per-food amino-acid nutrients from an
/// FDC-style payload (`foodNutrients` list with nutrient number/name/unit +
/// amount). Preserves nutrient ids and source refs. Returns null when no
/// amino-acid fields are present so the LNAA layer can fall back to the
/// protein-source proxy. No network. Educational prototype; synthetic only.
class AminoAcidExtractor {
  /// FDC nutrient numbers for the amino acids of interest. Some datasets use
  /// alternate codes; this map captures the common ones plus the names as a
  /// fallback match.
  static const Map<String, String> _numberToField = {
    '507': 'leucine',
    '506': 'isoleucine',
    '510': 'valine',
    '508': 'phenylalanine',
    '509': 'tyrosine',
    '501': 'tryptophan',
    '512': 'histidine',
    '503': 'threonine',
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
        threonine;
    final ids = <String>[];
    const basis = 'per_100g';
    // After normalization all values are expressed in grams.
    const unit = 'g';
    var partial = false;

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
      unit: unit,
      basis: basis,
      nutrientIds: List.unmodifiable(ids),
      sourceRefs: sourceRefs,
      partial: partial,
    );
    return profile.competingLnaaGrams == null ? null : profile;
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
    return null;
  }
}
