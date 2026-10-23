import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_scope.dart';
import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/category_bar.dart';
import '../widgets/data_state.dart';
import '../widgets/greeting_bar.dart';
import '../widgets/horizontal_drag_scroll.dart';
import '../widgets/top_bar.dart';
import '../widgets/trending_card.dart';
import '../widgets/video_card.dart';
import 'account_screen.dart';
import 'history_screen.dart';
import 'subscriptions_screen.dart';
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
  bool _loadingVideos = true;
  bool _refreshingVideos = false;
  String? _error;
  Timer? _refreshTimer;

  String _query = '';
  String _category = 'Tất cả';

  bool get _searching => _query.trim().isNotEmpty;

  bool get _usingSql => _remoteVideos != null;

  List<Video> get _allVideos => _remoteVideos ?? const <Video>[];

  List<Video> get _trending {
    final remote = _remoteVideos;
    if (remote == null || remote.isEmpty) return const <Video>[];
    final ordered = <Video>[
      ...remote.where((Video video) => video.isLive),
      ...remote.where((Video video) => !video.isLive),
    ];
    return ordered.take(4).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = widget.api ?? ApiClient();
    _loadVideos();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _refreshingVideos) return;
      unawaited(_loadVideos(silent: true));
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadVideos(silent: true));
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
      await _loadVideos();
    }
  }

  void _handleAction(String action) {
    switch (action) {
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
    final profile = AuthScope.maybeOf(context)?.profile;
    final String greetingName = profile == null
        ? 'kiepthan4'
        : (profile.name.isNotEmpty
              ? profile.name
              : (profile.userKey.isNotEmpty ? profile.userKey : 'bạn'));

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          TopBar(
            searchController: _searchController,
            onQueryChanged: (String value) {
              setState(() => _query = value);
            },
            onAction: _handleAction,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double pad = constraints.maxWidth < 700 ? 12 : 20;
                final double contentWidth = constraints.maxWidth - pad * 2;
                final int columns = (contentWidth / 268).floor().clamp(1, 6);
                const double gap = 16;
                final double cardWidth =
                    (contentWidth - gap * (columns - 1)) / columns;
                final List<Video> videos = _videos;
                final List<Video> trending = _trending;

                return Scrollbar(
                  controller: _scrollController,
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(pad, 14, pad, 48),
                    children: <Widget>[
                      GreetingBar(
                        name: greetingName,
                        onTap: () => _push(AccountScreen(api: _api)),
                      ),
                      if (!_searching && trending.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 18),
                        _SectionTitle(
                          title: 'Video xu hướng',
                          subtitle:
                              'Xếp hạng dựa trên Điểm Xu Hướng trực tiếp.',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 232,
                          child: HorizontalDragScroll(
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: trending.length,
                              separatorBuilder: (
                                BuildContext context,
                                int index,
                              ) => const SizedBox(width: 14),
                              itemBuilder: (BuildContext context, int index) {
                                final Video video = trending[index];
                                return TrendingCard(
                                  video: video,
                                  onTap: () => _openVideo(video),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Divider(color: p.border),
                        const SizedBox(height: 14),
                      ] else
                        const SizedBox(height: 16),
                      CategoryBar(
                        selected: _category,
                        onSelected: (String value) {
                          setState(() => _category = value);
                        },
                      ),
                      const SizedBox(height: 18),
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          _SourceBadge(
                            loading: _loadingVideos,
                            online: _usingSql,
                            onTap: _loadVideos,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_loadingVideos && _remoteVideos == null)
                        const DataLoading(message: 'Đang tải video từ Neon...')
                      else if (_error != null && _remoteVideos == null)
                        DataError(message: _error!, onRetry: _loadVideos)
                      else if (videos.isEmpty)
                        _EmptyState(onReset: _resetFilters)
                      else
                        Wrap(
                          spacing: gap,
                          runSpacing: 22,
                          children: <Widget>[
                            for (final Video video in videos)
                              SizedBox(
                                width: cardWidth,
                                child: VideoCard(
                                  video: video,
                                  onTap: () => _openVideo(video),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: p.textPrimary,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
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
