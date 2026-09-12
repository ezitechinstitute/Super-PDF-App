import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last successful `/recent-files` response on the device.
///
/// Recent files came straight from the API, so the section sat empty whenever
/// the phone was offline or the server was unreachable — which is exactly when
/// a user is most likely to be looking for a file they made earlier. Caching
/// the last good response lets the list survive that.
class RecentFilesCache {
  RecentFilesCache._();

  static const String _payloadKey = 'recent_files_payload';
  static const String _savedAtKey = 'recent_files_saved_at';

  /// Stores the raw response body. Parsing stays with the caller so this
  /// class does not have to know the response shape.
  static Future<void> save(dynamic responseData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_payloadKey, jsonEncode(responseData));
      await prefs.setInt(
        _savedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // A cache write must never break a screen that already has its data.
      debugPrint('⚠️ Recent files cache write failed: $e');
    }
  }

  /// The last stored response body, or null when nothing is cached or the
  /// stored value can no longer be decoded.
  static Future<dynamic> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? payload = prefs.getString(_payloadKey);

      if (payload == null || payload.isEmpty) return null;

      return jsonDecode(payload);
    } catch (e) {
      debugPrint('⚠️ Recent files cache read failed: $e');
      return null;
    }
  }

  /// When the cache was written, for telling the user how stale it is.
  static Future<DateTime?> savedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final int? millis = prefs.getInt(_savedAtKey);

      if (millis == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_payloadKey);
      await prefs.remove(_savedAtKey);
    } catch (e) {
      debugPrint('⚠️ Recent files cache clear failed: $e');
    }
  }
}
