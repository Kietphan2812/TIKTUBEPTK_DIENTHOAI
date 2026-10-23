import 'dart:io';

/// Script cũ tạo schema riêng của app (`users`, `videos`, `sessions`, ...).
///
/// TIKTUBE hiện dùng chung database `TIKTUBETPK` với web app, theo schema
/// tiếng Việt (`nguoi_dung`, `video`, `binh_luan`, ...). Chạy script cũ sẽ tạo
/// schema song song và làm app không thấy video của web, nên script này dừng
/// lại để tránh ghi nhầm.
///
/// Chuẩn bị database đích bằng:
///   dart run bin/setup_target_db.dart
Future<void> main() async {
  stderr.writeln('Không chạy bin/init_db.dart trên database TIKTUBETPK.');
  stderr.writeln(
    'Database đích đã có schema web (nguoi_dung, video, binh_luan, ...).',
  );
  stderr.writeln('Script này không tạo schema cũ để tránh tách dữ liệu.');
  stderr.writeln('');
  stderr.writeln('Chạy lệnh sau để thêm bảng phiên/cột hiển thị của app:');
  stderr.writeln('  dart run bin/setup_target_db.dart');
  exit(1);
}
