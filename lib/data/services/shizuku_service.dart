import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../models/app_model.dart';

class ShizukuService {
  const ShizukuService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(AppConstants.channelName);

  final MethodChannel _channel;

  Future<String> getStatus() async {
    return await _channel.invokeMethod<String>('getShizukuStatus') ?? 'unavailable';
  }

  Future<String> requestPermission() async {
    return await _channel.invokeMethod<String>('requestShizukuPermission') ?? 'unavailable';
  }

  Future<List<AppModel>> getInstalledApps() async {
    final apps = await _channel.invokeMethod<List<Object?>>('getInstalledApps');
    return (apps ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(AppModel.fromMap)
        .toList();
  }

  Future<bool> setFrozen(String packageName, {required bool frozen}) async {
    final result = await _channel.invokeMethod<bool>('setFrozen', {
      'packageName': packageName,
      'frozen': frozen,
    });
    return result ?? false;
  }
}