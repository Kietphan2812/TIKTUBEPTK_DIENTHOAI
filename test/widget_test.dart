import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_app_ptk/app.dart';
import 'package:flutter_app_ptk/auth/auth_session_store_base.dart';
import 'package:flutter_app_ptk/data/sample_data.dart';
import 'package:flutter_app_ptk/data/tiktube_api.dart';
import 'package:flutter_app_ptk/models/auth_session.dart';
import 'package:flutter_app_ptk/models/channel.dart';
import 'package:flutter_app_ptk/models/comment.dart';
import 'package:flutter_app_ptk/models/creator_stats.dart';
import 'package:flutter_app_ptk/models/profile.dart';
import 'package:flutter_app_ptk/models/video.dart';
import 'package:flutter_app_ptk/models/watch_history_item.dart';
import 'package:flutter_app_ptk/widgets/video_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// API giả lập: luôn offline để test dùng dữ liệu mẫu, không gọi mạng.
class _OfflineApi implements TikTubeApi {
  @override
  Future<List<Video>> fetchVideos() async => kLatestVideos;

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
  Future<Video> uploadVideo({
    required String title,
    required String description,
    required String category,
    required List<String> tags,
    required bool kidsOnly,
    required Uint8List bytes,
    required String filename,
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
  Future<List<Channel>> fetchSubscriptions() async =>
      throw Exception('offline');

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
  }) async => Profile(
        userKey: 'kiepthan4',
        name: name,
        email: email,
        age: age,
      );

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
        profile: Profile(
          userKey: username,
          name: name,
          email: email,
          age: age,
        ),
      );

  @override
  Future<void> logout() async {}
}

class _BrokenApi extends _OfflineApi {
  @override
  Future<List<Video>> fetchVideos() async => throw Exception('offline');
}

class _BadLoginApi extends _OfflineApi {
  @override
  Future<AuthSession> login({
    required String login,
    required String password,
  }) async => throw ApiException('Tên đăng nhập hoặc mật khẩu không đúng.',
      statusCode: 401);
}

class _MemoryAuthStore implements AuthSessionStore {
  String? _value;

  @override
  String? read() => _value;

  @override
  void write(String value) => _value = value;

  @override
  void clear() => _value = null;
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

    expect(find.text('Xin chào, kiepthan4'), findsOneWidget);
    expect(find.text('Video xu hướng'), findsOneWidget);
    expect(find.text('Video mới'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
  });

  testWidgets('Trang chủ báo lỗi thay vì dùng dữ liệu mẫu khi API offline', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PtkTubeApp(api: _BrokenApi(), authRequired: false),
    );
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

    await tester.pumpWidget(
      PtkTubeApp(api: _StatsApi(), authRequired: false),
    );
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

  testWidgets('Đăng nhập bằng tài khoản demo rồi đăng xuất', (
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
    expect(find.text('Tài khoản demo'), findsNothing);
    expect(find.text('TÀI KHOẢN DEMO'), findsOneWidget);

    await tester.tap(find.text('Điền'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Xin chào, kiepthan4'), findsOneWidget);
    expect(find.text('Video xu hướng'), findsOneWidget);

    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào!'), findsOneWidget);

    await tester.tap(find.text('Đăng xuất'));
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

    expect(find.text('Tên đăng nhập hoặc mật khẩu không đúng.'), findsOneWidget);
  });
}
