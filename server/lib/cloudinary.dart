import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Lỗi từ Cloudinary (đã được dịch sang thông báo thân thiện).
class CloudinaryException implements Exception {
  CloudinaryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'CloudinaryException($statusCode): $message';
}

/// Kết quả upload video lên Cloudinary.
class CloudinaryUpload {
  const CloudinaryUpload({
    required this.publicId,
    required this.secureUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
  });

  final String publicId;
  final String secureUrl;
  final String thumbnailUrl;
  final int durationSeconds;

  factory CloudinaryUpload.fromJson(
    Map<String, dynamic> json, {
    required String cloudName,
    required String fallbackPublicId,
  }) {
    final publicId = (json['public_id'] ?? fallbackPublicId).toString();
    final secureUrl = (json['secure_url'] ?? '').toString();
    final duration = (json['duration'] as num?)?.round() ?? 0;
    return CloudinaryUpload(
      publicId: publicId,
      secureUrl: secureUrl,
      thumbnailUrl: thumbnailUrlFor(
        cloudName: cloudName,
        publicId: publicId,
      ),
      durationSeconds: duration,
    );
  }

  static String thumbnailUrlFor({
    required String cloudName,
    required String publicId,
  }) {
    return 'https://res.cloudinary.com/$cloudName/video/upload/'
        'so_2,w_640,h_360,c_fill/$publicId.jpg';
  }
}

/// Upload/xoá video bằng Upload API có chữ ký (signed upload).
///
/// API secret chỉ nằm ở server, không bao giờ gửi xuống Flutter.
class CloudinaryService {
  CloudinaryService({
    required this.cloudName,
    required this.apiKey,
    required this.apiSecret,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String cloudName;
  final String apiKey;
  final String apiSecret;
  final http.Client _client;

  bool get configured =>
      cloudName.isNotEmpty && apiKey.isNotEmpty && apiSecret.isNotEmpty;

  static const String folder = 'tiktube_videos';
  static const Duration _uploadTimeout = Duration(minutes: 5);

  Future<CloudinaryUpload> uploadVideo({
    required List<int> bytes,
    required String filename,
  }) async {
    final timestamp = _timestamp();
    final params = <String, String>{
      'folder': folder,
      'timestamp': timestamp,
    };
    final signature = _sign(params);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload'),
    )
      ..fields.addAll(<String, String>{
        ...params,
        'api_key': apiKey,
        'signature': signature,
      })
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(_uploadTimeout);
    } catch (error) {
      throw CloudinaryException('Không gửi được video lên Cloudinary: $error');
    }

    final body = await streamed.stream.bytesToString();
    final decoded = _decode(body);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw CloudinaryException(
        _errorMessage(decoded, 'Cloudinary từ chối upload.'),
        statusCode: streamed.statusCode,
      );
    }
    if (decoded['secure_url'] == null) {
      throw CloudinaryException('Cloudinary không trả về URL video.');
    }
    return CloudinaryUpload.fromJson(
      decoded,
      cloudName: cloudName,
      fallbackPublicId: '${decoded['public_id'] ?? ''}',
    );
  }

  Future<void> destroyVideo(String publicId) async {
    if (publicId.trim().isEmpty) return;
    final timestamp = _timestamp();
    final params = <String, String>{
      'public_id': publicId,
      'timestamp': timestamp,
    };
    final signature = _sign(params);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/destroy'),
    )..fields.addAll(<String, String>{
        ...params,
        'api_key': apiKey,
        'signature': signature,
      });

    try {
      final streamed = await _client.send(request).timeout(_uploadTimeout);
      final body = await streamed.stream.bytesToString();
      final decoded = _decode(body);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw CloudinaryException(
          _errorMessage(decoded, 'Không xoá được video trên Cloudinary.'),
          statusCode: streamed.statusCode,
        );
      }
    } catch (error) {
      throw CloudinaryException('Không xoá được video trên Cloudinary: $error');
    }
  }

  String _sign(Map<String, String> params) {
    final keys = params.keys.toList()..sort();
    final toSign = keys.map((key) => '$key=${params[key]}').join('&');
    return sha1.convert(utf8.encode('$toSign$apiSecret')).toString();
  }

  static String _timestamp() =>
      (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

  static Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Trả về thông báo chung bên dưới.
    }
    return <String, dynamic>{
      'error': <String, dynamic>{'message': body}
    };
  }

  static String _errorMessage(Map<String, dynamic> decoded, String fallback) {
    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
    if (error is String && error.trim().isNotEmpty) return error;
    return fallback;
  }
}
