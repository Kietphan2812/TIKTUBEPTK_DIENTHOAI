import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/sample_data.dart';
import '../data/tiktube_api.dart';
import '../models/video.dart';
import '../models/watch_history_item.dart';
import '../theme/app_theme.dart';
import '../widgets/app_pill.dart';
import '../widgets/app_tab_pill.dart';
import '../widgets/data_state.dart';
import '../widgets/mobile_segmented_tabs.dart';
import '../widgets/section_top_bar.dart';
import '../widgets/video_thumb.dart';
import 'account_screen.dart';
import 'stats_screen.dart';
import 'watch_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.api});

  final TikTubeApi? api;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final TikTubeApi _api;
  int _tab = 0;
  bool _loading = true;
  String? _error;

  List<Video> _uploads = <Video>[];
  List<WatchHistoryItem> _watched = <WatchHistoryItem>[];

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
      final results = await Future.wait(<Future<Object>>[
        _api.fetchUploads(),
        _api.fetchWatchHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _uploads = results[0] as List<Video>;
        _watched = results[1] as List<WatchHistoryItem>;
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

  Future<void> _openWatch(Video video) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WatchScreen(
          video: video,
          api: _api,
          related: _watched.map((item) => item.video).toList(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _clearHistory() async {
    try {
      await _api.clearWatchHistory();
      if (!mounted) return;
      setState(() => _watched = <WatchHistoryItem>[]);
      _notify('Đã xoá toàn bộ lịch sử xem trên Neon.');
    } catch (_) {
      _notify('Không xoá được lịch sử — kiểm tra API/Neon.');
    }
  }

  Future<void> _removeHistory(WatchHistoryItem item) async {
    try {
      await _api.removeWatchHistory(item.video.id);
      if (!mounted) return;
      setState(() => _watched.remove(item));
      _notify('Đã xoá khỏi lịch sử xem.');
    } catch (_) {
      _notify('Không xoá được mục này — kiểm tra API/Neon.');
    }
  }

  Future<void> _deleteUpload(Video video) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Xoá video?'),
        content: Text(
          'Video “${video.title}” sẽ bị xoá khỏi Neon'
          '${video.videoUrl != null ? ' và Cloudinary' : ''}.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteVideo(video.id);
      if (!mounted) return;
      setState(() => _uploads.remove(video));
      _notify('Đã xoá video “${video.title}”.');
    } catch (error) {
      if (!mounted) return;
      _notify('Không xoá được video: $error');
    }
  }

  Future<void> _editUpload(Video video) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (BuildContext context) => _EditVideoDialog(video: video),
    );
    if (result == null) return;

    try {
      final updated = await _api.updateVideo(
        video.id,
        title: result.title,
        description: result.description,
        category: result.category,
        tags: video.tags,
      );
      if (!mounted) return;
      setState(() {
        final int index = _uploads.indexWhere((v) => v.id == video.id);
        if (index >= 0) _uploads[index] = updated;
      });
      _notify('Đã cập nhật video “${updated.title}”.');
    } catch (error) {
      if (!mounted) return;
      _notify('Không cập nhật được video: $error');
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
            title: 'Lịch sử',
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
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (compact)
                            MobileSegmentedTabs(
                              labels: const <String>['Đã đăng', 'Đã xem'],
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
                                  label: 'LỊCH SỬ ĐĂNG VIDEO',
                                  selected: _tab == 0,
                                  onTap: () => setState(() => _tab = 0),
                                ),
                                AppTabPill(
                                  label: 'LỊCH SỬ XEM VIDEO',
                                  selected: _tab == 1,
                                  onTap: () => setState(() => _tab = 1),
                                ),
                              ],
                            ),
                          SizedBox(height: compact ? 16 : 20),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  compact
                                      ? (_tab == 0
                                            ? 'Video đã đăng'
                                            : 'Video đã xem')
                                      : (_tab == 0
                                            ? 'Lịch sử Đăng Video của bạn'
                                            : 'Lịch sử Xem Video của bạn'),
                                  style: TextStyle(
                                    fontSize: compact ? 17 : 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                              if (!_loading &&
                                  _error == null &&
                                  _tab == 1 &&
                                  _watched.isNotEmpty)
                                AppPill(
                                  label: compact
                                      ? 'Xoá hết'
                                      : 'Xoá tất cả lịch sử xem',
                                  height: 30,
                                  fontSize: 10.5,
                                  background: p.chip,
                                  onTap: _clearHistory,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_loading)
                            const DataLoading(
                              message: 'Đang tải lịch sử từ Neon...',
                            )
                          else if (_error != null)
                            DataError(message: _error!, onRetry: _load)
                          else if (_tab == 0)
                            _uploads.isEmpty
                                ? const _EmptyState(
                                    icon: Icons.video_library_outlined,
                                    title: 'Bạn chưa đăng video nào',
                                    subtitle: 'Video sau khi đăng sẽ xuất hiện tại đây.',
                                  )
                                : _UploadTable(
                                    uploads: _uploads,
                                    compact: compact,
                                    onEdit: _editUpload,
                                    onDelete: _deleteUpload,
                                  )
                          else if (_watched.isEmpty)
                            const _EmptyState(
                              icon: Icons.history_rounded,
                              title: 'Lịch sử xem video trống',
                              subtitle: 'Những video bạn đã xem sẽ được lưu lại tại đây.',
                            )
                          else
                            _WatchHistory(
                              items: _watched,
                              onOpen: _openWatch,
                              onRemove: _removeHistory,
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

class _UploadTable extends StatelessWidget {
  const _UploadTable({
    required this.uploads,
    required this.compact,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Video> uploads;
  final bool compact;
  final ValueChanged<Video> onEdit;
  final ValueChanged<Video> onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (compact) {
      return Column(
        children: <Widget>[
          for (final Video video in uploads) ...<Widget>[
            _UploadCard(
              video: video,
              onEdit: () => onEdit(video),
              onDelete: () => onDelete(video),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 720;
        final double statsWidth = wide ? 86 : 0;
        final double actionsWidth = wide ? 118 : 96;

        Widget header(String label) {
          return Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: p.textSecondary,
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              Container(
                color: p.surfaceAlt,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    const SizedBox(width: 122),
                    Expanded(flex: 4, child: header('VIDEO')),
                    if (wide) ...<Widget>[
                      SizedBox(
                        width: statsWidth,
                        child: Center(child: header('LƯỢT XEM')),
                      ),
                      SizedBox(
                        width: statsWidth,
                        child: Center(child: header('LƯỢT THÍCH')),
                      ),
                      SizedBox(
                        width: statsWidth,
                        child: Center(child: header('BÌNH LUẬN')),
                      ),
                    ],
                    SizedBox(width: actionsWidth),
                  ],
                ),
              ),
              for (int index = 0; index < uploads.length; index++) ...<Widget>[
                if (index > 0) Divider(color: p.border),
                _UploadRow(
                  video: uploads[index],
                  wide: wide,
                  statsWidth: statsWidth,
                  actionsWidth: actionsWidth,
                  onEdit: () => onEdit(uploads[index]),
                  onDelete: () => onDelete(uploads[index]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.video,
    required this.onEdit,
    required this.onDelete,
  });

  final Video video;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 108,
                child: VideoThumb(video: video, radius: 8, showControls: false),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                        if (!video.isApproved) ...<Widget>[
                          const SizedBox(width: 4),
                          _UploadStatusBadge(video: video),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.tags.isEmpty
                          ? video.category
                          : video.tags.map((String tag) => '#$tag').join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: p.textSecondary),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${video.viewsLabel} · ${video.likeCount} thích · '
                      '${video.commentCount} bình luận',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Sửa'),
                style: TextButton.styleFrom(
                  foregroundColor: p.textPrimary,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Xóa'),
                style: TextButton.styleFrom(
                  foregroundColor: p.brandRed,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({
    required this.video,
    required this.wide,
    required this.statsWidth,
    required this.actionsWidth,
    required this.onEdit,
    required this.onDelete,
  });

  final Video video;
  final bool wide;
  final double statsWidth;
  final double actionsWidth;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 112,
            child: VideoThumb(video: video, radius: 4, showControls: false),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    if (!video.isApproved) ...<Widget>[
                      const SizedBox(width: 6),
                      _UploadStatusBadge(video: video),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  video.tags.map((String tag) => '#$tag').join(' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: p.textSecondary),
                ),
              ],
            ),
          ),
          if (wide) ...<Widget>[
            SizedBox(
              width: statsWidth,
              child: Center(
                child: Text(
                  '${video.views}',
                  style: TextStyle(fontSize: 11.5, color: p.textPrimary),
                ),
              ),
            ),
            SizedBox(
              width: statsWidth,
              child: Center(
                child: Text(
                  '${video.likeCount}',
                  style: TextStyle(fontSize: 11.5, color: p.textPrimary),
                ),
              ),
            ),
            SizedBox(
              width: statsWidth,
              child: Center(
                child: Text(
                  '${video.commentCount}',
                  style: TextStyle(fontSize: 11.5, color: p.textPrimary),
                ),
              ),
            ),
          ],
          SizedBox(
            width: actionsWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                AppPill(
                  label: 'Sửa',
                  height: 24,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  gradient: const <Color>[Color(0xFFFFC24B), Color(0xFFE9A616)],
                  foreground: const Color(0xFF3D2B00),
                  onTap: onEdit,
                ),
                const SizedBox(width: 6),
                AppPill(
                  label: 'Xóa',
                  height: 24,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  background: const Color(0xFFE8323C),
                  foreground: Colors.white,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadStatusBadge extends StatelessWidget {
  const _UploadStatusBadge({required this.video});

  final Video video;

  @override
  Widget build(BuildContext context) {
    final Color color = video.isRejected
        ? const Color(0xFFE8323C)
        : const Color(0xFFE9A616);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        video.statusLabel,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}

class _WatchHistory extends StatelessWidget {
  const _WatchHistory({
    required this.items,
    required this.onOpen,
    required this.onRemove,
  });

  final List<WatchHistoryItem> items;
  final ValueChanged<Video> onOpen;
  final ValueChanged<WatchHistoryItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool compact = MediaQuery.sizeOf(context).width < 700;

    return Column(
      children: <Widget>[
        for (final WatchHistoryItem item in items) ...<Widget>[
          Container(
            padding: EdgeInsets.all(compact ? 8 : 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(compact ? 12 : 8),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: <Widget>[
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => onOpen(item.video),
                    child: SizedBox(
                      width: compact ? 112 : 140,
                      child: VideoThumb(
                        video: item.video,
                        radius: 6,
                        showControls: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => onOpen(item.video),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.video.title,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 12.5 : 13,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${item.video.channel} · ${item.video.viewsLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: p.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.video.date} · ${item.watchedLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: p.textSecondary.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onRemove(item),
                  tooltip: 'Xoá khỏi lịch sử',
                  visualDensity: VisualDensity.compact,
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 38, color: p.textSecondary),
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

class _EditResult {
  const _EditResult({
    required this.title,
    required this.description,
    required this.category,
  });

  final String title;
  final String description;
  final String category;
}

class _EditVideoDialog extends StatefulWidget {
  const _EditVideoDialog({required this.video});

  final Video video;

  @override
  State<_EditVideoDialog> createState() => _EditVideoDialogState();
}

class _EditVideoDialogState extends State<_EditVideoDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _category;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.video.title);
    _description = TextEditingController(text: widget.video.description);
    _category = widget.video.category;
    if (!kCategories.contains(_category)) {
      _category = kCategories.firstWhere(
        (String item) => item != 'Tất cả',
        orElse: () => widget.video.category,
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      _EditResult(
        title: title,
        description: _description.text.trim(),
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa video'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String>>[
                  for (final String item in kCategories)
                    if (item != 'Tất cả')
                      DropdownMenuItem<String>(value: item, child: Text(item)),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}
