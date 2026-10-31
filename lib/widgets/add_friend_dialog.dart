import 'package:flutter/material.dart';

import '../data/chat_service.dart';
import '../models/chat_contact.dart';
import '../theme/app_theme.dart';

class AddFriendDialog extends StatefulWidget {
  const AddFriendDialog({super.key, this.onChatWithFriend});

  final ValueChanged<Friend>? onChatWithFriend;

  static Future<void> show(
    BuildContext context, {
    ValueChanged<Friend>? onChatWithFriend,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AddFriendDialog(onChatWithFriend: onChatWithFriend),
    );
  }

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _queryController = TextEditingController();
  List<Friend> _searchResults = <Friend>[];
  bool _searched = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _search() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searchResults = ChatService.instance.searchPotentialFriends(query);
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chatService = ChatService.instance;
    final requests = chatService.friendRequests;

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Header
              Row(
                children: <Widget>[
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    color: p.brandRed,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tìm kiếm bạn bè',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: p.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Nhập Số điện thoại hoặc Tên đăng nhập để kết nối trò chuyện & gọi điện:',
                style: TextStyle(fontSize: 12.5, color: p.textSecondary),
              ),
              const SizedBox(height: 16),

              // Search Input Form
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: p.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _queryController,
                        onSubmitted: (_) => _search(),
                        style: TextStyle(fontSize: 13, color: p.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Nhập số điện thoại hoặc tên đăng nhập...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: p.textSecondary.withValues(alpha: 0.8),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.brandRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Tìm Kiếm',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Results Area
              Expanded(
                child: ListView(
                  children: <Widget>[
                    if (_searched && _searchResults.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Không tìm thấy người dùng phù hợp.',
                            style: TextStyle(color: p.textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    else if (_searchResults.isNotEmpty) ...<Widget>[
                      Text(
                        'KẾT QUẢ TÌM KIẾM (${_searchResults.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final friend in _searchResults)
                        _buildUserCard(friend, p),
                    ],

                    // Danh sách lời mời kết bạn (nếu có)
                    if (requests.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        'LỜI MỜI KẾT BẠN (${requests.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final req in requests) _buildRequestCard(req, p),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Friend friend, PtPalette p) {
    final bool alreadyFriend = ChatService.instance.isFriend(friend.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: p.ctaGradient,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  friend.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  '${friend.username} • SĐT: ${friend.phone}',
                  style: TextStyle(fontSize: 11, color: p.textSecondary),
                ),
              ],
            ),
          ),
          if (alreadyFriend)
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onChatWithFriend?.call(friend);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Nhắn tin', style: TextStyle(fontSize: 12)),
            )
          else
            ElevatedButton.icon(
              onPressed: () async {
                await ChatService.instance.sendFriendRequest(friend);
                setState(() {});
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã kết bạn thành công với ${friend.name}!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Kết bạn', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.brandRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(FriendRequest req, PtPalette p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.brandRed,
            ),
            alignment: Alignment.center,
            child: Text(
              req.fromName.isNotEmpty ? req.fromName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  req.fromName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  'SĐT: ${req.phone} • ${req.time}',
                  style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await ChatService.instance.rejectFriendRequest(req.id);
              setState(() {});
            },
            child: Text(
              'Từ chối',
              style: TextStyle(fontSize: 12, color: p.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ChatService.instance.acceptFriendRequest(req);
              setState(() {});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã đồng ý kết bạn với ${req.fromName}!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: p.brandRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: const Text('Đồng ý', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

