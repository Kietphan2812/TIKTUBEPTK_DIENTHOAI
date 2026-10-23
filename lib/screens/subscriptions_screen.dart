import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/tiktube_api.dart';
import '../models/channel.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tab_pill.dart';
import '../widgets/data_state.dart';
import '../widgets/section_top_bar.dart';
import 'account_screen.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, this.api});

  final TikTubeApi? api;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  late final TikTubeApi _api;
  List<Channel> _channels = <Channel>[];
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
      final List<Channel> channels = await _api.fetchSubscriptions();
      if (!mounted) return;
      setState(() {
        _channels = channels;
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
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _unsubscribe(Channel channel) async {
    final int index = _channels.indexOf(channel);
    if (index < 0) return;
    setState(() => _channels.removeAt(index));
    _notify('Đã hủy đăng ký kênh ${channel.name}.');
    try {
      await _api.setSubscription(channel.id, subscribed: false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final int restoreAt = index.clamp(0, _channels.length);
        _channels.insert(restoreAt, channel);
      });
      _notify('Không hủy được đăng ký — kiểm tra API/Neon.');
    }
  }

  void _goHome() =>
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccountScreen(api: _api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          SectionTopBar(
            onBack: () => Navigator.of(context).maybePop(),
            onHome: _goHome,
            onAccount: _openAccount,
            onSearch: _goHome,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: <Widget>[
                          AppTabPill(
                            label: 'KÊNH ĐÃ ĐĂNG KÝ',
                            selected: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                          ),
                          AppTabPill(
                            label: 'NGƯỜI ĐĂNG KÝ KÊNH BẠN',
                            selected: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _tab == 0
                            ? 'Kênh bạn đã đăng ký'
                            : 'Người đăng ký kênh bạn',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _tab == 0
                            ? 'Danh sách những người sáng tạo nội dung bạn đang theo dõi.'
                            : 'Những người đang theo dõi nội dung của bạn.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_loading)
                        const DataLoading(
                          message: 'Đang tải danh sách kênh từ Neon...',
                        )
                      else if (_error != null)
                        DataError(message: _error!, onRetry: _load)
                      else if (_tab == 1)
                        _EmptyState(
                          icon: Icons.group_outlined,
                          title: 'Chưa có ai đăng ký kênh bạn',
                          subtitle:
                              'Hãy đăng video đều đặn để có thêm người theo dõi.',
                        )
                      else if (_channels.isEmpty)
                        _EmptyState(
                          icon: Icons.subscriptions_outlined,
                          title: 'Bạn chưa đăng ký kênh nào',
                          subtitle:
                              'Nhấn Đăng ký ở trang xem video để theo dõi kênh yêu thích.',
                        )
                      else
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: <Widget>[
                            for (final Channel channel in _channels)
                              _ChannelCard(
                                channel: channel,
                                onUnsubscribe: () => _unsubscribe(channel),
                              ),
                          ],
                        ),
                    ],
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
          BoxShadow(
            color: p.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
