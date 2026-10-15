import 'dart:convert';

import '../entities/portable_schema_migration.dart';

const userPortableDataCompactSchemaVersion = 5;
const userPortableDataFoodItemSnapshotsPath = 'food_item_snapshots.json';

/// Additional semantic-expansion limits for schema 5, never substitutes for
/// the unchanged 500000-node/32-MiB lexical and decoded *wire* limits.
/// These count the eight logical embedded files, including every reference use.
const userPortableDataMaxLogicalFileNodes = 1200000;
const userPortableDataMaxLogicalFileBytes = 32 * 1024 * 1024;
const userPortableDataMaxLogicalDepth = 24;
const userPortableDataMaxFoodItemSnapshots = 25000;

class PortableCompactLogicalFiles {
  const PortableCompactLogicalFiles({
    required this.files,
    required this.logicalNodeCount,
    required this.logicalCanonicalBytes,
  });

  /// Meal rows/items are shallow views. Nested immutable snapshot evidence is
  /// shared, rather than copying a large referenced tree for every use.
  final Map<String, Object?> files;
  final int logicalNodeCount;
  final int logicalCanonicalBytes;
}

/// A schema-defined encoding of complete captured item evidence. Sharing does
/// not reconcile foods, update a catalogue or infer a quantity/nutrient value.
abstract final class PortableDataCompactTransportService {
  static const _snapshotFields = <String>{
    'foodId',
    'foodName',
    'foodCategory',
    'foodTags',
    'nutrientsPer100g',
    'catalogProvenance',
  };
  static const _mealFields = <String>{
    'id',
    'title',
    'time',
    'context',
    'items',
    'computedTotalsStatus',
  };

  static Map<String, Object?> encode(Map<String, Object?> logicalFiles) {
    if (logicalFiles.containsKey(userPortableDataFoodItemSnapshotsPath)) {
      throw const FormatException('portable_compact_snapshot_file_conflict');
    }
    final snapshots = <String, Map<String, Object?>>{};
    final canonicalSnapshots = <String, String>{};
    final meals = _rows(logicalFiles['meals.json']);
    final compactMeals = <Object?>[];
    for (final rawMeal in meals) {
      final meal = _map(rawMeal);
      _exactKeys(meal, _mealFields);
      final compactItems = <Object?>[];
      for (final rawItem in _rows(meal['items'])) {
        final item = _map(rawItem);
        _exactKeys(item, <String>{..._snapshotFields, 'quantity'});
        final snapshot = Map<String, Object?>.from(item)..remove('quantity');
        final canonical = portableCanonicalJson(snapshot);
        final id = portableSha256(canonical);
        final previous = canonicalSnapshots[id];
        if (previous != null && previous != canonical) {
          throw const FormatException(
            'portable_compact_snapshot_hash_collision',
          );
        }
        if (previous == null) {
          snapshots[id] = snapshot;
          canonicalSnapshots[id] = canonical;
        }
        compactItems.add(<String, Object?>{
          'snapshotId': id,
          'quantity': item['quantity'],
        });
      }
      compactMeals.add(<String, Object?>{...meal, 'items': compactItems});
    }
    final ids = snapshots.keys.toList()..sort();
    final result = <String, Object?>{
      ...logicalFiles,
      'meals.json': compactMeals,
      userPortableDataFoodItemSnapshotsPath: <Object?>[
        for (final id in ids)
          <String, Object?>{'snapshotId': id, 'snapshot': snapshots[id]},
      ],
    };
    // Export must satisfy the same expansion contract as untrusted input.
    resolve(result);
    return result;
  }

  /// Must be called only after the production bounded wire parser/decoded
  /// guard. Counts all uses before producing any resolved record views, so a
  /// small reference table cannot amplify into an unbounded allocation.
  static PortableCompactLogicalFiles resolve(Map<String, Object?> wireFiles) {
    final rawSnapshots = _rows(
      wireFiles[userPortableDataFoodItemSnapshotsPath],
    );
    if (rawSnapshots.length > userPortableDataMaxFoodItemSnapshots) {
      throw const FormatException('portable_compact_snapshot_record_budget');
    }
    final snapshots = <String, Map<String, Object?>>{};
    final measures = <String, _JsonMeasure>{};
    String? lastId;
    for (final rawEntry in rawSnapshots) {
      final entry = _map(rawEntry);
      _exactKeys(entry, const <String>{'snapshotId', 'snapshot'});
      final id = entry['snapshotId'];
      if (id is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
          (lastId != null && lastId.compareTo(id) >= 0)) {
        throw const FormatException('portable_compact_snapshot_id_or_order');
      }
      final snapshot = _map(entry['snapshot']);
      _exactKeys(snapshot, _snapshotFields);
      final measure = _measure(snapshot);
      // Snapshot nodes sit at full-envelope depth 6 when referenced by an item.
      if (measure.depth + 5 > userPortableDataMaxLogicalDepth) {
        throw const FormatException('portable_compact_logical_depth_budget');
      }
      if (portableCanonicalSha256(snapshot) != id) {
        throw const FormatException('portable_compact_snapshot_checksum');
      }
      snapshots[id] = _freezeMap(snapshot);
      measures[id] = measure;
      lastId = id;
    }
    final meals = _rows(wireFiles['meals.json']);
    final base = Map<String, Object?>.from(wireFiles)
      ..remove(userPortableDataFoodItemSnapshotsPath)
      ..['meals.json'] = const <Object?>[];
    final baseMeasure = _measure(base);
    var nodes = baseMeasure.nodes;
    var bytes = baseMeasure.bytes;
    if (baseMeasure.depth + 1 > userPortableDataMaxLogicalDepth) {
      throw const FormatException('portable_compact_logical_depth_budget');
    }
    _requireLogicalBudget(nodes, bytes);
    final used = <String>{};
    // First pass only measures immutable evidence and each reference's cost.
    // Canonical JSON byte counts include delimiters, escaping and field names.
    for (var mealIndex = 0; mealIndex < meals.length; mealIndex++) {
      final meal = _map(meals[mealIndex]);
      _exactKeys(meal, _mealFields);
      final items = _rows(meal['items']);
      final mealBase = _measure(<String, Object?>{
        ...meal,
        'items': const <Object?>[],
      });
      if (mealBase.depth + 3 > userPortableDataMaxLogicalDepth) {
        throw const FormatException('portable_compact_logical_depth_budget');
      }
      nodes += mealBase.nodes;
      bytes += mealBase.bytes + (mealIndex == 0 ? 0 : 1);
      _requireLogicalBudget(nodes, bytes);
      for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final item = _map(items[itemIndex]);
        _exactKeys(item, const <String>{'snapshotId', 'quantity'});
        final id = item['snapshotId'];
        final snapshotMeasure = id is String ? measures[id] : null;
        if (snapshotMeasure == null) {
          throw const FormatException('portable_compact_snapshot_reference');
        }
        final quantity = _map(item['quantity']);
        _exactKeys(quantity, const <String>{'factorPer100g', 'grams'});
        final quantityMeasure = _measure(quantity);
        if (quantityMeasure.depth + 6 > userPortableDataMaxLogicalDepth) {
          throw const FormatException('portable_compact_logical_depth_budget');
        }
        // The snapshot root becomes the item's root; adding the quantity does
        // not introduce a second container node.
        nodes += snapshotMeasure.nodes + quantityMeasure.nodes;
        bytes += snapshotMeasure.bytes + quantityMeasure.bytes + 12;
        if (itemIndex != 0) bytes += 1;
        _requireLogicalBudget(nodes, bytes);
        used.add(id as String);
      }
    }
    if (used.length != snapshots.length) {
      throw const FormatException('portable_compact_unused_snapshot');
    }
    final logicalMeals = <Object?>[];
    for (final rawMeal in meals) {
      final meal = _map(rawMeal);
      logicalMeals.add(
        Map<String, Object?>.unmodifiable(<String, Object?>{
          ...meal,
          'items': List<Object?>.unmodifiable(<Object?>[
            for (final rawItem in _rows(meal['items']))
              () {
                final item = _map(rawItem);
                return Map<String, Object?>.unmodifiable(<String, Object?>{
                  ...snapshots[item['snapshotId']]!,
                  'quantity': _freezeMap(_map(item['quantity'])),
                });
              }(),
          ]),
        }),
      );
    }
    return PortableCompactLogicalFiles(
      files: Map<String, Object?>.unmodifiable(<String, Object?>{
        ...base,
        'meals.json': List<Object?>.unmodifiable(logicalMeals),
      }),
      logicalNodeCount: nodes,
      logicalCanonicalBytes: bytes,
    );
  }

  static void _requireLogicalBudget(int nodes, int bytes) {
    if (nodes > userPortableDataMaxLogicalFileNodes) {
      throw const FormatException('portable_compact_logical_node_budget');
    }
    if (bytes > userPortableDataMaxLogicalFileBytes) {
      throw const FormatException('portable_compact_logical_byte_budget');
    }
  }

  static List _rows(Object? value) {
    if (value is! List) {
      throw const FormatException('portable_compact_invalid_rows');
    }
    return value;
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const FormatException('portable_compact_invalid_object');
    }
    return Map<String, Object?>.from(value);
  }

  static void _exactKeys(Map<String, Object?> value, Set<String> fields) {
    if (value.length != fields.length ||
        value.keys.any((key) => !fields.contains(key))) {
      throw const FormatException('portable_compact_unknown_or_missing_field');
    }
  }

  static Object? _freeze(Object? value) {
    if (value is Map) return _freezeMap(_map(value));
    if (value is List) {
      return List<Object?>.unmodifiable(value.map<Object?>(_freeze));
    }
    return value;
  }

  static Map<String, Object?> _freezeMap(Map<String, Object?> value) =>
      Map<String, Object?>.unmodifiable(<String, Object?>{
        for (final entry in value.entries) entry.key: _freeze(entry.value),
      });

  static _JsonMeasure _measure(Object? value) {
    if (value is Map) {
      var nodes = 1;
      var bytes = 2 + (value.isEmpty ? 0 : value.length - 1);
      var depth = 1;
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const FormatException('portable_compact_invalid_object');
        }
        final child = _measure(entry.value);
        nodes += child.nodes;
        bytes += utf8.encode(jsonEncode(entry.key)).length + 1 + child.bytes;
        if (child.depth + 1 > depth) depth = child.depth + 1;
        _requireLogicalBudget(nodes, bytes);
      }
      return _JsonMeasure(nodes, bytes, depth);
    }
    if (value is List) {
      var nodes = 1;
      var bytes = 2 + (value.isEmpty ? 0 : value.length - 1);
      var depth = 1;
      for (final item in value) {
        final child = _measure(item);
        nodes += child.nodes;
        bytes += child.bytes;
        if (child.depth + 1 > depth) depth = child.depth + 1;
        _requireLogicalBudget(nodes, bytes);
      }
      return _JsonMeasure(nodes, bytes, depth);
    }
    if (value != null && value is! String && value is! num && value is! bool ||
        value is num && !value.isFinite) {
      throw const FormatException('portable_compact_invalid_scalar');
    }
    return _JsonMeasure(1, utf8.encode(jsonEncode(value)).length, 1);
  }
}

class _JsonMeasure {
  const _JsonMeasure(this.nodes, this.bytes, this.depth);
  final int nodes;
  final int bytes;
  final int depth;
}
