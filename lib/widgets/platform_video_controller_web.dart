import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

/// Trên web, `PlatformFile.uri` là URL blob của tệp vừa chọn.
VideoPlayerController createPlatformVideoController(PlatformFile file) {
  return VideoPlayerController.networkUrl(file.uri);
}
