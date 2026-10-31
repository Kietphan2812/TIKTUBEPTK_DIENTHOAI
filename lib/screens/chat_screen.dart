import 'dart:async';
import 'package:flutter/material.dart';

import '../data/chat_service.dart';
import '../models/chat_contact.dart';
import '../theme/app_theme.dart';
import '../widgets/add_friend_dialog.dart';
import '../widgets/call_overlay.dart';
import '../widgets/section_top_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialFriendId});

  final String? initialFriendId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService.instance;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Friend? _selectedFriend;
  int _activeTab = 0; // 0: Tin nhắn, 1: Danh bạ bạn bè

  @override
  void initState() {
    super.initState();
    unawaited(_chatService.init());
    _chatService.addListener(_onServiceChanged);

    // Chọn bạn bè ban đầu nếu có
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
      if (_chatService.friends.isNotEmpty) {
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
            title: 'Tin nhắn & Bạn bè (ZaloChat PTK)',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: wide ? _buildWideLayout(p) : _buildMobileLayout(p),
          ),
        ],
      ),
    );
  }

  // Giao diện máy tính / Web rộng (2 cột Zalo PC)
  Widget _buildWideLayout(PtPalette p) {
    return Row(
      children: <Widget>[
        // Cột trái: Danh sách bạn bè & tab
        SizedBox(
          width: 330,
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(right: BorderSide(color: p.border)),
            ),
            child: Column(
              children: <Widget>[
                _buildSidebarHeader(p),
                _buildTabRow(p),
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
          // Header chat với nút Back
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
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  tooltip: 'Quay lại danh sách',
                ),
                _buildAvatar(_selectedFriend!, 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _selectedFriend!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        _selectedFriend!.statusMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF00C853),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _makeAudioCall,
                  icon: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Color(0xFF0068FF),
                  ),
                  tooltip: 'Gọi thoại',
                ),
                IconButton(
                  onPressed: _makeVideoCall,
                  icon: const Icon(
                    Icons.videocam_rounded,
                    color: Color(0xFF0068FF),
                  ),
                  tooltip: 'Gọi video',
                ),
              ],
            ),
          ),
          Expanded(child: _buildChatArea(p, _selectedFriend!, showHeader: false)),
        ],
      );
    }

    return Column(
      children: <Widget>[
        _buildSidebarHeader(p),
        _buildTabRow(p),
        Expanded(
          child: _activeTab == 0 ? _buildChatList(p) : _buildContactsList(p),
        ),
      ],
    );
  }

  Widget _buildSidebarHeader(PtPalette p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF0068FF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Color(0xFF0068FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ZaloChat PTK',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  'Nhắn tin & Gọi điện thời gian thực',
                  style: TextStyle(fontSize: 10.5, color: p.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showAddFriend,
            icon: const Icon(Icons.person_add_rounded, size: 15),
            label: const Text('Thêm bạn', style: TextStyle(fontSize: 11.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0068FF),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabRow(PtPalette p) {
    final unread = _chatService.totalUnread;

    return Container(
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _activeTab == 0
                          ? const Color(0xFF0068FF)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Tin nhắn',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: _activeTab == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _activeTab == 0
                            ? const Color(0xFF0068FF)
                            : p.textSecondary,
                      ),
                    ),
                    if (unread > 0) ...<Widget>[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: p.brandRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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
            child: InkWell(
              onTap: () => setState(() => _activeTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _activeTab == 1
                          ? const Color(0xFF0068FF)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Danh bạ (${_chatService.friends.length})',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        _activeTab == 1 ? FontWeight.w700 : FontWeight.w500,
                    color: _activeTab == 1
                        ? const Color(0xFF0068FF)
                        : p.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(PtPalette p) {
    final friends = _chatService.friends;
    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.chat_bubble_outline, size: 40, color: p.textSecondary),
            const SizedBox(height: 10),
            Text(
              'Chưa có tin nhắn nào',
              style: TextStyle(color: p.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _showAddFriend,
              child: const Text('Tìm kiếm và kết bạn ngay'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final f = friends[index];
        final bool selected = _selectedFriend?.id == f.id;

        return InkWell(
          onTap: () => _selectFriend(f),
          child: Container(
            color: selected
                ? const Color(0xFF0068FF).withValues(alpha: 0.1)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                _buildAvatar(f, 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              f.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: f.unreadCount > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            f.lastMessageTime,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: f.unreadCount > 0
                                  ? const Color(0xFF0068FF)
                                  : p.textSecondary,
                              fontWeight: f.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              f.lastMessage.isNotEmpty
                                  ? f.lastMessage
                                  : f.statusMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: f.unreadCount > 0
                                    ? p.textPrimary
                                    : p.textSecondary,
                                fontWeight: f.unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (f.unreadCount > 0) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: p.brandRed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${f.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
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
        );
      },
    );
  }

  Widget _buildContactsList(PtPalette p) {
    final friends = _chatService.friends;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        // Mục thêm bạn
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF0068FF),
            ),
            child: const Icon(Icons.person_add_rounded, color: Colors.white),
          ),
          title: Text(
            'Thêm bạn bè mới',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          subtitle: Text(
            'Tìm qua số điện thoại hoặc tên tài khoản',
            style: TextStyle(fontSize: 11, color: p.textSecondary),
          ),
          onTap: _showAddFriend,
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            'BẠN BÈ HIỆN TẠI (${friends.length})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: p.textSecondary,
            ),
          ),
        ),
        for (final f in friends)
          ListTile(
            leading: _buildAvatar(f, 40),
            title: Text(
              f.name,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            subtitle: Text(
              'SĐT: ${f.phone} • ${f.statusMessage}',
              style: TextStyle(fontSize: 11, color: p.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.phone_rounded, size: 20),
                  color: const Color(0xFF0068FF),
                  tooltip: 'Gọi thoại',
                  onPressed: () {
                    _selectFriend(f);
                    _makeAudioCall();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  color: p.textSecondary,
                  tooltip: 'Nhắn tin',
                  onPressed: () => _selectFriend(f),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChatArea(PtPalette p, Friend friend, {bool showHeader = true}) {
    final messages = _chatService.getMessages(friend.id);

    return Column(
      children: <Widget>[
        // Header khung chat chi tiết (Desktop)
        if (showHeader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(
              children: <Widget>[
                _buildAvatar(friend, 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        friend.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        'SĐT: ${friend.phone} • ${friend.statusMessage}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF00C853),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _makeAudioCall,
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: const Text('Gọi thoại', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0068FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _makeVideoCall,
                  icon: const Icon(Icons.videocam_rounded, size: 16),
                  label: const Text('Gọi video', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0049B7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Danh sách tin nhắn
        Expanded(
          child: Container(
            color: p.bg,
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildAvatar(friend, 64),
                        const SizedBox(height: 12),
                        Text(
                          'Bắt đầu cuộc trò chuyện với ${friend.name}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hai bạn đã là bạn bè trên TIKTUBE & ZaloChat!',
                          style: TextStyle(
                            fontSize: 12,
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageBubble(msg, p);
                    },
                  ),
          ),
        ),

        // Thanh nhập tin nhắn
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () {
                    _textController.text += ' 👍';
                  },
                  icon: const Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 20,
                    color: Color(0xFF0068FF),
                  ),
                  tooltip: 'Gửi like',
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.border),
                    ),
                    child: TextField(
                      controller: _textController,
                      onSubmitted: (_) => _sendMessage(),
                      style: TextStyle(fontSize: 13, color: p.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn tới ${friend.name}...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: p.textSecondary.withValues(alpha: 0.8),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0068FF),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    tooltip: 'Gửi tin nhắn',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, PtPalette p) {
    if (msg.isCall) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.phone_forwarded_rounded,
                size: 16,
                color: Color(0xFF0068FF),
              ),
              const SizedBox(width: 8),
              Text(
                '${msg.text} • ${msg.time}',
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

    final bool isMe = msg.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0068FF) : p.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
          border: isMe ? null : Border.all(color: p.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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
                color: isMe ? Colors.white70 : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              color: const Color(0xFF0068FF).withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF0068FF),
              size: 36,
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
            'Kết nối, nhắn tin và gọi điện với bạn bè qua ZaloChat PTK.',
            style: TextStyle(fontSize: 12, color: p.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Friend friend, double size) {
    return Stack(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF0068FF), Color(0xFF0049B7)],
            ),
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
                color: const Color(0xFF00C853),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
              ),
            ),
          ),
      ],
    );
  }
}

