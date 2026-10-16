/// Competing-LNAA fraction of protein measured across official food records.
///
/// The six competing large neutral amino acids (leucine, isoleucine, valine,
/// phenylalanine, tyrosine, tryptophan) are summed per 100 g and divided by
/// protein per 100 g. The statistics describe food composition only. They
/// say nothing about a person, a dose or a timing choice.
library;

import 'protein_source.dart';

/// Distribution of the competing-LNAA fraction of protein over one set of
/// calibration foods.
///
/// Statistics are taken over independent amino-acid patterns: records that
/// share a pattern contribute one value, the median of their fractions, so a
/// pattern repeated across several forms of a food is counted once. Quantiles
/// use linear interpolation between order statistics (Hyndman and Fan
/// type 7).
class LnaaFractionStatistics {
  /// Number of calibration foods.
  final int foodCount;

  /// Number of distinct amino-acid patterns among those foods. Records whose
  /// six amino-acid-to-protein ratios agree within the rounding of the
  /// published values share one pattern; source tables often carry one
  /// pattern across several forms of a food, so this count can be lower than
  /// [foodCount].
  final int independentPatternCount;

  final double median;
  final double lowerQuartile;
  final double upperQuartile;
  final double minimum;
  final double maximum;

  /// Calibration foods per weakest FDC derivation tier of their six
  /// amino-acid rows (`analytical`, `calculated`, `imputedOrAssumed`,
  /// `unknown`). Only tiers with at least one food are listed.
  final Map<String, int> weakestTierCounts;

  const LnaaFractionStatistics({
    required this.foodCount,
    required this.independentPatternCount,
    required this.median,
    required this.lowerQuartile,
    required this.upperQuartile,
    required this.minimum,
    required this.maximum,
    required this.weakestTierCounts,
  });

  Map<String, dynamic> toJson() => {
    'food_count': foodCount,
    'independent_pattern_count': independentPatternCount,
    'median': median,
    'lower_quartile': lowerQuartile,
    'upper_quartile': upperQuartile,
    'minimum': minimum,
    'maximum': maximum,
    'weakest_tier_counts': weakestTierCounts,
  };
}

/// One calibration food: an SR Legacy reference record with at least the
/// minimum protein and all six competing amino acids reported.
class LnaaCalibrationFood {
  final int fdcId;

  /// Curated catalog group (`tool/data/reference_food_curation.json`).
  final String curatedGroup;

  /// Protein source the group maps to, or null for groups that the protein
  /// source proxy does not name (fruit, vegetable, nut and seed, and so on).
  /// Those foods still count toward the all-food statistics.
  final ProteinSourceType? proteinSource;

  /// Protein, g per 100 g, as published.
  final double proteinG;

  /// Sum of the six published competing amino acids, g per 100 g.
  final double competingLnaaG;

  /// Lowest FoodData Central id of the food's amino-acid pattern.
  final int patternId;

  /// Weakest derivation tier among the six amino-acid rows.
  final String weakestTier;

  const LnaaCalibrationFood(
    this.fdcId,
    this.curatedGroup,
    this.proteinSource,
    this.proteinG,
    this.competingLnaaG,
    this.patternId,
    this.weakestTier,
  );

  double get fraction => competingLnaaG / proteinG;
}
