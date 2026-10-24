import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_scope.dart';
import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/app_notification.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_comments_sheet.dart';
import '../widgets/quick_watch_page.dart';
import '../widgets/video_surface.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';
import 'trending_screen.dart';
import 'upload_choice_sheet.dart';

enum QuickWatchFeed { following, friends, forYou }

/// Feed xem nhanh toàn màn hình, vuốt dọc và tự phát video đang hiển thị.
///
/// Ba tab lấy dữ liệu thật từ Neon:
/// - Đã follow: video mới từ kênh đã đăng ký.
/// - Bạn bè: kênh người dùng đã thích/bình luận/xem gần đây.
/// - Dành cho bạn: feed cá nhân hóa + tín hiệu xu hướng.
class QuickWatchScreen extends StatefulWidget {
  const QuickWatchScreen({
    super.key,
    required this.api,
    this.initialVideos = const <Video>[],
  });

  final TikTubeApi api;

  /// Video đã có từ trang chủ, dùng làm nội dung hiển thị ngay trong lúc feed
  /// cá nhân hóa đang được xếp hạng lại từ Neon.
  final List<Video> initialVideos;

  @override
  State<QuickWatchScreen> createState() => _QuickWatchScreenState();
}

class _QuickWatchScreenState extends State<QuickWatchScreen>
    with WidgetsBindingObserver {
  static const List<QuickWatchFeed> _feedOrder = <QuickWatchFeed>[
    QuickWatchFeed.following,
    QuickWatchFeed.friends,
    QuickWatchFeed.forYou,
  ];

  final Map<QuickWatchFeed, List<Video>> _feeds =
      <QuickWatchFeed, List<Video>>{};
  final Map<QuickWatchFeed, bool> _loading = <QuickWatchFeed, bool>{};
  final Map<QuickWatchFeed, String?> _errors = <QuickWatchFeed, String?>{};
  final Map<QuickWatchFeed, int> _requests = <QuickWatchFeed, int>{};
  final Map<String, VideoPlaybackProgress> _progress =
      <String, VideoPlaybackProgress>{};
  final Map<String, int> _savedProgress = <String, int>{};
  final Set<String> _viewed = <String>{};

  late PageController _pageController;
  QuickWatchFeed _selected = QuickWatchFeed.forYou;
  int _index = 0;
  bool _userScrolled = false;
  bool _muted = kIsWeb;

  Timer? _notificationTimer;
  Timer? _bannerTimer;
  Timer? _progressTimer;
  final Set<String> _knownNotificationIds = <String>{};
  bool _notificationsPrimed = false;
  bool _notificationsLoading = false;
  int _unread = 0;
  AppNotification? _banner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    if (widget.initialVideos.isNotEmpty) {
      _feeds[QuickWatchFeed.forYou] = List<Video>.of(widget.initialVideos);
    }
    unawaited(_loadFeed(QuickWatchFeed.forYou));
    unawaited(_loadNotifications(initial: true));
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _loadNotifications(),
    );
    _progressTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _persistCurrentProgress(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewCurrent();
      _persistCurrentProgress();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistCurrentProgress(force: true);
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_loadNotifications());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persistCurrentProgress(force: true);
    _notificationTimer?.cancel();
    _bannerTimer?.cancel();
    _progressTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<Video> get _videos =>
      _feeds[_selected] ?? const <Video>[];

  Video? get _currentVideo {
    final List<Video> videos = _videos;
    if (_index < 0 || _index >= videos.length) return null;
    return videos[_index];
  }

  Future<void> _loadFeed(QuickWatchFeed feed) async {
    if (_loading[feed] == true) return;
    final int request = (_requests[feed] ?? 0) + 1;
    _requests[feed] = request;
    setState(() {
      _loading[feed] = true;
      _errors[feed] = null;
    });

    try {
      List<Video> videos = const <Video>[];
      switch (feed) {
        case QuickWatchFeed.forYou:
          try {
            final feedData = await widget.api.fetchForYouFeed(
              limit: 40,
              days: 30,
            );
            videos = feedData.videos;
            if (videos.length < 12) {
              try {
                final trending = await widget.api.fetchTrendingVideos(
                  limit: 20,
                  days: 7,
                );
                videos = _mergeUnique(videos, trending);
              } catch (_) {
                // Feed cá nhân hóa vẫn dùng được nếu riêng xu hướng lỗi.
              }
            }
          } catch (_) {
            videos = await widget.api.fetchTrendingVideos(
              limit: 30,
              days: 7,
            );
          }
          break;
        case QuickWatchFeed.following:
          videos = await widget.api.fetchSubscriptionFeed(limit: 40);
          break;
        case QuickWatchFeed.friends:
          try {
            videos = await widget.api.fetchFriendsFeed(limit: 40);
          } catch (_) {
            videos = const <Video>[];
          }
          if (videos.isEmpty) {
            try {
              videos = await widget.api.fetchSubscriptionFeed(limit: 20);
            } catch (_) {
              videos = const <Video>[];
            }
          }
          if (videos.isEmpty) {
            videos = await widget.api.fetchTrendingVideos(limit: 20, days: 7);
          }
          break;
      }

      if (!mounted || _requests[feed] != request) return;

      final List<Video> existing = _feeds[feed] ?? const <Video>[];
      final List<Video> next = existing.isEmpty || !_userScrolled
          ? videos
          : _mergeUnique(existing, videos);

      setState(() {
        _feeds[feed] = List<Video>.of(next);
        _errors[feed] = null;
      });
      if (_selected == feed) _viewCurrent();
    } catch (error) {
      if (!mounted || _requests[feed] != request) return;
      final String message = _friendlyError(error);
      setState(() {
        if ((_feeds[feed] ?? const <Video>[]).isEmpty) {
          _errors[feed] = message;
        }
      });
    } finally {
      if (mounted && _requests[feed] == request) {
        setState(() => _loading[feed] = false);
      }
    }
  }

  void _selectFeed(QuickWatchFeed feed) {
    if (_selected == feed) return;
    _persistCurrentProgress(force: true);
    setState(() {
      _selected = feed;
      _index = 0;
      _userScrolled = false;
      _banner = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _viewCurrent();
    });
    if ((_feeds[feed] ?? const <Video>[]).isEmpty &&
        _loading[feed] != true) {
      unawaited(_loadFeed(feed));
    }
  }

  void _onPageChanged(int index) {
    _persistCurrentProgress(force: true);
    setState(() {
      _index = index;
      _userScrolled = true;
    });
    _viewCurrent();
  }

  void _viewCurrent() {
    final Video? video = _currentVideo;
    if (video != null) _viewVideo(video);
  }

  void _viewVideo(Video video) {
    if (video.id.isEmpty || !_viewed.add(video.id)) return;
    unawaited(
      widget.api.registerView(video.id).catchError((Object _) {}),
    );
  }

  void _onProgress(Video video, VideoPlaybackProgress progress) {
    _progress[video.id] = progress;
  }

  void _persistCurrentProgress({bool force = false}) {
    final Video? video = _currentVideo;
    if (video == null) return;
    _persistVideoProgress(video, force: force);
  }

  void _persistVideoProgress(Video video, {bool force = false}) {
    final VideoPlaybackProgress? progress = _progress[video.id];
    if (progress == null) return;
    final int seconds = progress.position.inSeconds;
    if (seconds <= 0) return;
    final int lastSaved = _savedProgress[video.id] ?? 0;
    if (!force && seconds < lastSaved + 5) return;
    final int duration = progress.duration.inSeconds > 0
        ? progress.duration.inSeconds
        : video.duration.inSeconds;
    if (duration <= 0) return;
    _savedProgress[video.id] = seconds;
    unawaited(
      widget.api
          .recordWatchProgress(
            video.id,
            watchedSeconds: seconds,
            durationSeconds: duration,
          )
          .catchError((Object _) {}),
    );
  }

  Future<void> _toggleLike(Video target) async {
    final Video current = _findVideo(target.id) ?? target;
    final bool next = !current.liked;
    final int optimistic = (current.likeCount + (next ? 1 : -1))
        .clamp(0, 1 << 30)
        .toInt();
    _updateVideo(
      current.id,
      (Video video) => video.copyWith(liked: next, likeCount: optimistic),
    );
    try {
      final int count = await widget.api.setLike(current.id, liked: next);
      _updateVideo(
        current.id,
        (Video video) => video.copyWith(liked: next, likeCount: count),
      );
    } catch (error) {
      _updateVideo(
        current.id,
        (Video video) => video.copyWith(
          liked: current.liked,
          likeCount: current.likeCount,
        ),
      );
      _showSnack('Không cập nhật được lượt thích: ${_friendlyError(error)}');
    }
  }

  Future<void> _toggleSave(Video target) async {
    final Video current = _findVideo(target.id) ?? target;
    final bool next = !current.saved;
    _updateVideo(
      current.id,
      (Video video) => video.copyWith(saved: next),
    );
    try {
      await widget.api.setSaved(current.id, saved: next);
      _showSnack(next ? 'Đã lưu video vào bộ sưu tập.' : 'Đã bỏ lưu video.');
    } catch (error) {
      _updateVideo(
        current.id,
        (Video video) => video.copyWith(saved: current.saved),
      );
      _showSnack('Không lưu được video: ${_friendlyError(error)}');
    }
  }

  Future<void> _toggleFollow(Video target) async {
    final Video current = _findVideo(target.id) ?? target;
    if (current.channelId.isEmpty) return;
    final bool next = !current.subscribed;
    _updateWhere(
      (Video video) => video.channelId == current.channelId,
      (Video video) => video.copyWith(
        subscribed: next,
        subscriberCount: (video.subscriberCount + (next ? 1 : -1))
            .clamp(0, 1 << 30)
            .toInt(),
      ),
    );
    try {
      final int count = await widget.api.setSubscription(
        current.channelId,
        subscribed: next,
      );
      _updateWhere(
        (Video video) => video.channelId == current.channelId,
        (Video video) => video.copyWith(subscriberCount: count),
      );
      _showSnack(next ? 'Đã theo dõi kênh.' : 'Đã bỏ theo dõi kênh.');
    } catch (error) {
      _updateWhere(
        (Video video) => video.channelId == current.channelId,
        (Video video) => video.copyWith(
          subscribed: current.subscribed,
          subscriberCount: current.subscriberCount,
        ),
      );
      _showSnack('Không cập nhật được kênh: ${_friendlyError(error)}');
    }
  }

  Future<void> _openComments(Video target) async {
    final Video current = _findVideo(target.id) ?? target;
    final String author =
        AuthScope.maybeOf(context)?.profile?.name.trim() ?? '';
    await showQuickCommentsSheet(
      context,
      api: widget.api,
      video: current,
      author: author.isEmpty ? 'Bạn' : author,
      onCountChanged: (int count) {
        _updateVideo(
          current.id,
          (Video video) => video.copyWith(commentCount: count),
        );
      },
    );
  }

  void _share(Video target) {
    final Video current = _findVideo(target.id) ?? target;
    final String fallbackBase = widget.api is ApiClient
        ? (widget.api as ApiClient).baseUrl
        : 'https://tiktube-api.onrender.com';
    final String link = (current.videoUrl ?? '').trim().isNotEmpty
        ? current.videoUrl!
        : '$fallbackBase/api/videos/${current.id}';
    final String description =
        '${current.title} — ${current.channel} trên TIKTUBE';

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (BuildContext sheetContext) {
        final p = context.palette;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              ListTile(
                leading: Icon(Icons.link_rounded, color: p.brandRed),
                title: Text(
                  'Sao chép liên kết video',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textSecondary, fontSize: 10.5),
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  _showSnack('Đã sao chép liên kết video.');
                },
              ),
              ListTile(
                leading: Icon(Icons.notes_rounded, color: p.textSecondary),
                title: Text(
                  'Sao chép mô tả',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textSecondary, fontSize: 10.5),
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: description));
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  _showSnack('Đã sao chép mô tả video.');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(api: widget.api),
      ),
    );
    if (!mounted) return;
    unawaited(_loadNotifications());
  }

  Future<void> _openTrending() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrendingScreen(api: widget.api),
      ),
    );
    if (!mounted) return;
    unawaited(_loadFeed(_selected));
  }

  Future<void> _openAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountScreen(api: widget.api),
      ),
    );
  }

  Future<void> _openUpload() async {
    final bool uploaded = await openUploadFlow(context, api: widget.api);
    if (!mounted || !uploaded) return;
    unawaited(_loadFeed(_selected));
  }

  Future<void> _loadNotifications({bool initial = false}) async {
    if (_notificationsLoading) return;
    _notificationsLoading = true;
    try {
      final List<AppNotification> items =
          await widget.api.fetchNotifications();
      if (!mounted) return;
      final List<AppNotification> unseen =
          items.where((AppNotification item) => !item.seen).toList();
      final List<AppNotification> fresh = items
          .where((AppNotification item) => !_knownNotificationIds.contains(item.id))
          .toList();

      if (!_notificationsPrimed || initial) {
        _knownNotificationIds.addAll(
          items.map((AppNotification item) => item.id),
        );
        _notificationsPrimed = true;
      } else if (fresh.isNotEmpty) {
        _knownNotificationIds.addAll(
          fresh.map((AppNotification item) => item.id),
        );
        AppNotification? newest;
        for (final AppNotification item in fresh) {
          if (!item.seen) {
            newest = item;
            break;
          }
        }
        if (newest != null) _showBanner(newest);
      }

      setState(() => _unread = unseen.length);
    } catch (_) {
      // Polling lỗi mạng không được làm gián đoạn video đang phát.
    } finally {
      _notificationsLoading = false;
    }
  }

  void _showBanner(AppNotification notification) {
    _bannerTimer?.cancel();
    setState(() => _banner = notification);
    _bannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  AppNotification? get _bannerNotification => _banner;

  Video? _findVideo(String id) {
    for (final List<Video> videos in _feeds.values) {
      for (final Video video in videos) {
        if (video.id == id) return video;
      }
    }
    return null;
  }

  void _updateVideo(String id, Video Function(Video video) transform) {
    if (!mounted) return;
    setState(() {
      for (final List<Video> videos in _feeds.values) {
        for (int index = 0; index < videos.length; index += 1) {
          if (videos[index].id == id) {
            videos[index] = transform(videos[index]);
          }
        }
      }
    });
  }

  void _updateWhere(
    bool Function(Video video) matches,
    Video Function(Video video) transform,
  ) {
    if (!mounted) return;
    setState(() {
      for (final List<Video> videos in _feeds.values) {
        for (int index = 0; index < videos.length; index += 1) {
          if (matches(videos[index])) {
            videos[index] = transform(videos[index]);
          }
        }
      }
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;
    final double width = MediaQuery.sizeOf(context).width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: <Widget>[
            Positioned.fill(child: _buildContent()),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _buildTopBar(topInset, width),
            ),
            if (_bannerNotification != null)
              Positioned(
                left: 12,
                right: 12,
                top: topInset + 58,
                child: _NotificationBanner(
                  notification: _bannerNotification!,
                  onTap: () {
                    setState(() => _banner = null);
                    unawaited(_openNotifications());
                  },
                  onClose: () => setState(() => _banner = null),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _QuickBottomNav(
                onHome: () => Navigator.of(context).maybePop(),
                onDiscover: _openTrending,
                onUpload: _openUpload,
                onInbox: _openNotifications,
                onMe: _openAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(double topInset, double width) {
    return Container(
      padding: EdgeInsets.fromLTRB(2, topInset + 2, 2, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.32),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: Colors.white,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _feedOrder.map((QuickWatchFeed feed) {
                return _FeedTab(
                  label: _feedLabel(feed),
                  selected: _selected == feed,
                  onTap: () => _selectFeed(feed),
                );
              }).toList(),
            ),
          ),
          IconButton(
            tooltip: 'Làm mới feed',
            onPressed: _loading[_selected] == true
                ? null
                : () => unawaited(_loadFeed(_selected)),
            icon: _loading[_selected] == true
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            color: Colors.white,
          ),
          _NotificationBell(
            key: const ValueKey<String>('quick-watch-notifications'),
            unread: _unread,
            onTap: _openNotifications,
          ),
          if (width >= 420)
            IconButton(
              tooltip: 'Tìm kiếm',
              onPressed: () => _showSnack(
                'Dùng ô tìm kiếm ở trang chủ để tìm video.',
              ),
              icon: const Icon(Icons.search_rounded, size: 21),
              color: Colors.white,
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final List<Video> videos = _videos;
    if (videos.isEmpty) {
      final bool loading = _loading[_selected] == true;
      final String? error = _errors[_selected];
      if (loading) {
        return const _FeedState(
          icon: Icons.auto_awesome_rounded,
          title: 'Đang xếp hạng video từ Neon...',
          subtitle: 'Feed cá nhân hóa, xu hướng và kênh đã đăng ký.',
          loading: true,
        );
      }
      if (error != null) {
        return _FeedState(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được feed',
          subtitle: error,
          actionLabel: 'Thử lại',
          onAction: () => unawaited(_loadFeed(_selected)),
        );
      }
      switch (_selected) {
        case QuickWatchFeed.following:
          return _FeedState(
            icon: Icons.subscriptions_outlined,
            title: 'Chưa có video từ kênh bạn đăng ký',
            subtitle:
                'Hãy theo dõi thêm kênh hoặc khám phá feed Dành cho bạn.',
            actionLabel: 'Xem Dành cho bạn',
            onAction: () => _selectFeed(QuickWatchFeed.forYou),
          );
        case QuickWatchFeed.friends:
          return _FeedState(
            icon: Icons.people_outline_rounded,
            title: 'Chưa đủ tương tác để tạo feed Bạn bè',
            subtitle:
                'Thích, bình luận hoặc xem video của một kênh để kênh đó xuất hiện tại đây.',
            actionLabel: 'Xem Dành cho bạn',
            onAction: () => _selectFeed(QuickWatchFeed.forYou),
          );
        case QuickWatchFeed.forYou:
          return _FeedState(
            icon: Icons.video_library_outlined,
            title: 'Chưa có video phù hợp',
            subtitle: 'Thử làm mới feed hoặc quay lại sau khi có video mới.',
            actionLabel: 'Thử lại',
            onAction: () => unawaited(_loadFeed(_selected)),
          );
      }
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: videos.length,
      itemBuilder: (BuildContext context, int index) {
        final Video video = videos[index];
        return QuickWatchPage(
          key: ValueKey<String>('${_selected.name}-${video.id}'),
          video: video,
          active: index == _index,
          muted: _muted,
          onLike: () => unawaited(_toggleLike(video)),
          onComment: () => unawaited(_openComments(video)),
          onSave: () => unawaited(_toggleSave(video)),
          onShare: () => _share(video),
          onFollow: () => unawaited(_toggleFollow(video)),
          onToggleMute: () => setState(() => _muted = !_muted),
          onProgress: (VideoPlaybackProgress progress) {
            _onProgress(video, progress);
          },
          onRegisterView: () => _viewVideo(video),
        );
      },
    );
  }

  String _feedLabel(QuickWatchFeed feed) {
    switch (feed) {
      case QuickWatchFeed.following:
        return 'Đã follow';
      case QuickWatchFeed.friends:
        return 'Bạn bè';
      case QuickWatchFeed.forYou:
        return 'Dành cho bạn';
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }

  static List<Video> _mergeUnique(List<Video> first, List<Video> second) {
    final List<Video> merged = <Video>[...first];
    final Set<String> seen = first.map((Video video) => video.id).toSet();
    for (final Video video in second) {
      if (seen.add(video.id)) merged.add(video);
    }
    return merged;
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: selected ? 1 : 0.64),
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  shadows: const <Shadow>[
                    Shadow(blurRadius: 5, color: Colors.black45),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 20 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({super.key, required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: unread > 0 ? 'Thông báo ($unread chưa đọc)' : 'Thông báo',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 23,
              ),
              if (unread > 0)
                Positioned(
                  top: 6,
                  right: 5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFE2C55),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
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

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({
    required this.notification,
    required this.onTap,
    required this.onClose,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: const Color(0xF21A1A1D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFFE2C55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Thông báo mới',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Đóng thông báo',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickBottomNav extends StatelessWidget {
  const _QuickBottomNav({
    required this.onHome,
    required this.onDiscover,
    required this.onUpload,
    required this.onInbox,
    required this.onMe,
  });

  final VoidCallback onHome;
  final VoidCallback onDiscover;
  final VoidCallback onUpload;
  final VoidCallback onInbox;
  final VoidCallback onMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.92),
          ],
        ),
        border: const Border(
          top: BorderSide(color: Color(0x22FFFFFF)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 61,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Row(
                children: <Widget>[
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Trang chủ',
                    onTap: onHome,
                  ),
                  _NavItem(
                    icon: Icons.explore_outlined,
                    label: 'Khám phá',
                    onTap: onDiscover,
                  ),
                  Expanded(
                    child: Center(
                      child: Tooltip(
                        message: 'Đăng video',
                        child: InkResponse(
                          onTap: onUpload,
                          radius: 28,
                          child: Container(
                            width: 43,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF25F4EE),
                                  Color(0xFFFE2C55),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.inbox_outlined,
                    label: 'Hộp thư',
                    onTap: onInbox,
                  ),
                  _NavItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Tôi',
                    onTap: onMe,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 23),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedState extends StatelessWidget {
  const _FeedState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF111827), Color(0xFF050507)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 90, 28, 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (loading)
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              else
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(icon, color: Colors.white, size: 29),
                ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFE2C55),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
