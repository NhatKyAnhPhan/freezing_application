import '../../core/json_utils.dart';
import 'battery_stats.dart';
import 'cpu_stats.dart';
import 'gpu_stats.dart';
import 'network_stats.dart';
import 'ram_stats.dart';
import 'storage_stats.dart';

/// Full telemetry snapshot for one polling tick.
class DeviceStats {
  const DeviceStats({
    this.cpu = const CpuStats(),
    this.gpu = const GpuStats(),
    this.network = const NetworkStats(),
    this.ram = const RamStats(),
    this.battery = const BatteryStats(),
    this.storage = const StorageStats(),
    this.runningAppCount = 0,
    this.timestamp,
  });

  final CpuStats cpu;
  final GpuStats gpu;
  final NetworkStats network;
  final RamStats ram;
  final BatteryStats battery;
  final StorageStats storage;

  /// Third-party packages currently resident in memory.
  final int runningAppCount;

  /// When the native layer produced this snapshot.
  final DateTime? timestamp;

  static const DeviceStats empty = DeviceStats();

  /// Builds a snapshot from a native payload shaped as
  /// `{cpu: {...}, ram: {...}, battery: {...}, storage: {...}, runningAppCount: n}`.
  factory DeviceStats.fromMap(Map<Object?, Object?> map) {
    final Object? timestamp = map['timestamp'];
    return DeviceStats(
      cpu: CpuStats.fromMap(JsonUtils.toMap(map['cpu'])),
      gpu: GpuStats.fromMap(JsonUtils.toMap(map['gpu'])),
      network: NetworkStats.fromMap(JsonUtils.toMap(map['network'])),
      ram: RamStats.fromMap(JsonUtils.toMap(map['ram'])),
      battery: BatteryStats.fromMap(JsonUtils.toMap(map['battery'])),
      storage: StorageStats.fromMap(JsonUtils.toMap(map['storage'])),
      runningAppCount: JsonUtils.toInt(map['runningAppCount']),
      timestamp: timestamp is int
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null,
    );
  }
}
