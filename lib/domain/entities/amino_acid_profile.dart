/// Per-food large-neutral-amino-acid (LNAA) profile, used to compute the
/// amino-acid competition proxy from *actual* nutrient fields when available,
/// in preference to the coarse protein-source approximation.
///
/// Educational prototype only — not a clinical pharmacokinetic prediction.
library;

import 'nutrient_derivation.dart';

export 'nutrient_derivation.dart'
    show NutrientConfidenceTier, NutrientDerivation;

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
  // Additional indispensable / conditionally-indispensable amino acids FDC
  // publishes alongside the competing LNAAs. Captured for representation
  // completeness (B2); NOT part of the levodopa-competing LNAA set, so they do
  // not affect `competingLnaaGrams`.
  final double? lysine;
  final double? cystine;
  final double? arginine;
  final String unit; // normalized unit, e.g. "g"
  final String basis; // e.g. "per_100g" / "per_serving"
  final List<String> nutrientIds; // upstream nutrient numbers (e.g. FDC 505)
  final List<String> sourceRefs;

  /// True when one or more amino-acid values lacked an explicit unit and were
  /// accepted only provisionally. Such a profile is treated as partial and
  /// lowers confidence rather than being trusted as precise.
  final bool partial;

  /// Optional per-nutrient FDC provenance keyed by amino-acid field name
  /// (e.g. `"leucine"`). Additive and default-empty; absent → no provenance
  /// reported (missing ≠ a confident value).
  final Map<String, NutrientDerivation> derivations;

  /// Optional FDC food data type (Foundation / SR Legacy / Survey / Branded).
  final String? fdcDataType;

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
    this.lysine,
    this.cystine,
    this.arginine,
    this.unit = 'g',
    this.basis = 'per_100g',
    this.nutrientIds = const [],
    this.sourceRefs = const [],
    this.partial = false,
    this.derivations = const {},
    this.fdcDataType,
  });

  /// Conservative "weakest-wins" provenance tier across present per-nutrient
  /// derivations. Null when no derivation provenance is available — a missing
  /// derivation never raises confidence.
  NutrientConfidenceTier? get aggregateConfidenceTier =>
      derivations.isEmpty ? null : weakestConfidenceTier(derivations.values);

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

  /// Count of the six competing LNAA fields that are present. Used to detect a
  /// partial LNAA profile (some but not all of the six present).
  int get presentLnaaFieldCount => [
        leucine,
        isoleucine,
        valine,
        phenylalanine,
        tyrosine,
        tryptophan,
      ].where((v) => v != null).length;

  /// True when at least one but not all six competing LNAA fields are present.
  /// Such a profile is treated as partial (uncertainty widened), distinct from
  /// the `partial` flag which marks unit-ambiguous values.
  bool get hasPartialLnaaFields {
    final n = presentLnaaFieldCount;
    return n > 0 && n < 6;
  }

  /// Return a copy scaled to a serving of [grams], assuming this profile is on
  /// a `per_100g` basis. Each present amino-acid value is multiplied by
  /// `grams / 100`; absent values stay null (missing ≠ zero). When the basis is
  /// not `per_100g`, the profile is returned unchanged to avoid wrong math.
  /// Used to express absolute competing LNAA grams for a logged serving.
  AminoAcidProfile scaledToGrams(double grams) {
    if (basis != 'per_100g' || grams <= 0) return this;
    final f = grams / 100.0;
    double? s(double? v) => v == null ? null : v * f;
    return AminoAcidProfile(
      leucine: s(leucine),
      isoleucine: s(isoleucine),
      valine: s(valine),
      phenylalanine: s(phenylalanine),
      tyrosine: s(tyrosine),
      tryptophan: s(tryptophan),
      histidine: s(histidine),
      methionine: s(methionine),
      threonine: s(threonine),
      lysine: s(lysine),
      cystine: s(cystine),
      arginine: s(arginine),
      unit: unit,
      basis: 'per_serving',
      nutrientIds: nutrientIds,
      sourceRefs: sourceRefs,
      partial: partial,
      derivations: derivations,
      fdcDataType: fdcDataType,
    );
  }

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
        'lysine': lysine,
        'cystine': cystine,
        'arginine': arginine,
        'unit': unit,
        'basis': basis,
        'nutrient_ids': nutrientIds,
        'source_refs': sourceRefs,
        'partial': partial,
        'competing_lnaa_grams': competingLnaaGrams,
        'fdc_data_type': fdcDataType,
        'aggregate_confidence_tier': aggregateConfidenceTier?.name,
        'derivations': derivations.map((k, v) => MapEntry(k, v.toJson())),
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
      lysine: d('lysine'),
      cystine: d('cystine'),
      arginine: d('arginine'),
      unit: (json['unit'] as String?) ?? 'g',
      basis: (json['basis'] as String?) ?? 'per_100g',
      nutrientIds: (json['nutrient_ids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      sourceRefs: (json['source_refs'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      partial: (json['partial'] as bool?) ?? false,
      fdcDataType: json['fdc_data_type'] as String?,
      derivations: (json['derivations'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(
              k, NutrientDerivation.fromJson(v as Map<String, dynamic>))),
    );
  }
}
