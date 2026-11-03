import 'package:flutter/material.dart';

import 'app.dart';
import 'services/call_manager.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.instance.init();
  CallManager.instance.init();
  runApp(const PtkTubeApp());
}
