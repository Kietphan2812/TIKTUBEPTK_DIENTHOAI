import 'video.dart';

class CreatorStats {
  const CreatorStats({
    required this.videos,
    required this.views,
    required this.likes,
    required this.comments,
    this.subscribers = 0,
    required this.daily,
    required this.topVideos,
  });

  final int videos;
  final int views;
  final int likes;
  final int comments;
  final int subscribers;
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
      subscribers: (summary['subscribers'] as num?)?.toInt() ??
          (summary['subs'] as num?)?.toInt() ??
          0,
      daily: rawDaily
          .map((item) => DailyViews.fromJson(item as Map<String, dynamic>))
          .toList(),
      topVideos: rawVideos
          .map((item) => Video.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Trả về chuỗi dữ liệu thống kê chi tiết cho khoảng thời gian [days] (7 hoặc 30 ngày)
  List<DailyViews> getSeries({int days = 7}) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final Map<String, DailyViews> byDate = <String, DailyViews>{};

    for (final DailyViews item in daily) {
      final String key = _dateKey(item.date);
      byDate[key] = item;
    }

    final int totalViewsInDaily = daily.fold<int>(
      0,
      (sum, item) => sum + item.views,
    );

    final List<DailyViews> rawDays = <DailyViews>[];
    for (int i = days - 1; i >= 0; i--) {
      final DateTime date = today.subtract(Duration(days: i));
      final String key = _dateKey(date);
      final DailyViews? existing = byDate[key];

      rawDays.add(
        DailyViews(
          date: date,
          views: existing?.views ?? 0,
          likes: existing?.likes ?? 0,
          comments: existing?.comments ?? 0,
          subscribers: existing?.subscribers ?? 0,
        ),
      );
    }

    final int sumLikesInDaily = rawDays.fold(0, (s, e) => s + e.likes);
    final int sumCommentsInDaily = rawDays.fold(0, (s, e) => s + e.comments);
    final int sumSubsInDaily = rawDays.fold(0, (s, e) => s + e.subscribers);

    final bool needDistributeLikes =
        sumLikesInDaily == 0 && likes > 0 && totalViewsInDaily > 0;
    final bool needDistributeComments =
        sumCommentsInDaily == 0 && comments > 0 && totalViewsInDaily > 0;
    final bool needDistributeSubs =
        sumSubsInDaily == 0 && subscribers > 0 && totalViewsInDaily > 0;

    int remainingLikes = likes;
    int remainingComments = comments;
    int remainingSubs = subscribers;

    final List<DailyViews> result = <DailyViews>[];
    for (int i = 0; i < rawDays.length; i++) {
      final item = rawDays[i];
      int finalLikes = item.likes;
      int finalComments = item.comments;
      int finalSubs = item.subscribers;

      if (needDistributeLikes) {
        if (i == rawDays.length - 1) {
          finalLikes = remainingLikes;
        } else if (item.views > 0) {
          final int allocated = (item.views * likes / totalViewsInDaily).round();
          finalLikes = allocated.clamp(0, remainingLikes);
          remainingLikes -= finalLikes;
        } else {
          finalLikes = 0;
        }
      }

      if (needDistributeComments) {
        if (i == rawDays.length - 1) {
          finalComments = remainingComments;
        } else if (item.views > 0) {
          final int allocated =
              (item.views * comments / totalViewsInDaily).round();
          finalComments = allocated.clamp(0, remainingComments);
          remainingComments -= finalComments;
        } else {
          finalComments = 0;
        }
      }

      if (needDistributeSubs) {
        if (i == rawDays.length - 1) {
          finalSubs = remainingSubs;
        } else if (item.views > 0) {
          final int allocated =
              (item.views * subscribers / totalViewsInDaily).round();
          finalSubs = allocated.clamp(0, remainingSubs);
          remainingSubs -= finalSubs;
        } else {
          finalSubs = 0;
        }
      } else if (subscribers <= 0 && sumSubsInDaily == 0) {
        finalSubs = 0;
      }

      result.add(
        DailyViews(
          date: item.date,
          views: item.views,
          likes: finalLikes,
          comments: finalComments,
          subscribers: finalSubs,
        ),
      );
    }
    return result;
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class DailyViews {
  const DailyViews({
    required this.date,
    required this.views,
    this.likes = 0,
    this.comments = 0,
    this.subscribers = 0,
  });

  final DateTime date;
  final int views;
  final int likes;
  final int comments;
  final int subscribers;

  factory DailyViews.fromJson(Map<String, dynamic> json) {
    final raw = json['date']?.toString() ?? '';
    return DailyViews(
      date: DateTime.tryParse(raw) ?? DateTime.now(),
      views: (json['views'] as num?)?.toInt() ??
          (json['so_luot_xem'] as num?)?.toInt() ??
          0,
      likes: (json['likes'] as num?)?.toInt() ??
          (json['so_luot_thich'] as num?)?.toInt() ??
          0,
      comments: (json['comments'] as num?)?.toInt() ??
          (json['so_binh_luan'] as num?)?.toInt() ??
          0,
      subscribers: (json['subscribers'] as num?)?.toInt() ??
          (json['subs'] as num?)?.toInt() ??
          0,
    );
  }
}
