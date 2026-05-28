import '../entities/source_metadata.dart';

/// Deterministic, educational source-authority scorer + cross-jurisdiction
/// conflict policy. NOT a regulatory ranking.
///
/// Policy (encoded as deterministic rules):
/// - Official label/monograph/SmPC/package insert from the *relevant*
///   jurisdiction has the highest authority for that jurisdiction.
/// - Official databases (DPD, dm+d, EU national registers) are strong for
///   identity/coding; dictionaries (dm+d) are weaker for food-effect text.
/// - Reference translations (e.g. PMDA English index) are marked
///   reference-only and scored below the official-language source.
/// - Seed/demo/synthetic data must NEVER outrank official imported data.
/// - Cross-jurisdiction differences are preserved, never silently merged.
class SourceAuthorityScorer {
  /// Base authority weight per tier (0..1).
  static const Map<SourceAuthorityTier, double> _tierBase = {
    SourceAuthorityTier.officialLabelInJurisdiction: 1.0,
    SourceAuthorityTier.officialDatabaseInJurisdiction: 0.85,
    SourceAuthorityTier.officialOutOfJurisdiction: 0.6,
    SourceAuthorityTier.drugDictionary: 0.55,
    SourceAuthorityTier.referenceTranslation: 0.45,
    SourceAuthorityTier.foodCompositionTable: 0.7,
    SourceAuthorityTier.seedOrManualDemo: 0.2,
    SourceAuthorityTier.syntheticDemo: 0.1,
    SourceAuthorityTier.unknown: 0.15,
  };

  /// Composite authority score in 0..1 for a source document, given the
  /// user's jurisdiction chain (closest-first).
  double score(
    SourceDocumentMetadata source, {
    required List<String> userJurisdictionChain,
  }) {
    var s = _tierBase[source.authorityTier] ?? 0.15;

    // Jurisdiction match bonus/penalty.
    final jm = jurisdictionMatchScore(
      sourceJurisdiction: source.jurisdiction,
      userJurisdictionChain: userJurisdictionChain,
    );
    s = s * (0.6 + 0.4 * jm); // jurisdiction modulates, never zeroes a tier

    // Reference-translation downgrade.
    if (source.translationStatus ==
        ReferenceTranslationStatus.referenceOnlyTranslation) {
      s *= 0.8;
    }

    // Seed/synthetic hard cap so they never approach official scores.
    if (source.isSyntheticOrSeed) {
      s = s.clamp(0.0, 0.3);
    }

    return s.clamp(0.0, 1.0);
  }

  /// 0..1 jurisdiction match: 1.0 for exact closest match, decreasing along
  /// the chain, 0.2 for GLOBAL, 0.0 for unmatched.
  double jurisdictionMatchScore({
    required String sourceJurisdiction,
    required List<String> userJurisdictionChain,
  }) {
    final src = sourceJurisdiction.trim().toUpperCase();
    if (src.isEmpty) return 0.0;
    if (src == 'GLOBAL') return 0.2;
    final idx = userJurisdictionChain
        .map((j) => j.trim().toUpperCase())
        .toList()
        .indexOf(src);
    if (idx < 0) return 0.0;
    // Closest (index 0) → 1.0; decay by position.
    return (1.0 - 0.2 * idx).clamp(0.2, 1.0);
  }

  /// Determine whether seed/synthetic data is allowed to override an official
  /// source. Always false — the policy forbids it.
  bool seedMayOverride(
          SourceDocumentMetadata seed, SourceDocumentMetadata official) =>
      false;

  /// Classify a cross-jurisdiction comparison between two sources for the
  /// same attribute. Conflicts are preserved, never silently collapsed.
  CrossJurisdictionConflictStatus classifyConflict({
    required SourceDocumentMetadata a,
    required SourceDocumentMetadata b,
    required bool valuesAgree,
  }) {
    final ja = a.jurisdiction.trim().toUpperCase();
    final jb = b.jurisdiction.trim().toUpperCase();
    if (ja.isEmpty || jb.isEmpty) {
      return CrossJurisdictionConflictStatus.unknown;
    }
    if (ja == jb) return CrossJurisdictionConflictStatus.sameJurisdiction;
    return valuesAgree
        ? CrossJurisdictionConflictStatus.differentJurisdictionNoConflict
        : CrossJurisdictionConflictStatus.differentJurisdictionConflict;
  }

  SourceAuthorityTier tierFor(SourceAuthorityTier tier) => tier;
}
