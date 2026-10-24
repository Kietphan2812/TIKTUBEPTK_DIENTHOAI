import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/tiktube_api.dart';
import '../models/comment.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';

/// Bảng bình luận dùng trong feed xem nhanh (Shorts/QuickWatch).
///
/// Giao diện kính mờ trong suốt (Glassmorphism) giúp người xem vừa đọc/viết
/// bình luận vừa nhìn xuyên thấy video đang phát ở nền sau.
/// Hỗ trợ chọn icon/emoji biểu cảm nhanh và đính kèm hình ảnh/sticker vào bình luận.
class QuickCommentsSheet extends StatefulWidget {
  const QuickCommentsSheet({
    super.key,
    required this.api,
    required this.video,
    required this.author,
    required this.onCountChanged,
  });

  final TikTubeApi api;
  final Video video;
  final String author;
  final ValueChanged<int> onCountChanged;

  @override
  State<QuickCommentsSheet> createState() => _QuickCommentsSheetState();
}

class _QuickCommentsSheetState extends State<QuickCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Comment> _comments = <Comment>[];

  late int _count;
  bool _loading = true;
  bool _sending = false;
  String? _attachedImageUrl;
  String? _error;

  static const List<String> _quickEmojis = <String>[
    '❤️', '😂', '🔥', '👍', '😍', '👏', '🥺', '🎉',
    '💯', '🤣', '🤩', '🙏', '🥰', '🚀', '✨', '⚡',
    '😎', '😭', '🤯', '🥳', '💪', '💬', '👀', '☕',
  ];

  static const List<Map<String, String>> _sampleStickers = <Map<String, String>>[
    {
      'label': 'Tim bay',
      'url': 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?w=300&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Mèo vui',
      'url': 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=300&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Vỗ tay',
      'url': 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=300&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Chill',
      'url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=300&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _count = widget.video.commentCount;
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Comment> items = await widget.api.fetchComments(
        widget.video.id,
      );
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được bình luận. $error';
      });
    }
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = selection.start >= 0
        ? text.replaceRange(selection.start, selection.end, emoji)
        : '$text$emoji';
    final int newOffset = (selection.start >= 0 ? selection.start : text.length) +
        emoji.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  Future<void> _pickImage() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final p = ctx.palette;
        final urlController = TextEditingController();

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E222D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Đính kèm hình ảnh / sticker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final PlatformFile? file = await FilePicker.pickFile(
                      type: FileType.image,
                    );
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      if (bytes.isNotEmpty) {
                        final ext = (file.extension ?? 'jpg').toLowerCase();
                        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                        final base64String = base64Encode(bytes);
                        setState(() {
                          _attachedImageUrl = 'data:$mime;base64,$base64String';
                        });
                      }
                    }
                  } catch (_) {}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.brandRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Chọn ảnh từ thiết bị', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Hoặc chọn nhanh sticker mẫu:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sampleStickers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, int i) {
                    final item = _sampleStickers[i];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _attachedImageUrl = item['url']);
                        Navigator.of(ctx).pop();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 60,
                          height: 60,
                          color: Colors.white10,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              Image.network(item['url']!, fit: BoxFit.cover),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    item['label']!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 9.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Dán đường dẫn ảnh (URL)...',
                        hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final text = urlController.text.trim();
                      if (text.isNotEmpty) {
                        setState(() => _attachedImageUrl = text);
                        Navigator.of(ctx).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Thêm'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    final String rawText = _controller.text.trim();
    String content = rawText;
    if (_attachedImageUrl != null && _attachedImageUrl!.isNotEmpty) {
      if (content.isNotEmpty) {
        content = '$content\n[img:${_attachedImageUrl!}]';
      } else {
        content = '[img:${_attachedImageUrl!}]';
      }
    }

    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final Comment comment = await widget.api.addComment(
        widget.video.id,
        author: widget.author,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments.insert(0, comment);
        _count += 1;
        _sending = false;
        _controller.clear();
        _attachedImageUrl = null;
        _error = null;
      });
      widget.onCountChanged(_count);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Không gửi được bình luận. $error';
      });
    }
  }

  Future<void> _delete(Comment comment) async {
    final String? id = comment.id;
    if (id == null || id.isEmpty) return;
    try {
      await widget.api.deleteComment(widget.video.id, id);
      if (!mounted) return;
      setState(() {
        _comments.remove(comment);
        _count = (_count - 1).clamp(0, 1 << 30).toInt();
      });
      widget.onCountChanged(_count);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Không xoá được bình luận. $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.74,
            decoration: BoxDecoration(
              // Nền bán trong suốt sang trọng giúp nhìn xuyên ra sau thấy video đang chạy
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.2,
                ),
              ),
            ),
            child: Column(
              children: <Widget>[
                // Vạch tay kéo nhẹ
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                // Thanh tiêu đề
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Bình luận ($_count)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng bình luận',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
                // Danh sách bình luận
                Expanded(child: _buildList(p)),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      _error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
                    ),
                  ),

                // Xem trước ảnh đính kèm (nếu có)
                if (_attachedImageUrl != null && _attachedImageUrl!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _renderImageThumbnail(_attachedImageUrl!),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Đã đính kèm hình ảnh',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _attachedImageUrl = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Thanh Emoji cảm xúc nhanh
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickEmojis.length,
                    itemBuilder: (BuildContext _, int index) {
                      final emoji = _quickEmojis[index];
                      return GestureDetector(
                        onTap: () => _insertEmoji(emoji),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          alignment: Alignment.center,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Ô nhập bình luận + Nút Emoji / Ảnh / Gửi
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        // Nút chọn icon/ảnh
                        IconButton(
                          tooltip: 'Đính kèm ảnh hoặc sticker',
                          onPressed: _pickImage,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.image_outlined, color: Colors.white70, size: 22),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Thêm bình luận...',
                              hintStyle: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.12),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton.filled(
                            tooltip: 'Gửi bình luận',
                            onPressed: _sending ? null : _send,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFE2C55),
                              foregroundColor: Colors.white,
                            ),
                            icon: _sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 18),
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
    );
  }

  Widget _renderImageThumbnail(String source) {
    if (source.startsWith('data:image')) {
      try {
        final comma = source.indexOf(',');
        if (comma > 0) {
          final bytes = base64Decode(source.substring(comma + 1));
          return Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover);
        }
      } catch (_) {}
    }
    return Image.network(
      source,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: 40,
        height: 40,
        color: Colors.white12,
        child: const Icon(Icons.image, color: Colors.white54, size: 20),
      ),
    );
  }

  Widget _buildList(PtPalette p) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFE2C55),
          ),
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white54,
                size: 32,
              ),
              const SizedBox(height: 8),
              const Text(
                'Chưa có bình luận. Hãy là người đầu tiên!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _load,
                child: const Text('Tải lại', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final Comment comment = _comments[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 17,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: Text(
                comment.author.trim().isEmpty
                    ? '?'
                    : comment.author.trim().substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          comment.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (comment.date.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 6),
                        Text(
                          comment.date,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  _buildCommentBody(comment.content),
                ],
              ),
            ),
            if (comment.own)
              IconButton(
                tooltip: 'Xoá bình luận',
                visualDensity: VisualDensity.compact,
                onPressed: () => _delete(comment),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCommentBody(String rawContent) {
    final RegExp imgReg = RegExp(r'\[img:(.+?)\]');
    final match = imgReg.firstMatch(rawContent);
    final String? imgUrl = match?.group(1);
    final String cleanText = rawContent.replaceAll(imgReg, '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (cleanText.isNotEmpty)
          Text(
            cleanText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        if (imgUrl != null && imgUrl.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
              color: Colors.white10,
              child: _renderImageThumbnail(imgUrl),
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> showQuickCommentsSheet(
  BuildContext context, {
  required TikTubeApi api,
  required Video video,
  required String author,
  required ValueChanged<int> onCountChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => QuickCommentsSheet(
      api: api,
      video: video,
      author: author,
      onCountChanged: onCountChanged,
    ),
  );
}
