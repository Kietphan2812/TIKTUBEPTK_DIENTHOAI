/// Nơi lưu phiên đăng nhập (token + hồ sơ) giữa các lần mở app.
abstract interface class AuthSessionStore {
  String? read();

  void write(String value);

  void clear();
}
