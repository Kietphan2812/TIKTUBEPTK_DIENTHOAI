import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/chat_contact.dart';

class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const String _baseUrl = 'https://nhantinptk.onrender.com';
  static const String _prefFriendsKey = 'tiktube_friends_v2';
  static const String _prefMessagesKey = 'tiktube_messages_v2';
  static const String _prefRequestsKey = 'tiktube_requests_v2';
  static const String _prefCurrentUserKey = 'tiktube_current_chat_user_v2';

  final List<Friend> _friends = <Friend>[];
  final List<Friend> _allUsers = <Friend>[];
  final List<FriendRequest> _requests = <FriendRequest>[];
  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};

  Friend? _currentUser;
  io.Socket? _socket;
  bool _initialized = false;
  bool _isConnected = false;

  final StreamController<Map<String, dynamic>> _callEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  String get baseUrl => _baseUrl;
  bool get isConnected => _isConnected;
  Friend? get currentUser => _currentUser;
  List<Friend> get friends => List<Friend>.unmodifiable(_friends);
  List<Friend> get allUsers => List<Friend>.unmodifiable(_allUsers);
  List<FriendRequest> get friendRequests =>
      List<FriendRequest>.unmodifiable(_requests);
  Stream<Map<String, dynamic>> get callEvents => _callEventsController.stream;

  int get totalUnread => _friends.fold(0, (sum, f) => sum + f.unreadCount);

  List<ChatMessage> getMessages(String friendId) {
    return List<ChatMessage>.unmodifiable(_messages[friendId] ?? <ChatMessage>[]);
  }

  Future<void> init({String? defaultAccount}) async {
    if (_initialized) return;
    _initialized = true;

    await _loadFromLocalStorage();

    // Tải toàn bộ người dùng thật từ Neon PostgreSQL qua API bootstrap
    unawaited(fetchNeonUsersAndSync(preferredAccount: defaultAccount));

    // Khởi tạo và kết nối Socket.io thời gian thực
    _initSocket();
  }

  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final userJson = prefs.getString(_prefCurrentUserKey);
      if (userJson != null && userJson.isNotEmpty) {
        try {
          _currentUser = Friend.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        } catch (_) {}
      }

      final friendsJson = prefs.getString(_prefFriendsKey);
      if (friendsJson != null && friendsJson.isNotEmpty) {
        final list = (jsonDecode(friendsJson) as List<dynamic>?) ?? <dynamic>[];
        _friends
          ..clear()
          ..addAll(
            list.map((e) => Friend.fromJson(e as Map<String, dynamic>)),
          );
      } else {
        _seedInitialFriends();
      }

      final requestsJson = prefs.getString(_prefRequestsKey);
      if (requestsJson != null && requestsJson.isNotEmpty) {
        final list = (jsonDecode(requestsJson) as List<dynamic>?) ?? <dynamic>[];
        _requests
          ..clear()
          ..addAll(
            list.map((e) => FriendRequest.fromJson(e as Map<String, dynamic>)),
          );
      }

      final messagesJson = prefs.getString(_prefMessagesKey);
      if (messagesJson != null && messagesJson.isNotEmpty) {
        final map = (jsonDecode(messagesJson) as Map<String, dynamic>?) ??
            <String, dynamic>{};
        _messages.clear();
        map.forEach((key, val) {
          if (val is List) {
            _messages[key] = val
                .map((e) => ChatMessage.fromJson(
                      e as Map<String, dynamic>,
                      currentUserId: _currentUser?.id,
                    ))
                .toList();
          }
        });
      }
    } catch (_) {
      _seedInitialFriends();
    }
    notifyListeners();
  }

  void _seedInitialFriends() {
    _friends
      ..clear()
      ..addAll(<Friend>[
        const Friend(
          id: 'ptk_admin',
          name: 'TIKTUBE Official',
          username: 'tiktube_official',
          phone: '0900000001',
          avatar: '',
          isOnline: true,
          statusMessage: 'Kênh hỗ trợ chính thức TIKTUBE',
          lastMessage: 'Chào mừng bạn đến với tính năng Tin nhắn & Bạn bè TIKTUBE!',
          lastMessageTime: '08:30',
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
          lastMessage: 'Hệ thống gọi điện thoại và nhắn tin kết nối Neon SQL đã sẵn sàng.',
          lastMessageTime: '10:15',
          unreadCount: 0,
        ),
      ]);
  }

  /// Đồng bộ người dùng và dữ liệu từ Neon Cloud PostgreSQL
  Future<void> fetchNeonUsersAndSync({String? preferredAccount}) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/bootstrap'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawUsers = (data['users'] as List<dynamic>?) ?? <dynamic>[];

        _allUsers.clear();
        final Map<String, List<String>> userFriendsMap = <String, List<String>>{};

        for (final item in rawUsers) {
          if (item is Map<String, dynamic>) {
            final f = Friend.fromJson(item);
            _allUsers.add(f);

            final rawFList = item['friends'];
            final List<String> fIds = <String>[];
            if (rawFList is List) {
              for (final id in rawFList) {
                fIds.add(id.toString());
              }
            }
            userFriendsMap[f.id] = fIds;
          }
        }

        // Chọn tài khoản hiện tại nếu chưa có
        if (_currentUser == null || !_allUsers.any((u) => u.id == _currentUser!.id)) {
          Friend? target;
          if (preferredAccount != null && preferredAccount.isNotEmpty) {
            target = _allUsers.firstWhere(
              (u) =>
                  u.phone == preferredAccount ||
                  u.username.toLowerCase() == preferredAccount.toLowerCase(),
              orElse: () => _allUsers.firstWhere(
                (u) => u.username == 'phantaanskieetj' || u.phone == '0338351410',
                orElse: () => _allUsers.isNotEmpty
                    ? _allUsers.first
                    : const Friend(
                        id: 'user_1792224901328_512',
                        name: 'Phantaanskieetj',
                        username: 'phantaanskieetj',
                        phone: '0338351410',
                        avatar: '',
                      ),
              ),
            );
          } else {
            target = _allUsers.firstWhere(
              (u) => u.username == 'phantaanskieetj' || u.phone == '0338351410',
              orElse: () => _allUsers.isNotEmpty
                  ? _allUsers.first
                  : const Friend(
                      id: 'user_1792224901328_512',
                      name: 'Phantaanskieetj',
                      username: 'phantaanskieetj',
                      phone: '0338351410',
                      avatar: '',
                    ),
            );
          }
          _currentUser = target;
          unawaited(_saveCurrentUserToStorage());
        }

        // Cập nhật danh sách bạn bè dựa trên quan hệ SQL Neon
        if (_currentUser != null) {
          final myFriendIds = userFriendsMap[_currentUser!.id] ?? <String>[];
          final List<Friend> newFriendsList = <Friend>[];

          // Giữ TIKTUBE Official & Trợ lý AI ở đầu
          newFriendsList.addAll([
            const Friend(
              id: 'ptk_admin',
              name: 'TIKTUBE Official',
              username: 'tiktube_official',
              phone: '0900000001',
              avatar: '',
              isOnline: true,
              statusMessage: 'Kênh hỗ trợ chính thức TIKTUBE',
              lastMessage: 'Kênh hỗ trợ trực tuyến 24/7.',
              lastMessageTime: '08:30',
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
              lastMessage: 'Đã kết nối cơ sở dữ liệu Neon PostgreSQL.',
              lastMessageTime: '10:15',
              unreadCount: 0,
            ),
          ]);

          // Thêm các bạn bè thật từ Neon Postgres
          for (final friendId in myFriendIds) {
            final realUser = _allUsers.firstWhere(
              (u) => u.id == friendId,
              orElse: () => Friend(
                id: friendId,
                name: 'Bạn bè ($friendId)',
                username: friendId,
                phone: '',
                avatar: '',
              ),
            );
            if (!newFriendsList.any((f) => f.id == realUser.id)) {
              newFriendsList.add(realUser);
            }
          }

          // Thêm các người dùng khác trong hệ thống để dễ dàng trò chuyện
          for (final user in _allUsers) {
            if (user.id != _currentUser!.id &&
                !newFriendsList.any((f) => f.id == user.id)) {
              newFriendsList.add(user);
            }
          }

          // Giữ lại tin nhắn cuối cùng và số chưa đọc đã lưu
          for (int i = 0; i < newFriendsList.length; i++) {
            final nf = newFriendsList[i];
            final existingIndex = _friends.indexWhere((f) => f.id == nf.id);
            if (existingIndex >= 0) {
              final ex = _friends[existingIndex];
              newFriendsList[i] = nf.copyWith(
                lastMessage: ex.lastMessage.isNotEmpty ? ex.lastMessage : nf.lastMessage,
                lastMessageTime: ex.lastMessageTime.isNotEmpty
                    ? ex.lastMessageTime
                    : nf.lastMessageTime,
                unreadCount: ex.unreadCount,
              );
            }
          }

          _friends
            ..clear()
            ..addAll(newFriendsList);

          // Nếu socket đã kết nối, tiến hành đăng nhập và tải lịch sử tin nhắn
          _emitSocketLogin();
          _fetchAllChatHistories();
        }

        notifyListeners();
        unawaited(_saveToStorage());
      }
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu Neon: $e');
    }
  }

  void _initSocket() {
    try {
      _socket?.dispose();

      _socket = io.io(
        _baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        notifyListeners();
        _emitSocketLogin();
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        notifyListeners();
      });

      _socket!.onConnectError((err) {
        _isConnected = false;
        notifyListeners();
      });

      _socket!.on('login:success', (data) {
        _fetchAllChatHistories();
      });

      _socket!.on('user:status_changed', (data) {
        if (data is Map) {
          final userId = data['userId']?.toString();
          final status = data['status']?.toString();
          if (userId != null) {
            final idx = _friends.indexWhere((f) => f.id == userId);
            if (idx >= 0) {
              _friends[idx] = _friends[idx].copyWith(isOnline: status == 'online');
              notifyListeners();
            }
          }
        }
      });

      _socket!.on('chat:history', (data) {
        if (data is Map) {
          final targetId = data['targetId']?.toString();
          final rawMsgs = data['messages'];
          if (targetId != null && rawMsgs is List) {
            final List<ChatMessage> list = <ChatMessage>[];
            for (final m in rawMsgs) {
              if (m is Map<String, dynamic>) {
                list.add(ChatMessage.fromJson(m, currentUserId: _currentUser?.id));
              } else if (m is Map) {
                list.add(ChatMessage.fromJson(
                  Map<String, dynamic>.from(m),
                  currentUserId: _currentUser?.id,
                ));
              }
            }

            _messages[targetId] = list;

            if (list.isNotEmpty) {
              final lastMsg = list.last;
              final idx = _friends.indexWhere((f) => f.id == targetId);
              if (idx >= 0) {
                _friends[idx] = _friends[idx].copyWith(
                  lastMessage: lastMsg.text.isNotEmpty
                      ? lastMsg.text
                      : (lastMsg.imageUrl != null ? '[Hình ảnh]' : ''),
                  lastMessageTime: lastMsg.time,
                );
              }
            }

            notifyListeners();
            unawaited(_saveToStorage());
          }
        }
      });

      _socket!.on('message:new', (data) {
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final msg = ChatMessage.fromJson(map, currentUserId: _currentUser?.id);

          final myId = _currentUser?.id ?? '';
          final partnerId = (msg.senderId == myId) ? msg.receiverId : msg.senderId;

          if (partnerId.isNotEmpty) {
            final list = _messages.putIfAbsent(partnerId, () => <ChatMessage>[]);
            if (!list.any((m) => m.id == msg.id)) {
              list.add(msg);
            }

            final idx = _friends.indexWhere((f) => f.id == partnerId);
            if (idx >= 0) {
              final f = _friends[idx];
              _friends[idx] = f.copyWith(
                lastMessage: msg.text.isNotEmpty
                    ? msg.text
                    : (msg.imageUrl != null ? '[Hình ảnh]' : ''),
                lastMessageTime: msg.time,
                unreadCount: msg.isMe ? f.unreadCount : f.unreadCount + 1,
              );
            }

            notifyListeners();
            unawaited(_saveToStorage());
          }
        }
      });

      // Nhận cuộc gọi đến thời gian thực
      _socket!.on('call:incoming', (data) {
        if (data is Map) {
          _callEventsController.add({
            'type': 'incoming',
            'data': Map<String, dynamic>.from(data),
          });
        }
      });

      _socket!.on('call:answered', (data) {
        if (data is Map) {
          _callEventsController.add({
            'type': 'answered',
            'data': Map<String, dynamic>.from(data),
          });
        }
      });

      _socket!.on('call:ended', (data) {
        _callEventsController.add({'type': 'ended'});
      });

      _socket!.on('call:rejected', (data) {
        _callEventsController.add({'type': 'rejected'});
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('Lỗi khởi tạo socket: $e');
    }
  }

  void _emitSocketLogin() {
    if (_socket != null && _socket!.connected && _currentUser != null) {
      _socket!.emit('user:login', {
        'id': _currentUser!.id,
        'name': _currentUser!.name,
        'username': _currentUser!.username,
        'phone': _currentUser!.phone,
        'avatar': _currentUser!.avatar,
      });
      _socket!.emit('call:check_pending');
    }
  }

  void _fetchAllChatHistories() {
    if (_socket != null && _socket!.connected && _currentUser != null) {
      for (final f in _friends) {
        if (f.id != 'ptk_admin' && f.id != 'nhantin_ptk') {
          _socket!.emit('chat:get_history', {
            'targetId': f.id,
            'isGroup': false,
          });
        }
      }
    }
  }

  /// Tải lịch sử trò chuyện cho một người bạn cụ thể
  void loadChatHistory(String friendId) {
    if (_socket != null && _socket!.connected && _currentUser != null) {
      _socket!.emit('chat:get_history', {
        'targetId': friendId,
        'isGroup': false,
      });
    }
  }

  /// Chuyển đổi tài khoản người dùng đang đăng nhập
  Future<void> switchCurrentUser(Friend user) async {
    _currentUser = user;
    await _saveCurrentUserToStorage();
    _emitSocketLogin();
    _fetchAllChatHistories();
    notifyListeners();
  }

  /// Đăng nhập tài khoản qua SĐT hoặc tên người dùng
  Future<bool> loginWithCredentials(String account, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'account': account.trim(), 'password': password.trim()}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true && data['user'] != null) {
          final userMap = Map<String, dynamic>.from(data['user'] as Map);
          _currentUser = Friend.fromJson(userMap);
          await _saveCurrentUserToStorage();
          _emitSocketLogin();
          unawaited(fetchNeonUsersAndSync());
          notifyListeners();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> _saveCurrentUserToStorage() async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCurrentUserKey, jsonEncode(_currentUser!.toJson()));
    } catch (_) {}
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

  /// Tìm kiếm người dùng thật từ Neon PostgreSQL
  List<Friend> searchPotentialFriends(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return <Friend>[];

    final List<Friend> results = <Friend>[];
    for (final u in _allUsers) {
      if (u.id == _currentUser?.id) continue;
      if (u.phone.contains(clean) ||
          u.username.toLowerCase().contains(clean) ||
          u.name.toLowerCase().contains(clean)) {
        results.add(u);
      }
    }

    // Nếu chưa có trong danh sách toàn bộ người dùng, tìm kiếm thêm trong bạn bè
    for (final f in _friends) {
      if (f.id == _currentUser?.id) continue;
      if (!results.any((r) => r.id == f.id)) {
        if (f.phone.contains(clean) ||
            f.username.toLowerCase().contains(clean) ||
            f.name.toLowerCase().contains(clean)) {
          results.add(f);
        }
      }
    }

    return results;
  }

  bool isFriend(String userId) {
    return _friends.any((f) => f.id == userId);
  }

  Future<void> sendFriendRequest(Friend target) async {
    if (isFriend(target.id)) return;

    if (_socket != null && _socket!.connected) {
      _socket!.emit('friend:add_direct', {'targetUserId': target.id});
    }

    _friends.insert(0, target.copyWith(statusMessage: 'Đã kết bạn'));
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> acceptFriendRequest(FriendRequest req) async {
    _requests.removeWhere((r) => r.id == req.id);

    if (_socket != null && _socket!.connected) {
      _socket!.emit('friend:accept', {'senderId': req.id});
    }

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
    if (_socket != null && _socket!.connected) {
      _socket!.emit('friend:reject', {'senderId': reqId});
    }
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

  /// Tải ảnh lên Cloudinary qua API nhantinptk (lưu vĩnh viễn trên đám mây qfgja134)
  Future<String?> uploadImage(Uint8List bytes, String fileName) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/upload');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName.isNotEmpty ? fileName : 'chat_image.jpg',
        ),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final url = data['url']?.toString();
        if (url != null && url.isNotEmpty) {
          if (url.startsWith('http')) return url;
          return '$_baseUrl$url';
        }
      }
    } catch (e) {
      debugPrint('Lỗi tải ảnh lên Cloudinary: $e');
    }
    return null;
  }

  /// Gửi tin nhắn thật lưu vào Neon PostgreSQL & phát qua Socket.io
  Future<void> sendMessage(String friendId, String text, {String? imageUrl}) async {
    final clean = text.trim();
    if (clean.isEmpty && imageUrl == null) return;

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final myId = _currentUser?.id ?? 'me';
    final myName = _currentUser?.name ?? 'Tôi';
    final myAvatar = _currentUser?.avatar ?? '';

    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Gửi qua Socket.io tới server để ghi vào bảng messages của Neon PostgreSQL
    if (_socket != null && _socket!.connected) {
      _socket!.emit('message:send', {
        'id': msgId,
        'senderId': myId,
        'senderName': myName,
        'senderAvatar': myAvatar,
        'targetId': friendId,
        'isGroup': false,
        'text': clean,
        'imageUrl': imageUrl,
        'messageType': 'normal',
      });
    }

    // 2. Thêm ngay vào giao diện máy người gửi để hiển thị tức thì
    final msg = ChatMessage(
      id: msgId,
      senderId: myId,
      receiverId: friendId,
      text: clean,
      time: timeStr,
      isMe: true,
      imageUrl: imageUrl,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _messages.putIfAbsent(friendId, () => <ChatMessage>[]).add(msg);

    // Cập nhật tin nhắn gần nhất
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

    // Nếu đang nhắn tin với Trợ lý AI hoặc tài khoản bot demo
    if (friendId == 'ptk_admin' || friendId == 'nhantin_ptk') {
      _simulateFriendReply(friendId, clean);
    }
  }

  /// Bắt đầu cuộc gọi thoại hoặc video qua tín hiệu Socket.io
  void initiateCall(String friendId, {required bool isVideo}) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('call:initiate', {
        'targetUserId': friendId,
        'isVideo': isVideo,
        'offer': null,
      });
    }
  }

  /// Trả lời cuộc gọi đến
  void answerCall(String callerId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('call:answer', {
        'targetUserId': callerId,
        'answer': null,
      });
    }
  }

  /// Kết thúc cuộc gọi
  void endCall(String friendId, {required bool isVideo, required int durationSeconds}) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('call:hangup', {
        'targetUserId': friendId,
      });
    }
    recordCall(friendId, isVideo: isVideo, durationSeconds: durationSeconds);
  }

  /// Từ chối cuộc gọi đến
  void rejectCall(String callerId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('call:reject', {
        'targetUserId': callerId,
      });
    }
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
      senderId: _currentUser?.id ?? 'me',
      receiverId: friendId,
      text: callText,
      time: timeStr,
      isMe: true,
      isCall: true,
      callDuration: durationStr,
      timestamp: DateTime.now().millisecondsSinceEpoch,
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
        replyText = 'Chào bạn! Rất vui được trò chuyện cùng bạn trên hệ thống TIKTUBE & nhantinptk!';
      } else if (lower.contains('video') || lower.contains('xem')) {
        replyText = 'Video trên TIKTUBE mượt mà lắm, mình đang theo dõi kênh của bạn nè!';
      } else if (lower.contains('sql') || lower.contains('neon')) {
        replyText = 'Dữ liệu tin nhắn đã được kết nối và lưu trữ an toàn trên Neon Cloud PostgreSQL!';
      } else if (lower.contains('gọi') || lower.contains('alo')) {
        replyText = 'Bạn có thể bấm biểu tượng 📞 hoặc 📹 ở góc trên để gọi thử cho mình nha!';
      }

      final replyMsg = ChatMessage(
        id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
        senderId: friendId,
        receiverId: _currentUser?.id ?? 'me',
        text: replyText,
        time: timeStr,
        isMe: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
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

  @override
  void dispose() {
    _socket?.dispose();
    _callEventsController.close();
    super.dispose();
  }
}
