import 'dart:async';
import 'package:flutter/material.dart';

import '../data/chat_service.dart';
import '../models/chat_contact.dart';
import '../widgets/call_overlay.dart';
import 'push_notification_service.dart';

/// Quản lý cuộc gọi toàn cục (Global Call Manager)
/// Tự động chuyển app sang màn hình cuộc gọi bất kể người dùng đang ở trang nào.
class CallManager {
  CallManager._();
  static final CallManager instance = CallManager._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  StreamSubscription<Map<String, dynamic>>? _callSub;
  bool _initialized = false;

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

        showIncomingCall(
          callerId: callerId,
          callerName: callerName,
          callerPhone: callerPhone,
          callerAvatar: callerAvatar,
          isVideo: isVideo,
        );
      } else if (type == 'ended' || type == 'rejected') {
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
    _initialized = false;
  }
}

