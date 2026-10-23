import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'logo.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.searchController,
    required this.onQueryChanged,
    required this.onAction,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = ThemeScope.of(context);
    final isDark = theme.isDark;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final width = constraints.maxWidth;
          final bool isMobile = width < 700;
          final showSearch = width >= 700;
          final showCta = width >= 800;
          final showSecondaryNav = width >= 1080;
          final showPrimaryNav = width >= 960;
          final showLogoText = width >= 340;

          return SizedBox(
            height: isMobile ? 56 : 62,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18),
              child: Row(
                children: <Widget>[
                  TikTubeLogo(showText: showLogoText),
                  SizedBox(width: isMobile ? 10 : 20),
                  if (showSearch)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _SearchField(
                            controller: searchController,
                            onChanged: onQueryChanged,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  SizedBox(width: isMobile ? 4 : 12),
                  _IconButton(
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    tooltip: isDark ? 'Giao diện sáng' : 'Giao diện tối',
                    onTap: theme.toggle,
                  ),
                  if (showCta) ...<Widget>[
                    const SizedBox(width: 6),
                    _AppDownloadButton(onTap: () => onAction('Tải App')),
                  ],
                  _IconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Thông báo',
                    onTap: () => onAction('Thông báo'),
                  ),
                  if (showPrimaryNav)
                    _NavItem(
                      label: 'Trang chủ',
                      onTap: () => onAction('Trang chủ'),
                    ),
                  if (showSecondaryNav) ...<Widget>[
                    _NavItem(
                      label: 'Đăng Video',
                      onTap: () => onAction('Đăng Video'),
                    ),
                    _NavItem(
                      label: 'Lịch sử',
                      onTap: () => onAction('Lịch sử'),
                    ),
                    _NavItem(
                      label: 'Đăng ký',
                      onTap: () => onAction('Đăng ký'),
                    ),
                  ],
                  SizedBox(width: isMobile ? 2 : 6),
                  if (isMobile)
                    _MobileAccountButton(onTap: () => onAction('Tài khoản'))
                  else
                    _AccountPill(onTap: () => onAction('Tài khoản')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: p.brandRed,
              style: TextStyle(fontSize: 13, color: p.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tìm bằng tiêu đề, #tag...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: p.textSecondary.withValues(alpha: 0.9),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _HoverSurface(
          onTap: () => onChanged(controller.text),
          borderRadius: BorderRadius.circular(8),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 36,
          child: Text(
            'Tìm',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
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

    return Tooltip(
      message: tooltip,
      child: _HoverSurface(
        onTap: onTap,
        height: 34,
        width: 34,
        borderRadius: BorderRadius.circular(8),
        child: Icon(icon, size: 19, color: p.textSecondary),
      ),
    );
  }
}

class _AppDownloadButton extends StatelessWidget {
  const _AppDownloadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return _HoverSurface(
      onTap: onTap,
      height: 32,
      borderRadius: BorderRadius.circular(999),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: p.ctaGradient),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.file_download_outlined, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Tải App',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return _HoverSurface(
      onTap: onTap,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      borderRadius: BorderRadius.circular(8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: p.textPrimary.withValues(alpha: 0.86),
        ),
      ),
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return _HoverSurface(
      onTap: onTap,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      borderRadius: BorderRadius.circular(999),
      decoration: BoxDecoration(
        color: p.textPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Tài khoản',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.surface,
        ),
      ),
    );
  }
}

class _MobileAccountButton extends StatelessWidget {
  const _MobileAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return _HoverSurface(
      onTap: onTap,
      height: 34,
      width: 34,
      borderRadius: BorderRadius.circular(999),
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
    );
  }
}

/// Nền tảng hover chung cho các nút trên top bar.
class _HoverSurface extends StatefulWidget {
  const _HoverSurface({
    required this.child,
    required this.onTap,
    this.height,
    this.width,
    this.padding,
    this.borderRadius,
    this.decoration,
  });

  final Widget child;
  final VoidCallback onTap;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final BoxDecoration? decoration;

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = widget.borderRadius ?? BorderRadius.circular(8);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: widget.height,
          width: widget.width,
          padding: widget.padding,
          alignment: Alignment.center,
          decoration:
              widget.decoration ??
              BoxDecoration(
                color: _hovered ? p.chip : Colors.transparent,
                borderRadius: radius,
              ),
          child: widget.child,
        ),
      ),
    );
  }
}
