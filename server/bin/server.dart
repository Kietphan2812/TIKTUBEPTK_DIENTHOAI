import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:tiktube_server/api.dart';
import 'package:tiktube_server/cloudinary.dart';
import 'package:tiktube_server/config.dart';
import 'package:tiktube_server/db.dart';

Future<void> main() async {
  final config = ServerConfig.load();

  stdout.writeln('Đang kết nối Neon Postgres...');
  final Db db;
  try {
    db = await Db.open(config.databaseUrl);
  } catch (error) {
    stderr.writeln('Kết nối database thất bại: $error');
    stderr.writeln(
      'Kiểm tra DATABASE_URL trong server/.env (dùng host trực tiếp, '
      'không có "-pooler", và sslmode=require).',
    );
    exit(1);
  }
  stdout.writeln('Đã kết nối database.');

  final CloudinaryService? cloudinary = config.hasCloudinary
      ? CloudinaryService(
          cloudName: config.cloudinaryCloudName,
          apiKey: config.cloudinaryApiKey,
          apiSecret: config.cloudinaryApiSecret,
        )
      : null;
  stdout.writeln(
    cloudinary == null
        ? 'Cloudinary: chưa cấu hình (tính năng tải video sẽ tắt).'
        : 'Cloudinary: đã cấu hình (${config.cloudinaryCloudName}).',
  );

  final server = await shelf_io.serve(
    createApi(db, cloudinary: cloudinary),
    InternetAddress.anyIPv4,
    config.port,
  );

  stdout.writeln('TIKTUBE API đang chạy: http://localhost:${server.port}');
  stdout.writeln('Health check: http://localhost:${server.port}/health');

  Future<void> shutdown(ProcessSignal signal) async {
    stdout.writeln('\nĐang tắt server...');
    await server.close(force: true);
    await db.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(shutdown);
  }
}
