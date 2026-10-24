import 'package:flutter/material.dart';

import '../models/video.dart';
import '../theme/app_theme.dart';
import 'channel_avatar.dart';
import 'video_thumb.dart';

/// Card video trong lưới "Video mới".
///
/// Trên điện thoại, [compact] dùng kiểu hàng ngang để danh sách gọn và dễ
/// xem hơn; trên màn hình lớn vẫn giữ kiểu card dọc như cũ.
class VideoCard extends StatefulWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.compact = false,
  });

  final Video video;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.compact ? _buildCompact(p) : _buildGrid(p),
      ),
    );
  }

  Widget _buildCompact(PtPalette p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 136,
          child: VideoThumb(
            video: widget.video,
            radius: 9,
            showControls: false,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                _ChannelLine(video: widget.video, palette: p, compact: true),
                const SizedBox(height: 2),
                Text(
                  '${widget.video.viewsLabel} · ${widget.video.date}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(PtPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedScale(
          scale: _hovered ? 1.012 : 1,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _hovered ? p.shadow : p.shadow.withValues(alpha: 0),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: VideoThumb(
              video: widget.video,
              showControls: widget.video.isPlayable,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ChannelAvatar(video: widget.video, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _ChannelLine(video: widget.video, palette: p),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.video.viewsLabel} · ${widget.video.date}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tên kênh kèm huy hiệu khi video thuộc kênh người dùng đã đăng ký.
class _ChannelLine extends StatelessWidget {
  const _ChannelLine({
    required this.video,
    required this.palette,
    this.compact = false,
  });

  final Video video;
  final PtPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            video.channel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
          ),
        ),
        if (video.subscribed) ...<Widget>[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: palette.brandRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.check_circle_rounded,
                  size: compact ? 9 : 10,
                  color: palette.brandRed,
                ),
                const SizedBox(width: 2),
                Text(
                  'Đã đăng ký',
                  style: TextStyle(
                    fontSize: compact ? 8.5 : 9,
                    fontWeight: FontWeight.w700,
                    color: palette.brandRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
