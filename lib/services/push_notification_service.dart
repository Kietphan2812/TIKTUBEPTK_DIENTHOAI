import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/chat_service.dart';
import '../data/user_preferences.dart';
import 'call_manager.dart';

/// Hàm xử lý thông báo chạy ngầm khi ứng dụng bị đóng hoặc ở nền (Background/Terminated).
/// Bắt buộc phải là hàm top-level và có annotation @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const int callNotificationId = 88888;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _messagesChannel =
      AndroidNotificationChannel(
    'tiktube_messages',
    'Tin nhắn TIKTUBE',
    description: 'Kênh thông báo tin nhắn mới',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationChannel _callsChannel =
      AndroidNotificationChannel(
    'tiktube_calls',
    'Cuộc gọi TIKTUBE',
    description: 'Kênh thông báo cuộc gọi đến',
    importance: Importance.max,
    playSound: true,
  );

  static const AndroidNotificationChannel _socialChannel =
      AndroidNotificationChannel(
    'tiktube_interactions',
    'Tương tác TIKTUBE',
    description: 'Kênh thông báo thích, bình luận và đăng ký kênh',
    importance: Importance.high,
    playSound: true,
  );

  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Khởi tạo Firebase và hệ thống thông báo đẩy
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (kIsWeb) {
        // Cấu hình web Firebase nếu cần
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyDEcfKADqo56LH7nKojiP8zCl2c7Sw_Rew',
            appId: '1:60200620861:android:96c4ab0412e8e2acffab54',
            messagingSenderId: '60200620861',
            projectId: 'tiktube-cd8d5',
            storageBucket: 'tiktube-cd8d5.firebasestorage.app',
          ),
        );
      } else {
        await Firebase.initializeApp();
      }

      // Đăng ký background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Cài đặt Local Notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          _onNotificationResponse(response);
        },
      );

      // Tạo các notification channels trên Android
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_messagesChannel);
        await androidImplementation.createNotificationChannel(_callsChannel);
        await androidImplementation.createNotificationChannel(_socialChannel);
        await androidImplementation.requestNotificationsPermission();
      }

      // Kiểm tra xem ứng dụng có được mở từ việc nhấn vào thông báo hay không
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final resp = launchDetails.notificationResponse;
        if (resp != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onNotificationResponse(resp);
          });
        }
      }

      // Xin quyền nhận thông báo từ Firebase
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // ignore: deprecated_member_use
        _fcmToken = await FirebaseMessaging.instance.getToken();
        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          unawaited(UserPreferences.saveUserPhone('fcm_token', _fcmToken!));
        }
      }

      // Lắng nghe khi token thay đổi
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        unawaited(UserPreferences.saveUserPhone('fcm_token', newToken));
      });

      // Lắng nghe tin nhắn khi app đang mở (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });
    } catch (e) {
      debugPrint('Khởi tạo Push Notification thất bại: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payloadStr = response.payload;
    if (payloadStr == null || payloadStr.isEmpty) return;
    try {
      final data = jsonDecode(payloadStr) as Map<String, dynamic>;
      if (data['type'] == 'call') {
        final callerId = data['callerId']?.toString() ?? '';
        final callerName = data['callerName']?.toString() ?? 'Bạn bè';
        final callerPhone = data['callerPhone']?.toString() ?? '';
        final callerAvatar = data['callerAvatar']?.toString() ?? '';
        final isVideo = data['isVideo'] == true;

        if (response.actionId == 'action_decline') {
          // Bấm Từ chối trực tiếp từ thông báo
          unawaited(CallManager.instance.stopRingtone());
          ChatService.instance.rejectCall(callerId);
          unawaited(cancelCallNotification());
          return;
        }

        // Bấm Trả lời hoặc bấm thẳng vào banner thông báo -> Chuyển ngay vào trang gọi!
        unawaited(CallManager.instance.stopRingtone());
        unawaited(CallManager.instance.bringAppToFront());
        CallManager.instance.showIncomingCall(
          callerId: callerId,
          callerName: callerName,
          callerPhone: callerPhone,
          callerAvatar: callerAvatar,
          isVideo: isVideo,
        );

        if (response.actionId == 'action_answer') {
          ChatService.instance.answerCall(callerId);
        }
      }
    } catch (e) {
      debugPrint('Lỗi xử lý phản hồi thông báo: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final isCall = data['type'] == 'call' || (data['callType'] != null);

    final title = notification?.title ?? (isCall ? 'Cuộc gọi đến' : 'Tin nhắn mới');
    final body = notification?.body ?? (isCall ? 'Bạn có cuộc gọi đến trên TIKTUBE' : 'Bạn nhận được tin nhắn mới');

    _showNotification(
      id: isCall ? callNotificationId : message.hashCode,
      title: title,
      body: body,
      isCall: isCall,
      payload: jsonEncode(data),
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required bool isCall,
    String? payload,
  }) async {
    final channel = isCall ? _callsChannel : _messagesChannel;

    final actions = isCall
        ? <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'action_answer',
              'Trả lời',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              'action_decline',
              'Từ chối',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ]
        : null;

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: isCall ? Priority.max : Priority.high,
      fullScreenIntent: isCall,
      category: isCall ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
      icon: '@mipmap/ic_launcher',
      ongoing: isCall,
      autoCancel: !isCall,
      actions: actions,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Hiển thị thông báo cuộc gọi đến dạng Heads-up banner và rung chuông kèm nút bấm thao tác
  Future<void> showIncomingCallNotification({
    required String callerId,
    required String callerName,
    required String callerPhone,
    required String callerAvatar,
    required bool isVideo,
  }) async {
    final title = 'Cuộc gọi ${isVideo ? "Video" : "thoại"} TIKTUBE';
    final body = '$callerName ($callerPhone) đang gọi cho bạn...';
    final payload = jsonEncode({
      'type': 'call',
      'callerId': callerId,
      'callerName': callerName,
      'callerPhone': callerPhone,
      'callerAvatar': callerAvatar,
      'isVideo': isVideo,
    });

    await _showNotification(
      id: callNotificationId,
      title: title,
      body: body,
      isCall: true,
      payload: payload,
    );
  }

  /// Hủy thông báo cuộc gọi đến khi cuộc gọi kết thúc hoặc bị hủy
  Future<void> cancelCallNotification() async {
    try {
      await _localNotifications.cancel(id: callNotificationId);
    } catch (_) {}
  }

  /// Hiển thị thông báo tin nhắn mới
  Future<void> showNewMessageNotification({
    required String senderName,
    required String text,
  }) async {
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: senderName,
      body: text,
      isCall: false,
    );
  }

  /// Hiển thị thông báo tương tác video TIKTUBE (Thích, Bình luận, Đăng ký kênh)
  Future<void> showSocialNotification({
    required String id,
    required String content,
  }) async {
    String title = 'TIKTUBE';
    if (content.contains('đã thích')) {
      title = '❤️ Lượt thích mới';
    } else if (content.contains('đã bình luận')) {
      title = '💬 Bình luận mới';
    } else if (content.contains('đã đăng ký')) {
      title = '🔔 Đăng ký kênh mới';
    }

    final androidDetails = AndroidNotificationDetails(
      _socialChannel.id,
      _socialChannel.name,
      channelDescription: _socialChannel.description,
      importance: _socialChannel.importance,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: id.hashCode,
      title: title,
      body: content,
      notificationDetails: details,
    );
  }
}
