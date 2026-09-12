import 'package:flutter/material.dart';

/// Luxury palette shared across the app: deep obsidian surfaces paired with
/// champagne gold accents. Every colour used by the UI is declared here so the
/// light and dark variants stay perfectly symmetrical.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.gold,
    required this.goldSoft,
    required this.onGold,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color gold;
  final Color goldSoft;
  final Color onGold;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shadow;
  final bool isDark;

  /// Champange sheen used for premium accents, gauges and primary actions.
  LinearGradient get goldGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[goldSoft, gold],
      );

  /// Subtle vertical fade applied to elevated cards.
  LinearGradient get surfaceGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.alphaBlend(
            gold.withValues(alpha: isDark ? 0.05 : 0.03),
            surface,
          ),
          surface,
        ],
      );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF08080A),
    surface: Color(0xFF121215),
    surfaceAlt: Color(0xFF1A1A20),
    border: Color(0xFF26262E),
    gold: Color(0xFFD8B26A),
    goldSoft: Color(0xFFF1DFB2),
    onGold: Color(0xFF14100A),
    textPrimary: Color(0xFFF4F1EA),
    textSecondary: Color(0xFFB9B4A8),
    textMuted: Color(0xFF7C776C),
    success: Color(0xFF58C99A),
    warning: Color(0xFFE8B45C),
    danger: Color(0xFFE8735F),
    shadow: Color(0xFF000000),
    isDark: true,
  );

  static const AppPalette light = AppPalette(
    background: Color(0xFFF7F4EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1ECE2),
    border: Color(0xFFE2DACA),
    gold: Color(0xFF8A6A1F),
    goldSoft: Color(0xFFC9A552),
    onGold: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF191713),
    textSecondary: Color(0xFF55504A),
    textMuted: Color(0xFF8B857A),
    success: Color(0xFF1F8A5F),
    warning: Color(0xFFB07B1E),
    danger: Color(0xFFC2453A),
    shadow: Color(0xFF3A3327),
    isDark: false,
  );

  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ?? AppPalette.dark;
  }

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? gold,
    Color? goldSoft,
    Color? onGold,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? shadow,
    bool? isDark,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      onGold: onGold ?? this.onGold,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      onGold: Color.lerp(onGold, other.onGold, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
  TextTheme get texts => Theme.of(this).textTheme;
}
