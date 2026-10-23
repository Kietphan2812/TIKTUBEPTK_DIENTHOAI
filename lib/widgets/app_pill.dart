import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Nút dạng viên thuốc dùng chung cho các trang.
class AppPill extends StatefulWidget {
  const AppPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.background,
    this.foreground,
    this.borderColor,
    this.gradient,
    this.height = 34,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w600,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.letterSpacing,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final List<Color>? gradient;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry padding;
  final double? letterSpacing;

  @override
  State<AppPill> createState() => _AppPillState();
}

class _AppPillState extends State<AppPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final background = widget.background ?? p.chip;
    final foreground = widget.foreground ?? p.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: widget.height,
          padding: widget.padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.gradient == null
                ? (_hovered
                      ? Color.alphaBlend(
                          foreground.withValues(alpha: 0.08),
                          background,
                        )
                      : background)
                : null,
            gradient: widget.gradient == null
                ? null
                : LinearGradient(colors: widget.gradient!),
            borderRadius: BorderRadius.circular(999),
            border: widget.borderColor == null
                ? null
                : Border.all(color: widget.borderColor!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: widget.fontSize + 3, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: widget.fontWeight,
                  color: foreground,
                  letterSpacing: widget.letterSpacing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
