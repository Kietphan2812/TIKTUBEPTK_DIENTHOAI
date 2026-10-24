import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_app_ptk/app.dart';
import 'package:flutter_app_ptk/auth/auth_session_store_base.dart';
import 'package:flutter_app_ptk/data/sample_data.dart';
import 'package:flutter_app_ptk/data/tiktube_api.dart';
import 'package:flutter_app_ptk/models/app_notification.dart';
import 'package:flutter_app_ptk/models/auth_session.dart';
import 'package:flutter_app_ptk/models/channel.dart';
import 'package:flutter_app_ptk/models/comment.dart';
import 'package:flutter_app_ptk/models/creator_stats.dart';
import 'package:flutter_app_ptk/models/profile.dart';
import 'package:flutter_app_ptk/models/recommended_feed.dart';
import 'package:flutter_app_ptk/models/video.dart';
import 'package:flutter_app_ptk/models/watch_history_item.dart';
import 'package:flutter_app_ptk/widgets/video_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// API giả lập: luôn offline để test dùng dữ liệu mẫu, không gọi mạng.
class _OfflineApi implements TikTubeApi {
  @override
  Future<List<Video>> fetchVideos() async => kLatestVideos;

  @override
  Future<RecommendedFeed> fetchForYouFeed({
    int limit = 24,
    int days = 30,
    String? category,
  }) async => RecommendedFeed(
    videos: kLatestVideos.take(limit).toList(),
    personalized: true,
    historySignals: 3,
    windowDays: days,
    forDate: '2026-10-24',
    algorithm: 'test_for_you',
    reason: 'history',
  );

  @override
  Future<List<Video>> fetchTrendingVideos({
    int limit = 12,
    int days = 7,
    String? category,
  }) async => kTrendingVideos;

  @override
  Future<List<String>> fetchTags(String category) async {
    switch (category) {
      case 'Giáo dục & kiến thức':
        return const <String>['giaoduc', 'hoctap', 'learning'];
      case 'Gaming':
        return const <String>['gaming', 'gameplay', 'esports'];
      case 'Âm nhạc & sáng tạo':
        return const <String>['remix', 'music', 'cover'];
      default:
        return const <String>['tiktok'];
    }
  }

  @override
  Future<List<Comment>> fetchComments(String videoId) async => kSampleComments;

  @override
  Future<Comment> addComment(
    String videoId, {
    required String author,
    required String content,
  }) async =>
      Comment(author: author, content: content, date: 'Hôm nay', own: true);

  @override
  Future<void> deleteComment(String videoId, String commentId) async {}

  @override
  Future<int> setLike(String videoId, {required bool liked}) async =>
      liked ? 2 : 1;

  @override
  Future<void> registerView(String videoId) async {}

  @override
  Future<void> recordWatchProgress(
    String videoId, {
    required int watchedSeconds,
    required int durationSeconds,
  }) async {}

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
  }) async => throw Exception('offline');

  @override
  Future<Video> updateVideo(
    String videoId, {
    required String title,
    required String description,
    required String category,
    required List<String> tags,
  }) async => throw Exception('offline');

  @override
  Future<void> deleteVideo(String videoId) async => throw Exception('offline');

  @override
  Future<List<Channel>> fetchChannels() async => throw Exception('offline');

  @override
  Future<List<Channel>> fetchSubscriptions() async => kSubscribedChannels;

  @override
  Future<List<Video>> fetchSubscriptionFeed({int limit = 30}) async =>
      kLatestVideos.take(4).toList();

  @override
  Future<int> setSubscription(
    String channelId, {
    required bool subscribed,
  }) async => throw Exception('offline');

  @override
  Future<List<WatchHistoryItem>> fetchWatchHistory() async =>
      throw Exception('offline');

  @override
  Future<void> clearWatchHistory() async => throw Exception('offline');

  @override
  Future<void> removeWatchHistory(String videoId) async =>
      throw Exception('offline');

  @override
  Future<List<Video>> fetchUploads() async => throw Exception('offline');

  @override
  Future<CreatorStats> fetchStats() async => throw Exception('offline');

  @override
  Future<Profile> fetchProfile() async => const Profile(
    userKey: 'kiepthan4',
    name: 'kiepthan4',
    email: 'kiepthan4444@gmail.com',
    age: 18,
  );

  @override
  Future<Profile> updateProfile({
    required String name,
    required String email,
    int? age,
  }) async => Profile(userKey: 'kiepthan4', name: name, email: email, age: age);

  @override
  void setAuthToken(String? token) {}

  @override
  Future<AuthSession> login({
    required String login,
    required String password,
  }) async => const AuthSession(
    token: 'test-token',
    profile: Profile(
      userKey: 'kiepthan4',
      name: 'kiepthan4',
      email: 'kiepthan4444@gmail.com',
      age: 18,
    ),
  );

  @override
  Future<AuthSession> register({
    required String name,
    required String username,
    required String email,
    required String password,
    int? age,
  }) async => AuthSession(
    token: 'test-token',
    profile: Profile(userKey: username, name: name, email: email, age: age),
  );

  @override
  Future<void> logout() async {}

  @override
  Future<List<AppNotification>> fetchNotifications() async =>
      const <AppNotification>[];

  @override
  Future<void> markNotificationsRead() async {}

  @override
  Future<void> markNotificationRead(String notificationId) async {}
}

class _BrokenApi extends _OfflineApi {
  @override
  Future<List<Video>> fetchVideos() async => throw Exception('offline');

  @override
  Future<RecommendedFeed> fetchForYouFeed({
    int limit = 24,
    int days = 30,
    String? category,
  }) async => throw Exception('offline');

  @override
  Future<List<Video>> fetchTrendingVideos({
    int limit = 12,
    int days = 7,
    String? category,
  }) async => throw Exception('offline');
}

class _PriorityApi extends _OfflineApi {
  @override
  Future<RecommendedFeed> fetchForYouFeed({
    int limit = 24,
    int days = 30,
    String? category,
  }) async => RecommendedFeed(
    videos: <Video>[
      kLatestVideos.first.copyWith(
        subscribed: true,
        recommendationScore: 999,
        recommendationReason: 'subscription',
      ),
      ...kLatestVideos.skip(1).take(3),
    ],
    personalized: true,
    historySignals: 8,
    windowDays: days,
    forDate: '2026-10-24',
    algorithm: 'test_for_you',
    reason: 'history',
  );
}

class _BadLoginApi extends _OfflineApi {
  @override
  Future<AuthSession> login({
    required String login,
    required String password,
  }) async => throw ApiException(
    'Tên đăng nhập hoặc mật khẩu không đúng.',
    statusCode: 401,
  );
}

class _MemoryAuthStore implements AuthSessionStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;

  @override
  Future<void> clear() async => _value = null;
}

class _StatsApi extends _OfflineApi {
  @override
  Future<CreatorStats> fetchStats() async {
    final DateTime today = DateTime.now();
    return CreatorStats(
      videos: 33,
      views: 9876543,
      likes: 4321,
      comments: 22,
      daily: <DailyViews>[
        DailyViews(date: today.subtract(const Duration(days: 2)), views: 2),
        DailyViews(date: today.subtract(const Duration(days: 1)), views: 8),
        DailyViews(date: today, views: 4),
      ],
      topVideos: kLatestVideos.take(2).toList(),
    );
  }
}

class _MobileDataApi extends _OfflineApi {
  @override
  Future<List<Video>> fetchUploads() async => kLatestVideos.take(3).toList();
  @override
  Future<List<WatchHistoryItem>> fetchWatchHistory() async =>
      <WatchHistoryItem>[
        WatchHistoryItem(
          video: kLatestVideos[0],
          watchedAt: DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
        ),
        WatchHistoryItem(
          video: kLatestVideos[1],
          watchedAt: DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        ),
      ];

  @override
  Future<List<Channel>> fetchSubscriptions() async => kSubscribedChannels;

  @override
  Future<CreatorStats> fetchStats() async {
    final DateTime today = DateTime.now();
    return CreatorStats(
      videos: 33,
      views: 9876543,
      likes: 4321,
      comments: 22,
      daily: <DailyViews>[
        for (int index = 6; index >= 0; index--)
          DailyViews(
            date: today.subtract(Duration(days: index)),
            views: 10 + index * 7,
          ),
      ],
      topVideos: kLatestVideos.take(3).toList(),
    );
  }
}

class _TrendingApi extends _OfflineApi {
  @override
  Future<List<Video>> fetchTrendingVideos({
    int limit = 12,
    int days = 7,
    String? category,
  }) async {
    final List<Video> videos = kTrendingVideos.take(limit).toList();
    return <Video>[
      for (int index = 0; index < videos.length; index++)
        videos[index].copyWith(
          trendScore: 1200 - index * 180,
          recentViews: 5 - index,
        ),
    ];
  }

  @override
  Future<List<Video>> fetchSubscriptionFeed({int limit = 30}) async =>
      kLatestVideos.take(3).toList();
}

class _NotificationApi extends _OfflineApi {
  @override
  Future<List<AppNotification>> fetchNotifications() async => <AppNotification>[
    AppNotification(
      id: '1',
      content: 'PTK đã thích video của bạn: Nhạc Mỹ Nhân',
      link: 'video.html?id=2',
      seen: false,
      createdAt: DateTime.now()
          .subtract(const Duration(minutes: 2))
          .toIso8601String(),
    ),
  ];

  @override
  Future<void> markNotificationsRead() async {}

  @override
  Future<void> markNotificationRead(String notificationId) async {}
}

void main() {
  testWidgets('Trang chủ TIKTUBE hiển thị các mục chính', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xin chào, kiepthan4'), findsNothing);
    expect(find.text('Video xu hướng'), findsOneWidget);
    expect(find.text('Dành cho bạn'), findsOneWidget);
    expect(find.text('MỚI NHẤT'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
  });

  testWidgets('Dành cho bạn ưu tiên video từ kênh đã đăng ký', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _PriorityApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dành cho bạn'), findsOneWidget);
    expect(find.textContaining('Kênh đã đăng ký được ưu tiên'), findsOneWidget);
    expect(find.text('Đã đăng ký'), findsOneWidget);

    await tester.tap(find.text('MỚI NHẤT'));
    await tester.pumpAndSettle();
    expect(find.text('Video mới'), findsOneWidget);
    expect(find.text('Đã đăng ký'), findsNothing);
  });

  testWidgets('Trang chủ hiển thị giao diện điện thoại không bị tràn', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Dành cho bạn'), findsNWidgets(2));
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Đăng'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
  });

  testWidgets('Các trang con hiển thị gọn trên điện thoại', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _MobileDataApi(), authRequired: false),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào!'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Tài khoản')).dy,
      greaterThanOrEqualTo(24),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Đã đăng'), findsOneWidget);
    expect(find.text('Video đã đăng'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Đã xem'));
    await tester.pumpAndSettle();
    expect(find.text('Video đã xem'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Thống kê'));
    await tester.pumpAndSettle();
    expect(find.text('Thống Kê Video'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Video mới từ kênh đã đăng ký'), findsOneWidget);
    expect(find.text('Video mới'), findsOneWidget);
    expect(find.text('Đã đăng ký'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Đã đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Kênh bạn đã đăng ký'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng'));
    await tester.pumpAndSettle();
    expect(find.text('Tải video'), findsOneWidget);
    expect(find.text('Chọn video để tải lên'), findsOneWidget);
    expect(find.text('Xem trước video'), findsOneWidget);
    expect(find.text('Thông tin video'), findsOneWidget);
    expect(find.text('Thẻ tag'), findsOneWidget);
    expect(find.text('#remix'), findsOneWidget);
    expect(find.text('#giaoduc'), findsNothing);
    expect(find.text('Cài đặt video'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Đăng video'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Âm nhạc & sáng tạo'));
    await tester.tap(find.text('Âm nhạc & sáng tạo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giáo dục & kiến thức').last);
    await tester.pumpAndSettle();
    expect(find.text('#giaoduc'), findsOneWidget);
    expect(find.text('#remix'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(VideoCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(VideoCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Bình luận'), findsOneWidget);
    expect(find.text('Video liên quan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chuông thông báo mở trung tâm thông báo trên điện thoại', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();

    expect(find.text('Tất cả thông báo'), findsOneWidget);
    expect(find.text('Chưa có thông báo'), findsOneWidget);
    expect(find.text('Đánh dấu đã đọc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thông báo chưa đọc hiện badge và đánh dấu đã đọc được', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _NotificationApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Thông báo (1 chưa đọc)'), findsOneWidget);
    await tester.tap(find.byTooltip('Thông báo (1 chưa đọc)'));
    await tester.pumpAndSettle();

    expect(find.text('1 chưa đọc'), findsOneWidget);
    expect(find.textContaining('đã thích video của bạn'), findsOneWidget);

    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle();

    expect(find.text('1 chưa đọc'), findsNothing);
    expect(find.text('Bạn đã xem hết thông báo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bảng xu hướng hiển thị điểm và đổi được khoảng thời gian', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _TrendingApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Xem tất cả video xu hướng'), findsOneWidget);
    await tester.tap(find.byTooltip('Xem tất cả video xu hướng'));
    await tester.pumpAndSettle();

    expect(find.text('Video đang thịnh hành'), findsOneWidget);
    expect(find.text('Khoảng thời gian'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('7 ngày'), findsOneWidget);
    expect(find.text('30 ngày'), findsOneWidget);
    expect(find.textContaining('Điểm xu hướng'), findsWidgets);
    expect(find.text('Nhạc Mỹ Nhân'), findsWidgets);

    await tester.tap(find.text('Hôm nay'));
    await tester.pumpAndSettle();

    expect(find.textContaining('24 giờ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mục Đăng ký hiển thị video mới từ kênh đã đăng ký', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    expect(find.text('Video mới từ kênh đã đăng ký'), findsOneWidget);
    expect(find.text('Video mới'), findsOneWidget);
    expect(find.text('Nhạc Ai Là Người Thương Em'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Nhạc Ai Là Người Thương Em').first);
    await tester.pumpAndSettle();
    expect(find.text('Bình luận'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã đăng ký'));
    await tester.pumpAndSettle();

    expect(find.text('Kênh bạn đã đăng ký'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trang chủ báo lỗi thay vì dùng dữ liệu mẫu khi API offline', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(PtkTubeApp(api: _BrokenApi(), authRequired: false));
    await tester.pumpAndSettle();

    expect(find.text('Không tải được dữ liệu từ Neon'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Chưa kết nối'), findsOneWidget);
    expect(find.text('Nhạc Mỹ Nhân'), findsNothing);
  });

  testWidgets('Thống kê hiển thị đúng số liệu trả về từ API', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(PtkTubeApp(api: _StatsApi(), authRequired: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thống Kê'));
    await tester.pumpAndSettle();

    expect(find.text('Thống Kê Video'), findsOneWidget);
    expect(find.text('9,9 Tr'), findsOneWidget);
    expect(find.text('4,3 N'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('33'), findsOneWidget);
    expect(find.text('Lượt xem 7 ngày gần nhất'), findsOneWidget);
    expect(find.text('Không tải được dữ liệu từ Neon'), findsNothing);
  });

  testWidgets('Tìm kiếm lọc được danh sách video', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'gaming');
    await tester.pumpAndSettle();

    expect(find.textContaining('Kết quả cho'), findsOneWidget);
    expect(find.text('Video mới'), findsNothing);
  });

  testWidgets('Desktop rộng hiển thị 5 cột và đủ menu điều hướng', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    // 1400 - 40 (padding 2 bên) = 1360; 5 cột, gap 16 => (1360 - 64) / 5 = 259.2
    final double cardWidth = tester.getSize(find.byType(VideoCard).first).width;
    expect(cardWidth, closeTo(259.2, 1));

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Đăng Video'), findsOneWidget);
    expect(find.text('Lịch sử'), findsOneWidget);
    expect(find.text('Đăng ký'), findsOneWidget);
  });

  testWidgets('Điều hướng tới các trang con', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng Video'));
    await tester.pumpAndSettle();
    expect(find.text('Tải video'), findsOneWidget);
    expect(find.text('Chọn video để tải lên'), findsOneWidget);

    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Video xu hướng'), findsOneWidget);

    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử Đăng Video của bạn'), findsOneWidget);

    await tester.tap(find.text('LỊCH SỬ XEM VIDEO'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử Xem Video của bạn'), findsOneWidget);

    await tester.tap(find.text('Thống Kê'));
    await tester.pumpAndSettle();
    expect(find.text('Thống Kê Video'), findsOneWidget);

    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Video mới từ kênh đã đăng ký'), findsOneWidget);
    await tester.tap(find.text('KÊNH ĐÃ ĐĂNG KÝ'));
    await tester.pumpAndSettle();
    expect(find.text('Kênh bạn đã đăng ký'), findsOneWidget);

    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào!'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
  });

  testWidgets('Trang xem video hiển thị bình luận và gửi được bình luận', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nhạc Mỹ Nhân').first);
    await tester.pumpAndSettle();

    expect(find.text('Bình luận'), findsOneWidget);
    expect(find.text('Video liên quan'), findsOneWidget);
    expect(find.text('Viết bình luận...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hay quá');
    await tester.ensureVisible(find.byTooltip('Gửi bình luận'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gửi bình luận'));
    await tester.pumpAndSettle();

    expect(find.text('hay quá'), findsOneWidget);
  });

  testWidgets('Đăng nhập rồi đăng xuất và không hiện tài khoản demo', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(
        api: _OfflineApi(),
        authRequired: true,
        authStore: _MemoryAuthStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('DÙNG DEMO'), findsNothing);
    expect(find.text('TÀI KHOẢN DEMO'), findsNothing);
    expect(find.textContaining('TikTube@123'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'kiepthan4');
    await tester.enterText(find.byType(TextFormField).at(1), 'TikTube@123');
    await tester.tap(find.byKey(const ValueKey<String>('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Xin chào, kiepthan4'), findsNothing);
    expect(find.text('Video xu hướng'), findsOneWidget);

    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào!'), findsOneWidget);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
  });

  testWidgets('Mở lại app vẫn giữ phiên đăng nhập cho đến khi đăng xuất', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MemoryAuthStore store = _MemoryAuthStore();
    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: true, authStore: store),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'kiepthan4');
    await tester.enterText(find.byType(TextFormField).at(1), 'TikTube@123');
    await tester.tap(find.byKey(const ValueKey<String>('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Video xu hướng'), findsOneWidget);

    // Giả lập thoát hẳn app rồi mở lại: phiên phải được khôi phục.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: true, authStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsNothing);
    expect(find.text('Video xu hướng'), findsOneWidget);

    // Đăng xuất phải xoá phiên để lần mở sau hiện lại màn hình đăng nhập.
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      PtkTubeApp(api: _OfflineApi(), authRequired: true, authStore: store),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
  });

  testWidgets('Chuyển sang đăng ký hiển thị đầy đủ trường', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(
        api: _OfflineApi(),
        authRequired: true,
        authStore: _MemoryAuthStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo tài khoản mới'), findsOneWidget);
    expect(find.text('Tên hiển thị'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Nhập lại mật khẩu'), findsOneWidget);
    expect(find.text('Tuổi (không bắt buộc)'), findsOneWidget);
    expect(find.text('Tạo tài khoản'), findsOneWidget);
  });

  testWidgets('Sai mật khẩu hiển thị thông báo lỗi rõ ràng', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(
        api: _BadLoginApi(),
        authRequired: true,
        authStore: _MemoryAuthStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'kiepthan4');
    await tester.enterText(find.byType(TextFormField).at(1), 'sai-mat-khau');
    await tester.tap(find.byKey(const ValueKey<String>('auth-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Tên đăng nhập hoặc mật khẩu không đúng.'),
      findsOneWidget,
    );
  });
}
