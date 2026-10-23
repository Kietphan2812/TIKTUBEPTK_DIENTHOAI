import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/creator_stats.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/data_state.dart';
import '../widgets/section_top_bar.dart';
import '../widgets/video_thumb.dart';
import 'account_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, this.api});

  final TikTubeApi? api;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final TikTubeApi _api;
  CreatorStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiClient();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final CreatorStats stats = await _api.fetchStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _goHome(BuildContext context) =>
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

  void _openAccount(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => AccountScreen(api: _api)));
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _copyCsv() async {
    final stats = _stats;
    if (stats == null) return;
    final buffer = StringBuffer('id,title,views,likes,comments\n');
    for (final Video video in stats.topVideos) {
      final title = video.title.replaceAll('"', '""');
      buffer.writeln(
        '"${video.id}","$title",${video.views},'
        '${video.likeCount},${video.commentCount}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    _notify(context, 'Đã sao chép CSV thống kê vào clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool isMobile = MediaQuery.sizeOf(context).width < 700;

    final CreatorStats? stats = _stats;
    final List<DailyViews> daily = stats?.daily ?? const <DailyViews>[];
    final int maxDaily = daily.fold<int>(
      1,
      (int max, DailyViews item) => item.views > max ? item.views : max,
    );
    final List<double> factors = daily
        .map(
          (DailyViews item) =>
              item.views <= 0 ? 0.03 : (item.views / maxDaily).clamp(0.06, 1.0),
        )
        .toList();
    final List<String> labels = daily
        .map((DailyViews item) => _weekdayLabel(item.date))
        .toList();
    final List<Video> videos = stats?.topVideos ?? const <Video>[];

    String compact(int value) => _formatCompact(value);

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          SectionTopBar(
            title: 'Thống kê',
            onBack: () => Navigator.of(context).maybePop(),
            onHome: () => _goHome(context),
            onAccount: () => _openAccount(context),
            onSearch: () => _goHome(context),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 14 : 20,
                  isMobile ? 14 : 20,
                  isMobile ? 14 : 20,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Thống Kê Video',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Số liệu thật từ Neon: video, lượt xem, lượt thích và bình luận',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: p.textSecondary,
                          ),
                        ),
                        SizedBox(height: isMobile ? 14 : 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: p.border),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: p.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Dữ liệu được tính trực tiếp từ Neon Postgres, cập nhật ngay khi có lượt xem mới.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 14 : 16),
                        if (_loading)
                          const DataLoading(
                            message: 'Đang tính thống kê từ Neon...',
                          )
                        else if (_error != null)
                          DataError(message: _error!, onRetry: _load)
                        else if (stats != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              LayoutBuilder(
                                builder:
                                    (
                                      BuildContext context,
                                      BoxConstraints constraints,
                                    ) {
                                      final int columns =
                                          constraints.maxWidth >= 700 ? 4 : 2;
                                      const double gap = 10;
                                      final double cardWidth =
                                          (constraints.maxWidth -
                                              gap * (columns - 1)) /
                                          columns;
                                      final List<Widget> cards = <Widget>[
                                        _StatCard(
                                          label: 'Tổng lượt xem',
                                          value: compact(stats.views),
                                          icon: Icons.visibility_outlined,
                                          compact: isMobile,
                                        ),
                                        _StatCard(
                                          label: 'Lượt thích',
                                          value: compact(stats.likes),
                                          icon: Icons.favorite_border_rounded,
                                          compact: isMobile,
                                        ),
                                        _StatCard(
                                          label: 'Bình luận',
                                          value: compact(stats.comments),
                                          icon:
                                              Icons.chat_bubble_outline_rounded,
                                          compact: isMobile,
                                        ),
                                        _StatCard(
                                          label: 'Video đã đăng',
                                          value: compact(stats.videos),
                                          icon: Icons.video_library_outlined,
                                          compact: isMobile,
                                        ),
                                      ];
                                      return Wrap(
                                        spacing: gap,
                                        runSpacing: gap,
                                        children: <Widget>[
                                          for (final Widget card in cards)
                                            SizedBox(
                                              width: cardWidth,
                                              child: card,
                                            ),
                                        ],
                                      );
                                    },
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(isMobile ? 14 : 18),
                                decoration: BoxDecoration(
                                  color: p.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: p.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Lượt xem 7 ngày gần nhất',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 148,
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: <Widget>[
                                          for (
                                            int i = 0;
                                            i < factors.length;
                                            i++
                                          )
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: <Widget>[
                                                    Container(
                                                      height: 118 * factors[i],
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                              begin: Alignment
                                                                  .topCenter,
                                                              end: Alignment
                                                                  .bottomCenter,
                                                              colors: <Color>[
                                                                p.brandRed,
                                                                p.brandPink,
                                                              ],
                                                            ),
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    5,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      labels[i],
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        color: p.textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _TopVideosCard(videos: videos, compact: isMobile),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _copyCsv(),
                                    child: Text(
                                      'Xuất báo cáo CSV (sao chép)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: p.brandRed,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopVideosCard extends StatelessWidget {
  const _TopVideosCard({required this.videos, required this.compact});

  final List<Video> videos;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            color: p.surfaceAlt,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: 10,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'VIDEO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: p.textSecondary,
                    ),
                  ),
                ),
                if (!compact) ...<Widget>[
                  const _HeaderCell('LƯỢT XEM'),
                  const _HeaderCell('LƯỢT THÍCH'),
                  const _HeaderCell('BÌNH LUẬN'),
                ],
              ],
            ),
          ),
          if (videos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Chưa có video nào để thống kê.',
                style: TextStyle(fontSize: 12, color: p.textSecondary),
              ),
            )
          else
            for (int index = 0; index < videos.length; index++) ...<Widget>[
              if (index > 0) Divider(color: p.border),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 14,
                  vertical: compact ? 10 : 9,
                ),
                child: Row(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: compact ? 92 : 100,
                      child: VideoThumb(
                        video: videos[index],
                        radius: 4,
                        showControls: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            videos[index].title,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: p.textPrimary,
                            ),
                          ),
                          if (compact) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              '${videos[index].views} xem · '
                              '${videos[index].likeCount} thích · '
                              '${videos[index].commentCount} bình luận',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.35,
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!compact) ...<Widget>[
                      _ValueCell('${videos[index].views}'),
                      _ValueCell('${videos[index].likeCount}'),
                      _ValueCell('${videos[index].commentCount}'),
                    ],
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.compact,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: p.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: p.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: p.textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SizedBox(
      width: 86,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: p.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SizedBox(
      width: 86,
      child: Center(
        child: Text(
          value,
          style: TextStyle(fontSize: 11.5, color: p.textPrimary),
        ),
      ),
    );
  }
}

String _weekdayLabel(DateTime date) {
  const List<String> names = <String>['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final int index = date.weekday - 1;
  if (index < 0 || index >= names.length) return '';
  return names[index];
}

String _formatCompact(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} Tr';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} N';
  }
  return '$value';
}
