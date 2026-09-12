import '../../core/json_utils.dart';

class GpuStats {
  const GpuStats({
    this.name = '',
    this.usagePercent = -1,
    this.currentFrequencyMhz = 0,
    this.temperatureCelsius,
  });

  final String name;
  final double usagePercent;
  final int currentFrequencyMhz;
  final double? temperatureCelsius;

  factory GpuStats.fromMap(Map<Object?, Object?> map) {
    return GpuStats(
      name: JsonUtils.toStringValue(map['name']),
      usagePercent: JsonUtils.toDouble(map['usagePercent']),
      currentFrequencyMhz: JsonUtils.toInt(map['currentFrequencyMhz']),
      temperatureCelsius: JsonUtils.toNullableDouble(map['temperatureCelsius']),
    );
  }
}
