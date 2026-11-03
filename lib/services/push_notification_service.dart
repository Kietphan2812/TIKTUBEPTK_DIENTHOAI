import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/user_preferences.dart';

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
          // Người dùng bấm vào thông báo
        },
      );

      // Tạo các notification channels trên Android
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_messagesChannel);
        await androidImplementation.createNotificationChannel(_callsChannel);
        await androidImplementation.requestNotificationsPermission();
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

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final isCall = data['type'] == 'call' || (data['callType'] != null);

    final title = notification?.title ?? (isCall ? 'Cuộc gọi đến' : 'Tin nhắn mới');
    final body = notification?.body ?? (isCall ? 'Bạn có cuộc gọi đến trên TIKTUBE' : 'Bạn nhận được tin nhắn mới');

    _showNotification(
      id: message.hashCode,
      title: title,
      body: body,
      isCall: isCall,
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required bool isCall,
  }) async {
    final channel = isCall ? _callsChannel : _messagesChannel;

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: isCall ? Priority.max : Priority.high,
      fullScreenIntent: isCall,
      category: isCall ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
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
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Hiển thị thông báo cuộc gọi đến dạng Heads-up banner và rung chuông
  Future<void> showIncomingCallNotification({
    required String callerName,
    required String callerPhone,
    required bool isVideo,
  }) async {
    final title = 'Cuộc gọi ${isVideo ? "Video" : "thoại"} TIKTUBE';
    final body = '$callerName ($callerPhone) đang gọi cho bạn...';

    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      isCall: true,
    );
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
}
