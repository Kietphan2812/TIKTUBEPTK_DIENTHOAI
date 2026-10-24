import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session_store_base.dart';

AuthSessionStore createPlatformAuthSessionStore() =>
    _SharedPreferencesAuthSessionStore();

/// Lưu phiên bằng bộ nhớ bền của hệ điều hành (Android/iOS/desktop).
///
/// `SharedPreferencesAsync` không cần khởi tạo trước và đọc/ghi bất đồng bộ,
/// nên phiên vẫn còn sau khi người dùng thoát hẳn ứng dụng.
class _SharedPreferencesAuthSessionStore implements AuthSessionStore {
  static const String _key = 'tiktube.auth.session.v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read() => _preferences.getString(_key);

  @override
  Future<void> write(String value) => _preferences.setString(_key, value);

  @override
  Future<void> clear() => _preferences.remove(_key);
}
