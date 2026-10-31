import 'package:flutter/foundation.dart';

@immutable
class Friend {
  const Friend({
    required this.id,
    required this.name,
    required this.username,
    required this.phone,
    required this.avatar,
    this.isOnline = true,
    this.statusMessage = 'Đang hoạt động',
    this.lastMessage = '',
    this.lastMessageTime = '',
    this.unreadCount = 0,
    this.bio,
    this.gender,
  });

  final String id;
  final String name;
  final String username;
  final String phone;
  final String avatar;
  final bool isOnline;
  final String statusMessage;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final String? bio;
  final String? gender;

  Friend copyWith({
    String? id,
    String? name,
    String? username,
    String? phone,
    String? avatar,
    bool? isOnline,
    String? statusMessage,
    String? lastMessage,
    String? lastMessageTime,
    int? unreadCount,
    String? bio,
    String? gender,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      isOnline: isOnline ?? this.isOnline,
      statusMessage: statusMessage ?? this.statusMessage,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
    );
  }

  factory Friend.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    final isOnline = json['isOnline'] as bool? ?? (status == 'online');
    return Friend(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      isOnline: isOnline,
      statusMessage: json['bio']?.toString() ?? json['statusMessage']?.toString() ?? 'Đang hoạt động',
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageTime: json['lastMessageTime']?.toString() ?? '',
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      bio: json['bio']?.toString(),
      gender: json['gender']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'username': username,
        'phone': phone,
        'avatar': avatar,
        'isOnline': isOnline,
        'statusMessage': statusMessage,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime,
        'unreadCount': unreadCount,
        'bio': bio,
        'gender': gender,
      };
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.time,
    required this.isMe,
    this.isCall = false,
    this.callDuration,
    this.imageUrl,
    this.timestamp,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String time;
  final bool isMe;
  final bool isCall;
  final String? callDuration;
  final String? imageUrl;
  final int? timestamp;

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final sId = json['senderId']?.toString() ?? json['sender_id']?.toString() ?? '';
    final rId = json['receiverId']?.toString() ?? json['targetId']?.toString() ?? json['target_id']?.toString() ?? '';
    final isMeExplicit = json['isMe'] as bool?;
    final isMe = isMeExplicit ?? (currentUserId != null ? (sId == currentUserId || sId == 'me') : (sId == 'me'));

    String timeStr = json['time']?.toString() ?? '';
    final rawTs = json['timestamp'];
    int? ts;
    if (rawTs is num) {
      ts = rawTs.toInt();
    } else if (rawTs != null) {
      ts = int.tryParse(rawTs.toString());
    }

    if (timeStr.isEmpty && ts != null && ts > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    final isCallVal = json['isCall'] as bool? ?? (json['message_type'] == 'call' || json['messageType'] == 'call');

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      senderId: sId,
      receiverId: rId,
      text: json['text']?.toString() ?? '',
      time: timeStr.isNotEmpty ? timeStr : 'Vừa xong',
      isMe: isMe,
      isCall: isCallVal,
      callDuration: json['callDuration']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString(),
      timestamp: ts,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'senderId': senderId,
        'receiverId': receiverId,
        'text': text,
        'time': time,
        'isMe': isMe,
        'isCall': isCall,
        'callDuration': callDuration,
        'imageUrl': imageUrl,
        'timestamp': timestamp,
      };
}

@immutable
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromName,
    required this.fromUsername,
    required this.phone,
    required this.avatar,
    required this.time,
  });

  final String id;
  final String fromName;
  final String fromUsername;
  final String phone;
  final String avatar;
  final String time;

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id']?.toString() ?? '',
      fromName: json['fromName']?.toString() ?? '',
      fromUsername: json['fromUsername']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fromName': fromName,
        'fromUsername': fromUsername,
        'phone': phone,
        'avatar': avatar,
        'time': time,
      };
}

