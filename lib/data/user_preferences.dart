import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Lưu trữ và truy xuất các cài đặt vĩnh viễn theo từng tài khoản (userKey),
/// không bao giờ bị xóa khi người dùng đăng xuất.
class UserPreferences {
  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  static final Map<String, String> _memoryCache = <String, String>{};

  static String _phoneKey(String userKey) =>
      'tiktube_permanent_phone_${userKey.trim().toLowerCase()}';

  /// Lưu số điện thoại vĩnh viễn cho tài khoản [userKey]
  static Future<void> saveUserPhone(String userKey, String phone) async {
    final cleanKey = userKey.trim().toLowerCase();
    final cleanPhone = phone.trim();
    if (cleanKey.isEmpty) return;

    if (cleanPhone.isEmpty) {
      _memoryCache.remove(cleanKey);
    } else {
      _memoryCache[cleanKey] = cleanPhone;
    }

    try {
      if (cleanPhone.isEmpty) {
        await _prefs
            .remove(_phoneKey(cleanKey))
            .timeout(const Duration(milliseconds: 500));
      } else {
        await _prefs
            .setString(_phoneKey(cleanKey), cleanPhone)
            .timeout(const Duration(milliseconds: 500));
      }
    } catch (_) {}
  }

  /// Lấy số điện thoại đã lưu vĩnh viễn của tài khoản [userKey]
  static Future<String?> getUserPhone(String userKey) async {
    final cleanKey = userKey.trim().toLowerCase();
    if (cleanKey.isEmpty) return null;

    if (_memoryCache.containsKey(cleanKey)) {
      return _memoryCache[cleanKey];
    }

    try {
      final saved = await _prefs
          .getString(_phoneKey(cleanKey))
          .timeout(const Duration(milliseconds: 500));
      if (saved != null && saved.isNotEmpty) {
        _memoryCache[cleanKey] = saved;
        return saved;
      }
    } catch (_) {}
    return null;
  }
}
