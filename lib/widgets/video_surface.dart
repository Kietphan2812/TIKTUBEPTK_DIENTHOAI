import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/video.dart';
import 'video_thumb.dart';

/// Trình phát thật cho video Cloudinary; tự quay về thumbnail gradient nếu
/// video không có URL hoặc trình duyệt không phát được.
class VideoSurface extends StatefulWidget {
  const VideoSurface({super.key, required this.video});

  final Video video;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;

  String? get _url => widget.video.videoUrl;

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
        aspectRatio: aspect,
        child: GestureDetector(
          onTap: _togglePlay,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(
                color: Colors.black,
                child: Center(child: VideoPlayer(controller)),
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

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
