import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _channel = MethodChannel('com.example.flutter_app_ptk/app_control');

Future<Uint8List?> captureVideoFrame({
  PlatformFile? file,
  String? videoUrl,
  required Duration position,
  GlobalKey? repaintKey,
}) async {
  // 1. Trên Android: dùng native MediaMetadataRetriever để lấy khung hình độ nét cao
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final dynamic result = await _channel.invokeMethod('getVideoFrame', <String, Object?>{
        if (file?.path != null && file!.path!.isNotEmpty) 'path': file.path,
        if (file?.uri != null) 'uri': file!.uri.toString(),
        if (videoUrl != null && videoUrl.isNotEmpty) 'url': videoUrl,
        'timeMs': position.inMilliseconds,
      });
      if (result is Uint8List && result.isNotEmpty) {
        return result;
      }
    } catch (e) {
      debugPrint('MediaMetadataRetriever error, fallback to RepaintBoundary: $e');
    }
  }

  // 2. Dự phòng: chụp từ RenderRepaintBoundary của widget preview
  if (repaintKey != null) {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          return byteData.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('RepaintBoundary capture error: $e');
    }
  }

  return null;
}
