import 'package:flutter/foundation.dart';

@immutable
class Comment {
  const Comment({
    this.id,
    required this.author,
    required this.content,
    required this.date,
    this.own = false,
  });

  /// ID trong database (null với bình luận mẫu hoặc đang chờ gửi).
  final String? id;
  final String author;
  final String content;
  final String date;
  final bool own;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString(),
      author: json['author']?.toString() ?? 'Ẩn danh',
      content: json['content']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      own: json['own'] as bool? ?? false,
    );
  }
}
