import 'package:postgres/postgres.dart';
import 'package:tiktube_server/config.dart';

void main() async {
  final config = ServerConfig.load();
  final pool = Pool.withEndpoints([
    Endpoint(
      host: Uri.parse(config.databaseUrl).host,
      port: Uri.parse(config.databaseUrl).port == 0 ? 5432 : Uri.parse(config.databaseUrl).port,
      database: Uri.parse(config.databaseUrl).pathSegments.first,
      username: Uri.parse(config.databaseUrl).userInfo.split(':').first,
      password: Uri.parse(config.databaseUrl).userInfo.split(':').last,
    ),
  ], settings: const PoolSettings(sslMode: SslMode.require));

  print('Đang cập nhật video_url trong Neon DB sang endpoint stream công khai...');
  final res1 = await pool.execute('''
    update video
    set duong_dan_video = replace(
      duong_dan_video,
      'https://drive.google.com/uc?export=download&id=',
      'https://tiktube-api.onrender.com/api/drive/stream?id='
    )
    where duong_dan_video like '%drive.google.com/uc?export=download&id=%'
  ''');
  print('Đã cập nhật ${res1.affectedRows} dòng trong bảng video.');

  final res2 = await pool.execute('''
    update lich_su_dang_video
    set video_url = replace(
      video_url,
      'https://drive.google.com/uc?export=download&id=',
      'https://tiktube-api.onrender.com/api/drive/stream?id='
    )
    where video_url like '%drive.google.com/uc?export=download&id=%'
  ''');
  print('Đã cập nhật ${res2.affectedRows} dòng trong bảng lich_su_dang_video.');

  await pool.close();
  print('Hoàn tất!');
}

