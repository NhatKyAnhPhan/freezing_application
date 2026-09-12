import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'constants.dart';

/// Builds the paired light / dark themes. The app follows the system theme
/// setting automatically (see `ThemeMode.system` in `main.dart`).
abstract final class AppTheme {
  static ThemeData get light => _build(AppPalette.light);

  static ThemeData get dark => _build(AppPalette.dark);

  static ThemeData _build(AppPalette palette) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: palette.gold,
      brightness: palette.isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      surface: palette.surface,
      primary: palette.gold,
      onPrimary: palette.onGold,
      secondary: palette.goldSoft,
      error: palette.danger,
      outline: palette.border,
    );

    final TextTheme base =
        palette.isDark ? Typography.whiteMountainView : Typography.blackMountainView;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      fontFamily: 'Roboto',
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: base
          .copyWith(
            displayLarge: base.displayLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
            ),
            headlineMedium: base.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
            titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            labelLarge: base.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          )
          .apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: palette.textPrimary,
        systemOverlayStyle:
            palette.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          side: BorderSide(color: palette.border),
        ),
      ),
      iconTheme: IconThemeData(color: palette.textSecondary, size: AppSizes.iconMedium),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.gold,
        linearTrackColor: palette.surfaceAlt,
        circularTrackColor: palette.surfaceAlt,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return palette.onGold;
          return palette.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return palette.gold;
          return palette.surfaceAlt;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.gold,
          foregroundColor: palette.onGold,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.tileRadius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.tileRadius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.gold,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceAlt,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.tileRadius),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        textStyle: TextStyle(color: palette.textPrimary, fontSize: 12),
      ),
    );
  }
}
