import 'video.dart';

class WatchHistoryItem {
  const WatchHistoryItem({required this.video, required this.watchedAt});

  final Video video;

  /// ISO 8601 do API trả về; có thể rỗng nếu dữ liệu cũ.
  final String watchedAt;

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      video: Video.fromJson(json),
      watchedAt: json['watchedAt']?.toString() ?? '',
    );
  }

  String get watchedLabel {
    final parsed = DateTime.tryParse(watchedAt);
    if (parsed == null) return 'Đã xem gần đây';
    final local = parsed.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Vừa xem';
    if (diff.inHours < 1) return 'Đã xem ${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return 'Đã xem ${diff.inHours} giờ trước';
    if (diff.inDays < 7) return 'Đã xem ${diff.inDays} ngày trước';
    return 'Đã xem ${local.day}/${local.month}/${local.year}';
  }
}
