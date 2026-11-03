import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_service.dart';
import '../models/chat_contact.dart';
import '../widgets/call_overlay.dart';
import 'push_notification_service.dart';

/// Quản lý cuộc gọi toàn cục (Global Call Manager)
/// Tự động chuyển app sang màn hình cuộc gọi, phát nhạc chuông hệ thống, và đưa app lên trước.
class CallManager {
  CallManager._();
  static final CallManager instance = CallManager._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const MethodChannel _appControl =
      MethodChannel('com.example.flutter_app_ptk/app_control');

  StreamSubscription<Map<String, dynamic>>? _callSub;
  bool _initialized = false;

  /// Đưa ứng dụng lên màn hình chính khi có cuộc gọi đến
  Future<void> bringAppToFront() async {
    try {
      await _appControl.invokeMethod('bringToFront');
    } catch (e) {
      debugPrint('[CallManager] Lỗi bringAppToFront: $e');
    }
  }

  /// Phát nhạc chuông điện thoại thật của hệ thống
  Future<void> startRingtone() async {
    try {
      await _appControl.invokeMethod('startRingtone');
    } catch (e) {
      debugPrint('[CallManager] Lỗi startRingtone: $e');
    }
  }

  /// Dừng phát nhạc chuông điện thoại
  Future<void> stopRingtone() async {
    try {
      await _appControl.invokeMethod('stopRingtone');
    } catch (e) {
      debugPrint('[CallManager] Lỗi stopRingtone: $e');
    }
  }

  void init() {
    if (_initialized) return;
    _initialized = true;

    _callSub?.cancel();
    _callSub = ChatService.instance.callEvents.listen((event) {
      final type = event['type']?.toString();
      if (type == 'incoming') {
        final data = event['data'] as Map<String, dynamic>? ?? {};
        final caller = data['caller'] as Map<String, dynamic>? ?? {};
        final callerId = caller['id']?.toString() ?? '';
        final callerName = caller['name']?.toString() ??
            caller['username']?.toString() ??
            'Bạn bè';
        final callerPhone = caller['phone']?.toString() ?? '';
        final callerAvatar = caller['avatar']?.toString() ?? '';
        final isVideo = (data['isVideo'] == true) || (data['type'] == 'video');

        // Bật chuông điện thoại & chuyển app ra màn hình trước
        unawaited(bringAppToFront());
        unawaited(startRingtone());

        showIncomingCall(
          callerId: callerId,
          callerName: callerName,
          callerPhone: callerPhone,
          callerAvatar: callerAvatar,
          isVideo: isVideo,
        );
      } else if (type == 'ended' || type == 'rejected' || type == 'answered') {
        unawaited(stopRingtone());
        unawaited(PushNotificationService.instance.cancelCallNotification());
      }
    });
  }

  /// Hiển thị màn hình cuộc gọi đến trên toàn bộ ứng dụng
  void showIncomingCall({
    required String callerId,
    required String callerName,
    required String callerPhone,
    required String callerAvatar,
    required bool isVideo,
  }) {
    if (CallOverlay.isCallOpen) return;

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[CallManager] Navigator context chưa sẵn sàng, sẽ thử lại sau frame đầu');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delayedContext = navigatorKey.currentContext;
        if (delayedContext != null && !CallOverlay.isCallOpen) {
          _launchCall(
            context: delayedContext,
            callerId: callerId,
            callerName: callerName,
            callerPhone: callerPhone,
            callerAvatar: callerAvatar,
            isVideo: isVideo,
          );
        }
      });
      return;
    }

    _launchCall(
      context: context,
      callerId: callerId,
      callerName: callerName,
      callerPhone: callerPhone,
      callerAvatar: callerAvatar,
      isVideo: isVideo,
    );
  }

  void _launchCall({
    required BuildContext context,
    required String callerId,
    required String callerName,
    required String callerPhone,
    required String callerAvatar,
    required bool isVideo,
  }) {
    if (CallOverlay.isCallOpen) return;

    final friend = ChatService.instance.friends.firstWhere(
      (f) => f.id == callerId,
      orElse: () => Friend(
        id: callerId,
        name: callerName,
        username: callerName,
        phone: callerPhone,
        avatar: callerAvatar,
      ),
    );

    CallOverlay.startCall(
      context,
      friend: friend,
      isVideo: isVideo,
      isIncoming: true,
    );
  }

  void dispose() {
    _callSub?.cancel();
    unawaited(stopRingtone());
    _initialized = false;
  }
}
