import 'dart:async';

import 'package:flutter/material.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_scope.dart';
import 'auth/auth_session_store.dart';
import 'data/api_client.dart';
import 'data/tiktube_api.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class PtkTubeApp extends StatefulWidget {
  const PtkTubeApp({
    super.key,
    this.api,
    this.authRequired = true,
    this.authStore,
  });

  /// Cho phép test hoặc môi trường khác thay nguồn dữ liệu.
  /// Mặc định dùng REST API tại `API_BASE_URL` (http://127.0.0.1:8787).
  final TikTubeApi? api;

  /// Tắt cổng đăng nhập khi test các màn hình bằng API giả lập.
  final bool authRequired;

  /// Cho phép test bơm bộ nhớ phiên thay cho localStorage.
  final AuthSessionStore? authStore;

  @override
  State<PtkTubeApp> createState() => _PtkTubeAppState();
}

class _PtkTubeAppState extends State<PtkTubeApp> {
  final ThemeController _theme = ThemeController();
  late final TikTubeApi _api;
  AuthController? _auth;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiClient();
    if (widget.authRequired) {
      _auth = AuthController(_api, store: widget.authStore);
      unawaited(_auth!.restore());
    }
  }

  @override
  void dispose() {
    _auth?.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController? auth = _auth;
    if (auth == null) {
      return AnimatedBuilder(
        animation: _theme,
        builder: (BuildContext context, Widget? child) {
          return ThemeScope(
            notifier: _theme,
            child: MaterialApp(
              title: 'TIKTUBE - Xem & Chia sẻ Video - Đăng Video',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: _theme.mode,
              home: child,
            ),
          );
        },
        child: HomeScreen(api: _api),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_theme, auth]),
      builder: (BuildContext context, Widget? child) {
        final Widget home = switch (auth.status) {
          AuthStatus.restoring => const _AuthSplashScreen(),
          AuthStatus.unauthenticated => AuthScreen(controller: auth),
          AuthStatus.authenticated => HomeScreen(api: _api),
        };

        return AuthScope(
          notifier: auth,
          child: ThemeScope(
            notifier: _theme,
            child: MaterialApp(
              key: ValueKey<AuthStatus>(auth.status),
              title: 'TIKTUBE - Xem & Chia sẻ Video - Đăng Video',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: _theme.mode,
              home: home,
            ),
          ),
        );
      },
    );
  }
}

class _AuthSplashScreen extends StatelessWidget {
  const _AuthSplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B1A),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF080A18),
              Color(0xFF16112F),
              Color(0xFF26123F),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 33,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFFFF3850),
                          Color(0xFFC90C27),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      'PTK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text.rich(
                    const TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: 'TIK',
                          style: TextStyle(color: Color(0xFFFF5A70)),
                        ),
                        TextSpan(
                          text: 'TUBE',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Đang kiểm tra phiên đăng nhập...',
                style: TextStyle(
                  color: Color(0xB8FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
