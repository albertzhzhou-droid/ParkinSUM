/// Coarse protein source type used by the educational LNAA-competition
/// proxy. ParkinSUM does not capture amino-acid composition per food today;
/// this enum lets the amino-acid competition layer apply a *direction*-only
/// load factor (animal protein generally carries higher LNAA per gram than
/// plant protein) without claiming patient-level pharmacokinetics.
///
/// Magnitudes are documented as `prototype_heuristic` in
/// `Bibliographies.md`. Direction is grounded in the cited reviews.
library;

import '../usecases/model_assumption_registry.dart';

enum ProteinSourceType {
  dairy,
  meat,
  fish,
  egg,
  soy,
  legume,
  grain,
  mixed,
  unknown,
}

/// Multiplier applied to the existing `proteinAmplitude` inside the
/// amino-acid competition layer. Unitless. Magnitudes are illustrative.
class LnaaLoadFactor {
  final ProteinSourceType sourceType;
  final double loadFactor;
  final List<String> sourceRefs;
  final String limitation;
  final bool isPrototypeHeuristic;

  const LnaaLoadFactor({
    required this.sourceType,
    required this.loadFactor,
    required this.sourceRefs,
    required this.limitation,
    required this.isPrototypeHeuristic,
  });

  Map<String, dynamic> toJson() => {
        'source_type': sourceType.name,
        'load_factor': loadFactor,
        'source_refs': sourceRefs,
        'limitation': limitation,
        'is_prototype_heuristic': isPrototypeHeuristic,
      };
}

/// Static registry mapping `ProteinSourceType` to a load factor. Defaults
/// follow the *direction* indicated by the cited reviews: animal protein
/// tends to carry higher LNAA per gram than plant protein; magnitudes here
/// are illustrative and labeled `prototype_heuristic`.
class ProteinSourceLnaaRegistry {
  static const List<String> _baseSourceRefs = [
    'src.nutt.lnaa.1989',
    'src.cereda.protein.2017',
    'src.advances.nutrition.2021',
    'src.npj.peripheral.resistance.2022',
    'src.lnaa.plantvanimal.2023',
    'src.internal.prototype.heuristic',
  ];

  static const Map<ProteinSourceType, LnaaLoadFactor> _factors = {
    ProteinSourceType.dairy: LnaaLoadFactor(
      sourceType: ProteinSourceType.dairy,
      loadFactor: 1.10,
      sourceRefs: _baseSourceRefs,
      limitation:
          'Animal protein generally carries higher LNAA per gram than plant '
          'protein; magnitude is illustrative.',
      isPrototypeHeuristic: true,
    ),
    ProteinSourceType.meat: LnaaLoadFactor(
      sourceType: ProteinSourceType.meat,
      loadFactor: 1.15,
      sourceRefs: _baseSourceRefs,
      limitation: 'Direction supported by reviews; magnitude illustrative.',
      isPrototypeHeuristic: true,
    ),
    ProteinSourceType.fish: LnaaLoadFactor(
      sourceType: ProteinSourceType.fish,
      loadFactor: 1.10,
      sourceRefs: _baseSourceRefs,
      limitation: 'Direction supported by reviews; magnitude illustrative.',
      isPrototypeHeuristic: true,
    ),
    ProteinSourceType.egg: LnaaLoadFactor(
      sourceType: ProteinSourceType.egg,
      loadFactor: 1.10,
      sourceRefs: _baseSourceRefs,
      limitation: 'Direction supported by reviews; magnitude illustrative.',
      isPrototypeHeuristic: true,
    ),
    ProteinSourceType.soy: LnaaLoadFactor(
      sourceType: ProteinSourceType.soy,
      loadFactor: 0.95,
      sourceRefs: _baseSourceRefs,
      limitation:
          'Plant protein generally carries lower LNAA per gram than animal '
          'protein; magnitude is illustrative.',
      isPrototypeHeuristic: true,
    ),
    ProteinSourceType.legume: LnaaLoadFactor(
      sourceType: ProteinSourceType.legume,
      loadFactor: 0.90,
      sourceRefs: _baseSourceRefs,
      limitation: 'Direction supported by reviews; magnitude illustrative.',
      isPrototypeHeuristic: true,
    ),
    ProteinSourceType.grain: LnaaLoadFactor(
      sourceType: ProteinSourceType.grain,
      loadFactor: 0.85,
      sourceRefs: _baseSourceRefs,
      limitation: 'Direction supported by reviews; magnitude illustrative.',
      isPrototypeHeuristic: true,
    ),
    ProteinSourceType.mixed: LnaaLoadFactor(
      sourceType: ProteinSourceType.mixed,
      loadFactor: 1.00,
      sourceRefs: _baseSourceRefs,
      limitation:
          'Mixed protein sources default to a neutral load factor and widen '
          'uncertainty.',
      isPrototypeHeuristic: true,
    ),
    ProteinSourceType.unknown: LnaaLoadFactor(
      sourceType: ProteinSourceType.unknown,
      loadFactor: 1.00,
      sourceRefs: _baseSourceRefs,
      limitation:
          'Unknown protein source; the model neither favors nor penalizes '
          'direction and widens the competition uncertainty band.',
      isPrototypeHeuristic: true,
    ),
  };

  static LnaaLoadFactor factorFor(ProteinSourceType sourceType) {
    return _factors[sourceType] ?? _factors[ProteinSourceType.unknown]!;
  }

  static List<LnaaLoadFactor> all() => _factors.values.toList(growable: false);

  static ModelEvidenceLevel evidenceLevelFor(ProteinSourceType sourceType) =>
      ModelEvidenceLevel.prototypeHeuristic;
}

/// Best-effort inference of a `ProteinSourceType` from a food item's name +
/// category. Deterministic, side-effect-free. Tests assert specific
/// mappings. Unknown inputs return `ProteinSourceType.unknown` (never an
/// arbitrary guess) so the model widens uncertainty rather than faking
/// precision.
ProteinSourceType inferProteinSourceFromNameAndCategory({
  required String name,
  String? category,
}) {
  final n = name.toLowerCase();
  bool any(List<String> needles) => needles.any((needle) => n.contains(needle));

  if (any(['tofu', 'tempeh', 'edamame', 'soy', 'soybean'])) {
    return ProteinSourceType.soy;
  }
  if (any(['lentil', 'chickpea', 'bean', 'pea ', 'pulse', 'fava'])) {
    return ProteinSourceType.legume;
  }
  if (any(
      ['salmon', 'tuna', 'cod', 'fish', 'sardine', 'mackerel', 'tilapia'])) {
    return ProteinSourceType.fish;
  }
  if (any(['egg', 'omelet', 'frittata'])) {
    return ProteinSourceType.egg;
  }
  if (any(
      ['milk', 'yogurt', 'yoghurt', 'cheese', 'cottage', 'kefir', 'whey'])) {
    return ProteinSourceType.dairy;
  }
  if (any(
      ['beef', 'pork', 'lamb', 'chicken', 'turkey', 'duck', 'meat', 'steak'])) {
    return ProteinSourceType.meat;
  }
  if (any(
      ['oat', 'wheat', 'rice', 'barley', 'rye', 'quinoa', 'corn', 'bread'])) {
    return ProteinSourceType.grain;
  }
  if (category != null && category.toLowerCase() == 'protein') {
    // Category says protein but name didn't match any source — treat as mixed
    // rather than unknown to reflect "we know it's a protein food but not
    // its kind".
    return ProteinSourceType.mixed;
  }
  return ProteinSourceType.unknown;
}
