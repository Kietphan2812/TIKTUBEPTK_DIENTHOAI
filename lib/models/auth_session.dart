import 'package:flutter/foundation.dart';

import 'profile.dart';

/// Phiên đăng nhập trả về từ API: bearer token + hồ sơ người dùng.
@immutable
class AuthSession {
  const AuthSession({required this.token, required this.profile});

  final String token;
  final Profile profile;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token']?.toString() ?? '',
      profile: Profile.fromJson(
        (json['profile'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'token': token,
        'profile': profile.toJson(),
      };
}
