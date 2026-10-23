import 'auth_session_store_base.dart';

AuthSessionStore createPlatformAuthSessionStore() => _MemoryAuthSessionStore();

String? _session;

class _MemoryAuthSessionStore implements AuthSessionStore {
  @override
  String? read() => _session;

  @override
  void write(String value) {
    _session = value;
  }

  @override
  void clear() {
    _session = null;
  }
}
