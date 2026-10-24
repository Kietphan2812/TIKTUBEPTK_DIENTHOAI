import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../data/tiktube_api.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import '../widgets/dashed_box.dart';
import '../widgets/section_top_bar.dart';

/// Luồng đăng nhanh: chọn video, tự điền tiêu đề, lấy hashtag gợi ý từ SQL
/// và tải thẳng lên Cloudinary qua server.
class QuickUploadScreen extends StatefulWidget {
  const QuickUploadScreen({super.key, required this.api});

  final TikTubeApi api;

  @override
  State<QuickUploadScreen> createState() => _QuickUploadScreenState();
}

class _QuickUploadScreenState extends State<QuickUploadScreen> {
  final TextEditingController _title = TextEditingController();

  PlatformFile? _file;
  Uint8List? _bytes;
  String _category = 'Âm nhạc & sáng tạo';
  List<String> _tags = <String>[];
  bool _loadingTags = true;
  bool _uploading = false;
  double _progress = 0;

  List<String> get _categories => kCategories
      .where((String item) => item != 'Tất cả')
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    unawaited(_loadTags());
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() => _loadingTags = true);
    try {
      final List<String> tags = await widget.api.fetchTags(_category);
      if (!mounted) return;
      setState(() {
        _tags = tags.take(4).toList();
        _loadingTags = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tags = <String>[];
        _loadingTags = false;
      });
    }
  }

  Future<void> _changeCategory(String value) async {
    if (value == _category) return;
    setState(() {
      _category = value;
      _tags = <String>[];
    });
    await _loadTags();
  }

  Future<void> _pickVideo() async {
    if (_uploading) return;
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.video,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _notify('Không đọc được tệp video đã chọn.');
        return;
      }
      if (bytes.length > 100 * 1024 * 1024) {
        _notify('Video vượt quá giới hạn 100 MB của Cloudinary.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _file = file;
        _bytes = bytes;
        _progress = 0;
      });
      if (_title.text.trim().isEmpty) {
        _title.text = _titleFromFilename(file.name);
      }
    } catch (error) {
      _notify('Không mở được trình chọn tệp: ${_message(error)}');
    }
  }

  Future<void> _submit() async {
    if (_uploading) return;
    if (_bytes == null || _file == null) {
      _notify('Vui lòng chọn video để đăng.');
      return;
    }
    final String title = _title.text.trim();
    if (title.isEmpty) {
      _notify('Vui lòng nhập tiêu đề video.');
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0;
    });

    try {
      final Video video = await widget.api.uploadVideo(
        title: title,
        description: '',
        category: _category,
        tags: _tags,
        kidsOnly: true,
        bytes: _bytes!,
        filename: _file!.name,
        onProgress: (double value) {
          if (!mounted) return;
          setState(() => _progress = value.clamp(0, 1).toDouble());
        },
      );
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _progress = 1;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Đã đăng video nhanh lên TIKTUBE.'),
            duration: Duration(seconds: 2),
          ),
        );
      Navigator.of(context).pop(video);
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _notify('Đăng video thất bại: ${_message(error)}');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
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
            title: 'Đăng video nhanh',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 20,
                  compact ? 14 : 20,
                  compact ? 14 : 20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _QuickHeader(p: p),
                        const SizedBox(height: 14),
                        _PickerCard(
                          p: p,
                          file: _file,
                          onPick: _pickVideo,
                          enabled: !_uploading,
                        ),
                        const SizedBox(height: 14),
                        _FormCard(
                          p: p,
                          title: _title,
                          categories: _categories,
                          category: _category,
                          tags: _tags,
                          loadingTags: _loadingTags,
                          onCategory: _changeCategory,
                          onRemoveTag: (String tag) {
                            setState(() => _tags.remove(tag));
                          },
                          enabled: !_uploading,
                        ),
                        const SizedBox(height: 14),
                        if (_uploading) _ProgressCard(p: p, value: _progress),
                        if (_uploading) const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _uploading
                                    ? null
                                    : () => Navigator.of(context).maybePop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: p.textSecondary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: p.border),
                                ),
                                child: const Text('Hủy'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _uploading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: p.brandRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                icon: _uploading
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.bolt_rounded),
                                label: Text(
                                  _uploading ? 'Đang đăng...' : 'Đăng video nhanh',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
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

class _QuickHeader extends StatelessWidget {
  const _QuickHeader({required this.p});

  final PtPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            p.brandRed.withValues(alpha: 0.12),
            const Color(0xFF2563EB).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: p.ctaGradient),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Đăng nhanh, dữ liệu thật',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Video lưu trên Cloudinary, metadata và hashtag lấy từ Neon. '
                  'Bạn có thể sửa tiêu đề trước khi đăng.',
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
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

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.p,
    required this.file,
    required this.onPick,
    required this.enabled,
  });

  final PtPalette p;
  final PlatformFile? file;
  final VoidCallback onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool picked = file != null;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '1. Chọn video',
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: enabled ? onPick : null,
            child: DashedBox(
              color: picked ? p.brandRed : p.border,
              radius: 12,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: p.chip,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      picked ? Icons.video_file_rounded : Icons.video_call_rounded,
                      color: picked ? p.brandRed : p.textSecondary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          picked ? file!.name : 'Chạm để chọn video từ thiết bị',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          picked
                              ? '${_formatBytes(file!.lengthSync() ?? 0)} · Chạm để đổi video'
                              : 'MP4, MOV, WebM · tối đa 100 MB',
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    picked ? Icons.swap_horiz_rounded : Icons.upload_rounded,
                    color: picked ? p.brandRed : p.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.p,
    required this.title,
    required this.categories,
    required this.category,
    required this.tags,
    required this.loadingTags,
    required this.onCategory,
    required this.onRemoveTag,
    required this.enabled,
  });

  final PtPalette p;
  final TextEditingController title;
  final List<String> categories;
  final String category;
  final List<String> tags;
  final bool loadingTags;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onRemoveTag;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '2. Thông tin nhanh',
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: title,
            enabled: enabled,
            maxLength: 120,
            style: TextStyle(color: p.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Tiêu đề video',
              labelStyle: TextStyle(color: p.textSecondary, fontSize: 12),
              helperText: 'Tự điền từ tên tệp, bạn có thể sửa lại.',
              helperStyle: TextStyle(color: p.textSecondary, fontSize: 10.5),
              counterStyle: TextStyle(color: p.textSecondary, fontSize: 10),
              filled: true,
              fillColor: p.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.brandRed),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: category,
            isExpanded: true,
            style: TextStyle(color: p.textPrimary, fontSize: 12.5),
            decoration: InputDecoration(
              labelText: 'Danh mục',
              labelStyle: TextStyle(color: p.textSecondary, fontSize: 12),
              filled: true,
              fillColor: p.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: p.border),
              ),
            ),
            items: categories
                .map(
                  (String item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (String? value) {
                    if (value != null) onCategory(value);
                  }
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                'Hashtag gợi ý từ Neon',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              if (loadingTags)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: p.brandRed,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (!loadingTags && tags.isEmpty)
            Text(
              'Chưa có hashtag cho danh mục này — video vẫn được đăng bình thường.',
              style: TextStyle(color: p.textSecondary, fontSize: 10.5),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map(
                    (String tag) => InputChip(
                      label: Text('#$tag'),
                      labelStyle: TextStyle(color: p.brandRed, fontSize: 10.5),
                      backgroundColor: p.brandRed.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: p.brandRed.withValues(alpha: 0.25),
                      ),
                      visualDensity: VisualDensity.compact,
                      onDeleted: enabled ? () => onRemoveTag(tag) : null,
                      deleteIconColor: p.brandRed,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.p, required this.value});

  final PtPalette p;
  final double value;

  @override
  Widget build(BuildContext context) {
    final int percent = (value * 100).round();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.cloud_upload_rounded, color: p.brandRed, size: 18),
              const SizedBox(width: 6),
              Text(
                'Đang tải lên Cloudinary',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  color: p.brandRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: value <= 0 ? null : value,
              backgroundColor: p.chip,
              color: p.brandRed,
            ),
          ),
        ],
      ),
    );
  }
}

String _titleFromFilename(String name) {
  String value = name.trim();
  final int dot = value.lastIndexOf('.');
  if (dot > 0) value = value.substring(0, dot);
  value = value.replaceAll(RegExp(r'[_\-.]+'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  value = value.trim();
  if (value.isEmpty) return 'Video mới';
  return value.length > 120 ? value.substring(0, 120) : value;
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

String _message(Object error) {
  if (error is ApiException) return error.message;
  return error.toString();
}
