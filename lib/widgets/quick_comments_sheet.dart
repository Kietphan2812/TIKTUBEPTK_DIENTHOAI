import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tiktube_api.dart';
import '../models/comment.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';

/// Bảng bình luận dùng trong feed xem nhanh.
///
/// Bình luận thật được tải từ Neon, gửi bằng tài khoản đang đăng nhập và cập
/// nhật lại số lượng trên thanh hành động ngay khi gửi/xoá.
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
  final List<Comment> _comments = <Comment>[];

  late int _count;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _count = widget.video.commentCount;
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
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

  Future<void> _send() async {
    final String content = _controller.text.trim();
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
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.76,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Bình luận ($_count)',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng bình luận',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close_rounded, color: p.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),
            Expanded(child: _buildList(p)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  _error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.brandRed, fontSize: 11),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: TextStyle(color: p.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Viết bình luận...',
                          hintStyle: TextStyle(
                            color: p.textSecondary,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: p.surfaceAlt,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: p.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: p.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: p.brandRed),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: IconButton.filled(
                        tooltip: 'Gửi bình luận',
                        onPressed: _sending ? null : _send,
                        style: IconButton.styleFrom(
                          backgroundColor: p.brandRed,
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
                            : const Icon(Icons.send_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(PtPalette p) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: p.brandRed,
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
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: p.textSecondary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Chưa có bình luận. Hãy là người đầu tiên!',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: const Text('Tải lại')),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final Comment comment = _comments[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              radius: 17,
              backgroundColor: p.chip,
              child: Text(
                comment.author.trim().isEmpty
                    ? '?'
                    : comment.author.trim().substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 9),
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
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (comment.date.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 6),
                        Text(
                          comment.date,
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comment.content,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (comment.own)
              IconButton(
                tooltip: 'Xoá bình luận',
                visualDensity: VisualDensity.compact,
                onPressed: () => _delete(comment),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: p.textSecondary,
                  size: 18,
                ),
              ),
          ],
        );
      },
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
    builder: (_) => QuickCommentsSheet(
      api: api,
      video: video,
      author: author,
      onCountChanged: onCountChanged,
    ),
  );
}
