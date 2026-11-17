import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Kết quả trả về sau khi người dùng đăng nhập bằng tài khoản Google thật.
class GoogleAuthResult {
  const GoogleAuthResult({
    required this.email,
    required this.name,
    this.avatarUrl,
  });

  final String email;
  final String name;
  final String? avatarUrl;
}

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static const String googleClientId =
      '767308821556-u8m4lou3li7a97avu47c9mkd5569lj4v.apps.googleusercontent.com';

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? googleClientId : null,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('GoogleSignIn.initialize notice: $e');
    }
  }

  /// Kích hoạt đăng nhập Google thật:
  /// - Mở cửa sổ "Chọn tài khoản" của Google (accounts.google.com)
  /// - Người dùng chọn tài khoản Gmail thật của mình từ trình duyệt / thiết bị
  /// - Nhận email, họ tên, ảnh đại diện từ Google
  Future<GoogleAuthResult?> signIn() async {
    await _ensureInitialized();

    try {
      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate(
        scopeHint: const <String>['email', 'profile', 'openid'],
      );

      return GoogleAuthResult(
        email: account.email,
        name: account.displayName ?? account.email.split('@').first,
        avatarUrl: account.photoUrl,
      );
    } catch (e) {
      debugPrint('GoogleSignIn.authenticate error: $e');
      rethrow;
    }
  }
}
