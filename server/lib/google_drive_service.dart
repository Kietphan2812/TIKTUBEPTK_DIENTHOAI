import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleDriveUpload {
  const GoogleDriveUpload({
    required this.fileId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
  });

  final String fileId;
  final String videoUrl;
  final String thumbnailUrl;
  final int durationSeconds;
}

/// Dịch vụ lưu trữ video lên Google Drive (tài khoản dung lượng 400 GB+)
class GoogleDriveService {
  GoogleDriveService({
    this.serviceAccountJson = '',
    this.clientId = '',
    this.clientSecret = '',
    this.refreshToken = '',
    required this.folderId,
  });

  final String serviceAccountJson;
  final String clientId;
  final String clientSecret;
  final String refreshToken;
  final String folderId;

  bool get configured {
    final hasFolder = folderId.trim().isNotEmpty;
    final hasOAuth = clientId.trim().isNotEmpty &&
        clientSecret.trim().isNotEmpty &&
        refreshToken.trim().isNotEmpty;
    final hasServiceAccount = serviceAccountJson.trim().isNotEmpty;
    return hasFolder && (hasOAuth || hasServiceAccount);
  }

  AutoRefreshingAuthClient? _client;

  Future<drive.DriveApi> _getDriveApi() async {
    if (_client != null) {
      return drive.DriveApi(_client!);
    }

    // 1. Ưu tiên OAuth2 (sử dụng trực tiếp dung lượng 400 GB của tài khoản người dùng)
    if (clientId.trim().isNotEmpty &&
        clientSecret.trim().isNotEmpty &&
        refreshToken.trim().isNotEmpty) {
      final id = ClientId(clientId.trim(), clientSecret.trim());
      final credentials = AccessCredentials(
        AccessToken('Bearer', '', DateTime.now().toUtc()),
        refreshToken.trim(),
        <String>[drive.DriveApi.driveScope],
      );
      _client = autoRefreshingClient(id, credentials, http.Client());
      return drive.DriveApi(_client!);
    }

    // 2. Dự phòng: Service Account
    final Map<String, dynamic> credentials;
    final trimmed = serviceAccountJson.trim();
    if (trimmed.startsWith('{')) {
      credentials = jsonDecode(trimmed) as Map<String, dynamic>;
    } else {
      final file = File(trimmed);
      if (await file.exists()) {
        credentials =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } else {
        throw StateError(
            'Không tìm thấy cấu hình Service Account JSON hoặc OAuth credentials.');
      }
    }

    final accountCredentials = ServiceAccountCredentials.fromJson(credentials);
    _client = await clientViaServiceAccount(
      accountCredentials,
      <String>[
        drive.DriveApi.driveScope,
      ],
    );
    return drive.DriveApi(_client!);
  }

  /// Upload video trực tiếp lên Google Drive vào thư mục được chỉ định
  Future<GoogleDriveUpload> uploadVideo({
    required Uint8List bytes,
    required String filename,
    int durationSeconds = 0,
  }) async {
    final driveApi = await _getDriveApi();

    final driveFile = drive.File()
      ..name = filename.isNotEmpty
          ? filename
          : 'tiktube_${DateTime.now().millisecondsSinceEpoch}.mp4'
      ..parents = <String>[folderId]
      ..description = 'TIKTUBE Video Upload (Google Drive Storage)';

    final media = drive.Media(
      Stream<List<int>>.value(bytes),
      bytes.length,
      contentType: 'video/mp4',
    );

    final uploaded = await driveApi.files.create(
      driveFile,
      uploadMedia: media,
      $fields: 'id, name, webViewLink, webContentLink, thumbnailLink',
    );

    final fileId = uploaded.id;
    if (fileId == null || fileId.isEmpty) {
      throw StateError('Google Drive không trả về ID tệp.');
    }

    // Cấp quyền đọc công khai (anyone can view)
    try {
      await driveApi.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        fileId,
      );
    } catch (_) {}

    // Link stream trực tiếp cho trình phát video
    final videoUrl =
        'https://tiktube-api.onrender.com/api/drive/stream?id=$fileId';
    final thumbUrl = uploaded.thumbnailLink ??
        'https://res.cloudinary.com/qfgja134/video/upload/so_2,w_640,h_360,c_fill/$fileId.jpg';

    return GoogleDriveUpload(
      fileId: fileId,
      videoUrl: videoUrl,
      thumbnailUrl: thumbUrl,
      durationSeconds: durationSeconds,
    );
  }

  /// Xóa video khỏi Google Drive
  Future<bool> deleteVideo(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      await driveApi.files.delete(fileId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

