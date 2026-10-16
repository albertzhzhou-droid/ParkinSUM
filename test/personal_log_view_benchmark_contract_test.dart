import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/personal_log_view.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_date_window_resolver.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_view_projector.dart';
import 'package:parkinsum_companion/engineering/personal_log_view_benchmark_fixture.dart';
import 'package:parkinsum_companion/engineering/personal_log_persistent_benchmark.dart';

// These checks validate fixture and statistics contracts. They do not run a
// timed benchmark, mount its entry point or stand in for the W31 prerequisite.
void main() {
  test(
    'restore readback compares typed identity while retaining all values',
    () {
      final rows = PersonalLogBenchmarkFixture.generate(
        100,
      ).meals.map((meal) => meal.toJson()).toList();
      final reordered = rows.reversed.toList();
      expect(benchmarkRecordsMatchById(reordered, rows), isTrue);
      expect(benchmarkRecordsMatchById([...rows, rows.first], rows), isFalse);
      expect(benchmarkRecordsMatchById(rows.skip(1), rows), isFalse);
      expect(
        benchmarkRecordsMatchById([
          {...rows.first, 'eatenAt': '2026-09-30T00:00:00.000Z'},
          ...rows.skip(1),
        ], rows),
        isFalse,
      );
      final invalid = rows[2];
      final items = (invalid['items'] as List).cast<Map<String, dynamic>>();
      expect(
        benchmarkRecordsMatchById([
          ...rows.take(2),
          {
            ...invalid,
            'items': [
              {...items.single, 'quantityFactor': 1},
            ],
          },
          ...rows.skip(3),
        ], rows),
        isFalse,
      );
    },
  );
  test(
    'disposable-origin guard refuses unrelated preferences and stale ownership',
    () {
      const expected = 'current-source-marker';
      expect(
        () => requireDisposableBenchmarkOrigin(
          existingKeys: {'meal_draft'},
          marker: null,
          expectedMarker: expected,
        ),
        throwsStateError,
      );
      expect(
        () => requireDisposableBenchmarkOrigin(
          existingKeys: {'db.user_state.v1'},
          marker: 'old-source',
          expectedMarker: expected,
        ),
        throwsStateError,
      );
      requireDisposableBenchmarkOrigin(
        existingKeys: {},
        marker: null,
        expectedMarker: expected,
      );
      requireDisposableBenchmarkOrigin(
        existingKeys: {PersonalLogPersistentBenchmark.markerKey},
        marker: expected,
        expectedMarker: expected,
      );
    },
  );

  test(
    'failed measured operation retains partial samples without a passing percentile',
    () async {
      var calls = 0;
      final samples = <Map<String, Object>>[];
      try {
        await measurePersonalLogBenchmark(
          operation: () async {
            if (++calls == 5) throw StateError('controlled_storage_failure');
            return 3;
          },
          consume: (_) {},
          onSample: samples.add,
        );
        fail('The failed operation must not produce a passing distribution.');
      } on PersonalLogBenchmarkIncomplete catch (error) {
        expect(samples, hasLength(4));
        expect(error.evidence['status'], 'incomplete');
        expect(error.evidence['completedWarmupSamplesMs'], hasLength(2));
        expect(error.evidence['rawSamples'], hasLength(2));
        expect(error.evidence['failedIteration'], 4);
        expect(error.evidence.containsKey('median'), false);
        expect(error.evidence.containsKey('p95'), false);
      }
    },
  );

  test('warmup failure retains no fabricated successful samples', () async {
    await expectLater(
      measurePersonalLogBenchmark(
        operation: () async => throw StateError('controlled_warmup_failure'),
        consume: (_) {},
        onSample: (_) => fail('No successful operation'),
      ),
      throwsA(
        isA<PersonalLogBenchmarkIncomplete>()
            .having(
              (e) => e.evidence['rawSamples'],
              'successful samples',
              isEmpty,
            )
            .having(
              (e) => e.evidence.containsKey('p95'),
              'no percentile',
              false,
            ),
      ),
    );
  });
  test(
    'fixed fixture preserves independent known/unknown/invalid/zero counts',
    () {
      final fixture = PersonalLogBenchmarkFixture.generate(100);
      final window = PersonalLogDateWindowResolver().resolve(
        PersonalLogDateWindow(
          start: LogCivilDate(2026, 9, 1),
          endInclusive: LogCivilDate(2026, 9, 30),
          zoneId: 'Etc/UTC',
        ),
        asOf: PersonalLogBenchmarkFixture.asOf,
      );
      final projected = const PersonalLogViewProjector().insights(
        window: window,
        meals: fixture.meals,
        intakes: fixture.intakes,
        observations: const [],
        foods: fixture.foods,
        medications: fixture.drugs,
      );
      // Among 100 meals: five mod20 rows are future; mod10==1/2 are
      // independently ten unknown and ten invalid rows, and five historic zeros.
      expect(fixture.meals, hasLength(100));
      expect(fixture.intakes, hasLength(20));
      expect(projected.protein, hasLength(95));
      expect(projected.knownProtein, hasLength(75));
      expect(projected.unknownCount, 10);
      expect(projected.invalidCount, 10);
      expect(projected.reportedZeroCount, 5);
      expect(
        fixture.meals[0].eatenAt,
        PersonalLogBenchmarkFixture.asOf.add(const Duration(minutes: 1)),
      );
      expect(fixture.meals[3].eatenAt, DateTime.utc(2026, 9, 1, 0, 6));
      // Independent integer recurrence: the fourth LCG value is 343952906,
      // giving 0.5 + 123 / 100 = 1.73 for this first fully known row.
      expect(fixture.meals[3].items.single.quantityFactor, 1.73);
      expect(fixture.meals[1].items.single.missingNutrientFields, {'proteinG'});
      expect(fixture.meals[1].items.single.proteinPer100g, 999);
      expect(fixture.meals[2].items.single.quantityFactor, 0);
      expect(fixture.intakes.first.id, fixture.meals.first.id);
      expect(
        fixture.intakes.first.takenAt,
        fixture.meals.first.eatenAt.subtract(const Duration(minutes: 15)),
      );
    },
  );

  test('declared sizes and seed create reproducible bound inputs', () {
    final first = PersonalLogBenchmarkFixture.generate(100);
    final repeated = PersonalLogBenchmarkFixture.generate(100);
    final larger = PersonalLogBenchmarkFixture.generate(1000);
    expect(first.parameters['seed'], 31415926);
    expect(first.inputSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(first.inputSha256, repeated.inputSha256);
    expect(larger.inputSha256, isNot(first.inputSha256));
    expect(larger.intakes, hasLength(200));
    expect(larger.meals[3].toJson(), first.meals[3].toJson());
    expect(
      () => PersonalLogBenchmarkFixture.generate(999),
      throwsArgumentError,
    );
    expect(() => first.meals.clear(), throwsUnsupportedError);
  });

  test('median and nearest-rank p95 retain original repeated samples', () {
    final distribution = personalLogBenchmarkDistribution([
      9,
      1,
      5,
      3,
      7,
      2,
      4,
    ]);
    expect(distribution['sampleCount'], 7);
    expect(distribution['median'], 4);
    expect(distribution['p95'], 9);
    expect(distribution['p95Method'], 'nearest_rank');
    expect(distribution['rawSamples'], [9, 1, 5, 3, 7, 2, 4]);
    final even = personalLogBenchmarkDistribution([8, 7, 6, 5, 4, 3, 2, 1]);
    expect(even['median'], 4.5);
    expect(even['p95'], 8);
  });

  test(
    'unfinished and invalid measurements never form a valid distribution',
    () {
      for (final input in <List<double>>[
        [],
        [1, 2, 3, 4, 5, 6],
        [1, 2, 3, 4, 5, 6, -1],
        [1, 2, 3, 4, 5, 6, double.nan],
        [1, 2, 3, 4, 5, 6, double.infinity],
      ]) {
        expect(
          () => personalLogBenchmarkDistribution(input),
          throwsArgumentError,
        );
      }
    },
  );
}
