import 'dart:typed_data';

import '../models/app_notification.dart';
import '../models/auth_session.dart';
import '../models/channel.dart';
import '../models/comment.dart';
import '../models/creator_stats.dart';
import '../models/profile.dart';
import '../models/recommended_feed.dart';
import '../models/video.dart';
import '../models/watch_history_item.dart';

/// Hợp đồng API mà tầng UI sử dụng.
///
/// Có thể thay bằng bản giả lập trong test, hoặc `ApiClient` thật.
abstract interface class TikTubeApi {
  Future<List<Video>> fetchVideos();

  /// Feed cá nhân hóa từ lịch sử xem, like, bình luận, danh mục/hashtag và
  /// kênh đã đăng ký. Người chưa có lịch sử sẽ nhận tín hiệu xu hướng.
  Future<RecommendedFeed> fetchForYouFeed({
    int limit = 24,
    int days = 30,
    String? category,
  });

  /// Video được xếp hạng bởi hệ thống xu hướng từ dữ liệu Neon.
  Future<List<Video>> fetchTrendingVideos({
    int limit = 12,
    int days = 7,
    String? category,
  });

  /// Thẻ tag gợi ý theo đúng danh mục đang chọn trong SQL.
  Future<List<String>> fetchTags(String category);

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

  /// Lưu hoặc bỏ lưu video. Trả về tổng số lượt lưu.
  Future<int> setSaved(String videoId, {required bool saved});

  Future<void> registerView(String videoId);

  /// Ghi thời lượng đã xem để cải thiện gợi ý và mức độ hoàn thành video.
  Future<void> recordWatchProgress(
    String videoId, {
    required int watchedSeconds,
    required int durationSeconds,
  });

  // ---------------------------------------------------------------------------
  // Video / Cloudinary
  // ---------------------------------------------------------------------------

  /// Tải video lên Cloudinary qua server, sau đó lưu metadata vào Neon.
  ///
  /// [onProgress] nhận tiến độ 0..1 của phần dữ liệu đã gửi lên server.
  Future<Video> uploadVideo({
    required String title,
    required String description,
    required String category,
    required List<String> tags,
    required bool kidsOnly,
    required Uint8List bytes,
    required String filename,
    void Function(double progress)? onProgress,
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

  /// Video mới nhất từ các kênh người dùng đang đăng ký.
  Future<List<Video>> fetchSubscriptionFeed({int limit = 30});

  /// Video mới từ những kênh người dùng đã thích/bình luận/xem.
  Future<List<Video>> fetchFriendsFeed({int limit = 30});

  /// Những video người dùng đã lưu.
  Future<List<Video>> fetchSavedVideos({int limit = 50});

  /// Trả về số người đăng ký mới của kênh.
  Future<int> setSubscription(String channelId, {required bool subscribed});

  // ---------------------------------------------------------------------------
  // Xác thực
  // ---------------------------------------------------------------------------

  /// Gắn bearer token vào mọi request tiếp theo. Truyền null để xoá token.
  void setAuthToken(String? token);

  Future<AuthSession> login({required String login, required String password});

  Future<AuthSession> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
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
    String? avatarUrl,
  });

  // ---------------------------------------------------------------------------
  // Thông báo (dùng chung dữ liệu với web)
  // ---------------------------------------------------------------------------

  /// Thông báo mới nhất của tài khoản đang đăng nhập.
  Future<List<AppNotification>> fetchNotifications();

  /// Đánh dấu tất cả thông báo là đã đọc.
  Future<void> markNotificationsRead();

  /// Đánh dấu một thông báo là đã đọc.
  Future<void> markNotificationRead(String notificationId);
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
