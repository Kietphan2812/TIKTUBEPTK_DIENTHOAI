import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';

/// Avatar kênh: hiển thị ảnh thật từ tác giả / Neon / Cloudinary nếu có;
/// nếu không thì quay về gradient + chữ cái đầu.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({super.key, required this.video, this.size = 32});

  final Video video;
  final double size;

  Widget _buildFallback(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.maybeOf(context)?.profile;
    String? effectiveAvatar = video.authorAvatarUrl;
    if ((effectiveAvatar == null || effectiveAvatar.trim().isEmpty) && profile != null) {
      final ch = video.channel.trim().toLowerCase();
      final up = video.uploadedBy.trim().toLowerCase();
      final pName = profile.name.trim().toLowerCase();
      final pKey = profile.userKey.trim().toLowerCase();
      if ((ch.isNotEmpty && (ch == pName || ch == pKey)) ||
          (up.isNotEmpty && (up == pName || up == pKey))) {
        effectiveAvatar = profile.avatarUrl;
      }
    }

    if (effectiveAvatar != null && effectiveAvatar.trim().isNotEmpty) {
      final trimmed = effectiveAvatar.trim();
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: context.palette.surface.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            trimmed,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(context),
          ),
        ),
      );
    }

    return _buildFallback(context);
  }
}
