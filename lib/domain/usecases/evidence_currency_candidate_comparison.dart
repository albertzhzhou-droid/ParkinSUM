import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/origin_storage_coordination.dart';
import '../entities/evidence_currency.dart';
import '../entities/knowledge_pack.dart';
import '../entities/mechanistic_medication_applicability.dart';

/// Read-only candidate comparison. Both lanes call the existing currency gate
/// at the same explicit instant. This service has no registry activation API.
final class EvidenceCurrencyCandidateComparisonService {
  const EvidenceCurrencyCandidateComparisonService();

  EvidenceCurrencyComparisonReceipt compare({
    required EvidenceCurrencyRegistry baseline,
    required EvidenceCurrencyRegistry candidate,
    required DateTime asOfUtc,
  }) {
    if (!asOfUtc.isUtc) throw ArgumentError('Comparison time must be UTC.');
    final before = baseline.assess(asOfUtc: asOfUtc);
    final after = candidate.assess(asOfUtc: asOfUtc);
    final baselineById = {
      for (final record in baseline.records) record.claimId: record,
    };
    final candidateById = {
      for (final record in candidate.records) record.claimId: record,
    };
    final ids = {...baselineById.keys, ...candidateById.keys}.toList()..sort();
    final changes = <Map<String, Object?>>[];
    for (final id in ids) {
      final original = baselineById[id];
      final proposed = candidateById[id];
      if (original?.recordSha256 == proposed?.recordSha256) continue;
      changes.add({
        'claim_id': id,
        'change_kind': original == null
            ? 'added'
            : proposed == null
            ? 'removed'
            : 'changed',
        'before_record_sha256': original?.recordSha256,
        'candidate_record_sha256': proposed?.recordSha256,
        'before_effective_status': original?.effectiveStatusAt(asOfUtc).name,
        'candidate_effective_status': proposed?.effectiveStatusAt(asOfUtc).name,
        'before_recorded_status': original?.status.name,
        'candidate_recorded_status': proposed?.status.name,
      });
    }
    final providers =
        MechanisticApplicabilityManifest.current.providers
            .map((entry) => entry.providerId)
            .toList()
          ..sort();
    return EvidenceCurrencyComparisonReceipt._({
      'schema': EvidenceCurrencyComparisonReceipt.schema,
      'as_of_utc': asOfUtc.toIso8601String(),
      'baseline_snapshot': before.toJson(),
      'candidate_snapshot': after.toJson(),
      'claim_changes': changes,
      'provider_dispositions': [
        for (final provider in providers)
          {
            'provider_id': provider,
            'baseline': before.runtimeDispositionFor([provider]).name,
            'candidate': after.runtimeDispositionFor([provider]).name,
          },
      ],
      'runtime_activation_authorized': false,
      'boundary': EvidenceCurrencyComparisonReceipt.boundary,
    });
  }
}

/// Self-contained historical snapshots, rather than a pointer to the current
/// registry. Hashes establish internal consistency, never issuer authenticity.
final class EvidenceCurrencyComparisonReceipt {
  static const schema = 'parkinsum.evidence-currency-candidate-comparison/1';
  static const boundary =
      'Offline candidate comparison and retained historical snapshots only. No runtime activation, signature, source-validity, clinical-validation or treatment authority.';

  EvidenceCurrencyComparisonReceipt._(Map<String, Object?> body)
    : _canonicalBody = _checkedCanonicalBody(body);

  final String _canonicalBody;
  String get receiptSha256 => _comparisonHash(jsonDecode(_canonicalBody));
  Map<String, Object?> toJson() => {
    ...Map<String, Object?>.from(jsonDecode(_canonicalBody) as Map),
    'receipt_sha256': receiptSha256,
  };

  factory EvidenceCurrencyComparisonReceipt.fromJson(
    Map<String, dynamic> value,
  ) {
    const keys = {
      'schema',
      'as_of_utc',
      'baseline_snapshot',
      'candidate_snapshot',
      'claim_changes',
      'provider_dispositions',
      'runtime_activation_authorized',
      'boundary',
      'receipt_sha256',
    };
    if (value.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(value.keys.toSet()).isNotEmpty ||
        value['schema'] != schema ||
        value['boundary'] != boundary ||
        value['runtime_activation_authorized'] != false) {
      throw const FormatException('evidence_comparison_receipt_schema_invalid');
    }
    final instant = value['as_of_utc'];
    final parsed = instant is String ? DateTime.tryParse(instant) : null;
    if (parsed == null ||
        !parsed.isUtc ||
        parsed.toIso8601String() != instant ||
        value['baseline_snapshot'] is! Map ||
        value['candidate_snapshot'] is! Map ||
        value['claim_changes'] is! List ||
        value['provider_dispositions'] is! List) {
      throw const FormatException('evidence_comparison_receipt_shape_invalid');
    }
    final body = Map<String, Object?>.from(value)..remove('receipt_sha256');
    final receipt = EvidenceCurrencyComparisonReceipt._(body);
    if (receipt.receiptSha256 != value['receipt_sha256']) {
      throw const FormatException('evidence_comparison_receipt_digest_invalid');
    }
    return receipt;
  }
}

/// Reuses the app's existing local preference backend, under separate keys.
/// It never writes the knowledge-activation ledger or changes a currency gate.
/// Participating browser tabs use one lock around reload, validation and write.
/// Capacity exhaustion rejects a new receipt; historical snapshots are not
/// silently evicted. The owner identifier is hashed in the storage key.
abstract interface class EvidenceCurrencyComparisonReceiptStore {
  Future<List<EvidenceCurrencyComparisonReceipt>> load({
    bool Function()? authorize,
  });
  Future<void> retain(
    EvidenceCurrencyComparisonReceipt receipt, {
    bool Function()? authorize,
  });
}

final class LocalEvidenceCurrencyComparisonReceiptStore
    implements EvidenceCurrencyComparisonReceiptStore {
  LocalEvidenceCurrencyComparisonReceiptStore({required String ownerId})
    : _key =
          'parkinsum.evidence_currency_comparison.v1.${_comparisonHash(ownerId)}' {
    if (ownerId.trim().isEmpty ||
        ownerId.length > 512 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(ownerId)) {
      throw ArgumentError('Receipt owner is required.');
    }
  }
  final String _key;
  static final Map<String, Future<void>> _tails = {};

  @override
  Future<List<EvidenceCurrencyComparisonReceipt>> load({
    bool Function()? authorize,
  }) async {
    _requireReceiptAuthorization(authorize);
    await _tails[_key];
    _requireReceiptAuthorization(authorize);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _requireReceiptAuthorization(authorize);
    return _decode(prefs.getString(_key));
  }

  @override
  Future<void> retain(
    EvidenceCurrencyComparisonReceipt receipt, {
    bool Function()? authorize,
  }) {
    final operation = (_tails[_key] ?? Future<void>.value()).then(
      (_) => withOriginStorageLock(_key, () async {
        _requireReceiptAuthorization(authorize);
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        _requireReceiptAuthorization(authorize);
        final receipts = _decode(prefs.getString(_key));
        if (receipts.any(
          (item) => item.receiptSha256 == receipt.receiptSha256,
        )) {
          return;
        }
        if (receipts.length >= 128) {
          throw StateError('Evidence receipt capacity reached.');
        }
        final raw = jsonEncode({
          'schema_version': 1,
          'receipts': [
            ...receipts,
            receipt,
          ].map((item) => item.toJson()).toList(),
        });
        knowledgeDecode(raw, maxBytes: knowledgePackMaxBytes);
        _requireReceiptAuthorization(authorize);
        if (!await prefs.setString(_key, raw)) {
          throw StateError('Evidence receipt persistence failed.');
        }
        // An accepted backend write remains in its original owner archive.
        // An expired lease must not receive a successful acknowledgement.
        _requireReceiptAuthorization(authorize);
      }),
    );
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[_key] = tail;
    return operation.whenComplete(() {
      if (identical(_tails[_key], tail)) _tails.remove(_key);
    });
  }

  List<EvidenceCurrencyComparisonReceipt> _decode(String? raw) {
    if (raw == null) return [];
    final document = knowledgeDecode(raw, maxBytes: knowledgePackMaxBytes);
    if (document.length != 2 ||
        document['schema_version'] != 1 ||
        document['receipts'] is! List ||
        (document['receipts'] as List).length > 128) {
      throw const FormatException('evidence_comparison_archive_schema_invalid');
    }
    final receipts = (document['receipts'] as List)
        .map(
          (item) =>
              EvidenceCurrencyComparisonReceipt.fromJson(knowledgeMap(item)),
        )
        .toList();
    if (receipts.map((item) => item.receiptSha256).toSet().length !=
        receipts.length) {
      throw const FormatException(
        'evidence_comparison_archive_duplicate_receipt',
      );
    }
    return receipts;
  }
}

void _requireReceiptAuthorization(bool Function()? authorize) {
  if (authorize != null && !authorize()) {
    throw StateError('evidence_comparison_session_changed');
  }
}

String _checkedCanonicalBody(Map<String, Object?> body) {
  knowledgeCheckJson(body, maxBytes: knowledgePackMaxBytes);
  _checkReceiptSnapshotShape(body);
  return _comparisonCanonicalJson(body);
}

void _checkReceiptSnapshotShape(Map<String, Object?> body) {
  for (final lane in ['baseline_snapshot', 'candidate_snapshot']) {
    final snapshot = knowledgeMap(body[lane]);
    const snapshotKeys = {
      'registry_sha256',
      'snapshot_sha256',
      'as_of_utc',
      'requires_requalification',
      'held_claim_ids',
      'blocked_claim_ids',
      'affected_provider_ids',
      'affected_predicate_ids',
      'integrity_reasons',
      'records',
      'boundary',
    };
    if (!_sameReceiptKeys(snapshot.keys.toSet(), snapshotKeys) ||
        snapshot['as_of_utc'] != body['as_of_utc'] ||
        snapshot['requires_requalification'] is! bool ||
        snapshot['boundary'] is! String ||
        snapshot['records'] is! List) {
      throw const FormatException('evidence_comparison_snapshot_shape_invalid');
    }
    for (final key in ['registry_sha256', 'snapshot_sha256']) {
      if (snapshot[key] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(snapshot[key] as String)) {
        throw const FormatException(
          'evidence_comparison_snapshot_hash_invalid',
        );
      }
    }
    for (final key in [
      'held_claim_ids',
      'blocked_claim_ids',
      'affected_provider_ids',
      'affected_predicate_ids',
      'integrity_reasons',
    ]) {
      final list = snapshot[key];
      if (list is! List || list.any((item) => item is! String)) {
        throw const FormatException(
          'evidence_comparison_snapshot_list_invalid',
        );
      }
    }
    for (final rawRecord in snapshot['records'] as List) {
      final record = knowledgeMap(rawRecord);
      for (final key in [
        'claim_id',
        'claim',
        'source_id',
        'source_revision',
        'status',
        'effective_status',
      ]) {
        if (record[key] is! String) {
          throw const FormatException(
            'evidence_comparison_snapshot_record_invalid',
          );
        }
      }
    }
  }
  for (final rawChange in body['claim_changes'] as List) {
    final change = knowledgeMap(rawChange);
    if (change['claim_id'] is! String ||
        change['change_kind'] is! String ||
        !change.containsKey('before_recorded_status') ||
        !change.containsKey('candidate_recorded_status')) {
      throw const FormatException('evidence_comparison_change_shape_invalid');
    }
  }
  final dispositions = EvidenceCurrencyRuntimeDisposition.values
      .map((value) => value.name)
      .toSet();
  for (final rawRow in body['provider_dispositions'] as List) {
    final row = knowledgeMap(rawRow);
    if (!_sameReceiptKeys(row.keys.toSet(), {
          'provider_id',
          'baseline',
          'candidate',
        }) ||
        row['provider_id'] is! String ||
        !dispositions.contains(row['baseline']) ||
        !dispositions.contains(row['candidate'])) {
      throw const FormatException('evidence_comparison_provider_shape_invalid');
    }
  }
}

bool _sameReceiptKeys(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

String _comparisonHash(Object? value) =>
    sha256.convert(utf8.encode(_comparisonCanonicalJson(value))).toString();

String _comparisonCanonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_comparisonCanonicalJson(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_comparisonCanonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}
