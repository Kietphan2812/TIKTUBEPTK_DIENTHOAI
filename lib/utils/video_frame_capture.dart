import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import 'video_frame_capture_io.dart'
    if (dart.library.js_interop) 'video_frame_capture_web.dart' as impl;

/// Trích xuất ảnh khung hình video tại thời điểm hiện tại (phục vụ cắt ảnh bìa).
Future<Uint8List?> captureVideoFrame({
  PlatformFile? file,
  String? videoUrl,
  required Duration position,
  GlobalKey? repaintKey,
}) {
  return impl.captureVideoFrame(
    file: file,
    videoUrl: videoUrl,
    position: position,
    repaintKey: repaintKey,
  );
}
