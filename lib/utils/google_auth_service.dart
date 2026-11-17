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
      '767308821556-4ofr0c7a66p78md3nrq1svn03i1u7q0a.apps.googleusercontent.com';

  bool _initialized = false;
  final StreamController<GoogleAuthResult> _authResultController =
      StreamController<GoogleAuthResult>.broadcast();

  Stream<GoogleAuthResult> get onUserSignedIn => _authResultController.stream;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? googleClientId : null,
        serverClientId: kIsWeb ? null : googleClientId,
      );
      _initialized = true;

      // Lắng nghe sự kiện đăng nhập từ Google Identity Services (trên Web & Mobile)
      GoogleSignIn.instance.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            final account = event.user;
            final result = GoogleAuthResult(
              email: account.email,
              name: account.displayName ?? account.email.split('@').first,
              avatarUrl: account.photoUrl,
            );
            _authResultController.add(result);
          }
        },
        onError: (Object e) {
          debugPrint('GoogleSignIn.authenticationEvents error: $e');
        },
      );
    } catch (e) {
      debugPrint('GoogleSignIn.initialize notice: $e');
    }
  }

  /// Kích hoạt đăng nhập Google thật:
  /// - Trên Mobile: gọi authenticate() mở native Google Account Chooser
  /// - Trên Web: không gọi authenticate() mà hệ thống sử dụng nút GIS renderButton()
  Future<GoogleAuthResult?> signIn() async {
    await ensureInitialized();

    if (GoogleSignIn.instance.supportsAuthenticate()) {
      try {
        final GoogleSignInAccount account =
            await GoogleSignIn.instance.authenticate(
          scopeHint: const <String>['email', 'profile', 'openid'],
        );

        final result = GoogleAuthResult(
          email: account.email,
          name: account.displayName ?? account.email.split('@').first,
          avatarUrl: account.photoUrl,
        );
        _authResultController.add(result);
        return result;
      } catch (e) {
        debugPrint('GoogleSignIn.authenticate error: $e');
        rethrow;
      }
    } else {
      // Trên Web, authenticate không được hỗ trợ theo quy chuẩn GIS.
      // Người dùng tương tác trực tiếp với nút buildGsiButton() do GIS render.
      return null;
    }
  }
}
