import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../models/user.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // Token Management
  static Future<void> saveToken(String token) async {
    await prefs.setString(AppConfig.tokenKey, token);
  }

  static String? getToken() {
    return prefs.getString(AppConfig.tokenKey);
  }

  static Future<void> deleteToken() async {
    await prefs.remove(AppConfig.tokenKey);
  }

  // User Data Management
  static Future<void> saveUser(User user) async {
    await prefs.setString(AppConfig.userKey, jsonEncode(user.toJson()));
  }

  static User? getUser() {
    final userJson = prefs.getString(AppConfig.userKey);
    if (userJson == null) return null;
    return User.fromJson(jsonDecode(userJson));
  }

  static Future<void> deleteUser() async {
    await prefs.remove(AppConfig.userKey);
  }

  // FCM Token
  static Future<void> saveFcmToken(String token) async {
    await prefs.setString(AppConfig.fcmTokenKey, token);
  }

  static String? getFcmToken() {
    return prefs.getString(AppConfig.fcmTokenKey);
  }

  // Clear All Data
  static Future<void> clearAll() async {
    await prefs.clear();
  }
}
