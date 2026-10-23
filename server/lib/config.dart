import 'dart:io';

/// Cấu hình server: đọc từ biến môi trường, sau đó tới file `server/.env`.
class ServerConfig {
  const ServerConfig({
    required this.databaseUrl,
    required this.port,
    this.cloudinaryCloudName = '',
    this.cloudinaryApiKey = '',
    this.cloudinaryApiSecret = '',
  });

  final String databaseUrl;
  final int port;
  final String cloudinaryCloudName;
  final String cloudinaryApiKey;
  final String cloudinaryApiSecret;

  bool get hasCloudinary =>
      cloudinaryCloudName.isNotEmpty &&
      cloudinaryApiKey.isNotEmpty &&
      cloudinaryApiSecret.isNotEmpty;

  static ServerConfig load() {
    final fileValues = _readDotEnv();

    String read(String key) {
      final fromEnv = Platform.environment[key];
      if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
      return fileValues[key]?.trim() ?? '';
    }

    final databaseUrl = read('DATABASE_URL');
    if (databaseUrl.isEmpty) {
      stderr.writeln(
        'Thiếu DATABASE_URL. Tạo file server/.env (xem .env.example) '
        'hoặc đặt biến môi trường DATABASE_URL.',
      );
      exit(1);
    }

    final port = int.tryParse(read('PORT')) ?? 8787;
    return ServerConfig(
      databaseUrl: _sanitizeDatabaseUrl(databaseUrl),
      port: port,
      cloudinaryCloudName: read('CLOUDINARY_CLOUD_NAME'),
      cloudinaryApiKey: read('CLOUDINARY_API_KEY'),
      cloudinaryApiSecret: read('CLOUDINARY_API_SECRET'),
    );
  }

  /// Package `postgres` không hỗ trợ `channel_binding` (Neon thêm vào chuỗi
  /// kết nối mặc định). Bỏ tham số này để có thể dán chuỗi Neon nguyên bản.
  static String _sanitizeDatabaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasQuery) return url;
    if (!uri.queryParameters.containsKey('channel_binding')) return url;
    final params = Map<String, String>.from(uri.queryParameters)
      ..remove('channel_binding');
    return uri.replace(queryParameters: params).toString();
  }

  static Map<String, String> _readDotEnv() {
    final file = File('.env');
    if (!file.existsSync()) return const {};
    final values = <String, String>{};
    for (final rawLine in file.readAsLinesSync()) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      values[key] = value;
    }
    return values;
  }
}
