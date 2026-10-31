import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../auth/auth_scope.dart';
import '../data/chat_service.dart';
import '../models/chat_contact.dart';
import '../theme/app_theme.dart';
import '../widgets/add_friend_dialog.dart';
import '../widgets/call_overlay.dart';

/// Dải màu nghệ thuật cho Avatar người dùng
const List<List<Color>> _avatarGradients = <List<Color>>[
  <Color>[Color(0xFFFF2D55), Color(0xFFFF5277)], // Brand Red / Pink
  <Color>[Color(0xFFFF6B6B), Color(0xFFFF8E53)], // Sunset Coral
  <Color>[Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Neon Purple
  <Color>[Color(0xFF00B4DB), Color(0xFF0083B0)], // Ocean Blue
  <Color>[Color(0xFF11998E), Color(0xFF38EF7D)], // Emerald Teal
  <Color>[Color(0xFFFF9900), Color(0xFFFF5E62)], // Amber Gold
];

List<Color> _gradientFor(String name) {
  if (name.isEmpty) return _avatarGradients[0];
  final int code = name.codeUnits.fold<int>(0, (int a, int b) => a + b);
  return _avatarGradients[code % _avatarGradients.length];
}

/// Bộ lọc danh sách cuộc trò chuyện
enum _ChatFilter {
  all, // Tất cả tin nhắn
  unread, // Tin nhắn chưa đọc
  contacts, // Danh bạ bạn bè
  cloud, // Cloud của tôi
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialFriendId});

  final String? initialFriendId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService.instance;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Friend? _selectedFriend;
  _ChatFilter _filter = _ChatFilter.all;
  String _searchFilter = '';
  bool _isSearchVisible = false;
  bool _showEmojiPicker = false;
  StreamSubscription<Map<String, dynamic>>? _callSub;
  bool _isUploadingImage = false;
  bool _isSending = false;

  final List<String> _quickEmojis = const <String>[
    '👍',
    '❤️',
    '😂',
    '🔥',
    '🎉',
    '👋',
    '🙏',
    '👏',
    '😍',
    '🥰',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = AuthScope.maybeOf(context)?.profile;
    if (profile != null) {
      unawaited(_chatService.syncWithProfile(profile));
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_chatService.init());
    _chatService.addListener(_onServiceChanged);

    _callSub = _chatService.callEvents.listen((event) {
      if (!mounted) return;
      final type = event['type']?.toString();
      if (type == 'incoming') {
        final data = event['data'] as Map<String, dynamic>? ?? {};
        final caller = data['caller'] as Map<String, dynamic>? ?? {};
        final callerId = caller['id']?.toString() ?? '';
        final callerName = caller['name']?.toString() ?? 'Bạn bè';
        final isVideo = data['isVideo'] as bool? ?? false;

        final friend = _chatService.friends.firstWhere(
          (f) => f.id == callerId,
          orElse: () => Friend(
            id: callerId,
            name: callerName,
            username: caller['username']?.toString() ?? callerId,
            phone: caller['phone']?.toString() ?? '',
            avatar: caller['avatar']?.toString() ?? '',
          ),
        );

        CallOverlay.startCall(
          context,
          friend: friend,
          isVideo: isVideo,
          isIncoming: true,
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialFriendId != null) {
        final matches = _chatService.friends.where(
          (f) => f.id == widget.initialFriendId,
        );
        if (matches.isNotEmpty) {
          _selectFriend(matches.first);
          return;
        }
      }
      final double width = MediaQuery.sizeOf(context).width;
      if (width >= 720 && _chatService.friends.isNotEmpty) {
        _selectFriend(_chatService.friends.first);
      }
    });
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {
      if (_selectedFriend != null) {
        final updated = _chatService.friends.firstWhere(
          (f) => f.id == _selectedFriend!.id,
          orElse: () => _selectedFriend!,
        );
        _selectedFriend = updated;
      }
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _chatService.removeListener(_onServiceChanged);
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectFriend(Friend friend) {
    setState(() {
      _selectedFriend = friend;
      _showEmojiPicker = false;
    });
    _chatService.markAsRead(friend.id);
    _chatService.loadChatHistory(friend.id);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _textController.text.trim();
    if (text.isEmpty || _selectedFriend == null || _isSending) return;

    _isSending = true;
    if (quickText == null) {
      _textController.clear();
    }
    try {
      await _chatService.sendMessage(_selectedFriend!.id, text);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_selectedFriend == null || _isUploadingImage) return;

    try {
      final res = await FilePicker.pickFile(type: FileType.image);
      if (res == null) return;
      final bytes = await res.readAsBytes();
      if (bytes.isEmpty) return;

      setState(() => _isUploadingImage = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang tải ảnh lên Cloudinary & lưu Neon SQL...'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final url = await _chatService.uploadImage(bytes, res.name);
      if (url != null && url.isNotEmpty) {
        await _chatService.sendMessage(_selectedFriend!.id, '', imageUrl: url);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải ảnh: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _confirmRemoveFriend(Friend friend) {
    if (friend.id == 'my_cloud') return;
    showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_remove_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Xóa bạn bè',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa "${friend.name}" khỏi danh sách bạn bè không?\n\nQuan hệ bạn bè sẽ được hủy trên máy chủ Neon PostgreSQL.',
            style: TextStyle(fontSize: 13.5, height: 1.45, color: p.textSecondary),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Hủy', style: TextStyle(color: p.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Xác nhận xóa'),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        final name = friend.name;
        if (_selectedFriend?.id == friend.id) {
          setState(() => _selectedFriend = null);
        }
        await _chatService.removeFriend(friend.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa $name khỏi danh sách bạn bè'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _showAddFriend() {
    AddFriendDialog.show(
      context,
      onChatWithFriend: (friend) {
        _selectFriend(friend);
      },
    );
  }

  void _makeAudioCall([Friend? target]) {
    final friend = target ?? _selectedFriend;
    if (friend == null || friend.id == 'my_cloud') return;
    CallOverlay.startCall(
      context,
      friend: friend,
      isVideo: false,
    );
  }

  void _makeVideoCall([Friend? target]) {
    final friend = target ?? _selectedFriend;
    if (friend == null || friend.id == 'my_cloud') return;
    CallOverlay.startCall(
      context,
      friend: friend,
      isVideo: true,
    );
  }

  void _showFriendDetailsSheet(Friend friend) {
    final p = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                _buildAvatar(friend, 76),
                const SizedBox(height: 12),
                Text(
                  friend.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friend.phone.isNotEmpty
                      ? 'SĐT: ${friend.phone} • @${friend.username}'
                      : '@${friend.username}',
                  style: TextStyle(fontSize: 13, color: p.textSecondary),
                ),
                if (friend.statusMessage.isNotEmpty && friend.statusMessage != 'Đang hoạt động') ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      friend.statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: p.textSecondary),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (friend.id != 'my_cloud')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      _buildActionCircle(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Nhắn tin',
                        color: p.brandRed,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _selectFriend(friend);
                        },
                      ),
                      _buildActionCircle(
                        icon: Icons.phone_rounded,
                        label: 'Gọi thoại',
                        color: const Color(0xFF00C853),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _makeAudioCall(friend);
                        },
                      ),
                      _buildActionCircle(
                        icon: Icons.videocam_rounded,
                        label: 'Gọi video',
                        color: const Color(0xFF0088FF),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _makeVideoCall(friend);
                        },
                      ),
                      _buildActionCircle(
                        icon: Icons.person_remove_rounded,
                        label: 'Xóa bạn',
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _confirmRemoveFriend(friend);
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFriendRequestsSheet() {
    final p = context.palette;
    final requests = _chatService.friendRequests;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Icon(Icons.mail_rounded, color: p.brandRed, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Lời mời kết bạn (${requests.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (requests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: <Widget>[
                            Icon(Icons.mark_email_read_outlined, size: 44, color: p.textSecondary),
                            const SizedBox(height: 10),
                            Text(
                              'Không có lời mời kết bạn nào',
                              style: TextStyle(fontSize: 13.5, color: p.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: requests.length,
                          separatorBuilder: (context, index) => Divider(color: p.border, height: 1),
                          itemBuilder: (ctx, index) {
                            final req = requests[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: <Widget>[
                                  _buildAvatar(
                                    Friend(
                                      id: req.id,
                                      name: req.fromName,
                                      username: req.fromUsername,
                                      phone: req.phone,
                                      avatar: req.avatar,
                                    ),
                                    42,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          req.fromName,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: p.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          req.phone.isNotEmpty
                                              ? 'SĐT: ${req.phone} • @${req.fromUsername}'
                                              : '@${req.fromUsername}',
                                          style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await _chatService.acceptFriendRequest(req);
                                      setSheetState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00C853),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('Đồng ý', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    onPressed: () async {
                                      await _chatService.rejectFriendRequest(req.id);
                                      setSheetState(() {});
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: p.textSecondary,
                                      side: BorderSide(color: p.border),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text('Từ chối', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 720;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        top: true,
        bottom: false,
        child: wide ? _buildWideLayout(p) : _buildMobileLayout(p),
      ),
    );
  }

  // Layout 2 cột cho Desktop & Tablet
  Widget _buildWideLayout(PtPalette p) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 380,
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(right: BorderSide(color: p.border)),
            ),
            child: Column(
              children: <Widget>[
                _buildModernHeader(p, isWide: true),
                _buildSearchField(p),
                _buildActiveStoriesBar(p),
                _buildFilterChips(p),
                const SizedBox(height: 6),
                Expanded(
                  child: _filter == _ChatFilter.contacts
                      ? _buildContactsList(p)
                      : _buildConversationList(p),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _selectedFriend != null
              ? _buildChatArea(p, _selectedFriend!)
              : _buildEmptyChatPlaceholder(p),
        ),
      ],
    );
  }

  // Layout di động chuẩn Smartphone
  Widget _buildMobileLayout(PtPalette p) {
    if (_selectedFriend != null) {
      return _buildChatArea(p, _selectedFriend!, isMobileRoom: true);
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          _buildModernHeader(p, isWide: false),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _isSearchVisible
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildSearchField(p),
          ),
          _buildActiveStoriesBar(p),
          _buildFilterChips(p),
          const SizedBox(height: 6),
          Expanded(
            child: _filter == _ChatFilter.contacts
                ? _buildContactsList(p)
                : _buildConversationList(p),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriend,
        backgroundColor: p.brandRed,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.person_add_alt_1_rounded, size: 22),
      ),
    );
  }

  // Header hiện đại thay thế thanh debug cũ
  Widget _buildModernHeader(PtPalette p, {required bool isWide}) {
    final isOnline = _chatService.isConnected;
    final user = _chatService.currentUser;
    final profile = AuthScope.maybeOf(context)?.profile;
    final effectivePhone = (profile?.phone ?? user?.phone ?? '').trim();
    final displayName = user?.name ?? profile?.name ?? profile?.userKey ?? 'TIKTUBE User';
    final requestCount = _chatService.friendRequests.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: <Widget>[
          if (!isWide)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.arrow_back_rounded, color: p.textPrimary, size: 22),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Quay lại',
            ),
          if (!isWide) const SizedBox(width: 10),

          // Avatar tài khoản hiện tại với chấm xanh Neon SQL
          Stack(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: _gradientFor(displayName)),
                ),
                alignment: Alignment.center,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                    shape: BoxShape.circle,
                    border: Border.all(color: p.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Tên tài khoản & Trạng thái máy chủ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Tin nhắn & Bạn bè',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        isOnline
                            ? (effectivePhone.isNotEmpty
                                ? 'Neon SQL • $effectivePhone'
                                : 'Neon SQL Online')
                            : 'Đang kết nối Neon SQL...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOnline ? const Color(0xFF00C853) : const Color(0xFFFF9100),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cụm nút hành động nhanh
          IconButton(
            icon: Icon(
              _isSearchVisible ? Icons.search_off_rounded : Icons.search_rounded,
              color: p.textPrimary,
              size: 22,
            ),
            tooltip: 'Tìm kiếm',
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchController.clear();
                  _searchFilter = '';
                }
              });
            },
          ),
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.mail_outline_rounded, color: p.textPrimary, size: 21),
                tooltip: 'Lời mời kết bạn',
                onPressed: _showFriendRequestsSheet,
              ),
              if (requestCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$requestCount',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.person_add_outlined, color: p.brandRed, size: 22),
            tooltip: 'Thêm bạn mới',
            onPressed: _showAddFriend,
          ),
        ],
      ),
    );
  }

  // Khung tìm kiếm mượt mà
  Widget _buildSearchField(PtPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            Icon(Icons.search_rounded, size: 18, color: p.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                style: TextStyle(fontSize: 13, color: p.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên, SĐT, tin nhắn...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: p.textSecondary.withValues(alpha: 0.75),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchFilter.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchFilter = '');
                },
                child: Icon(Icons.close_rounded, size: 16, color: p.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  // Carousel "Khoảnh khắc & Bạn bè đang Online" (Stories / Active Bar)
  Widget _buildActiveStoriesBar(PtPalette p) {
    final friends = _chatService.friends;

    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          final isCloud = friend.id == 'my_cloud';

          return GestureDetector(
            onTap: () => _selectFriend(friend),
            child: Container(
              width: 66,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      // Viền phát sáng nhẹ quanh avatar đang online
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCloud
                                ? const Color(0xFF0088FF)
                                : (friend.isOnline
                                    ? const Color(0xFF00E676)
                                    : p.border),
                            width: 2,
                          ),
                        ),
                      ),
                      _buildAvatar(friend, 44),
                      if (friend.isOnline && !isCloud)
                        Positioned(
                          right: 3,
                          bottom: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676),
                              shape: BoxShape.circle,
                              border: Border.all(color: p.surface, width: 2),
                            ),
                          ),
                        ),
                      if (isCloud)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0088FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isCloud ? 'Cloud cá nhân' : friend.name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Bộ chọn Filter Chips hiện đại
  Widget _buildFilterChips(PtPalette p) {
    final unread = _chatService.totalUnread;
    final friendsCount = _chatService.friends.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: <Widget>[
          _buildFilterChip(
            label: 'Tất cả',
            selected: _filter == _ChatFilter.all,
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () => setState(() => _filter = _ChatFilter.all),
            p: p,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Chưa đọc',
            badge: unread > 0 ? '$unread' : null,
            selected: _filter == _ChatFilter.unread,
            icon: Icons.mark_chat_unread_outlined,
            onTap: () => setState(() => _filter = _ChatFilter.unread),
            p: p,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Danh bạ ($friendsCount)',
            selected: _filter == _ChatFilter.contacts,
            icon: Icons.contacts_outlined,
            onTap: () => setState(() => _filter = _ChatFilter.contacts),
            p: p,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Cloud của tôi',
            selected: _filter == _ChatFilter.cloud,
            icon: Icons.cloud_outlined,
            onTap: () {
              setState(() => _filter = _ChatFilter.cloud);
              final cloud = _chatService.friends.firstWhere(
                (f) => f.id == 'my_cloud',
                orElse: () => ChatService.myCloud,
              );
              _selectFriend(cloud);
            },
            p: p,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required IconData icon,
    required VoidCallback onTap,
    required PtPalette p,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? p.brandRed : p.chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? p.brandRed : p.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : p.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : p.textPrimary,
              ),
            ),
            if (badge != null) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : p.brandRed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? p.brandRed : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Danh sách hội thoại trò chuyện phong cách di động
  Widget _buildConversationList(PtPalette p) {
    List<Friend> friends = _chatService.friends;

    if (_filter == _ChatFilter.unread) {
      friends = friends.where((f) => f.unreadCount > 0).toList();
    } else if (_filter == _ChatFilter.cloud) {
      friends = friends.where((f) => f.id == 'my_cloud').toList();
    }

    if (_searchFilter.isNotEmpty) {
      friends = friends.where((f) {
        return f.name.toLowerCase().contains(_searchFilter) ||
            f.username.toLowerCase().contains(_searchFilter) ||
            f.phone.contains(_searchFilter) ||
            f.lastMessage.toLowerCase().contains(_searchFilter);
      }).toList();
    }

    if (friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.chip,
                ),
                child: Icon(
                  _filter == _ChatFilter.unread
                      ? Icons.done_all_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 32,
                  color: p.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _filter == _ChatFilter.unread
                    ? 'Không có tin nhắn chưa đọc'
                    : (_searchFilter.isNotEmpty
                        ? 'Không tìm thấy cuộc trò chuyện'
                        : 'Chưa có cuộc trò chuyện nào'),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Kết nối và nhắn tin với bạn bè trên TIKTUBE ngay.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: p.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showAddFriend,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Tìm bạn bè ngay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.brandRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: friends.length,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      itemBuilder: (context, index) {
        final friend = friends[index];
        final bool isSelected = _selectedFriend?.id == friend.id;

        return _buildConversationCard(friend, p, isSelected: isSelected);
      },
    );
  }

  // Thẻ cuộc trò chuyện phong cách di động hiện đại
  Widget _buildConversationCard(
    Friend friend,
    PtPalette p, {
    required bool isSelected,
  }) {
    final isCloud = friend.id == 'my_cloud';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? p.chip : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectFriend(friend),
          onLongPress: () => _showFriendDetailsSheet(friend),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: <Widget>[
                _buildAvatar(friend, 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              friend.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: friend.unreadCount > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          if (isCloud) ...<Widget>[
                            const SizedBox(width: 6),
                            _buildBadgeTag(friend.id, p),
                          ],
                          const Spacer(),
                          if (friend.lastMessageTime.isNotEmpty)
                            Text(
                              friend.lastMessageTime,
                              style: TextStyle(
                                fontSize: 11,
                                color: friend.unreadCount > 0
                                    ? p.brandRed
                                    : p.textSecondary,
                                fontWeight: friend.unreadCount > 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              isCloud
                                  ? (friend.lastMessage.isNotEmpty
                                      ? friend.lastMessage
                                      : 'Lưu trữ đám mây cá nhân vĩnh viễn')
                                  : (friend.lastMessage.isNotEmpty
                                      ? friend.lastMessage
                                      : 'Bắt đầu cuộc trò chuyện với bạn bè...'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: friend.unreadCount > 0
                                    ? p.textPrimary
                                    : p.textSecondary,
                                fontWeight: friend.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (friend.unreadCount > 0) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: p.brandRed,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${friend.unreadCount}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Danh bạ bạn bè phong cách Zalo / Điện thoại
  Widget _buildContactsList(PtPalette p) {
    List<Friend> friends = _chatService.friends.where((f) => f.id != 'my_cloud').toList();
    if (_searchFilter.isNotEmpty) {
      friends = friends.where((f) {
        return f.name.toLowerCase().contains(_searchFilter) ||
            f.username.toLowerCase().contains(_searchFilter) ||
            f.phone.contains(_searchFilter);
      }).toList();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      children: <Widget>[
        // Mục Thêm bạn mới
        _buildContactActionTile(
          icon: Icons.person_add_rounded,
          color: const Color(0xFF8E2DE2),
          title: 'Thêm bạn mới',
          subtitle: 'Tìm bạn bè qua Số điện thoại hoặc Username',
          onTap: _showAddFriend,
          p: p,
        ),
        // Lời mời kết bạn
        _buildContactActionTile(
          icon: Icons.mail_rounded,
          color: const Color(0xFFFF6B6B),
          title: 'Lời mời kết bạn',
          subtitle: _chatService.friendRequests.isNotEmpty
              ? 'Có ${_chatService.friendRequests.length} lời mời đang chờ'
              : 'Chưa có lời mời mới',
          badgeCount: _chatService.friendRequests.length,
          onTap: _showFriendRequestsSheet,
          p: p,
        ),
        // Cloud của tôi
        _buildContactActionTile(
          icon: Icons.cloud_rounded,
          color: const Color(0xFF0088FF),
          title: 'Cloud của tôi',
          subtitle: 'Lưu trữ đám mây cá nhân an toàn',
          onTap: () {
            final cloud = _chatService.friends.firstWhere(
              (f) => f.id == 'my_cloud',
              orElse: () => ChatService.myCloud,
            );
            _selectFriend(cloud);
          },
          p: p,
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            'BẠN BÈ (${friends.length})',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: p.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (friends.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Danh bạ bạn bè đang trống.\nHãy nhấn "Thêm bạn mới" để kết nối!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: p.textSecondary),
              ),
            ),
          )
        else
          ...friends.map((friend) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border.withValues(alpha: 0.5)),
              ),
              child: ListTile(
                onTap: () => _selectFriend(friend),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                leading: _buildAvatar(friend, 44),
                title: Text(
                  friend.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                subtitle: Text(
                  friend.phone.isNotEmpty
                      ? 'SĐT: ${friend.phone}'
                      : '@${friend.username}',
                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.chat_bubble_outline_rounded, color: p.brandRed, size: 20),
                      tooltip: 'Nhắn tin',
                      onPressed: () => _selectFriend(friend),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone_outlined, color: Color(0xFF00C853), size: 20),
                      tooltip: 'Gọi thoại',
                      onPressed: () => _makeAudioCall(friend),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert_rounded, color: p.textSecondary, size: 20),
                      tooltip: 'Tùy chọn',
                      onPressed: () => _showFriendDetailsSheet(friend),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildContactActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required PtPalette p,
    int badgeCount = 0,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border.withValues(alpha: 0.6)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            if (badgeCount > 0) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.5, color: p.textSecondary),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 20),
      ),
    );
  }

  // Khung chat chi tiết với bạn bè / Cloud
  Widget _buildChatArea(
    PtPalette p,
    Friend friend, {
    bool isMobileRoom = false,
  }) {
    final messages = _chatService.getMessages(friend.id);
    final isCloud = friend.id == 'my_cloud';

    return Column(
      children: <Widget>[
        // Top App Bar của phòng chat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: Row(
            children: <Widget>[
              if (isMobileRoom)
                IconButton(
                  onPressed: () => setState(() => _selectedFriend = null),
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  tooltip: 'Quay lại',
                ),
              _buildAvatar(friend, 40),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _showFriendDetailsSheet(friend),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                friend.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                            if (isCloud) ...<Widget>[
                              const SizedBox(width: 6),
                              _buildBadgeTag(friend.id, p),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 6.5,
                              height: 6.5,
                              decoration: BoxDecoration(
                                color: isCloud
                                    ? const Color(0xFF0088FF)
                                    : (friend.isOnline
                                        ? const Color(0xFF00E676)
                                        : Colors.grey),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isCloud
                                  ? 'Đám mây riêng tư'
                                  : (friend.isOnline
                                      ? 'Đang hoạt động'
                                      : 'Offline'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isCloud
                                    ? const Color(0xFF0088FF)
                                    : (friend.isOnline
                                        ? const Color(0xFF00E676)
                                        : p.textSecondary),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isCloud) ...<Widget>[
                IconButton(
                  onPressed: () => _makeAudioCall(friend),
                  icon: const Icon(Icons.phone_outlined, size: 21),
                  tooltip: 'Gọi thoại',
                ),
                IconButton(
                  onPressed: () => _makeVideoCall(friend),
                  icon: const Icon(Icons.videocam_outlined, size: 23),
                  tooltip: 'Gọi video',
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: p.textSecondary, size: 21),
                  tooltip: 'Tùy chọn',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: p.surface,
                  onSelected: (val) {
                    if (val == 'info') {
                      _showFriendDetailsSheet(friend);
                    } else if (val == 'remove') {
                      _confirmRemoveFriend(friend);
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'info',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.info_outline_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Xem thông tin', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'remove',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Xóa bạn bè',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Danh sách tin nhắn
        Expanded(
          child: messages.isEmpty
              ? (isCloud
                  ? Center(child: _buildCloudWelcomeCard(p))
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _buildAvatar(friend, 64),
                          const SizedBox(height: 12),
                          Text(
                            friend.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gửi lời chào ngay để bắt đầu trò chuyện! 👋',
                            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () => _sendMessage('Xin chào bạn! 👋'),
                            icon: const Icon(Icons.waving_hand_rounded, size: 16),
                            label: const Text('Gửi lời chào 👋'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.brandRed,
                              side: BorderSide(color: p.brandRed.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                          ),
                        ],
                      ),
                    ))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg, p);
                  },
                ),
        ),

        // Thanh chọn Emoji nhanh (nếu mở)
        if (_showEmojiPicker)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: p.surfaceAlt,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickEmojis.length,
              itemBuilder: (context, idx) {
                final emoji = _quickEmojis[idx];
                return InkWell(
                  onTap: () {
                    _textController.text += emoji;
                    _textController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _textController.text.length),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
          ),

        // Thanh nhập tin nhắn phong cách di động
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: _pickAndSendImage,
                  icon: _isUploadingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.image_outlined,
                          color: p.brandRed,
                          size: 22,
                        ),
                  tooltip: 'Gửi ảnh (Cloudinary)',
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _showEmojiPicker = !_showEmojiPicker);
                  },
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_rounded,
                    color: _showEmojiPicker ? p.brandRed : p.textSecondary,
                    size: 22,
                  ),
                  tooltip: 'Biểu cảm',
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.border),
                    ),
                    child: TextField(
                      controller: _textController,
                      onSubmitted: (_) => unawaited(_sendMessage()),
                      textInputAction: TextInputAction.send,
                      cursorColor: p.brandRed,
                      style: TextStyle(fontSize: 13.5, color: p.textPrimary),
                      decoration: InputDecoration(
                        hintText: isCloud
                            ? 'Lưu ghi chú, ảnh vào Cloud...'
                            : 'Nhập tin nhắn...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: p.textSecondary.withValues(alpha: 0.8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => unawaited(_sendMessage()),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: p.ctaGradient),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: p.brandRed.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Card chào đón Cloud của tôi
  Widget _buildCloudWelcomeCard(PtPalette p) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0088FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0088FF).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF0088FF),
            ),
            child: const Icon(Icons.cloud_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cloud của tôi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0088FF),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kho lưu trữ đám mây cá nhân an toàn. Tin nhắn và hình ảnh được lưu trữ vĩnh viễn trên Neon PostgreSQL & Cloudinary, chỉ mình bạn xem được.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: p.textSecondary),
          ),
        ],
      ),
    );
  }

  // Bong bóng tin nhắn phong cách smartphone
  Widget _buildMessageBubble(ChatMessage msg, PtPalette p) {
    if (msg.isCall) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.phone_forwarded_rounded, size: 14, color: p.brandRed),
              const SizedBox(width: 6),
              Text(
                '${msg.text} • ${msg.time}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool isMe = msg.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isMe ? null : p.surfaceAlt,
          gradient: isMe ? LinearGradient(colors: p.ctaGradient) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: isMe ? null : Border.all(color: p.border),
          boxShadow: isMe
              ? <BoxShadow>[
                  BoxShadow(
                    color: p.brandRed.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...<Widget>[
              GestureDetector(
                onTap: () => _showImagePreview(msg.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    msg.imageUrl!,
                    width: 210,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 210,
                        height: 140,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white70,
                      size: 40,
                    ),
                  ),
                ),
              ),
              if (msg.text.isNotEmpty) const SizedBox(height: 6),
            ],
            if (msg.text.isNotEmpty)
              Text(
                msg.text,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isMe ? Colors.white : p.textPrimary,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  msg.time,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isMe ? Colors.white.withValues(alpha: 0.8) : p.textSecondary,
                  ),
                ),
                if (isMe) ...<Widget>[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded, size: 12, color: Colors.white70),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder trống trên Desktop
  Widget _buildEmptyChatPlaceholder(PtPalette p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.chip),
            child: Icon(Icons.forum_outlined, color: p.brandRed, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn một cuộc trò chuyện để bắt đầu',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Kết nối, nhắn tin và gọi điện với bạn bè trên TIKTUBE.',
            style: TextStyle(fontSize: 12, color: p.textSecondary),
          ),
        ],
      ),
    );
  }

  // Avatar người dùng với gradient nghệ thuật & chấm online
  Widget _buildAvatar(Friend friend, double size) {
    if (friend.id == 'my_cloud' || friend.avatar == 'cloud_icon') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF0088FF), Color(0xFF0055FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF0088FF).withValues(alpha: 0.32),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.cloud_rounded,
          color: Colors.white,
          size: size * 0.54,
        ),
      );
    }

    final gradient = _gradientFor(friend.name);

    return Stack(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: gradient),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: gradient[0].withValues(alpha: 0.24),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.42,
            ),
          ),
        ),
        if (friend.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: const Color(0xFF00E676),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBadgeTag(String id, PtPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0088FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF0088FF).withValues(alpha: 0.3)),
      ),
      child: const Text(
        'CLOUD',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0088FF),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
