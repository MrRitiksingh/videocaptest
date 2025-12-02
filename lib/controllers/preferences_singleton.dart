import 'dart:async' show Future;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PreferenceUtils {
  static Future<SharedPreferences> get _instance async =>
      _prefsInstance ??= await SharedPreferences.getInstance();
  static SharedPreferences? _prefsInstance;

  static Future<SharedPreferences?> init() async {
    _prefsInstance = await _instance;
    return _prefsInstance;
  }

  static Future<bool?> setBool(String key, bool value) async {
    return _prefsInstance?.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefsInstance?.getBool(key);
  }

  static String? getString(String key) {
    return _prefsInstance?.getString(key);
  }

  static List<String>? getStringList(String key) {
    return _prefsInstance?.getStringList(key);
  }

  static Future<bool> setString(String key, String value) async {
    var prefs = await _instance;
    return prefs.setString(key, value);
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    var prefs = await _instance;
    return prefs.setStringList(key, value);
  }

  static Future<bool> setMap(String key, Map<String, dynamic> value) async {
    var prefs = await _instance;
    String jsonString = jsonEncode(value); // Convert Map to JSON string
    return prefs.setString(key, jsonString);
  }

  // Get Map<String, dynamic>
  static Future<Map<String, dynamic>?> getMap(String key) async {
    var prefs = await _instance;
    String? jsonString = prefs.getString(key);
    if (jsonString != null) {
      return jsonDecode(jsonString); // Convert JSON string back to Map
    }
    return null;
  }

  static Future<bool> clear() async {
    var prefs = await _instance;
    return prefs.clear();
  }

  static Future<bool> remove(String key) async {
    var prefs = await _instance;
    return prefs.remove(key);
  }
}
