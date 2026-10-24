import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Tạo trình phát cho tệp vừa chọn trên Android/iOS/desktop.
VideoPlayerController createPlatformVideoController(PlatformFile file) {
  final String? path = file.path;
  if (path != null && path.isNotEmpty) {
    return VideoPlayerController.file(File(path));
  }

  final Uri uri = file.uri;
  if (uri.scheme == 'content' &&
      defaultTargetPlatform == TargetPlatform.android) {
    return VideoPlayerController.contentUri(uri);
  }
  return VideoPlayerController.networkUrl(uri);
}
