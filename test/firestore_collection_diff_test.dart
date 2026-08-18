import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/firestore_collection_diff.dart';

void main() {
  test('no-op sync leaves unchanged documents untouched', () {
    final plan = planFirestoreCollectionSync(
      existing: {
        'meal_1': {
          'id': 'meal_1',
          'nested': {
            'protein': 20,
            'tags': ['dinner'],
          },
        },
      },
      desired: {
        'meal_1': {
          'nested': {
            'tags': ['dinner'],
            'protein': 20,
          },
          'id': 'meal_1',
        },
      },
    );

    expect(plan.isEmpty, isTrue);
  });

  test('sync plans only changed, added, and removed rows', () {
    final plan = planFirestoreCollectionSync(
      existing: {
        'keep': {'id': 'keep', 'value': 1},
        'change': {'id': 'change', 'value': 1},
        'remove': {'id': 'remove', 'value': 1},
      },
      desired: {
        'keep': {'id': 'keep', 'value': 1},
        'change': {'id': 'change', 'value': 2},
        'add': {'id': 'add', 'value': 3},
      },
    );

    expect(plan.upserts.keys, unorderedEquals(['change', 'add']));
    expect(plan.removals, {'remove'});
    expect(plan.mutationCount, 3);
  });

  test('unsafe document IDs and non-JSON data fail before remote writes', () {
    expect(
      () => planFirestoreCollectionSync(
        existing: const {},
        desired: {
          'unsafe/id': {'id': 'unsafe/id'},
        },
      ),
      throwsArgumentError,
    );
    expect(
      () => planFirestoreCollectionSync(
        existing: const {},
        desired: {
          'safe': {'created_at': DateTime.utc(2026)},
        },
      ),
      throwsArgumentError,
    );
  });
}
