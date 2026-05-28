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
  final String unit; // e.g. "g"
  final String basis; // e.g. "per_100g" / "per_serving"
  final List<String> nutrientIds; // upstream nutrient numbers (e.g. FDC 505)
  final List<String> sourceRefs;

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
        'competing_lnaa_grams': competingLnaaGrams,
      };
}
