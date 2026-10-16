import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../core/models/drug_definition.dart';
import '../core/models/food_item.dart';
import '../core/models/intake.dart';
import '../core/models/meal.dart';

/// Fixed fabricated inputs. Persistent experiments require a separately
/// guarded, initially empty disposable origin; ordinary app data is excluded.
final class PersonalLogBenchmarkFixture {
  PersonalLogBenchmarkFixture._(
    this.meals,
    this.intakes,
    this.foods,
    this.drugs,
  );

  static const seed = 31415926;
  static const sizes = [100, 1000, 10000];
  static final asOf = DateTime.utc(2026, 9, 30, 12);
  final List<Meal> meals;
  final List<Intake> intakes;
  final List<FoodItem> foods;
  final List<DrugDefinition> drugs;

  factory PersonalLogBenchmarkFixture.generate(int count) {
    if (!sizes.contains(count)) {
      throw ArgumentError.value(count, 'count', 'Use a declared fixture size.');
    }
    final foods = <FoodItem>[
      for (var index = 0; index < 3; index++)
        FoodItem(
          id: 'synthetic-perf-food-$index',
          name: 'Synthetic benchmark food $index',
          category: FoodCategory.other,
          sourceSystem: 'SYNTHETIC_PERF',
          proteinG: index == 0
              ? 0
              : index == 1
              ? 999
              : 20,
          carbsG: 10,
          fatG: 1,
          fiberG: 2,
          sodiumMg: 3,
          missingNutrientFields: index == 1 ? {'proteinG'} : {},
        ),
    ];
    final drugs = <DrugDefinition>[
      DrugDefinition(
        id: 'synthetic-perf-drug',
        genericName: 'Synthetic benchmark medication',
        brandNames: const [],
        tags: const [DrugTag.unknown],
        notes: 'Engineering fixture; no clinical meaning.',
        sourceSystem: 'SYNTHETIC_PERF',
      ),
    ];
    final meals = <Meal>[];
    final intakes = <Intake>[];
    var random = seed;
    for (var index = 0; index < count; index++) {
      // This integer LCG stays below 2^53 before modulo, including dart2js.
      random = (random * 1664525 + 1013904223) % 4294967296;
      final status = index % 10;
      final food =
          foods[status == 0
              ? 0
              : status == 1
              ? 1
              : 2];
      final time = index % 20 == 0
          ? asOf.add(Duration(minutes: 1 + index % 300))
          : DateTime.utc(2026, 9, 1).add(Duration(minutes: index * 2));
      final id = 'synthetic-perf-row-$index';
      meals.add(
        Meal(
          id: id,
          title: 'Synthetic benchmark meal $index',
          eatenAt: time,
          items: [
            MealItem.fromFood(
              food: food,
              quantityFactor: status == 2 ? 0 : 0.5 + (random % 151) / 100,
            ),
          ],
        ),
      );
      if (index % 5 == 0) {
        intakes.add(
          Intake(
            // Deliberately share IDs across types; identity remains typed.
            id: id,
            drugId: drugs.single.id,
            takenAt: time.subtract(const Duration(minutes: 15)),
            dosageNote: 'Synthetic engineering entry',
          ),
        );
      }
    }
    return PersonalLogBenchmarkFixture._(
      List.unmodifiable(meals),
      List.unmodifiable(intakes),
      List.unmodifiable(foods),
      List.unmodifiable(drugs),
    );
  }

  Map<String, Object?> get parameters => {
    'generator': 'integer_lcg_1664525_1013904223_mod_2pow32',
    'seed': seed,
    'mealCount': meals.length,
    'intakeCount': intakes.length,
    'foodCount': foods.length,
    'drugCount': drugs.length,
    'zone': 'Etc/UTC',
    'startCivilDate': '2026-09-01',
    'endCivilDateInclusive': '2026-09-30',
    'fixedAsOfUtc': asOf.toIso8601String(),
    'statusesByIndexMod10': [
      'reported_zero',
      'captured_unknown',
      'invalid_quantity',
      'known',
      'known',
      'known',
      'known',
      'known',
      'known',
      'known',
    ],
    'futureRule': 'index mod 20 == 0; fixedAsOf + 1 + index mod 300 minutes',
    'historicalRule': '2026-09-01T00:00Z + index * 2 minutes',
    'intakeRule':
        'index mod 5 == 0; meal time minus 15 minutes; shared typed ID',
  };

  String get inputSha256 => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'parameters': parameters,
            'foods': foods.map((food) => food.toJson()).toList(),
            'drugs': drugs.map((drug) => drug.toJson()).toList(),
            'meals': meals.map((meal) => meal.toJson()).toList(),
            'intakes': intakes.map((intake) => intake.toJson()).toList(),
          }),
        ),
      )
      .toString();
}

/// Distribution over measured samples only; warmups are excluded by callers.
Map<String, Object> personalLogBenchmarkDistribution(List<double> rawMs) {
  if (rawMs.length < 7 || rawMs.any((value) => !value.isFinite || value < 0)) {
    throw ArgumentError(
      'At least seven finite, nonnegative samples are required.',
    );
  }
  final sorted = rawMs.toList()..sort();
  final middle = sorted.length ~/ 2;
  final median = sorted.length.isOdd
      ? sorted[middle]
      : sorted[middle - 1] / 2 + sorted[middle] / 2;
  final percentileIndex = math.max(0, (sorted.length * 0.95).ceil() - 1);
  return {
    'unit': 'ms',
    'sampleCount': rawMs.length,
    'median': median,
    'p95': sorted[percentileIndex],
    'p95Method': 'nearest_rank',
    'rawSamples': List<double>.unmodifiable(rawMs),
  };
}

final class PersonalLogBenchmarkIncomplete implements Exception {
  const PersonalLogBenchmarkIncomplete(this.evidence);
  final Map<String, Object> evidence;
  @override
  String toString() => 'PersonalLogBenchmarkIncomplete(${evidence['reason']})';
}

/// Keeps completed observations on failure. A failed or unfinished operation
/// never contributes a duration to the distribution of successful operations.
Future<Map<String, Object>> measurePersonalLogBenchmark({
  required Future<int> Function() operation,
  required void Function(int checksum) consume,
  required void Function(Map<String, Object> sample) onSample,
}) async {
  final raw = <double>[];
  final warmupRaw = <double>[];
  for (var index = 0; index < 9; index++) {
    final watch = Stopwatch()..start();
    try {
      final checksum = await operation();
      watch.stop();
      consume(checksum);
    } catch (error) {
      watch.stop();
      throw PersonalLogBenchmarkIncomplete({
        'status': 'incomplete',
        'sampleCount': raw.length,
        'rawSamples': List<double>.unmodifiable(raw),
        'completedWarmupSamplesMs': List<double>.unmodifiable(warmupRaw),
        'failedIteration': index,
        'failedOperationElapsedMs': watch.elapsedMicroseconds / 1000,
        'reason': '$error',
      });
    }
    final duration = watch.elapsedMicroseconds / 1000;
    (index < 2 ? warmupRaw : raw).add(duration);
    onSample({'iteration': index, 'warmup': index < 2, 'elapsedMs': duration});
    await Future<void>.delayed(Duration.zero);
  }
  return personalLogBenchmarkDistribution(raw);
}
