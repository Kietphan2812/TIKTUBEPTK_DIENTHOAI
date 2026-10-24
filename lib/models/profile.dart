import 'package:flutter/foundation.dart';

@immutable
class Profile {
  const Profile({
    required this.userKey,
    required this.name,
    required this.email,
    this.age,
    this.avatarUrl,
  });

  final String userKey;
  final String name;
  final String email;
  final int? age;
  final String? avatarUrl;

  Profile copyWith({
    String? userKey,
    String? name,
    String? email,
    int? age,
    String? avatarUrl,
  }) {
    return Profile(
      userKey: userKey ?? this.userKey,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userKey: json['userKey']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userKey': userKey,
        'name': name,
        'email': email,
        'age': age,
        'avatarUrl': avatarUrl,
      };
}
