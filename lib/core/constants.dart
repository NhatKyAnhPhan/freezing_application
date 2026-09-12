import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const String appName = 'FrostGuard';
  static const String appTagline = 'Smart App Freezer';

  /// Version badge shown on the dashboard header.
  static const String appVersion = 'v2.4';
  static const String buildChannel = 'Pro';

  /// Platform channel names.
  static const String shizukuChannel = 'freezing_app/shizuku';
  static const String deviceChannel = 'freezing_app/device';

  /// How often the dashboard polls CPU / RAM / battery telemetry.
  static const Duration statsPollInterval = Duration(seconds: 2);

  /// Number of samples kept for the mini history charts.
  static const int historyLength = 30;

  /// Rough RAM footprint assumed for a single frozen application.
  static const double estimatedRamPerFrozenAppMb = 380;

  /// Estimated power draw assumed for one frozen application, in mA.
  static const double estimatedMilliAmpPerFrozenApp = 32;

  /// How long the RAM cleaning animation runs before showing the summary.
  static const Duration cleanAnimationDuration = Duration(milliseconds: 4200);

  /// Aggressive cleaning waits a little longer for the kernel to reclaim pages.
  static const Duration cleanSettleDelay = Duration(milliseconds: 550);

  static const double screenPadding = 16;
  static const double cardRadius = 20;
  static const double tileRadius = 16;
}

/// Thresholds used to switch a metric between "healthy", "warning" and
/// "critical" styling.
abstract final class AppThresholds {
  static const double ramWarningPercent = 70;
  static const double ramCriticalPercent = 88;

  static const double cpuWarningPercent = 65;
  static const double cpuCriticalPercent = 85;

  static const double storageWarningPercent = 80;
  static const double storageCriticalPercent = 92;

  static const int batteryLowPercent = 20;
  static const int batteryCriticalPercent = 10;

  static const double batteryWarmCelsius = 40;
  static const double batteryHotCelsius = 45;

  static const double cpuWarmCelsius = 55;
  static const double cpuHotCelsius = 70;
}

/// Icon sizes / spacing steps reused across widgets.
abstract final class AppSizes {
  static const double iconSmall = 16;
  static const double iconMedium = 20;
  static const double iconLarge = 24;
  static const double gaugeSize = 96;

  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const double cardGap = 12;
}
