import 'package:flutter/foundation.dart';

@immutable
class Comment {
  const Comment({
    this.id,
    required this.author,
    required this.content,
    required this.date,
    this.own = false,
    this.likes = 0,
    this.liked = false,
    this.parentId,
    this.replies = const <Comment>[],
  });

  /// ID trong database (null với bình luận mẫu hoặc đang chờ gửi).
  final String? id;
  final String author;
  final String content;
  final String date;
  final bool own;
  final int likes;
  final bool liked;
  final String? parentId;
  final List<Comment> replies;

  Comment copyWith({
    String? id,
    String? author,
    String? content,
    String? date,
    bool? own,
    int? likes,
    bool? liked,
    String? parentId,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      date: date ?? this.date,
      own: own ?? this.own,
      likes: likes ?? this.likes,
      liked: liked ?? this.liked,
      parentId: parentId ?? this.parentId,
      replies: replies ?? this.replies,
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content']?.toString() ?? '';
    String? pId = json['parentId']?.toString();
    String cleanContent = rawContent;

    final reg = RegExp(r'^\[reply:([^\]]+)\]\s*');
    final match = reg.firstMatch(rawContent);
    if (match != null) {
      pId ??= match.group(1);
      cleanContent = rawContent.substring(match.end);
    }

    return Comment(
      id: json['id']?.toString(),
      author: json['author']?.toString() ?? 'Ẩn danh',
      content: cleanContent,
      date: json['date']?.toString() ?? '',
      own: json['own'] as bool? ?? false,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      liked: json['liked'] as bool? ?? false,
      parentId: pId,
      replies: (json['replies'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Comment>[],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'author': author,
        'content': content,
        'date': date,
        'own': own,
        'likes': likes,
        'liked': liked,
        'parentId': parentId,
        'replies': replies.map((e) => e.toJson()).toList(),
      };
}
