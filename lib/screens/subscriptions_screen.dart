import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/channel.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tab_pill.dart';
import '../widgets/data_state.dart';
import '../widgets/mobile_segmented_tabs.dart';
import '../widgets/section_top_bar.dart';
import '../widgets/video_card.dart';
import 'account_screen.dart';
import 'watch_screen.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, this.api});

  final TikTubeApi? api;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  late final TikTubeApi _api;
  List<Channel> _channels = <Channel>[];
  List<Video> _videos = <Video>[];
  int _tab = 0;
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
      final List<dynamic> results = await Future.wait<dynamic>(
        <Future<dynamic>>[
          _api.fetchSubscriptionFeed(limit: 30),
          _api.fetchSubscriptions(),
        ],
      );
      if (!mounted) return;
      setState(() {
        _videos = results[0] as List<Video>;
        _channels = results[1] as List<Channel>;
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

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _unsubscribe(Channel channel) async {
    final int index = _channels.indexOf(channel);
    if (index < 0) return;
    final List<Video> removedVideos = _videos
        .where(
          (Video video) =>
              video.channelId == channel.id || video.channel == channel.name,
        )
        .toList();
    setState(() {
      _channels.removeAt(index);
      _videos.removeWhere(
        (Video video) =>
            video.channelId == channel.id || video.channel == channel.name,
      );
    });
    _notify('Đã hủy đăng ký kênh ${channel.name}.');
    try {
      await _api.setSubscription(channel.id, subscribed: false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final int restoreAt = index.clamp(0, _channels.length);
        _channels.insert(restoreAt, channel);
        _videos = <Video>[...removedVideos, ..._videos];
      });
      _notify('Không hủy được đăng ký — kiểm tra API/Neon.');
    }
  }

  Future<void> _openVideo(Video video) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WatchScreen(video: video, api: _api, related: _videos),
      ),
    );
    if (mounted) unawaited(_load());
  }

  void _goHome() =>
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

  void _openAccount() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => AccountScreen(api: _api)));
  }

  String get _title {
    switch (_tab) {
      case 1:
        return 'Kênh bạn đã đăng ký';
      case 2:
        return 'Người đăng ký kênh bạn';
      default:
        return 'Video mới từ kênh đã đăng ký';
    }
  }

  String get _subtitle {
    switch (_tab) {
      case 1:
        return 'Danh sách những người sáng tạo nội dung bạn đang theo dõi.';
      case 2:
        return 'Những người đang theo dõi nội dung của bạn.';
      default:
        return 'Những video mới nhất từ các kênh bạn đang theo dõi, '
            'cập nhật trực tiếp từ Neon.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool compact = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          SectionTopBar(
            title: 'Đăng ký',
            onBack: () => Navigator.of(context).maybePop(),
            onHome: _goHome,
            onAccount: _openAccount,
            onSearch: _goHome,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                color: p.brandRed,
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    compact ? 14 : 20,
                    compact ? 14 : 20,
                    compact ? 14 : 20,
                    32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (compact)
                            MobileSegmentedTabs(
                              labels: const <String>[
                                'Video mới',
                                'Đã đăng ký',
                                'Người theo dõi',
                              ],
                              selectedIndex: _tab,
                              onChanged: (int index) =>
                                  setState(() => _tab = index),
                            )
                          else
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: <Widget>[
                                AppTabPill(
                                  label: 'VIDEO MỚI',
                                  selected: _tab == 0,
                                  onTap: () => setState(() => _tab = 0),
                                ),
                                AppTabPill(
                                  label: 'KÊNH ĐÃ ĐĂNG KÝ',
                                  selected: _tab == 1,
                                  onTap: () => setState(() => _tab = 1),
                                ),
                                AppTabPill(
                                  label: 'NGƯỜI ĐĂNG KÝ KÊNH BẠN',
                                  selected: _tab == 2,
                                  onTap: () => setState(() => _tab = 2),
                                ),
                              ],
                            ),
                          SizedBox(height: compact ? 15 : 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  _title,
                                  style: TextStyle(
                                    fontSize: compact ? 17 : 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _loading ? null : _load,
                                tooltip: 'Làm mới',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _subtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: p.textSecondary,
                            ),
                          ),
                          SizedBox(height: compact ? 14 : 18),
                          if (_loading)
                            DataLoading(
                              message: _tab == 0
                                  ? 'Đang tải video mới từ kênh đã đăng ký...'
                                  : 'Đang tải danh sách kênh từ Neon...',
                            )
                          else if (_error != null)
                            DataError(message: _error!, onRetry: _load)
                          else if (_tab == 2)
                            _EmptyState(
                              icon: Icons.group_outlined,
                              title: 'Chưa có ai đăng ký kênh bạn',
                              subtitle: 'Hãy đăng video đều đặn để có thêm người theo dõi.',
                            )
                          else if (_tab == 1)
                            _channels.isEmpty
                                ? _EmptyState(
                                    icon: Icons.subscriptions_outlined,
                                    title: 'Bạn chưa đăng ký kênh nào',
                                    subtitle: 'Nhấn Đăng ký ở trang xem video để theo dõi kênh yêu thích.',
                                  )
                                : compact
                                ? Column(
                                    children: <Widget>[
                                      for (final Channel channel
                                          in _channels) ...<Widget>[
                                        _MobileChannelTile(
                                          channel: channel,
                                          onUnsubscribe: () =>
                                              _unsubscribe(channel),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ],
                                  )
                                : Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: <Widget>[
                                      for (final Channel channel in _channels)
                                        _ChannelCard(
                                          channel: channel,
                                          onUnsubscribe: () =>
                                              _unsubscribe(channel),
                                        ),
                                    ],
                                  )
                          else if (_videos.isEmpty)
                            _EmptyState(
                              icon: Icons.video_library_outlined,
                              title: 'Chưa có video mới',
                              subtitle: 'Đăng ký kênh để video mới của họ xuất hiện tại đây.',
                            )
                          else
                            _SubscriptionFeed(
                              videos: _videos,
                              compact: compact,
                              onOpen: _openVideo,
                            ),
                        ],
                      ),
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

class _SubscriptionFeed extends StatelessWidget {
  const _SubscriptionFeed({
    required this.videos,
    required this.compact,
    required this.onOpen,
  });

  final List<Video> videos;
  final bool compact;
  final ValueChanged<Video> onOpen;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: <Widget>[
          for (int index = 0; index < videos.length; index++) ...<Widget>[
            VideoCard(
              video: videos[index],
              compact: true,
              onTap: () => onOpen(videos[index]),
            ),
            if (index != videos.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 16;
        final int columns = (constraints.maxWidth / 260)
            .floor()
            .clamp(1, 5)
            .toInt();
        final double cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 20,
          children: <Widget>[
            for (final Video video in videos)
              SizedBox(
                width: cardWidth,
                child: VideoCard(video: video, onTap: () => onOpen(video)),
              ),
          ],
        );
      },
    );
  }
}

class _MobileChannelTile extends StatelessWidget {
  const _MobileChannelTile({
    required this.channel,
    required this.onUnsubscribe,
  });

  final Channel channel;
  final VoidCallback onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: channel.colors,
              ),
            ),
            child: Text(
              channel.initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${channel.videoCount} video · ${channel.subscriberLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: onUnsubscribe,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: p.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Hủy đăng ký',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.onUnsubscribe});

  final Channel channel;
  final VoidCallback onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: 168,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
        boxShadow: <BoxShadow>[
          BoxShadow(color: p.shadow, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: channel.colors,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: p.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              channel.initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${channel.videoCount} video · ${channel.subscriberLabel}',
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: p.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: OutlinedButton(
              onPressed: onUnsubscribe,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.textPrimary,
                padding: EdgeInsets.zero,
                side: BorderSide(color: p.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'Hủy đăng ký',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 52),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 36, color: p.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}
