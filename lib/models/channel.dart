import 'package:flutter/material.dart';

@immutable
class Channel {
  const Channel({
    this.id = '',
    required this.name,
    required this.handle,
    required this.videoCount,
    required this.colors,
    this.subscriberCount = 0,
    this.subscribed = false,
  });

  final String id;
  final String name;
  final String handle;
  final int videoCount;
  final List<Color> colors;
  final int subscriberCount;
  final bool subscribed;

  factory Channel.fromJson(Map<String, dynamic> json) {
    final rawColors = json['colors'] as List<dynamic>? ?? const <dynamic>[];
    final colors = rawColors
        .map((value) => _parseColor(value.toString()))
        .whereType<Color>()
        .toList();
    return Channel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Kênh',
      handle: json['handle']?.toString() ?? '@kenh',
      videoCount: (json['videoCount'] as num?)?.toInt() ?? 0,
      colors: colors.length >= 2
          ? colors
          : const <Color>[Color(0xFF2E6F7E), Color(0xFF12312E)],
      subscriberCount: (json['subscriberCount'] as num?)?.toInt() ?? 0,
      subscribed: json['subscribed'] as bool? ?? false,
    );
  }

  Channel copyWith({
    int? subscriberCount,
    bool? subscribed,
  }) {
    return Channel(
      id: id,
      name: name,
      handle: handle,
      videoCount: videoCount,
      colors: colors,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      subscribed: subscribed ?? this.subscribed,
    );
  }

  static Color? _parseColor(String value) {
    final hex = value.replaceAll('#', '').trim();
    if (hex.length != 6) return null;
    final number = int.tryParse(hex, radix: 16);
    if (number == null) return null;
    return Color(0xFF000000 | number);
  }

  String get initial {
    final value = name.trim();
    if (value.isEmpty) return '?';
    return value.substring(0, 1).toUpperCase();
  }

  String get subscriberLabel {
    final count = subscriberCount;
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
}
