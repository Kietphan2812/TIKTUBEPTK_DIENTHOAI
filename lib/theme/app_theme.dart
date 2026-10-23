import 'package:flutter/material.dart';

/// Bảng màu dùng chung cho toàn app (hỗ trợ light / dark).
@immutable
class PtPalette extends ThemeExtension<PtPalette> {
  const PtPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.chip,
    required this.brandRed,
    required this.brandPink,
    required this.ctaGradient,
    required this.shadow,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color chip;
  final Color brandRed;
  final Color brandPink;
  final List<Color> ctaGradient;
  final Color shadow;

  static const light = PtPalette(
    bg: Color(0xFFF7F7F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBFBFC),
    border: Color(0xFFE7E7EA),
    textPrimary: Color(0xFF111114),
    textSecondary: Color(0xFF62636A),
    chip: Color(0xFFF1F1F3),
    brandRed: Color(0xFFE8112D),
    brandPink: Color(0xFFD6246E),
    ctaGradient: [Color(0xFFF35C8D), Color(0xFFC2185B)],
    shadow: Color(0x14000000),
  );

  static const dark = PtPalette(
    bg: Color(0xFF0E0F11),
    surface: Color(0xFF17181C),
    surfaceAlt: Color(0xFF1D1F24),
    border: Color(0xFF2A2C33),
    textPrimary: Color(0xFFF4F5F7),
    textSecondary: Color(0xFF9EA1AB),
    chip: Color(0xFF23252B),
    brandRed: Color(0xFFFF3B4E),
    brandPink: Color(0xFFE24C86),
    ctaGradient: [Color(0xFFF35C8D), Color(0xFFB8154F)],
    shadow: Color(0x66000000),
  );

  @override
  PtPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? chip,
    Color? brandRed,
    Color? brandPink,
    List<Color>? ctaGradient,
    Color? shadow,
  }) {
    return PtPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      chip: chip ?? this.chip,
      brandRed: brandRed ?? this.brandRed,
      brandPink: brandPink ?? this.brandPink,
      ctaGradient: ctaGradient ?? this.ctaGradient,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  PtPalette lerp(ThemeExtension<PtPalette>? other, double t) {
    if (other is! PtPalette) return this;
    return PtPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      chip: Color.lerp(chip, other.chip, t)!,
      brandRed: Color.lerp(brandRed, other.brandRed, t)!,
      brandPink: Color.lerp(brandPink, other.brandPink, t)!,
      ctaGradient: <Color>[
        Color.lerp(ctaGradient[0], other.ctaGradient[0], t)!,
        Color.lerp(ctaGradient[1], other.ctaGradient[1], t)!,
      ],
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension PtPaletteContext on BuildContext {
  PtPalette get palette =>
      Theme.of(this).extension<PtPalette>() ?? PtPalette.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(PtPalette.light, Brightness.light);
  static ThemeData dark() => _build(PtPalette.dark, Brightness.dark);

  static ThemeData _build(PtPalette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.brandRed,
      brightness: brightness,
    ).copyWith(
      primary: p.brandRed,
      surface: p.surface,
      onSurface: p.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      extensions: <ThemeExtension<dynamic>>[p],
      iconTheme: IconThemeData(color: p.textSecondary, size: 20),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.brandRed,
        selectionColor: p.brandRed.withValues(alpha: 0.22),
        selectionHandleColor: p.brandRed,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.textPrimary,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: p.surface, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double>(7),
        radius: const Radius.circular(999),
        thumbColor: WidgetStatePropertyAll<Color>(
          p.textSecondary.withValues(alpha: 0.35),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.textPrimary,
        contentTextStyle: TextStyle(color: p.surface, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
