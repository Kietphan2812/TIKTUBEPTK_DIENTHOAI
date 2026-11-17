import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_scope.dart';
import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/channel.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/channel_avatar.dart';
import '../widgets/data_state.dart';
import '../widgets/video_card.dart';
import 'account_screen.dart';
import 'watch_screen.dart';

/// Màn hình Trang Kênh của bất kỳ tác giả/người dùng nào trên TIKTUBE.
/// Hiển thị thông tin kênh, số người đăng ký, nút đăng ký và danh sách tất cả
/// các video mà người đó đã tải lên.
class ChannelScreen extends StatefulWidget {
  const ChannelScreen({
    super.key,
    required this.channelName,
    this.channelId = '',
    this.avatarUrl,
    this.subscriberCount = 0,
    this.subscribed = false,
    this.initialVideo,
    this.api,
  });

  final String channelName;
  final String channelId;
  final String? avatarUrl;
  final int subscriberCount;
  final bool subscribed;
  final Video? initialVideo;
  final TikTubeApi? api;

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen>
    with SingleTickerProviderStateMixin {
  late final TikTubeApi _api;
  late TabController _tabController;

  List<Video> _channelVideos = <Video>[];
  bool _loading = true;
  String? _error;
  late int _subscriberCount;
  late bool _subscribed;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiClient();
    _tabController = TabController(length: 2, vsync: this);
    _subscriberCount = widget.subscriberCount;
    _subscribed = widget.subscribed;
    if (widget.initialVideo != null) {
      _channelVideos = <Video>[widget.initialVideo!];
    }
    _loadChannelData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChannelData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _api.fetchVideos(),
        _api.fetchSubscriptions(),
      ]);

      final allVideos = results[0] as List<Video>;
      final mySubscriptions = results[1] as List<Channel>;

      final String targetName = widget.channelName.trim().toLowerCase();
      final String targetId = widget.channelId.trim();

      final matching = allVideos.where((v) {
        final chName = v.channel.trim().toLowerCase();
        final upName = v.uploadedBy.trim().toLowerCase();
        final chId = v.channelId.trim();
        return chName == targetName ||
            upName == targetName ||
            (targetId.isNotEmpty && chId == targetId);
      }).toList();

      if (widget.initialVideo != null &&
          !matching.any((v) => v.id == widget.initialVideo!.id)) {
        matching.insert(0, widget.initialVideo!);
      }

      final isSub = mySubscriptions.any(
        (c) =>
            c.name.trim().toLowerCase() == targetName ||
            (targetId.isNotEmpty && c.id == targetId),
      );

      if (!mounted) return;
      setState(() {
        _channelVideos = matching;
        _subscribed = isSub || widget.subscribed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleSubscribe() async {
    final next = !_subscribed;
    setState(() {
      _subscribed = next;
      _subscriberCount = (_subscriberCount + (next ? 1 : -1)).clamp(0, 1 << 30);
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'Đã đăng ký kênh ${widget.channelName}.'
                : 'Đã hủy đăng ký kênh ${widget.channelName}.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

    try {
      if (widget.channelId.isNotEmpty) {
        final count = await _api.setSubscription(
          widget.channelId,
          subscribed: next,
        );
        if (mounted) setState(() => _subscriberCount = count);
      }
    } catch (_) {
      // Giữ UI lạc quan
    }
  }

  void _shareChannel() {
    final handle = widget.channelName.replaceAll(' ', '').toLowerCase();
    final link = 'https://tiktube-api.onrender.com/@$handle';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép liên kết kênh vào bộ nhớ tạm.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  void _openVideo(Video video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => WatchScreen(video: video, api: _api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final profile = AuthScope.maybeOf(context)?.profile;
    final bool isMyChannel = profile != null &&
        (profile.name.trim().toLowerCase() ==
                widget.channelName.trim().toLowerCase() ||
            profile.userKey.trim().toLowerCase() ==
                widget.channelName.trim().toLowerCase());

    final isMobile = MediaQuery.sizeOf(context).width < 700;

    // Tính tổng lượt xem của kênh
    int totalViews = 0;
    for (final v in _channelVideos) {
      totalViews += v.views;
    }

    // Avatar đại diện kênh
    String? effectiveAvatar = widget.avatarUrl;
    if (effectiveAvatar == null || effectiveAvatar.isEmpty) {
      if (isMyChannel && profile.avatarUrl != null) {
        effectiveAvatar = profile.avatarUrl;
      } else if (_channelVideos.isNotEmpty) {
        effectiveAvatar = _channelVideos.first.authorAvatarUrl;
      }
    }

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: p.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.channelName,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.share_rounded, color: p.textPrimary),
            tooltip: 'Chia sẻ kênh',
            onPressed: _shareChannel,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext ctx, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Banner kênh
                  Container(
                    height: isMobile ? 110 : 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.initialVideo?.colors ??
                            const <Color>[
                              Color(0xFF1E2640),
                              Color(0xFF0F172A),
                              Color(0xFFE8112D),
                            ],
                      ),
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned(
                          right: -20,
                          bottom: -20,
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: isMobile ? 120 : 180,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Header thông tin kênh
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            // Avatar kênh lớn
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: p.surface, width: 3),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: (effectiveAvatar != null &&
                                        effectiveAvatar.trim().isNotEmpty)
                                    ? Image.network(
                                        effectiveAvatar.trim(),
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _buildInitialsAvatar(p),
                                      )
                                    : (widget.initialVideo != null
                                        ? ChannelAvatar(
                                            video: widget.initialVideo!,
                                            size: 72,
                                          )
                                        : _buildInitialsAvatar(p)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    widget.channelName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: p.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '@${widget.channelName.replaceAll(' ', '').toLowerCase()}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: p.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_subscriberCount người đăng ký  •  ${_channelVideos.length} video',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Nút hành động chính: Đăng ký hoặc Quản lý kênh
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: isMyChannel
                              ? OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Quản lý kênh & Video',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: p.textPrimary,
                                    side: BorderSide(color: p.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const AccountScreen(),
                                      ),
                                    );
                                  },
                                )
                              : ElevatedButton.icon(
                                  icon: Icon(
                                    _subscribed
                                        ? Icons.check_circle_rounded
                                        : Icons.notifications_active_outlined,
                                    size: 18,
                                    color: _subscribed
                                        ? p.textSecondary
                                        : Colors.white,
                                  ),
                                  label: Text(
                                    _subscribed ? 'Đã đăng ký' : 'Đăng ký kênh',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _subscribed
                                          ? p.textSecondary
                                          : Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _subscribed
                                        ? p.chip
                                        : p.brandRed,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: _toggleSubscribe,
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Tab chọn Video / Giới thiệu
                  Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: p.border)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: p.brandRed,
                      indicatorWeight: 3,
                      labelColor: p.textPrimary,
                      unselectedLabelColor: p.textSecondary,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      tabs: <Widget>[
                        Tab(text: 'Video (${_channelVideos.length})'),
                        const Tab(text: 'Giới thiệu'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: <Widget>[
            // Tab 1: Danh sách video của kênh
            _buildVideosTab(p, isMobile),

            // Tab 2: Giới thiệu kênh
            _buildAboutTab(p, totalViews),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(PtPalette p) {
    final initial = widget.channelName.trim().isNotEmpty
        ? widget.channelName.trim()[0].toUpperCase()
        : 'K';
    return Container(
      alignment: Alignment.center,
      color: p.brandRed,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildVideosTab(PtPalette p, bool isMobile) {
    if (_loading && _channelVideos.isEmpty) {
      return const Center(child: DataLoading(message: 'Đang tải video của kênh...'));
    }
    if (_error != null && _channelVideos.isEmpty) {
      return Center(
        child: DataError(
          message: 'Không tải được danh sách video: $_error',
          onRetry: _loadChannelData,
        ),
      );
    }
    if (_channelVideos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.video_library_outlined,
                size: 64,
                color: p.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Kênh chưa đăng video nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hãy quay lại sau khi tác giả tải lên video mới.',
                style: TextStyle(fontSize: 13, color: p.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _channelVideos.length,
        separatorBuilder: (_, _) => Container(
          height: 1,
          color: p.border.withValues(alpha: 0.5),
          margin: const EdgeInsets.symmetric(vertical: 4),
        ),
        itemBuilder: (BuildContext ctx, int index) {
          final video = _channelVideos[index];
          return VideoCard(
            video: video,
            compact: true,
            onTap: () => _openVideo(video),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        const double gap = 16;
        final int columns = (constraints.maxWidth / 268).floor().clamp(1, 5);
        final double cardWidth =
            (constraints.maxWidth - gap * (columns - 1) - 32) / columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: gap,
            runSpacing: 20,
            children: <Widget>[
              for (final video in _channelVideos)
                SizedBox(
                  width: cardWidth,
                  child: VideoCard(
                    video: video,
                    compact: false,
                    onTap: () => _openVideo(video),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutTab(PtPalette p, int totalViews) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Mô tả kênh',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kênh chính thức của ${widget.channelName} trên nền tảng video TIKTUBE PTK. Xem các video âm nhạc, giải trí, thước phim ngắn và chia sẻ sáng tạo.',
            style: TextStyle(
              fontSize: 13.5,
              color: p.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: p.border),
          const SizedBox(height: 16),
          Text(
            'Thông tin chi tiết',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _detailRow(Icons.person_outline_rounded, 'Chủ kênh', widget.channelName, p),
          _detailRow(Icons.link_rounded, 'Đường dẫn kênh', 'tiktube-api.onrender.com/@${widget.channelName.replaceAll(' ', '').toLowerCase()}', p),
          _detailRow(Icons.remove_red_eye_outlined, 'Tổng lượt xem', '$totalViews lượt xem', p),
          _detailRow(Icons.video_collection_outlined, 'Số lượng video', '${_channelVideos.length} video', p),
          _detailRow(Icons.calendar_today_outlined, 'Nền tảng', 'Gia nhập TIKTUBE PTK', p),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, PtPalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: p.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: p.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
