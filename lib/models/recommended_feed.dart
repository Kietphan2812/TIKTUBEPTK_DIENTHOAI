import 'video.dart';

/// Kết quả feed "Dành cho bạn" từ API Neon.
class RecommendedFeed {
  const RecommendedFeed({
    required this.videos,
    this.personalized = false,
    this.historySignals = 0,
    this.windowDays = 30,
    this.forDate = '',
    this.algorithm = '',
    this.reason = '',
  });

  final List<Video> videos;
  final bool personalized;
  final int historySignals;
  final int windowDays;
  final String forDate;
  final String algorithm;
  final String reason;

  factory RecommendedFeed.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return RecommendedFeed(
      videos: rawItems
          .whereType<Map<String, dynamic>>()
          .map(Video.fromJson)
          .toList(),
      personalized: json['personalized'] as bool? ?? false,
      historySignals: (json['historySignals'] as num?)?.toInt() ?? 0,
      windowDays: (json['windowDays'] as num?)?.toInt() ?? 30,
      forDate: json['forDate']?.toString() ?? '',
      algorithm: json['algorithm']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }
}
