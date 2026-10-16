import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../models/portable_data_restore.dart';
import '../models/user_preference_write_scope.dart';
import '../services/user_state_change_notifications.dart';
import 'web_user_state_store.dart';

final class _VerifiedUserStateEnvelope {
  _VerifiedUserStateEnvelope({
    required this.raw,
    required Map<String, Object?> value,
    required this.legacyCanonicalJson,
  }) : value = Map<String, Object?>.unmodifiable({
         ...value,
         'legacyKeys': Map<String, String?>.unmodifiable(
           Map<String, String?>.from(value['legacyKeys'] as Map),
         ),
       });

  final String raw;
  final Map<String, Object?> value;
  final String legacyCanonicalJson;
}

/// One complete envelope retains the unchanged legacy values, their witness,
/// and the current aggregate. It preserves existing restore/history atomicity
/// without splitting records across multiple independently committed keys.
final class IndexedDbWebUserStateStore implements WebUserStateStore {
  IndexedDbWebUserStateStore({
    this.databaseName = 'parkinsum.personal-records.v1',
    this.beforePublication,
    this.afterWriteQueued,
    this.afterPublication,
    this.readCurrentLegacy,
  });

  final String databaseName;

  /// Synchronous seams for abort-before-publication and lost-ack tests. Tests
  /// use an explicitly disposable database; production supplies neither hook.
  final void Function()? beforePublication;
  final void Function()? afterWriteQueued;
  final void Function()? afterPublication;

  /// Production supplies a synchronous six-key reader so the active IndexedDB
  /// callback can reject an intervening uncoordinated legacy write. An injected
  /// test store may instead use its explicit synthetic preference adapter.
  final WebUserStateLegacySnapshot Function()? readCurrentLegacy;
  static const _objectStore = 'documents';
  static const _documentKey = 'user_state';
  static const _schema = 'parkinsum.indexeddb-user-state/1';
  static const _envelopeKeys = <String>[
    'schema',
    'legacyKeys',
    'legacyDigest',
    'document',
    'documentDigest',
  ];
  web.IDBDatabase? _database;
  _VerifiedUserStateEnvelope? _verifiedEnvelope;
  ({String document, String digest})? _lastCandidateDigest;

  @override
  String get backendId => 'IndexedDB / personal-record aggregate';

  String get _markerKey => 'parkinsum.indexeddb.migrated.$databaseName';

  Future<web.IDBDatabase> _open() async {
    final prior = _database;
    if (prior != null) return prior;
    if (!web.window.isSecureContext) {
      throw StateError('web_user_state_storage_unavailable');
    }
    final completed = Completer<web.IDBDatabase>();
    try {
      final request = web.window.indexedDB.open(databaseName, 1);
      request.onupgradeneeded = ((web.Event _) {
        try {
          final database = request.result as web.IDBDatabase;
          database.createObjectStore(_objectStore);
        } catch (_) {
          request.transaction?.abort();
        }
      }).toJS;
      request.onblocked = ((web.Event _) {
        if (!completed.isCompleted) {
          completed.completeError(StateError('web_user_state_storage_blocked'));
        }
      }).toJS;
      request.onerror = ((web.Event _) {
        if (!completed.isCompleted) {
          completed.completeError(
            StateError('web_user_state_storage_unavailable'),
          );
        }
      }).toJS;
      request.onsuccess = ((web.Event _) {
        final database = request.result as web.IDBDatabase;
        if (completed.isCompleted) {
          database.close();
          return;
        }
        database.onversionchange = ((web.Event _) {
          database.close();
          if (identical(_database, database)) {
            _database = null;
            _verifiedEnvelope = null;
            _lastCandidateDigest = null;
          }
        }).toJS;
        _database = database;
        completed.complete(database);
      }).toJS;
      return await completed.future;
    } catch (_) {
      throw StateError('web_user_state_storage_unavailable');
    }
  }

  Future<String?> _readRaw() async {
    final database = await _open();
    final completed = Completer<String?>();
    String? value;
    final transaction = database.transaction(_objectStore.toJS, 'readonly');
    transaction.oncomplete = ((web.Event _) {
      if (!completed.isCompleted) completed.complete(value);
    }).toJS;
    transaction.onabort = ((web.Event _) {
      if (!completed.isCompleted) {
        completed.completeError(StateError('web_user_state_read_aborted'));
      }
    }).toJS;
    final request = transaction
        .objectStore(_objectStore)
        .get(_documentKey.toJS);
    request.onsuccess = ((web.Event _) {
      try {
        final result = request.result;
        value = result == null ? null : (result as JSString).toDart;
      } catch (_) {
        transaction.abort();
      }
    }).toJS;
    return completed.future;
  }

  Future<void> _compareAndPut(
    String candidate, {
    required String? expectedRaw,
    required bool Function() authorize,
    required WebUserStateLegacySnapshot legacy,
    bool invokeHook = false,
  }) async {
    final database = await _open();
    if (!authorize()) throw StateError('web_user_state_authorization_changed');
    final completed = Completer<void>();
    Object? refusal;
    final transaction = database.transaction(
      _objectStore.toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    transaction.oncomplete = ((web.Event _) {
      if (!completed.isCompleted) completed.complete();
    }).toJS;
    transaction.onabort = ((web.Event _) {
      if (!completed.isCompleted) {
        completed.completeError(
          refusal ?? StateError('web_user_state_write_aborted'),
        );
      }
    }).toJS;
    final objectStore = transaction.objectStore(_objectStore);
    final request = objectStore.get(_documentKey.toJS);
    request.onsuccess = ((web.Event _) {
      try {
        final result = request.result;
        final current = result == null ? null : (result as JSString).toDart;
        if (current != expectedRaw) {
          throw StateError('web_user_state_document_changed');
        }
        if (!authorize()) {
          throw StateError('web_user_state_authorization_changed');
        }
        if (invokeHook) beforePublication?.call();
        _requireUnchangedLiveLegacy(legacy);
        // Queue the write in this active request callback. Awaiting unrelated
        // Futures here could let IndexedDB auto-commit before put is queued.
        objectStore.put(candidate.toJS, _documentKey.toJS);
        if (invokeHook) afterWriteQueued?.call();
        _requireUnchangedLiveLegacy(legacy);
      } catch (error) {
        refusal = error;
        transaction.abort();
      }
    }).toJS;
    await completed.future;
  }

  _VerifiedUserStateEnvelope _verifyEnvelope(
    String raw,
    WebUserStateLegacySnapshot legacy,
  ) {
    // The caller has just read the actual IndexedDB value and checked live
    // legacy storage. Only byte-for-byte equality reuses a prior verification;
    // a different raw value always passes the complete decoder and witnesses.
    final verified = _verifiedEnvelope;
    if (verified != null && verified.raw == raw) {
      if (legacy.canonicalJson != verified.legacyCanonicalJson) {
        throw StateError('web_user_state_legacy_writer_conflict');
      }
      return verified;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded.length != _envelopeKeys.length ||
        !_envelopeKeys.every(decoded.containsKey) ||
        decoded['schema'] != _schema ||
        decoded['legacyKeys'] is! Map ||
        (decoded['document'] != null && decoded['document'] is! String)) {
      throw const FormatException('Invalid personal-record storage envelope.');
    }
    final old = WebUserStateLegacySnapshot(
      Map<String, String?>.from(decoded['legacyKeys'] as Map),
    );
    if (decoded['legacyDigest'] != old.digest ||
        decoded['documentDigest'] !=
            portableRestoreDigest(decoded['document'])) {
      throw const FormatException('Invalid personal-record storage witness.');
    }
    if (legacy.canonicalJson != old.canonicalJson) {
      throw StateError('web_user_state_legacy_writer_conflict');
    }
    final result = _VerifiedUserStateEnvelope(
      raw: raw,
      value: Map<String, Object?>.from(decoded),
      legacyCanonicalJson: old.canonicalJson,
    );
    _verifiedEnvelope = result;
    return result;
  }

  void _requireUnchangedLiveLegacy(WebUserStateLegacySnapshot legacy) {
    final current = readCurrentLegacy?.call();
    if (current != null && current.canonicalJson != legacy.canonicalJson) {
      throw StateError('web_user_state_legacy_writer_conflict');
    }
  }

  void _ensureMigrationMarker() {
    // The marker is required BEFORE any new record mutation, after the exact
    // original snapshot has committed. A failed marker leaves only that
    // unchanged snapshot in IndexedDB and refuses the requested mutation.
    try {
      final storage = web.window.localStorage;
      final prior = storage.getItem(_markerKey);
      if (prior != null && prior != '1') {
        throw StateError('web_user_state_migration_marker_invalid');
      }
      if (prior == null) storage.setItem(_markerKey, '1');
      if (storage.getItem(_markerKey) != '1') {
        throw StateError('web_user_state_migration_marker_unavailable');
      }
    } catch (_) {
      throw StateError('web_user_state_migration_marker_unavailable');
    }
  }

  Future<_VerifiedUserStateEnvelope> _ensureEnvelope(
    WebUserStateLegacySnapshot legacy,
  ) async {
    _requireUnchangedLiveLegacy(legacy);
    final prior = await _readRaw();
    _requireUnchangedLiveLegacy(legacy);
    if (prior != null) {
      final verified = _verifyEnvelope(prior, legacy);
      _ensureMigrationMarker();
      return verified;
    }
    _verifiedEnvelope = null;
    // A surviving marker distinguishes first migration from disappearance of
    // the previously authoritative database. Never resurrect an old snapshot.
    if (web.window.localStorage.getItem(_markerKey) != null) {
      throw StateError('web_user_state_authoritative_document_missing');
    }
    final document = legacy.values['db.user_state.v1'];
    final envelope = <String, Object?>{
      'schema': _schema,
      'legacyKeys': legacy.values,
      'legacyDigest': legacy.digest,
      'document': document,
      'documentDigest': portableRestoreDigest(document),
    };
    final candidate = jsonEncode(envelope);
    await _compareAndPut(
      candidate,
      expectedRaw: null,
      authorize: () => true,
      legacy: legacy,
    );
    if (await _readRaw() != candidate) {
      throw StateError('web_user_state_migration_readback_mismatch');
    }
    _requireUnchangedLiveLegacy(legacy);
    _ensureMigrationMarker();
    debugPrint('WebUserState: original snapshot retained in IndexedDB');
    return _verifyEnvelope(candidate, legacy);
  }

  @override
  Future<String?> read(WebUserStateLegacySnapshot legacy) async =>
      (await _ensureEnvelope(legacy)).value['document'] as String?;

  String _candidateDigest(String document) {
    // A failed transaction can retry the exact same immutable document. This
    // memo is only a mathematical result, never proof that a write persisted.
    // Reading a different external envelope still verifies it independently.
    final previous = _lastCandidateDigest;
    if (previous != null && previous.document == document) {
      return previous.digest;
    }
    final digest = portableRestoreDigest(document);
    _lastCandidateDigest = (document: document, digest: digest);
    return digest;
  }

  @override
  Future<void> write(
    String document, {
    required String? expectedDocument,
    required WebUserStateLegacySnapshot legacy,
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('web_user_state_authorization_changed');
    final prior = await _ensureEnvelope(legacy);
    final envelope = prior.value;
    if (envelope['document'] != expectedDocument) {
      throw StateError('web_user_state_document_changed');
    }
    final nextEnvelope = <String, Object?>{
      ...envelope,
      'document': document,
      'documentDigest': _candidateDigest(document),
    };
    final candidate = jsonEncode(nextEnvelope);
    await _compareAndPut(
      candidate,
      expectedRaw: prior.raw,
      authorize: authorize,
      legacy: legacy,
      invokeHook: true,
    );
    if (await _readRaw() != candidate) {
      throw StateError('web_user_state_write_readback_mismatch');
    }
    // There is no transaction spanning localStorage and IndexedDB. A legacy
    // writer in another browser agent can still change after the last active
    // callback check. Refuse success and retain both values in that case.
    _requireUnchangedLiveLegacy(legacy);
    // This envelope combines verified immutable legacy evidence with the
    // exact document whose digest we just computed. A completed transaction
    // and exact readback prove these bytes persisted; do not hash them again
    // on the next read. External changes still miss the exact-raw cache.
    _verifiedEnvelope = _VerifiedUserStateEnvelope(
      raw: candidate,
      value: nextEnvelope,
      legacyCanonicalJson: prior.legacyCanonicalJson,
    );
    notifyUserStateChanged();
    afterPublication?.call();
    _requireUnchangedLiveLegacy(legacy);
    try {
      if (!authorize()) {
        throw StateError('web_user_state_authorization_changed');
      }
    } on UserPreferenceWriteScopeChanged {
      throw const UserPreferenceWriteCommittedForPreviousSession();
    }
    debugPrint('WebUserState: complete personal-record aggregate persisted');
  }

  /// Closing a connection preserves every record; useful for restart checks.
  void close() {
    _database?.close();
    _database = null;
    _verifiedEnvelope = null;
    _lastCandidateDigest = null;
  }
}
