import '../../core/json_utils.dart';
import 'dart:typed_data';

/// A launchable application installed on the device.
class AppModel {
  const AppModel({
    required this.name,
    required this.packageName,
    this.isFrozen = false,
    this.isRunning = false,
    this.memoryBytes = 0,
    this.isSystem = false,
    this.versionName = '',
    this.iconBytes,
  });

  final String name;
  final String packageName;

  /// Frozen apps are disabled for the current user (`pm disable-user`).
  final bool isFrozen;

  /// Whether a process with this package is resident in memory right now.
  final bool isRunning;

  /// Resident memory reported for the running process, ignored when stopped.
  final double memoryBytes;

  final bool isSystem;
  final String versionName;
  final Uint8List? iconBytes;

  AppModel copyWith({
    String? name,
    bool? isFrozen,
    bool? isRunning,
    double? memoryBytes,
    bool? isSystem,
    Uint8List? iconBytes,
  }) {
    return AppModel(
      name: name ?? this.name,
      packageName: packageName,
      isFrozen: isFrozen ?? this.isFrozen,
      isRunning: isRunning ?? this.isRunning,
      memoryBytes: memoryBytes ?? this.memoryBytes,
      isSystem: isSystem ?? this.isSystem,
      versionName: versionName,
      iconBytes: iconBytes ?? this.iconBytes,
    );
  }

  factory AppModel.fromMap(Map<Object?, Object?> map) {
    return AppModel(
      name: JsonUtils.toStringValue(
        map['name'],
        fallback: JsonUtils.toStringValue(map['packageName'], fallback: 'Unknown app'),
      ),
      packageName: JsonUtils.toStringValue(map['packageName']),
      isFrozen: JsonUtils.toBool(map['isFrozen']),
      isRunning: JsonUtils.toBool(map['isRunning']),
      memoryBytes: JsonUtils.toDouble(map['memoryBytes']),
      isSystem: JsonUtils.toBool(map['isSystem']),
      versionName: JsonUtils.toStringValue(map['versionName']),
        iconBytes: map['iconBytes'] is Uint8List
          ? map['iconBytes'] as Uint8List
          : map['iconBytes'] is List
            ? Uint8List.fromList((map['iconBytes'] as List).whereType<int>().toList())
            : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppModel && other.packageName == packageName;

  @override
  int get hashCode => packageName.hashCode;
}
