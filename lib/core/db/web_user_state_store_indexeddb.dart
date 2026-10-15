import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../models/portable_data_restore.dart';
import '../models/user_preference_write_scope.dart';
import '../services/user_state_change_notifications.dart';
import 'web_user_state_store.dart';

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
          if (identical(_database, database)) _database = null;
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

  Map<String, Object?> _decode(String raw, WebUserStateLegacySnapshot legacy) {
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
    return Map<String, Object?>.from(decoded);
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

  Future<String> _ensureEnvelope(WebUserStateLegacySnapshot legacy) async {
    _requireUnchangedLiveLegacy(legacy);
    final prior = await _readRaw();
    _requireUnchangedLiveLegacy(legacy);
    if (prior != null) {
      _decode(prior, legacy);
      _ensureMigrationMarker();
      return prior;
    }
    // A surviving marker distinguishes first migration from disappearance of
    // the previously authoritative database. Never resurrect an old snapshot.
    if (web.window.localStorage.getItem(_markerKey) != null) {
      throw StateError('web_user_state_authoritative_document_missing');
    }
    final document = legacy.values['db.user_state.v1'];
    final candidate = jsonEncode({
      'schema': _schema,
      'legacyKeys': legacy.values,
      'legacyDigest': legacy.digest,
      'document': document,
      'documentDigest': portableRestoreDigest(document),
    });
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
    return candidate;
  }

  @override
  Future<String?> read(WebUserStateLegacySnapshot legacy) async =>
      _decode(await _ensureEnvelope(legacy), legacy)['document'] as String?;

  @override
  Future<void> write(
    String document, {
    required String? expectedDocument,
    required WebUserStateLegacySnapshot legacy,
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('web_user_state_authorization_changed');
    final prior = await _ensureEnvelope(legacy);
    final envelope = _decode(prior, legacy);
    if (envelope['document'] != expectedDocument) {
      throw StateError('web_user_state_document_changed');
    }
    final candidate = jsonEncode({
      ...envelope,
      'document': document,
      'documentDigest': portableRestoreDigest(document),
    });
    await _compareAndPut(
      candidate,
      expectedRaw: prior,
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
  }
}
