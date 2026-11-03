import 'package:flutter/material.dart';

import 'app.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.instance.init();
  runApp(const PtkTubeApp());
}
