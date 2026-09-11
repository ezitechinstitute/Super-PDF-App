import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  AuthStorage._();

  static const String _tokenKey = 'auth_token';

  /// Save the Sanctum authentication token.
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    final success = await prefs.setString(_tokenKey, token);

    if (!success) {
      throw Exception('Failed to save authentication token.');
    }
  }

  /// Get the saved authentication token.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_tokenKey);
  }

  /// Check whether an authentication token exists.
  static Future<bool> hasToken() async {
    final token = await getToken();

    return token != null && token.trim().isNotEmpty;
  }

  /// Remove the saved authentication token.
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
  }
}
