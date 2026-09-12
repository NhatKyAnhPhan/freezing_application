import '../../core/json_utils.dart';

/// Battery telemetry shown on the dashboard "Đóng Xạ Pin" card.
class BatteryStats {
  const BatteryStats({
    this.levelPercent = 0,
    this.isCharging = false,
    this.isPlugged = false,
    this.plugType = 'unplugged',
    this.temperatureCelsius = 0,
    this.voltageMilliVolts = 0,
    this.currentMilliAmps = 0,
    this.health = 'unknown',
    this.technology = '',
    this.chargeCounterMah = 0,
    this.capacityMah = 0,
    this.designCapacityMah = 0,
    this.fullChargeCapacityMah = 0,
    this.measuredCapacityMah = 0,
    this.referenceCapacityMah = 0,
    this.estimatedRemainingMinutes,
    this.estimatedFullMinutes,
  });

  /// Charge level in percent, 0-100.
  final int levelPercent;
  final bool isCharging;
  final bool isPlugged;

  /// `ac`, `usb`, `wireless` or `unplugged`.
  final String plugType;

  final double temperatureCelsius;
  final int voltageMilliVolts;

  /// Instantaneous current in mA. Negative means discharging.
  final double currentMilliAmps;

  /// `good`, `overheat`, `dead`, `cold` or `unknown`.
  final String health;
  final String technology;

  /// Charge counter reported by the fuel gauge, in mAh.
  final double chargeCounterMah;
  final double capacityMah;
  final double designCapacityMah;
  final double fullChargeCapacityMah;
  final double measuredCapacityMah;
  final double referenceCapacityMah;

  /// Time until empty (or until full while charging), in minutes.
  final int? estimatedRemainingMinutes;
  final int? estimatedFullMinutes;

  bool get isLow => levelPercent <= 20;
  bool get isCritical => levelPercent <= 10;
  bool get isWarm => temperatureCelsius >= 40;
  bool get isHot => temperatureCelsius >= 45;
  bool get isHealthy => health == 'good';
  double? get healthPercent {
    final reference = designCapacityMah > 0 ? designCapacityMah : referenceCapacityMah;
    final actual = fullChargeCapacityMah > 0 ? fullChargeCapacityMah : measuredCapacityMah;
    if (reference <= 0 || actual <= 0) return null;
    return (actual / reference * 100).clamp(0, 100).toDouble();
  }
  double? get wearPercent {
    final value = healthPercent;
    return value == null ? null : (100 - value).clamp(0, 100).toDouble();
  }

  /// Negative while draining, positive while charging.
  double get signedCurrent => isCharging ? currentMilliAmps.abs() : -currentMilliAmps.abs();

  /// Displays a positive magnitude regardless of charge direction.
  double get currentMagnitude => currentMilliAmps.abs();

  String get statusLabel {
    if (isCharging) return 'Đang Sạc';
    if (isPlugged) return 'Đã Cắm Sạc';
    return 'Đang Hao';
  }

  factory BatteryStats.fromMap(Map<Object?, Object?> map) {
    return BatteryStats(
      levelPercent: JsonUtils.toInt(map['levelPercent']),
      isCharging: JsonUtils.toBool(map['isCharging']),
      isPlugged: JsonUtils.toBool(map['isPlugged']),
      plugType: JsonUtils.toStringValue(map['plugType'], fallback: 'unplugged'),
      temperatureCelsius: JsonUtils.toDouble(map['temperatureCelsius']),
      voltageMilliVolts: JsonUtils.toInt(map['voltageMilliVolts']),
      currentMilliAmps: JsonUtils.toDouble(map['currentMilliAmps']),
      health: JsonUtils.toStringValue(map['health'], fallback: 'unknown'),
      technology: JsonUtils.toStringValue(map['technology']),
      chargeCounterMah: JsonUtils.toDouble(map['chargeCounterMah']),
      capacityMah: JsonUtils.toDouble(map['capacityMah']),
      designCapacityMah: JsonUtils.toDouble(map['designCapacityMah']),
      fullChargeCapacityMah: JsonUtils.toDouble(map['fullChargeCapacityMah']),
      measuredCapacityMah: JsonUtils.toDouble(map['measuredCapacityMah']),
      referenceCapacityMah: JsonUtils.toDouble(map['referenceCapacityMah']),
      estimatedRemainingMinutes: JsonUtils.toNullableInt(map['estimatedRemainingMinutes']),
      estimatedFullMinutes: JsonUtils.toNullableInt(map['estimatedFullMinutes']),
    );
  }
}
