import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/usecases/user_portable_data_package_service.dart';
import 'care_workspace_service.dart';

const carePortableDataSchemaVersion = 1;
const carePortableDataFormat = 'parkinsum_care_portable_data_package';
const _ownerRole = 'package_owner';
const _recordCollections = <String>[
  'observations',
  'notes',
  'medicationDiscussionEntries',
  'medicationDiscussionOutcomes',
  'medicationListReviews',
];

/// This is a separate Care-only artifact. The ordinary v4 package does not
/// supply a Care snapshot, even when it contains exported observations.
final class CarePortableDataArtifact {
  const CarePortableDataArtifact._(this.json, this.contentSha256, this.counts);
  final String json;
  final String contentSha256;
  final Map<String, int> counts;
}

/// The constructor is private: callers cannot substitute the frozen target.
final class CarePortableRestorePreview {
  CarePortableRestorePreview._({
    required this.before,
    required this.after,
    required this.packageSha256,
    required this.sessionEpoch,
    required this.counts,
  }) : beforeSha256 = carePortableSnapshotDigest(before),
       afterSha256 = carePortableSnapshotDigest(after);

  final CareWorkspaceSnapshot before;
  final CareWorkspaceSnapshot after;
  final String beforeSha256;
  final String afterSha256;
  final String packageSha256;
  final int sessionEpoch;
  final Map<String, int> counts;
  bool get changesState => beforeSha256 != afterSha256;
}

/// A process-local acknowledgement of a single Care document write, not a
/// durable restore ledger or cancellation of a write already accepted by OS.
final class CarePortableRestoreReceipt {
  const CarePortableRestoreReceipt._(this.preview);
  final CarePortableRestorePreview preview;
}

String carePortableSnapshotDigest(CareWorkspaceSnapshot snapshot) =>
    _digest(snapshot.toJson());

final class CarePortableDataService {
  const CarePortableDataService();

  CarePortableDataArtifact create({
    required CareWorkspaceSnapshot snapshot,
    required DateTime createdAt,
  }) {
    if (createdAt.toUtc().year < 1 || createdAt.toUtc().year > 9999) {
      throw const FormatException('care_portable_invalid_timestamp');
    }
    // Validate the entire existing schema before changing structured owner
    // fields. User-authored strings and prompt input snapshots are untouched.
    CareWorkspaceSnapshot.decode(
      jsonEncode(snapshot.toJson()),
      ownerScope: snapshot.ownerScope,
    );
    final payload = _transport(
      snapshot.toJson(),
      snapshot.ownerScope,
      encode: true,
    );
    final counts = _counts(payload);
    final body = <String, Object?>{
      'format': carePortableDataFormat,
      'schemaVersion': carePortableDataSchemaVersion,
      'availability': 'captured_current_local_snapshot',
      'createdAt': createdAt.toUtc().toIso8601String(),
      'ownerBinding': _ownerBinding(snapshot.ownerScope),
      'scope': 'care_only_no_user_state_or_reminder_activation',
      'workspace': payload,
    };
    final hash = _digest(body);
    final root = <String, Object?>{...body, 'contentSha256': hash};
    final raw = _canonical(root);
    decodeBoundedPortableJson(raw, maxBytes: careWorkspaceMaxBytes);
    return CarePortableDataArtifact._(raw, hash, counts);
  }

  /// Coverage is explicit for older general packages; unavailable never means
  /// an empty Care history and cannot be used for this restore operation.
  String availability(String raw) {
    final root = _object(
      decodeBoundedPortableJson(raw, maxBytes: careWorkspaceMaxBytes),
    );
    if (root['format'] == userPortableDataPackageFormat &&
        userPortableDataLegacyReadableVersions
            .union({userPortableDataPackageSchemaVersion})
            .contains(root['schemaVersion'])) {
      return 'unavailable_in_source_schema';
    }
    if (root['format'] != carePortableDataFormat ||
        root['schemaVersion'] != carePortableDataSchemaVersion ||
        root['availability'] != 'captured_current_local_snapshot') {
      throw const FormatException('care_portable_unsupported_version_or_scope');
    }
    return 'captured_current_local_snapshot';
  }

  CarePortableRestorePreview prepare({
    required String packageJson,
    required CareWorkspaceSnapshot current,
    required int sessionEpoch,
  }) {
    if (availability(packageJson) != 'captured_current_local_snapshot') {
      throw StateError('care_portable_snapshot_unavailable');
    }
    final root = _object(
      decodeBoundedPortableJson(packageJson, maxBytes: careWorkspaceMaxBytes),
    );
    _exact(root, const {
      'format',
      'schemaVersion',
      'availability',
      'createdAt',
      'ownerBinding',
      'scope',
      'workspace',
      'contentSha256',
    });
    if (root['ownerBinding'] != _ownerBinding(current.ownerScope) ||
        root['scope'] != 'care_only_no_user_state_or_reminder_activation') {
      throw const FormatException('care_portable_owner_or_scope_mismatch');
    }
    final at = root['createdAt'];
    if (at is! String ||
        !at.endsWith('Z') ||
        DateTime.tryParse(at)?.toUtc().toIso8601String() != at) {
      throw const FormatException('care_portable_invalid_timestamp');
    }
    final body = Map<String, Object?>.from(root)..remove('contentSha256');
    if (_digest(body) != root['contentSha256']) {
      throw const FormatException('care_portable_integrity_mismatch');
    }
    final payload = _object(root['workspace']);
    final restored = CareWorkspaceSnapshot.decode(
      jsonEncode(_transport(payload, current.ownerScope, encode: false)),
      ownerScope: current.ownerScope,
    );
    // A merge never silently replaces a record with the same identity.
    final merged = _object(current.toJson());
    final incoming = restored.toJson();
    for (final key in _recordCollections) {
      merged[key] = _merge(
        merged[key] as List,
        incoming[key] as List,
        identity: key == 'medicationListReviews' ? 'section' : 'id',
      );
    }
    final ledger = _object(merged['followups']);
    final incomingLedger = _object(incoming['followups']);
    ledger['prompts'] = _merge(
      ledger['prompts'] as List,
      incomingLedger['prompts'] as List,
    );
    final feedback = _merge(
      ledger['feedback'] as List,
      incomingLedger['feedback'] as List,
    );
    // Keep original sequence for equal timestamps; the ledger parser rejects
    // incompatible transitions rather than guessing which branch won.
    final orderedFeedback = feedback.indexed.toList();
    if ((ledger['feedback'] as List).isNotEmpty &&
        feedback.length != (ledger['feedback'] as List).length) {
      orderedFeedback.sort((a, b) {
        final time = (a.$2 as Map)['occurredAt'].toString().compareTo(
          (b.$2 as Map)['occurredAt'].toString(),
        );
        return time == 0 ? a.$1.compareTo(b.$1) : time;
      });
    }
    ledger['feedback'] = orderedFeedback.map((item) => item.$2).toList();
    merged['followups'] = ledger;
    final after = CareWorkspaceSnapshot.decode(
      jsonEncode(merged),
      ownerScope: current.ownerScope,
    );
    return CarePortableRestorePreview._(
      before: current,
      after: after,
      packageSha256: sha256.convert(utf8.encode(packageJson)).toString(),
      sessionEpoch: sessionEpoch,
      counts: _counts(payload),
    );
  }

  Future<CarePortableRestoreReceipt> commit({
    required CarePortableRestorePreview preview,
    required CareWorkspaceService service,
    required bool Function() authorize,
    required bool confirmed,
  }) async {
    if (!confirmed) throw StateError('care_portable_confirmation_required');
    await service.mutate(preview.before.ownerScope, (current) {
      if (carePortableSnapshotDigest(current) != preview.beforeSha256) {
        throw StateError('care_portable_preview_stale');
      }
      return preview.after;
    }, authorize: authorize);
    if (!authorize()) throw StateError('care_portable_session_changed');
    return CarePortableRestoreReceipt._(preview);
  }
}

Map<String, Object?> _transport(
  Map<String, Object?> document,
  String owner, {
  required bool encode,
}) {
  final value = _object(jsonDecode(jsonEncode(document)));
  final from = encode ? owner : _ownerRole;
  final to = encode ? _ownerRole : owner;
  if (value['ownerScope'] != from) {
    throw const FormatException('care_portable_owner_role_invalid');
  }
  value['ownerScope'] = to;
  for (final key in _recordCollections) {
    final records = value[key];
    if (records is! List) {
      throw const FormatException('care_portable_collection_missing');
    }
    for (var i = 0; i < records.length; i++) {
      final row = _object(records[i]);
      if (row['recorderId'] != from) {
        throw const FormatException('care_portable_recorder_role_invalid');
      }
      row['recorderId'] = to;
      records[i] = row;
    }
  }
  final ledger = _object(value['followups']);
  final feedback = ledger['feedback'];
  if (feedback is! List) {
    throw const FormatException('care_portable_feedback_missing');
  }
  for (var i = 0; i < feedback.length; i++) {
    final row = _object(feedback[i]);
    if (row['actorId'] != from) {
      throw const FormatException('care_portable_actor_role_invalid');
    }
    // The original feedback identity is retained. It is checked by the real
    // ledger parser only after restoring the current same-owner actor binding.
    row['actorId'] = to;
    feedback[i] = row;
  }
  ledger['feedback'] = feedback;
  value['followups'] = ledger;
  return value;
}

List<Object?> _merge(List current, List incoming, {String identity = 'id'}) {
  final result = <Object?>[...current];
  final byId = <Object?, Object?>{
    for (final row in current) (row as Map)[identity]: row,
  };
  for (final row in incoming) {
    final id = (row as Map)[identity];
    if (byId.containsKey(id)) {
      if (_canonical(byId[id]) != _canonical(row)) {
        throw StateError('care_portable_record_conflict');
      }
    } else {
      byId[id] = row;
      result.add(row);
    }
  }
  return result;
}

Map<String, int> _counts(Map<String, Object?> value) => Map.unmodifiable({
  for (final key in _recordCollections) key: (value[key] as List).length,
  'prompts': ((_object(value['followups']))['prompts'] as List).length,
  'feedback': ((_object(value['followups']))['feedback'] as List).length,
});

Map<String, Object?> _object(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('care_portable_expected_object');
  }
  return Map<String, Object?>.from(value);
}

void _exact(Map<String, Object?> value, Set<String> keys) {
  if (value.length != keys.length || !keys.containsAll(value.keys)) {
    throw const FormatException('care_portable_unexpected_fields');
  }
}

String _ownerBinding(String owner) =>
    _digest({'format': carePortableDataFormat, 'owner': owner});
String _digest(Object? value) =>
    sha256.convert(utf8.encode(_canonical(value))).toString();
String _canonical(Object? value) => jsonEncode(_sorted(value));
Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _sorted(value[key])};
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}
