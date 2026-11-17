import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'web_downloader_stub.dart' if (dart.library.js_interop) 'web_downloader_web.dart';

class VideoDownloader {
  static const MethodChannel _channel = MethodChannel('com.example.flutter_app_ptk/app_control');

  static Future<void> downloadVideo({
    required String videoId,
    required String title,
    String? directUrl,
  }) async {
    final downloadUrl = 'https://tiktube-api.onrender.com/api/videos/$videoId/download';
    final safeTitle = title.trim().isEmpty ? 'video_$videoId' : title.trim();
    final filename = '${safeTitle.replaceAll(RegExp(r'[\/\\:*?"<>|]'), '_')}.mp4';

    if (kIsWeb) {
      triggerWebDownload(downloadUrl, filename);
    } else {
      try {
        await _channel.invokeMethod<bool>('openUrl', <String, Object?>{
          'url': downloadUrl,
        });
      } catch (_) {
        // Fallback: nếu gọi method channel không thành công
      }
    }
  }
}

