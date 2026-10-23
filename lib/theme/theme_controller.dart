import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  bool _dark = false;

  bool get isDark => _dark;
  ThemeMode get mode => _dark ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    _dark = !_dark;
    notifyListeners();
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController super.notifier,
    required super.child,
  });

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope không được tìm thấy trong widget tree.');
    return scope!.notifier!;
  }
}
