import '../../core/formatters.dart';
import '../../core/json_utils.dart';

/// Physical memory snapshot used by the RAM card and the cleaning flow.
class RamStats {
  const RamStats({
    this.totalBytes = 0,
    this.usedBytes = 0,
    this.availableBytes = 0,
    this.cachedBytes = 0,
    this.swapTotalBytes = 0,
    this.swapUsedBytes = 0,
    this.isLowMemory = false,
    this.thresholdBytes = 0,
  });

  final double totalBytes;
  final double usedBytes;
  final double availableBytes;

  /// Kernel page-cache, reclaimable without killing anything.
  final double cachedBytes;

  final double swapTotalBytes;
  final double swapUsedBytes;
  final bool isLowMemory;

  /// `MemoryInfo.threshold` - the point at which the system starts killing.
  final double thresholdBytes;

  double get percent => Formatters.ratioPercent(usedBytes, totalBytes);

  double get freePercent => (100 - percent).clamp(0, 100).toDouble();

  String get usedLabel => Formatters.gigabytes(usedBytes);

  String get totalLabel => Formatters.gigabytes(totalBytes);

  String get availableLabel => Formatters.gigabytes(availableBytes);

  /// RAM that could realistically be reclaimed by a clean cycle.
  double get reclaimableBytes {
    final double soft = availableBytes + cachedBytes;
    return soft.clamp(0, totalBytes).toDouble();
  }

  factory RamStats.fromMap(Map<Object?, Object?> map) {
    return RamStats(
      totalBytes: JsonUtils.toDouble(map['totalBytes']),
      usedBytes: JsonUtils.toDouble(map['usedBytes']),
      availableBytes: JsonUtils.toDouble(map['availableBytes']),
      cachedBytes: JsonUtils.toDouble(map['cachedBytes']),
      swapTotalBytes: JsonUtils.toDouble(map['swapTotalBytes']),
      swapUsedBytes: JsonUtils.toDouble(map['swapUsedBytes']),
      isLowMemory: JsonUtils.toBool(map['isLowMemory']),
      thresholdBytes: JsonUtils.toDouble(map['thresholdBytes']),
    );
  }
}
