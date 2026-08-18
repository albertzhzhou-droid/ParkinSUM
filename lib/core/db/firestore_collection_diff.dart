import 'dart:collection';
import 'dart:convert';

final RegExp _firestoreDocumentIdPattern = RegExp(r'^[A-Za-z0-9._:-]{1,160}$');

class FirestoreCollectionSyncPlan {
  final Map<String, Map<String, dynamic>> upserts;
  final Set<String> removals;

  const FirestoreCollectionSyncPlan({
    required this.upserts,
    required this.removals,
  });

  int get mutationCount => upserts.length + removals.length;
  bool get isEmpty => mutationCount == 0;
}

/// Computes the minimal remote mutations needed to make a user collection
/// match the locally committed list.
///
/// This keeps unchanged documents intact, which avoids the former
/// delete-everything/recreate-everything window and dramatically reduces the
/// number of billed writes. The caller remains responsible for committing each
/// returned plan in bounded Firestore batches.
FirestoreCollectionSyncPlan planFirestoreCollectionSync({
  required Map<String, Map<String, dynamic>> existing,
  required Map<String, Map<String, dynamic>> desired,
}) {
  for (final id in desired.keys) {
    if (!_firestoreDocumentIdPattern.hasMatch(id)) {
      throw ArgumentError.value(id, 'desired', 'unsafe Firestore document ID');
    }
  }

  final upserts = <String, Map<String, dynamic>>{};
  for (final entry in desired.entries) {
    _canonicalize(entry.value);
    final current = existing[entry.key];
    if (current == null || !_canonicalJsonEquals(current, entry.value)) {
      upserts[entry.key] = Map<String, dynamic>.unmodifiable(entry.value);
    }
  }

  return FirestoreCollectionSyncPlan(
    upserts: Map<String, Map<String, dynamic>>.unmodifiable(upserts),
    removals: Set<String>.unmodifiable(
      existing.keys.toSet()..removeAll(desired.keys),
    ),
  );
}

bool _canonicalJsonEquals(Object? left, Object? right) {
  return jsonEncode(_canonicalize(left)) == jsonEncode(_canonicalize(right));
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      sorted['${entry.key}'] = _canonicalize(entry.value);
    }
    return sorted;
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw ArgumentError.value(
    value,
    'document',
    'must contain only JSON-compatible values',
  );
}
