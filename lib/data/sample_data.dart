import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/comment.dart';
import '../models/video.dart';

const List<String> kCategories = <String>[
  'Tất cả',
  'Giải trí',
  'Âm nhạc & sáng tạo',
  'Gaming',
  'Giáo dục & kiến thức',
  'Làm đẹp & thời trang',
  'Ẩm thực',
  'Du lịch & trải nghiệm',
  'Lifestyle (đời sống)',
  'Thể thao & sức khỏe',
  'Review & kiểm tiền',
  'DIY & sáng tạo',
  'Tin tức & xã hội',
];

const List<Video> kTrendingVideos = <Video>[
  Video(
    id: 't1',
    title: 'Nhạc Mỹ Nhân',
    channel: 'PTK',
    handle: '@ptk',
    views: 28,
    date: '9/9/2026',
    duration: Duration(minutes: 4, seconds: 56),
    category: 'Âm nhạc & sáng tạo',
    colors: [Color(0xFF1B3B4A), Color(0xFF2F6E7C), Color(0xFF08171E)],
    isLive: true,
  ),
  Video(
    id: 't2',
    title: 'Ai Là Người Thương Em',
    channel: 'PTK',
    handle: '@ptk',
    views: 128400,
    date: '8/9/2026',
    duration: Duration(minutes: 5, seconds: 42),
    category: 'Âm nhạc & sáng tạo',
    colors: [Color(0xFF6E5B52), Color(0xFFB9A79B), Color(0xFF2B2320)],
  ),
  Video(
    id: 't3',
    title: 'Em Sẽ Là Cô Dâu',
    channel: 'PTK',
    handle: '@ptk',
    views: 2751000,
    date: '7/9/2026',
    duration: Duration(minutes: 4, seconds: 53),
    category: 'Âm nhạc & sáng tạo',
    colors: [Color(0xFF7A5CC4), Color(0xFF4B3F8F), Color(0xFF1B1633)],
  ),
  Video(
    id: 't4',
    title: 'Nhạc Cũ Ngỡ Là Anh',
    channel: 'kiepthan4',
    handle: '@kiepthan4',
    views: 9800,
    date: '9/9/2026',
    duration: Duration(minutes: 3, seconds: 2),
    category: 'Lifestyle (đời sống)',
    colors: [Color(0xFF2A2F45), Color(0xFF42506E), Color(0xFF0B0E1A)],
  ),
];

const List<Video> kLatestVideos = <Video>[
  Video(
    id: 'v1',
    title: 'Nhạc Ai Là Người Thương Em',
    channel: 'PTK',
    handle: '@ptk',
    views: 17400,
    date: '9/9/2026',
    duration: Duration(minutes: 5, seconds: 42),
    category: 'Âm nhạc & sáng tạo',
    colors: [Color(0xFF1B3B4A), Color(0xFF2F6E7C), Color(0xFF08171E)],
  ),
  Video(
    id: 'v2',
    title: 'Em sẽ là cô dâu',
    channel: 'PTK',
    handle: '@ptk',
    views: 52300,
    date: '9/9/2026',
    duration: Duration(minutes: 4, seconds: 53),
    category: 'Âm nhạc & sáng tạo',
    colors: [Color(0xFF7A5CC4), Color(0xFF4B3F8F), Color(0xFF1B1633)],
  ),
  Video(
    id: 'v3',
    title: 'Nhạc Mỹ Nhân',
    channel: 'PTK',
    handle: '@ptk',
    views: 28,
    date: '9/9/2026',
    duration: Duration(minutes: 4, seconds: 56),
    category: 'Âm nhạc & sáng tạo',
    colors: [Color(0xFF12312E), Color(0xFF1F5F57), Color(0xFF071A18)],
  ),
  Video(
    id: 'v4',
    title: 'Alista bỏ sữa và những người bạn',
    channel: 'Nhat',
    handle: '@nhat',
    views: 12400,
    date: '9/9/2026',
    duration: Duration(minutes: 1, seconds: 12),
    category: 'Giải trí',
    colors: [Color(0xFF3E5C3A), Color(0xFF6E8C5A), Color(0xFF14200F)],
  ),
  Video(
    id: 'v5',
    title: 'Nhạc Cũ ngỡ là anh',
    channel: 'kiepthan4',
    handle: '@kiepthan4',
    views: 9800,
    date: '9/9/2026',
    duration: Duration(minutes: 4, seconds: 54),
    category: 'Lifestyle (đời sống)',
    colors: [Color(0xFF2A2F45), Color(0xFF42506E), Color(0xFF0B0E1A)],
  ),
  Video(
    id: 'v6',
    title: 'Review 5 quán ăn đêm Sài Gòn dưới 50k',
    channel: 'Foodie PTK',
    handle: '@foodieptk',
    views: 341000,
    date: '8/9/2026',
    duration: Duration(minutes: 12, seconds: 8),
    category: 'Ẩm thực',
    colors: [Color(0xFFFFB74D), Color(0xFFE2703A), Color(0xFF5A2410)],
  ),
  Video(
    id: 'v7',
    title: 'Leo núi Tà Xùa săn mây 2 ngày 1 đêm',
    channel: 'Đi Đâu Đó',
    handle: '@didado',
    views: 89000,
    date: '6/9/2026',
    duration: Duration(minutes: 18, seconds: 31),
    category: 'Du lịch & trải nghiệm',
    colors: [Color(0xFF4E6E8E), Color(0xFF9EC5D9), Color(0xFF1B2A38)],
  ),
  Video(
    id: 'v8',
    title: 'Hướng dẫn Flutter: dựng UI trong 15 phút',
    channel: 'Code Vỉa Hè',
    handle: '@codeviahè',
    views: 56200,
    date: '5/9/2026',
    duration: Duration(minutes: 15, seconds: 4),
    category: 'Giáo dục & kiến thức',
    colors: [Color(0xFF2A4B7C), Color(0xFF4C8DFF), Color(0xFF0A1526)],
  ),
  Video(
    id: 'v9',
    title: 'Đấu rank leo top 1 server — highlight cực cháy',
    channel: 'Game Thủ PTK',
    handle: '@gamethuptk',
    views: 1203000,
    date: '4/9/2026',
    duration: Duration(minutes: 22, seconds: 17),
    category: 'Gaming',
    colors: [Color(0xFF3B1F5E), Color(0xFF8B2FC9), Color(0xFF120619)],
  ),
  Video(
    id: 'v10',
    title: 'Skincare buổi tối cho da dầu mụn',
    channel: 'Linh Beauty',
    handle: '@linhbeauty',
    views: 45000,
    date: '3/9/2026',
    duration: Duration(minutes: 8, seconds: 22),
    category: 'Làm đẹp & thời trang',
    colors: [Color(0xFFE7A8B8), Color(0xFFB5627C), Color(0xFF3A1622)],
  ),
  Video(
    id: 'v11',
    title: 'Bài tập 10 phút mỗi sáng cho người ngồi nhiều',
    channel: 'Fit 24h',
    handle: '@fit24h',
    views: 210500,
    date: '2/9/2026',
    duration: Duration(minutes: 10, seconds: 36),
    category: 'Thể thao & sức khỏe',
    colors: [Color(0xFF1F6F63), Color(0xFF57C6A5), Color(0xFF08221D)],
  ),
  Video(
    id: 'v12',
    title: 'Tự làm kệ gỗ treo tường chỉ với 150k',
    channel: 'DIY Nhà Xinh',
    handle: '@diynhaxinh',
    views: 77200,
    date: '1/9/2026',
    duration: Duration(minutes: 7, seconds: 49),
    category: 'DIY & sáng tạo',
    colors: [Color(0xFF8A5A2B), Color(0xFFD9A45B), Color(0xFF2E1B08)],
  ),
];

/// Toàn bộ video (dùng cho trang xem + gợi ý liên quan).
List<Video> get kAllVideos => <Video>[...kTrendingVideos, ...kLatestVideos];

/// Bình luận mẫu cho trang xem video.
const List<Comment> kSampleComments = <Comment>[
  Comment(author: 'kiepthan4', content: '222', date: '11/9/2026', own: true),
  Comment(author: 'kiepthan4', content: 'XCLOL', date: '11/9/2026', own: true),
  Comment(author: 'kiepthan4', content: 'XCLOL', date: '11/9/2026', own: true),
  Comment(author: 'kiepthan4', content: '1', date: '11/9/2026', own: true),
  Comment(author: 'kiepthan4', content: 'hehe', date: '9/9/2026', own: true),
  Comment(
    author: 'kiepthan4',
    content: 'không bk',
    date: '9/9/2026',
    own: true,
  ),
  Comment(author: 'Bắp Bơ', content: 'Bắp ngô', date: '9/9/2026'),
  Comment(
    author: 'Mèo Con',
    content: 'Nghe hoài không chán luôn 🎧',
    date: '8/9/2026',
  ),
  Comment(author: 'Nhat', content: 'Nhạc hay quá ad ơi', date: '8/9/2026'),
];

/// Các kênh người dùng đang đăng ký.
const List<Channel> kSubscribedChannels = <Channel>[
  Channel(
    name: 'PTK',
    handle: '@ptk',
    videoCount: 0,
    colors: <Color>[Color(0xFF7A5CC4), Color(0xFF4B3F8F)],
  ),
  Channel(
    name: 'Nhat',
    handle: '@nhat',
    videoCount: 12,
    colors: <Color>[Color(0xFF3E5C3A), Color(0xFF6E8C5A)],
  ),
  Channel(
    name: 'Foodie PTK',
    handle: '@foodieptk',
    videoCount: 28,
    colors: <Color>[Color(0xFFFFB74D), Color(0xFFE2703A)],
  ),
];

/// Hashtag gợi ý theo danh mục của video.
List<String> tagsFor(Video video) {
  switch (video.category) {
    case 'Âm nhạc & sáng tạo':
      return <String>['remix', 'nhacdj', 'hay', 'tiktok', 'nhacmoi'];
    case 'Gaming':
      return <String>['gaming', 'highlight', 'rank', 'tiktok', 'gameviet'];
    case 'Ẩm thực':
      return <String>['food', 'review', 'anngon', 'saigon', 'tiktok'];
    case 'Du lịch & trải nghiệm':
      return <String>['travel', 'sanmay', 'taxua', 'vietnam', 'tiktok'];
    case 'Giáo dục & kiến thức':
      return <String>['flutter', 'coding', 'hoclaptrinh', 'tutorial'];
    case 'Làm đẹp & thời trang':
      return <String>['skincare', 'beauty', 'lamdep', 'tiktok'];
    case 'Thể thao & sức khỏe':
      return <String>['fit', 'workout', 'suckhoe', 'homeworkout'];
    case 'DIY & sáng tạo':
      return <String>['diy', 'handmade', 'nhaxinh', 'tiktok'];
    case 'Lifestyle (đời sống)':
      return <String>['life', 'daily', 'vlog', 'tiktok'];
    default:
      return <String>['tiktube', 'video', 'trending'];
  }
}

/// Số người đăng ký hiển thị dưới tên kênh.
String subscriberLabelFor(String channel) {
  switch (channel) {
    case 'PTK':
      return '7 người đăng ký';
    case 'Nhat':
      return '12 N người đăng ký';
    case 'kiepthan4':
      return '4 người đăng ký';
    case 'Foodie PTK':
      return '32,4 N người đăng ký';
    default:
      return '1,2 N người đăng ký';
  }
}
