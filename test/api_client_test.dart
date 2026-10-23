import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_app_ptk/data/api_client.dart';
import 'package:flutter_app_ptk/data/tiktube_api.dart';
import 'package:flutter_app_ptk/models/auth_session.dart';
import 'package:flutter_app_ptk/models/video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Video.fromJson đọc đúng dữ liệu từ REST API', () {
    final video = Video.fromJson(<String, dynamic>{
      'id': '22222222-2222-4222-8222-222222222201',
      'title': 'Nhạc Mỹ Nhân',
      'channel': 'PTK',
      'handle': '@ptk',
      'views': 28,
      'date': '9/9/2026',
      'durationSeconds': 296,
      'category': 'Âm nhạc & sáng tạo',
      'colors': <String>['#1B3B4A', '#2F6E7C'],
      'isLive': true,
    });

    expect(video.title, 'Nhạc Mỹ Nhân');
    expect(video.durationLabel, '4:56');
    expect(video.colors, hasLength(2));
    expect(video.colors.first, const Color(0xFF1B3B4A));
    expect(video.isLive, isTrue);
  });

  test('ApiClient.fetchVideos gọi đúng endpoint và phân tích JSON', () async {
    final client = MockClient((http.Request request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/videos');
      expect(request.url.queryParameters['limit'], '100');
      return http.Response(
        jsonEncode(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': 'abc',
              'title': 'Video từ Neon',
              'channel': 'PTK',
              'handle': '@ptk',
              'views': 1234,
              'date': '9/9/2026',
              'durationSeconds': 65,
              'category': 'Giải trí',
              'colors': <String>['#111111', '#222222'],
              'isLive': false,
            },
          ],
        }),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final api = ApiClient(client: client, baseUrl: 'http://localhost:8787/');
    final videos = await api.fetchVideos();

    expect(videos, hasLength(1));
    expect(videos.single.title, 'Video từ Neon');
    expect(videos.single.viewsLabel, '1,2 N lượt xem');
  });

  test('ApiClient ném ApiException kèm thông báo lỗi của server', () async {
    final client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, String>{'error': 'Không tìm thấy video.'}),
        404,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final api = ApiClient(client: client, baseUrl: 'http://localhost:8787');

    await expectLater(
      api.fetchComments('missing'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Không tìm thấy video.'),
      ),
    );
  });

  test('ApiClient đăng nhập, nhận token và gắn Bearer vào request sau đó', () async {
    final client = MockClient((http.Request request) async {
      if (request.url.path == '/api/auth/login') {
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['login'], 'kiepthan4');
        expect(body['password'], 'TikTube@123');
        return http.Response(
          jsonEncode(<String, Object?>{
            'token': 'session-token-123',
            'profile': <String, Object?>{
              'userKey': 'kiepthan4',
              'name': 'kiepthan4',
              'email': 'kiepthan4444@gmail.com',
              'age': 18,
            },
          }),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }

      expect(request.url.path, '/api/videos');
      expect(request.headers['authorization'], 'Bearer session-token-123');
      return http.Response(
        jsonEncode(<String, Object?>{'items': <Object?>[]}),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final api = ApiClient(client: client, baseUrl: 'http://localhost:8787');
    final AuthSession session = await api.login(
      login: 'kiepthan4',
      password: 'TikTube@123',
    );

    expect(session.token, 'session-token-123');
    expect(session.profile.name, 'kiepthan4');

    api.setAuthToken(session.token);
    await api.fetchVideos();
  });

  test('ApiClient đọc thông báo và gắn Bearer khi đánh dấu đã đọc', () async {
    var markedAll = false;
    var markedOne = '';
    final client = MockClient((http.Request request) async {
      expect(request.headers['authorization'], 'Bearer token-abc');

      if (request.url.path == '/api/notifications/7/read') {
        expect(request.method, 'POST');
        markedOne = '7';
        return http.Response(
          jsonEncode(<String, Object?>{'updated': true}),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }
      if (request.url.path == '/api/notifications/read') {
        expect(request.method, 'POST');
        markedAll = true;
        return http.Response(
          jsonEncode(<String, Object?>{'updated': 1}),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }

      expect(request.method, 'GET');
      expect(request.url.path, '/api/notifications');
      return http.Response(
        jsonEncode(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': '7',
              'content': 'PTK đã thích video của bạn: Nhạc Mỹ Nhân',
              'link': 'video.html?id=2',
              'seen': false,
              'createdAt': '2026-10-23T05:41:08.000Z',
            },
          ],
          'unread': 1,
        }),
        200,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final api = ApiClient(client: client, baseUrl: 'http://localhost:8787');
    api.setAuthToken('token-abc');

    final items = await api.fetchNotifications();
    expect(items, hasLength(1));
    expect(items.single.id, '7');
    expect(items.single.seen, isFalse);
    expect(items.single.videoId, '2');
    expect(items.single.content, contains('đã thích video'));

    await api.markNotificationsRead();
    await api.markNotificationRead('7');
    expect(markedAll, isTrue);
    expect(markedOne, '7');
  });
}
