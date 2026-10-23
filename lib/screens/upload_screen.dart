import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/sample_data.dart';
import '../data/tiktube_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_pill.dart';
import '../widgets/dashed_box.dart';
import '../widgets/section_top_bar.dart';
import 'account_screen.dart';
import 'stats_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, this.api});

  final TikTubeApi? api;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final TikTubeApi _api;

  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _hashtag = TextEditingController();

  final List<String> _tags = <String>[
    'remix',
    'djhot',
    'tiktok',
    'tiktokremix',
    'tiktokvn',
    'mashup',
    'dj',
    'house',
    'vietmix',
    'nhacdj',
  ];

  String _category = 'Âm nhạc & sáng tạo';
  bool _kidsOnly = true;
  PlatformFile? _file;
  Uint8List? _bytes;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiClient();
    _title.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _title.removeListener(_onTitleChanged);
    _title.dispose();
    _description.dispose();
    _hashtag.dispose();
    super.dispose();
  }

  void _addTag() {
    final value = _hashtag.text.trim().replaceAll('#', '');
    if (value.isEmpty) return;
    if (!_tags.contains(value)) {
      setState(() => _tags.add(value));
    }
    _hashtag.clear();
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

  Future<void> _pickVideo() async {
    if (_uploading) return;
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.video,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _notify('Không đọc được tệp video đã chọn.');
        return;
      }
      if (bytes.length > 100 * 1024 * 1024) {
        _notify('Video vượt quá giới hạn 100 MB của Cloudinary.');
        return;
      }
      setState(() {
        _file = file;
        _bytes = bytes;
      });
    } catch (error) {
      _notify('Không mở được trình chọn tệp: $error');
    }
  }

  Future<void> _submit() async {
    if (_uploading) return;
    if (_bytes == null || _file == null) {
      _notify('Vui lòng chọn video để tải lên.');
      return;
    }
    if (_title.text.trim().isEmpty) {
      _notify('Vui lòng nhập tiêu đề video.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final video = await _api.uploadVideo(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        tags: _tags,
        kidsOnly: _kidsOnly,
        bytes: _bytes!,
        filename: _file!.name,
      );
      if (!mounted) return;
      _notify('Đã đăng video “${video.title}” lên Cloudinary + Neon.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      _notify(error.message);
    } catch (error) {
      if (!mounted) return;
      _notify('Tải video thất bại: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String get _fileSizeLabel {
    final size = _bytes?.length ?? 0;
    if (size >= 1024 * 1024) {
      final value = size / (1024 * 1024);
      return '${value.toStringAsFixed(1).replaceAll('.', ',')} MB';
    }
    if (size >= 1024) {
      final value = size / 1024;
      return '${value.toStringAsFixed(0)} KB';
    }
    return '$size B';
  }

  void _goHome() =>
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccountScreen(api: _api)),
    );
  }

  void _openStats() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StatsScreen(api: _api)),
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
            onStats: _openStats,
            onSearch: _goHome,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      final bool wide = constraints.maxWidth >= 880;

                      final Widget form = _UploadForm(
                        titleController: _title,
                        descriptionController: _description,
                        hashtagController: _hashtag,
                        tags: _tags,
                        category: _category,
                        kidsOnly: _kidsOnly,
                        picked: _file != null,
                        fileName: _file?.name,
                        fileSizeLabel: _fileSizeLabel,
                        uploading: _uploading,
                        onPick: _pickVideo,
                        onCategory: (String value) =>
                            setState(() => _category = value),
                        onKids: (bool value) =>
                            setState(() => _kidsOnly = value),
                        onRemoveTag: (String tag) =>
                            setState(() => _tags.remove(tag)),
                        onAddTag: _addTag,
                        onCancel: _uploading
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        onSubmit: _submit,
                        onCover: () => _notify(
                          'Ảnh bìa sẽ được Cloudinary tạo tự động từ video.',
                        ),
                      );

                      final Widget preview = _PhonePreview(
                        title: _title.text.trim(),
                        fileName: _file?.name,
                        uploading: _uploading,
                      );

                      if (!wide) {
                        return Column(
                          children: <Widget>[
                            form,
                            const SizedBox(height: 24),
                            preview,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: form),
                          const SizedBox(width: 30),
                          preview,
                        ],
                      );
                    },
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

class _UploadForm extends StatelessWidget {
  const _UploadForm({
    required this.titleController,
    required this.descriptionController,
    required this.hashtagController,
    required this.tags,
    required this.category,
    required this.kidsOnly,
    required this.picked,
    required this.fileName,
    required this.fileSizeLabel,
    required this.uploading,
    required this.onPick,
    required this.onCategory,
    required this.onKids,
    required this.onRemoveTag,
    required this.onAddTag,
    required this.onCancel,
    required this.onSubmit,
    required this.onCover,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController hashtagController;
  final List<String> tags;
  final String category;
  final bool kidsOnly;
  final bool picked;
  final String? fileName;
  final String fileSizeLabel;
  final bool uploading;
  final VoidCallback onPick;
  final ValueChanged<String> onCategory;
  final ValueChanged<bool> onKids;
  final ValueChanged<String> onRemoveTag;
  final VoidCallback onAddTag;
  final VoidCallback? onCancel;
  final VoidCallback onSubmit;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tải video',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Đăng video vào tài khoản của bạn',
            style: TextStyle(fontSize: 12, color: p.textSecondary),
          ),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: uploading ? null : onPick,
              child: DashedBox(
                color: picked
                    ? const Color(0xFF2E9E62).withValues(alpha: 0.7)
                    : p.border,
                radius: 8,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        uploading
                            ? Icons.cloud_upload_outlined
                            : picked
                                ? Icons.check_circle_outline_rounded
                                : Icons.photo_size_select_actual_outlined,
                        size: 34,
                        color: uploading
                            ? p.brandRed
                            : picked
                                ? const Color(0xFF2E9E62)
                                : p.textSecondary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        uploading
                            ? 'Đang tải video lên Cloudinary...'
                            : picked
                                ? (fileName ?? 'video.mp4')
                                : 'Chọn video để tải lên',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        uploading
                            ? 'Vui lòng giữ trang mở trong khi tải lên.'
                            : picked
                                ? 'Đã chọn · $fileSizeLabel · Nhấn để đổi tập tin'
                                : 'Hoặc kéo và thả tập tin',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MP4 hoặc WebM · Tối đa 100 MB',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: p.textSecondary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _Label('Tiêu đề'),
          _TextField(
            controller: titleController,
            hint: 'Nhập tiêu đề cho video',
          ),
          const SizedBox(height: 14),
          const _Label('Danh mục'),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: category,
                isExpanded: true,
                isDense: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: p.textSecondary,
                ),
                dropdownColor: p.surface,
                borderRadius: BorderRadius.circular(8),
                style: TextStyle(fontSize: 12.5, color: p.textPrimary),
                items: <DropdownMenuItem<String>>[
                  for (final String item in kCategories)
                    if (item != 'Tất cả')
                      DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                ],
                onChanged: (String? value) {
                  if (value != null) onCategory(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _Label('Mô tả'),
          TextField(
            controller: descriptionController,
            minLines: 4,
            maxLines: 6,
            style: TextStyle(fontSize: 12.5, color: p.textPrimary),
            decoration: _decoration(
              context,
              hint: 'Kể câu chuyện về video của bạn...',
              alignTop: true,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String tag in tags)
                _HashtagChip(
                  label: tag,
                  onRemove: () => onRemoveTag(tag),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: hashtagController,
                    onSubmitted: (_) => onAddTag(),
                    style: TextStyle(fontSize: 12, color: p.textPrimary),
                    decoration: _decoration(
                      context,
                      hint: 'Thêm tag (VD: #game)',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppPill(
                label: 'Thêm',
                height: 36,
                background: p.chip,
                borderColor: p.border,
                onTap: onAddTag,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Ảnh bìa (ảnh nên có điện thoại)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onCover,
                  child: Text(
                    'Chọn ảnh bìa từ thiết bị',
                    style: TextStyle(fontSize: 10.5, color: p.brandRed),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ai có thể xem video này?',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _AgeOption(
                label: 'Video cho trẻ em',
                selected: kidsOnly,
                onTap: () => onKids(true),
              ),
              const SizedBox(width: 22),
              _AgeOption(
                label: 'Video trên 18 tuổi',
                selected: !kidsOnly,
                onTap: () => onKids(false),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.textPrimary,
                      side: BorderSide(color: p.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Hủy bỏ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: uploading ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: p.textPrimary,
                      foregroundColor: p.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: uploading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: p.surface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Đang đăng...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Đăng',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String hint,
    bool alignTop = false,
  }) {
    final p = context.palette;

    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: p.textSecondary),
      filled: true,
      fillColor: p.surfaceAlt,
      alignLabelWithHint: alignTop,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.textSecondary),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 12.5, color: p.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: p.textSecondary),
          filled: true,
          fillColor: p.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: p.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: p.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: context.palette.textPrimary,
        ),
      ),
    );
  }
}

class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
      decoration: BoxDecoration(
        color: p.chip,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '#$label',
            style: TextStyle(fontSize: 10.5, color: p.textSecondary),
          ),
          const SizedBox(width: 4),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close_rounded,
                size: 11,
                color: p.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeOption extends StatelessWidget {
  const _AgeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 15,
              height: 15,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2D6CDF)
                      : p.textSecondary.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2D6CDF),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, color: p.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({
    required this.title,
    required this.fileName,
    required this.uploading,
  });

  final String title;
  final String? fileName;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasFile = fileName != null;

    return Container(
      width: 255,
      height: 502,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: p.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: p.shadow,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 70,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          if (!hasFile)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.smart_display_outlined,
                    size: 34,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Xem trước video',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color(0xFF1B3B4A),
                            Color(0xFF7A5CC4),
                            Color(0xFF0A0A0A),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            uploading
                                ? Icons.cloud_upload_outlined
                                : Icons.play_circle_outline_rounded,
                            size: 46,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              title.isEmpty ? 'Tiêu đề video' : title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: p.brandRed,
                        child: const Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'kiepthan4',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        uploading
                            ? Icons.cloud_upload_rounded
                            : Icons.more_vert_rounded,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fileName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9.5,
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
