import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/chat_contact.dart';
import '../models/profile.dart';

class ChatService extends ChangeNotifier {
  static const Friend myCloud = Friend(
    id: 'my_cloud',
    name: 'Cloud của tôi',
    username: 'my_cloud',
    phone: '',
    avatar: 'cloud_icon',
    isOnline: true,
    statusMessage: 'Lưu trữ đám mây cá nhân',
    lastMessage: 'Nơi lưu trữ an toàn văn bản, hình ảnh và tập tin cá nhân.',
    lastMessageTime: '',
    unreadCount: 0,
  );

  ChatService._();
  static final ChatService instance = ChatService._();

  static const String _baseUrl = 'https://nhantinptk.onrender.com';

  String _userKey([String? key]) {
    final k = key ?? _currentProfile?.userKey ?? _currentUser?.username ?? 'default';
    return k.trim().toLowerCase();
  }

  String _prefFriendsKey([String? key]) => 'tiktube_friends_v3_${_userKey(key)}';
  String _prefMessagesKey([String? key]) => 'tiktube_messages_v3_${_userKey(key)}';
  String _prefRequestsKey([String? key]) => 'tiktube_requests_v3_${_userKey(key)}';
  String _prefCurrentUserKey([String? key]) => 'tiktube_current_chat_user_v3_${_userKey(key)}';
  String _prefDeletedFriendsKey([String? key]) => 'tiktube_deleted_friends_v3_${_userKey(key)}';

  final List<Friend> _friends = <Friend>[];
  final List<Friend> _allUsers = <Friend>[];
  final List<FriendRequest> _requests = <FriendRequest>[];
  final Map<String, List<ChatMessage>> _messages = <String, List<ChatMessage>>{};
  final Set<String> _deletedFriendIds = <String>{};

  Profile? _currentProfile;
  Friend? _currentUser;
  io.Socket? _socket;
  bool _initialized = false;
  bool _isConnected = false;

  final StreamController<Map<String, dynamic>> _callEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  String get baseUrl => _baseUrl;
  bool get isConnected => _isConnected;
  Profile? get currentProfile => _currentProfile;
  Friend? get currentUser => _currentUser;
  List<Friend> get friends => List<Friend>.unmodifiable(_friends);
  List<Friend> get allUsers => List<Friend>.unmodifiable(_allUsers);
  List<FriendRequest> get friendRequests =>
      List<FriendRequest>.unmodifiable(_requests);
  Stream<Map<String, dynamic>> get callEvents => _callEventsController.stream;

  int get totalUnread => _friends
      .where((f) => f.id != 'my_cloud')
      .fold(0, (sum, f) => sum + f.unreadCount);

  List<ChatMessage> getMessages(String friendId) {
    return List<ChatMessage>.unmodifiable(_messages[friendId] ?? <ChatMessage>[]);
  }

  /// Đồng bộ phiên tài khoản chat trực tiếp với tài khoản TIKTUBE đang đăng nhập
  Future<void> syncWithProfile(Profile? profile) async {
    if (profile == null) {
      _currentProfile = null;
      _currentUser = null;
      _friends
        ..clear()
        ..add(myCloud);
      _messages.clear();
      _requests.clear();
      _deletedFriendIds.clear();
      _socket?.disconnect();
      notifyListeners();
      return;
    }

    final String newKey = profile.userKey.trim().toLowerCase();
    final bool isUserSwitch = _currentProfile == null ||
        _currentProfile!.userKey.trim().toLowerCase() != newKey;

    _currentProfile = profile;

    if (isUserSwitch) {
      // 1. Chuyển đổi sang tài khoản mới: dọn dẹp bộ nhớ phiên tài khoản cũ
      _friends
        ..clear()
        ..add(myCloud);
      _messages.clear();
      _requests.clear();
      _deletedFriendIds.clear();

      // 2. Nạp dữ liệu bộ nhớ đệm riêng của tài khoản này
      await _loadFromLocalStorage(userKey: newKey);
      notifyListeners();
    }

    final cleanPhone = (profile.phone ?? '').trim().replaceAll(' ', '');
    if (cleanPhone.isNotEmpty) {
      if (_currentUser != null && _currentUser!.phone != cleanPhone) {
        _currentUser = _currentUser!.copyWith(phone: cleanPhone);
        await _saveCurrentUserToStorage();
        notifyListeners();
      }
    }

    // 3. Đồng bộ danh sách bạn bè thật từ Neon PostgreSQL của tài khoản này
    await fetchNeonUsersAndSync(profile: profile);
  }

  Future<void> init({Profile? profile, String? defaultAccount}) async {
    if (profile != null) {
      await syncWithProfile(profile);
      return;
    }
    if (_initialized) return;
    _initialized = true;

    await _loadFromLocalStorage();

    // Tải toàn bộ người dùng thật từ Neon PostgreSQL qua API bootstrap
    unawaited(fetchNeonUsersAndSync(preferredAccount: defaultAccount));

    // Khởi tạo và kết nối Socket.io thời gian thực
    _initSocket();
  }

  Future<void> _loadFromLocalStorage({String? userKey}) async {
    final k = _userKey(userKey);
    try {
      final prefs = await SharedPreferences.getInstance();

      final deletedJson = prefs.getString(_prefDeletedFriendsKey(k));
      if (deletedJson != null && deletedJson.isNotEmpty) {
        try {
          final list = jsonDecode(deletedJson) as List<dynamic>;
          _deletedFriendIds
            ..clear()
            ..addAll(list.map((e) => e.toString()));
        } catch (_) {}
      }

      final userJson = prefs.getString(_prefCurrentUserKey(k));
      if (userJson != null && userJson.isNotEmpty) {
        try {
          _currentUser = Friend.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
          final cleanPhone = (_currentProfile?.phone ?? '').trim().replaceAll(' ', '');
          if (cleanPhone.isNotEmpty && _currentUser!.phone != cleanPhone) {
            _currentUser = _currentUser!.copyWith(phone: cleanPhone);
          }
        } catch (_) {}
      }

      final friendsJson = prefs.getString(_prefFriendsKey(k));
      if (friendsJson != null && friendsJson.isNotEmpty) {
        final list = (jsonDecode(friendsJson) as List<dynamic>?) ?? <dynamic>[];
        _friends
          ..clear()
          ..add(myCloud)
          ..addAll(
            list
                .map((e) => Friend.fromJson(e as Map<String, dynamic>))
                .where((f) => f.id != 'my_cloud' && !_deletedFriendIds.contains(f.id)),
          );
      } else {
        _seedInitialFriends();
      }

      final requestsJson = prefs.getString(_prefRequestsKey(k));
      if (requestsJson != null && requestsJson.isNotEmpty) {
        final list = (jsonDecode(requestsJson) as List<dynamic>?) ?? <dynamic>[];
        _requests
          ..clear()
          ..addAll(
            list.map((e) => FriendRequest.fromJson(e as Map<String, dynamic>)),
          );
      }

      final messagesJson = prefs.getString(_prefMessagesKey(k));
      if (messagesJson != null && messagesJson.isNotEmpty) {
        final map = (jsonDecode(messagesJson) as Map<String, dynamic>?) ??
            <String, dynamic>{};
        _messages.clear();
        map.forEach((key, val) {
          if (val is List) {
            final List<ChatMessage> deduped = <ChatMessage>[];
            for (final e in val) {
              if (e is Map) {
                final m = ChatMessage.fromJson(
                  Map<String, dynamic>.from(e),
                  currentUserId: _currentUser?.id,
                );
                final isDup = deduped.any((d) =>
                    d.id == m.id ||
                    (d.isMe == m.isMe &&
                        d.text == m.text &&
                        d.imageUrl == m.imageUrl &&
                        d.time == m.time &&
                        (d.timestamp != null &&
                            m.timestamp != null &&
                            (d.timestamp! - m.timestamp!).abs() < 5000)));
                if (!isDup) {
                  deduped.add(m);
                }
              }
            }
            _messages[key] = deduped;
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
      ..add(myCloud);
  }

  /// Đồng bộ người dùng và dữ liệu từ Neon Cloud PostgreSQL
  Future<void> fetchNeonUsersAndSync({Profile? profile, String? preferredAccount}) async {
    final effectiveProfile = profile ?? _currentProfile;
    final String targetAccountKey = (effectiveProfile?.userKey ?? preferredAccount ?? '').trim().toLowerCase();

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

        // Tìm hoặc tạo tài khoản tương ứng trên Neon PostgreSQL
        Friend? targetUser;
        if (targetAccountKey.isNotEmpty) {
          // 1. Tìm theo username chính xác
          for (final u in _allUsers) {
            if (u.username.toLowerCase() == targetAccountKey) {
              targetUser = u;
              break;
            }
          }

          // 2. Tìm theo số điện thoại (nếu có)
          final userPhone = (effectiveProfile?.phone ?? '').trim().replaceAll(' ', '');
          if (targetUser == null && userPhone.isNotEmpty) {
            for (final u in _allUsers) {
              if (u.phone.isNotEmpty && u.phone == userPhone) {
                targetUser = u;
                break;
              }
            }
          }

          // 3. Tìm theo tên hiển thị
          final userName = (effectiveProfile?.name ?? '').trim().toLowerCase();
          if (targetUser == null && userName.isNotEmpty) {
            for (final u in _allUsers) {
              if (u.name.toLowerCase() == userName) {
                targetUser = u;
                break;
              }
            }
          }

          // 4. Nếu chưa có trên Neon, đăng ký tài khoản này vào bảng users của Neon
          if (targetUser == null) {
            final regPhone = userPhone.isNotEmpty
                ? userPhone
                : '03${(targetAccountKey.hashCode.abs() % 90000000 + 10000000)}';
            final regName = (effectiveProfile?.name.isNotEmpty == true)
                ? effectiveProfile!.name
                : targetAccountKey;

            try {
              final regRes = await http.post(
                Uri.parse('$_baseUrl/api/auth/register'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'name': regName,
                  'username': targetAccountKey,
                  'phone': regPhone,
                  'password': 'ptk_$targetAccountKey',
                  'avatar': effectiveProfile?.avatarUrl ?? '',
                }),
              ).timeout(const Duration(seconds: 8));

              if (regRes.statusCode == 200) {
                final regData = jsonDecode(regRes.body) as Map<String, dynamic>;
                if (regData['user'] != null) {
                  targetUser = Friend.fromJson(
                    Map<String, dynamic>.from(regData['user'] as Map),
                  );
                  _allUsers.add(targetUser);
                }
              }
            } catch (_) {}

            targetUser ??= Friend(
              id: 'user_${targetAccountKey}_${DateTime.now().millisecondsSinceEpoch}',
              name: regName,
              username: targetAccountKey,
              phone: regPhone,
              avatar: effectiveProfile?.avatarUrl ?? '',
            );
          }
        } else if (_currentUser != null) {
          targetUser = _allUsers.firstWhere(
            (u) => u.id == _currentUser!.id,
            orElse: () => _currentUser!,
          );
        }

        if (targetUser != null) {
          final cleanPhone = (effectiveProfile?.phone ?? '').trim().replaceAll(' ', '');
          if (cleanPhone.isNotEmpty && targetUser.phone != cleanPhone) {
            targetUser = targetUser.copyWith(phone: cleanPhone);
            unawaited(http.post(
              Uri.parse('$_baseUrl/api/users/profile'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'id': targetUser.id,
                'name': targetUser.name,
                'phone': cleanPhone,
                'avatar': targetUser.avatar,
              }),
            ).then((_) {}, onError: (_) {}));
          }

          _currentUser = targetUser;
          unawaited(_saveCurrentUserToStorage());

          // CHỈ tải danh sách bạn bè của CHÍNH tài khoản này từ Neon
          final myFriendIds = userFriendsMap[_currentUser!.id] ?? <String>[];
          final List<Friend> newFriendsList = <Friend>[myCloud];

          for (final friendId in myFriendIds) {
            if (_deletedFriendIds.contains(friendId)) continue;
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

          // Khởi tạo Socket.io với tài khoản hiện tại
          _initSocket();
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
          String? targetId = data['targetId']?.toString();
          if (targetId == _currentUser?.id) {
            targetId = 'my_cloud';
          }
          final rawMsgs = data['messages'];
          if (targetId != null && rawMsgs is List) {
            final List<ChatMessage> list = <ChatMessage>[];
            for (final m in rawMsgs) {
              ChatMessage? parsed;
              if (m is Map<String, dynamic>) {
                parsed = ChatMessage.fromJson(m, currentUserId: _currentUser?.id);
              } else if (m is Map) {
                parsed = ChatMessage.fromJson(
                  Map<String, dynamic>.from(m),
                  currentUserId: _currentUser?.id,
                );
              }
              if (parsed != null) {
                final isDup = list.any((existing) =>
                    existing.id == parsed!.id ||
                    (existing.isMe == parsed.isMe &&
                        existing.text == parsed.text &&
                        existing.imageUrl == parsed.imageUrl &&
                        existing.time == parsed.time &&
                        (existing.timestamp != null &&
                            parsed.timestamp != null &&
                            (existing.timestamp! - parsed.timestamp!).abs() < 5000)));
                if (!isDup) {
                  list.add(parsed);
                }
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
          final partnerId = (msg.senderId == myId && (msg.receiverId == myId || msg.receiverId == 'my_cloud'))
              ? 'my_cloud'
              : ((msg.senderId == myId) ? msg.receiverId : msg.senderId);

          if (partnerId.isNotEmpty) {
            final list = _messages.putIfAbsent(partnerId, () => <ChatMessage>[]);
            if (msg.isMe) {
              // 1. Kiểm tra xem đã có tin nhắn trùng ID chưa
              final exactIdx = list.indexWhere((m) => m.id == msg.id);
              if (exactIdx >= 0) {
                list[exactIdx] = msg;
              } else {
                // 2. Tìm tin nhắn gửi lạc quan (optimistic) vừa chèn tại máy để cập nhật lại ID từ server
                final optIdx = list.lastIndexWhere((m) =>
                    m.isMe &&
                    m.text == msg.text &&
                    m.imageUrl == msg.imageUrl &&
                    (msg.timestamp == null ||
                        m.timestamp == null ||
                        (msg.timestamp! - m.timestamp!).abs() < 60000));
                if (optIdx >= 0) {
                  list[optIdx] = msg;
                } else {
                  list.add(msg);
                }
              }
            } else {
              // Tin nhắn đối phương gửi tới
              final exactIdx = list.indexWhere((m) => m.id == msg.id);
              if (exactIdx >= 0) {
                list[exactIdx] = msg;
              } else {
                final isDup = list.any((m) =>
                    !m.isMe &&
                    m.senderId == msg.senderId &&
                    m.text == msg.text &&
                    m.imageUrl == msg.imageUrl &&
                    m.time == msg.time &&
                    (msg.timestamp != null &&
                        m.timestamp != null &&
                        (msg.timestamp! - m.timestamp!).abs() < 5000));
                if (!isDup) {
                  list.add(msg);
                }
              }
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

      // Nhận sự kiện bị hủy / xóa kết bạn
      _socket!.on('friend:removed', (data) {
        if (data is Map) {
          final removedId = data['removedFriendId']?.toString() ??
              data['targetUserId']?.toString() ??
              data['friendId']?.toString();
          if (removedId != null && removedId.isNotEmpty && removedId != 'my_cloud') {
            _deletedFriendIds.add(removedId);
            _friends.removeWhere((f) => f.id == removedId);
            _messages.remove(removedId);
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
        if (f.id != 'my_cloud') {
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
      final targetId = (friendId == 'my_cloud') ? _currentUser!.id : friendId;
      _socket!.emit('chat:get_history', {
        'targetId': targetId,
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

  /// Cập nhật số điện thoại người dùng hiện tại và đồng bộ ngay lên Neon SQL
  Future<void> updateCurrentUserPhone(String newPhone) async {
    final clean = newPhone.trim().replaceAll(' ', '');
    if (clean.isEmpty) return;

    if (_currentProfile != null) {
      _currentProfile = _currentProfile!.copyWith(phone: clean);
    }

    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(phone: clean);
      await _saveCurrentUserToStorage();
      notifyListeners();

      try {
        await http.post(
          Uri.parse('$_baseUrl/api/users/profile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': _currentUser!.id,
            'name': _currentUser!.name,
            'phone': clean,
            'avatar': _currentUser!.avatar,
          }),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}

      _emitSocketLogin();
    } else {
      await fetchNeonUsersAndSync();
    }
  }

  Future<void> _saveCurrentUserToStorage() async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCurrentUserKey(), jsonEncode(_currentUser!.toJson()));
    } catch (_) {}
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefFriendsKey(),
        jsonEncode(_friends.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _prefRequestsKey(),
        jsonEncode(_requests.map((e) => e.toJson()).toList()),
      );
      await prefs.setString(
        _prefDeletedFriendsKey(),
        jsonEncode(_deletedFriendIds.toList()),
      );
      final map = <String, dynamic>{};
      _messages.forEach((k, v) {
        map[k] = v.map((m) => m.toJson()).toList();
      });
      await prefs.setString(_prefMessagesKey(), jsonEncode(map));
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
    _deletedFriendIds.remove(target.id);
    if (isFriend(target.id)) return;

    if (_socket != null && _socket!.connected) {
      _socket!.emit('friend:add_direct', {'targetUserId': target.id});
    }

    final insertIdx = _friends.isNotEmpty ? 1 : 0;
    _friends.insert(insertIdx, target.copyWith(statusMessage: 'Đã kết bạn'));
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> acceptFriendRequest(FriendRequest req) async {
    _deletedFriendIds.remove(req.id);
    _requests.removeWhere((r) => r.id == req.id);

    if (_socket != null && _socket!.connected) {
      _socket!.emit('friend:accept', {'senderId': req.id});
    }

    final insertIdx = _friends.isNotEmpty ? 1 : 0;
    _friends.insert(
      insertIdx,
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

  /// Xóa bạn bè khỏi danh bạ và đồng bộ Neon PostgreSQL
  Future<void> removeFriend(String friendId) async {
    if (friendId == 'my_cloud') return;

    _deletedFriendIds.add(friendId);
    _friends.removeWhere((f) => f.id == friendId);
    _messages.remove(friendId);

    if (_socket != null && _socket!.connected) {
      _socket!.emit('friend:remove', {
        'userId': _currentUser?.id,
        'targetUserId': friendId,
      });
    }

    try {
      await http.post(
        Uri.parse('$_baseUrl/api/friends/remove'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _currentUser?.id,
          'targetUserId': friendId,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}

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
    final targetUserId = (friendId == 'my_cloud') ? myId : friendId;

    // 1. Gửi qua Socket.io tới server để ghi vào bảng messages của Neon PostgreSQL
    if (_socket != null && _socket!.connected) {
      _socket!.emit('message:send', {
        'id': msgId,
        'senderId': myId,
        'senderName': myName,
        'senderAvatar': myAvatar,
        'targetId': targetUserId,
        'isGroup': false,
        'text': clean,
        'imageUrl': imageUrl,
        'messageType': (friendId == 'my_cloud') ? 'cloud_note' : 'normal',
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



  @override
  void dispose() {
    _socket?.dispose();
    _callEventsController.close();
    super.dispose();
  }
}
