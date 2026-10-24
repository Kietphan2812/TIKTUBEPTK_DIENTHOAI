import 'package:web/web.dart' as web;

import 'auth_session_store_base.dart';

AuthSessionStore createPlatformAuthSessionStore() => _WebAuthSessionStore();

class _WebAuthSessionStore implements AuthSessionStore {
  static const String _key = 'tiktube.auth.session.v1';

  @override
  Future<String?> read() async => web.window.localStorage.getItem(_key);

  @override
  Future<void> write(String value) async =>
      web.window.localStorage.setItem(_key, value);

  @override
  Future<void> clear() async => web.window.localStorage.removeItem(_key);
}
