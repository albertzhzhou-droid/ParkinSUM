/// Per-food large-neutral-amino-acid (LNAA) profile, used to compute the
/// amino-acid competition proxy from *actual* nutrient fields when available,
/// in preference to the coarse protein-source approximation.
///
/// Educational prototype only — not a clinical pharmacokinetic prediction.
library;

/// Which data path produced the competition LNAA load.
enum AminoAcidDataMode {
  /// Actual per-food amino-acid nutrient fields were used.
  actualAminoAcidFields,

  /// Fell back to the protein-source-type load-factor approximation.
  proteinSourceProxy,

  /// Neither amino-acid fields nor protein data were available.
  unknown,
}

/// LNAA grams per serving/basis, plus provenance. Null fields are treated as
/// missing (not zero) so the model never fabricates precision.
class AminoAcidProfile {
  final double? leucine;
  final double? isoleucine;
  final double? valine;
  final double? phenylalanine;
  final double? tyrosine;
  final double? tryptophan;
  final double? histidine;
  final double? methionine;
  final double? threonine;
  final String unit; // normalized unit, e.g. "g"
  final String basis; // e.g. "per_100g" / "per_serving"
  final List<String> nutrientIds; // upstream nutrient numbers (e.g. FDC 505)
  final List<String> sourceRefs;

  /// True when one or more amino-acid values lacked an explicit unit and were
  /// accepted only provisionally. Such a profile is treated as partial and
  /// lowers confidence rather than being trusted as precise.
  final bool partial;

  const AminoAcidProfile({
    this.leucine,
    this.isoleucine,
    this.valine,
    this.phenylalanine,
    this.tyrosine,
    this.tryptophan,
    this.histidine,
    this.methionine,
    this.threonine,
    this.unit = 'g',
    this.basis = 'per_100g',
    this.nutrientIds = const [],
    this.sourceRefs = const [],
    this.partial = false,
  });

  /// The six classic LNAAs that compete with levodopa transport
  /// (branched-chain + aromatic): leucine, isoleucine, valine, phenylalanine,
  /// tyrosine, tryptophan. Returns the sum of those that are present, or null
  /// when none are present.
  double? get competingLnaaGrams {
    final present = <double>[
      if (leucine != null) leucine!,
      if (isoleucine != null) isoleucine!,
      if (valine != null) valine!,
      if (phenylalanine != null) phenylalanine!,
      if (tyrosine != null) tyrosine!,
      if (tryptophan != null) tryptophan!,
    ];
    if (present.isEmpty) return null;
    return present.fold<double>(0, (a, b) => a + b);
  }

  bool get hasAnyLnaaField => competingLnaaGrams != null;

  Map<String, dynamic> toJson() => {
        'leucine': leucine,
        'isoleucine': isoleucine,
        'valine': valine,
        'phenylalanine': phenylalanine,
        'tyrosine': tyrosine,
        'tryptophan': tryptophan,
        'histidine': histidine,
        'methionine': methionine,
        'threonine': threonine,
        'unit': unit,
        'basis': basis,
        'nutrient_ids': nutrientIds,
        'source_refs': sourceRefs,
        'partial': partial,
        'competing_lnaa_grams': competingLnaaGrams,
      };

  /// Defensive deserialization. Absent numeric fields stay null (never coerced
  /// to 0), preserving the missing≠zero invariant through round-trips.
  static AminoAcidProfile fromJson(Map<String, dynamic> json) {
    double? d(String k) => (json[k] as num?)?.toDouble();
    return AminoAcidProfile(
      leucine: d('leucine'),
      isoleucine: d('isoleucine'),
      valine: d('valine'),
      phenylalanine: d('phenylalanine'),
      tyrosine: d('tyrosine'),
      tryptophan: d('tryptophan'),
      histidine: d('histidine'),
      methionine: d('methionine'),
      threonine: d('threonine'),
      unit: (json['unit'] as String?) ?? 'g',
      basis: (json['basis'] as String?) ?? 'per_100g',
      nutrientIds: (json['nutrient_ids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      sourceRefs: (json['source_refs'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      partial: (json['partial'] as bool?) ?? false,
    );
  }
}
