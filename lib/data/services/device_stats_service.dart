import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/json_utils.dart';
import '../models/device_stats.dart';

/// Reads CPU / RAM / battery / storage telemetry from the native layer.
///
/// Returns [DeviceStats.empty] whenever the platform channel is unavailable so
/// the dashboard can keep rendering on desktop, web and in widget tests.
class DeviceStatsService {
  const DeviceStatsService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(AppConstants.deviceChannel);

  final MethodChannel _channel;

  Future<DeviceStats> fetchStats() async {
    try {
      final Object? payload = await _channel.invokeMethod<Object?>('getDeviceStats');
      if (payload is! Map<Object?, Object?>) return DeviceStats.empty;
      return DeviceStats.fromMap(payload);
    } on MissingPluginException {
      return DeviceStats.empty;
    } on PlatformException {
      return DeviceStats.empty;
    }
  }

  /// Aggressive memory trim performed by `am trim-memory`. Returns `true` when
  /// the native call reported success.
  Future<bool> trimMemory({required int level}) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('trimMemory', {
        'level': level,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Number of user-facing packages that currently hold a process.
  Future<int> runningAppCount() async {
    try {
      final Object? payload = await _channel.invokeMethod<Object?>('getRunningAppCount');
      return JsonUtils.toInt(payload);
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }
}
