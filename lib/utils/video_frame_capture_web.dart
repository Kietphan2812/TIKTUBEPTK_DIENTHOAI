import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

Future<Uint8List?> captureVideoFrame({
  PlatformFile? file,
  String? videoUrl,
  required Duration position,
  GlobalKey? repaintKey,
}) async {
  try {
    final videoList = web.document.querySelectorAll('video');
    if (videoList.length == 0) return null;

    // Lấy thẻ video đang hiển thị trong DOM
    final video = videoList.item(0) as web.HTMLVideoElement?;
    if (video == null) return null;

    final int width = video.videoWidth > 0 ? video.videoWidth : 640;
    final int height = video.videoHeight > 0 ? video.videoHeight : 360;

    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = width;
    canvas.height = height;

    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) return null;

    ctx.drawImage(video, 0, 0, width.toDouble(), height.toDouble());

    final dataUrl = canvas.toDataURL('image/jpeg', 0.85.toJS);
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) return null;

    final base64Str = dataUrl.substring(commaIndex + 1);
    return base64Decode(base64Str);
  } catch (e) {
    return null;
  }
}
