import 'video.dart';

class CreatorStats {
  const CreatorStats({
    required this.videos,
    required this.views,
    required this.likes,
    required this.comments,
    required this.daily,
    required this.topVideos,
  });

  final int videos;
  final int views;
  final int likes;
  final int comments;
  final List<DailyViews> daily;
  final List<Video> topVideos;

  factory CreatorStats.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final rawDaily = json['daily'] as List<dynamic>? ?? const <dynamic>[];
    final rawVideos = json['videos'] as List<dynamic>? ?? const <dynamic>[];

    return CreatorStats(
      videos: (summary['videos'] as num?)?.toInt() ?? 0,
      views: (summary['views'] as num?)?.toInt() ?? 0,
      likes: (summary['likes'] as num?)?.toInt() ?? 0,
      comments: (summary['comments'] as num?)?.toInt() ?? 0,
      daily: rawDaily
          .map((item) => DailyViews.fromJson(item as Map<String, dynamic>))
          .toList(),
      topVideos: rawVideos
          .map((item) => Video.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DailyViews {
  const DailyViews({required this.date, required this.views});

  final DateTime date;
  final int views;

  factory DailyViews.fromJson(Map<String, dynamic> json) {
    final raw = json['date']?.toString() ?? '';
    return DailyViews(
      date: DateTime.tryParse(raw) ?? DateTime.now(),
      views: (json['views'] as num?)?.toInt() ?? 0,
    );
  }
}
