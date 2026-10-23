import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// Cho phép mọi màn hình truy cập trạng thái đăng nhập hiện tại.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController super.notifier,
    required super.child,
  });

  static AuthController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AuthScope>()
        ?.notifier;
  }

  static AuthController of(BuildContext context) {
    final AuthController? controller = maybeOf(context);
    assert(controller != null, 'AuthScope không được tìm thấy trong widget tree.');
    return controller!;
  }
}
