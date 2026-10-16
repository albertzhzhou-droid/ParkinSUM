import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/portable_schema_migration.dart';
import 'package:parkinsum_companion/domain/usecases/portable_data_compact_transport_service.dart';
import 'package:parkinsum_companion/domain/usecases/portable_schema_migration_registry.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';
import 'package:parkinsum_companion/engineering/personal_log_view_benchmark_fixture.dart';

const _service = UserPortableDataPackageService();
const _owner = 'local_user';
const _kind = 'local_device_account';
final _time = DateTime.utc(2026, 9, 30, 12);

UserPortableDataSnapshot _snapshot(PersonalLogBenchmarkFixture fixture) =>
    UserPortableDataSnapshot(
      userScope: _owner,
      doseOwnerScope: _owner,
      scopeKind: _kind,
      profile: UserProfile.defaults(),
      activeDrugIds: const [],
      intakes: fixture.intakes,
      meals: fixture.meals,
      medicationCatalog: fixture.drugs,
      foodCatalog: fixture.foods,
      reminders: const [],
    );

Map<String, Object?> _root({bool compact = true}) => Map<String, Object?>.from(
  jsonDecode(
        _service
            .create(
              snapshot: _snapshot(PersonalLogBenchmarkFixture.generate(100)),
              generatedAt: _time,
              preferCompactTransport: compact,
            )
            .canonicalJson,
      )
      as Map,
);

Map<String, Object?> _files(Map<String, Object?> root) =>
    Map<String, Object?>.from(root['files'] as Map);

String _resign(Map<String, Object?> root) {
  final files = _files(root);
  final manifest = root['manifest'] as Map;
  for (final raw in manifest['files'] as List) {
    final row = raw as Map;
    final value = files[row['path']];
    row['sha256'] = portableCanonicalSha256(value);
    row['recordCount'] = value is List
        ? value.length
        : value is Map && value['records'] is List
        ? (value['records'] as List).length
        : value is Map && value['links'] is List
        ? (value['links'] as List).length
        : 1;
  }
  final content = portableCanonicalSha256(files);
  (manifest['integrity'] as Map)['contentSha256'] = content;
  manifest['packageId'] = portableSha256(
    'parkinsum-portable-package-v${root['schemaVersion']}|'
    '${(manifest['ownerScope'] as Map)['bindingSha256']}|$content',
  );
  return portableCanonicalJson(root);
}

UserPortableDataImportPreview _inspect(String text, {String owner = _owner}) =>
    _service.inspect(
      packageJson: text,
      currentUserScope: owner,
      currentDoseOwnerScope: owner,
      currentScopeKind: _kind,
    );

int _independentNodes(Object? value) =>
    1 +
    (value is Map
        ? value.values.fold<int>(
            0,
            (sum, item) => sum + _independentNodes(item),
          )
        : value is List
        ? value.fold<int>(0, (sum, item) => sum + _independentNodes(item))
        : 0);

Object? _independentSorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _independentSorted(value[key]),
    };
  }
  if (value is List) return value.map(_independentSorted).toList();
  return value;
}

void _expectIndependentWireHashes(Map<String, Object?> root) {
  String digest(Object? value) => sha256
      .convert(utf8.encode(jsonEncode(_independentSorted(value))))
      .toString();
  final files = _files(root);
  final manifest = root['manifest'] as Map;
  final summaries = (manifest['files'] as List).cast<Map>();
  expect(summaries.map((row) => row['path']), unorderedEquals(files.keys));
  for (final row in summaries) {
    final value = files[row['path']];
    expect(row['sha256'], digest(value), reason: row['path'] as String);
    final count = value is List
        ? value.length
        : value is Map && value['records'] is List
        ? (value['records'] as List).length
        : value is Map && value['links'] is List
        ? (value['links'] as List).length
        : 1;
    expect(row['recordCount'], count, reason: row['path'] as String);
  }
  final contentSha256 = digest(files);
  expect((manifest['integrity'] as Map)['contentSha256'], contentSha256);
  expect(
    manifest['packageId'],
    sha256
        .convert(
          utf8.encode(
            'parkinsum-portable-package-v${root['schemaVersion']}|'
            '${(manifest['ownerScope'] as Map)['bindingSha256']}|$contentSha256',
          ),
        )
        .toString(),
  );
}

void _rewriteSnapshot(Map<String, Object?> root, void Function(Map) mutate) {
  final files = root['files'] as Map;
  final entries = files[userPortableDataFoodItemSnapshotsPath] as List;
  final firstItem =
      (((files['meals.json'] as List).first as Map)['items'] as List).first
          as Map;
  final entry =
      entries.singleWhere(
            (raw) => (raw as Map)['snapshotId'] == firstItem['snapshotId'],
          )
          as Map;
  final oldId = entry['snapshotId'];
  mutate(entry['snapshot'] as Map);
  final newId = portableCanonicalSha256(entry['snapshot']);
  entry['snapshotId'] = newId;
  for (final meal in files['meals.json'] as List) {
    for (final item in (meal as Map)['items'] as List) {
      if ((item as Map)['snapshotId'] == oldId) item['snapshotId'] = newId;
    }
  }
  entries.sort(
    (a, b) => ((a as Map)['snapshotId'] as String).compareTo(
      (b as Map)['snapshotId'] as String,
    ),
  );
}

void main() {
  test('ordinary packages keep schema 4 and its original eight files', () {
    final first = _root(compact: false);
    expect(first['schemaVersion'], 4);
    expect(_files(first).keys.toSet(), userPortableDataFilePaths.toSet());
    _expectIndependentWireHashes(first);
    expect(
      _inspect(portableCanonicalJson(first)).status,
      UserPortableDataPreviewStatus.ready,
    );
    expect(PortableSchemaMigrationRegistry.currentVersion, 4);
  });

  test(
    'compact evidence resolves exactly and quantities remain per record',
    () {
      final legacy = _root(compact: false);
      final compact = _root();
      expect(compact['schemaVersion'], 5);
      final logical = PortableDataCompactTransportService.resolve(
        _files(compact),
      );
      expect(
        portableCanonicalJson(logical.files),
        portableCanonicalJson(_files(legacy)),
      );
      expect(logical.logicalNodeCount, _independentNodes(logical.files));
      expect(
        logical.logicalCanonicalBytes,
        utf8.encode(portableCanonicalJson(logical.files)).length,
      );
      final preview = _inspect(portableCanonicalJson(compact));
      expect(preview.status, UserPortableDataPreviewStatus.ready);
      expect(preview.schemaMigrationReceipt?.targetVersion, 5);
      expect(
        preview.schemaMigrationReceipt?.decision,
        'not_required_compact_transport',
      );
      expect(
        _inspect(portableCanonicalJson(compact), owner: 'another_owner').status,
        UserPortableDataPreviewStatus.wrongOwner,
      );
    },
  );

  test(
    'repeated equal snapshots share an identity without sharing quantities or later edits',
    () {
      final files = _files(_root(compact: false));
      final meal = Map<String, Object?>.from(
        (files['meals.json'] as List).first as Map,
      );
      final original = Map<String, Object?>.from(
        (meal['items'] as List).first as Map,
      );
      final snapshot = Map<String, Object?>.from(original)..remove('quantity');
      final expectedId = portableCanonicalSha256(snapshot);
      final items = [
        for (var index = 0; index < 300; index++)
          <String, Object?>{
            // Equal content with a different insertion order must share the
            // same identity; each row still carries its own exact quantity.
            ...Map<String, Object?>.fromEntries(
              index.isEven
                  ? original.entries
                  : original.entries.toList().reversed,
            ),
            'quantity': {'factorPer100g': index / 10, 'grams': index * 10.0},
          },
      ];
      files['meals.json'] = [
        <String, Object?>{...meal, 'items': items},
      ];
      final first = PortableDataCompactTransportService.encode(files);
      final snapshots = first[userPortableDataFoodItemSnapshotsPath] as List;
      expect(snapshots, hasLength(1));
      expect((snapshots.single as Map)['snapshotId'], expectedId);
      expect(
        portableCanonicalJson(
          PortableDataCompactTransportService.resolve(first).files,
        ),
        portableCanonicalJson(files),
      );
      final references =
          ((first['meals.json'] as List).single as Map)['items'] as List;
      for (var index = 0; index < references.length; index++) {
        expect((references[index] as Map)['snapshotId'], expectedId);
        expect(
          (references[index] as Map)['quantity'],
          items[index]['quantity'],
        );
      }

      // A subsequent encode re-evaluates changed captured content even when
      // its food ID and object identity are unchanged.
      items.first['foodName'] = 'Synthetic later captured name';
      final second = PortableDataCompactTransportService.encode(files);
      final changedEntries =
          second[userPortableDataFoodItemSnapshotsPath] as List;
      expect(changedEntries, hasLength(2));
      for (final raw in changedEntries) {
        final entry = raw as Map;
        expect(entry['snapshotId'], portableCanonicalSha256(entry['snapshot']));
      }
      expect(
        portableCanonicalJson(
          PortableDataCompactTransportService.resolve(second).files,
        ),
        portableCanonicalJson(files),
      );
      expect((snapshots.single as Map)['snapshotId'], expectedId);
    },
  );

  test('same food ID with different captured missingness is never merged', () {
    final food = FoodItem(
      id: 'same_food',
      name: 'Captured evidence',
      category: FoodCategory.other,
      proteinG: 0,
      carbsG: 1,
      fatG: 2,
      fiberG: 3,
      sodiumMg: 4,
    );
    final original = MealItem.fromFood(food: food, quantityFactor: 1.5);
    final changed = original.copyWith(
      proteinPer100g: 999,
      missingNutrientFields: {'proteinG'},
      quantityFactor: 0.25,
    );
    final snapshot = UserPortableDataSnapshot(
      userScope: _owner,
      doseOwnerScope: _owner,
      scopeKind: _kind,
      profile: UserProfile.defaults(),
      activeDrugIds: const [],
      intakes: const [],
      meals: [
        Meal(
          id: 'same_id_evidence',
          title: 'Captured same-food evidence',
          eatenAt: _time,
          items: [original, changed],
        ),
      ],
      medicationCatalog: const [],
      foodCatalog: [food],
      reminders: const [],
    );
    final artifact = _service.create(
      snapshot: snapshot,
      generatedAt: _time,
      preferCompactTransport: true,
    );
    final files = _files(artifact.document);
    expect(files[userPortableDataFoodItemSnapshotsPath], hasLength(2));
    final logical = PortableDataCompactTransportService.resolve(files).files;
    final items =
        ((logical['meals.json'] as List).single as Map)['items'] as List;
    final zero =
        ((items[0] as Map)['nutrientsPer100g'] as Map)['protein'] as Map;
    final unknown =
        ((items[1] as Map)['nutrientsPer100g'] as Map)['protein'] as Map;
    expect(zero['value'], 0);
    expect(unknown['value'], isNull);
    expect(unknown['rawCompatibilityValue'], 999);
    expect(unknown['missing'], true);
    expect((items[0] as Map)['quantity'], {
      'factorPer100g': 1.5,
      'grams': 150.0,
    });
    expect((items[1] as Map)['quantity'], {
      'factorPer100g': 0.25,
      'grams': 25.0,
    });
  });

  for (final mutation in [
    'dangling',
    'duplicate',
    'unused',
    'checksum',
    'unknown',
    'quantity',
  ]) {
    test('self-resigned compact $mutation remains rejected', () {
      final root = _root();
      final files = root['files'] as Map;
      final snapshots = files[userPortableDataFoodItemSnapshotsPath] as List;
      final firstItem =
          (((files['meals.json'] as List).first as Map)['items'] as List).first
              as Map;
      switch (mutation) {
        case 'dangling':
          firstItem['snapshotId'] = List.filled(64, 'f').join();
          break;
        case 'duplicate':
          snapshots.add(snapshots.first);
          break;
        case 'unused':
          final extra = jsonDecode(jsonEncode(snapshots.first)) as Map;
          (extra['snapshot'] as Map)['foodName'] = 'Unused captured snapshot';
          extra['snapshotId'] = portableCanonicalSha256(extra['snapshot']);
          snapshots.add(extra);
          snapshots.sort(
            (a, b) => ((a as Map)['snapshotId'] as String).compareTo(
              (b as Map)['snapshotId'] as String,
            ),
          );
          break;
        case 'checksum':
          ((snapshots.first as Map)['snapshot'] as Map)['foodName'] =
              'Tampered evidence';
          break;
        case 'unknown':
          firstItem['hiddenOverride'] = 0;
          break;
        case 'quantity':
          (firstItem['quantity'] as Map)['grams'] = 12345;
          break;
      }
      expect(
        _inspect(_resign(root)).status,
        UserPortableDataPreviewStatus.corrupt,
      );
    });
  }

  test(
    'reference fanout is refused before resolved record views are allocated',
    () {
      final root = _root();
      _rewriteSnapshot(
        root,
        (snapshot) => snapshot['foodTags'] = List.filled(3000, 'x'),
      );
      final files = root['files'] as Map;
      final firstMeal = (files['meals.json'] as List).first as Map;
      final item = ((firstMeal['items'] as List).first as Map);
      firstMeal['items'] = List.filled(1000, item);
      files['meals.json'] = [firstMeal];
      // Retain only the actually referenced snapshot; unused-entry detection
      // cannot mask the separately tested expansion refusal.
      files[userPortableDataFoodItemSnapshotsPath] =
          (files[userPortableDataFoodItemSnapshotsPath] as List)
              .where(
                (entry) => (entry as Map)['snapshotId'] == item['snapshotId'],
              )
              .toList();
      final text = _resign(root);
      expect(_independentNodes(jsonDecode(text)), lessThan(500000));
      expect(() => decodeBoundedPortableJson(text), returnsNormally);
      expect(
        () => PortableDataCompactTransportService.resolve(_files(root)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'code',
            'portable_compact_logical_node_budget',
          ),
        ),
      );
      expect(_inspect(text).status, UserPortableDataPreviewStatus.corrupt);
    },
  );

  test(
    'small wire cannot amplify a permitted string past logical byte limit',
    () {
      final root = _root();
      _rewriteSnapshot(
        root,
        (snapshot) => snapshot['foodName'] = List.filled(65536, 'x').join(),
      );
      final files = root['files'] as Map;
      final firstMeal = (files['meals.json'] as List).first as Map;
      final item = ((firstMeal['items'] as List).first as Map);
      firstMeal['items'] = List.filled(600, item);
      files['meals.json'] = [firstMeal];
      files[userPortableDataFoodItemSnapshotsPath] =
          (files[userPortableDataFoodItemSnapshotsPath] as List)
              .where(
                (entry) => (entry as Map)['snapshotId'] == item['snapshotId'],
              )
              .toList();
      final text = _resign(root);
      expect(() => decodeBoundedPortableJson(text), returnsNormally);
      expect(
        () => PortableDataCompactTransportService.resolve(_files(root)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'code',
            'portable_compact_logical_byte_budget',
          ),
        ),
      );
    },
  );

  test('wire depth 24 cannot become logical envelope depth 25', () {
    final root = _root();
    _rewriteSnapshot(root, (snapshot) {
      Object? nested = 0;
      for (var index = 0; index < 17; index++) {
        nested = {'a': nested};
      }
      (snapshot['catalogProvenance'] as Map)['aminoAcidProfile'] = nested;
    });
    final text = _resign(root);
    expect(() => decodeBoundedPortableJson(text), returnsNormally);
    expect(
      () => PortableDataCompactTransportService.resolve(_files(root)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'code',
          'portable_compact_logical_depth_budget',
        ),
      ),
    );
  });

  test(
    'actual 10k/2k fixture fits wire limits and retains whole restore payload',
    () {
      final fixture = PersonalLogBenchmarkFixture.generate(10000);
      // Raw jsonEncode hashes are runtime-qualified: VM retains integral-double
      // .0 tokens; the original 034 release-Web fixture used browser encoding.
      const isBrowser = bool.fromEnvironment('dart.library.js_interop');
      expect(
        fixture.inputSha256,
        isBrowser
            ? '97db49a275871c8fd1592ff28318a77c0a67400d8390052c74346226b6534eba'
            : '523447a7df5cd46c195fbdfb063cb6d10a7fe6253954fb5171c094e69973a228',
      );
      final artifact = _service.create(
        snapshot: _snapshot(fixture),
        generatedAt: _time,
      );
      expect(artifact.document['schemaVersion'], 5);
      _expectIndependentWireHashes(artifact.document);
      expect(_independentNodes(artifact.document), lessThanOrEqualTo(500000));
      expect(
        utf8.encode(artifact.prettyJson).length,
        lessThanOrEqualTo(32 * 1024 * 1024),
      );
      final logical = PortableDataCompactTransportService.resolve(
        _files(artifact.document),
      );
      expect(logical.logicalNodeCount, _independentNodes(logical.files));
      expect(logical.logicalNodeCount, lessThanOrEqualTo(1200000));
      expect(
        logical.logicalCanonicalBytes,
        utf8.encode(portableCanonicalJson(logical.files)).length,
      );
      final preview = _inspect(artifact.canonicalJson);
      expect(preview.status, UserPortableDataPreviewStatus.ready);
      final payload = _service.prepareLocalRestore(
        packageJson: artifact.canonicalJson,
        currentUserScope: _owner,
        currentDoseOwnerScope: _owner,
        currentScopeKind: _kind,
        currentState: PortableDataRestoreState({
          'profile': UserProfile.defaults().toJson(),
          'activeDrugIds': [],
          'intakes': [],
          'meals': [],
          'eventHistory': [],
        }),
        foodCatalog: fixture.foods,
        medicationCatalog: fixture.drugs,
      );
      final mealsById = {
        for (final row in payload.json['meals'] as List)
          (row as Map)['id']: row,
      };
      final intakesById = {
        for (final row in payload.json['intakes'] as List)
          (row as Map)['id']: row,
      };
      expect(
        portableCanonicalJson(mealsById),
        portableCanonicalJson({
          for (final meal in fixture.meals) meal.id: meal.toJson(),
        }),
      );
      expect(
        portableCanonicalJson(intakesById),
        portableCanonicalJson({
          for (final intake in fixture.intakes) intake.id: intake.toJson(),
        }),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
