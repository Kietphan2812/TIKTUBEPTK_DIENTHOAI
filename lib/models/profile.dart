import 'package:flutter/foundation.dart';

@immutable
class Profile {
  const Profile({
    required this.userKey,
    required this.name,
    required this.email,
    this.phone,
    this.age,
    this.avatarUrl,
  });

  final String userKey;
  final String name;
  final String email;
  final String? phone;
  final int? age;
  final String? avatarUrl;

  Profile copyWith({
    String? userKey,
    String? name,
    String? email,
    String? phone,
    int? age,
    String? avatarUrl,
  }) {
    return Profile(
      userKey: userKey ?? this.userKey,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userKey: json['userKey']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      age: (json['age'] as num?)?.toInt(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userKey': userKey,
        'name': name,
        'email': email,
        'phone': phone,
        'age': age,
        'avatarUrl': avatarUrl,
      };
}
