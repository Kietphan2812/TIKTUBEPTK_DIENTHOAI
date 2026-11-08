import 'dart:convert';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';

Future<void> main(List<String> args) async {
  print('======================================================');
  print('    TIKTUBE - CÔNG CỤ XÁC THỰC GOOGLE DRIVE 400GB    ');
  print('======================================================');

  String clientId = '';
  String clientSecret = '';

  // 1. Kiểm tra nếu có file JSON tải về trong thư mục Downloads hoặc server/
  final downloadsDir = Directory('${Platform.environment['USERPROFILE']}\\Downloads');
  File? clientSecretFile;

  if (downloadsDir.existsSync()) {
    final files = downloadsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('client_secret') && f.path.endsWith('.json'))
        .toList();
    if (files.isNotEmpty) {
      // Sắp xếp lấy file mới nhất
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      clientSecretFile = files.first;
      print('Tìm thấy file xác thực tại Downloads: ${clientSecretFile.path}');
    }
  }

  if (clientSecretFile == null && File('client_secret.json').existsSync()) {
    clientSecretFile = File('client_secret.json');
    print('Tìm thấy file xác thực tại thư mục hiện tại: ${clientSecretFile.path}');
  }

  if (clientSecretFile == null && File('server/client_secret.json').existsSync()) {
    clientSecretFile = File('server/client_secret.json');
    print('Tìm thấy file xác thực tại server: ${clientSecretFile.path}');
  }

  if (clientSecretFile != null && clientSecretFile.existsSync()) {
    try {
      final json = jsonDecode(await clientSecretFile.readAsString()) as Map<String, dynamic>;
      final installed = (json['installed'] ?? json['web']) as Map<String, dynamic>?;
      if (installed != null) {
        clientId = installed['client_id'] as String? ?? '';
        clientSecret = installed['client_secret'] as String? ?? '';
      }
    } catch (e) {
      print('Không đọc được file json: $e');
    }
  }

  // 2. Nếu chưa có, thử đọc từ tham số dòng lệnh hoặc .env
  if (clientId.isEmpty || clientSecret.isEmpty) {
    if (args.length >= 2) {
      clientId = args[0];
      clientSecret = args[1];
    } else {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        for (final line in envFile.readAsLinesSync()) {
          if (line.startsWith('GOOGLE_OAUTH_CLIENT_ID=')) {
            clientId = line.substring('GOOGLE_OAUTH_CLIENT_ID='.length).trim();
          }
          if (line.startsWith('GOOGLE_OAUTH_CLIENT_SECRET=')) {
            clientSecret = line.substring('GOOGLE_OAUTH_CLIENT_SECRET='.length).trim();
          }
        }
      }
    }
  }

  if (clientId.isEmpty || clientSecret.isEmpty) {
    print('\nCHƯA TÌM THẤY CLIENT ID VÀ CLIENT SECRET!');
    print('Vui lòng làm theo hướng dẫn để tải file client_secret_*.json');
    print('hoặc chạy: dart run tool/auth_drive.dart <CLIENT_ID> <CLIENT_SECRET>\n');
    exit(1);
  }

  print('\nKhởi động quá trình xác thực với Client ID: $clientId');
  final id = ClientId(clientId, clientSecret);
  const scopes = <String>[
    drive.DriveApi.driveScope,
  ];

  print('\nĐang tạo liên kết xác thực Google...');
  final authClient = await clientViaUserConsent(
    id,
    scopes,
    (url) {
      print('\n>>> VUI LÒNG MỞ ĐƯỜNG LINK DƯỚI ĐÂY BẰNG TRÌNH DUYỆT CỦA BẠN: <<<');
      print(url);
      print('\n(Hệ thống đang thử tự động mở trình duyệt cho bạn...)');
      try {
        Process.run('cmd', ['/c', 'start', url]);
      } catch (_) {}
    },
  );

  final credentials = authClient.credentials;
  final refreshToken = credentials.refreshToken;

  if (refreshToken == null || refreshToken.isEmpty) {
    print('CẢNH BÁO: Google không trả về refreshToken. Có thể cần cấp quyền lại.');
  } else {
    print('\n>>> XÁC THỰC THÀNH CÔNG RỰC RỠ! <<<');
    print('Refresh Token: $refreshToken');

    // Lưu vào server/.env
    final envFile = File('.env');
    var content = envFile.existsSync() ? await envFile.readAsString() : '';

    void updateOrAdd(String key, String value) {
      final pattern = RegExp('^$key=.*', multiLine: true);
      if (pattern.hasMatch(content)) {
        content = content.replaceAll(pattern, '$key=$value');
      } else {
        content += '\n$key=$value';
      }
    }

    updateOrAdd('GOOGLE_OAUTH_CLIENT_ID', clientId);
    updateOrAdd('GOOGLE_OAUTH_CLIENT_SECRET', clientSecret);
    updateOrAdd('GOOGLE_OAUTH_REFRESH_TOKEN', refreshToken);

    await envFile.writeAsString('${content.trim()}\n');
    print('Đã tự động lưu cấu hình vào server/.env!');

    // Thử nghiệm tạo file trong thư mục
    const folderId = '19KOpd7VOawrH2J_E8zbNkJagHloqFPRI';
    print('\nĐang kiểm tra tải file mẫu lên thư mục 400GB ($folderId)...');
    try {
      final driveApi = drive.DriveApi(authClient);
      final testFile = drive.File()
        ..name = 'tiktube_welcome_test.txt'
        ..parents = [folderId]
        ..description = 'TIKTUBE 400GB Storage Test';

      final testMedia = drive.Media(
        Stream.value(utf8.encode('Chao mung TIKTUBE den voi bo nho Google Drive 400GB!')),
        52,
        contentType: 'text/plain',
      );

      final uploaded = await driveApi.files.create(
        testFile,
        uploadMedia: testMedia,
        $fields: 'id, name, webViewLink',
      );

      print('>>> UPLOAD THÀNH CÔNG VÀO THƯ MỤC 400GB! <<<');
      print('File ID: ${uploaded.id}');
      print('Tên file: ${uploaded.name}');
      print('Link xem: ${uploaded.webViewLink}');

      // Xoá file test
      if (uploaded.id != null) {
        await driveApi.files.delete(uploaded.id!);
        print('Đã dọn dẹp file test thành công.');
      }
      print('\n=== CHÚC MỪNG! GOOGLE DRIVE 400GB ĐÃ HOẠT ĐỘNG HOÀN TOÀN TRÊN TIKTUBE! ===');
    } catch (e) {
      print('Lỗi khi tải file: $e');
    }
  }

  authClient.close();
}
