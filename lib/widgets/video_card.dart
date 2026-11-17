import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video.dart';
import '../theme/app_theme.dart';
import '../utils/video_downloader.dart';
import 'channel_avatar.dart';
import 'video_thumb.dart';

/// Card video chuẩn phong cách YouTube:
/// - Trên điện thoại ([compact] = true): thẻ tràn viền (16:9 full-width),
///   ảnh đại diện kênh 38px, tiêu đề 2 dòng đậm, thời lượng góc dưới thumbnail,
///   thông tin kênh & lượt xem và menu tùy chọn 3 chấm.
/// - Trên màn hình lớn ([compact] = false): dạng lưới card bo góc hiện đại.
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

  void _showVideoMenu(BuildContext context, Video video) {
    final p = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.playlist_add_rounded, color: p.textPrimary),
                  title: Text(
                    'Lưu vào danh sách xem sau',
                    style: TextStyle(color: p.textPrimary, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã thêm vào danh sách xem sau')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.share_rounded, color: p.textPrimary),
                  title: Text(
                    'Chia sẻ liên kết',
                    style: TextStyle(color: p.textPrimary, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(
                      ClipboardData(
                        text: 'https://tiktube-api.onrender.com/watch?v=${video.id}',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép liên kết video')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.download_rounded, color: p.textPrimary),
                  title: Text(
                    'Tải video xuống',
                    style: TextStyle(color: p.textPrimary, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    VideoDownloader.downloadVideo(
                      videoId: video.id,
                      title: video.title,
                      directUrl: video.videoUrl,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.flag_outlined, color: p.textPrimary),
                  title: Text(
                    'Báo cáo vi phạm',
                    style: TextStyle(color: p.textPrimary, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cảm ơn bạn đã báo cáo. Chúng tôi sẽ xem xét.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

  /// Giao diện thẻ video YouTube tràn viền trên Mobile.
  Widget _buildCompact(PtPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Video thumbnail (16:9 full-width)
        VideoThumb(
          video: widget.video,
          radius: 0,
          showControls: false,
        ),
        // Thông tin kênh & Tiêu đề
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ChannelAvatar(video: widget.video, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _ChannelLine(
                      video: widget.video,
                      palette: p,
                      compact: true,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showVideoMenu(context, widget.video),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, right: 4, top: 2),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: p.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Giao diện thẻ video dạng lưới trên Desktop/Tablet.
  Widget _buildGrid(PtPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedScale(
          scale: _hovered ? 1.015 : 1,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
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
              radius: 10,
              showControls: false,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ChannelAvatar(video: widget.video, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _ChannelLine(video: widget.video, palette: p),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showVideoMenu(context, widget.video),
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: p.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tên kênh, lượt xem, thời gian đăng và huy hiệu khi đã đăng ký kênh.
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
            '${video.channel}  •  ${video.viewsLabel}  •  ${video.date}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12 : 11,
              color: palette.textSecondary,
              height: 1.2,
            ),
          ),
        ),
        if (video.subscribed) ...<Widget>[
          const SizedBox(width: 6),
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
                  size: compact ? 9.5 : 9,
                  color: palette.brandRed,
                ),
                const SizedBox(width: 2),
                Text(
                  'Đã đăng ký',
                  style: TextStyle(
                    fontSize: compact ? 8.5 : 8,
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
