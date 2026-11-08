import 'package:tiktube_server/config.dart';
import 'package:tiktube_server/db.dart';

void main() async {
  final config = ServerConfig.load();
  final db = await Db.open(config.databaseUrl);
  final videos = await db.listVideos(limit: 100);
  print('Tổng số video hiện có trong Neon DB: ${videos.length}');
  for (final v in videos) {
    print('- [${v['id']}] ${v['title']} (URL: ${v['videoUrl']})');
  }
}

