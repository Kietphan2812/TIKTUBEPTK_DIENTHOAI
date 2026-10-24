import 'auth_session_store_base.dart';

AuthSessionStore createPlatformAuthSessionStore() => _MemoryAuthSessionStore();

String? _session;

class _MemoryAuthSessionStore implements AuthSessionStore {
  @override
  Future<String?> read() async => _session;

  @override
  Future<void> write(String value) async {
    _session = value;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
