import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/tiktube_api.dart';
import '../models/auth_session.dart';
import '../models/profile.dart';
import 'auth_session_store.dart';

enum AuthStatus { restoring, unauthenticated, authenticated }

/// Giữ trạng thái đăng nhập của toàn app.
class AuthController extends ChangeNotifier {
  AuthController(this._api, {AuthSessionStore? store})
      : _store = store ?? createAuthSessionStore();

  final TikTubeApi _api;
  final AuthSessionStore _store;

  AuthStatus _status = AuthStatus.restoring;
  Profile? _profile;
  String? _token;

  AuthStatus get status => _status;
  Profile? get profile => _profile;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _profile != null;

  /// Đọc phiên đã lưu. Nếu có token + hồ sơ, vào app ngay rồi xác thực lại
  /// trong nền; token hết hạn sẽ tự quay về màn hình đăng nhập.
  Future<void> restore() async {
    String? raw;
    try {
      raw = await _store.read();
    } catch (_) {
      raw = null;
    }

    if (raw == null || raw.trim().isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Phiên đăng nhập không hợp lệ.');
      }
      final session = AuthSession.fromJson(decoded);
      if (session.token.isEmpty) {
        throw const FormatException('Thiếu token đăng nhập.');
      }

      _token = session.token;
      _profile = session.profile;
      _status = AuthStatus.authenticated;
      _api.setAuthToken(_token);
      notifyListeners();

      try {
        final Profile fresh = await _api.fetchProfile();
        _profile = fresh;
        await _persist();
        notifyListeners();
      } on ApiException catch (error) {
        if (error.statusCode == 401) {
          await _clearLocal();
          notifyListeners();
        }
        // Lỗi mạng: giữ phiên đã lưu để app vẫn mở được.
      } catch (_) {
        // Lỗi mạng: giữ phiên đã lưu để app vẫn mở được.
      }
    } catch (_) {
      await _clearLocal();
      notifyListeners();
    }
  }

  Future<void> login({
    required String login,
    required String password,
  }) async {
    final session = await _api.login(login: login, password: password);
    await _apply(session);
  }

  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
    int? age,
  }) async {
    final session = await _api.register(
      name: name,
      username: username,
      email: email,
      password: password,
      phone: phone,
      age: age,
    );
    await _apply(session);
  }

  Future<void> _apply(AuthSession session) async {
    _token = session.token;
    _profile = session.profile;
    _status = AuthStatus.authenticated;
    _api.setAuthToken(_token);
    await _persist();
    notifyListeners();
  }

  /// Đăng xuất: luôn xoá phiên cục bộ, kể cả khi server không phản hồi.
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Vẫn đăng xuất trên thiết bị.
    }
    _api.setAuthToken(null);
    await _clearLocal();
    notifyListeners();
  }

  /// Cập nhật hồ sơ đang hiển thị sau khi người dùng lưu ở trang tài khoản.
  void updateProfileCache(Profile profile) {
    _profile = profile;
    unawaited(_persist());
    notifyListeners();
  }

  Future<void> _persist() async {
    final token = _token;
    final profile = _profile;
    if (token == null || profile == null) return;
    try {
      await _store.write(
        jsonEncode(AuthSession(token: token, profile: profile).toJson()),
      );
    } catch (_) {
      // Bộ nhớ thiết bị có thể bị chặn; không làm hỏng phiên hiện tại.
    }
  }

  Future<void> _clearLocal() async {
    _token = null;
    _profile = null;
    _status = AuthStatus.unauthenticated;
    try {
      await _store.clear();
    } catch (_) {
      // Bỏ qua lỗi lưu trữ.
    }
  }
}
