import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../security/cdss_identifier_factory.dart';

/// Optional capability. Sequential reads never satisfy this interface.
abstract interface class CdssCatalogSnapshotReader {
  Future<CdssCatalogTableSnapshot> readFoodCatalogSnapshot();
}

/// One local transaction boundary, not an upstream catalogue release.
final class CdssCatalogTableSnapshot {
  static const schemaId = 'parkinsum.cdss-catalog-table-snapshot/2';
  static const tables = [
    'food_variant',
    'food_concept',
    'observation',
    'concept_variant_crosswalk',
    'source_document',
    'variant_scope',
    'ingestion_run',
    'engine_snapshot',
    'resolved_fact',
    'conflict_audit_log',
  ];
  CdssCatalogTableSnapshot({
    required Map<String, List<Map<String, Object?>>> rows,
    required this.consistency,
  }) : rows = _freeze(rows) {
    if (rows.keys.toSet().length != tables.length ||
        !tables.every(rows.containsKey)) {
      throw const FormatException('Incomplete catalogue transaction.');
    }
  }
  final Map<String, List<Map<String, Object?>>> rows;
  final String consistency;
  List<String> get holds {
    final result = <String>[];
    if (consistency != 'native_sqlite_transaction' &&
        consistency != 'web_single_document') {
      result.add('unverified_transaction_boundary');
    }
    Set<String> identities(String table, String field) {
      final ids = <String>{};
      for (final row in rows[table]!) {
        final id = row[field]?.toString() ?? '';
        if (id.isEmpty || !ids.add(id)) {
          result.add('ambiguous_$table');
        }
      }
      return ids;
    }

    final variants = identities('food_variant', 'food_variant_id');
    final concepts = identities('food_concept', 'food_concept_id');
    final sources = identities('source_document', 'source_doc_id');
    final scopes = identities('variant_scope', 'scope_hash');
    identities('observation', 'observation_id');
    identities('engine_snapshot', 'snapshot_id');
    identities('ingestion_run', 'run_id');
    identities('resolved_fact', 'fact_id');
    identities('conflict_audit_log', 'audit_id');
    identities('concept_variant_crosswalk', 'crosswalk_id');
    final runs = rows['ingestion_run']!;
    for (final run in runs.where((r) => r['status'] == 'running')) {
      final id = run['run_id'];
      final completed = runs.any((r) {
        if (r['run_id'] != '${id}_promote' || r['status'] != 'completed') {
          return false;
        }
        try {
          final notes = jsonDecode('${r['notes_json']}');
          return notes is Map &&
              notes['staging_snapshot_id'] == run['snapshot_id'] &&
              rows['engine_snapshot']!.any(
                (s) =>
                    s['snapshot_id'] == r['snapshot_id'] &&
                    s['promoted_at'] != null,
              );
        } on FormatException {
          return false;
        }
      });
      final terminalHeld = runs.any((r) {
        if (r['run_id'] != '${id}_promote' ||
            r['status'] != 'held_for_conflict_review' ||
            r['snapshot_id'] != run['snapshot_id']) {
          return false;
        }
        try {
          final notes = jsonDecode(r['notes_json'] as String) as Map;
          final evidence = notes['review_evidence'] as Map;
          final payload = evidence['payload'] as Map;
          return notes['activated'] == false &&
              evidence['schema'] == 'parkinsum.held-import-review-evidence/2' &&
              payload['run_id'] == id &&
              payload['snapshot_id'] == run['snapshot_id'] &&
              evidence['input_sha256'] ==
                  CdssIdentifierFactory().inputDigest(
                    'held-import-review-evidence',
                    payload,
                  ) &&
              rows['engine_snapshot']!.any(
                (s) =>
                    s['snapshot_id'] == run['snapshot_id'] &&
                    s['promoted_at'] == null,
              );
        } catch (_) {
          return false;
        }
      });
      // A complete non-activated held episode is terminal history; no staging
      // row from it is ever emitted by this current live-table reader.
      if (!completed && !terminalHeld) {
        result.add('incomplete_promotion');
      }
    }
    for (final row in rows['food_variant']!) {
      if (!concepts.contains(row['food_concept_id'])) {
        result.add('dangling_food_concept');
      }
    }
    for (final row in rows['observation']!) {
      if (row['domain'] != 'food') {
        continue;
      }
      if (!variants.contains(row['entity_key'])) {
        result.add('dangling_food_observation');
      }
      if (!sources.contains(row['source_doc_id'])) {
        result.add('dangling_observation_source');
      }
      final scope = row['scope_hash'];
      if (scope != null && scope != '' && !scopes.contains(scope)) {
        result.add('dangling_observation_scope');
      }
    }
    for (final row in rows['concept_variant_crosswalk']!) {
      if (row['domain'] != 'food') {
        continue;
      }
      if (!variants.contains(row['variant_id']) ||
          !concepts.contains(row['concept_id']) ||
          !sources.contains(row['source_doc_id'])) {
        result.add('dangling_food_crosswalk');
      }
    }
    return (result.toSet().toList()..sort());
  }

  Map<String, Object?> toAuditJson() {
    final tableHashes = {
      for (final table in tables)
        table: sha256.convert(utf8.encode(_canonical(rows[table]))).toString(),
    };
    final body = <String, Object?>{
      'schema_id': schemaId,
      'consistency': consistency,
      'table_sha256': tableHashes,
      'row_counts': {for (final t in tables) t: rows[t]!.length},
      'holds': holds,
      'status': holds.isEmpty ? 'captured' : 'HOLD',
      'scope':
          'One local SQLite transaction or one complete Web storage document plus completed-promotion/reference checks; not an upstream full catalogue release or source authenticity proof.',
      'volatile_exclusions': ['_synced_at'],
    };
    return {
      ...body,
      'sha256': sha256.convert(utf8.encode(_canonical(body))).toString(),
    };
  }
}

Map<String, List<Map<String, Object?>>> _freeze(
  Map<String, List<Map<String, Object?>>> value,
) {
  Object? freeze(Object? v) {
    if (v is Map) {
      return Map<String, Object?>.unmodifiable(
        v.map((k, x) => MapEntry(k as String, freeze(x))),
      );
    }
    if (v is List) {
      return List<Object?>.unmodifiable(v.map(freeze));
    }
    return v;
  }

  return Map.unmodifiable({
    for (final entry in value.entries)
      entry.key: List<Map<String, Object?>>.unmodifiable(
        entry.value.map((r) => freeze(r) as Map<String, Object?>),
      ),
  });
}

String _canonical(Object? value) {
  Object? normalize(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {
        for (final key in keys)
          if (key != '_synced_at') key: normalize(v[key]),
      };
    }
    if (v is List) {
      return v.map(normalize).toList();
    }
    return v;
  }

  return jsonEncode(normalize(value));
}
