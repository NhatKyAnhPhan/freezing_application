import '../../core/json_utils.dart';

/// Snapshot of the processor state reported by the native layer.
class CpuStats {
  const CpuStats({
    this.usagePercent = 0,
    this.coreCount = 0,
    this.maxFrequencyMhz = 0,
    this.currentFrequencyMhz = 0,
    this.temperatureCelsius,
    this.processCount = 0,
    this.loadAverage = 0,
    this.architecture = '',
    this.model = '',
  });

  /// Aggregate utilisation across all cores, 0-100.
  final double usagePercent;

  /// Number of logical cores advertised by the device.
  final int coreCount;

  /// Highest frequency advertised by any core, in MHz.
  final int maxFrequencyMhz;

  /// Current frequency of the busiest core, in MHz.
  final int currentFrequencyMhz;

  /// SoC temperature when the thermal zone is readable.
  final double? temperatureCelsius;

  /// Number of processes currently alive on the device.
  final int processCount;

  /// One minute load average, when readable from `/proc/loadavg`.
  final double loadAverage;

  /// CPU ABI, e.g. `arm64-v8a`.
  final String architecture;
  final String model;

  bool get isWarm => (temperatureCelsius ?? 0) >= 55;
  bool get isHot => (temperatureCelsius ?? 0) >= 70;

  /// Load expressed relative to the core count, capped at 100.
  double get loadPercent {
    if (coreCount <= 0) return 0;
    return (loadAverage / coreCount * 100).clamp(0, 100).toDouble();
  }

  factory CpuStats.fromMap(Map<Object?, Object?> map) {
    return CpuStats(
      usagePercent: JsonUtils.toDouble(map['usagePercent']),
      coreCount: JsonUtils.toInt(map['coreCount']),
      maxFrequencyMhz: JsonUtils.toInt(map['maxFrequencyMhz']),
      currentFrequencyMhz: JsonUtils.toInt(map['currentFrequencyMhz']),
      temperatureCelsius: JsonUtils.toNullableDouble(map['temperatureCelsius']),
      processCount: JsonUtils.toInt(map['processCount']),
      loadAverage: JsonUtils.toDouble(map['loadAverage']),
      architecture: JsonUtils.toStringValue(map['architecture']),
      model: JsonUtils.toStringValue(map['model']),
    );
  }
}
