import 'package:flutter/material.dart';

@immutable
class Video {
  const Video({
    required this.id,
    required this.title,
    required this.channel,
    required this.handle,
    required this.views,
    required this.date,
    required this.duration,
    required this.category,
    required this.colors,
    this.isLive = false,
    this.description = '',
    this.likeCount = 0,
    this.commentCount = 0,
    this.videoUrl,
    this.thumbnailUrl,
    this.tags = const <String>[],
    this.channelId = '',
    this.subscriberCount = 0,
    this.subscribed = false,
    this.uploadedBy = '',
    this.status = 'da_duyet',
    this.trendScore = 0,
    this.recentViews = 0,
  });

  final String id;
  final String title;
  final String channel;
  final String handle;
  final int views;
  final String date;
  final Duration duration;
  final String category;

  /// Màu gradient dùng làm ảnh thumbnail dự phòng.
  final List<Color> colors;
  final bool isLive;

  final String description;
  final int likeCount;
  final int commentCount;

  /// URL video trên Cloudinary (null với dữ liệu mẫu cũ).
  final String? videoUrl;

  /// Ảnh thumbnail thật trên Cloudinary (null thì dùng gradient).
  final String? thumbnailUrl;
  final List<String> tags;
  final String channelId;
  final int subscriberCount;
  final bool subscribed;
  final String uploadedBy;

  /// Trạng thái kiểm duyệt của web: `da_duyet`, `cho_duyet`, `tu_choi`.
  final String status;

  /// Điểm xếp hạng do API xu hướng tính từ dữ liệu Neon.
  final int trendScore;

  /// Số người xem duy nhất trong cửa sổ thời gian của bảng xu hướng.
  final int recentViews;

  bool get isApproved => status == 'da_duyet' || status == 'approved';
  bool get isRejected => status == 'tu_choi';
  bool get isPending => status == 'cho_duyet';

  String get statusLabel {
    if (isRejected) return 'Bị từ chối';
    if (isPending) return 'Chờ duyệt';
    return '';
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    final rawColors = json['colors'] as List<dynamic>? ?? const <dynamic>[];
    final colors = rawColors
        .map((value) => _parseColor(value.toString()))
        .whereType<Color>()
        .toList();
    final rawTags = json['tags'] as List<dynamic>? ?? const <dynamic>[];

    return Video(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Không có tiêu đề',
      channel: json['channel']?.toString() ?? 'Kênh',
      handle: json['handle']?.toString() ?? '@kenh',
      views: (json['views'] as num?)?.toInt() ?? 0,
      date: json['date']?.toString() ?? '',
      duration: Duration(
        seconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      ),
      category: json['category']?.toString() ?? 'Khác',
      colors: colors.length >= 2
          ? colors
          : const <Color>[Color(0xFF1B3B4A), Color(0xFF2F6E7C)],
      isLive: json['isLive'] as bool? ?? false,
      description: json['description']?.toString() ?? '',
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      videoUrl: _emptyToNull(json['videoUrl']?.toString()),
      thumbnailUrl: _emptyToNull(json['thumbnailUrl']?.toString()),
      tags: rawTags.map((value) => value.toString()).toList(),
      channelId: json['channelId']?.toString() ?? '',
      subscriberCount: (json['subscriberCount'] as num?)?.toInt() ?? 0,
      subscribed: json['subscribed'] as bool? ?? false,
      uploadedBy: json['uploadedBy']?.toString() ?? '',
      status: json['status']?.toString() ?? 'da_duyet',
      trendScore: (json['trendScore'] as num?)?.toInt() ?? 0,
      recentViews: (json['recentViews'] as num?)?.toInt() ?? 0,
    );
  }

  Video copyWith({
    int? views,
    int? likeCount,
    int? commentCount,
    int? subscriberCount,
    bool? subscribed,
    int? trendScore,
    int? recentViews,
  }) {
    return Video(
      id: id,
      title: title,
      channel: channel,
      handle: handle,
      views: views ?? this.views,
      date: date,
      duration: duration,
      category: category,
      colors: colors,
      isLive: isLive,
      description: description,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      tags: tags,
      channelId: channelId,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      subscribed: subscribed ?? this.subscribed,
      uploadedBy: uploadedBy,
      status: status,
      trendScore: trendScore ?? this.trendScore,
      recentViews: recentViews ?? this.recentViews,
    );
  }

  static String? _emptyToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Color? _parseColor(String value) {
    final hex = value.replaceAll('#', '').trim();
    if (hex.length != 6) return null;
    final number = int.tryParse(hex, radix: 16);
    if (number == null) return null;
    return Color(0xFF000000 | number);
  }

  bool get isPlayable => (videoUrl ?? '').trim().isNotEmpty;

  String get durationLabel {
    if (duration.inSeconds <= 0) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get viewsLabel {
    if (views >= 1000000) {
      final value = (views / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return '$value Tr lượt xem';
    }
    if (views >= 1000) {
      final value = (views / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return '$value N lượt xem';
    }
    return '$views lượt xem';
  }

  String get recentViewsLabel {
    if (recentViews <= 0) return 'Chưa có người xem mới';
    if (recentViews >= 1000000) {
      final value = (recentViews / 1000000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return '$value Tr người xem gần đây';
    }
    if (recentViews >= 1000) {
      final value = (recentViews / 1000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return '$value N người xem gần đây';
    }
    return '$recentViews người xem gần đây';
  }

  String get trendScoreLabel => '$trendScore điểm';

  String get subscriberLabel {
    final count = subscriberCount;
    if (count <= 0) return 'Chưa có người đăng ký';
    if (count >= 1000000) {
      final value = (count / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return '$value Tr người đăng ký';
    }
    if (count >= 1000) {
      final value = (count / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return '$value N người đăng ký';
    }
    return '$count người đăng ký';
  }

  String get initial {
    final name = channel.trim();
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }
}
