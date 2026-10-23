import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'app_pill.dart';
import 'logo.dart';

/// Top bar dùng cho các trang con (Tải video, Lịch sử, Kênh đăng ký, ...).
///
/// Trên điện thoại thanh này rút gọn thành app bar native: nút quay lại,
/// tiêu đề trang, nút đổi giao diện và avatar tài khoản. Toàn bộ thanh nằm
/// trong [SafeArea] để không bị thanh trạng thái che mất.
class SectionTopBar extends StatelessWidget {
  const SectionTopBar({
    super.key,
    this.title,
    this.onBack,
    this.onHome,
    this.onAccount,
    this.onStats,
    this.onSearch,
  });

  /// Tiêu đề hiển thị trên app bar điện thoại.
  final String? title;
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final VoidCallback? onAccount;
  final VoidCallback? onStats;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = ThemeScope.of(context);

    return ColoredBox(
      color: p.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              if (width < 700) {
                return _MobileBar(
                  title: title,
                  onBack: onBack,
                  onAccount: onAccount,
                  onStats: onStats,
                  isDark: theme.isDark,
                  onToggleTheme: theme.toggle,
                );
              }

              final bool showAppButton = width >= 1060;
              final bool showHome = width >= 780;
              final bool showStats = width >= 660;

              return SizedBox(
                height: 62,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
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
                        tooltip: theme.isDark
                            ? 'Giao diện sáng'
                            : 'Giao diện tối',
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
                      if (onAccount != null) ...<Widget>[
                        const SizedBox(width: 6),
                        AppPill(
                          label: 'Tài khoản',
                          background: p.textPrimary,
                          foreground: p.surface,
                          fontWeight: FontWeight.w700,
                          onTap: onAccount!,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
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

class _MobileBar extends StatelessWidget {
  const _MobileBar({
    required this.title,
    required this.onBack,
    required this.onAccount,
    required this.onStats,
    required this.isDark,
    required this.onToggleTheme,
  });

  final String? title;
  final VoidCallback? onBack;
  final VoidCallback? onAccount;
  final VoidCallback? onStats;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: <Widget>[
            if (onBack != null)
              IconButton(
                onPressed: onBack,
                tooltip: 'Quay lại',
                icon: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: p.textPrimary,
                ),
              )
            else
              const SizedBox(width: 10),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                title ?? 'TIKTUBE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: p.textPrimary,
                ),
              ),
            ),
            if (onStats != null)
              IconButton(
                onPressed: onStats,
                tooltip: 'Thống kê',
                icon: Icon(
                  Icons.insights_rounded,
                  size: 20,
                  color: p.textSecondary,
                ),
              ),
            IconButton(
              onPressed: onToggleTheme,
              tooltip: isDark ? 'Giao diện sáng' : 'Giao diện tối',
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
                color: p.textSecondary,
              ),
            ),
            if (onAccount != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAccount,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.chip,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.border),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
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
