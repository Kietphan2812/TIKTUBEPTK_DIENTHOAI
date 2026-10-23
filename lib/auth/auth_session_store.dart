import 'auth_session_store_base.dart';
import 'auth_session_store_stub.dart'
    if (dart.library.js_interop) 'auth_session_store_web.dart'
    as platform;

export 'auth_session_store_base.dart';

/// Trên web dùng localStorage; nền tảng khác dùng bộ nhớ tạm.
AuthSessionStore createAuthSessionStore() =>
    platform.createPlatformAuthSessionStore();
