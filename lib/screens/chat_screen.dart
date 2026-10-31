import 'dart:async';
import 'package:flutter/material.dart';

import '../data/chat_service.dart';
import '../models/chat_contact.dart';
import '../theme/app_theme.dart';
import '../widgets/add_friend_dialog.dart';
import '../widgets/call_overlay.dart';
import '../widgets/section_top_bar.dart';

/// Bảng dải màu nghệ thuật cho Avatar người dùng
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
  int _activeTab = 0; // 0: Tin nhắn, 1: Bạn bè
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    unawaited(_chatService.init());
    _chatService.addListener(_onServiceChanged);

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
      // Trên desktop tự chọn bạn bè đầu tiên nếu có
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
    _chatService.removeListener(_onServiceChanged);
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectFriend(Friend friend) {
    setState(() => _selectedFriend = friend);
    _chatService.markAsRead(friend.id);
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

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _selectedFriend == null) return;

    _textController.clear();
    await _chatService.sendMessage(_selectedFriend!.id, text);
    _scrollToBottom();
  }

  void _showAddFriend() {
    AddFriendDialog.show(
      context,
      onChatWithFriend: (friend) {
        _selectFriend(friend);
      },
    );
  }

  void _makeAudioCall() {
    if (_selectedFriend == null) return;
    CallOverlay.startCall(
      context,
      friend: _selectedFriend!,
      isVideo: false,
    );
  }

  void _makeVideoCall() {
    if (_selectedFriend == null) return;
    CallOverlay.startCall(
      context,
      friend: _selectedFriend!,
      isVideo: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    final bool wide = width >= 720;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: <Widget>[
          SectionTopBar(
            title: 'Tin nhắn & Bạn bè',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: wide ? _buildWideLayout(p) : _buildMobileLayout(p),
          ),
        ],
      ),
    );
  }

  // Giao diện 2 cột trên máy tính / Web
  Widget _buildWideLayout(PtPalette p) {
    return Row(
      children: <Widget>[
        // Cột trái: Tìm kiếm, Tabs & Danh sách hội thoại
        SizedBox(
          width: 360,
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(right: BorderSide(color: p.border)),
            ),
            child: Column(
              children: <Widget>[
                _buildSearchAndAddBar(p),
                _buildSegmentedTabs(p),
                const SizedBox(height: 6),
                Expanded(
                  child: _activeTab == 0
                      ? _buildChatList(p)
                      : _buildContactsList(p),
                ),
              ],
            ),
          ),
        ),

        // Cột phải: Khung chat chi tiết
        Expanded(
          child: _selectedFriend != null
              ? _buildChatArea(p, _selectedFriend!)
              : _buildEmptyChatPlaceholder(p),
        ),
      ],
    );
  }

  // Giao diện điện thoại
  Widget _buildMobileLayout(PtPalette p) {
    if (_selectedFriend != null) {
      return Column(
        children: <Widget>[
          // Header cuộc trò chuyện với bạn bè
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => setState(() => _selectedFriend = null),
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  tooltip: 'Quay lại',
                ),
                _buildAvatar(_selectedFriend!, 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              _selectedFriend!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          if (_isSpecialAccount(_selectedFriend!.id)) ...<Widget>[
                            const SizedBox(width: 6),
                            _buildBadgeTag(_selectedFriend!.id, p),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E676),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _selectedFriend!.isOnline
                                ? 'Đang hoạt động'
                                : 'Hoạt động gần đây',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _makeAudioCall,
                  icon: Icon(
                    Icons.phone_outlined,
                    color: p.textPrimary,
                    size: 21,
                  ),
                  tooltip: 'Gọi thoại',
                ),
                IconButton(
                  onPressed: _makeVideoCall,
                  icon: Icon(
                    Icons.videocam_outlined,
                    color: p.textPrimary,
                    size: 23,
                  ),
                  tooltip: 'Gọi video',
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildChatArea(p, _selectedFriend!, showHeader: false),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        _buildSearchAndAddBar(p),
        _buildSegmentedTabs(p),
        const SizedBox(height: 6),
        Expanded(
          child: _activeTab == 0 ? _buildChatList(p) : _buildContactsList(p),
        ),
      ],
    );
  }

  // Thanh tìm kiếm và nút Kết bạn phong cách TIKTUBE
  Widget _buildSearchAndAddBar(PtPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
                        hintText: 'Tìm kiếm bạn bè, tin nhắn...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: p.textSecondary.withValues(alpha: 0.8),
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
          ),
          const SizedBox(width: 10),
          // Nút Thêm bạn dạng viên thuốc Gradient TIKTUBE
          InkWell(
            onTap: _showAddFriend,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: p.ctaGradient),
                borderRadius: BorderRadius.circular(999),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: p.brandRed.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Kết bạn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bộ chọn Tab dạng viên thuốc bo tròn Segmented Control
  Widget _buildSegmentedTabs(PtPalette p) {
    final unread = _chatService.totalUnread;
    final friendsCount = _chatService.friends.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.chip,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _activeTab == 0 ? p.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: _activeTab == 0
                        ? <BoxShadow>[
                            BoxShadow(
                              color: p.shadow,
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Tin nhắn',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _activeTab == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _activeTab == 0 ? p.textPrimary : p.textSecondary,
                        ),
                      ),
                      if (unread > 0) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: p.brandRed,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _activeTab == 1 ? p.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: _activeTab == 1
                        ? <BoxShadow>[
                            BoxShadow(
                              color: p.shadow,
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Bạn bè ($friendsCount)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _activeTab == 1
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _activeTab == 1 ? p.textPrimary : p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Danh sách hội thoại trò chuyện
  Widget _buildChatList(PtPalette p) {
    List<Friend> friends = _chatService.friends;
    if (_searchFilter.isNotEmpty) {
      friends = friends.where((f) {
        return f.name.toLowerCase().contains(_searchFilter) ||
            f.username.toLowerCase().contains(_searchFilter) ||
            f.lastMessage.toLowerCase().contains(_searchFilter);
      }).toList();
    }

    if (friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.chip,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 28,
                  color: p.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _searchFilter.isNotEmpty
                    ? 'Không tìm thấy cuộc trò chuyện'
                    : 'Chưa có tin nhắn nào',
                style: TextStyle(
                  fontSize: 14,
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
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _showAddFriend,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Tìm bạn bè ngay'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.brandRed,
                  side: BorderSide(color: p.brandRed.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: friends.length,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemBuilder: (context, index) {
        final friend = friends[index];
        final bool isSelected = _selectedFriend?.id == friend.id;

        return _buildContactTile(friend, p, isSelected: isSelected);
      },
    );
  }

  // Danh sách danh bạ bạn bè
  Widget _buildContactsList(PtPalette p) {
    List<Friend> friends = _chatService.friends;
    if (_searchFilter.isNotEmpty) {
      friends = friends.where((f) {
        return f.name.toLowerCase().contains(_searchFilter) ||
            f.username.toLowerCase().contains(_searchFilter) ||
            f.phone.contains(_searchFilter);
      }).toList();
    }

    if (friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.people_outline_rounded, size: 36, color: p.textSecondary),
              const SizedBox(height: 10),
              Text(
                'Danh bạ trống',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Thêm bạn bằng Số điện thoại hoặc Tên đăng nhập.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: p.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: friends.length,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemBuilder: (context, index) {
        final friend = friends[index];
        final bool isSelected = _selectedFriend?.id == friend.id;

        return _buildContactTile(friend, p, isSelected: isSelected, isContactMode: true);
      },
    );
  }

  // Item danh thiếp bạn bè / hội thoại
  Widget _buildContactTile(
    Friend friend,
    PtPalette p, {
    required bool isSelected,
    bool isContactMode = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? p.chip : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectFriend(friend),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: <Widget>[
                _buildAvatar(friend, 44),
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
                                fontSize: 13.5,
                                fontWeight: friend.unreadCount > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          if (_isSpecialAccount(friend.id)) ...<Widget>[
                            const SizedBox(width: 6),
                            _buildBadgeTag(friend.id, p),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isContactMode
                            ? (friend.statusMessage.isNotEmpty
                                ? friend.statusMessage
                                : '@${friend.username}')
                            : (friend.lastMessage.isNotEmpty
                                ? friend.lastMessage
                                : 'Bắt đầu cuộc trò chuyện...'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: friend.unreadCount > 0
                              ? p.textPrimary
                              : p.textSecondary,
                          fontWeight: friend.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (!isContactMode && friend.lastMessageTime.isNotEmpty)
                      Text(
                        friend.lastMessageTime,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: friend.unreadCount > 0
                              ? p.brandRed
                              : p.textSecondary,
                          fontWeight: friend.unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (friend.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.brandRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${friend.unreadCount}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
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
    );
  }

  // Khung chat chi tiết
  Widget _buildChatArea(PtPalette p, Friend friend, {bool showHeader = true}) {
    final messages = _chatService.getMessages(friend.id);

    return Column(
      children: <Widget>[
        // Header trên desktop
        if (showHeader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(
              children: <Widget>[
                _buildAvatar(friend, 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            friend.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                          if (_isSpecialAccount(friend.id)) ...<Widget>[
                            const SizedBox(width: 6),
                            _buildBadgeTag(friend.id, p),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E676),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            friend.isOnline ? 'Đang hoạt động' : 'Offline',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _makeAudioCall,
                  icon: Icon(Icons.phone_outlined, color: p.textPrimary, size: 21),
                  tooltip: 'Gọi thoại',
                ),
                IconButton(
                  onPressed: _makeVideoCall,
                  icon: Icon(Icons.videocam_outlined, color: p.textPrimary, size: 23),
                  tooltip: 'Gọi video',
                ),
              ],
            ),
          ),

        // Danh sách tin nhắn
        Expanded(
          child: messages.isEmpty
              ? Center(
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
                        'Hãy gửi lời chào để bắt đầu kết nối!',
                        style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg, p);
                  },
                ),
        ),

        // Thanh nhập tin nhắn
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
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
                        hintText: 'Nhập tin nhắn với ${friend.name}...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: p.textSecondary.withValues(alpha: 0.8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sendMessage,
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

  // Bong bóng tin nhắn
  Widget _buildMessageBubble(ChatMessage msg, PtPalette p) {
    if (msg.isCall) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.phone_forwarded_rounded,
                size: 14,
                color: p.brandRed,
              ),
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
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? null : p.surfaceAlt,
          gradient: isMe ? LinearGradient(colors: p.ctaGradient) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
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
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 13,
                color: isMe ? Colors.white : p.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              msg.time,
              style: TextStyle(
                fontSize: 9.5,
                color: isMe ? Colors.white.withValues(alpha: 0.8) : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder khi chưa chọn cuộc trò chuyện trên desktop
  Widget _buildEmptyChatPlaceholder(PtPalette p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.chip,
            ),
            child: Icon(
              Icons.forum_outlined,
              color: p.brandRed,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn một cuộc trò chuyện để bắt đầu',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
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

  bool _isSpecialAccount(String id) {
    return id == 'ptk_admin' || id == 'nhantin_ptk';
  }

  Widget _buildBadgeTag(String id, PtPalette p) {
    final isOfficial = id == 'ptk_admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: p.brandRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.brandRed.withValues(alpha: 0.25)),
      ),
      child: Text(
        isOfficial ? 'OFFICIAL' : 'AI',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: p.brandRed,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
