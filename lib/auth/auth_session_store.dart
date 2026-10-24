import 'auth_session_store_base.dart';
import 'auth_session_store_stub.dart'
    if (dart.library.io) 'auth_session_store_native.dart'
    if (dart.library.js_interop) 'auth_session_store_web.dart'
    as platform;

export 'auth_session_store_base.dart';

/// Web dùng localStorage; Android/iOS/desktop dùng SharedPreferences.
AuthSessionStore createAuthSessionStore() =>
    platform.createPlatformAuthSessionStore();
