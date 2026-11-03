import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/tiktube_api.dart';
import '../models/app_notification.dart';
import 'push_notification_service.dart';

/// Dịch vụ tự động đồng bộ và bắn thông báo đẩy hệ thống cho TIKTUBE
/// (Khi có ai đó bấm thích, bình luận hoặc đăng ký kênh)
class NotificationSyncService {
  NotificationSyncService._();
  static final NotificationSyncService instance = NotificationSyncService._();

  TikTubeApi? _api;
  Timer? _pollTimer;
  final Set<String> _knownNotificationIds = <String>{};
  bool _isPrimed = false;
  bool _isChecking = false;

  void init(TikTubeApi api) {
    _api = api;
    _pollTimer?.cancel();
    // Lần đầu mở app: lấy danh sách thông báo và nạp vào bộ nhớ để không spam thông báo cũ
    unawaited(checkNewNotifications(silentInitial: true));
    // Kiểm tra thông báo mới định kỳ mỗi 15 giây
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(checkNewNotifications());
    });
  }

  Future<void> checkNewNotifications({bool silentInitial = false}) async {
    if (_api == null || _isChecking) return;
    _isChecking = true;

    try {
      final List<AppNotification> items = await _api!.fetchNotifications();
      if (!_isPrimed || silentInitial) {
        _knownNotificationIds.addAll(items.map((e) => e.id));
        _isPrimed = true;
      } else {
        // Tìm thông báo mới chưa xem và chưa từng thông báo
        final List<AppNotification> freshItems = items
            .where((e) => !_knownNotificationIds.contains(e.id) && !e.seen)
            .toList();

        for (final item in freshItems) {
          _knownNotificationIds.add(item.id);
          unawaited(PushNotificationService.instance.showSocialNotification(
            id: item.id,
            content: item.content,
          ));
        }

        _knownNotificationIds.addAll(items.map((e) => e.id));
      }
    } catch (e) {
      debugPrint('[NotificationSyncService] Lỗi đồng bộ thông báo: $e');
    } finally {
      _isChecking = false;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPrimed = false;
  }
}

