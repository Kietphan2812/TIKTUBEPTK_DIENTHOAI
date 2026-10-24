import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:tiktube_server/config.dart';

/// Chuẩn bị database TIKTUBETPK (schema web có sẵn) cho app Flutter.
///
/// - Tạo bảng phiên đăng nhập riêng của app (`app_sessions`).
/// - Thêm cột `ten_hien_thi` (nullable) để app có tên hiển thị riêng, không
///   làm ảnh hưởng `ten_dang_nhap` mà web đang dùng để đăng nhập.
/// - Tạo tài khoản demo `kiepthan4` nếu chưa có.
///
/// Không xoá, không ghi đè dữ liệu video/người dùng hiện có.
Future<void> main() async {
  final config = ServerConfig.load();
  final connection = await Connection.openFromUrl(config.databaseUrl);
  try {
    await connection.execute('''
create table if not exists app_sessions (
  token_hash text primary key,
  nguoi_dung_id integer not null
    references nguoi_dung(nguoi_dung_id) on delete cascade,
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone not null default now()
)
''');
    await connection.execute('''
create index if not exists app_sessions_expires_idx
on app_sessions (expires_at)
''');
    await connection.execute('''
alter table nguoi_dung
add column if not exists ten_hien_thi varchar(60)
''');
    await connection.execute('''
alter table lich_su_xem
add column if not exists thoi_luong_xem double precision not null default 0
''');
    await connection.execute('''
alter table lich_su_xem
add column if not exists thoi_luong_video double precision not null default 0
''');
    await connection.execute('''
create index if not exists app_lich_su_xem_user_time_idx
on lich_su_xem (nguoi_dung_id, thoi_gian_xem desc)
''');
    await connection.execute('''
create index if not exists app_luot_thich_user_time_idx
on luot_thich (nguoi_dung_id, ngay_tao desc)
''');
    await connection.execute('''
create index if not exists app_binh_luan_user_time_idx
on binh_luan (nguoi_dung_id, ngay_tao desc)
''');
    await connection.execute('''
create table if not exists app_saved_videos (
  nguoi_dung_id integer not null
    references nguoi_dung(nguoi_dung_id) on delete cascade,
  video_id integer not null
    references video(video_id) on delete cascade,
  created_at timestamp with time zone not null default now(),
  primary key (nguoi_dung_id, video_id)
)
''');
    await connection.execute('''
create index if not exists app_saved_videos_user_time_idx
on app_saved_videos (nguoi_dung_id, created_at desc)
''');

    final demoHash = sha256.convert(utf8.encode('TikTube@123')).toString();
    final inserted = await connection.execute(
      Sql.named('''
insert into nguoi_dung (ten_dang_nhap, email, mat_khau_hash, do_tuoi)
values ('kiepthan4', 'kiepthan4@local.test', @passwordHash, '18')
on conflict (ten_dang_nhap) do nothing
returning nguoi_dung_id
'''),
      parameters: {'passwordHash': demoHash},
    );

    final users =
        await connection.execute('select count(*)::int from nguoi_dung');
    final videos = await connection.execute('select count(*)::int from video');
    final approved = await connection.execute(
      "select count(*)::int from video where trang_thai in ('da_duyet', 'approved')",
    );

    stdout.writeln('app_sessions: sẵn sàng');
    stdout.writeln('ten_hien_thi: sẵn sàng');
    stdout.writeln(
      inserted.isEmpty
          ? 'Tài khoản demo kiepthan4 đã tồn tại — giữ nguyên mật khẩu hiện tại.'
          : 'Đã tạo tài khoản demo kiepthan4 / TikTube@123.',
    );
    stdout.writeln(
      'Dữ liệu: ${users.first[0]} người dùng, ${videos.first[0]} video '
      '(${approved.first[0]} đã duyệt).',
    );
  } finally {
    await connection.close();
  }
}
