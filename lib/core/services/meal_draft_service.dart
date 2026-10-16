import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_draft.dart';

abstract interface class MealDraftStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? document, bool Function() authorize);
}

class LocalMealDraftStore implements MealDraftStore {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(key);
  }

  @override
  Future<void> write(
    String key,
    String? document,
    bool Function() authorize,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (!authorize()) throw StateError('meal_draft_session_changed');
    final saved = document == null
        ? await prefs.remove(key)
        : await prefs.setString(key, document);
    if (!saved) throw StateError('meal_draft_save_rejected');
    if (!authorize()) throw StateError('meal_draft_session_changed');
  }
}

class MemoryMealDraftStore implements MealDraftStore {
  final Map<String, String> documents = {};
  @override
  Future<String?> read(String key) async => documents[key];
  @override
  Future<void> write(
    String key,
    String? document,
    bool Function() authorize,
  ) async {
    if (!authorize()) throw StateError('meal_draft_session_changed');
    if (document == null) {
      documents.remove(key);
    } else {
      documents[key] = document;
    }
  }
}

/// A single resumable entry per owner. Serial writes prevent slow autosaves
/// from resurrecting a draft after its save / discard has completed.
class MealDraftService {
  MealDraftService({required this.store});
  final MealDraftStore store;
  Future<void> _serial = Future<void>.value();

  static String storageKey(String owner) {
    if (owner.trim().isEmpty ||
        owner.length > 512 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(owner)) {
      throw ArgumentError('Invalid meal draft owner');
    }
    return 'parkinsum.meal_draft.v1.${sha256.convert(utf8.encode(owner))}';
  }

  Future<MealDraft?> load(String owner) async {
    await _serial;
    final raw = await store.read(storageKey(owner));
    if (raw == null) return null;
    if (utf8.encode(raw).length > 512 * 1024) {
      throw const FormatException('Meal draft exceeds storage capacity');
    }
    final envelope = jsonDecode(raw) as Map;
    if (envelope['schemaId'] != 'parkinsum.owner-meal-draft/1' ||
        envelope['ownerDigest'] !=
            sha256.convert(utf8.encode(owner)).toString() ||
        envelope.length != 3) {
      throw const FormatException('Meal draft owner or schema mismatch');
    }
    return MealDraft.fromJson(
      Map<String, dynamic>.from(envelope['draft'] as Map),
    );
  }

  Future<void> save(
    String owner,
    MealDraft draft, {
    required bool Function() authorize,
  }) => _run(() async {
    // Validate before accepting a new persistence schema.
    MealDraft.fromJson(draft.toJson());
    final raw = jsonEncode({
      'schemaId': 'parkinsum.owner-meal-draft/1',
      'ownerDigest': sha256.convert(utf8.encode(owner)).toString(),
      'draft': draft.toJson(),
    });
    if (utf8.encode(raw).length > 512 * 1024) {
      throw StateError('meal_draft_capacity_reached');
    }
    if (!authorize()) throw StateError('meal_draft_session_changed');
    await store.write(storageKey(owner), raw, authorize);
  });

  Future<void> clear(
    String owner,
    String draftId, {
    required bool Function() authorize,
  }) => _run(() async {
    final key = storageKey(owner);
    final raw = await store.read(key);
    if (raw == null) return;
    final saved = jsonDecode(raw) as Map;
    if ((saved['draft'] as Map)['draftId'] != draftId) return;
    if (!authorize()) throw StateError('meal_draft_session_changed');
    await store.write(key, null, authorize);
  });

  Future<void> _run(Future<void> Function() operation) {
    final next = _serial.then((_) => operation());
    _serial = next.catchError((Object _) {});
    return next;
  }
}
