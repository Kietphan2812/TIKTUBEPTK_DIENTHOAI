import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:tiktube_server/config.dart';
import 'package:tiktube_server/google_drive_service.dart';

void main() async {
  print('Đang lấy một video từ Cloudinary để đẩy vào Google Drive 400GB...');
  final config = ServerConfig.load();
  final service = GoogleDriveService(
    folderId: config.googleDriveFolderId,
    clientId: config.googleOAuthClientId,
    clientSecret: config.googleOAuthClientSecret,
    refreshToken: config.googleOAuthRefreshToken,
  );

  // Lấy video mẫu chuẩn từ W3C hoặc Cloudinary
  final sampleVideoUrl = 'https://www.w3schools.com/html/mov_bbb.mp4';
  print('Đang tải video từ: $sampleVideoUrl');
  final response = await http.get(Uri.parse(sampleVideoUrl));

  if (response.statusCode != 200) {
    print('Không tải được video mẫu: HTTP ${response.statusCode}');
    exit(1);
  }

  print('Đã tải video (${response.bodyBytes.length} bytes). Đang đẩy vào Google Drive TIKTUBE_VIDEOS...');
  final upload = await service.uploadVideo(
    bytes: response.bodyBytes,
    filename: 'TIKTUBE_Video_Mau_400GB.mp4',
    durationSeconds: 10,
  );

  print('==================================================');
  print('>>> ĐÃ TẢI LÊN THÀNH CÔNG VÀO GOOGLE DRIVE 400GB! <<<');
  print('Tên file: TIKTUBE_Video_Mau_400GB.mp4');
  print('File ID: ${upload.fileId}');
  print('Link xem trực tiếp: ${upload.videoUrl}');
  print('==================================================');
}
