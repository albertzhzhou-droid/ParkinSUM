import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'data_service.dart';
import 'firebase_backend.dart';

/// Firestore key-value adapter for the existing DataService seam.
///
/// Layout:
/// users/{uid}/kv/{key}
///
/// Values stay JSON/string encoded so the old SharedPreferences contract keeps
/// working while storage moves to Firebase.
class FirestoreDataService implements DataService {
  final AuthService authService;
  final FirebaseFirestore firestore;

  FirestoreDataService({
    required this.authService,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  Future<DocumentReference<Map<String, dynamic>>> _doc(String key) async {
    await FirebaseBackend.ensureInitialized();
    final uid = await authService.ensureUser();
    return firestore.collection('users').doc(uid).collection('kv').doc(key);
  }

  @override
  Future<String?> getString(String key) async {
    final snapshot = await (await _doc(key)).get();
    return snapshot.data()?['value']?.toString();
  }

  @override
  Future<void> remove(String key) async {
    await (await _doc(key)).delete();
  }

  @override
  Future<void> setString(String key, String value) async {
    await (await _doc(key)).set({
      'value': value,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  @override
  Future<List<dynamic>?> getJsonList(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    return null;
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> json) {
    return setString(key, jsonEncode(json));
  }

  @override
  Future<void> setJsonList(String key, List<Map<String, dynamic>> list) {
    return setString(key, jsonEncode(list));
  }
}
