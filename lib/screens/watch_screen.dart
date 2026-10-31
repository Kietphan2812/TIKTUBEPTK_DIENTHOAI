import 'dart:async';

import 'package:flutter/material.dart';
import 'chat_screen.dart';

import '../auth/auth_scope.dart';
import '../data/tiktube_api.dart';
import '../models/comment.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
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

class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver {
  bool _subscribed = false;
  bool _liked = false;
  bool _disliked = false;
  int _likeCount = 0;
  int _subscriberCount = 0;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final List<Comment> _comments = <Comment>[];
  Comment? _replyingTo;
  final Set<String> _expandedReplyIds = <String>{};
  bool _commentsLoading = true;
  String? _commentsError;

  Timer? _progressTimer;
  int _watchedSeconds = 0;
  int _durationSeconds = 0;
  int _lastSavedSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribed = widget.video.subscribed;
    _likeCount = widget.video.likeCount;
    _subscriberCount = widget.video.subscriberCount;
    _durationSeconds = widget.video.duration.inSeconds;
    unawaited(_loadComments());
    unawaited(_registerView());
    _progressTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveWatchProgress(),
    );
  }

  void _handlePlaybackProgress(VideoPlaybackProgress progress) {
    final int position = progress.position.inSeconds;
    final int duration = progress.duration.inSeconds;
    if (position > _watchedSeconds) _watchedSeconds = position;
    if (duration > 0) _durationSeconds = duration;
  }

  void _saveWatchProgress({bool force = false}) {
    final int watched = _watchedSeconds;
    if (watched <= 0) return;
    if (!force && watched < _lastSavedSeconds + 5) return;
    _lastSavedSeconds = watched;
    final int duration = _durationSeconds > 0
        ? _durationSeconds
        : widget.video.duration.inSeconds;
    unawaited(_persistWatchProgress(watched, duration));
  }

  Future<void> _persistWatchProgress(int watched, int duration) async {
    try {
      await widget.api.recordWatchProgress(
        widget.video.id,
        watchedSeconds: watched,
        durationSeconds: duration,
      );
    } catch (_) {
      // Không chặn việc xem video nếu API tạm thời không phản hồi.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveWatchProgress(force: true);
    }
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

  List<Comment> _getStructuredComments() {
    final Map<String, List<Comment>> repliesMap = <String, List<Comment>>{};
    final Set<String> rootIds = <String>{};
    final List<Comment> roots = <Comment>[];
    final List<Comment> potentialOrphans = <Comment>[];

    for (final Comment c in _comments) {
      if (c.parentId != null && c.parentId!.isNotEmpty) {
        repliesMap.putIfAbsent(c.parentId!, () => <Comment>[]).add(c);
        potentialOrphans.add(c);
      } else {
        if (c.id != null) rootIds.add(c.id!);
        roots.add(c);
      }
    }

    final List<Comment> structured = <Comment>[];
    for (final Comment root in roots) {
      final List<Comment> children = repliesMap[root.id] ?? <Comment>[];
      final List<Comment> allReplies = <Comment>[...root.replies];
      final Set<String?> existingIds = allReplies.map((e) => e.id).toSet();
      for (final child in children) {
        if (child.id == null || !existingIds.contains(child.id)) {
          allReplies.add(child);
        }
      }
      structured.add(root.copyWith(replies: allReplies));
    }

    for (final orphan in potentialOrphans) {
      if (!rootIds.contains(orphan.parentId)) {
        structured.add(orphan);
      }
    }

    return structured;
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
    _progressTimer?.cancel();
    _saveWatchProgress(force: true);
    WidgetsBinding.instance.removeObserver(this);
    _commentController.dispose();
    _commentFocusNode.dispose();
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

  void _startReply(Comment comment) {
    setState(() {
      _replyingTo = comment;
      if (comment.id != null) {
        _expandedReplyIds.add(comment.id!);
      }
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _toggleReplies(String commentId) {
    setState(() {
      if (_expandedReplyIds.contains(commentId)) {
        _expandedReplyIds.remove(commentId);
      } else {
        _expandedReplyIds.add(commentId);
      }
    });
  }

  void _toggleCommentLike(Comment comment) {
    setState(() {
      final int idx = _comments.indexWhere(
        (c) => c == comment || (c.id != null && c.id == comment.id),
      );
      if (idx >= 0) {
        final current = _comments[idx];
        final bool next = !current.liked;
        _comments[idx] = current.copyWith(
          liked: next,
          likes: (current.likes + (next ? 1 : -1)).clamp(0, 1 << 31),
        );
      }
    });
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final String author = _commentAuthor;
    final Comment? replyParent = _replyingTo;
    final String? parentId = replyParent?.id;

    final String contentToSend = parentId != null && parentId.isNotEmpty
        ? '[reply:$parentId] $text'
        : text;

    final optimistic = Comment(
      author: author,
      content: text,
      date: 'Hôm nay',
      own: true,
      parentId: parentId,
    );
    setState(() {
      _comments.insert(0, optimistic);
      _commentController.clear();
      if (parentId != null) {
        _expandedReplyIds.add(parentId);
      }
      _replyingTo = null;
    });

    try {
      final Comment saved = await widget.api.addComment(
        widget.video.id,
        author: author,
        content: contentToSend,
      );
      if (!mounted) return;
      setState(() {
        final int index = _comments.indexOf(optimistic);
        if (index >= 0) {
          _comments[index] = saved.copyWith(
            parentId: parentId,
            content: text,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _comments.remove(optimistic));
      _commentController.text = text;
      _notify('Không gửi được bình luận — kiểm tra API/Neon.');
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final int index = _comments.indexWhere(
      (c) => c == comment || (c.id != null && c.id == comment.id),
    );
    if (index < 0) return;

    final removed = _comments.removeAt(index);
    setState(() {});
    _notify('Đã xoá bình luận.');

    final String? id = comment.id;
    if (id == null) return;

    try {
      await widget.api.deleteComment(widget.video.id, id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final int restoreAt = index.clamp(0, _comments.length);
        _comments.insert(restoreAt, removed);
      });
      _notify('Không xoá được bình luận — API đang offline.');
    }
  }

  void _toggleLike() {
    final bool next = !_liked;
    setState(() {
      _liked = next;
      if (next) _disliked = false;
      _likeCount += next ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    unawaited(_syncLike(next));
  }

  void _toggleDislike() {
    setState(() {
      _disliked = !_disliked;
      if (_disliked && _liked) {
        _liked = false;
        _likeCount = (_likeCount - 1).clamp(0, 1 << 31);
        unawaited(_syncLike(false));
      }
    });
  }

  List<Video> _relatedVideos() {
    final Set<String> currentTags = widget.video.tags
        .map((String tag) => tag.toLowerCase())
        .toSet();
    final List<Video> candidates = widget.related
        .where((Video video) => video.id != widget.video.id)
        .toList();

    int score(Video video) {
      var value = 0;
      if (video.category == widget.video.category) value += 6;
      if (video.channelId.isNotEmpty &&
          video.channelId == widget.video.channelId) {
        value += 3;
      } else if (video.channel == widget.video.channel) {
        value += 3;
      }
      for (final String tag in video.tags) {
        if (currentTags.contains(tag.toLowerCase())) value += 2;
      }
      return value;
    }

    candidates.sort((Video a, Video b) {
      final int byType = score(b).compareTo(score(a));
      if (byType != 0) return byType;
      final int byViews = b.views.compareTo(a.views);
      if (byViews != 0) return byViews;
      return b.id.compareTo(a.id);
    });
    return candidates.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final String commentAuthor = _commentAuthor;
    final List<Video> related = _relatedVideos();

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
                    disliked: _disliked,
                    likeCount: _likeCount,
                    comments: _getStructuredComments(),
                    commentsLoading: _commentsLoading,
                    commentsError: _commentsError,
                    commentController: _commentController,
                    commentFocusNode: _commentFocusNode,
                    replyingTo: _replyingTo,
                    expandedReplyIds: _expandedReplyIds,
                    currentUserName: commentAuthor,
                    onReloadComments: _loadComments,
                    onToggleSubscribe: _toggleSubscribe,
                    onToggleLike: _toggleLike,
                    onToggleDislike: _toggleDislike,
                    onAddComment: _addComment,
                    onDeleteComment: _deleteComment,
                    onStartReply: _startReply,
                    onCancelReply: _cancelReply,
                    onToggleReplies: _toggleReplies,
                    onToggleCommentLike: _toggleCommentLike,
                    onNotify: _notify,
                    onProgress: _handlePlaybackProgress,
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
    required this.disliked,
    required this.likeCount,
    required this.comments,
    required this.commentsLoading,
    required this.commentsError,
    required this.commentController,
    required this.commentFocusNode,
    required this.replyingTo,
    required this.expandedReplyIds,
    required this.currentUserName,
    required this.onReloadComments,
    required this.onToggleSubscribe,
    required this.onToggleLike,
    required this.onToggleDislike,
    required this.onAddComment,
    required this.onDeleteComment,
    required this.onStartReply,
    required this.onCancelReply,
    required this.onToggleReplies,
    required this.onToggleCommentLike,
    required this.onNotify,
    required this.onProgress,
  });

  final Video video;
  final bool subscribed;
  final int subscriberCount;
  final bool liked;
  final bool disliked;
  final int likeCount;
  final List<Comment> comments;
  final bool commentsLoading;
  final String? commentsError;
  final TextEditingController commentController;
  final FocusNode commentFocusNode;
  final Comment? replyingTo;
  final Set<String> expandedReplyIds;
  final String currentUserName;
  final VoidCallback onReloadComments;
  final VoidCallback onToggleSubscribe;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleDislike;
  final VoidCallback onAddComment;
  final ValueChanged<Comment> onDeleteComment;
  final ValueChanged<Comment> onStartReply;
  final VoidCallback onCancelReply;
  final ValueChanged<String> onToggleReplies;
  final ValueChanged<Comment> onToggleCommentLike;
  final ValueChanged<String> onNotify;
  final ValueChanged<VideoPlaybackProgress> onProgress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool compact = MediaQuery.sizeOf(context).width < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Cố định tỷ lệ khung video 16:9, video mọi kích cỡ nằm vừa vặn bên trong không đổi layout
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 8 : 12),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                VideoSurface(video: video, onProgress: onProgress),
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
        // Thanh Kênh & Nút Hành động kiểu YouTube
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
                      fontSize: compact ? 13.5 : 14,
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
                    style: TextStyle(
                      fontSize: compact ? 10.5 : 11,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _SubscribeButton(
              subscribed: subscribed,
              onTap: onToggleSubscribe,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _YouTubeActionBar(
          liked: liked,
          disliked: disliked,
          likeCount: likeCount,
          onToggleLike: onToggleLike,
          onToggleDislike: onToggleDislike,
          onNotify: onNotify,
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
        // Banner thông báo đang phản hồi
        if (replyingTo != null) ...<Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: p.chip,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.reply_rounded,
                  size: 16,
                  color: Color(0xFF065FD4),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Đang phản hồi @${replyingTo!.author}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onCancelReply,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CommentAvatar(author: currentUserName, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: commentController,
                focusNode: commentFocusNode,
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => onAddComment(),
                style: TextStyle(fontSize: 12, color: p.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: replyingTo != null
                      ? 'Viết phản hồi cho @${replyingTo!.author}...'
                      : 'Viết bình luận...',
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
                onReply: () => onStartReply(comment),
                onLike: () => onToggleCommentLike(comment),
                isExpanded:
                    comment.id != null && expandedReplyIds.contains(comment.id),
                onToggleReplies: comment.id != null
                    ? () => onToggleReplies(comment.id!)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ],
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({
    required this.subscribed,
    required this.onTap,
  });

  final bool subscribed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: subscribed
              ? p.chip
              : (isDark ? Colors.white : const Color(0xFF0F0F0F)),
          border: subscribed ? Border.all(color: p.border) : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (subscribed) ...<Widget>[
              Icon(
                Icons.check_rounded,
                size: 15,
                color: p.textPrimary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              subscribed ? 'Đã đăng ký' : 'Đăng ký',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: subscribed
                    ? p.textPrimary
                    : (isDark ? Colors.black : Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YouTubeActionBar extends StatelessWidget {
  const _YouTubeActionBar({
    required this.liked,
    required this.disliked,
    required this.likeCount,
    required this.onToggleLike,
    required this.onToggleDislike,
    required this.onNotify,
  });

  final bool liked;
  final bool disliked;
  final int likeCount;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleDislike;
  final ValueChanged<String> onNotify;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _YouTubeLikeDislikePill(
            liked: liked,
            disliked: disliked,
            likeCount: likeCount,
            onToggleLike: onToggleLike,
            onToggleDislike: onToggleDislike,
          ),
          const SizedBox(width: 8),
          _YouTubePillButton(
            icon: Icons.reply_rounded,
            label: 'Chia sẻ',
            onTap: () => onNotify('Đã sao chép liên kết video.'),
          ),
          const SizedBox(width: 8),
          _YouTubePillButton(
            icon: Icons.auto_awesome,
            label: 'Đặt câu hỏi',
            onTap: () => onNotify('Trợ lý AI TIKTUBE đã sẵn sàng hỗ trợ.'),
          ),
          const SizedBox(width: 8),
          _YouTubePillButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Nhắn tin',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChatScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _YouTubePillButton(
            icon: Icons.download_rounded,
            label: 'Tải xuống',
            onTap: () => onNotify('Đang chuẩn bị tải video về máy...'),
          ),
          const SizedBox(width: 8),
          _YouTubeCircleButton(
            icon: Icons.more_horiz_rounded,
            onTap: () => _showMoreSheet(context, onNotify),
          ),
        ],
      ),
    );
  }
}

class _YouTubeLikeDislikePill extends StatelessWidget {
  const _YouTubeLikeDislikePill({
    required this.liked,
    required this.disliked,
    required this.likeCount,
    required this.onToggleLike,
    required this.onToggleDislike,
  });

  final bool liked;
  final bool disliked;
  final int likeCount;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleDislike;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: p.chip,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: onToggleLike,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                    size: 18,
                    color: liked ? p.brandRed : p.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    likeCount > 0 ? _shortCount(likeCount) : 'Thích',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: liked ? p.brandRed : p.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 18,
            color: p.border,
          ),
          InkWell(
            onTap: onToggleDislike,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                disliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                size: 18,
                color: disliked ? p.brandRed : p.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YouTubePillButton extends StatelessWidget {
  const _YouTubePillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: p.chip,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: p.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YouTubeCircleButton extends StatelessWidget {
  const _YouTubeCircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: p.chip,
          shape: BoxShape.circle,
          border: Border.all(color: p.border.withValues(alpha: 0.5)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: p.textPrimary),
      ),
    );
  }
}

void _showMoreSheet(BuildContext context, ValueChanged<String> onNotify) {
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
              ListTile(
                leading: Icon(Icons.flag_outlined, color: p.brandRed),
                title: Text(
                  'Báo cáo vi phạm',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.brandRed,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onNotify('Đã gửi báo cáo video vi phạm.');
                },
              ),
              ListTile(
                leading: Icon(Icons.link_rounded, color: p.textPrimary),
                title: Text(
                  'Sao chép liên kết',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onNotify('Đã sao chép liên kết video.');
                },
              ),
              ListTile(
                leading: Icon(Icons.tune_rounded, color: p.textPrimary),
                title: Text(
                  'Chất lượng (Tự động 1080p)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onNotify('Đang phát ở độ phân giải cao nhất.');
                },
              ),
              ListTile(
                leading: Icon(Icons.speed_rounded, color: p.textPrimary),
                title: Text(
                  'Tốc độ phát lại (Chuẩn 1.0x)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onNotify('Tốc độ chuẩn 1.0x.');
                },
              ),
            ],
          ),
        ),
      );
    },
  );
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
  const _CommentTile({
    required this.comment,
    required this.onDelete,
    required this.onReply,
    required this.onLike,
    this.isReply = false,
    this.isExpanded = false,
    this.onToggleReplies,
  });

  final Comment comment;
  final VoidCallback onDelete;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final bool isReply;
  final bool isExpanded;
  final VoidCallback? onToggleReplies;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final double avatarSize = isReply ? 24 : 32;

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 38 : 0,
        bottom: isReply ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CommentAvatar(author: comment.author, size: avatarSize),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          comment.author.startsWith('@')
                              ? comment.author
                              : '@${comment.author}',
                          style: TextStyle(
                            fontSize: isReply ? 11 : 12,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          comment.date,
                          style: TextStyle(
                            fontSize: isReply ? 9.5 : 10,
                            color: p.textSecondary,
                          ),
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
                                  fontSize: 10,
                                  color: p.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.content,
                      style: TextStyle(
                        fontSize: isReply ? 12 : 12.5,
                        height: 1.35,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Action row under comment: 👍 Like, 👎 Dislike, Phản hồi
                    Row(
                      children: <Widget>[
                        InkWell(
                          onTap: onLike,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  comment.liked
                                      ? Icons.thumb_up_rounded
                                      : Icons.thumb_up_outlined,
                                  size: 14,
                                  color: comment.liked
                                      ? p.brandRed
                                      : p.textSecondary,
                                ),
                                if (comment.likes > 0) ...<Widget>[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${comment.likes}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: comment.liked
                                          ? p.brandRed
                                          : p.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {},
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Icon(
                              Icons.thumb_down_outlined,
                              size: 14,
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: onReply,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              'Phản hồi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: p.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Reply toggle row if has replies
          if (!isReply && comment.replies.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: InkWell(
                onTap: onToggleReplies,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        isExpanded
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        color: const Color(0xFF065FD4),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpanded
                            ? 'Thu gọn'
                            : '${comment.replies.length} phản hồi',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065FD4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // List of nested replies
          if (!isReply && isExpanded && comment.replies.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            for (final Comment reply in comment.replies)
              _CommentTile(
                comment: reply,
                isReply: true,
                onDelete: onDelete,
                onReply: onReply,
                onLike: onLike,
              ),
          ],
        ],
      ),
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
