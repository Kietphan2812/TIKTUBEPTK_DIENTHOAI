import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video.dart';
import 'channel_avatar.dart';
import 'video_surface.dart';

/// Một trang dọc trong feed xem nhanh.
///
/// Trang chỉ phát khi [active] = true. Khi người dùng vuốt sang video khác,
/// trang cũ tự dừng, báo vị trí đã xem rồi nhường tài nguyên cho trang mới.
class QuickWatchPage extends StatefulWidget {
  const QuickWatchPage({
    super.key,
    required this.video,
    required this.active,
    required this.muted,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    required this.onFollow,
    required this.onToggleMute,
    required this.onProgress,
    required this.onRegisterView,
  });

  final Video video;
  final bool active;
  final bool muted;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onFollow;
  final VoidCallback onToggleMute;
  final ValueChanged<VideoPlaybackProgress> onProgress;
  final VoidCallback onRegisterView;

  @override
  State<QuickWatchPage> createState() => _QuickWatchPageState();
}

class _QuickWatchPageState extends State<QuickWatchPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;
  bool _pausedByUser = false;
  bool _captionExpanded = false;

  String? get _url => widget.video.videoUrl;

  @override
  void initState() {
    super.initState();
    if (widget.active) widget.onRegisterView();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant QuickWatchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.videoUrl != widget.video.videoUrl) {
      _controller?.removeListener(_onPlayerChanged);
      _controller?.dispose();
      _controller = null;
      _initialized = false;
      _failed = false;
      _initialize();
      return;
    }

    if (oldWidget.active != widget.active) {
      if (widget.active) {
        widget.onRegisterView();
        _pausedByUser = false;
        _play();
      } else {
        _reportProgress();
        _controller?.pause();
      }
    }

    if (oldWidget.muted != widget.muted) {
      _applyVolume();
    }
  }

  Future<void> _initialize() async {
    final String? url = _url;
    if (url == null || url.trim().isEmpty) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      controller.addListener(_onPlayerChanged);
      if (!mounted) return;
      setState(() => _initialized = true);
      if (widget.active) await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _applyVolume() async {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    try {
      await controller.setVolume(widget.muted ? 0 : 1);
    } catch (_) {
      // Một số trình duyệt chặn đổi âm lượng; không làm hỏng feed.
    }
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.isInitialized) {
      widget.onProgress(
        VideoPlaybackProgress(position: value.position, duration: value.duration),
      );
    }
  }

  void _play() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    unawaited(controller.play());
  }

  void _reportProgress() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    final value = controller.value;
    if (value.isInitialized) {
      widget.onProgress(
        VideoPlaybackProgress(position: value.position, duration: value.duration),
      );
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        _pausedByUser = true;
        unawaited(controller.pause());
        _reportProgress();
      } else {
        _pausedByUser = false;
        unawaited(controller.play());
      }
    });
  }

  @override
  void dispose() {
    _reportProgress();
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final Video video = widget.video;
    final bool showPaused =
        _initialized && _pausedByUser && !(_controller?.value.isPlaying ?? false);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildVideoLayer(),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0, 0.24, 0.55, 1],
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.38),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showPaused)
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          Positioned(
            left: 14,
            right: 92,
            bottom: 104 + bottomInset,
            child: _Caption(
              video: video,
              expanded: _captionExpanded,
              muted: widget.muted,
              onToggleExpanded: () {
                setState(() => _captionExpanded = !_captionExpanded);
              },
              onFollow: widget.onFollow,
              onToggleMute: widget.onToggleMute,
            ),
          ),
          Positioned(
            right: 8,
            bottom: 100 + bottomInset,
            child: _ActionRail(
              video: video,
              onLike: widget.onLike,
              onComment: widget.onComment,
              onSave: widget.onSave,
              onShare: widget.onShare,
              onFollow: widget.onFollow,
            ),
          ),
          if (_initialized && _controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 61 + bottomInset,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                padding: const EdgeInsets.only(top: 2),
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() {
    final VideoPlayerController? controller = _controller;
    if (_initialized &&
        controller != null &&
        controller.value.isInitialized) {
      final Size size = controller.value.size;
      if (size.width > 0 && size.height > 0) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      }
    }

    return _Poster(video: widget.video, failed: _failed);
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.video, required this.failed});

  final Video video;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = video.colors.length >= 2
        ? video.colors
        : const <Color>[Color(0xFF111827), Color(0xFF334155)];

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
        if ((video.thumbnailUrl ?? '').trim().isNotEmpty)
          Image.network(
            video.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (!failed && (video.videoUrl ?? '').trim().isNotEmpty)
          Center(
            child: Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: Colors.white54),
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        if (failed)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 38),
                SizedBox(height: 8),
                Text(
                  'Không phát được video này',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.video,
    required this.expanded,
    required this.muted,
    required this.onToggleExpanded,
    required this.onFollow,
    required this.onToggleMute,
  });

  final Video video;
  final bool expanded;
  final bool muted;
  final VoidCallback onToggleExpanded;
  final VoidCallback onFollow;
  final VoidCallback onToggleMute;

  String get _handle {
    final String value = video.handle.trim();
    if (value.isEmpty) return '@kenh';
    return value.startsWith('@') ? value : '@$value';
  }

  @override
  Widget build(BuildContext context) {
    final bool canExpand = video.description.trim().length > 80;
    final String reason = video.recommendationLabel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                _handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  shadows: <Shadow>[Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
            ),
            if (video.channelId.isNotEmpty && !video.subscribed) ...<Widget>[
              const SizedBox(width: 8),
              _FollowPill(onTap: onFollow),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w600,
            shadows: <Shadow>[Shadow(blurRadius: 6, color: Colors.black54)],
          ),
        ),
        if (video.description.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            video.description.trim(),
            maxLines: expanded ? 6 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              height: 1.32,
              shadows: const <Shadow>[
                Shadow(blurRadius: 6, color: Colors.black54),
              ],
            ),
          ),
          if (canExpand)
            GestureDetector(
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  expanded ? 'Thu gọn' : 'Xem thêm',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _MetaPill(
              icon: Icons.play_arrow_rounded,
              label: '${_compactNumber(video.views)} lượt xem',
            ),
            if (reason.isNotEmpty)
              _MetaPill(icon: Icons.auto_awesome_rounded, label: reason),
            if (video.category.trim().isNotEmpty)
              _MetaPill(
                icon: Icons.tag_rounded,
                label: video.category,
                maxWidth: 150,
              ),
          ],
        ),
        if (video.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          SizedBox(
            height: 24,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: video.tags.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, int index) => Text(
                '#${video.tags[index]}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Icon(Icons.music_note_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Âm thanh gốc — ${video.channel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: muted ? 'Bật âm thanh' : 'Tắt âm thanh',
              child: InkResponse(
                onTap: onToggleMute,
                radius: 18,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FollowPill extends StatelessWidget {
  const _FollowPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white54),
        ),
        child: const Text(
          'Theo dõi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.maxWidth,
  });

  final IconData icon;
  final String label;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 210),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.video,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    required this.onFollow,
  });

  final Video video;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 56,
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: <Widget>[
              ChannelAvatar(video: video, size: 48),
              if (video.channelId.isNotEmpty && !video.subscribed)
                Positioned(
                  bottom: 0,
                  child: Tooltip(
                    message: 'Theo dõi kênh',
                    child: GestureDetector(
                      onTap: onFollow,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFE2C55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _RailButton(
          tooltip: video.liked ? 'Bỏ thích' : 'Thích',
          icon: video.liked ? Icons.favorite : Icons.favorite_border,
          color: video.liked ? const Color(0xFFFE2C55) : Colors.white,
          label: _compactNumber(video.likeCount),
          onTap: onLike,
        ),
        _RailButton(
          tooltip: 'Bình luận',
          icon: Icons.mode_comment_outlined,
          label: _compactNumber(video.commentCount),
          onTap: onComment,
        ),
        _RailButton(
          tooltip: video.saved ? 'Bỏ lưu' : 'Lưu video',
          icon: video.saved ? Icons.bookmark : Icons.bookmark_border,
          color: video.saved ? const Color(0xFFFFC94A) : Colors.white,
          label: video.saved ? 'Đã lưu' : 'Lưu',
          onTap: onSave,
        ),
        _RailButton(
          tooltip: 'Chia sẻ',
          icon: Icons.share_rounded,
          label: 'Chia sẻ',
          onTap: onShare,
        ),
        const SizedBox(height: 4),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF1F2937), Color(0xFF111827)],
            ),
            border: Border.all(color: Colors.white54, width: 4),
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.22),
                  ),
                  child: Icon(icon, color: color, size: 29),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    shadows: <Shadow>[
                      Shadow(blurRadius: 5, color: Colors.black54),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _compactNumber(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')}K';
  }
  return '$value';
}
