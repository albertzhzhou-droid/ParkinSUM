import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const careWorkspaceDocumentMaxBytes = 8 * 1024 * 1024;

/// Local-only storage. Each account has a separate key; no health payload or
/// readable account identifier is included in that key.
abstract interface class CareWorkspaceStore {
  Future<String?> read(String ownerScope);

  /// Implementations must check authorization immediately before committing.
  /// A write already submitted to an asynchronous backend may finish after
  /// sign-out, but remains confined to its original owner key. Do not report
  /// success to that expired session or roll back another session's changes.
  Future<void> write(
    String ownerScope,
    String document, {
    required bool Function() authorize,
  });
}

String careWorkspaceStorageKey(String ownerScope) {
  if (ownerScope.trim().isEmpty ||
      ownerScope.length > 512 ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(ownerScope)) {
    throw ArgumentError('Invalid account scope');
  }
  final digest = sha256.convert(utf8.encode('care-workspace-v1|$ownerScope'));
  return 'parkinsum.care_workspace.v1.$digest';
}

final class LocalCareWorkspaceStore implements CareWorkspaceStore {
  @override
  Future<String?> read(String ownerScope) async {
    final key = careWorkspaceStorageKey(ownerScope);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(key);
  }

  @override
  Future<void> write(
    String ownerScope,
    String document, {
    required bool Function() authorize,
  }) async {
    final key = careWorkspaceStorageKey(ownerScope);
    _requireAuthorization(authorize);
    _requireDocumentCapacity(document);
    final prefs = await SharedPreferences.getInstance();
    _requireAuthorization(authorize);
    final saved = await prefs.setString(key, document);
    if (!saved) throw StateError('care_workspace_save_rejected');
    _requireAuthorization(authorize);
  }
}

final class MemoryCareWorkspaceStore implements CareWorkspaceStore {
  final Map<String, String> documents = <String, String>{};

  @override
  Future<String?> read(String ownerScope) async =>
      documents[careWorkspaceStorageKey(ownerScope)];

  @override
  Future<void> write(
    String ownerScope,
    String document, {
    required bool Function() authorize,
  }) async {
    final key = careWorkspaceStorageKey(ownerScope);
    _requireAuthorization(authorize);
    _requireDocumentCapacity(document);
    documents[key] = document;
  }
}

void _requireAuthorization(bool Function() authorize) {
  if (!authorize()) throw StateError('care_workspace_session_changed');
}

void _requireDocumentCapacity(String document) {
  if (document.length > careWorkspaceDocumentMaxBytes ||
      utf8.encode(document).length > careWorkspaceDocumentMaxBytes) {
    throw StateError('care_workspace_capacity_reached');
  }
}
