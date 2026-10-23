import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/app_notification.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/data_state.dart';
import '../widgets/section_top_bar.dart';
import 'account_screen.dart';
import 'stats_screen.dart';
import 'watch_screen.dart';

/// Trung tâm thông báo: đăng ký kênh, bình luận, lượt thích và video mới.
///
/// Dữ liệu đọc từ bảng `thong_bao` dùng chung với web. Màn hình tự làm mới
/// mỗi 10 giây để thông báo do web hoặc người dùng khác tạo hiện gần như ngay.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.api});

  final TikTubeApi? api;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final TikTubeApi _api;

  List<AppNotification>? _items;
  bool _loading = true;
  bool _refreshing = false;
  bool _markingRead = false;
  String? _error;
  Timer? _pollTimer;

  int get _unreadCount =>
      _items?.where((AppNotification item) => !item.seen).length ?? 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiClient();
    unawaited(_load());
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _refreshing) return;
      unawaited(_load(silent: true));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final List<AppNotification> items = await _api.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (!silent || _items == null) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _markAllRead() async {
    if (_markingRead || _unreadCount == 0) return;
    final List<AppNotification>? previous = _items;
    setState(() {
      _markingRead = true;
      _items = _items
          ?.map((AppNotification item) => item.copyWith(seen: true))
          .toList();
    });
    try {
      await _api.markNotificationsRead();
    } catch (error) {
      if (!mounted) return;
      setState(() => _items = previous);
      _notify('Không đánh dấu được thông báo: $error');
    } finally {
      if (mounted) setState(() => _markingRead = false);
    }
  }

  Future<void> _markOneRead(String id) async {
    try {
      await _api.markNotificationRead(id);
    } catch (_) {
      // Không chặn việc mở video nếu bước đánh dấu đã đọc thất bại.
    }
  }

  Future<void> _openNotification(AppNotification item) async {
    if (!item.seen) {
      setState(() {
        _items = _items
            ?.map(
              (AppNotification entry) =>
                  entry.id == item.id ? entry.copyWith(seen: true) : entry,
            )
            .toList();
      });
      unawaited(_markOneRead(item.id));
    }

    final String? videoId = item.videoId;
    if (videoId == null || videoId.isEmpty) return;

    try {
      final List<Video> videos = await _api.fetchVideos();
      Video? selected;
      for (final Video video in videos) {
        if (video.id == videoId) {
          selected = video;
          break;
        }
      }
      if (!mounted) return;
      if (selected == null) {
        _notify('Video này không còn khả dụng.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              WatchScreen(video: selected!, api: _api, related: videos),
        ),
      );
      if (mounted) unawaited(_load(silent: true));
    } catch (error) {
      if (!mounted) return;
      _notify('Không mở được video: $error');
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _goHome() =>
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

  void _openAccount() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => AccountScreen(api: _api)));
  }

  void _openStats() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => StatsScreen(api: _api)));
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
            title: 'Thông báo',
            onBack: () => Navigator.of(context).maybePop(),
            onHome: _goHome,
            onAccount: _openAccount,
            onStats: _openStats,
            onSearch: _goHome,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                color: p.brandRed,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    compact ? 14 : 20,
                    compact ? 14 : 20,
                    compact ? 14 : 20,
                    32,
                  ),
                  children: <Widget>[
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: _content(context, compact: compact),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, {required bool compact}) {
    final p = context.palette;

    return Column(
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
                    'Tất cả thông báo',
                    style: TextStyle(
                      fontSize: compact ? 20 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tự động làm mới mỗi 10 giây · dùng chung dữ liệu với web',
                    style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                  ),
                ],
              ),
            ),
            if (_unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 10, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: p.brandRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.brandRed.withValues(alpha: 0.22)),
                ),
                child: Text(
                  '$_unreadCount chưa đọc',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: p.brandRed,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _unreadCount == 0
                    ? 'Bạn đã xem hết thông báo'
                    : 'Chạm vào thông báo để mở video liên quan',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: p.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: (_unreadCount == 0 || _markingRead)
                  ? null
                  : _markAllRead,
              icon: Icon(
                Icons.done_all_rounded,
                size: 16,
                color: _unreadCount == 0 ? p.textSecondary : p.brandRed,
              ),
              label: Text(
                _markingRead ? 'Đang lưu...' : 'Đánh dấu đã đọc',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _unreadCount == 0 ? p.textSecondary : p.brandRed,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading && _items == null)
          const DataLoading(message: 'Đang tải thông báo...')
        else if (_error != null && _items == null)
          DataError(message: _error!, onRetry: _load)
        else if (_items == null || _items!.isEmpty)
          _EmptyNotifications(compact: compact)
        else
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < _items!.length; index++) ...[
                  if (index > 0) Divider(height: 1, color: p.border),
                  _NotificationTile(
                    item: _items![index],
                    onTap: () => _openNotification(_items![index]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final _NotificationVisual visual = _visualFor(item.content, p);

    return Material(
      color: item.seen ? p.surface : p.chip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.icon, size: 19, color: visual.color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: item.seen
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.timeLabel,
                      style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (!item.seen)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: p.brandRed,
                    shape: BoxShape.circle,
                  ),
                )
              else if (item.videoId != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: p.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 24 : 40,
        vertical: compact ? 40 : 56,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.notifications_none_rounded,
            size: 38,
            color: p.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có thông báo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Khi ai đó đăng ký kênh, bình luận hoặc thích video của bạn, '
            'thông báo sẽ xuất hiện ở đây.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationVisual {
  const _NotificationVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}

_NotificationVisual _visualFor(String content, PtPalette p) {
  final String text = content.toLowerCase();
  if (text.contains('đăng ký kênh')) {
    return const _NotificationVisual(
      Icons.person_add_alt_1_rounded,
      Color(0xFF2E9E62),
    );
  }
  if (text.contains('bình luận')) {
    return const _NotificationVisual(
      Icons.chat_bubble_outline_rounded,
      Color(0xFF2D6CDF),
    );
  }
  if (text.contains('thích video')) {
    return _NotificationVisual(Icons.favorite_border_rounded, p.brandRed);
  }
  if (text.contains('đăng video')) {
    return const _NotificationVisual(Icons.movie_outlined, Color(0xFFF0820C));
  }
  return _NotificationVisual(Icons.notifications_none_rounded, p.textSecondary);
}
