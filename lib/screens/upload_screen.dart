import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/api_client.dart';
import '../data/sample_data.dart';
import '../data/tiktube_api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_pill.dart';
import '../widgets/dashed_box.dart';
import '../widgets/platform_video_controller.dart';
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

  final List<String> _tags = <String>[];
  List<String> _categoryTags = <String>[];
  bool _loadingTags = true;
  String? _tagsError;
  int _tagRequest = 0;

  String _category = 'Âm nhạc & sáng tạo';
  bool _kidsOnly = true;
  PlatformFile? _file;
  Uint8List? _bytes;
  bool _uploading = false;
  bool _uploadComplete = false;
  double _uploadProgress = 0;
  final Stopwatch _uploadWatch = Stopwatch();
  Timer? _uploadTicker;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiClient();
    _title.addListener(_onTitleChanged);
    _loadCategoryTags();
  }

  Future<void> _loadCategoryTags([String? category]) async {
    final String target = category ?? _category;
    final int request = ++_tagRequest;
    setState(() {
      _loadingTags = true;
      _tagsError = null;
    });
    try {
      final List<String> tags = await _api.fetchTags(target);
      if (!mounted || request != _tagRequest) return;
      setState(() {
        _categoryTags = tags;
        _loadingTags = false;
      });
    } catch (_) {
      if (!mounted || request != _tagRequest) return;
      setState(() {
        _categoryTags = const <String>[];
        _tagsError = 'Không tải được thẻ tag cho danh mục này.';
        _loadingTags = false;
      });
    }
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _uploadTicker?.cancel();
    _uploadWatch.stop();
    _title.removeListener(_onTitleChanged);
    _title.dispose();
    _description.dispose();
    _hashtag.dispose();
    super.dispose();
  }

  List<String> get _suggestedTags {
    final selected = _tags.map((String tag) => tag.toLowerCase()).toSet();
    return _categoryTags
        .where((String tag) => !selected.contains(tag.toLowerCase()))
        .toList();
  }

  void _addSuggestedTag(String tag) {
    final String value = tag.trim().replaceFirst(RegExp(r'^#+'), '').trim();
    if (value.isEmpty) return;
    if (!_tags.any(
      (String item) => item.toLowerCase() == value.toLowerCase(),
    )) {
      setState(() => _tags.add(value));
    }
  }

  void _addTag() {
    final String value = _hashtag.text
        .trim()
        .replaceFirst(RegExp(r'^#+'), '')
        .trim();
    if (value.isEmpty) return;
    _addSuggestedTag(value);
    _hashtag.clear();
  }

  void _changeCategory(String value) {
    if (value == _category) return;
    setState(() {
      _category = value;
      _tags.clear();
      _categoryTags = const <String>[];
    });
    _loadCategoryTags(value);
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
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
        _uploadProgress = 0;
        _uploadComplete = false;
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

    setState(() {
      _uploading = true;
      _uploadComplete = false;
      _uploadProgress = 0;
    });
    _uploadWatch
      ..reset()
      ..start();
    _uploadTicker?.cancel();
    _uploadTicker = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted && _uploading) setState(() {});
    });

    try {
      final video = await _api.uploadVideo(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        tags: _tags,
        kidsOnly: _kidsOnly,
        bytes: _bytes!,
        filename: _file!.name,
        onProgress: (double progress) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _uploadProgress = 1;
        _uploadComplete = true;
      });
      // Giữ thanh tiến trình ở 100% một nhịp để người dùng thấy đã xong.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      _notify('Đã đăng video “${video.title}” lên Cloudinary + Neon.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadComplete = false;
        _uploadProgress = 0;
      });
      _notify(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadComplete = false;
        _uploadProgress = 0;
      });
      _notify('Tải video thất bại: $error');
    } finally {
      _uploadTicker?.cancel();
      _uploadTicker = null;
      _uploadWatch.stop();
      if (mounted && !_uploadComplete) {
        setState(() => _uploading = false);
      }
    }
  }

  String get _uploadStatus {
    if (_uploadComplete) return 'Đăng video thành công';
    if (_uploadProgress >= 1) return 'Đang xử lý trên Cloudinary...';
    return 'Đang tải video lên Cloudinary...';
  }

  String get _uploadSpeedLabel {
    if (_uploadProgress <= 0 || !_uploading) return 'Đang kết nối...';
    final double seconds = _uploadWatch.elapsedMilliseconds / 1000;
    if (seconds < 0.3) return 'Đang tính...';
    final int uploaded = ((_bytes?.length ?? 0) * _uploadProgress).round();
    final double bytesPerSecond = uploaded / seconds;
    if (bytesPerSecond >= 1024 * 1024) {
      final String value = (bytesPerSecond / (1024 * 1024))
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return '$value MB/s';
    }
    if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${bytesPerSecond.toStringAsFixed(0)} B/s';
  }

  String get _uploadRemainingLabel {
    if (_uploadComplete) return 'Hoàn tất';
    if (_uploadProgress >= 1) return 'Chờ máy chủ phản hồi';
    final double seconds = _uploadWatch.elapsedMilliseconds / 1000;
    final int total = _bytes?.length ?? 0;
    final int uploaded = (total * _uploadProgress).round();
    if (uploaded <= 0 || seconds < 0.3 || total <= uploaded) {
      return 'Đang tính...';
    }
    final double speed = uploaded / seconds;
    final int secondsLeft = ((total - uploaded) / speed).ceil();
    return 'Còn lại ${secondsLeft ~/ 60}:'
        '${(secondsLeft % 60).toString().padLeft(2, '0')}';
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
            title: 'Đăng video',
            onBack: () => Navigator.of(context).maybePop(),
            onHome: _goHome,
            onAccount: _openAccount,
            onStats: _openStats,
            onSearch: _goHome,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 20,
                  compact ? 14 : 20,
                  compact ? 14 : 20,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool wide = constraints.maxWidth >= 880;

                            final Widget form = _UploadForm(
                              compact: compact,
                              titleController: _title,
                              descriptionController: _description,
                              hashtagController: _hashtag,
                              tags: _tags,
                              suggestedTags: _suggestedTags,
                              category: _category,
                              loadingTags: _loadingTags,
                              tagsError: _tagsError,
                              file: _file,
                              kidsOnly: _kidsOnly,
                              picked: _file != null,
                              fileName: _file?.name,
                              fileSizeLabel: _fileSizeLabel,
                              uploading: _uploading,
                              uploadProgress: _uploadProgress,
                              uploadStatus: _uploadStatus,
                              uploadSpeedLabel: _uploadSpeedLabel,
                              uploadRemainingLabel: _uploadRemainingLabel,
                              uploadComplete: _uploadComplete,
                              onPick: _pickVideo,
                              onCategory: _changeCategory,
                              onKids: (bool value) =>
                                  setState(() => _kidsOnly = value),
                              onRemoveTag: (String tag) =>
                                  setState(() => _tags.remove(tag)),
                              onAddTag: _addTag,
                              onAddSuggestedTag: _addSuggestedTag,
                              onRetryTags: () => _loadCategoryTags(),
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
                              file: _file,
                              uploading: _uploading,
                            );

                            if (!wide) {
                              return Column(
                                children: <Widget>[
                                  form,
                                  if (!compact) ...<Widget>[
                                    const SizedBox(height: 24),
                                    preview,
                                  ],
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
          ),
        ],
      ),
    );
  }
}

class _UploadForm extends StatelessWidget {
  const _UploadForm({
    required this.compact,
    required this.titleController,
    required this.descriptionController,
    required this.hashtagController,
    required this.tags,
    required this.suggestedTags,
    required this.category,
    required this.loadingTags,
    required this.tagsError,
    required this.file,
    required this.kidsOnly,
    required this.picked,
    required this.fileName,
    required this.fileSizeLabel,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadStatus,
    required this.uploadSpeedLabel,
    required this.uploadRemainingLabel,
    required this.uploadComplete,
    required this.onPick,
    required this.onCategory,
    required this.onKids,
    required this.onRemoveTag,
    required this.onAddTag,
    required this.onAddSuggestedTag,
    required this.onRetryTags,
    required this.onCancel,
    required this.onSubmit,
    required this.onCover,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController hashtagController;
  final List<String> tags;
  final List<String> suggestedTags;
  final String category;
  final bool loadingTags;
  final String? tagsError;
  final PlatformFile? file;
  final bool compact;
  final bool kidsOnly;
  final bool picked;
  final String? fileName;
  final String fileSizeLabel;
  final bool uploading;
  final double uploadProgress;
  final String uploadStatus;
  final String uploadSpeedLabel;
  final String uploadRemainingLabel;
  final bool uploadComplete;
  final VoidCallback onPick;
  final ValueChanged<String> onCategory;
  final ValueChanged<bool> onKids;
  final ValueChanged<String> onRemoveTag;
  final VoidCallback onAddTag;
  final ValueChanged<String> onAddSuggestedTag;
  final VoidCallback onRetryTags;
  final VoidCallback? onCancel;
  final VoidCallback onSubmit;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 22,
        compact ? 16 : 22,
        compact ? 16 : 22,
        compact ? 18 : 24,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(compact ? 14 : 10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tải video',
            style: TextStyle(
              fontSize: compact ? 18 : 20,
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
          if (compact) ...<Widget>[
            const SizedBox(height: 16),
            _MobileVideoPreview(
              title: titleController.text.trim(),
              file: file,
              uploading: uploading,
            ),
          ],
          const SizedBox(height: 20),
          const _FormSectionHeader(
            title: 'Thông tin video',
            subtitle: 'Tiêu đề, danh mục, mô tả và thẻ tag',
          ),
          const SizedBox(height: 14),
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
                      DropdownMenuItem<String>(value: item, child: Text(item)),
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
          const _Label('Thẻ tag'),
          Text(
            'Gợi ý lấy từ danh mục “$category” trong SQL.',
            style: TextStyle(fontSize: 10.5, color: p.textSecondary),
          ),
          const SizedBox(height: 8),
          if (tags.isNotEmpty) ...<Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String tag in tags)
                  _HashtagChip(label: tag, onRemove: () => onRemoveTag(tag)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          _CategoryTagSuggestions(
            tags: suggestedTags,
            loading: loadingTags,
            error: tagsError,
            onAdd: onAddSuggestedTag,
            onRetry: onRetryTags,
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
                      hint: 'Thêm tag khác (VD: #game)',
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
          const SizedBox(height: 20),
          const _FormSectionHeader(
            title: 'Cài đặt video',
            subtitle: 'Ảnh bìa và đối tượng người xem',
          ),
          const SizedBox(height: 14),
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
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: <Widget>[
              _AgeOption(
                label: 'Video cho trẻ em',
                selected: kidsOnly,
                onTap: () => onKids(true),
              ),
              _AgeOption(
                label: 'Video trên 18 tuổi',
                selected: !kidsOnly,
                onTap: () => onKids(false),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (uploading || uploadProgress > 0 || uploadComplete) ...<Widget>[
            _UploadProgressCard(
              progress: uploadProgress,
              status: uploadStatus,
              speedLabel: uploadSpeedLabel,
              remainingLabel: uploadRemainingLabel,
              complete: uploadComplete,
            ),
            const SizedBox(height: 18),
          ],
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
                                child: uploadComplete
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: p.surface,
                                      )
                                    : CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: p.surface,
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                uploadComplete
                                    ? 'Đã đăng'
                                    : uploadProgress >= 1
                                    ? 'Đang xử lý...'
                                    : '${(uploadProgress * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Đăng video',
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

class _FormSectionHeader extends StatelessWidget {
  const _FormSectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: p.brandRed,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: p.textPrimary,
              ),
            ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 3),
            child: Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: p.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// Gợi ý thẻ tag được tải từ bảng `the_tag` theo danh mục đang chọn.
class _CategoryTagSuggestions extends StatelessWidget {
  const _CategoryTagSuggestions({
    required this.tags,
    required this.loading,
    required this.error,
    required this.onAdd,
    required this.onRetry,
  });

  final List<String> tags;
  final bool loading;
  final String? error;
  final ValueChanged<String> onAdd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (loading) {
      return Row(
        children: <Widget>[
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: p.brandRed,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Đang tải thẻ tag từ SQL...',
            style: TextStyle(fontSize: 10.5, color: p.textSecondary),
          ),
        ],
      );
    }

    if (error != null) {
      return Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, size: 14, color: p.brandRed),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error!,
              style: TextStyle(fontSize: 10.5, color: p.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: p.brandRed,
              textStyle: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Thử lại'),
          ),
        ],
      );
    }

    if (tags.isEmpty) {
      return Text(
        'Danh mục này chưa có thẻ tag trong SQL. Bạn vẫn có thể tự thêm.',
        style: TextStyle(fontSize: 10.5, color: p.textSecondary),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final String tag in tags)
          _SuggestedHashtagChip(label: tag, onTap: () => onAdd(tag)),
      ],
    );
  }
}

class _SuggestedHashtagChip extends StatelessWidget {
  const _SuggestedHashtagChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 4, 8, 4),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 11, color: p.brandRed),
              const SizedBox(width: 3),
              Text(
                '#$label',
                style: TextStyle(fontSize: 10.5, color: p.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khung xem trước gọn dành cho điện thoại.
///
/// Bản desktop dùng mockup điện thoại bên phải form; trên màn hình nhỏ,
/// mockup đó quá cao và chiếm chỗ nên thay bằng khung 16:9 ngay trong form.
class _MobileVideoPreview extends StatelessWidget {
  const _MobileVideoPreview({
    required this.title,
    required this.file,
    required this.uploading,
  });

  final String title;
  final PlatformFile? file;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool hasFile = file != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.smart_display_outlined,
              size: 16,
              color: p.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Xem trước video',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const Spacer(),
            if (hasFile)
              Flexible(
                child: Text(
                  file!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: uploading
                    ? p.brandRed.withValues(alpha: 0.55)
                    : p.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (file != null)
                    _VideoPreviewPlayer(file: file!, title: title)
                  else
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color(0xFF10232C),
                            Color(0xFF3B2D61),
                            Color(0xFF080808),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    top: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'XEM TRƯỚC',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  if (!hasFile)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 25,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Chọn video để xem trước',
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadProgressCard extends StatelessWidget {
  const _UploadProgressCard({
    required this.progress,
    required this.status,
    required this.speedLabel,
    required this.remainingLabel,
    required this.complete,
  });

  final double progress;
  final String status;
  final String speedLabel;
  final String remainingLabel;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const Color success = Color(0xFF2E9E62);
    final Color accent = complete ? success : p.brandRed;
    final double value = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
    final int percent = (value * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: complete ? success.withValues(alpha: 0.4) : p.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                complete
                    ? Icons.check_circle_rounded
                    : Icons.cloud_upload_outlined,
                size: 17,
                color: accent,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: p.chip,
              color: accent,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  complete ? 'Đã lưu vào Neon' : 'Tốc độ: $speedLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                complete ? 'Hoàn tất' : remainingLabel,
                style: TextStyle(fontSize: 10.5, color: p.textSecondary),
              ),
            ],
          ),
        ],
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
            Text(label, style: TextStyle(fontSize: 11.5, color: p.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _VideoPreviewPlayer extends StatefulWidget {
  const _VideoPreviewPlayer({required this.file, required this.title});

  final PlatformFile file;
  final String title;

  @override
  State<_VideoPreviewPlayer> createState() => _VideoPreviewPlayerState();
}

class _VideoPreviewPlayerState extends State<_VideoPreviewPlayer> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _muted = kIsWeb;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant _VideoPreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.uri != widget.file.uri ||
        oldWidget.file.name != widget.file.name) {
      _replace();
    }
  }

  Future<void> _open() async {
    final int generation = ++_generation;
    final VideoPlayerController controller = createPlatformVideoController(
      widget.file,
    );
    _controller = controller;
    if (mounted) {
      setState(() => _error = null);
    }
    try {
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      try {
        await controller.setVolume(_muted ? 0 : 1);
        await controller.play();
      } catch (_) {
        // Autoplay có thể bị trình duyệt chặn; nút play vẫn dùng được.
      }
      if (mounted && generation == _generation) setState(() {});
    } catch (error) {
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      if (identical(_controller, controller)) _controller = null;
      setState(() => _error = error);
      await controller.dispose();
    }
  }

  void _replace() {
    final VideoPlayerController? old = _controller;
    _controller = null;
    _generation++;
    old?.dispose();
    if (mounted) {
      setState(() => _error = null);
    }
    _open();
  }

  @override
  void dispose() {
    _generation++;
    final VideoPlayerController? controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _toggleMute() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null) return;
    final bool muted = !_muted;
    await controller.setVolume(muted ? 0 : 1);
    if (mounted) setState(() => _muted = muted);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final VideoPlayerController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      if (_error != null) {
        return _PreviewPlaybackError(title: widget.title);
      }
      return const ColoredBox(
        color: Color(0xFF080808),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (BuildContext context, VideoPlayerValue value, Widget? _) {
        if (value.hasError) {
          return _PreviewPlaybackError(title: widget.title);
        }
        final Size size = value.size;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _togglePlay(),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const ColoredBox(color: Colors.black),
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: size.width > 0 ? size.width : 16,
                  height: size.height > 0 ? size.height : 9,
                  child: VideoPlayer(controller),
                ),
              ),
              if (!value.isPlaying)
                Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
              Positioned(
                top: 7,
                right: 7,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.only(top: 6),
                  colors: VideoProgressColors(
                    playedColor: p.brandRed,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewPlaybackError extends StatelessWidget {
  const _PreviewPlaybackError({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF10232C),
            Color(0xFF3B2D61),
            Color(0xFF080808),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.videocam_off_outlined,
                size: 28,
                color: Colors.white70,
              ),
              const SizedBox(height: 7),
              const Text(
                'Không phát được video này',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (title.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({
    required this.title,
    required this.file,
    required this.uploading,
  });

  final String title;
  final PlatformFile? file;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool hasFile = file != null;

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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _VideoPreviewPlayer(file: file!, title: title),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'XEM TRƯỚC',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Colors.white70,
                                ),
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
                  const SizedBox(height: 6),
                  Text(
                    title.isEmpty ? 'Tiêu đề video' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file!.name,
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
