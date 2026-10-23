import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../data/tiktube_api.dart';
import '../models/comment.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/app_pill.dart';
import '../widgets/channel_avatar.dart';
import '../widgets/data_state.dart';
import '../widgets/section_top_bar.dart';
import '../widgets/video_surface.dart';
import '../widgets/video_thumb.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({
    super.key,
    required this.video,
    required this.api,
    this.related = const <Video>[],
  });

  final Video video;
  final TikTubeApi api;

  /// Danh sách để lấy video liên quan. Bỏ trống sẽ dùng dữ liệu mẫu.
  final List<Video> related;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  bool _subscribed = false;
  bool _liked = false;
  int _likeCount = 0;
  int _subscriberCount = 0;

  final TextEditingController _commentController = TextEditingController();
  final List<Comment> _comments = <Comment>[];
  bool _commentsLoading = true;
  String? _commentsError;

  @override
  void initState() {
    super.initState();
    _subscribed = widget.video.subscribed;
    _likeCount = widget.video.likeCount;
    _subscriberCount = widget.video.subscriberCount;
    unawaited(_loadComments());
    unawaited(_registerView());
  }

  Future<void> _loadComments() async {
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    try {
      final List<Comment> comments = await widget.api.fetchComments(
        widget.video.id,
      );
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(comments);
        _commentsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _commentsLoading = false;
        _commentsError = error.toString();
      });
    }
  }

  Future<void> _registerView() async {
    try {
      await widget.api.registerView(widget.video.id);
    } catch (_) {
      // Không chặn UI nếu API offline.
    }
  }

  Future<void> _syncLike(bool liked) async {
    try {
      final int likeCount = await widget.api.setLike(
        widget.video.id,
        liked: liked,
      );
      if (!mounted) return;
      setState(() => _likeCount = likeCount);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = !liked;
        _likeCount = (_likeCount + (liked ? -1 : 1)).clamp(0, 1 << 31);
      });
      _notify('Không cập nhật được lượt thích — kiểm tra API/Neon.');
    }
  }

  Future<void> _toggleSubscribe() async {
    final bool next = !_subscribed;
    final int previousCount = _subscriberCount;
    setState(() {
      _subscribed = next;
      _subscriberCount = (_subscriberCount + (next ? 1 : -1)).clamp(0, 1 << 31);
    });

    if (widget.video.channelId.isEmpty) return;
    try {
      final int count = await widget.api.setSubscription(
        widget.video.channelId,
        subscribed: next,
      );
      if (!mounted) return;
      setState(() => _subscriberCount = count);
      _notify(
        next
            ? 'Đã đăng ký kênh ${widget.video.channel}.'
            : 'Đã hủy đăng ký kênh ${widget.video.channel}.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscribed = !next;
        _subscriberCount = previousCount;
      });
      _notify('Không cập nhật được đăng ký — kiểm tra API/Neon.');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  String get _commentAuthor {
    final profile = AuthScope.maybeOf(context)?.profile;
    if (profile == null) return 'kiepthan4';
    return profile.name.isNotEmpty ? profile.name : profile.userKey;
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final String author = _commentAuthor;
    final optimistic = Comment(
      author: author,
      content: text,
      date: 'Hôm nay',
      own: true,
    );
    setState(() {
      _comments.insert(0, optimistic);
      _commentController.clear();
    });

    try {
      final Comment saved = await widget.api.addComment(
        widget.video.id,
        author: author,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        final int index = _comments.indexOf(optimistic);
        if (index >= 0) _comments[index] = saved;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _comments.remove(optimistic));
      _commentController.text = text;
      _notify('Không gửi được bình luận — kiểm tra API/Neon.');
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final int index = _comments.indexOf(comment);
    if (index < 0) return;

    setState(() => _comments.removeAt(index));
    _notify('Đã xoá bình luận.');

    final String? id = comment.id;
    if (id == null) return;

    try {
      await widget.api.deleteComment(widget.video.id, id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final int restoreAt = index.clamp(0, _comments.length);
        _comments.insert(restoreAt, comment);
      });
      _notify('Không xoá được bình luận — API đang offline.');
    }
  }

  void _toggleLike() {
    final bool next = !_liked;
    setState(() {
      _liked = next;
      _likeCount += next ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    unawaited(_syncLike(next));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final String commentAuthor = _commentAuthor;
    final List<Video> related = widget.related
        .where((Video v) => v.id != widget.video.id)
        .take(8)
        .toList();

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          SectionTopBar(
            title: 'Xem video',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth >= 900;
                  final bool compact = constraints.maxWidth < 700;
                  final double pad = compact ? 12 : 20;

                  final Widget main = _MainColumn(
                    video: widget.video,
                    subscribed: _subscribed,
                    subscriberCount: _subscriberCount,
                    liked: _liked,
                    likeCount: _likeCount,
                    comments: _comments,
                    commentsLoading: _commentsLoading,
                    commentsError: _commentsError,
                    commentController: _commentController,
                    currentUserName: commentAuthor,
                    onReloadComments: _loadComments,
                    onToggleSubscribe: _toggleSubscribe,
                    onToggleLike: _toggleLike,
                    onAddComment: _addComment,
                    onDeleteComment: _deleteComment,
                    onNotify: _notify,
                  );

                  final Widget sidebar = _RelatedList(
                    videos: related,
                    onTap: (Video video) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => WatchScreen(
                            video: video,
                            api: widget.api,
                            related: widget.related,
                          ),
                        ),
                      );
                    },
                  );

                  return Scrollbar(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: pad,
                        vertical: compact ? 10 : 16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(child: main),
                                    const SizedBox(width: 26),
                                    SizedBox(width: 356, child: sidebar),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    main,
                                    SizedBox(height: compact ? 18 : 26),
                                    sidebar,
                                  ],
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    required this.video,
    required this.subscribed,
    required this.subscriberCount,
    required this.liked,
    required this.likeCount,
    required this.comments,
    required this.commentsLoading,
    required this.commentsError,
    required this.commentController,
    required this.currentUserName,
    required this.onReloadComments,
    required this.onToggleSubscribe,
    required this.onToggleLike,
    required this.onAddComment,
    required this.onDeleteComment,
    required this.onNotify,
  });

  final Video video;
  final bool subscribed;
  final int subscriberCount;
  final bool liked;
  final int likeCount;
  final List<Comment> comments;
  final bool commentsLoading;
  final String? commentsError;
  final TextEditingController commentController;
  final String currentUserName;
  final VoidCallback onReloadComments;
  final VoidCallback onToggleSubscribe;
  final VoidCallback onToggleLike;
  final VoidCallback onAddComment;
  final ValueChanged<Comment> onDeleteComment;
  final ValueChanged<String> onNotify;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool compact = MediaQuery.sizeOf(context).width < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          child: Stack(
            children: <Widget>[
              VideoSurface(video: video),
              if (!video.isPlayable)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.42),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(20),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Video chưa có file Cloudinary',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Hãy tải video mới để phát trực tiếp.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: compact ? 12 : 14),
        Text(
          video.title,
          style: TextStyle(
            fontSize: compact ? 17.5 : 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: p.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            ChannelAvatar(video: video, size: compact ? 38 : 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    video.channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    video
                        .copyWith(subscriberCount: subscriberCount)
                        .subscriberLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppPill(
              label: subscribed ? 'Đã đăng ký' : 'Đăng ký',
              height: 32,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              gradient: subscribed ? null : p.ctaGradient,
              background: subscribed ? p.chip : null,
              foreground: subscribed ? p.textPrimary : Colors.white,
              onTap: onToggleSubscribe,
            ),
          ],
        ),
        SizedBox(height: compact ? 12 : 12),
        if (compact)
          _WatchActions(
            liked: liked,
            likeCount: likeCount,
            onToggleLike: onToggleLike,
            onShare: () => onNotify('Đã sao chép liên kết video.'),
            onDownload: () => onNotify('Đang chuẩn bị tải video...'),
            onReport: () => onNotify('Đã gửi báo cáo video.'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              AppPill(
                label: '$likeCount',
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                height: 32,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                background: p.surface,
                borderColor: p.border,
                foreground: liked ? p.brandRed : p.textPrimary,
                onTap: onToggleLike,
              ),
              AppPill(
                label: 'Chia sẻ',
                icon: Icons.ios_share_rounded,
                height: 32,
                fontSize: 11.5,
                background: p.surface,
                borderColor: p.border,
                onTap: () => onNotify('Đã sao chép liên kết video.'),
              ),
              AppPill(
                label: 'Tải xuống',
                icon: Icons.file_download_outlined,
                height: 32,
                fontSize: 11.5,
                background: p.surface,
                borderColor: p.border,
                onTap: () => onNotify('Đang chuẩn bị tải video...'),
              ),
              AppPill(
                label: 'Báo cáo',
                icon: Icons.flag_outlined,
                height: 32,
                fontSize: 11.5,
                background: p.surface,
                borderColor: p.border,
                foreground: p.brandRed,
                onTap: () => onNotify('Đã gửi báo cáo video.'),
              ),
            ],
          ),
        const SizedBox(height: 14),
        Text(
          '${video.viewsLabel} · ${video.date}',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: <Widget>[
            for (final String tag in video.tags)
              Text(
                '#$tag',
                style: TextStyle(
                  fontSize: 11,
                  color: p.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Divider(color: p.border),
        const SizedBox(height: 14),
        Text(
          'Bình luận',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CommentAvatar(author: currentUserName, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: commentController,
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => onAddComment(),
                style: TextStyle(fontSize: 12, color: p.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Viết bình luận...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: p.textSecondary.withValues(alpha: 0.8),
                  ),
                  contentPadding: const EdgeInsets.only(bottom: 6),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: p.border),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: p.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: p.textSecondary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: onAddComment,
              tooltip: 'Gửi bình luận',
              icon: Icon(Icons.send_rounded, size: 17, color: p.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (commentsLoading)
          const DataLoading(message: 'Đang tải bình luận từ Neon...')
        else if (commentsError != null)
          DataError(message: commentsError!, onRetry: onReloadComments)
        else ...<Widget>[
          if (comments.isEmpty)
            Text(
              'Chưa có bình luận nào. Hãy là người đầu tiên!',
              style: TextStyle(fontSize: 11.5, color: p.textSecondary),
            )
          else
            for (final Comment comment in comments) ...<Widget>[
              _CommentTile(
                comment: comment,
                onDelete: () => onDeleteComment(comment),
              ),
              const SizedBox(height: 14),
            ],
        ],
      ],
    );
  }
}

class _WatchActions extends StatelessWidget {
  const _WatchActions({
    required this.liked,
    required this.likeCount,
    required this.onToggleLike,
    required this.onShare,
    required this.onDownload,
    required this.onReport,
  });

  final bool liked;
  final int likeCount;
  final VoidCallback onToggleLike;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _WatchAction(
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: likeCount > 0 ? _shortCount(likeCount) : 'Thích',
              active: liked,
              onTap: onToggleLike,
            ),
          ),
          _ActionDivider(color: p.border),
          Expanded(
            child: _WatchAction(
              icon: Icons.ios_share_rounded,
              label: 'Chia sẻ',
              onTap: onShare,
            ),
          ),
          _ActionDivider(color: p.border),
          Expanded(
            child: _WatchAction(
              icon: Icons.file_download_outlined,
              label: 'Tải xuống',
              onTap: onDownload,
            ),
          ),
          _ActionDivider(color: p.border),
          Expanded(
            child: _WatchAction(
              icon: Icons.flag_outlined,
              label: 'Báo cáo',
              danger: true,
              onTap: onReport,
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchAction extends StatelessWidget {
  const _WatchAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color color = danger
        ? p.brandRed
        : active
        ? p.brandRed
        : p.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: danger ? p.brandRed : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 26, color: color);
  }
}

String _shortCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} Tr';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} N';
  }
  return '$value';
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onDelete});

  final Comment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CommentAvatar(author: comment.author, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    comment.author,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    comment.date,
                    style: TextStyle(fontSize: 9.5, color: p.textSecondary),
                  ),
                  const Spacer(),
                  if (comment.own)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Text(
                          'Xóa',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                comment.content,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.author, required this.size});

  final String author;
  final double size;

  @override
  Widget build(BuildContext context) {
    const List<List<Color>> gradients = <List<Color>>[
      <Color>[Color(0xFF4B4F63), Color(0xFF22242E)],
      <Color>[Color(0xFF7A5CC4), Color(0xFF4B3F8F)],
      <Color>[Color(0xFF2E6F7E), Color(0xFF12312E)],
      <Color>[Color(0xFFC2532F), Color(0xFF3B1A12)],
      <Color>[Color(0xFF6E8C5A), Color(0xFF3E5C3A)],
    ];
    final int index =
        author.codeUnits.fold<int>(0, (int sum, int c) => sum + c) %
        gradients.length;
    final String initial = author.isEmpty
        ? '?'
        : author.substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: gradients[index]),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _RelatedList extends StatelessWidget {
  const _RelatedList({required this.videos, required this.onTap});

  final List<Video> videos;
  final ValueChanged<Video> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Video liên quan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: p.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        for (final Video video in videos) ...<Widget>[
          _RelatedTile(video: video, onTap: () => onTap(video)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RelatedTile extends StatefulWidget {
  const _RelatedTile({required this.video, required this.onTap});

  final Video video;
  final VoidCallback onTap;

  @override
  State<_RelatedTile> createState() => _RelatedTileState();
}

class _RelatedTileState extends State<_RelatedTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool compact = MediaQuery.sizeOf(context).width < 700;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _hovered ? p.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hovered ? p.border : Colors.transparent),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: compact ? 120 : 136,
                child: VideoThumb(
                  video: widget.video,
                  radius: 5,
                  showControls: false,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.video.channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.video.viewsLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: p.textSecondary),
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
