import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'app_pill.dart';
import 'logo.dart';

/// Top bar dùng cho các trang con (Tải video, Lịch sử, Kênh đăng ký, ...).
class SectionTopBar extends StatelessWidget {
  const SectionTopBar({
    super.key,
    this.onBack,
    this.onHome,
    this.onAccount,
    this.onStats,
    this.onSearch,
  });

  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final VoidCallback? onAccount;
  final VoidCallback? onStats;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = ThemeScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final bool showAppButton = width >= 1060;
          final bool showHome = width >= 780;
          final bool showStats = width >= 660;

          return SizedBox(
            height: 62,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: width < 700 ? 12 : 18),
              child: Row(
                children: <Widget>[
                  TikTubeLogo(showText: width >= 430, scale: 0.95),
                  const Spacer(),
                  if (onSearch != null)
                    _BarIcon(
                      icon: Icons.search_rounded,
                      tooltip: 'Tìm kiếm',
                      onTap: onSearch!,
                    ),
                  _BarIcon(
                    icon: theme.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    tooltip: theme.isDark ? 'Giao diện sáng' : 'Giao diện tối',
                    onTap: theme.toggle,
                  ),
                  if (showAppButton) ...<Widget>[
                    const SizedBox(width: 4),
                    AppPill(
                      label: 'Tải App',
                      icon: Icons.file_download_outlined,
                      gradient: p.ctaGradient,
                      foreground: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      onTap: () => _notify(context, 'Tải App'),
                    ),
                  ],
                  if (onBack != null) ...<Widget>[
                    const SizedBox(width: 6),
                    AppPill(
                      label: 'Quay lại',
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack!,
                    ),
                  ],
                  if (onStats != null && showStats) ...<Widget>[
                    const SizedBox(width: 6),
                    AppPill(
                      label: 'Thống Kê',
                      gradient: const <Color>[
                        Color(0xFFFFB020),
                        Color(0xFFF0820C),
                      ],
                      foreground: Colors.white,
                      fontWeight: FontWeight.w600,
                      onTap: onStats!,
                    ),
                  ],
                  if (onHome != null && showHome) ...<Widget>[
                    const SizedBox(width: 6),
                    AppPill(label: 'Trang chủ', onTap: onHome!),
                  ],
                  const SizedBox(width: 6),
                  AppPill(
                    label: 'Tài khoản',
                    background: p.textPrimary,
                    foreground: p.surface,
                    fontWeight: FontWeight.w700,
                    onTap: onAccount ?? () {},
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _notify(BuildContext context, String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$action — tính năng đang được xây dựng.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 19, color: p.textSecondary),
    );
  }
}
