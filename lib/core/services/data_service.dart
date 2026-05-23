import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// DataService：统一的键值存储抽象层
/// 要求：上层（UI/引擎）不关心落盘方式，只调用这里的 API
abstract class DataService {
  Future<void> setString(String key, String value);
  Future<String?> getString(String key);
  Future<void> remove(String key);

  /// 写入 JSON Map（默认实现：转成 String）
  Future<void> setJson(String key, Map<String, dynamic> json) async {
    await setString(key, jsonEncode(json));
  }

  /// 读取 JSON Map（默认实现：从 String decode）
  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  /// 写入 JSON List（默认实现：转成 String）
  Future<void> setJsonList(String key, List<Map<String, dynamic>> list) async {
    await setString(key, jsonEncode(list));
  }

  /// 读取 JSON List（默认实现：从 String decode）
  Future<List<dynamic>?> getJsonList(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded;
    return null;
  }
}

/// SharedPreferences 落盘实现
class SharedPrefsDataService implements DataService {
  SharedPreferences? _prefs;

  /// 延迟初始化，避免启动阶段过多 await
  Future<SharedPreferences> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<void> setString(String key, String value) async {
    final p = await _ensure();
    await p.setString(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    final p = await _ensure();
    return p.getString(key);
  }

  @override
  Future<void> remove(String key) async {
    final p = await _ensure();
    await p.remove(key);
  }

  // ✅ 关键：如果你项目里之前把 getJson 声明成 abstract（老版本残留），
  // 这里显式 override 一次，确保不会再报 “missing implementation”
  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> json) async {
    await setString(key, jsonEncode(json));
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
  Future<void> setJsonList(String key, List<Map<String, dynamic>> list) async {
    await setString(key, jsonEncode(list));
  }
}
