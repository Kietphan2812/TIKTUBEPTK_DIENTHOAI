import 'package:flutter/material.dart';

import '../models/video.dart';
import '../theme/app_theme.dart';

/// Avatar kênh: gradient + chữ cái đầu (không cần asset/network).
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({super.key, required this.video, this.size = 32});

  final Video video;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: video.colors,
        ),
        border: Border.all(
          color: context.palette.surface.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Text(
        video.initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
          height: 1,
        ),
      ),
    );
  }
}
