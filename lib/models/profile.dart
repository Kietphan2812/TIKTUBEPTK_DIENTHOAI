import 'package:flutter/foundation.dart';

@immutable
class Profile {
  const Profile({
    required this.userKey,
    required this.name,
    required this.email,
    this.age,
  });

  final String userKey;
  final String name;
  final String email;
  final int? age;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userKey: json['userKey']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userKey': userKey,
        'name': name,
        'email': email,
        'age': age,
      };
}
