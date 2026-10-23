import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/app_notification.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/category_bar.dart';
import '../widgets/data_state.dart';
import '../widgets/horizontal_drag_scroll.dart';
import '../widgets/top_bar.dart';
import '../widgets/trending_card.dart';
import '../widgets/video_card.dart';
import 'account_screen.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'subscriptions_screen.dart';
import 'trending_screen.dart';
import 'upload_screen.dart';
import 'watch_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.api});

  /// Bỏ trống để dùng REST API thật (`ApiClient`).
  final TikTubeApi? api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final TikTubeApi _api;
  List<Video>? _remoteVideos;
  List<Video> _trendingVideos = const <Video>[];
  bool _loadingVideos = true;
  bool _refreshingVideos = false;
  bool _loadingTrending = true;
  bool _loadingNotifications = false;
  int _unreadNotifications = 0;
  String? _error;
  String? _trendingError;
  int _trendingLoadId = 0;
  Timer? _refreshTimer;

  String _query = '';
  String _category = 'Tất cả';

  bool get _searching => _query.trim().isNotEmpty;

  bool get _usingSql => _remoteVideos != null;

  List<Video> get _allVideos => _remoteVideos ?? const <Video>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = widget.api ?? ApiClient();
    _loadVideos();
    unawaited(_loadTrending());
    unawaited(_loadUnreadNotifications());
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      if (!_refreshingVideos) unawaited(_loadVideos(silent: true));
      unawaited(_loadTrending(silent: true));
      unawaited(_loadUnreadNotifications());
    });
  }

  /// Tải lại danh sách video. `silent` dùng cho polling nền để video mới đăng
  /// từ web xuất hiện mà không làm nhấp nháy màn hình.
  Future<void> _loadVideos({bool silent = false}) async {
    if (_refreshingVideos) return;
    _refreshingVideos = true;
    final bool hadData = _remoteVideos != null;
    if (!silent) {
      setState(() {
        _loadingVideos = true;
        _error = null;
      });
    }
    try {
      final List<Video> videos = await _api.fetchVideos();
      if (!mounted) return;
      setState(() {
        _remoteVideos = videos;
        _loadingVideos = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('Không tải được video từ API Neon: $error');
      if (!silent) {
        setState(() {
          _loadingVideos = false;
          _error = error.toString();
        });
        if (hadData) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Không tải được video mới — giữ dữ liệu đã tải.'),
                duration: Duration(seconds: 2),
              ),
            );
        }
      }
    } finally {
      _refreshingVideos = false;
    }
  }

  /// Tải bảng xếp hạng xu hướng từ API. Bảng này được tính riêng bằng SQL
  /// (lượt xem, tương tác, nhịp xem gần đây và độ mới) nên không phụ thuộc vào
  /// danh sách "Video mới" đang hiển thị.
  Future<void> _loadTrending({bool silent = false}) async {
    final int loadId = ++_trendingLoadId;
    final String? category = _category == 'Tất cả' ? null : _category;
    if (!silent) {
      setState(() {
        _loadingTrending = true;
        _trendingError = null;
      });
    }
    try {
      final List<Video> videos = await _api.fetchTrendingVideos(
        limit: 8,
        days: 7,
        category: category,
      );
      if (!mounted || loadId != _trendingLoadId) return;
      setState(() {
        _trendingVideos = videos;
        _loadingTrending = false;
        _trendingError = null;
      });
    } catch (error) {
      if (!mounted || loadId != _trendingLoadId) return;
      debugPrint('Không tải được bảng xu hướng từ API Neon: $error');
      setState(() {
        _loadingTrending = false;
        _trendingError = error.toString();
      });
    }
  }

  /// Cập nhật số thông báo chưa đọc cho badge trên chuông. Lỗi mạng được bỏ
  /// qua để không làm phiền người dùng khi đang xem feed.
  Future<void> _loadUnreadNotifications() async {
    if (_loadingNotifications) return;
    _loadingNotifications = true;
    try {
      final List<AppNotification> items = await _api.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _unreadNotifications = items
            .where((AppNotification item) => !item.seen)
            .length;
      });
    } catch (_) {
      // Giữ badge cũ nếu API tạm thời không phản hồi.
    } finally {
      _loadingNotifications = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadVideos(silent: true));
      unawaited(_loadTrending(silent: true));
      unawaited(_loadUnreadNotifications());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Video> get _videos {
    final keyword = _query.trim().toLowerCase();
    return _allVideos.where((Video video) {
      final matchCategory =
          _category == 'Tất cả' || video.category == _category;
      final matchKeyword =
          keyword.isEmpty ||
          video.title.toLowerCase().contains(keyword) ||
          video.channel.toLowerCase().contains(keyword) ||
          video.category.toLowerCase().contains(keyword);
      return matchCategory && matchKeyword;
    }).toList();
  }

  void _openVideo(Video video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            WatchScreen(video: video, api: _api, related: _allVideos),
      ),
    );
  }

  void _notify(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$action — tính năng đang được xây dựng.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _push(Widget screen) {
    _openScreen(screen);
  }

  Future<void> _openScreen(Widget screen) async {
    final bool? result = await Navigator.of(context)
        .push<bool>(MaterialPageRoute<bool>(builder: (_) => screen));
    if (result == true && mounted) {
      await Future.wait<void>(<Future<void>>[_loadVideos(), _loadTrending()]);
    }
  }

  Future<void> _openTrending() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrendingScreen(
          api: _api,
          initialCategory: _category == 'Tất cả' ? null : _category,
        ),
      ),
    );
    if (mounted) unawaited(_loadTrending(silent: true));
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NotificationsScreen(api: _api)),
    );
    if (mounted) unawaited(_loadUnreadNotifications());
  }

  void _handleAction(String action) {
    switch (action) {
      case 'Thông báo':
        unawaited(_openNotifications());
        return;
      case 'Đăng Video':
        _push(UploadScreen(api: _api));
        return;
      case 'Lịch sử':
        _push(HistoryScreen(api: _api));
        return;
      case 'Đăng ký':
        _push(SubscriptionsScreen(api: _api));
        return;
      case 'Tài khoản':
        _push(AccountScreen(api: _api));
        return;
      case 'Trang chủ':
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
        return;
      default:
        _notify(action);
        return;
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = 'Tất cả';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final bool isMobile = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: <Widget>[
            TopBar(
              searchController: _searchController,
              onQueryChanged: (String value) {
                setState(() => _query = value);
              },
              onAction: _handleAction,
              unreadNotifications: _unreadNotifications,
            ),
            if (isMobile)
              _MobileSearchBar(
                controller: _searchController,
                onChanged: (String value) {
                  setState(() => _query = value);
                },
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compact = constraints.maxWidth < 700;
                  final double pad = compact ? 12 : 20;
                  final double contentWidth = constraints.maxWidth - pad * 2;
                  final int columns = compact
                      ? 1
                      : (contentWidth / 268).floor().clamp(1, 6);
                  const double gap = 16;
                  final double cardWidth =
                      (contentWidth - gap * (columns - 1)) / columns;
                  final List<Video> videos = _videos;
                  final List<Video> trending = _trendingVideos;

                  final Widget list = ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      compact ? 12 : 14,
                      pad,
                      compact ? 24 : 48,
                    ),
                    children: <Widget>[
                      if (!_searching &&
                          (_loadingTrending ||
                              _trendingError != null ||
                              trending.isNotEmpty)) ...<Widget>[
                        SizedBox(height: compact ? 14 : 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: _SectionTitle(
                                title: 'Video xu hướng',
                                subtitle: 'Điểm xu hướng · 7 ngày',
                                compact: compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Xem tất cả video xu hướng',
                              child: TextButton(
                                onPressed: _openTrending,
                                style: TextButton.styleFrom(
                                  foregroundColor: p.brandRed,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 6 : 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      compact ? 'Xem bảng' : 'Xem tất cả',
                                      style: TextStyle(
                                        fontSize: compact ? 11 : 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: compact ? 16 : 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 10 : 12),
                        if (trending.isNotEmpty)
                          SizedBox(
                            height: compact ? 206 : 232,
                            child: HorizontalDragScroll(
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: trending.length,
                                separatorBuilder: (
                                  BuildContext context,
                                  int index,
                                ) => SizedBox(width: compact ? 10 : 14),
                                itemBuilder: (BuildContext context, int index) {
                                  final Video video = trending[index];
                                  return TrendingCard(
                                    video: video,
                                    rank: index + 1,
                                    compact: compact,
                                    onTap: () => _openVideo(video),
                                  );
                                },
                              ),
                            ),
                          )
                        else if (_loadingTrending)
                          _TrendingStatus(
                            loading: true,
                            message: 'Đang tính điểm xu hướng từ Neon...',
                            onRetry: () => unawaited(_loadTrending()),
                          )
                        else
                          _TrendingStatus(
                            loading: false,
                            message: 'Chưa tải được bảng xu hướng.',
                            onRetry: () => unawaited(_loadTrending()),
                          ),
                        SizedBox(height: compact ? 14 : 18),
                        Divider(color: p.border),
                        SizedBox(height: compact ? 12 : 14),
                      ] else
                        SizedBox(height: compact ? 12 : 16),
                      CategoryBar(
                        selected: _category,
                        onSelected: (String value) {
                          setState(() => _category = value);
                          unawaited(_loadTrending());
                        },
                      ),
                      SizedBox(height: compact ? 14 : 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: _SectionTitle(
                              title: _searching
                                  ? 'Kết quả cho “${_query.trim()}”'
                                  : 'Video mới',
                              subtitle: _searching
                                  ? '${videos.length} video phù hợp'
                                  : null,
                              compact: compact,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _SourceBadge(
                            loading: _loadingVideos,
                            online: _usingSql,
                            onTap: _loadVideos,
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      if (_loadingVideos && _remoteVideos == null)
                        const DataLoading(message: 'Đang tải video từ Neon...')
                      else if (_error != null && _remoteVideos == null)
                        DataError(message: _error!, onRetry: _loadVideos)
                      else if (videos.isEmpty)
                        _EmptyState(onReset: _resetFilters)
                      else
                        Wrap(
                          spacing: gap,
                          runSpacing: compact ? 14 : 22,
                          children: <Widget>[
                            for (final Video video in videos)
                              SizedBox(
                                width: cardWidth,
                                child: VideoCard(
                                  video: video,
                                  compact: compact,
                                  onTap: () => _openVideo(video),
                                ),
                              ),
                          ],
                        ),
                    ],
                  );

                  if (!compact) {
                    return Scrollbar(
                      controller: _scrollController,
                      child: list,
                    );
                  }

                  return RefreshIndicator(
                    color: p.brandRed,
                    onRefresh: () async {
                      await Future.wait<void>(<Future<void>>[
                        _loadVideos(),
                        _loadTrending(),
                      ]);
                    },
                    child: list,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isMobile
          ? _MobileBottomNav(onTap: _handleAction)
          : null,
    );
  }
}

class _TrendingStatus extends StatelessWidget {
  const _TrendingStatus({
    required this.loading,
    required this.message,
    required this.onRetry,
  });

  final bool loading;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          if (loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.brandRed,
              ),
            )
          else
            Icon(Icons.trending_up_rounded, size: 18, color: p.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11.5, color: p.textSecondary),
            ),
          ),
          if (!loading)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: p.brandRed,
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Tải lại',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 19 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: compact ? -0.25 : -0.4,
            color: p.textPrimary,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          SizedBox(height: compact ? 3 : 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: compact ? 11.5 : 12.5,
              color: p.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({
    required this.loading,
    required this.online,
    required this.onTap,
  });

  final bool loading;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Tooltip(
      message: loading
          ? 'Đang tải dữ liệu từ Neon...'
          : online
          ? 'Nguồn dữ liệu Neon. Bấm để tải lại.'
          : 'Không tải được dữ liệu. Bấm để thử lại.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: loading ? null : onTap,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: p.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (loading)
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: p.textSecondary,
                    ),
                  )
                else
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? const Color(0xFF3BB273) : p.textSecondary,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  online
                      ? 'Neon SQL'
                      : loading
                      ? 'Đang tải...'
                      : 'Chưa kết nối',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: p.textSecondary,
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

class _MobileSearchBar extends StatelessWidget {
  const _MobileSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool hasText = controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 11),
            Icon(Icons.search_rounded, size: 20, color: p.textSecondary),
            const SizedBox(width: 7),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: onChanged,
                textInputAction: TextInputAction.search,
                cursorColor: p.brandRed,
                style: TextStyle(fontSize: 13, color: p.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Tìm video, kênh, danh mục...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: p.textSecondary.withValues(alpha: 0.9),
                  ),
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            if (hasText)
              IconButton(
                onPressed: onClear,
                tooltip: 'Xoá tìm kiếm',
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: p.textSecondary,
                ),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: p.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: p.shadow,
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: <Widget>[
                _MobileNavButton(
                  icon: Icons.home_rounded,
                  label: 'Trang chủ',
                  active: true,
                  onTap: () => onTap('Trang chủ'),
                ),
                _MobileNavButton(
                  icon: Icons.subscriptions_outlined,
                  label: 'Đăng ký',
                  onTap: () => onTap('Đăng ký'),
                ),
                _MobileUploadButton(onTap: () => onTap('Đăng Video')),
                _MobileNavButton(
                  icon: Icons.history_rounded,
                  label: 'Lịch sử',
                  onTap: () => onTap('Lịch sử'),
                ),
                _MobileNavButton(
                  icon: Icons.person_outline_rounded,
                  label: 'Tài khoản',
                  onTap: () => onTap('Tài khoản'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavButton extends StatelessWidget {
  const _MobileNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = active ? p.brandRed : p.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileUploadButton extends StatelessWidget {
  const _MobileUploadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: p.ctaGradient),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: p.brandPink.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 23,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Đăng',
              style: TextStyle(
                fontSize: 9.5,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.search_off_rounded, size: 40, color: p.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Không tìm thấy video phù hợp',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thử từ khoá khác hoặc chọn lại danh mục.',
            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.textPrimary,
              side: BorderSide(color: p.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Xoá bộ lọc'),
          ),
        ],
      ),
    );
  }
}
