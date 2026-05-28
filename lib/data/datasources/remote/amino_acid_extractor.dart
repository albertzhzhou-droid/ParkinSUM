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
    var unit = 'g';
    const basis = 'per_100g';

    for (final raw in nutrients) {
      if (raw is! Map) continue;
      final nutrient = raw['nutrient'];
      if (nutrient is! Map) continue;
      final number = (nutrient['number'] ?? '').toString();
      final name = (nutrient['name'] ?? '').toString().toLowerCase();
      final amount = raw['amount'];
      if (amount is! num) continue;
      final value = amount.toDouble();
      final unitName = (nutrient['unitName'] ?? '').toString();
      if (unitName.isNotEmpty) unit = unitName.toLowerCase();

      final field = _numberToField[number] ?? _nameToField(name);
      switch (field) {
        case 'leucine':
          leucine = value;
          ids.add(number.isEmpty ? 'name:leucine' : number);
          break;
        case 'isoleucine':
          isoleucine = value;
          ids.add(number.isEmpty ? 'name:isoleucine' : number);
          break;
        case 'valine':
          valine = value;
          ids.add(number.isEmpty ? 'name:valine' : number);
          break;
        case 'phenylalanine':
          phenylalanine = value;
          ids.add(number.isEmpty ? 'name:phenylalanine' : number);
          break;
        case 'tyrosine':
          tyrosine = value;
          ids.add(number.isEmpty ? 'name:tyrosine' : number);
          break;
        case 'tryptophan':
          tryptophan = value;
          ids.add(number.isEmpty ? 'name:tryptophan' : number);
          break;
        case 'histidine':
          histidine = value;
          ids.add(number.isEmpty ? 'name:histidine' : number);
          break;
        case 'methionine':
          methionine = value;
          ids.add(number.isEmpty ? 'name:methionine' : number);
          break;
        case 'threonine':
          threonine = value;
          ids.add(number.isEmpty ? 'name:threonine' : number);
          break;
        default:
          break;
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
    );
    return profile.competingLnaaGrams == null ? null : profile;
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
