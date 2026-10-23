import 'package:flutter/material.dart';

import '../models/video.dart';
import '../theme/app_theme.dart';
import 'channel_avatar.dart';
import 'video_thumb.dart';

/// Card lớn cho mục "Video xu hướng".
class TrendingCard extends StatefulWidget {
  const TrendingCard({super.key, required this.video, required this.onTap});

  final Video video;
  final VoidCallback onTap;

  @override
  State<TrendingCard> createState() => _TrendingCardState();
}

class _TrendingCardState extends State<TrendingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 252,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? p.textSecondary.withValues(alpha: 0.35)
                  : p.border,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: p.shadow,
                blurRadius: _hovered ? 18 : 10,
                offset: Offset(0, _hovered ? 6 : 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              VideoThumb(
                video: widget.video,
                radius: 0,
                showControls: widget.video.isPlayable,
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ChannelAvatar(video: widget.video, size: 34),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.video.channel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: p.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.video.viewsLabel} · ${widget.video.date}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
