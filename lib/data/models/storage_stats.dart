import '../../core/json_utils.dart';

/// Internal storage usage, surfaced on the dashboard detail screen.
class StorageStats {
  const StorageStats({
    this.totalBytes = 0,
    this.usedBytes = 0,
    this.availableBytes = 0,
    this.dataPartitionBytes = 0,
    this.cacheBytes = 0,
  });

  final double totalBytes;
  final double usedBytes;
  final double availableBytes;

  /// Size of the app data partition, used for the storage gauge.
  final double dataPartitionBytes;

  /// Bytes currently held by the OS caches.
  final double cacheBytes;

  double get percent {
    if (totalBytes <= 0) return 0;
    return (usedBytes / totalBytes * 100).clamp(0, 100).toDouble();
  }

  factory StorageStats.fromMap(Map<Object?, Object?> map) {
    return StorageStats(
      totalBytes: JsonUtils.toDouble(map['totalBytes']),
      usedBytes: JsonUtils.toDouble(map['usedBytes']),
      availableBytes: JsonUtils.toDouble(map['availableBytes']),
      dataPartitionBytes: JsonUtils.toDouble(map['dataPartitionBytes']),
      cacheBytes: JsonUtils.toDouble(map['cacheBytes']),
    );
  }
}
