import 'package:web/web.dart' as web;

import 'auth_session_store_base.dart';

AuthSessionStore createPlatformAuthSessionStore() => _WebAuthSessionStore();

class _WebAuthSessionStore implements AuthSessionStore {
  static const String _key = 'tiktube.auth.session.v1';

  @override
  String? read() => web.window.localStorage.getItem(_key);

  @override
  void write(String value) => web.window.localStorage.setItem(_key, value);

  @override
  void clear() => web.window.localStorage.removeItem(_key);
}
