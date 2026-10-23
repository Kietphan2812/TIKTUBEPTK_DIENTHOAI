import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tiktube_api.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tab_pill.dart';
import '../widgets/category_bar.dart';
import '../widgets/data_state.dart';
import '../widgets/mobile_segmented_tabs.dart';
import '../widgets/section_top_bar.dart';
import '../widgets/video_thumb.dart';
import 'account_screen.dart';
import 'watch_screen.dart';

/// Bảng xếp hạng video thịnh hành.
///
/// Điểm xu hướng do API tính bằng SQL từ dữ liệu Neon thật. Màn hình chỉ hiển
/// thị kết quả, đổi cửa sổ thời gian và lọc theo danh mục.
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key, required this.api, this.initialCategory});

  final TikTubeApi api;
  final String? initialCategory;

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  late final TikTubeApi _api;
  List<Video> _videos = const <Video>[];
  int _days = 7;
  String _category = 'Tất cả';
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _loadId = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = widget.api;
    final String? initial = widget.initialCategory?.trim();
    if (initial != null && initial.isNotEmpty) _category = initial;
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _refreshing) return;
      unawaited(_load(silent: true));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_refreshing) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _load({bool silent = false}) async {
    final int loadId = ++_loadId;
    _refreshing = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final List<Video> videos = await _api.fetchTrendingVideos(
        limit: 30,
        days: _days,
        category: _category == 'Tất cả' ? null : _category,
      );
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _videos = videos;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    } finally {
      if (loadId == _loadId) _refreshing = false;
    }
  }

  void _selectDays(int days) {
    if (_days == days) return;
    setState(() => _days = days);
    unawaited(_load());
  }

  void _selectCategory(String category) {
    if (_category == category) return;
    setState(() => _category = category);
    unawaited(_load());
  }

  void _goHome() =>
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

  void _openAccount() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => AccountScreen(api: _api)));
  }

  Future<void> _openVideo(Video video) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WatchScreen(video: video, api: _api, related: _videos),
      ),
    );
    if (mounted) unawaited(_load(silent: true));
  }

  String get _windowLabel => _days == 1 ? '24 giờ' : '$_days ngày';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool compact = MediaQuery.sizeOf(context).width < 700;
    final double pad = compact ? 12 : 20;

    final Widget list = ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        pad,
        compact ? 14 : 20,
        pad,
        compact ? 28 : 48,
      ),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Video đang thịnh hành',
                            style: TextStyle(
                              fontSize: compact ? 22 : 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: p.textPrimary,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Xếp hạng từ dữ liệu Neon · cập nhật mỗi 10 giây',
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _refreshing ? null : _load,
                      tooltip: 'Làm mới bảng xu hướng',
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: p.textPrimary,
                        size: 21,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 16),
                _AlgorithmCard(windowLabel: _windowLabel),
                SizedBox(height: compact ? 14 : 18),
                Text(
                  'Khoảng thời gian',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 7),
                if (compact)
                  MobileSegmentedTabs(
                    labels: const <String>['Hôm nay', '7 ngày', '30 ngày'],
                    selectedIndex: _days == 1
                        ? 0
                        : _days == 7
                        ? 1
                        : 2,
                    onChanged: (int index) {
                      _selectDays(<int>[1, 7, 30][index]);
                    },
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      AppTabPill(
                        label: 'HÔM NAY',
                        selected: _days == 1,
                        onTap: () => _selectDays(1),
                      ),
                      AppTabPill(
                        label: '7 NGÀY',
                        selected: _days == 7,
                        onTap: () => _selectDays(7),
                      ),
                      AppTabPill(
                        label: '30 NGÀY',
                        selected: _days == 30,
                        onTap: () => _selectDays(30),
                      ),
                    ],
                  ),
                SizedBox(height: compact ? 10 : 14),
                CategoryBar(selected: _category, onSelected: _selectCategory),
                SizedBox(height: compact ? 12 : 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_videos.length} video · $_windowLabel',
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                    if (_refreshing)
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: p.brandRed,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 9 : 12),
                if (_loading && _videos.isEmpty)
                  const DataLoading(
                    message: 'Đang tính điểm xu hướng từ Neon...',
                  )
                else if (_error != null && _videos.isEmpty)
                  DataError(message: _error!, onRetry: _load)
                else if (_videos.isEmpty)
                  _EmptyTrending(days: _days)
                else
                  Column(
                    children: <Widget>[
                      for (int index = 0; index < _videos.length; index++) ...[
                        _TrendingRow(
                          video: _videos[index],
                          rank: index + 1,
                          windowLabel: _windowLabel,
                          compact: compact,
                          onTap: () => _openVideo(_videos[index]),
                        ),
                        if (index != _videos.length - 1)
                          const SizedBox(height: 9),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          SectionTopBar(
            title: 'Xu hướng',
            onBack: () => Navigator.of(context).maybePop(),
            onHome: _goHome,
            onAccount: _openAccount,
            onSearch: _goHome,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: compact
                  ? RefreshIndicator(
                      color: p.brandRed,
                      onRefresh: _load,
                      child: list,
                    )
                  : Scrollbar(controller: _scrollController, child: list),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlgorithmCard extends StatelessWidget {
  const _AlgorithmCard({required this.windowLabel});

  final String windowLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: p.brandRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_graph_rounded, size: 18, color: p.brandRed),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Điểm xu hướng kết hợp lượt xem, lượt thích, bình luận, '
              'số người xem duy nhất trong $windowLabel, quy mô kênh và độ '
              'mới của video. Cùng một video có thể tăng hoặc giảm hạng khi '
              'chọn khoảng thời gian khác.',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: p.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({
    required this.video,
    required this.rank,
    required this.windowLabel,
    required this.compact,
    required this.onTap,
  });

  final Video video;
  final int rank;
  final String windowLabel;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool topThree = rank <= 3;

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(compact ? 9 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: compact ? 25 : 32,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 17 : 21,
                    fontWeight: FontWeight.w900,
                    color: topThree ? p.brandRed : p.textSecondary,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              SizedBox(
                width: compact ? 94 : 144,
                child: VideoThumb(video: video, radius: 8, showControls: false),
              ),
              SizedBox(width: compact ? 9 : 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12.5 : 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      video.channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 10.5 : 11.5,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${video.viewsLabel} · ${video.recentViewsLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 9.5 : 10.5,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: compact ? 12 : 14,
                          color: p.brandRed,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${video.trendScoreLabel} · $windowLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 9.5 : 10.5,
                              fontWeight: FontWeight.w700,
                              color: p.brandRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!compact) ...<Widget>[
                const SizedBox(width: 10),
                _ScorePill(score: video.trendScore, rank: rank),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.rank});

  final int score;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: rank <= 3 ? p.brandRed.withValues(alpha: 0.08) : p.chip,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: rank <= 3 ? p.brandRed.withValues(alpha: 0.28) : p.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$score',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: rank <= 3 ? p.brandRed : p.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'ĐIỂM',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrending extends StatelessWidget {
  const _EmptyTrending({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.local_fire_department_outlined,
            size: 34,
            color: p.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có video nào nổi bật',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Khoảng ${days == 1 ? '24 giờ' : '$days ngày'} hiện chưa có video '
            'nổi bật. Thử chọn khoảng thời gian dài hơn hoặc danh mục khác. '
            'Bảng xếp hạng dùng dữ liệu xem và tương tác thật từ Neon.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
