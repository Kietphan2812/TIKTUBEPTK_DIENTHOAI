import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../models/video.dart';
import '../screens/channel_screen.dart';
import '../theme/app_theme.dart';

/// Avatar kênh: hiển thị ảnh thật từ tác giả / Neon / Cloudinary nếu có;
/// nếu không thì quay về gradient + chữ cái đầu.
/// Tự động hỗ trợ bấm vào để mở trang kênh cá nhân của tác giả.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.video,
    this.size = 32,
    this.enableNavigation = true,
    this.onTap,
  });

  final Video video;
  final double size;
  final bool enableNavigation;
  final VoidCallback? onTap;

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

  void _handleTap(BuildContext context, String? effectiveAvatar) {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (!enableNavigation) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChannelScreen(
          channelName: video.channel,
          channelId: video.channelId,
          avatarUrl: effectiveAvatar ?? video.authorAvatarUrl,
          subscriberCount: video.subscriberCount,
          subscribed: video.subscribed,
          initialVideo: video,
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

    Widget content;
    if (effectiveAvatar != null && effectiveAvatar.trim().isNotEmpty) {
      final trimmed = effectiveAvatar.trim();
      content = Container(
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
    } else {
      content = _buildFallback(context);
    }

    if (enableNavigation || onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(context, effectiveAvatar),
          child: content,
        ),
      );
    }

    return content;
  }
}
