import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

/// Truy cập Neon Postgres qua connection pool.
///
/// Database đích là schema web TIKTUBETPK (các bảng tiếng Việt:
/// `nguoi_dung`, `video`, `binh_luan`, ...). App không tạo schema song song;
/// mọi video upload từ web hoặc app đều nằm trong cùng bảng `video`.
class Db {
  Db._(this._pool);

  final Pool _pool;

  static Future<Db> open(String databaseUrl) async {
    final pool = Pool.withUrl(_withPoolSettings(databaseUrl));
    await pool.execute('select 1').timeout(const Duration(seconds: 20));
    final db = Db._(pool);
    try {
      await db.ensureAppSchema();
    } catch (_) {
      await pool.close();
      rethrow;
    }
    return db;
  }

  static String _withPoolSettings(String url) {
    final extra = <String>[
      if (!url.contains('max_connection_count')) 'max_connection_count=5',
      if (!url.contains('connect_timeout')) 'connect_timeout=10',
      if (!url.contains('max_connection_age')) 'max_connection_age=300',
    ];
    if (extra.isEmpty) return url;
    return '$url${url.contains('?') ? '&' : '?'}${extra.join('&')}';
  }

  Future<void> close() => _pool.close();

  Future<void> ping() async {
    await _pool.execute('select 1');
  }

  /// Phần schema riêng của app, không đụng tới dữ liệu web.
  Future<void> ensureAppSchema() async {
    await _pool.execute('''
create table if not exists app_sessions (
  token_hash text primary key,
  nguoi_dung_id integer not null
    references nguoi_dung(nguoi_dung_id) on delete cascade,
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone not null default now()
)
''');
    await _pool.execute('''
create index if not exists app_sessions_expires_idx
on app_sessions (expires_at)
''');
    await _pool.execute('''
alter table nguoi_dung
add column if not exists ten_hien_thi varchar(60)
''');

    // Lưu thời lượng đã xem để gợi ý video cùng chủ đề chính xác hơn. Hai cột
    // này chỉ bổ sung cho bảng lịch sử của web, không thay đổi dữ liệu cũ.
    await _pool.execute('''
alter table lich_su_xem
add column if not exists thoi_luong_xem double precision not null default 0
''');
    await _pool.execute('''
alter table lich_su_xem
add column if not exists thoi_luong_video double precision not null default 0
''');
    await _pool.execute('''
create index if not exists app_lich_su_xem_user_time_idx
on lich_su_xem (nguoi_dung_id, thoi_gian_xem desc)
''');
    await _pool.execute('''
create index if not exists app_luot_thich_user_time_idx
on luot_thich (nguoi_dung_id, ngay_tao desc)
''');
    await _pool.execute('''
create index if not exists app_binh_luan_user_time_idx
on binh_luan (nguoi_dung_id, ngay_tao desc)
''');

    // Video đã lưu (bookmark) là dữ liệu riêng của app, không sửa bảng web.
    await _pool.execute('''
create table if not exists app_saved_videos (
  nguoi_dung_id integer not null
    references nguoi_dung(nguoi_dung_id) on delete cascade,
  video_id integer not null
    references video(video_id) on delete cascade,
  created_at timestamp with time zone not null default now(),
  primary key (nguoi_dung_id, video_id)
)
''');
    await _pool.execute('''
create index if not exists app_saved_videos_user_time_idx
on app_saved_videos (nguoi_dung_id, created_at desc)
''');
  }

  // ---------------------------------------------------------------------------
  // Xác thực / phiên đăng nhập
  // ---------------------------------------------------------------------------

  Future<bool> userKeyExists(String userKey) async {
    final result = await _pool.execute(
      Sql.named('''
select 1 from nguoi_dung
where lower(ten_dang_nhap) = lower(@userKey)
limit 1
'''),
      parameters: {'userKey': userKey},
    );
    return result.isNotEmpty;
  }

  Future<bool> emailExists(String email, {String? exceptUserKey}) async {
    final result = await _pool.execute(
      Sql.named('''
select 1 from nguoi_dung
where lower(email) = lower(@email)
  and (
    @exceptUserKey::text is null
    or lower(ten_dang_nhap) <> lower(@exceptUserKey)
  )
limit 1
'''),
      parameters: {'email': email, 'exceptUserKey': exceptUserKey},
    );
    return result.isNotEmpty;
  }

  /// Tạo tài khoản mới trong bảng `nguoi_dung` của web.
  ///
  /// Hash SHA-256 (hex) để tài khoản tạo từ app vẫn đăng nhập được trên web —
  /// web hiện dùng đúng kiểu hash này. Không dùng bcrypt vì sẽ phá tương thích.
  Future<Map<String, Object?>?> createUser({
    required String userKey,
    required String name,
    required String email,
    required String password,
    int? age,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
insert into nguoi_dung (
  ten_dang_nhap, ten_hien_thi, email, mat_khau_hash, do_tuoi
) values (
  @userKey, @name, lower(@email), @passwordHash, @age
)
on conflict do nothing
returning nguoi_dung_id, ten_dang_nhap,
          coalesce(nullif(ten_hien_thi, ''), ten_dang_nhap),
          email, do_tuoi, anh_dai_dien
'''),
      parameters: {
        'userKey': userKey,
        'name': name,
        'email': email,
        'passwordHash': _passwordHash(password),
        'age': (age ?? 18).toString(),
      },
    );
    if (result.isEmpty) return null;
    return _profileFromRow(result.first);
  }

  /// Xác thực theo tên đăng nhập hoặc email.
  ///
  /// Tài khoản web hiện lưu SHA-256 không salt (64 ký tự hex). Tài khoản mới
  /// do app tạo cũng dùng cùng định dạng để web và app dùng chung mật khẩu.
  Future<Map<String, Object?>?> authenticate({
    required String login,
    required String password,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
select nguoi_dung_id, ten_dang_nhap,
       coalesce(nullif(ten_hien_thi, ''), ten_dang_nhap),
       email, do_tuoi, anh_dai_dien, mat_khau_hash
from nguoi_dung
where lower(ten_dang_nhap) = lower(@login)
   or lower(email) = lower(@login)
limit 1
'''),
      parameters: {'login': login},
    );
    if (result.isEmpty) return null;

    final row = result.first;
    final stored = (row[6] as String?)?.trim().toLowerCase();
    if (stored == null || stored.isEmpty) return null;
    final actual = _passwordHash(password);
    if (!_safeEquals(stored, actual)) return null;
    return _profileFromRow(row);
  }

  Future<void> createSession({
    required String tokenHash,
    required String userKey,
    required DateTime expiresAt,
  }) async {
    await _pool.execute(
      Sql.named('''
insert into app_sessions (token_hash, nguoi_dung_id, expires_at)
select @tokenHash, nguoi_dung_id, @expiresAt
from nguoi_dung
where lower(ten_dang_nhap) = lower(@userKey)
on conflict (token_hash) do nothing
'''),
      parameters: {
        'tokenHash': tokenHash,
        'userKey': userKey,
        'expiresAt': expiresAt,
      },
    );
  }

  Future<Map<String, Object?>?> findSession(String tokenHash) async {
    final result = await _pool.execute(
      Sql.named('''
select u.nguoi_dung_id, u.ten_dang_nhap,
       coalesce(nullif(u.ten_hien_thi, ''), u.ten_dang_nhap),
       u.email, u.do_tuoi, u.anh_dai_dien
from app_sessions s
join nguoi_dung u on u.nguoi_dung_id = s.nguoi_dung_id
where s.token_hash = @tokenHash and s.expires_at > now()
limit 1
'''),
      parameters: {'tokenHash': tokenHash},
    );
    if (result.isEmpty) return null;
    return _profileFromRow(result.first);
  }

  Future<void> deleteSession(String tokenHash) async {
    await _pool.execute(
      Sql.named('delete from app_sessions where token_hash = @tokenHash'),
      parameters: {'tokenHash': tokenHash},
    );
  }

  Future<void> deleteExpiredSessions() async {
    await _pool.execute('delete from app_sessions where expires_at <= now()');
  }

  // ---------------------------------------------------------------------------
  // Danh mục / video
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> listCategories() async {
    final result = await _pool.execute(
      'select ten_danh_muc from danh_muc order by danh_muc_id',
    );
    return result.map((row) => <String, Object?>{'name': row[0]}).toList();
  }

  /// Thẻ tag đã liên kết với danh mục trong bảng `the_tag`.
  ///
  /// Trả về tên tag không kèm dấu `#` để UI tự định dạng.
  Future<List<String>> listTags({
    String? category,
    int limit = 60,
  }) async {
    final normalizedCategory = category?.trim() ?? '';
    final result = await _pool.execute(
      Sql.named('''
select t.ten_tag
from the_tag t
join danh_muc dm on dm.danh_muc_id = t.danh_muc_id
where (@category = '' or lower(dm.ten_danh_muc) = lower(@category))
order by t.tag_id
limit @limit
'''),
      parameters: <String, Object?>{
        'category': normalizedCategory,
        'limit': limit,
      },
    );
    final tags = <String>[];
    final seen = <String>{};
    for (final row in result) {
      final raw = row[0]?.toString().trim() ?? '';
      final name = raw.replaceFirst(RegExp(r'^#+'), '');
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      tags.add(name);
    }
    return tags;
  }

  Future<List<Map<String, Object?>>> listVideos({
    String? category,
    String? query,
    int limit = 60,
    String userKey = '',
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    final where = <String>["v.trang_thai in ('da_duyet', 'approved')"];
    final params = <String, Object?>{
      'limit': limit,
      'currentUserId': currentUserId,
    };

    if (category != null && category.trim().isNotEmpty) {
      where.add('dm.ten_danh_muc = @category');
      params['category'] = category.trim();
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add('''
(
  v.tieu_de ilike @query
  or coalesce(v.mo_ta, '') ilike @query
  or u.ten_dang_nhap ilike @query
  or coalesce(dm.ten_danh_muc, '') ilike @query
)
''');
      params['query'] = '%${query.trim()}%';
    }

    final sql = '''
select $_videoSelect
from video v
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
where ${where.join(' and ')}
order by v.ngay_tao desc nulls last
limit @limit
''';

    final result = await _pool.execute(Sql.named(sql), parameters: params);
    return result.map(_videoFromRow).toList();
  }

  /// Xếp hạng video thịnh hành bằng tín hiệu thật từ Neon.
  ///
  /// Điểm xu hướng kết hợp lượt xem trọn đời, lượt thích, bình luận, số người
  /// xem duy nhất trong [days] ngày gần nhất, quy mô kênh và độ mới của video.
  /// Các tín hiệu được log hoá để video có ít lượt xem vẫn có cơ hội xuất hiện,
  /// sau đó chia cho hệ số suy giảm theo tuổi video.
  Future<List<Map<String, Object?>>> listTrendingVideos({
    int days = 7,
    int limit = 12,
    String? category,
    String userKey = '',
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    final int windowDays = days.clamp(1, 90).toInt();
    final params = <String, Object?>{
      'limit': limit.clamp(1, 50).toInt(),
      'days': windowDays,
      'currentUserId': currentUserId,
    };
    final filters = <String>["v.trang_thai in ('da_duyet', 'approved')"];
    if (category != null &&
        category.trim().isNotEmpty &&
        category.trim() != 'Tất cả') {
      filters.add('dm.ten_danh_muc = @category');
      params['category'] = category.trim();
    }

    final result = await _pool.execute(
      Sql.named('''
with metrics as (
  select
    v.video_id,
    greatest(coalesce(v.luot_xem, 0), 0)::numeric as total_views,
    (
      select count(*)::int
      from luot_thich lt
      where lt.video_id = v.video_id
    )::numeric as like_count,
    (
      select count(*)::int
      from binh_luan bl
      where bl.video_id = v.video_id
    )::numeric as comment_count,
    (
      select count(distinct lx.nguoi_dung_id)::int
      from lich_su_xem lx
      where lx.video_id = v.video_id
        and lx.thoi_gian_xem >= now() - make_interval(days => @days::int)
    )::numeric as recent_view_count,
    (
      select count(*)::int
      from dang_ky_kenh dk
      where dk.kenh_id = v.nguoi_dung_id
    )::numeric as channel_subscribers,
    greatest(
      extract(epoch from (now() - coalesce(v.ngay_tao, now()))) / 86400.0,
      0
    )::numeric as age_days
  from video v
  where v.trang_thai in ('da_duyet', 'approved')
)
select $_videoSelect,
       greatest(
         0,
         round(
           100.0 * (
             ln(1.0 + m.total_views) * 2.0
             + ln(1.0 + m.like_count) * 5.0
             + ln(1.0 + m.comment_count) * 7.0
             + ln(1.0 + m.recent_view_count) * 9.0
             + ln(1.0 + m.channel_subscribers) * 0.8
           ) / power(m.age_days + 2.0, 0.65)
         )
       )::bigint as trend_score,
       m.recent_view_count::int as recent_views
from metrics m
join video v on v.video_id = m.video_id
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
where ${filters.join(' and ')}
order by trend_score desc, v.ngay_tao desc nulls last, v.video_id desc
limit @limit
'''),
      parameters: params,
    );
    return result.map(_trendingVideoFromRow).toList();
  }

  /// Feed "Dành cho bạn" dựa trên hành vi thật của người dùng.
  ///
  /// Tín hiệu được lấy từ `lich_su_xem` (có cả thời lượng đã xem), lượt thích,
  /// bình luận, danh mục, hashtag trong `video.mo_ta`/`the_tag` và các kênh đã
  /// đăng ký. Video thuộc kênh đã đăng ký được xếp trước trong 45 ngày gần đây;
  /// sau đó mới xếp theo điểm sở thích + tín hiệu xu hướng + độ mới. Cửa sổ hành
  /// vi mặc định là 30 ngày và được làm mới theo ngày.
  Future<Map<String, Object?>> listForYouFeed({
    String userKey = '',
    int limit = 24,
    int days = 30,
    String? category,
  }) async {
    final int safeLimit = limit.clamp(1, 40).toInt();
    final int historyDays = days.clamp(7, 90).toInt();
    final String normalizedCategory = (category ?? '').trim();
    final bool hasCategory =
        normalizedCategory.isNotEmpty && normalizedCategory != 'Tất cả';
    final int? currentUserId = await _userIdForKey(userKey);

    if (currentUserId == null) {
      final items = await listTrendingVideos(
        days: 7,
        limit: safeLimit,
        category: hasCategory ? normalizedCategory : null,
      );
      return <String, Object?>{
        'items': items,
        'count': items.length,
        'personalized': false,
        'historySignals': 0,
        'windowDays': 7,
        'forDate': _todayForFeed(),
        'algorithm': 'tiktube_trending_v1',
        'reason': 'guest',
        'signals': const <String>[
          'views',
          'likes',
          'comments',
          'recentViewers',
          'subscribers',
          'freshness',
        ],
      };
    }

    final stats = await _pool.execute(
      Sql.named('''
select current_date::text,
       (
         select count(*)::int
         from lich_su_xem lx
         where lx.nguoi_dung_id = @currentUserId
           and lx.thoi_gian_xem >= now() - make_interval(days => @historyDays::int)
       )
'''),
      parameters: <String, Object?>{
        'currentUserId': currentUserId,
        'historyDays': historyDays,
      },
    );
    final String forDate =
        stats.isEmpty ? _todayForFeed() : stats.first[0]?.toString() ?? '';
    final int historySignals = stats.isEmpty ? 0 : _asInt(stats.first[1]) ?? 0;

    final filters = <String>["v.trang_thai in ('da_duyet', 'approved')"];
    final params = <String, Object?>{
      'currentUserId': currentUserId,
      'historyDays': historyDays,
      'decayDays': 14.0,
      'limit': safeLimit,
    };
    if (hasCategory) {
      filters.add('dm.ten_danh_muc = @category');
      params['category'] = normalizedCategory;
    }

    final result = await _pool.execute(
      Sql.named('''
with history as (
  select lx.video_id,
         lx.thoi_gian_xem as event_at,
         (
           1.0 + 2.0 * case
             when coalesce(lx.thoi_luong_video, 0) > 0
             then least(
               1.0,
               greatest(
                 0.0,
                 coalesce(lx.thoi_luong_xem, 0) / lx.thoi_luong_video
               )
             )
             else 0.5
           end
         )::numeric as weight
  from lich_su_xem lx
  where lx.nguoi_dung_id = @currentUserId
    and lx.thoi_gian_xem >= now() - make_interval(days => @historyDays::int)
  union all
  select lt.video_id, lt.ngay_tao, 4.0::numeric
  from luot_thich lt
  where lt.nguoi_dung_id = @currentUserId
    and lt.ngay_tao >= now() - make_interval(days => @historyDays::int)
  union all
  select bl.video_id, bl.ngay_tao, 5.0::numeric
  from binh_luan bl
  where bl.nguoi_dung_id = @currentUserId
    and bl.ngay_tao >= now() - make_interval(days => @historyDays::int)
),
history_videos as (
  select h.video_id, h.event_at, h.weight,
         v.danh_muc_id, coalesce(v.mo_ta, '') as mo_ta, v.tag_id
  from history h
  join video v on v.video_id = h.video_id
),
category_affinity as (
  select hv.danh_muc_id,
         sum(
           hv.weight * exp(
             -greatest(
               extract(epoch from (now() - hv.event_at))::double precision,
               0.0
             ) / 86400.0 / @decayDays::double precision
           )
         ) as affinity
  from history_videos hv
  where hv.danh_muc_id is not null
  group by hv.danh_muc_id
),
history_tags as (
  select lower(regexp_replace(m.match[1], '[.,;:!?]+\$', '')) as tag,
         hv.weight, hv.event_at
  from history_videos hv
  cross join lateral regexp_matches(
    hv.mo_ta,
    '#([^[:space:]#]+)',
    'g'
  ) as m(match)
  union all
  select lower(regexp_replace(tt.ten_tag, '^#+', '')),
         hv.weight, hv.event_at
  from history_videos hv
  join the_tag tt on tt.tag_id = hv.tag_id
  where hv.tag_id is not null
),
tag_affinity as (
  select tag,
         sum(
           weight * exp(
             -greatest(
               extract(epoch from (now() - event_at))::double precision,
               0.0
             ) / 86400.0 / @decayDays::double precision
           )
         ) as affinity
  from history_tags
  where tag <> ''
  group by tag
),
metrics as (
  select v.video_id,
         v.danh_muc_id,
         greatest(coalesce(v.luot_xem, 0), 0)::numeric as total_views,
         (
           select count(*)::int
           from luot_thich lt2
           where lt2.video_id = v.video_id
         )::numeric as like_count,
         (
           select count(*)::int
           from binh_luan bl2
           where bl2.video_id = v.video_id
         )::numeric as comment_count,
         (
           select count(distinct lx2.nguoi_dung_id)::int
           from lich_su_xem lx2
           where lx2.video_id = v.video_id
             and lx2.thoi_gian_xem >= now() - make_interval(days => 7)
         )::numeric as recent_view_count,
         (
           select count(*)::int
           from dang_ky_kenh dk
           where dk.kenh_id = v.nguoi_dung_id
         )::numeric as channel_subscribers,
         greatest(
           extract(epoch from (now() - coalesce(v.ngay_tao, now())))
             ::double precision / 86400.0,
           0.0
         )::numeric as age_days,
         exists(
           select 1 from dang_ky_kenh dks
           where dks.kenh_id = v.nguoi_dung_id
             and dks.nguoi_dung_id = @currentUserId
         ) as is_subscribed,
         (
           select max(lx3.thoi_gian_xem)
           from lich_su_xem lx3
           where lx3.video_id = v.video_id
             and lx3.nguoi_dung_id = @currentUserId
         ) as last_watched_at
  from video v
  where v.trang_thai in ('da_duyet', 'approved')
),
candidate_tags as (
  select v.video_id,
         lower(regexp_replace(m.match[1], '[.,;:!?]+\$', '')) as tag
  from video v
  cross join lateral regexp_matches(
    coalesce(v.mo_ta, ''),
    '#([^[:space:]#]+)',
    'g'
  ) as m(match)
  union
  select v.video_id,
         lower(regexp_replace(tt.ten_tag, '^#+', '')) as tag
  from video v
  join the_tag tt on tt.tag_id = v.tag_id
  where v.tag_id is not null
),
tag_scores as (
  select ct.video_id, sum(ta.affinity) as tag_score
  from candidate_tags ct
  join tag_affinity ta on ta.tag = ct.tag
  where ct.tag <> ''
  group by ct.video_id
),
candidate_scores as (
  select m.video_id,
         m.is_subscribed,
         m.age_days,
         m.last_watched_at,
         coalesce(ca.affinity, 0) as category_affinity,
         coalesce(ts.tag_score, 0) as tag_score,
         greatest(
           0::bigint,
           round(
             100.0 * (
               ln(1.0 + coalesce(ca.affinity, 0)) * 4.0
               + ln(1.0 + coalesce(ts.tag_score, 0)) * 3.0
               + ln(1.0 + m.like_count) * 1.2
               + ln(1.0 + m.comment_count) * 1.5
               + ln(1.0 + m.recent_view_count) * 2.0
               + ln(1.0 + m.total_views) * 0.4
               + ln(1.0 + m.channel_subscribers) * 0.3
               + 1.0 / (m.age_days + 1.0)
             )
             + case when m.is_subscribed then 18.0 else 0.0 end
             - case
                 when m.last_watched_at >= now() - interval '2 days'
                 then 4.0
                 else 0.0
               end
           )::bigint
         ) as recommendation_score
  from metrics m
  left join category_affinity ca on ca.danh_muc_id = m.danh_muc_id
  left join tag_scores ts on ts.video_id = m.video_id
)
select $_videoSelect,
       cs.recommendation_score,
       case
         when cs.is_subscribed then 'subscription'
         when cs.category_affinity > 0 and cs.tag_score > 0 then 'category_tag'
         when cs.category_affinity > 0 then 'category'
         when cs.tag_score > 0 then 'tag'
         else 'trending'
       end as recommendation_reason
from candidate_scores cs
join video v on v.video_id = cs.video_id
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
where ${filters.join(' and ')}
order by
  (cs.is_subscribed and cs.age_days <= 45) desc,
  cs.recommendation_score desc,
  md5(v.video_id::text || current_date::text),
  v.ngay_tao desc nulls last,
  v.video_id desc
limit @limit
'''),
      parameters: params,
    );

    if (result.isEmpty) {
      final fallback = await listVideos(
        category: hasCategory ? normalizedCategory : null,
        limit: safeLimit,
        userKey: userKey,
      );
      return <String, Object?>{
        'items': fallback,
        'count': fallback.length,
        'personalized': false,
        'historySignals': historySignals,
        'windowDays': historyDays,
        'forDate': forDate,
        'algorithm': 'tiktube_for_you_v1',
        'reason': 'fallback',
        'signals': const <String>['freshness'],
      };
    }

    final items = result.map(_forYouVideoFromRow).toList();
    return <String, Object?>{
      'items': items,
      'count': items.length,
      'personalized': historySignals > 0,
      'historySignals': historySignals,
      'windowDays': historyDays,
      'forDate': forDate,
      'algorithm': 'tiktube_for_you_v1',
      'reason': historySignals > 0 ? 'history' : 'subscriptions_and_trending',
      'signals': const <String>[
        'watchHistory',
        'watchCompletion',
        'likes',
        'comments',
        'categories',
        'hashtags',
        'subscriptions',
        'recentViewers',
        'freshness',
      ],
    };
  }

  Future<Map<String, Object?>?> findVideo(
    String id, {
    String userKey = '',
  }) async {
    final videoId = _intId(id);
    if (videoId == null) return null;
    final currentUserId = await _userIdForKey(userKey);
    final result = await _pool.execute(
      Sql.named('''
select $_videoSelect
from video v
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
where v.video_id = @videoId
'''),
      parameters: {
        'videoId': videoId,
        'currentUserId': currentUserId,
      },
    );
    if (result.isEmpty) return null;
    return _videoFromRow(result.first);
  }

  Future<List<Map<String, Object?>>> listComments(
    String videoId, {
    String currentUser = '',
  }) async {
    final id = _intId(videoId);
    if (id == null) return const <Map<String, Object?>>[];
    final currentUserId = await _userIdForKey(currentUser);
    final result = await _pool.execute(
      Sql.named('''
select bl.binh_luan_id,
       coalesce(nullif(u.ten_hien_thi, ''), u.ten_dang_nhap),
       bl.noi_dung, bl.ngay_tao, bl.nguoi_dung_id
from binh_luan bl
join nguoi_dung u on u.nguoi_dung_id = bl.nguoi_dung_id
where bl.video_id = @videoId
order by bl.ngay_tao desc
'''),
      parameters: {'videoId': id},
    );
    return result
        .map((row) => _commentFromRow(row, currentUserId: currentUserId))
        .toList();
  }

  Future<Map<String, Object?>?> addComment({
    required String videoId,
    required String author,
    required String content,
    String currentUser = '',
    String? userKey,
  }) async {
    final id = _intId(videoId);
    final actorKey = (userKey ?? currentUser).trim();
    if (id == null || actorKey.isEmpty) return null;

    return _pool.runTx((tx) async {
      final actorId = await _userIdForKey(actorKey, session: tx);
      if (actorId == null) return null;

      final video = await tx.execute(
        Sql.named(
          'select nguoi_dung_id, tieu_de from video where video_id = @videoId',
        ),
        parameters: {'videoId': id},
      );
      if (video.isEmpty) return null;
      final ownerId = _asInt(video.first[0]);
      final videoTitle = video.first[1]?.toString() ?? 'video';

      final result = await tx.execute(
        Sql.named('''
with inserted as (
  insert into binh_luan (video_id, nguoi_dung_id, noi_dung)
  values (@videoId, @actorId, @content)
  returning binh_luan_id, nguoi_dung_id, noi_dung, ngay_tao
)
select i.binh_luan_id,
       coalesce(nullif(u.ten_hien_thi, ''), u.ten_dang_nhap),
       i.noi_dung, i.ngay_tao, i.nguoi_dung_id
from inserted i
join nguoi_dung u on u.nguoi_dung_id = i.nguoi_dung_id
'''),
        parameters: {
          'videoId': id,
          'actorId': actorId,
          'content': content,
        },
      );

      if (ownerId != null) {
        await _bumpStats(tx, ownerId, comments: 1);
        if (ownerId != actorId) {
          final actorName = await _displayNameFor(tx, actorId);
          await _insertNotification(
            tx,
            userId: ownerId,
            content: '$actorName đã bình luận: "$content" '
                '(trên video: $videoTitle)',
            link: 'video.html?id=$id',
          );
        }
      }
      return _commentFromRow(result.first, currentUserId: actorId);
    });
  }

  Future<bool> deleteComment({
    required String videoId,
    required String commentId,
    String currentUser = '',
  }) async {
    final vId = _intId(videoId);
    final cId = _intId(commentId);
    if (vId == null || cId == null || currentUser.trim().isEmpty) return false;

    return _pool.runTx((tx) async {
      final actorId = await _userIdForKey(currentUser, session: tx);
      if (actorId == null) return false;

      final owner = await tx.execute(
        Sql.named('''
select v.nguoi_dung_id, bl.ngay_tao
from binh_luan bl
join video v on v.video_id = bl.video_id
where bl.binh_luan_id = @commentId
  and bl.video_id = @videoId
  and bl.nguoi_dung_id = @actorId
'''),
        parameters: {
          'commentId': cId,
          'videoId': vId,
          'actorId': actorId,
        },
      );
      if (owner.isEmpty) return false;

      final deleted = await tx.execute(
        Sql.named('''
delete from binh_luan
where binh_luan_id = @commentId
  and video_id = @videoId
  and nguoi_dung_id = @actorId
'''),
        parameters: {
          'commentId': cId,
          'videoId': vId,
          'actorId': actorId,
        },
      );
      if (deleted.affectedRows == 0) return false;

      final ownerId = _asInt(owner.first[0]);
      final commentDate = owner.first[1] as DateTime?;
      if (ownerId != null) {
        await _bumpStats(tx, ownerId, comments: -1, day: commentDate);
      }
      return true;
    });
  }

  Future<Map<String, Object?>?> setLike({
    required String videoId,
    required bool liked,
    required String userKey,
  }) async {
    final id = _intId(videoId);
    if (id == null) return null;

    return _pool.runTx((tx) async {
      final actorId = await _userIdForKey(userKey, session: tx);
      if (actorId == null) return null;

      final video = await tx.execute(
        Sql.named(
          'select nguoi_dung_id, tieu_de from video where video_id = @videoId',
        ),
        parameters: {'videoId': id},
      );
      if (video.isEmpty) return null;
      final ownerId = _asInt(video.first[0]);
      final videoTitle = video.first[1]?.toString() ?? 'video';

      var delta = 0;
      if (liked) {
        final inserted = await tx.execute(
          Sql.named('''
insert into luot_thich (video_id, nguoi_dung_id)
values (@videoId, @actorId)
on conflict (video_id, nguoi_dung_id) do nothing
'''),
          parameters: {'videoId': id, 'actorId': actorId},
        );
        if (inserted.affectedRows > 0) delta = 1;
      } else {
        final deleted = await tx.execute(
          Sql.named('''
delete from luot_thich
where video_id = @videoId and nguoi_dung_id = @actorId
'''),
          parameters: {'videoId': id, 'actorId': actorId},
        );
        if (deleted.affectedRows > 0) delta = -1;
      }

      final count = await tx.execute(
        Sql.named(
          'select count(*)::int from luot_thich where video_id = @videoId',
        ),
        parameters: {'videoId': id},
      );

      if (delta != 0 && ownerId != null) {
        await _bumpStats(tx, ownerId, likes: delta);
        if (delta > 0 && ownerId != actorId) {
          final actorName = await _displayNameFor(tx, actorId);
          await _insertNotification(
            tx,
            userId: ownerId,
            content: '$actorName đã thích video của bạn: $videoTitle',
            link: 'video.html?id=$id',
          );
        }
      }

      return <String, Object?>{
        'liked': liked,
        'likeCount': count.first[0],
      };
    });
  }

  /// Lưu / bỏ lưu video cho riêng tài khoản đang đăng nhập.
  Future<Map<String, Object?>?> setSaved({
    required String videoId,
    required bool saved,
    required String userKey,
  }) async {
    final id = _intId(videoId);
    if (id == null) return null;

    return _pool.runTx((tx) async {
      final actorId = await _userIdForKey(userKey, session: tx);
      if (actorId == null) return null;

      final video = await tx.execute(
        Sql.named('select 1 from video where video_id = @videoId'),
        parameters: {'videoId': id},
      );
      if (video.isEmpty) return null;

      if (saved) {
        await tx.execute(
          Sql.named('''
insert into app_saved_videos (nguoi_dung_id, video_id)
values (@actorId, @videoId)
on conflict (nguoi_dung_id, video_id) do nothing
'''),
          parameters: {'actorId': actorId, 'videoId': id},
        );
      } else {
        await tx.execute(
          Sql.named('''
delete from app_saved_videos
where nguoi_dung_id = @actorId and video_id = @videoId
'''),
          parameters: {'actorId': actorId, 'videoId': id},
        );
      }

      final count = await tx.execute(
        Sql.named('''
select count(*)::int
from app_saved_videos
where video_id = @videoId
'''),
        parameters: {'videoId': id},
      );

      return <String, Object?>{
        'saved': saved,
        'saveCount': count.first[0],
      };
    });
  }

  Future<Map<String, Object?>?> registerView({
    required String videoId,
    String userKey = '',
  }) async {
    final id = _intId(videoId);
    if (id == null || userKey.trim().isEmpty) return null;

    return _pool.runTx((tx) async {
      final actorId = await _userIdForKey(userKey, session: tx);
      if (actorId == null) return null;

      final updated = await tx.execute(
        Sql.named('''
update video
set luot_xem = coalesce(luot_xem, 0) + 1,
    ngay_cap_nhat = now()
where video_id = @videoId
returning luot_xem, nguoi_dung_id
'''),
        parameters: {'videoId': id},
      );
      if (updated.isEmpty) return null;

      await tx.execute(
        Sql.named('''
insert into lich_su_xem (nguoi_dung_id, video_id, thoi_gian_xem)
values (@actorId, @videoId, now())
'''),
        parameters: {'actorId': actorId, 'videoId': id},
      );

      final ownerId = _asInt(updated.first[1]);
      if (ownerId != null) {
        await _bumpStats(tx, ownerId, views: 1);
      }

      return <String, Object?>{'viewCount': updated.first[0]};
    });
  }

  /// Cập nhật thời lượng đã xem cho lần xem gần nhất của người dùng.
  ///
  /// `registerView` tạo dòng lịch sử trước; hàm này chỉ cập nhật dòng mới nhất
  /// nên không làm tăng lượt xem lần thứ hai. Giá trị được lấy theo mức lớn
  /// nhất để tua lại hoặc thoát giữa chừng không làm giảm tín hiệu gợi ý.
  Future<bool> recordWatchProgress({
    required String videoId,
    required String userKey,
    required int watchedSeconds,
    required int durationSeconds,
  }) async {
    final id = _intId(videoId);
    if (id == null || userKey.trim().isEmpty) return false;
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return false;

    final int safeWatched = watchedSeconds.clamp(0, 24 * 60 * 60).toInt();
    final int safeDuration = durationSeconds.clamp(0, 24 * 60 * 60).toInt();
    if (safeWatched <= 0) return false;

    final result = await _pool.execute(
      Sql.named('''
update lich_su_xem
set thoi_luong_xem = greatest(
      coalesce(thoi_luong_xem, 0),
      least(@watchedSeconds::double precision, 86400.0)
    ),
    thoi_luong_video = case
      when @durationSeconds > 0
      then least(@durationSeconds::double precision, 86400.0)
      else coalesce(thoi_luong_video, 0)
    end
where lich_su_id = (
  select lich_su_id
  from lich_su_xem
  where nguoi_dung_id = @currentUserId
    and video_id = @videoId
  order by thoi_gian_xem desc nulls last, lich_su_id desc
  limit 1
)
'''),
      parameters: <String, Object?>{
        'currentUserId': currentUserId,
        'videoId': id,
        'watchedSeconds': safeWatched,
        'durationSeconds': safeDuration,
      },
    );
    return result.affectedRows > 0;
  }

  // ---------------------------------------------------------------------------
  // Kênh / đăng ký
  // ---------------------------------------------------------------------------

  /// Video mới nhất từ những kênh mà người dùng đang đăng ký.
  Future<List<Map<String, Object?>>> listSubscriptionFeed({
    required String userKey,
    int limit = 30,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return const <Map<String, Object?>>[];

    final result = await _pool.execute(
      Sql.named('''
select $_videoSelect
from video v
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
join dang_ky_kenh dk
  on dk.kenh_id = v.nguoi_dung_id
 and dk.nguoi_dung_id = @currentUserId
where v.trang_thai in ('da_duyet', 'approved')
order by v.ngay_tao desc nulls last, v.video_id desc
limit @limit
'''),
      parameters: {
        'currentUserId': currentUserId,
        'limit': limit.clamp(1, 100).toInt(),
      },
    );
    return result.map(_videoFromRow).toList();
  }

  /// Video mới từ những kênh người dùng đã tương tác (thích, bình luận hoặc
  /// xem) trong 90 ngày gần nhất. Đây là feed "Bạn bè" của màn hình xem nhanh,
  /// lấy từ hành vi thật thay vì danh sách bạn bè giả lập.
  Future<List<Map<String, Object?>>> listFriendsFeed({
    required String userKey,
    int limit = 30,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return const <Map<String, Object?>>[];

    final result = await _pool.execute(
      Sql.named('''
with interacted_creators as (
  select distinct v.nguoi_dung_id as creator_id
  from (
    select video_id
    from luot_thich
    where nguoi_dung_id = @currentUserId
    union
    select video_id
    from binh_luan
    where nguoi_dung_id = @currentUserId
    union
    select video_id
    from lich_su_xem
    where nguoi_dung_id = @currentUserId
      and thoi_gian_xem >= now() - interval '90 days'
  ) activity
  join video v on v.video_id = activity.video_id
  where v.nguoi_dung_id <> @currentUserId
)
select $_videoSelect
from video v
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
join interacted_creators f on f.creator_id = v.nguoi_dung_id
where v.trang_thai in ('da_duyet', 'approved')
order by v.ngay_tao desc nulls last, v.video_id desc
limit @limit
'''),
      parameters: {
        'currentUserId': currentUserId,
        'limit': limit.clamp(1, 100).toInt(),
      },
    );
    return result.map(_videoFromRow).toList();
  }

  /// Danh sách video người dùng đã lưu, mới nhất trước.
  Future<List<Map<String, Object?>>> listSavedVideos({
    required String userKey,
    int limit = 50,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return const <Map<String, Object?>>[];

    final result = await _pool.execute(
      Sql.named('''
select $_videoSelect
from app_saved_videos sv
join video v on v.video_id = sv.video_id
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
where sv.nguoi_dung_id = @currentUserId
  and v.trang_thai in ('da_duyet', 'approved')
order by sv.created_at desc, v.video_id desc
limit @limit
'''),
      parameters: {
        'currentUserId': currentUserId,
        'limit': limit.clamp(1, 100).toInt(),
      },
    );
    return result.map(_videoFromRow).toList();
  }

  Future<List<Map<String, Object?>>> listChannels({
    required String userKey,
    bool onlySubscribed = false,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    if (onlySubscribed && currentUserId == null) {
      return const <Map<String, Object?>>[];
    }

    final result = await _pool.execute(
      Sql.named('''
select u.nguoi_dung_id, u.ten_dang_nhap,
       (
         select count(*)::int from video v
         where v.nguoi_dung_id = u.nguoi_dung_id
           and v.trang_thai in ('da_duyet', 'approved')
       ) as video_count,
       (
         select count(*)::int from dang_ky_kenh dk
         where dk.kenh_id = u.nguoi_dung_id
       ) as subscriber_count,
       exists(
         select 1 from dang_ky_kenh dks
         where dks.kenh_id = u.nguoi_dung_id
           and dks.nguoi_dung_id = coalesce(@currentUserId::int, -1)
       ) as subscribed
from nguoi_dung u
where ${onlySubscribed ? '''exists(
               select 1 from dang_ky_kenh dk2
               where dk2.kenh_id = u.nguoi_dung_id
                 and dk2.nguoi_dung_id = @currentUserId
             )''' : '''exists(
               select 1 from video v2
               where v2.nguoi_dung_id = u.nguoi_dung_id
                 and v2.trang_thai in ('da_duyet', 'approved')
             )'''}
order by u.ten_dang_nhap
'''),
      parameters: {'currentUserId': currentUserId},
    );
    return result.map(_channelFromRow).toList();
  }

  Future<Map<String, Object?>?> setSubscription({
    required String channelId,
    required bool subscribed,
    required String userKey,
  }) async {
    final targetId = _intId(channelId);
    if (targetId == null) return null;

    return _pool.runTx((tx) async {
      final actorId = await _userIdForKey(userKey, session: tx);
      if (actorId == null) return null;

      final channel = await tx.execute(
        Sql.named('select 1 from nguoi_dung where nguoi_dung_id = @id'),
        parameters: {'id': targetId},
      );
      if (channel.isEmpty) return null;

      if (subscribed) {
        final inserted = await tx.execute(
          Sql.named('''
insert into dang_ky_kenh (nguoi_dung_id, kenh_id)
values (@actorId, @channelId)
on conflict (nguoi_dung_id, kenh_id) do nothing
'''),
          parameters: {'actorId': actorId, 'channelId': targetId},
        );
        if (inserted.affectedRows > 0 && targetId != actorId) {
          final actorName = await _displayNameFor(tx, actorId);
          await _insertNotification(
            tx,
            userId: targetId,
            content: '$actorName đã đăng ký kênh của bạn!',
            link: 'user.html?id=$actorId',
          );
        }
      } else {
        await tx.execute(
          Sql.named('''
delete from dang_ky_kenh
where nguoi_dung_id = @actorId and kenh_id = @channelId
'''),
          parameters: {'actorId': actorId, 'channelId': targetId},
        );
      }

      final count = await tx.execute(
        Sql.named(
          'select count(*)::int from dang_ky_kenh where kenh_id = @channelId',
        ),
        parameters: {'channelId': targetId},
      );

      return <String, Object?>{
        'subscribed': subscribed,
        'subscriberCount': count.first[0],
      };
    });
  }

  // ---------------------------------------------------------------------------
  // Thông báo
  // ---------------------------------------------------------------------------

  /// Danh sách thông báo mới nhất của người dùng, dùng chung bảng `thong_bao`
  /// với web để thông báo do web tạo cũng hiện trong app.
  Future<List<Map<String, Object?>>> listNotifications({
    required String userKey,
    int limit = 50,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return const <Map<String, Object?>>[];

    final result = await _pool.execute(
      Sql.named('''
select thong_bao_id, noi_dung, link, da_xem, ngay_tao
from thong_bao
where nguoi_dung_id = @userId
order by ngay_tao desc nulls last, thong_bao_id desc
limit @limit
'''),
      parameters: {'userId': currentUserId, 'limit': limit.clamp(1, 100)},
    );

    return result.map((row) {
      final createdAt = row[4] as DateTime?;
      return <String, Object?>{
        'id': row[0]?.toString() ?? '',
        'content': row[1]?.toString() ?? '',
        'link': row[2]?.toString() ?? '',
        'seen': row[3] as bool? ?? false,
        'createdAt': createdAt?.toUtc().toIso8601String() ?? '',
      };
    }).toList();
  }

  Future<int> markNotificationsRead(String userKey) async {
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return 0;
    final result = await _pool.execute(
      Sql.named('''
update thong_bao
set da_xem = true
where nguoi_dung_id = @userId and da_xem = false
'''),
      parameters: {'userId': currentUserId},
    );
    return result.affectedRows;
  }

  Future<bool> markNotificationRead({
    required String userKey,
    required String notificationId,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    final id = _intId(notificationId);
    if (currentUserId == null || id == null) return false;
    final result = await _pool.execute(
      Sql.named('''
update thong_bao
set da_xem = true
where thong_bao_id = @notificationId and nguoi_dung_id = @userId
'''),
      parameters: {'notificationId': id, 'userId': currentUserId},
    );
    if (result.affectedRows > 0) return true;

    // Thông báo đã đọc từ trước vẫn được coi là hợp lệ.
    final exists = await _pool.execute(
      Sql.named('''
select 1
from thong_bao
where thong_bao_id = @notificationId and nguoi_dung_id = @userId
'''),
      parameters: {'notificationId': id, 'userId': currentUserId},
    );
    return exists.isNotEmpty;
  }

  Future<void> _insertNotification(
    Session session, {
    required int userId,
    required String content,
    String? link,
  }) async {
    if (userId <= 0 || content.trim().isEmpty) return;
    await session.execute(
      Sql.named('''
insert into thong_bao (nguoi_dung_id, noi_dung, link, da_xem)
values (@userId, @content, @link, false)
'''),
      parameters: {
        'userId': userId,
        'content': content.trim(),
        'link': link,
      },
    );
  }

  Future<String> _displayNameFor(Session session, int userId) async {
    final result = await session.execute(
      Sql.named('''
select coalesce(nullif(ten_hien_thi, ''), ten_dang_nhap)
from nguoi_dung
where nguoi_dung_id = @userId
'''),
      parameters: {'userId': userId},
    );
    if (result.isEmpty) return 'Người dùng';
    final name = result.first[0]?.toString().trim() ?? '';
    return name.isEmpty ? 'Người dùng' : name;
  }

  // ---------------------------------------------------------------------------
  // Lịch sử xem / video đã đăng
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> listWatchHistory({
    required String userKey,
    int limit = 50,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return const <Map<String, Object?>>[];

    final result = await _pool.execute(
      Sql.named('''
select $_videoSelect, wh.watched_at
from video v
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
join (
  select video_id, max(thoi_gian_xem) as watched_at
  from lich_su_xem
  where nguoi_dung_id = @currentUserId
  group by video_id
) wh on wh.video_id = v.video_id
where v.trang_thai in ('da_duyet', 'approved')
order by wh.watched_at desc
limit @limit
'''),
      parameters: {'currentUserId': currentUserId, 'limit': limit},
    );
    return result.map((row) {
      final video = _videoFromRow(row);
      final watchedAt = row[19] as DateTime?;
      video['watchedAt'] = watchedAt?.toUtc().toIso8601String() ?? '';
      return video;
    }).toList();
  }

  Future<void> clearWatchHistory(String userKey) async {
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return;
    await _pool.execute(
      Sql.named('delete from lich_su_xem where nguoi_dung_id = @userId'),
      parameters: {'userId': currentUserId},
    );
  }

  Future<bool> removeWatchHistory({
    required String userKey,
    required String videoId,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    final id = _intId(videoId);
    if (currentUserId == null || id == null) return false;
    final result = await _pool.execute(
      Sql.named('''
delete from lich_su_xem
where nguoi_dung_id = @userId and video_id = @videoId
'''),
      parameters: {'userId': currentUserId, 'videoId': id},
    );
    return result.affectedRows > 0;
  }

  Future<List<Map<String, Object?>>> listUploads({
    required String userKey,
    int limit = 50,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return const <Map<String, Object?>>[];

    final result = await _pool.execute(
      Sql.named('''
select $_videoSelect
from video v
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
where v.nguoi_dung_id = @currentUserId
order by v.ngay_tao desc nulls last
limit @limit
'''),
      parameters: {'currentUserId': currentUserId, 'limit': limit},
    );
    return result.map(_videoFromRow).toList();
  }

  Future<Map<String, Object?>?> insertVideo({
    required String title,
    required String description,
    required String category,
    required List<String> tags,
    required String ageRating,
    required String userKey,
    String? videoUrl,
    String? thumbnailUrl,
    String? publicId,
    int durationSeconds = 0,
  }) async {
    if ((videoUrl ?? '').trim().isEmpty) return null;

    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) return null;

    final categoryResult = await _pool.execute(
      Sql.named('''
select danh_muc_id from danh_muc
where lower(ten_danh_muc) = lower(@category)
limit 1
'''),
      parameters: {'category': category},
    );
    final categoryId =
        categoryResult.isEmpty ? null : _asInt(categoryResult.first[0]);

    final storedDescription = _buildDescription(description, tags);
    final newId = await _pool.runTx<int?>((tx) async {
      final inserted = await tx.execute(
        Sql.named('''
insert into video (
  nguoi_dung_id, tieu_de, mo_ta, duong_dan_video, duong_dan_anh_bia,
  thoi_luong, danh_muc_id, trang_thai, danh_cho_tre_em
) values (
  @userId, @title, @description, @videoUrl, @thumbnailUrl,
  @duration, @categoryId, 'da_duyet', @kidsOnly
)
returning video_id
'''),
        parameters: {
          'userId': currentUserId,
          'title': title,
          'description': storedDescription,
          'videoUrl': videoUrl,
          'thumbnailUrl': thumbnailUrl,
          'duration': durationSeconds.toDouble(),
          'categoryId': categoryId,
          'kidsOnly': ageRating == 'kids',
        },
      );
      if (inserted.isEmpty) return null;
      final id = _asInt(inserted.first[0]);
      if (id == null) return null;

      await tx.execute(
        Sql.named('''
insert into lich_su_dang_video (
  video_id, nguoi_dung_id, tieu_de, mo_ta, video_url, luot_xem, thoi_gian_dang
) values (
  @videoId, @userId, @title, @description, @videoUrl, 0, now()
)
'''),
        parameters: {
          'videoId': id,
          'userId': currentUserId,
          'title': title,
          'description': storedDescription,
          'videoUrl': videoUrl,
        },
      );

      await tx.execute(
        Sql.named('''
insert into kiem_duyet_video (
  video_id, admin_username, trang_thai_moi, ly_do
)
select @videoId, 'admin', 'da_duyet',
       'Hệ thống tự động duyệt: Video từ ứng dụng TIKTUBE'
where exists (
  select 1 from tai_khoan_admin where username = 'admin'
)
'''),
        parameters: {'videoId': id},
      );

      final subscribers = await tx.execute(
        Sql.named('''
select nguoi_dung_id
from dang_ky_kenh
where kenh_id = @userId and nguoi_dung_id <> @userId
'''),
        parameters: {'userId': currentUserId},
      );
      if (subscribers.isNotEmpty) {
        final actorName = await _displayNameFor(tx, currentUserId);
        for (final row in subscribers) {
          final recipientId = _asInt(row[0]);
          if (recipientId == null) continue;
          await _insertNotification(
            tx,
            userId: recipientId,
            content: '🎬 $actorName vừa đăng video mới: "$title"',
            link: 'video.html?id=$id',
          );
        }
      }

      return id;
    });

    if (newId == null) return null;
    return findVideo(newId.toString(), userKey: userKey);
  }

  Future<bool> updateVideo({
    required String id,
    required String userKey,
    required String title,
    required String description,
    required String category,
    required List<String> tags,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    final videoId = _intId(id);
    if (currentUserId == null || videoId == null) return false;

    final categoryResult = await _pool.execute(
      Sql.named('''
select danh_muc_id from danh_muc
where lower(ten_danh_muc) = lower(@category)
limit 1
'''),
      parameters: {'category': category},
    );
    final categoryId =
        categoryResult.isEmpty ? null : _asInt(categoryResult.first[0]);

    final result = await _pool.execute(
      Sql.named('''
update video
set tieu_de = @title,
    mo_ta = @description,
    danh_muc_id = @categoryId,
    ngay_cap_nhat = now()
where video_id = @videoId and nguoi_dung_id = @userId
'''),
      parameters: {
        'videoId': videoId,
        'userId': currentUserId,
        'title': title,
        'description': _buildDescription(description, tags),
        'categoryId': categoryId,
      },
    );
    return result.affectedRows > 0;
  }

  /// Trả về public_id Cloudinary (nếu URL là Cloudinary) để API xoá media.
  Future<Map<String, Object?>?> deleteVideo({
    required String id,
    required String userKey,
  }) async {
    final currentUserId = await _userIdForKey(userKey);
    final videoId = _intId(id);
    if (currentUserId == null || videoId == null) return null;

    final result = await _pool.execute(
      Sql.named('''
delete from video
where video_id = @videoId and nguoi_dung_id = @userId
returning duong_dan_video
'''),
      parameters: {'videoId': videoId, 'userId': currentUserId},
    );
    if (result.isEmpty) return null;
    return <String, Object?>{
      'deleted': true,
      'publicId': _cloudinaryPublicId(result.first[0] as String?),
    };
  }

  // ---------------------------------------------------------------------------
  // Thống kê / tài khoản
  // ---------------------------------------------------------------------------

  Future<Map<String, Object?>> getStats(String userKey) async {
    final currentUserId = await _userIdForKey(userKey);
    if (currentUserId == null) {
      return <String, Object?>{
        'summary': <String, Object?>{
          'videos': 0,
          'views': 0,
          'likes': 0,
          'comments': 0,
        },
        'daily': <Object?>[],
        'videos': <Object?>[],
      };
    }

    final summaryResult = await _pool.execute(
      Sql.named('''
select count(*)::int,
       coalesce(sum(v.luot_xem), 0)::bigint,
       (
         select count(*)::int
         from luot_thich lt
         join video v2 on v2.video_id = lt.video_id
         where v2.nguoi_dung_id = @userId
       ),
       (
         select count(*)::int
         from binh_luan bl
         join video v3 on v3.video_id = bl.video_id
         where v3.nguoi_dung_id = @userId
       )
from video v
where v.nguoi_dung_id = @userId
'''),
      parameters: {'userId': currentUserId},
    );

    final dailyResult = await _pool.execute(
      Sql.named('''
select to_char(d.day::date, 'YYYY-MM-DD'),
       count(ls.lich_su_id)::int
from generate_series(current_date - 6, current_date, interval '1 day') d(day)
left join video v on v.nguoi_dung_id = @userId
left join lich_su_xem ls
  on ls.video_id = v.video_id
 and ls.thoi_gian_xem::date = d.day::date
group by d.day
order by d.day
'''),
      parameters: {'userId': currentUserId},
    );

    final videosResult = await _pool.execute(
      Sql.named('''
select $_videoSelect
from video v
join nguoi_dung u on u.nguoi_dung_id = v.nguoi_dung_id
left join danh_muc dm on dm.danh_muc_id = v.danh_muc_id
left join the_tag tt on tt.tag_id = v.tag_id
where v.nguoi_dung_id = @currentUserId
order by v.ngay_tao desc nulls last
limit 20
'''),
      parameters: {'currentUserId': currentUserId},
    );

    final row = summaryResult.first;
    return <String, Object?>{
      'summary': <String, Object?>{
        'videos': row[0],
        'views': row[1],
        'likes': row[2],
        'comments': row[3],
      },
      'daily': dailyResult
          .map((r) => <String, Object?>{
                'date': r[0],
                'views': r[1],
              })
          .toList(),
      'videos': videosResult.map(_videoFromRow).toList(),
    };
  }

  Future<Map<String, Object?>?> getProfile(String userKey) async {
    final result = await _pool.execute(
      Sql.named('''
select nguoi_dung_id, ten_dang_nhap,
       coalesce(nullif(ten_hien_thi, ''), ten_dang_nhap),
       email, do_tuoi, anh_dai_dien
from nguoi_dung
where lower(ten_dang_nhap) = lower(@userKey)
limit 1
'''),
      parameters: {'userKey': userKey},
    );
    if (result.isEmpty) return null;
    return _profileFromRow(result.first);
  }

  Future<Map<String, Object?>?> updateProfile({
    required String userKey,
    required String name,
    required String email,
    int? age,
    String? avatarUrl,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
update nguoi_dung
set ten_hien_thi = @name,
    email = lower(@email),
    do_tuoi = @age,
    anh_dai_dien = coalesce(@avatarUrl, anh_dai_dien),
    ngay_cap_nhat = now()
where lower(ten_dang_nhap) = lower(@userKey)
returning nguoi_dung_id, ten_dang_nhap,
          coalesce(nullif(ten_hien_thi, ''), ten_dang_nhap),
          email, do_tuoi, anh_dai_dien
'''),
      parameters: {
        'userKey': userKey,
        'name': name,
        'email': email,
        'age': (age ?? 18).toString(),
        'avatarUrl': avatarUrl,
      },
    );
    if (result.isEmpty) return null;
    return _profileFromRow(result.first);
  }

  // ---------------------------------------------------------------------------

  Future<int?> _userIdForKey(
    String userKey, {
    Session? session,
  }) async {
    final key = userKey.trim();
    if (key.isEmpty) return null;
    final executor = session ?? _pool;
    final result = await executor.execute(
      Sql.named('''
select nguoi_dung_id from nguoi_dung
where lower(ten_dang_nhap) = lower(@userKey)
limit 1
'''),
      parameters: {'userKey': key},
    );
    if (result.isEmpty) return null;
    return _asInt(result.first[0]);
  }

  /// Tăng/giảm thống kê ngày của chủ video để dashboard web thấy hoạt động app.
  Future<void> _bumpStats(
    Session session,
    int ownerId, {
    int views = 0,
    int likes = 0,
    int comments = 0,
    DateTime? day,
  }) async {
    if (ownerId <= 0 || (views == 0 && likes == 0 && comments == 0)) {
      return;
    }
    await session.execute(
      Sql.named('''
insert into thong_ke (
  nguoi_dung_id, ngay, so_luot_xem, so_luot_thich, so_binh_luan, ngay_cap_nhat
) values (
  @ownerId, coalesce(@day::date, current_date),
  greatest(0, @views), greatest(0, @likes), greatest(0, @comments), now()
)
on conflict (nguoi_dung_id, ngay) do update set
  so_luot_xem = greatest(0, coalesce(thong_ke.so_luot_xem, 0) + @views),
  so_luot_thich = greatest(0, coalesce(thong_ke.so_luot_thich, 0) + @likes),
  so_binh_luan = greatest(0, coalesce(thong_ke.so_binh_luan, 0) + @comments),
  ngay_cap_nhat = now()
'''),
      parameters: {
        'ownerId': ownerId,
        'day': day,
        'views': views,
        'likes': likes,
        'comments': comments,
      },
    );
  }

  static Map<String, Object?> _trendingVideoFromRow(ResultRow row) {
    final video = _videoFromRow(row);
    // Hai cột cuối chỉ xuất hiện trong truy vấn xếp hạng xu hướng.
    video['trendScore'] = _asInt(row[19]) ?? 0;
    video['recentViews'] = _asInt(row[20]) ?? 0;
    return video;
  }

  static Map<String, Object?> _forYouVideoFromRow(ResultRow row) {
    final video = _videoFromRow(row);
    video['recommendationScore'] = _asInt(row[19]) ?? 0;
    video['recommendationReason'] = row[20]?.toString() ?? 'trending';
    return video;
  }

  static String _todayForFeed() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Map<String, Object?> _videoFromRow(ResultRow row) {
    final channelId = _asInt(row[11]);
    final status = row[15]?.toString() ?? 'da_duyet';
    return <String, Object?>{
      'id': row[0]?.toString() ?? '',
      'title': row[1]?.toString() ?? '',
      'channel': row[2]?.toString() ?? 'Kênh',
      'handle': '@${row[2]?.toString() ?? 'kenh'}',
      'views': _asInt(row[3]) ?? 0,
      'date': _shortDate(row[4] as DateTime?),
      'durationSeconds': (row[5] as num?)?.round() ?? 0,
      'category': row[6]?.toString() ?? 'Khác',
      'colors': _colorsFor(channelId),
      'isLive': false,
      'description': row[7]?.toString() ?? '',
      'likeCount': _asInt(row[10]) ?? 0,
      'videoUrl': row[8]?.toString(),
      'thumbnailUrl': _thumbnailUrl(
        row[9]?.toString(),
        row[8]?.toString(),
      ),
      'tags': _parseTags(row[7]?.toString(), row[16]?.toString()),
      'channelId': channelId?.toString() ?? '',
      'subscriberCount': _asInt(row[12]) ?? 0,
      'subscribed': row[13] as bool? ?? false,
      'commentCount': _asInt(row[14]) ?? 0,
      'uploadedBy': row[2]?.toString() ?? '',
      'status': status,
      'liked': row[17] as bool? ?? false,
      'saved': row[18] as bool? ?? false,
    };
  }

  static Map<String, Object?> _channelFromRow(ResultRow row) {
    final id = _asInt(row[0]) ?? 0;
    final name = row[1]?.toString() ?? 'Kênh';
    return <String, Object?>{
      'id': id.toString(),
      'name': name,
      'handle': '@$name',
      'subscriberCount': _asInt(row[3]) ?? 0,
      'colors': _colorsFor(id),
      'videoCount': _asInt(row[2]) ?? 0,
      'subscribed': row[4] as bool? ?? false,
    };
  }

  static Map<String, Object?> _profileFromRow(ResultRow row) {
    final username = row[1]?.toString() ?? '';
    final displayName = row[2]?.toString().trim() ?? '';
    return <String, Object?>{
      'userKey': username,
      'name': displayName.isEmpty ? username : displayName,
      'email': row[3]?.toString() ?? '',
      'age': int.tryParse(row[4]?.toString() ?? ''),
      'avatarUrl': row[5]?.toString(),
    };
  }

  static Map<String, Object?> _commentFromRow(
    ResultRow row, {
    required int? currentUserId,
  }) {
    final ownerId = _asInt(row[4]);
    return <String, Object?>{
      'id': row[0]?.toString() ?? '',
      'author': row[1]?.toString() ?? 'Ẩn danh',
      'content': row[2]?.toString() ?? '',
      'date': _shortDate(row[3] as DateTime?),
      'own': currentUserId != null && ownerId == currentUserId,
    };
  }

  static String _shortDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  static String? _thumbnailUrl(String? thumbnail, String? videoUrl) {
    var value = thumbnail?.trim();
    if (value == null || value.isEmpty) return null;
    if (videoUrl != null && value == videoUrl.trim()) return null;
    final lower = value.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m3u8')) {
      return null;
    }

    // Ảnh bìa do Cloudinary tạo từ video thường lấy frame 0. Nhiều video bắt
    // đầu bằng khung trắng/đen nên đổi sang frame 2 giây để card không bị trống.
    value = value.replaceFirst(
      '/video/upload/so_0,',
      '/video/upload/so_2,',
    );
    return value;
  }

  static List<String> _parseTags(String? description, String? tag) {
    final tags = <String>[];
    final seen = <String>{};
    void add(String raw) {
      var value = raw.trim();
      while (value.startsWith('#')) {
        value = value.substring(1);
      }
      value = value.replaceAll(RegExp(r'[.,;:!?\)\]\}]+$'), '');
      if (value.isEmpty || value.length > 50) return;
      final key = value.toLowerCase();
      if (seen.add(key)) tags.add(value);
      if (tags.length >= 20) return;
    }

    final text = description ?? '';
    for (final match in RegExp(r'#([^\s#]+)', unicode: true).allMatches(text)) {
      add(match.group(1) ?? '');
      if (tags.length >= 20) break;
    }
    if (tag != null) add(tag);
    return tags;
  }

  static List<String> _colorsFor(int? id) {
    const palettes = <List<String>>[
      <String>['#1B3B4A', '#2F6E7C', '#08171E'],
      <String>['#6E5B52', '#B9A79B', '#2B2320'],
      <String>['#7A5CC4', '#4B3F8F', '#1B1633'],
      <String>['#2A2F45', '#42506E', '#0B0E1A'],
      <String>['#3E5C3A', '#6E8C5A', '#14200F'],
      <String>['#2A4B7C', '#4C8DFF', '#0A1526'],
      <String>['#1F6F63', '#57C6A5', '#08221D'],
      <String>['#8A5A2B', '#D9A45B', '#2E1B08'],
    ];
    return palettes[(id ?? 0).abs() % palettes.length];
  }

  static String _buildDescription(String description, List<String> tags) {
    final text = description.trim();
    final hashtags = tags.map((tag) => '#$tag').join(' ');
    if (text.isEmpty) return hashtags;
    if (hashtags.isEmpty) return text;
    return '$text\n\n$hashtags';
  }

  static int? _intId(String value) {
    final id = int.tryParse(value.trim());
    if (id == null || id <= 0) return null;
    return id;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _passwordHash(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static bool _safeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String? _cloudinaryPublicId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    const marker = '/upload/';
    final index = url.indexOf(marker);
    if (index < 0) return null;
    var path = url.substring(index + marker.length);
    final slash = path.indexOf('/');
    if (slash > 0) {
      final first = path.substring(0, slash);
      if (RegExp(r'^v\d+$').hasMatch(first)) {
        path = path.substring(slash + 1);
      }
    }
    final dot = path.lastIndexOf('.');
    if (dot > 0) path = path.substring(0, dot);
    return path.isEmpty ? null : path;
  }

  static const String _videoSelect = '''
v.video_id, v.tieu_de, u.ten_dang_nhap, v.luot_xem, v.ngay_tao,
v.thoi_luong, coalesce(dm.ten_danh_muc, 'Khác'),
coalesce(v.mo_ta, ''), v.duong_dan_video, v.duong_dan_anh_bia,
(select count(*)::int from luot_thich lt where lt.video_id = v.video_id),
u.nguoi_dung_id,
(select count(*)::int from dang_ky_kenh dk where dk.kenh_id = u.nguoi_dung_id),
exists(
  select 1 from dang_ky_kenh dks
  where dks.kenh_id = u.nguoi_dung_id
    and dks.nguoi_dung_id = coalesce(@currentUserId::int, -1)
),
(select count(*)::int from binh_luan bl where bl.video_id = v.video_id),
v.trang_thai,
tt.ten_tag,
exists(
  select 1 from luot_thich lts
  where lts.video_id = v.video_id
    and lts.nguoi_dung_id = coalesce(@currentUserId::int, -1)
) as liked,
exists(
  select 1 from app_saved_videos svs
  where svs.video_id = v.video_id
    and svs.nguoi_dung_id = coalesce(@currentUserId::int, -1)
) as saved
''';
}
