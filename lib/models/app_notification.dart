/// Một thông báo trong bảng `thong_bao` dùng chung với web TIKTUBE.
///
/// Nội dung đã được server tạo sẵn (ví dụ: "PTK đã thích video của bạn").
/// `link` thường có dạng `video.html?id=8` hoặc `user.html?id=3`; app dùng
/// phần `id` của link video để mở đúng video khi người dùng chạm vào.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.content,
    required this.link,
    required this.seen,
    required this.createdAt,
  });

  final String id;
  final String content;
  final String link;
  final bool seen;

  /// ISO 8601 do API trả về; có thể rỗng với dữ liệu cũ.
  final String createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      seen: json['seen'] as bool? ?? false,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  AppNotification copyWith({bool? seen}) {
    return AppNotification(
      id: id,
      content: content,
      link: link,
      seen: seen ?? this.seen,
      createdAt: createdAt,
    );
  }

  /// ID video nếu thông báo trỏ tới `video.html?id=...`.
  String? get videoId {
    final match = RegExp(r'video\.html\?id=(\d+)').firstMatch(link);
    if (match != null) return match.group(1);

    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    final id = uri.queryParameters['id'];
    if (id == null || id.isEmpty) return null;
    if (uri.path.endsWith('video.html')) return id;
    return null;
  }

  String get timeLabel {
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return 'Gần đây';
    final local = parsed.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.isNegative || diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${local.day}/${local.month}/${local.year}';
  }
}
