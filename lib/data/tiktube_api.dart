import 'dart:typed_data';

import '../models/auth_session.dart';
import '../models/channel.dart';
import '../models/comment.dart';
import '../models/creator_stats.dart';
import '../models/profile.dart';
import '../models/video.dart';
import '../models/watch_history_item.dart';

/// Hợp đồng API mà tầng UI sử dụng.
///
/// Có thể thay bằng bản giả lập trong test, hoặc `ApiClient` thật.
abstract interface class TikTubeApi {
  Future<List<Video>> fetchVideos();

  Future<List<Comment>> fetchComments(String videoId);

  Future<Comment> addComment(
    String videoId, {
    required String author,
    required String content,
  });

  /// Xoá bình luận của chính người dùng hiện tại.
  Future<void> deleteComment(String videoId, String commentId);

  /// Trả về tổng số lượt thích mới của video.
  Future<int> setLike(String videoId, {required bool liked});

  Future<void> registerView(String videoId);

  // ---------------------------------------------------------------------------
  // Video / Cloudinary
  // ---------------------------------------------------------------------------

  /// Tải video lên Cloudinary qua server, sau đó lưu metadata vào Neon.
  Future<Video> uploadVideo({
    required String title,
    required String description,
    required String category,
    required List<String> tags,
    required bool kidsOnly,
    required Uint8List bytes,
    required String filename,
  });

  Future<Video> updateVideo(
    String videoId, {
    required String title,
    required String description,
    required String category,
    required List<String> tags,
  });

  Future<void> deleteVideo(String videoId);

  // ---------------------------------------------------------------------------
  // Kênh / đăng ký
  // ---------------------------------------------------------------------------

  Future<List<Channel>> fetchChannels();

  Future<List<Channel>> fetchSubscriptions();

  /// Trả về số người đăng ký mới của kênh.
  Future<int> setSubscription(
    String channelId, {
    required bool subscribed,
  });

  // ---------------------------------------------------------------------------
  // Xác thực
  // ---------------------------------------------------------------------------

  /// Gắn bearer token vào mọi request tiếp theo. Truyền null để xoá token.
  void setAuthToken(String? token);

  Future<AuthSession> login({
    required String login,
    required String password,
  });

  Future<AuthSession> register({
    required String name,
    required String username,
    required String email,
    required String password,
    int? age,
  });

  Future<void> logout();

  // ---------------------------------------------------------------------------
  // Lịch sử / thống kê / tài khoản
  // ---------------------------------------------------------------------------

  Future<List<WatchHistoryItem>> fetchWatchHistory();

  Future<void> clearWatchHistory();

  Future<void> removeWatchHistory(String videoId);

  Future<List<Video>> fetchUploads();

  Future<CreatorStats> fetchStats();

  Future<Profile> fetchProfile();

  Future<Profile> updateProfile({
    required String name,
    required String email,
    int? age,
  });
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
