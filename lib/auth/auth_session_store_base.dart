/// Nơi lưu phiên đăng nhập (token + hồ sơ) giữa các lần mở app.
abstract interface class AuthSessionStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> clear();
}
