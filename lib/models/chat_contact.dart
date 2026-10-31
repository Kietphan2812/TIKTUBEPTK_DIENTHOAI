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
    );
  }

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      isOnline: json['isOnline'] as bool? ?? false,
      statusMessage: json['statusMessage']?.toString() ?? 'Đang hoạt động',
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageTime: json['lastMessageTime']?.toString() ?? '',
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      isMe: json['isMe'] as bool? ?? true,
      isCall: json['isCall'] as bool? ?? false,
      callDuration: json['callDuration']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
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

