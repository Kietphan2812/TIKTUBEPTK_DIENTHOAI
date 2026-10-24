import 'package:flutter/material.dart';

import '../data/tiktube_api.dart';
import '../models/video.dart';
import '../theme/app_theme.dart';
import 'quick_upload_screen.dart';
import 'upload_screen.dart';

enum UploadChoice { quick, tiktube }

/// Mở luồng đăng video và trả về `true` nếu có video mới được tạo.
Future<bool> openUploadFlow(
  BuildContext context, {
  required TikTubeApi api,
}) async {
  final UploadChoice? choice = await showUploadChoiceSheet(context);
  if (choice == null || !context.mounted) return false;

  if (choice == UploadChoice.quick) {
    final Video? video = await Navigator.of(context).push<Video>(
      MaterialPageRoute<Video>(
        builder: (_) => QuickUploadScreen(api: api),
      ),
    );
    return video != null;
  }

  final bool? uploaded = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => UploadScreen(api: api),
    ),
  );
  return uploaded == true;
}

Future<UploadChoice?> showUploadChoiceSheet(BuildContext context) {
  return showModalBottomSheet<UploadChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (BuildContext sheetContext) => _UploadChoiceSheet(
      onChoose: (UploadChoice choice) {
        Navigator.of(sheetContext).pop(choice);
      },
    ),
  );
}

class _UploadChoiceSheet extends StatelessWidget {
  const _UploadChoiceSheet({required this.onChoose});

  final ValueChanged<UploadChoice> onChoose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: p.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Đăng video',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chọn cách đăng phù hợp với bạn.',
                style: TextStyle(color: p.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              _ChoiceTile(
                icon: Icons.bolt_rounded,
                title: 'Đăng video nhanh',
                subtitle:
                    'Chọn video, tiêu đề tự điền từ tên tệp và đăng ngay với hashtag gợi ý.',
                accent: p.brandRed,
                onTap: () => onChoose(UploadChoice.quick),
              ),
              const SizedBox(height: 10),
              _ChoiceTile(
                icon: Icons.cloud_upload_rounded,
                title: 'Đăng video TIKTUBE',
                subtitle:
                    'Mở biểu mẫu đầy đủ: tiêu đề, mô tả, danh mục, hashtag, đối tượng và xem trước.',
                accent: const Color(0xFF2563EB),
                onTap: () => onChoose(UploadChoice.tiktube),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(
                  'Hủy',
                  style: TextStyle(
                    color: p.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: p.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: p.textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
