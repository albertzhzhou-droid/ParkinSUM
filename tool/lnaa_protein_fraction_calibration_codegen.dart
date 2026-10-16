// Code generator for
// lib/core/constants/lnaa_protein_fraction_calibration_table.dart.
//
// Inputs (all committed):
// - tool/data/fdc_2025-04-24/food_nutrient_sr_legacy_subset.csv: official
//   FoodData Central 2025-04-24 nutrient rows.
// - tool/data/fdc_2025-04-24/food_nutrient_derivation.csv: derivation codes.
// - tool/data/usda_sr_legacy_reference_subset_2018.csv and
//   tool/data/reference_food_curation.json: the reference foods, their
//   descriptions and curated catalog groups.
//
// A reference food enters the calibration when the official rows report
// protein of at least [calibrationMinimumProteinG] g per 100 g and all six
// competing amino acids. Its fraction is the sum of the six published
// amounts divided by published protein. Nothing is estimated or edited.
// Each food is assigned the protein source the app gives it at runtime
// (`proteinSourceForReferenceGroup`), so a type is calibrated on exactly the
// foods that carry it. test/lnaa_protein_fraction_calibration_test.dart
// recomputes every value.

import 'dart:convert';

import 'package:parkinsum_companion/domain/entities/nutrient_derivation.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/reference_food_composition.dart';

import 'reference_food_composition_codegen.dart' show parseSubsetRows;
import 'reference_food_nutrient_profile_codegen.dart';

const lnaaCalibrationTablePath =
    'lib/core/constants/lnaa_protein_fraction_calibration_table.dart';

/// Below this protein content the fraction is a ratio of small rounded
/// numbers and the food carries little protein.
const calibrationMinimumProteinG = 2.0;

const _proteinNutrientId = 1003;

/// FDC ids of the six competing LNAAs: tryptophan, isoleucine, leucine,
/// phenylalanine, tyrosine, valine.
const competingLnaaNutrientIds = <int>[1210, 1212, 1213, 1217, 1218, 1219];

/// Protein-source name the app assigns a curated reference food, or null
/// when it assigns `unknown`.
String? proteinSourceForCuratedGroup(String group, String description) {
  final source = proteinSourceForReferenceGroup(
    referenceFoodGroupFromWire(group),
    description,
  );
  return source == ProteinSourceType.unknown ? null : source.name;
}

/// Order in which calibrated protein sources are listed (enum order).
const calibratedProteinSources = <String>[
  'dairy',
  'meat',
  'fish',
  'egg',
  'soy',
  'legume',
  'grain',
];

class LnaaCalibrationRow {
  final int fdcId;
  final String description;
  final String curatedGroup;
  final String? proteinSource;
  final double proteinG;
  final double competingLnaaG;
  final String weakestTier;

  /// Bounds on each amino-acid-to-protein ratio implied by the rounding of
  /// the published values.
  final List<({double low, double high})> ratioBounds;
  int patternId;

  LnaaCalibrationRow({
    required this.fdcId,
    required this.description,
    required this.curatedGroup,
    required this.proteinSource,
    required this.proteinG,
    required this.competingLnaaG,
    required this.weakestTier,
    required this.ratioBounds,
  }) : patternId = fdcId;

  double get fraction => competingLnaaG / proteinG;
}

class LnaaStatisticsResult {
  final int foodCount;
  final int independentPatternCount;
  final double median;
  final double lowerQuartile;
  final double upperQuartile;
  final double minimum;
  final double maximum;
  final Map<String, int> weakestTierCounts;

  const LnaaStatisticsResult({
    required this.foodCount,
    required this.independentPatternCount,
    required this.median,
    required this.lowerQuartile,
    required this.upperQuartile,
    required this.minimum,
    required this.maximum,
    required this.weakestTierCounts,
  });
}

class LnaaCalibrationResult {
  final List<LnaaCalibrationRow> foods;
  final LnaaStatisticsResult overall;
  final Map<String, LnaaStatisticsResult> bySource;

  const LnaaCalibrationResult({
    required this.foods,
    required this.overall,
    required this.bySource,
  });
}

/// Quantile by linear interpolation between order statistics (Hyndman and
/// Fan type 7). [sorted] must be ascending and non-empty.
double quantileType7(List<double> sorted, double probability) {
  final position = (sorted.length - 1) * probability;
  final lower = position.floor();
  final upper = position.ceil();
  return sorted[lower] + (position - lower) * (sorted[upper] - sorted[lower]);
}

double _halfUnit(String published) {
  final dot = published.indexOf('.');
  final decimals = dot < 0 ? 0 : published.length - dot - 1;
  var unit = 0.5;
  for (var i = 0; i < decimals; i++) {
    unit /= 10;
  }
  return unit;
}

bool sharesPattern(LnaaCalibrationRow left, LnaaCalibrationRow right) {
  for (var i = 0; i < left.ratioBounds.length; i++) {
    final a = left.ratioBounds[i];
    final b = right.ratioBounds[i];
    if (a.high < b.low || b.high < a.low) return false;
  }
  return true;
}

/// One value per independent pattern: the median fraction of its members.
List<double> patternFractions(List<LnaaCalibrationRow> rows) {
  final byPattern = <int, List<double>>{};
  for (final row in rows) {
    byPattern.putIfAbsent(row.patternId, () => []).add(row.fraction);
  }
  return [
    for (final members in byPattern.values) quantileType7(members..sort(), 0.5),
  ]..sort();
}

LnaaStatisticsResult _statistics(List<LnaaCalibrationRow> rows) {
  final fractions = patternFractions(rows);
  final tiers = <String, int>{};
  for (final tier in NutrientConfidenceTier.values) {
    final count = rows.where((row) => row.weakestTier == tier.name).length;
    if (count > 0) tiers[tier.name] = count;
  }
  return LnaaStatisticsResult(
    foodCount: rows.length,
    independentPatternCount: fractions.length,
    median: quantileType7(fractions, 0.5),
    lowerQuartile: quantileType7(fractions, 0.25),
    upperQuartile: quantileType7(fractions, 0.75),
    minimum: fractions.first,
    maximum: fractions.last,
    weakestTierCounts: tiers,
  );
}

LnaaCalibrationResult computeLnaaCalibration({
  required String nutrientCsvText,
  required String derivationCsvText,
  required String referenceCsvText,
  required String curationJsonText,
}) {
  final official = <int, Map<int, NutrientCsvRow>>{};
  for (final row in parseNutrientSubset(nutrientCsvText)) {
    official.putIfAbsent(
      int.parse(row.fdcId),
      () => {},
    )[int.parse(row.nutrientId)] = row;
  }
  final derivations = {
    for (final row in parseDerivations(derivationCsvText))
      row[0]: (code: row[1], description: row[2]),
  };
  final curation =
      (jsonDecode(curationJsonText) as Map<String, dynamic>)['foods']
          as Map<String, dynamic>;

  final foods = <LnaaCalibrationRow>[];
  for (final reference in parseSubsetRows(referenceCsvText)) {
    final fdcId = reference.fdcId;
    final rows = official[fdcId];
    final protein = rows?[_proteinNutrientId];
    if (rows == null || protein == null) continue;
    final proteinG = double.parse(protein.amount);
    if (proteinG < calibrationMinimumProteinG) continue;
    if (!competingLnaaNutrientIds.every(rows.containsKey)) continue;

    var competing = 0.0;
    var weakest = NutrientConfidenceTier.analytical;
    final bounds = <({double low, double high})>[];
    final proteinHalf = _halfUnit(protein.amount);
    for (final id in competingLnaaNutrientIds) {
      final row = rows[id]!;
      final amount = double.parse(row.amount);
      competing += amount;
      final derivation = derivations[row.derivationId];
      final tier = NutrientDerivation(
        derivationCode: derivation?.code,
        derivationDescription: derivation?.description,
      ).tier;
      if (nutrientConfidenceRank(tier) > nutrientConfidenceRank(weakest)) {
        weakest = tier;
      }
      final half = _halfUnit(row.amount);
      bounds.add((
        low:
            (amount - half).clamp(0.0, double.infinity) /
            (proteinG + proteinHalf),
        high: (amount + half) / (proteinG - proteinHalf),
      ));
    }
    final meta = curation['$fdcId'] as Map<String, dynamic>;
    final group = meta['group'] as String;
    foods.add(
      LnaaCalibrationRow(
        fdcId: fdcId,
        description: reference.description,
        curatedGroup: group,
        proteinSource: proteinSourceForCuratedGroup(
          group,
          reference.description,
        ),
        proteinG: proteinG,
        competingLnaaG: competing,
        weakestTier: weakest.name,
        ratioBounds: bounds,
      ),
    );
  }
  foods.sort((a, b) => a.fdcId.compareTo(b.fdcId));

  // Connected components of the shared-pattern relation; each component is
  // named by its lowest fdc id.
  final parent = {for (final food in foods) food.fdcId: food.fdcId};
  int find(int id) {
    while (parent[id] != id) {
      id = parent[id]!;
    }
    return id;
  }

  for (var i = 0; i < foods.length; i++) {
    for (var j = i + 1; j < foods.length; j++) {
      if (!sharesPattern(foods[i], foods[j])) continue;
      final a = find(foods[i].fdcId);
      final b = find(foods[j].fdcId);
      if (a == b) continue;
      if (a < b) {
        parent[b] = a;
      } else {
        parent[a] = b;
      }
    }
  }
  for (final food in foods) {
    food.patternId = find(food.fdcId);
  }

  return LnaaCalibrationResult(
    foods: foods,
    overall: _statistics(foods),
    bySource: {
      for (final source in calibratedProteinSources)
        if (foods.any((food) => food.proteinSource == source))
          source: _statistics([
            for (final food in foods)
              if (food.proteinSource == source) food,
          ]),
    },
  );
}

String _renderStatistics(LnaaStatisticsResult stats) {
  final tiers = [
    for (final entry in stats.weakestTierCounts.entries)
      "'${entry.key}': ${entry.value}",
  ].join(', ');
  return 'LnaaFractionStatistics('
      'foodCount: ${stats.foodCount}, '
      'independentPatternCount: ${stats.independentPatternCount}, '
      'median: ${stats.median}, '
      'lowerQuartile: ${stats.lowerQuartile}, '
      'upperQuartile: ${stats.upperQuartile}, '
      'minimum: ${stats.minimum}, '
      'maximum: ${stats.maximum}, '
      'weakestTierCounts: {$tiers},)';
}

String renderLnaaCalibrationTable(LnaaCalibrationResult result) {
  final out = StringBuffer()
    ..writeln(
      '// GENERATED by '
      'tool/generate_lnaa_protein_fraction_calibration_table.dart.',
    )
    ..writeln('// Do not edit by hand. Source: USDA FoodData Central full')
    ..writeln('// download, release 2025-04-24 (public domain), SR Legacy')
    ..writeln(
      '// reference foods with at least '
      '$calibrationMinimumProteinG g protein per 100 g and all six',
    )
    ..writeln('// competing amino acids reported. Describes food composition')
    ..writeln('// only.')
    ..writeln()
    ..writeln(
      "import '../../domain/entities/lnaa_protein_fraction_calibration.dart';",
    )
    ..writeln("import '../../domain/entities/protein_source.dart';")
    ..writeln()
    ..writeln("const String lnaaCalibrationRelease = '2025-04-24';")
    ..writeln()
    ..writeln(
      'const double lnaaCalibrationMinimumProteinG = '
      '$calibrationMinimumProteinG;',
    )
    ..writeln()
    ..writeln(
      'const LnaaFractionStatistics lnaaFractionOverall = '
      '${_renderStatistics(result.overall)};',
    )
    ..writeln()
    ..writeln(
      'const Map<ProteinSourceType, LnaaFractionStatistics> '
      'lnaaFractionBySource = {',
    );
  for (final entry in result.bySource.entries) {
    out.writeln(
      '  ProteinSourceType.${entry.key}: ${_renderStatistics(entry.value)},',
    );
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln('const List<LnaaCalibrationFood> lnaaCalibrationFoods = [');
  for (final food in result.foods) {
    final source = food.proteinSource == null
        ? 'null'
        : 'ProteinSourceType.${food.proteinSource}';
    out.writeln(
      "  LnaaCalibrationFood(${food.fdcId}, '${food.curatedGroup}', $source, "
      '${food.proteinG}, ${food.competingLnaaG}, ${food.patternId}, '
      "'${food.weakestTier}'),",
    );
  }
  out.writeln('];');
  return out.toString();
}
