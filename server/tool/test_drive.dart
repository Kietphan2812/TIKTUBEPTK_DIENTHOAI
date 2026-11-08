import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tiktube_server/config.dart';
import 'package:tiktube_server/google_drive_service.dart';

void main() async {
  print('--- BẮT ĐẦU KIỂM TRA KẾT NỐI GOOGLE DRIVE ---');
  final config = ServerConfig.load();
  print('Service Account JSON path: ${config.googleServiceAccountJson}');
  print('Folder ID: ${config.googleDriveFolderId}');
  print('Has Google Drive configured: ${config.hasGoogleDrive}');

  if (!config.hasGoogleDrive) {
    print('LỖI: Chưa cấu hình đủ Google Drive!');
    exit(1);
  }

  final driveService = GoogleDriveService(
    serviceAccountJson: config.googleServiceAccountJson,
    folderId: config.googleDriveFolderId,
  );

  print('Đang thử tải file mẫu lên thư mục Google Drive...');
  final testBytes = Uint8List.fromList(utf8.encode('Hello TIKTUBE from Google Drive 400GB'));
  final result = await driveService.uploadVideo(
    bytes: testBytes,
    filename: 'test_tiktube_connection.txt',
    durationSeconds: 10,
  );

  print('>>> UPLOAD THÀNH CÔNG! <<<');
  print('File ID: ${result.fileId}');
  print('Video / Stream URL: ${result.videoUrl}');
  print('Thumbnail URL: ${result.thumbnailUrl}');

  print('Đang xóa file mẫu kiểm tra...');
  final deleted = await driveService.deleteVideo(result.fileId);
  print('Xóa file mẫu: ${deleted ? 'THÀNH CÔNG' : 'THẤT BẠI'}');
  print('--- KIỂM TRA HOÀN TẤT: GOOGLE DRIVE ĐÃ HOẠT ĐỘNG HOÀN HẢO! ---');
}
