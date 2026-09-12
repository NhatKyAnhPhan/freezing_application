import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/json_utils.dart';
import '../models/app_model.dart';

/// Talks to the Shizuku bridge implemented in `MainActivity.kt`.
///
/// Every call is defensive: when the native plugin is missing (desktop, web,
/// unit tests) the service reports `unavailable` instead of throwing.
class ShizukuService {
  const ShizukuService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(AppConstants.shizukuChannel);

  final MethodChannel _channel;

  static const String statusGranted = 'granted';
  static const String statusDenied = 'denied';
  static const String statusUnavailable = 'unavailable';

  Future<String> getStatus() async {
    try {
      return await _channel.invokeMethod<String>('getShizukuStatus') ??
          statusUnavailable;
    } on MissingPluginException {
      return statusUnavailable;
    } on PlatformException {
      return statusUnavailable;
    }
  }

  Future<String> requestPermission() async {
    try {
      return await _channel.invokeMethod<String>('requestShizukuPermission') ??
          statusUnavailable;
    } on MissingPluginException {
      return statusUnavailable;
    } on PlatformException {
      return statusUnavailable;
    }
  }

  Future<List<AppModel>> getInstalledApps() async {
    try {
      final Object? payload = await _channel.invokeMethod<Object?>('getInstalledApps');
      return JsonUtils.toMapList(payload).map(AppModel.fromMap).toList();
    } on MissingPluginException {
      return const <AppModel>[];
    } on PlatformException {
      return const <AppModel>[];
    }
  }

  Future<List<AppModel>> getInstalledAppsPage({
    required int offset,
    int limit = 24,
    bool refresh = false,
  }) async {
    try {
      final Object? payload = await _channel.invokeMethod<Object?>('getInstalledAppsPage', {
        'offset': offset,
        'limit': limit,
        'refresh': refresh,
      });
      return JsonUtils.toMapList(payload).map(AppModel.fromMap).toList(growable: false);
    } on MissingPluginException {
      return const <AppModel>[];
    } on PlatformException {
      return const <AppModel>[];
    }
  }

  Future<bool> setFrozen(String packageName, {required bool frozen}) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('setFrozen', {
        'packageName': packageName,
        'frozen': frozen,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Applies the same freeze state to many packages in a single shell round
  /// trip. Returns the packages that were updated successfully.
  Future<List<String>> setFrozenBatch(
    List<String> packageNames, {
    required bool frozen,
  }) async {
    if (packageNames.isEmpty) return const <String>[];
    try {
      final Object? payload = await _channel.invokeMethod<Object?>('setFrozenBatch', {
        'packageNames': packageNames,
        'frozen': frozen,
      });
      return JsonUtils.toStringList(payload);
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException {
      return const <String>[];
    }
  }

  /// Force-stops the given packages. Used by "Đóng băng tất cả" so a newly
  /// frozen app releases its memory immediately instead of at next boot.
  Future<int> killBackgroundApps(List<String> packageNames) async {
    if (packageNames.isEmpty) return 0;
    try {
      final Object? payload = await _channel.invokeMethod<Object?>('killBackgroundApps', {
        'packageNames': packageNames,
      });
      return JsonUtils.toInt(payload);
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }

  /// Package names that currently hold a running process.
  Future<List<String>> getRunningPackages() async {
    try {
      final Object? payload = await _channel.invokeMethod<Object?>('getRunningPackages');
      return JsonUtils.toStringList(payload);
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException {
      return const <String>[];
    }
  }
}
