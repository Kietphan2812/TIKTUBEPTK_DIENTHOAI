import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Cho phép kéo ngang bằng chuột trên desktop (mặc định Flutter chỉ kéo bằng touch).
class HorizontalDragScroll extends StatelessWidget {
  const HorizontalDragScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: <PointerDeviceKind>{
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: child,
    );
  }
}
