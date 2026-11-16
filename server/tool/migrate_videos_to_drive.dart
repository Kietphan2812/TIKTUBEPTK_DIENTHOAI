import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:tiktube_server/config.dart';
import 'package:tiktube_server/google_drive_service.dart';

Future<void> main() async {
  print('================================================================');
  print('    TIKTUBE - CÔNG CỤ DI CHUYỂN VIDEO SANG GOOGLE DRIVE 400GB   ');
  print('================================================================');

  final config = ServerConfig.load();
  final pool = Pool.withEndpoints([
    Endpoint(
      host: Uri.parse(config.databaseUrl).host,
      port: Uri.parse(config.databaseUrl).port == 0 ? 5432 : Uri.parse(config.databaseUrl).port,
      database: Uri.parse(config.databaseUrl).pathSegments.first,
      username: Uri.parse(config.databaseUrl).userInfo.split(':').first,
      password: Uri.parse(config.databaseUrl).userInfo.split(':').last,
    ),
  ], settings: const PoolSettings(sslMode: SslMode.require));

  final driveService = GoogleDriveService(
    folderId: config.googleDriveFolderId,
    clientId: config.googleOAuthClientId,
    clientSecret: config.googleOAuthClientSecret,
    refreshToken: config.googleOAuthRefreshToken,
  );

  print('Đang tìm kiếm các video đang lưu ở Cloudinary...');
  final rows = await pool.execute('''
    select video_id, tieu_de, duong_dan_video
    from video
    where duong_dan_video is not null
      and duong_dan_video like '%cloudinary%'
    order by video_id asc
  ''');

  if (rows.isEmpty) {
    print('Tất cả các video đã được lưu trên Google Drive 400GB rồi! Không cần chuyển.');
    await pool.close();
    return;
  }

  print('Tìm thấy ${rows.length} video cần chuyển sang Google Drive 400GB:');
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    print('  ${i + 1}. [ID: ${row[0]}] ${row[1]}');
  }

  print('\n--- BẮT ĐẦU QUÁ TRÌNH DI CHUYỂN TỰ ĐỘNG ---');
  int successCount = 0;
  int failCount = 0;

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final int videoId = row[0] as int;
    final String title = row[1]?.toString() ?? 'video';
    final String oldUrl = row[2]?.toString() ?? '';

    print('\n[${i + 1}/${rows.length}] Đang xử lý: "$title" (ID: $videoId)...');
    print('    Tải từ Cloudinary: $oldUrl');

    try {
      final response = await http.get(Uri.parse(oldUrl));
      if (response.statusCode != 200) {
        print('    LỖI: Không tải được video (HTTP ${response.statusCode})');
        failCount++;
        continue;
      }

      final bytes = response.bodyBytes;
      print('    Đã tải về (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB). Đang đẩy lên Google Drive 400GB...');

      final safeName = title.replaceAll(RegExp(r'[^\w\s\u00C0-\u1EF9_-]'), '').replaceAll(' ', '_');
      final filename = 'tiktube_${videoId}_$safeName.mp4';

      final upload = await driveService.uploadVideo(
        bytes: bytes,
        filename: filename,
      );

      print('    -> Đẩy lên Google Drive thành công! File ID: ${upload.fileId}');
      print('    -> Link phát mới: ${upload.videoUrl}');

      // Cập nhật lại Neon DB
      await pool.execute(
        Sql.named('update video set duong_dan_video = @newUrl where video_id = @id'),
        parameters: {'newUrl': upload.videoUrl, 'id': videoId},
      );
      await pool.execute(
        Sql.named('update lich_su_dang_video set video_url = @newUrl where video_id = @id'),
        parameters: {'newUrl': upload.videoUrl, 'id': videoId},
      );

      print('    -> Đã cập nhật vào cơ sở dữ liệu Neon thành công!');
      successCount++;
    } catch (e) {
      print('    LỖI khi chuyển video: $e');
      failCount++;
    }
  }

  await pool.close();
  print('\n================================================================');
  print('>>> DI CHUYỂN HOÀN TẤT! <<<');
  print('Thành công: $successCount video');
  print('Thất bại: $failCount video');
  print('Tất cả các video đã xuất hiện trong thư mục TIKTUBE_VIDEOS trên Google Drive của bạn!');
  print('================================================================');
}
