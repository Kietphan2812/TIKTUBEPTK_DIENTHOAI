import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'cloudinary.dart';
import 'db.dart';

const int _maxUploadBytes = 100 * 1024 * 1024;
const Duration _sessionTtl = Duration(days: 30);
final Random _secureRandom = Random.secure();

const Map<String, String> _corsHeaders = <String, String>{
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers': 'Content-Type, Authorization',
  'access-control-max-age': '86400',
};

class ApiError implements Exception {
  ApiError(this.status, this.message);

  final int status;
  final String message;
}

/// Tạo handler REST cho ứng dụng Flutter.
Handler createApi(Db db, {CloudinaryService? cloudinary}) {
  final router = Router();

  router.get('/', (Request request) {
    return _json(<String, Object?>{
      'name': 'TIKTUBE API',
      'version': '2.0.0',
      'endpoints': <String>[
        'POST /api/auth/register',
        'POST /api/auth/login',
        'POST /api/auth/logout',
        'GET /health',
        'GET /api/categories',
        'GET /api/tags?category=&limit=',
        'GET /api/videos?category=&q=&limit=',
        'GET /api/videos/trending?days=&limit=&category=',
        'GET /api/feed/for-you?days=&limit=&category=',
        'GET /api/feed/subscriptions',
        'GET /api/videos/<id>',
        'POST /api/videos/upload',
        'PATCH /api/videos/<id>',
        'DELETE /api/videos/<id>',
        'GET /api/videos/<id>/comments',
        'POST /api/videos/<id>/comments',
        'DELETE /api/videos/<id>/comments/<commentId>',
        'POST /api/videos/<id>/like',
        'POST /api/videos/<id>/view',
        'POST /api/videos/<id>/watch-progress',
        'GET /api/channels',
        'GET /api/subscriptions',
        'POST /api/channels/<id>/subscribe',
        'DELETE /api/channels/<id>/subscribe',
        'GET /api/history',
        'DELETE /api/history',
        'DELETE /api/history/<videoId>',
        'GET /api/uploads',
        'GET /api/stats',
        'GET /api/notifications',
        'POST /api/notifications/read',
        'POST /api/notifications/<id>/read',
        'GET /api/me',
        'PATCH /api/me',
      ],
    });
  });

  // ---------------------------------------------------------------------------
  // Xác thực
  // ---------------------------------------------------------------------------

  router.post('/api/auth/register', (Request request) async {
    final body = await _readJson(request);
    final name = (body['name'] as String?)?.trim() ?? '';
    final username = ((body['username'] as String?) ?? '').trim().toLowerCase();
    final email = (body['email'] as String?)?.trim().toLowerCase() ?? '';
    final password = (body['password'] as String?) ?? '';
    final rawAge = body['age'];
    final age = rawAge is num ? rawAge.toInt() : int.tryParse('$rawAge');

    if (name.isEmpty || name.length > 60) {
      throw ApiError(400, 'Tên hiển thị phải có từ 1 đến 60 ký tự.');
    }
    if (!_usernamePattern.hasMatch(username)) {
      throw ApiError(
        400,
        'Tên đăng nhập phải có 3–30 ký tự, chỉ gồm chữ, số và dấu gạch dưới.',
      );
    }
    if (!_emailPattern.hasMatch(email)) {
      throw ApiError(400, 'Email không hợp lệ.');
    }
    if (password.length < 8) {
      throw ApiError(400, 'Mật khẩu phải có ít nhất 8 ký tự.');
    }
    if (password.length > 200) {
      throw ApiError(400, 'Mật khẩu quá dài (tối đa 200 ký tự).');
    }
    if (age != null && (age < 1 || age > 120)) {
      throw ApiError(400, 'Tuổi phải nằm trong khoảng 1–120.');
    }
    if (await db.userKeyExists(username)) {
      throw ApiError(409, 'Tên đăng nhập đã được sử dụng.');
    }
    if (await db.emailExists(email)) {
      throw ApiError(409, 'Email đã được sử dụng.');
    }

    final profile = await db.createUser(
      userKey: username,
      name: name,
      email: email,
      password: password,
      age: age,
    );
    if (profile == null) {
      throw ApiError(409, 'Không tạo được tài khoản. Thử tên khác nhé.');
    }

    final token = await _issueSession(db, username);
    return _json(<String, Object?>{'token': token, 'profile': profile},
        status: 201);
  });

  router.post('/api/auth/login', (Request request) async {
    final body = await _readJson(request);
    final login = (body['login'] ?? body['email'] ?? body['username'] ?? '')
        .toString()
        .trim();
    final password = (body['password'] ?? '').toString();

    if (login.isEmpty || password.isEmpty) {
      throw ApiError(400, 'Vui lòng nhập tên đăng nhập/email và mật khẩu.');
    }
    if (login.length > 120 || password.length > 200) {
      throw ApiError(400, 'Thông tin đăng nhập quá dài.');
    }

    final profile = await db.authenticate(login: login, password: password);
    if (profile == null) {
      throw ApiError(401, 'Tên đăng nhập hoặc mật khẩu không đúng.');
    }

    final token = await _issueSession(db, profile['userKey'] as String);
    return _json(<String, Object?>{'token': token, 'profile': profile});
  });

  router.post('/api/auth/logout', (Request request) async {
    final token = _bearerToken(request);
    if (token != null) {
      await db.deleteSession(_hashToken(token));
    }
    return _json(<String, Object?>{'loggedOut': true});
  });

  router.get('/health', (Request request) async {
    try {
      await db.ping();
    } catch (error) {
      return _json(
        <String, Object?>{'status': 'degraded', 'database': false},
        status: 503,
      );
    }
    return _json(<String, Object?>{
      'status': 'ok',
      'database': 'neon',
      'cloudinary': cloudinary?.configured ?? false,
      'time': DateTime.now().toUtc().toIso8601String(),
    });
  });

  router.get('/api/categories', (Request request) async {
    final categories = await db.listCategories();
    return _json(<String, Object?>{
      'items': categories.map((category) => category['name']).toList(),
    });
  });

  router.get('/api/tags', (Request request) async {
    final params = request.url.queryParameters;
    final String category = (params['category'] ?? '').trim();
    final int limit =
        (int.tryParse(params['limit'] ?? '') ?? 60).clamp(1, 100).toInt();
    final List<String> tags = await db.listTags(
      category: category,
      limit: limit,
    );
    return _json(<String, Object?>{
      'items': tags,
      'count': tags.length,
      'category': category,
    });
  });

  router.get('/api/videos', (Request request) async {
    final params = request.url.queryParameters;
    final rawLimit = int.tryParse(params['limit'] ?? '') ?? 60;
    final limit = rawLimit.clamp(1, 100);
    final userKey = await _optionalUserKey(db, request) ?? '';
    final videos = await db.listVideos(
      category: params['category'],
      query: params['q'],
      limit: limit,
      userKey: userKey,
    );
    return _json(<String, Object?>{'items': videos, 'count': videos.length});
  });

  router.get('/api/videos/trending', (Request request) async {
    final params = request.url.queryParameters;
    final int limit =
        (int.tryParse(params['limit'] ?? '') ?? 12).clamp(1, 50).toInt();
    final int days =
        (int.tryParse(params['days'] ?? '') ?? 7).clamp(1, 90).toInt();
    final userKey = await _optionalUserKey(db, request) ?? '';
    final videos = await db.listTrendingVideos(
      days: days,
      limit: limit,
      category: params['category'],
      userKey: userKey,
    );
    return _json(<String, Object?>{
      'items': videos,
      'count': videos.length,
      'windowDays': days,
      'algorithm': 'tiktube_trending_v1',
      'signals': const <String>[
        'views',
        'likes',
        'comments',
        'recentViewers',
        'subscribers',
        'freshness',
      ],
    });
  });

  router.get('/api/feed/for-you', (Request request) async {
    final params = request.url.queryParameters;
    final int limit =
        (int.tryParse(params['limit'] ?? '') ?? 24).clamp(1, 40).toInt();
    final int days =
        (int.tryParse(params['days'] ?? '') ?? 30).clamp(7, 90).toInt();
    final userKey = await _optionalUserKey(db, request) ?? '';
    final feed = await db.listForYouFeed(
      userKey: userKey,
      limit: limit,
      days: days,
      category: params['category'],
    );
    return _json(feed);
  });

  router.post('/api/videos/upload', (Request request) async {
    if (cloudinary == null || !cloudinary.configured) {
      throw ApiError(
        503,
        'Chưa cấu hình Cloudinary. Thêm CLOUDINARY_CLOUD_NAME, '
        'CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET vào server/.env.',
      );
    }

    final session = await _requireSession(db, request);
    final userKey = session['userKey'] as String;
    final params = request.url.queryParameters;
    final title = (params['title'] ?? '').trim();
    final description = (params['description'] ?? '').trim();
    final category = (params['category'] ?? '').trim();
    final filename = (params['filename'] ?? 'video.mp4').trim();
    final age = (params['age'] ?? 'kids').trim();
    final tags = _parseTags(params['tags']);

    _validateVideoFields(
      title: title,
      description: description,
      category: category,
      tags: tags,
      age: age,
    );

    final bytes = await _readBodyBytes(request);
    if (bytes.isEmpty) {
      throw ApiError(400, 'Tệp video rỗng.');
    }
    if (bytes.length > _maxUploadBytes) {
      throw ApiError(413, 'Video vượt quá giới hạn 100 MB.');
    }

    final upload = await cloudinary.uploadVideo(
      bytes: bytes,
      filename: filename.isEmpty ? 'video.mp4' : filename,
    );

    try {
      final video = await db.insertVideo(
        title: title,
        description: description,
        category: category,
        tags: tags,
        ageRating: age,
        userKey: userKey,
        videoUrl: upload.secureUrl,
        thumbnailUrl: upload.thumbnailUrl,
        publicId: upload.publicId,
        durationSeconds: upload.durationSeconds,
      );
      if (video == null) {
        throw ApiError(500, 'Không lưu được video vào database.');
      }
      return _json(<String, Object?>{'video': video}, status: 201);
    } catch (error) {
      // Tránh file mồ côi trên Cloudinary nếu bước lưu DB thất bại.
      try {
        await cloudinary.destroyVideo(upload.publicId);
      } catch (cleanupError) {
        stderr.writeln('Không dọn được video Cloudinary: $cleanupError');
      }
      rethrow;
    }
  });

  router.get('/api/videos/<id>', (Request request, String id) async {
    _validateId(id);
    final userKey = await _optionalUserKey(db, request) ?? '';
    final video = await db.findVideo(id, userKey: userKey);
    if (video == null) throw ApiError(404, 'Không tìm thấy video.');
    final comments = await db.listComments(id, currentUser: userKey);
    return _json(<String, Object?>{'video': video, 'comments': comments});
  });

  router.patch('/api/videos/<id>', (Request request, String id) async {
    _validateId(id);
    final session = await _requireSession(db, request);
    final userKey = session['userKey'] as String;
    final body = await _readJson(request);
    final title = (body['title'] as String?)?.trim() ?? '';
    final description = (body['description'] as String?)?.trim() ?? '';
    final category = (body['category'] as String?)?.trim() ?? '';
    final tags = _parseTags(body['tags']);

    _validateVideoFields(
      title: title,
      description: description,
      category: category,
      tags: tags,
      age: 'kids',
    );

    final updated = await db.updateVideo(
      id: id,
      userKey: userKey,
      title: title,
      description: description,
      category: category,
      tags: tags,
    );
    if (!updated) {
      throw ApiError(404, 'Không tìm thấy video hoặc bạn không có quyền sửa.');
    }
    final video = await db.findVideo(id, userKey: userKey);
    return _json(<String, Object?>{'video': video});
  });

  router.delete('/api/videos/<id>', (Request request, String id) async {
    _validateId(id);
    final session = await _requireSession(db, request);
    final userKey = session['userKey'] as String;
    final deleted = await db.deleteVideo(id: id, userKey: userKey);
    if (deleted == null) {
      throw ApiError(404, 'Không tìm thấy video hoặc bạn không có quyền xoá.');
    }
    var cloudinaryDeleted = false;
    final publicId = deleted['publicId'] as String?;
    if (publicId != null && publicId.isNotEmpty) {
      if (cloudinary != null && cloudinary.configured) {
        try {
          await cloudinary.destroyVideo(publicId);
          cloudinaryDeleted = true;
        } catch (error) {
          stderr.writeln('Không xoá được video Cloudinary $publicId: $error');
        }
      }
    }
    return _json(<String, Object?>{
      'deleted': true,
      'cloudinaryDeleted': cloudinaryDeleted,
    });
  });

  router.get('/api/videos/<id>/comments', (Request request, String id) async {
    _validateId(id);
    final userKey = await _optionalUserKey(db, request) ?? '';
    final comments = await db.listComments(id, currentUser: userKey);
    return _json(<String, Object?>{'items': comments});
  });

  router.post('/api/videos/<id>/comments', (Request request, String id) async {
    _validateId(id);
    final session = await _requireSession(db, request);
    final userKey = session['userKey'] as String;
    final author = (session['name'] as String?)?.trim();
    final body = await _readJson(request);
    final content = (body['content'] as String?)?.trim();

    if (content == null || content.isEmpty) {
      throw ApiError(400, 'Nội dung bình luận không được để trống.');
    }
    if (content.length > 2000) {
      throw ApiError(400, 'Bình luận quá dài (tối đa 2000 ký tự).');
    }

    final comment = await db.addComment(
      videoId: id,
      author: (author == null || author.isEmpty) ? userKey : author,
      content: content,
      currentUser: userKey,
      userKey: userKey,
    );
    if (comment == null) {
      throw ApiError(404, 'Không tìm thấy video hoặc tài khoản.');
    }
    return _json(<String, Object?>{'comment': comment}, status: 201);
  });

  router.delete(
    '/api/videos/<videoId>/comments/<commentId>',
    (Request request, String videoId, String commentId) async {
      _validateId(videoId);
      _validateId(commentId);
      final session = await _requireSession(db, request);
      final deleted = await db.deleteComment(
        videoId: videoId,
        commentId: commentId,
        currentUser: session['userKey'] as String,
      );
      if (!deleted) {
        throw ApiError(
          404,
          'Không tìm thấy bình luận hoặc bạn không có quyền xoá.',
        );
      }
      return _json(<String, Object?>{'deleted': true});
    },
  );

  router.post('/api/videos/<id>/like', (Request request, String id) async {
    _validateId(id);
    final session = await _requireSession(db, request);
    final body = await _readJson(request);
    final liked = body['liked'];
    if (liked is! bool) {
      throw ApiError(400, 'Trường "liked" phải là true hoặc false.');
    }
    final result = await db.setLike(
      videoId: id,
      liked: liked,
      userKey: session['userKey'] as String,
    );
    if (result == null) throw ApiError(404, 'Không tìm thấy video.');
    return _json(result);
  });

  router.post('/api/videos/<id>/view', (Request request, String id) async {
    _validateId(id);
    final session = await _requireSession(db, request);
    final result = await db.registerView(
      videoId: id,
      userKey: session['userKey'] as String,
    );
    if (result == null) throw ApiError(404, 'Không tìm thấy video.');
    return _json(result);
  });

  router.post(
    '/api/videos/<id>/watch-progress',
    (Request request, String id) async {
      _validateId(id);
      final session = await _requireSession(db, request);
      final body = await _readJson(request);
      final rawWatched = body['watchedSeconds'];
      final rawDuration = body['durationSeconds'];
      final int watchedSeconds = rawWatched is num
          ? rawWatched.toInt()
          : int.tryParse('$rawWatched') ?? 0;
      final int durationSeconds = rawDuration is num
          ? rawDuration.toInt()
          : int.tryParse('$rawDuration') ?? 0;
      if (watchedSeconds <= 0 || durationSeconds < 0) {
        throw ApiError(
          400,
          'watchedSeconds phải lớn hơn 0 và durationSeconds không được âm.',
        );
      }
      final updated = await db.recordWatchProgress(
        videoId: id,
        userKey: session['userKey'] as String,
        watchedSeconds: watchedSeconds,
        durationSeconds: durationSeconds,
      );
      if (!updated) {
        throw ApiError(404, 'Không tìm thấy lịch sử xem của video này.');
      }
      return _json(<String, Object?>{
        'updated': true,
        'watchedSeconds': watchedSeconds.clamp(0, 24 * 60 * 60),
        'durationSeconds': durationSeconds.clamp(0, 24 * 60 * 60),
      });
    },
  );

  // ---------------------------------------------------------------------------
  // Kênh / đăng ký
  // ---------------------------------------------------------------------------

  router.get('/api/channels', (Request request) async {
    final userKey = await _optionalUserKey(db, request) ?? '';
    final channels = await db.listChannels(userKey: userKey);
    return _json(<String, Object?>{'items': channels});
  });

  router.get('/api/subscriptions', (Request request) async {
    final session = await _requireSession(db, request);
    final channels = await db.listChannels(
      userKey: session['userKey'] as String,
      onlySubscribed: true,
    );
    return _json(<String, Object?>{'items': channels});
  });

  router.get('/api/feed/subscriptions', (Request request) async {
    final session = await _requireSession(db, request);
    final params = request.url.queryParameters;
    final int limit =
        (int.tryParse(params['limit'] ?? '') ?? 30).clamp(1, 100).toInt();
    final videos = await db.listSubscriptionFeed(
      userKey: session['userKey'] as String,
      limit: limit,
    );
    return _json(<String, Object?>{'items': videos, 'count': videos.length});
  });

  router.post(
    '/api/channels/<id>/subscribe',
    (Request request, String id) async {
      _validateId(id);
      final session = await _requireSession(db, request);
      final result = await db.setSubscription(
        channelId: id,
        subscribed: true,
        userKey: session['userKey'] as String,
      );
      if (result == null) throw ApiError(404, 'Không tìm thấy kênh.');
      return _json(result);
    },
  );

  router.delete(
    '/api/channels/<id>/subscribe',
    (Request request, String id) async {
      _validateId(id);
      final session = await _requireSession(db, request);
      final result = await db.setSubscription(
        channelId: id,
        subscribed: false,
        userKey: session['userKey'] as String,
      );
      if (result == null) throw ApiError(404, 'Không tìm thấy kênh.');
      return _json(result);
    },
  );

  // ---------------------------------------------------------------------------
  // Lịch sử / video đã đăng / thống kê / tài khoản
  // ---------------------------------------------------------------------------

  router.get('/api/history', (Request request) async {
    final session = await _requireSession(db, request);
    final items =
        await db.listWatchHistory(userKey: session['userKey'] as String);
    return _json(<String, Object?>{'items': items, 'count': items.length});
  });

  router.delete('/api/history', (Request request) async {
    final session = await _requireSession(db, request);
    await db.clearWatchHistory(session['userKey'] as String);
    return _json(<String, Object?>{'deleted': true});
  });

  router.delete('/api/history/<videoId>', (
    Request request,
    String videoId,
  ) async {
    _validateId(videoId);
    final session = await _requireSession(db, request);
    final deleted = await db.removeWatchHistory(
      userKey: session['userKey'] as String,
      videoId: videoId,
    );
    return _json(<String, Object?>{'deleted': deleted});
  });

  router.get('/api/uploads', (Request request) async {
    final session = await _requireSession(db, request);
    final items = await db.listUploads(userKey: session['userKey'] as String);
    return _json(<String, Object?>{'items': items, 'count': items.length});
  });

  router.get('/api/stats', (Request request) async {
    final session = await _requireSession(db, request);
    final stats = await db.getStats(session['userKey'] as String);
    return _json(stats);
  });

  // ---------------------------------------------------------------------------
  // Thông báo (dùng chung bảng thong_bao với web)
  // ---------------------------------------------------------------------------

  router.get('/api/notifications', (Request request) async {
    final session = await _requireSession(db, request);
    final items = await db.listNotifications(
      userKey: session['userKey'] as String,
    );
    return _json(<String, Object?>{
      'items': items,
      'unread': items.where((item) => item['seen'] != true).length,
    });
  });

  router.post('/api/notifications/read', (Request request) async {
    final session = await _requireSession(db, request);
    final updated =
        await db.markNotificationsRead(session['userKey'] as String);
    return _json(<String, Object?>{'updated': updated});
  });

  router.post('/api/notifications/<id>/read', (
    Request request,
    String id,
  ) async {
    _validateId(id);
    final session = await _requireSession(db, request);
    final updated = await db.markNotificationRead(
      userKey: session['userKey'] as String,
      notificationId: id,
    );
    if (!updated) {
      throw ApiError(404, 'Không tìm thấy thông báo.');
    }
    return _json(<String, Object?>{'updated': true});
  });

  router.get('/api/me', (Request request) async {
    final session = await _requireSession(db, request);
    return _json(<String, Object?>{'profile': session});
  });

  router.patch('/api/me', (Request request) async {
    final session = await _requireSession(db, request);
    final userKey = session['userKey'] as String;
    final body = await _readJson(request);
    final name = (body['name'] as String?)?.trim() ?? '';
    final email = (body['email'] as String?)?.trim().toLowerCase() ?? '';
    final rawAge = body['age'];
    final age = rawAge is num ? rawAge.toInt() : int.tryParse('$rawAge');

    if (name.isEmpty || name.length > 60) {
      throw ApiError(400, 'Tên phải có từ 1 đến 60 ký tự.');
    }
    if (!_emailPattern.hasMatch(email)) {
      throw ApiError(400, 'Email không hợp lệ.');
    }
    if (age != null && (age < 1 || age > 120)) {
      throw ApiError(400, 'Tuổi phải nằm trong khoảng 1–120.');
    }
    if (await db.emailExists(email, exceptUserKey: userKey)) {
      throw ApiError(409, 'Email đã được sử dụng bởi tài khoản khác.');
    }

    final profile = await db.updateProfile(
      userKey: userKey,
      name: name,
      email: email,
      age: age,
    );
    if (profile == null) throw ApiError(404, 'Không tìm thấy tài khoản.');
    return _json(<String, Object?>{'profile': profile});
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addMiddleware(_errorHandler())
      .addHandler(router.call);

  return handler;
}

Middleware _cors() {
  return (innerHandler) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return Response(204, headers: _corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

Middleware _errorHandler() {
  return (innerHandler) {
    return (request) async {
      try {
        return await innerHandler(request);
      } on ApiError catch (error) {
        return _json(<String, Object?>{'error': error.message},
            status: error.status);
      } on CloudinaryException catch (error) {
        return _json(<String, Object?>{'error': error.message},
            status: error.statusCode == 413 ? 413 : 502);
      } on FormatException catch (error) {
        return _json(<String, Object?>{'error': error.message}, status: 400);
      } catch (error, stackTrace) {
        stderr.writeln('Lỗi xử lý ${request.method} ${request.requestedUri}');
        stderr.writeln(error);
        stderr.writeln(stackTrace);
        return _json(
          <String, Object?>{'error': 'Lỗi máy chủ, vui lòng thử lại.'},
          status: 500,
        );
      }
    };
  };
}

Future<Map<String, dynamic>> _readJson(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return <String, dynamic>{};
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Body phải là một JSON object.');
  }
  return decoded;
}

Future<String> _issueSession(Db db, String userKey) async {
  await db.deleteExpiredSessions();
  final token = _newToken();
  await db.createSession(
    tokenHash: _hashToken(token),
    userKey: userKey,
    expiresAt: DateTime.now().toUtc().add(_sessionTtl),
  );
  return token;
}

String _newToken() {
  final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

Future<Map<String, Object?>> _requireSession(Db db, Request request) async {
  final token = _bearerToken(request);
  if (token == null || token.isEmpty) {
    throw ApiError(401, 'Bạn cần đăng nhập để tiếp tục.');
  }
  final profile = await db.findSession(_hashToken(token));
  if (profile == null) {
    throw ApiError(
      401,
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    );
  }
  return profile;
}

Future<String?> _optionalUserKey(Db db, Request request) async {
  final token = _bearerToken(request);
  if (token == null || token.isEmpty) return null;
  final profile = await db.findSession(_hashToken(token));
  return profile?['userKey'] as String?;
}

String? _bearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null) return null;
  final match = RegExp(r'^Bearer\s+(.+)$', caseSensitive: false)
      .firstMatch(header.trim());
  return match?.group(1)?.trim();
}

String _hashToken(String token) {
  return sha256.convert(utf8.encode(token)).toString();
}

Future<Uint8List> _readBodyBytes(Request request) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in request.read()) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

List<String> _parseTags(Object? raw) {
  final values = <String>[];
  if (raw is List) {
    for (final item in raw) {
      values.add(item.toString());
    }
  } else if (raw is String) {
    values.addAll(raw.split(','));
  }
  final unique = <String>{};
  for (final rawTag in values) {
    final tag = rawTag.trim().replaceFirst(RegExp(r'^#'), '');
    if (tag.isEmpty || tag.length > 50) continue;
    unique.add(tag);
    if (unique.length >= 20) break;
  }
  return unique.toList();
}

void _validateVideoFields({
  required String title,
  required String description,
  required String category,
  required List<String> tags,
  required String age,
}) {
  if (title.isEmpty) {
    throw ApiError(400, 'Tiêu đề video không được để trống.');
  }
  if (title.length > 200) {
    throw ApiError(400, 'Tiêu đề quá dài (tối đa 200 ký tự).');
  }
  if (description.length > 5000) {
    throw ApiError(400, 'Mô tả quá dài (tối đa 5000 ký tự).');
  }
  if (category.length > 100) {
    throw ApiError(400, 'Danh mục quá dài.');
  }
  if (tags.length > 20) {
    throw ApiError(400, 'Tối đa 20 hashtag.');
  }
  if (age != 'kids' && age != '18') {
    throw ApiError(400, 'Độ tuổi phải là "kids" hoặc "18".');
  }
}

Response _json(Object? data, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(data),
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}

final RegExp _numericIdPattern = RegExp(r'^\d{1,12}$');

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _usernamePattern = RegExp(r'^[a-z0-9_]{3,30}$');

void _validateId(String id) {
  if (!_numericIdPattern.hasMatch(id)) {
    throw ApiError(404, 'Không tìm thấy dữ liệu.');
  }
}
