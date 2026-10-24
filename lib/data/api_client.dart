import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/app_notification.dart';
import '../models/auth_session.dart';
import '../models/channel.dart';
import '../models/comment.dart';
import '../models/creator_stats.dart';
import '../models/profile.dart';
import '../models/recommended_feed.dart';
import '../models/video.dart';
import '../models/watch_history_item.dart';
import 'tiktube_api.dart';

/// Gọi REST API (server Dart + Neon Postgres + Cloudinary).
///
/// Đổi địa chỉ API khi chạy:
/// `flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8787`
class ApiClient implements TikTubeApi {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = _normalize(
        baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://127.0.0.1:8787',
            ),
      );

  // Render Free có thể mất ~50 giây để đánh thức instance sau thời gian idle.
  static const Duration _timeout = Duration(seconds: 90);
  static const Duration _uploadTimeout = Duration(minutes: 5);

  final http.Client _client;
  final String baseUrl;
  String? _token;

  @override
  void setAuthToken(String? token) {
    _token = token;
  }

  Map<String, String> get _authHeaders {
    final token = _token;
    if (token == null || token.isEmpty) return const <String, String>{};
    return <String, String>{'authorization': 'Bearer $token'};
  }

  static String _normalize(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  @override
  Future<List<Video>> fetchVideos() async {
    final data = await _request('GET', _uri('/api/videos', {'limit': '100'}));
    return _videoList(data);
  }

  @override
  Future<RecommendedFeed> fetchForYouFeed({
    int limit = 24,
    int days = 30,
    String? category,
  }) async {
    final String trimmedCategory = category?.trim() ?? '';
    final data = await _request(
      'GET',
      _uri('/api/feed/for-you', <String, String>{
        'limit': '$limit',
        'days': '$days',
        if (trimmedCategory.isNotEmpty && trimmedCategory != 'Tất cả')
          'category': trimmedCategory,
      }),
    );
    return RecommendedFeed.fromJson(data);
  }

  @override
  Future<List<Video>> fetchTrendingVideos({
    int limit = 12,
    int days = 7,
    String? category,
  }) async {
    final String trimmedCategory = category?.trim() ?? '';
    final data = await _request(
      'GET',
      _uri('/api/videos/trending', <String, String>{
        'limit': '$limit',
        'days': '$days',
        if (trimmedCategory.isNotEmpty && trimmedCategory != 'Tất cả')
          'category': trimmedCategory,
      }),
    );
    return _videoList(data);
  }

  @override
  Future<List<String>> fetchTags(String category) async {
    final data = await _request(
      'GET',
      _uri('/api/tags', <String, String>{
        'category': category.trim(),
        'limit': '60',
      }),
    );
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
    final tags = <String>[];
    final seen = <String>{};
    for (final item in items) {
      final String name = item
          .toString()
          .trim()
          .replaceFirst(RegExp(r'^#+'), '')
          .trim();
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      tags.add(name);
    }
    return tags;
  }

  @override
  Future<List<Comment>> fetchComments(String videoId) async {
    final data = await _request('GET', _uri('/api/videos/$videoId/comments'));
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
    return items
        .map((item) => Comment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Comment> addComment(
    String videoId, {
    required String author,
    required String content,
  }) async {
    final data = await _request(
      'POST',
      _uri('/api/videos/$videoId/comments'),
      body: <String, Object?>{'author': author, 'content': content},
    );
    return Comment.fromJson(data['comment'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteComment(String videoId, String commentId) async {
    await _request('DELETE', _uri('/api/videos/$videoId/comments/$commentId'));
  }

  @override
  Future<int> setLike(String videoId, {required bool liked}) async {
    final data = await _request(
      'POST',
      _uri('/api/videos/$videoId/like'),
      body: <String, Object?>{'liked': liked},
    );
    return (data['likeCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> registerView(String videoId) async {
    await _request(
      'POST',
      _uri('/api/videos/$videoId/view'),
      body: const <String, Object?>{},
    );
  }

  @override
  Future<void> recordWatchProgress(
    String videoId, {
    required int watchedSeconds,
    required int durationSeconds,
  }) async {
    await _request(
      'POST',
      _uri('/api/videos/$videoId/watch-progress'),
      body: <String, Object?>{
        'watchedSeconds': watchedSeconds,
        'durationSeconds': durationSeconds,
      },
    );
  }

  @override
  Future<Video> uploadVideo({
    required String title,
    required String description,
    required String category,
    required List<String> tags,
    required bool kidsOnly,
    required Uint8List bytes,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final uri = _uri('/api/videos/upload', <String, String>{
      'title': title,
      'description': description,
      'category': category,
      'tags': tags.join(','),
      'age': kidsOnly ? 'kids' : '18',
      'filename': filename,
    });

    // Dùng StreamedRequest thay vì bodyBytes để có thể báo tiến độ theo từng
    // khối dữ liệu gửi lên server. Server đọc body dạng octet-stream.
    final request = http.StreamedRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..headers['content-type'] = 'application/octet-stream'
      ..contentLength = bytes.length;

    final Future<http.StreamedResponse> responseFuture = _client
        .send(request)
        .timeout(_uploadTimeout);

    Object? writeError;
    try {
      onProgress?.call(0);
      const int chunkSize = 256 * 1024;
      for (var offset = 0; offset < bytes.length; offset += chunkSize) {
        final int end = offset + chunkSize < bytes.length
            ? offset + chunkSize
            : bytes.length;
        request.sink.add(bytes.sublist(offset, end));
        onProgress?.call(end / bytes.length);
        // Nhường event loop để client kịp đọc khối vừa ghi.
        await Future<void>.delayed(Duration.zero);
      }
      await request.sink.close();
    } catch (error) {
      writeError = error;
      try {
        await request.sink.close();
      } catch (_) {
        // Kết nối đã đóng; lỗi gốc sẽ được báo bên dưới.
      }
    }

    http.Response response;
    try {
      final streamed = await responseFuture;
      response = await http.Response.fromStream(streamed)
          .timeout(_uploadTimeout);
    } catch (error) {
      throw ApiException(
        'Không kết nối được API tại $baseUrl: ${writeError ?? error}',
      );
    }
    if (writeError != null) {
      throw ApiException('Không kết nối được API tại $baseUrl: $writeError');
    }

    final data = _decodeResponse(response);
    return Video.fromJson(data['video'] as Map<String, dynamic>);
  }

  @override
  Future<Video> updateVideo(
    String videoId, {
    required String title,
    required String description,
    required String category,
    required List<String> tags,
  }) async {
    final data = await _request(
      'PATCH',
      _uri('/api/videos/$videoId'),
      body: <String, Object?>{
        'title': title,
        'description': description,
        'category': category,
        'tags': tags,
      },
    );
    return Video.fromJson(data['video'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteVideo(String videoId) async {
    await _request('DELETE', _uri('/api/videos/$videoId'));
  }

  @override
  Future<List<Channel>> fetchChannels() async {
    final data = await _request('GET', _uri('/api/channels'));
    return _channelList(data);
  }

  @override
  Future<List<Channel>> fetchSubscriptions() async {
    final data = await _request('GET', _uri('/api/subscriptions'));
    return _channelList(data);
  }

  @override
  Future<List<Video>> fetchSubscriptionFeed({int limit = 30}) async {
    final data = await _request(
      'GET',
      _uri('/api/feed/subscriptions', <String, String>{'limit': '$limit'}),
    );
    return _videoList(data);
  }

  @override
  Future<int> setSubscription(
    String channelId, {
    required bool subscribed,
  }) async {
    final data = await _request(
      subscribed ? 'POST' : 'DELETE',
      _uri('/api/channels/$channelId/subscribe'),
    );
    return (data['subscriberCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<WatchHistoryItem>> fetchWatchHistory() async {
    final data = await _request('GET', _uri('/api/history'));
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
    return items
        .map((item) => WatchHistoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> clearWatchHistory() async {
    await _request('DELETE', _uri('/api/history'));
  }

  @override
  Future<void> removeWatchHistory(String videoId) async {
    await _request('DELETE', _uri('/api/history/$videoId'));
  }

  @override
  Future<List<Video>> fetchUploads() async {
    final data = await _request('GET', _uri('/api/uploads'));
    return _videoList(data);
  }

  @override
  Future<CreatorStats> fetchStats() async {
    final data = await _request('GET', _uri('/api/stats'));
    return CreatorStats.fromJson(data);
  }

  @override
  Future<Profile> fetchProfile() async {
    final data = await _request('GET', _uri('/api/me'));
    return Profile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  @override
  Future<Profile> updateProfile({
    required String name,
    required String email,
    int? age,
  }) async {
    final data = await _request(
      'PATCH',
      _uri('/api/me'),
      body: <String, Object?>{'name': name, 'email': email, 'age': age},
    );
    return Profile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // Xác thực
  // ---------------------------------------------------------------------------

  @override
  Future<AuthSession> login({
    required String login,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      _uri('/api/auth/login'),
      body: <String, Object?>{'login': login, 'password': password},
    );
    return AuthSession.fromJson(data);
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String username,
    required String email,
    required String password,
    int? age,
  }) async {
    final data = await _request(
      'POST',
      _uri('/api/auth/register'),
      body: <String, Object?>{
        'name': name,
        'username': username,
        'email': email,
        'password': password,
        'age': age,
      },
    );
    return AuthSession.fromJson(data);
  }

  @override
  Future<void> logout() async {
    try {
      if (_token != null && _token!.isNotEmpty) {
        await _request('POST', _uri('/api/auth/logout'));
      }
    } finally {
      _token = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Thông báo
  // ---------------------------------------------------------------------------

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final data = await _request('GET', _uri('/api/notifications'));
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
    return items
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markNotificationsRead() async {
    await _request(
      'POST',
      _uri('/api/notifications/read'),
      body: const <String, Object?>{},
    );
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _request(
      'POST',
      _uri('/api/notifications/$notificationId/read'),
      body: const <String, Object?>{},
    );
  }

  List<Video> _videoList(Map<String, dynamic> data) {
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
    return items
        .map((item) => Video.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<Channel> _channelList(Map<String, dynamic> data) {
    final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
    return items
        .map((item) => Channel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Uri uri, {
    Object? body,
  }) async {
    final Map<String, String> headers = <String, String>{..._authHeaders};
    http.Response response;
    try {
      switch (method) {
        case 'POST':
          headers['content-type'] = 'application/json; charset=utf-8';
          response = await _client
              .post(
                uri,
                headers: headers,
                body: jsonEncode(body ?? const <String, Object?>{}),
              )
              .timeout(_timeout);
          break;
        case 'PATCH':
          headers['content-type'] = 'application/json; charset=utf-8';
          response = await _client
              .patch(
                uri,
                headers: headers,
                body: jsonEncode(body ?? const <String, Object?>{}),
              )
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(_timeout);
          break;
        default:
          response = await _client.get(uri, headers: headers).timeout(_timeout);
      }
    } catch (error) {
      throw ApiException('Không kết nối được API tại $baseUrl: $error');
    }
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    Map<String, dynamic>? data;
    if (text.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // Body không phải JSON (ví dụ trang lỗi HTML).
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          data?['error'] as String? ?? 'HTTP ${response.statusCode}';
      throw ApiException(message, statusCode: response.statusCode);
    }
    if (data == null) {
      throw ApiException('API trả về dữ liệu không hợp lệ.');
    }
    return data;
  }
}
