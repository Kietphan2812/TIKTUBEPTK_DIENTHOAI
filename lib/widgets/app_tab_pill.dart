import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Viên tab nhỏ dạng chữ in hoa (Lịch sử, Kênh đã đăng ký, ...).
class AppTabPill extends StatelessWidget {
  const AppTabPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = context.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.textPrimary : p.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : p.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: selected
                  ? (dark ? const Color(0xFF111114) : p.surface)
                  : p.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
