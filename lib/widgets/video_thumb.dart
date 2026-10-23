import 'package:flutter/material.dart';

import '../models/video.dart';

/// Thumbnail video mô phỏng trình phát: nền gradient, nhãn LIVE,
/// thanh điều khiển (play, thời lượng, âm lượng, toàn màn hình, menu).
class VideoThumb extends StatelessWidget {
  const VideoThumb({
    super.key,
    required this.video,
    this.radius = 8,
    this.big = false,
    this.showControls = true,
  });

  final Video video;
  final double radius;
  final bool big;
  final bool showControls;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (video.thumbnailUrl != null)
              Image.network(
                video.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) =>
                    _Backdrop(colors: video.colors),
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? progress,
                ) {
                  if (progress == null) return child;
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _Backdrop(colors: video.colors),
                      const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              _Backdrop(colors: video.colors),
            if (video.thumbnailUrl != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.12),
                    ],
                  ),
                ),
              ),
            if (video.isLive)
              Positioned(
                top: big ? 14 : 8,
                right: big ? 14 : 8,
                child: _LiveBadge(big: big),
              ),
            if (showControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ControlBar(video: video, big: big),
              ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            left: -30,
            top: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: -40,
            bottom: -60,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.2,
                colors: <Color>[
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.28),
                ],
                stops: const <double>[0.55, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.big});

  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: big ? 9 : 6,
        vertical: big ? 3 : 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8112D),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: big ? 12 : 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.video, required this.big});

  final Video video;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool showIcons = big || width >= 175;
        final double iconSize = big ? 20 : 13;
        final double gap = big ? 10 : 6;
        final double horizontal = big ? 14 : 8;
        final double timeFont = big ? 13 : (width < 120 ? 9 : 10.5);

        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            big ? 18 : 12,
            horizontal,
            big ? 10 : 7,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.transparent,
                Colors.black.withValues(alpha: 0.78),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.play_arrow_rounded,
                    size: iconSize + 3,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '0:00 / ${video.durationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: timeFont,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (showIcons) ...<Widget>[
                    const Spacer(),
                    _barIcon(Icons.volume_up_rounded, iconSize),
                    SizedBox(width: gap),
                    _barIcon(Icons.fullscreen_rounded, iconSize),
                    SizedBox(width: gap),
                    _barIcon(Icons.more_vert_rounded, iconSize),
                  ],
                ],
              ),
              SizedBox(height: big ? 8 : 5),
              SizedBox(
                height: big ? 3.5 : 2.5,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: big ? 26 : 8,
                        height: double.infinity,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _barIcon(IconData icon, double size) {
    return Icon(icon, size: size, color: Colors.white.withValues(alpha: 0.92));
  }
}
