import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video.dart';
import 'video_thumb.dart';

/// Trình phát thật cho video Cloudinary; tự quay về thumbnail gradient nếu
/// video không có URL hoặc trình duyệt không phát được.
class VideoPlaybackProgress {
  const VideoPlaybackProgress({required this.position, required this.duration});

  final Duration position;
  final Duration duration;
}

class VideoSurface extends StatefulWidget {
  const VideoSurface({super.key, required this.video, this.onProgress});

  final Video video;

  /// Báo vị trí phát hiện tại để màn hình xem lưu thời lượng đã xem.
  final ValueChanged<VideoPlaybackProgress>? onProgress;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;
  Duration _lastReportedPosition = Duration.zero;

  String? get _url {
    final raw = widget.video.videoUrl;
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.contains('drive.google.com') && trimmed.contains('id=')) {
      final match = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(trimmed);
      if (match != null) {
        return 'https://tiktube-api.onrender.com/api/drive/stream?id=${match.group(1)}';
      }
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant VideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.videoUrl != widget.video.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _initialized = false;
      _failed = false;
      _lastReportedPosition = Duration.zero;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final url = _url;
    if (url == null || url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      controller.addListener(_onPlayerChanged);
      setState(() => _initialized = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (controller != null) {
      final value = controller.value;
      final position = value.position;
      final delta = (position - _lastReportedPosition).abs();
      if (delta >= const Duration(seconds: 1)) {
        _lastReportedPosition = position;
        widget.onProgress?.call(
          VideoPlaybackProgress(position: position, duration: value.duration),
        );
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null || url.isEmpty) {
      return VideoThumb(
        video: widget.video,
        radius: 0,
        big: true,
        showControls: false,
      );
    }

    final controller = _controller;
    if (!_initialized || controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            VideoThumb(video: widget.video, radius: 0, big: true),
            Container(color: Colors.black.withValues(alpha: 0.2)),
            Center(
              child: _failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.videocam_off_rounded,
                          color: Colors.white70,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Không phát được video',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () {
                            setState(() => _failed = false);
                            _initialize();
                          },
                          child: const Text('Thử lại'),
                        ),
                      ],
                    )
                  : const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    final value = controller.value;
    final aspect = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: GestureDetector(
          onTap: _togglePlay,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              if (!value.isPlaying)
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        colors: VideoProgressColors(
                          playedColor: const Color(0xFFE8112D),
                          bufferedColor: Colors.white.withValues(alpha: 0.35),
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: _togglePlay,
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát',
                            visualDensity: VisualDensity.compact,
                          ),
                          Text(
                            '${_format(value.position)} / ${_format(value.duration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              controller.setVolume(
                                controller.value.volume > 0 ? 0 : 1,
                              );
                              setState(() {});
                            },
                            icon: Icon(
                              controller.value.volume > 0
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            tooltip: controller.value.volume > 0
                                ? 'Tắt tiếng'
                                : 'Bật tiếng',
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            onPressed: () => _openFullScreen(context, controller),
                            icon: const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            tooltip: 'Toàn màn hình',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, VideoPlayerController controller) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => _FullScreenVideoPlayer(
          controller: controller,
          video: widget.video,
        ),
      ),
    );
  }

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Màn hình phát video toàn màn hình
class _FullScreenVideoPlayer extends StatefulWidget {
  const _FullScreenVideoPlayer({
    required this.controller,
    required this.video,
  });

  final VideoPlayerController controller;
  final Video video;

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
      } else {
        widget.controller.play();
      }
    });
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final value = controller.value;
    final aspect = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Center(
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: VideoPlayer(controller),
                ),
              ),
              if (!value.isPlaying && _showControls)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.55),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              // Top Bar
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          tooltip: 'Thoát toàn màn hình',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 24),
                          tooltip: 'Thu nhỏ',
                        ),
                      ],
                    ),
                  ),
                ),
              // Bottom Controls
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          colors: VideoProgressColors(
                            playedColor: const Color(0xFFE8112D),
                            bufferedColor: Colors.white.withValues(alpha: 0.35),
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: _togglePlay,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát',
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_fmt(value.position)} / ${_fmt(value.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                controller.setVolume(
                                  controller.value.volume > 0 ? 0 : 1,
                                );
                                setState(() {});
                              },
                              icon: Icon(
                                controller.value.volume > 0
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              tooltip: controller.value.volume > 0
                                  ? 'Tắt tiếng'
                                  : 'Bật tiếng',
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.fullscreen_exit_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: 'Thu nhỏ',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
