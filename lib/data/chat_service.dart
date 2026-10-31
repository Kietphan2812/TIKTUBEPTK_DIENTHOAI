import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_contact.dart';

class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const String _prefFriendsKey = 'tiktube_friends_v1';
  static const String _prefMessagesKey = 'tiktube_messages_v1';
  static const String _prefRequestsKey = 'tiktube_requests_v1';

  final List<Friend> _friends = <Friend>[];
  final List<FriendRequest> _requests = <FriendRequest>[];
  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};
  bool _initialized = false;

  List<Friend> get friends => List<Friend>.unmodifiable(_friends);
  List<FriendRequest> get friendRequests =>
      List<FriendRequest>.unmodifiable(_requests);
  int get totalUnread => _friends.fold(0, (sum, f) => sum + f.unreadCount);

  List<ChatMessage> getMessages(String friendId) {
    return List<ChatMessage>.unmodifiable(_messages[friendId] ?? <ChatMessage>[]);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final friendsJson = prefs.getString(_prefFriendsKey);
      if (friendsJson != null && friendsJson.isNotEmpty) {
        final list = (jsonDecode(friendsJson) as List<dynamic>?) ?? <dynamic>[];
        _friends
          ..clear()
          ..addAll(
            list.map((e) => Friend.fromJson(e as Map<String, dynamic>)),
          );
        for (int i = 0; i < _friends.length; i++) {
          final f = _friends[i];
          if (f.id == 'ptk_admin' && (f.name.contains('ZaloChat') || f.name.contains('PTK Official'))) {
            _friends[i] = f.copyWith(
              name: 'TIKTUBE Official',
              statusMessage: 'Kênh hỗ trợ chính thức TIKTUBE',
            );
          } else if (f.id == 'nhantin_ptk' && f.name.contains('ZaloChat')) {
            _friends[i] = f.copyWith(
              name: 'Trợ lý AI TIKTUBE',
              statusMessage: 'Trợ lý AI hỗ trợ & hỏi đáp 24/7',
            );
          }
        }
      } else {
        _seedDefaultFriends();
      }

      final requestsJson = prefs.getString(_prefRequestsKey);
      if (requestsJson != null && requestsJson.isNotEmpty) {
        final list = (jsonDecode(requestsJson) as List<dynamic>?) ?? <dynamic>[];
        _requests
          ..clear()
          ..addAll(
            list.map((e) => FriendRequest.fromJson(e as Map<String, dynamic>)),
          );
      } else {
        _seedDefaultRequests();
      }

      final messagesJson = prefs.getString(_prefMessagesKey);
      if (messagesJson != null && messagesJson.isNotEmpty) {
        final map = (jsonDecode(messagesJson) as Map<String, dynamic>?) ??
            <String, dynamic>{};
        _messages.clear();
        map.forEach((key, val) {
          if (val is List) {
            _messages[key] = val
                .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        });
      } else {
        _seedDefaultMessages();
      }
    } catch (_) {
      _seedDefaultFriends();
      _seedDefaultRequests();
      _seedDefaultMessages();
    }
    notifyListeners();
  }

  void _seedDefaultFriends() {
    _friends
      ..clear()
      ..addAll(<Friend>[
        const Friend(
          id: 'ptk_admin',
          name: 'TIKTUBE Official',
          username: 'ptk_admin',
          phone: '0901234567',
          avatar: '',
          isOnline: true,
          statusMessage: 'Kênh hỗ trợ chính thức TIKTUBE',
          lastMessage: 'Chào bạn! Bạn cần hỗ trợ gì về video hoặc kết nối không?',
          lastMessageTime: '08:30',
          unreadCount: 1,
        ),
        const Friend(
          id: 'kietphan4',
          name: 'Kiệt Phan',
          username: 'kietphan4',
          phone: '0988888888',
          avatar: '',
          isOnline: true,
          statusMessage: 'Sáng tạo nội dung video TIKTUBE',
          lastMessage: 'Video mới đăng chất lượng lắm bạn ơi!',
          lastMessageTime: 'Hôm qua',
          unreadCount: 0,
        ),
        const Friend(
          id: 'nhantin_ptk',
          name: 'Trợ lý AI TIKTUBE',
          username: 'nhantinptk',
          phone: '0911223344',
          avatar: '',
          isOnline: true,
          statusMessage: 'Trợ lý AI hỗ trợ & hỏi đáp 24/7',
          lastMessage: 'Hệ thống gọi điện thoại và nhắn tin đã sẵn sàng 24/7.',
          lastMessageTime: '10:15',
          unreadCount: 0,
        ),
      ]);
  }

  void _seedDefaultRequests() {
    _requests
      ..clear()
      ..addAll(<FriendRequest>[
        const FriendRequest(
          id: 'req_1',
          fromName: 'Hoàng Long',
          fromUsername: 'hoanglong_ptk',
          phone: '0933445566',
          avatar: '',
          time: '15 phút trước',
        ),
      ]);
  }

  void _seedDefaultMessages() {
    _messages['ptk_admin'] = <ChatMessage>[
      const ChatMessage(
        id: 'm1',
        senderId: 'ptk_admin',
        receiverId: 'me',
        text: 'Chào mừng bạn đến với tính năng Nhắn tin & Gọi điện TIKTUBE!',
        time: '08:28',
        isMe: false,
      ),
      const ChatMessage(
        id: 'm2',
        senderId: 'ptk_admin',
        receiverId: 'me',
        text: 'Chào bạn! Bạn cần hỗ trợ gì về video hoặc nhắn tin không?',
        time: '08:30',
        isMe: false,
      ),
    ];

    _messages['kietphan4'] = <ChatMessage>[
      const ChatMessage(
        id: 'm3',
        senderId: 'me',
        receiverId: 'kietphan4',
        text: 'Alo Kiệt ơi, xem video mới chưa?',
        time: 'Hôm qua 18:20',
        isMe: true,
      ),
      const ChatMessage(
        id: 'm4',
        senderId: 'kietphan4',
        receiverId: 'me',
        text: 'Video mới đăng chất lượng lắm bạn ơi!',
        time: 'Hôm qua 18:22',
        isMe: false,
      ),
    ];
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefFriendsKey,
        jsonEncode(_friends.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _prefRequestsKey,
        jsonEncode(_requests.map((e) => e.toJson()).toList()),
      );
      final map = <String, dynamic>{};
      _messages.forEach((k, v) {
        map[k] = v.map((m) => m.toJson()).toList();
      });
      await prefs.setString(_prefMessagesKey, jsonEncode(map));
    } catch (_) {}
  }

  /// Tìm kiếm người dùng qua số điện thoại hoặc tên tài khoản
  List<Friend> searchPotentialFriends(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return <Friend>[];

    // Kiểm tra trong danh sách bạn bè hiện tại
    final List<Friend> results = <Friend>[];
    for (final f in _friends) {
      if (f.phone.contains(clean) ||
          f.username.toLowerCase().contains(clean) ||
          f.name.toLowerCase().contains(clean)) {
        results.add(f);
      }
    }

    // Nếu chưa là bạn bè, tạo đối tượng tìm kiếm khớp SĐT / Tài khoản
    final bool alreadyInResults = results.any(
      (f) =>
          f.phone.toLowerCase() == clean || f.username.toLowerCase() == clean,
    );
    if (!alreadyInResults) {
      final isPhone = RegExp(r'^[0-9+]{8,15}$').hasMatch(clean);
      final id = 'user_${clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      results.add(
        Friend(
          id: id,
          name: isPhone ? 'Người dùng $clean' : clean,
          username: isPhone ? 'user_$clean' : clean,
          phone: isPhone ? clean : '09${clean.hashCode.abs() % 90000000 + 10000000}',
          avatar: '',
          isOnline: true,
          statusMessage: 'Thành viên TIKTUBE & ZaloChat',
        ),
      );
    }

    return results;
  }

  bool isFriend(String userId) {
    return _friends.any((f) => f.id == userId);
  }

  Future<void> sendFriendRequest(Friend target) async {
    if (isFriend(target.id)) return;
    _friends.insert(0, target.copyWith(statusMessage: 'Đã kết bạn'));
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> acceptFriendRequest(FriendRequest req) async {
    _requests.removeWhere((r) => r.id == req.id);
    _friends.insert(
      0,
      Friend(
        id: req.id,
        name: req.fromName,
        username: req.fromUsername,
        phone: req.phone,
        avatar: req.avatar,
        isOnline: true,
        statusMessage: 'Vừa chấp nhận kết bạn',
        lastMessage: 'Đã trở thành bạn bè. Hãy bắt đầu trò chuyện!',
        lastMessageTime: 'Vừa xong',
      ),
    );
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> rejectFriendRequest(String reqId) async {
    _requests.removeWhere((r) => r.id == reqId);
    notifyListeners();
    await _saveToStorage();
  }

  void markAsRead(String friendId) {
    final index = _friends.indexWhere((f) => f.id == friendId);
    if (index >= 0 && _friends[index].unreadCount > 0) {
      _friends[index] = _friends[index].copyWith(unreadCount: 0);
      notifyListeners();
      unawaited(_saveToStorage());
    }
  }

  Future<void> sendMessage(String friendId, String text, {String? imageUrl}) async {
    final clean = text.trim();
    if (clean.isEmpty && imageUrl == null) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      receiverId: friendId,
      text: clean,
      time: timeStr,
      isMe: true,
      imageUrl: imageUrl,
    );

    _messages.putIfAbsent(friendId, () => <ChatMessage>[]).add(msg);

    // Cập nhật lastMessage cho friend
    final index = _friends.indexWhere((f) => f.id == friendId);
    if (index >= 0) {
      final f = _friends.removeAt(index);
      _friends.insert(
        0,
        f.copyWith(
          lastMessage: clean.isNotEmpty ? clean : '[Hình ảnh]',
          lastMessageTime: timeStr,
        ),
      );
    }
    notifyListeners();
    await _saveToStorage();

    // Tự động mô phỏng phản hồi từ bạn bè sau 1.2s để trải nghiệm sống động
    _simulateFriendReply(friendId, clean);
  }

  void recordCall(String friendId, {required bool isVideo, required int durationSeconds}) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final durationStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final callText = durationSeconds > 0
        ? '${isVideo ? "📹 Cuộc gọi video" : "📞 Cuộc gọi thoại"} ($durationStr)'
        : (isVideo ? '📹 Cuộc gọi video nhỡ' : '📞 Cuộc gọi thoại nhỡ');

    final msg = ChatMessage(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      receiverId: friendId,
      text: callText,
      time: timeStr,
      isMe: true,
      isCall: true,
      callDuration: durationStr,
    );

    _messages.putIfAbsent(friendId, () => <ChatMessage>[]).add(msg);

    final index = _friends.indexWhere((f) => f.id == friendId);
    if (index >= 0) {
      final f = _friends[index];
      _friends[index] = f.copyWith(
        lastMessage: callText,
        lastMessageTime: timeStr,
      );
    }
    notifyListeners();
    unawaited(_saveToStorage());
  }

  void _simulateFriendReply(String friendId, String userMessage) {
    Timer(const Duration(milliseconds: 1400), () {
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      String replyText = 'Mình đã nhận được tin nhắn của bạn nhé! 👍';
      final lower = userMessage.toLowerCase();
      if (lower.contains('chào') || lower.contains('alo') || lower.contains('hi')) {
        replyText = 'Chào bạn! Rất vui được kết bạn trò chuyện cùng bạn trên TIKTUBE!';
      } else if (lower.contains('video') || lower.contains('xem')) {
        replyText = 'Video trên TIKTUBE mượt mà lắm, mình đang theo dõi kênh của bạn nè!';
      } else if (lower.contains('gọi') || lower.contains('alo')) {
        replyText = 'Bạn có thể bấm biểu tượng 📞 hoặc 📹 ở góc trên để gọi cho mình nha!';
      } else if (lower.contains('zalo') || lower.contains('link')) {
        replyText = 'Hệ thống ZaloChat nhantinptk.onrender.com kết nối chuẩn luôn bạn nhé!';
      }

      final replyMsg = ChatMessage(
        id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
        senderId: friendId,
        receiverId: 'me',
        text: replyText,
        time: timeStr,
        isMe: false,
      );

      _messages.putIfAbsent(friendId, () => <ChatMessage>[]).add(replyMsg);

      final index = _friends.indexWhere((f) => f.id == friendId);
      if (index >= 0) {
        final f = _friends[index];
        _friends[index] = f.copyWith(
          lastMessage: replyText,
          lastMessageTime: timeStr,
          unreadCount: f.unreadCount + 1,
        );
      }
      notifyListeners();
      unawaited(_saveToStorage());
    });
  }
}

