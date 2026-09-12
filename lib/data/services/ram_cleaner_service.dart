import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../models/clean_result.dart';

/// Drives the native RAM cleaning routine.
///
/// The native side force-stops background packages through Shizuku, trims the
/// kernel page cache and measures the delta between the two memory readings.
class RamCleanerService {
  const RamCleanerService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(AppConstants.deviceChannel);

  final MethodChannel _channel;

  /// Runs one cleaning cycle.
  ///
  /// When [excludePackages] is provided those packages are kept alive, which is
  /// how the dashboard avoids killing the app the user is currently using.
  Future<CleanResult> cleanRam({
    List<String> excludePackages = const <String>[],
    bool aggressive = true,
  }) async {
    try {
      final Object? payload = await _channel.invokeMethod<Object?>('cleanRam', {
        'excludePackages': excludePackages,
        'aggressive': aggressive,
      });
      if (payload is! Map<Object?, Object?>) return CleanResult.unavailable;
      return CleanResult.fromMap(payload);
    } on MissingPluginException {
      return CleanResult.unavailable;
    } on PlatformException {
      return CleanResult.unavailable;
    }
  }

  /// Releases the page cache only. Cheap and safe, used for the automatic
  /// background trim when the dashboard polls low free memory.
  Future<bool> trimCaches() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('trimCaches');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
