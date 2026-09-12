import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models/device_stats.dart';
import '../../logic/device_stats_provider.dart';

class HardwareDetailScreen extends StatelessWidget {
  const HardwareDetailScreen({required this.section, required this.provider, super.key});

  final HardwareSection section;
  final DeviceStatsProvider provider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: AnimatedBuilder(
        animation: provider,
        builder: (context, _) {
          final stats = provider.stats;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _HeroMetric(
                icon: section == HardwareSection.cpu ? Icons.memory_rounded : section == HardwareSection.gpu ? Icons.developer_board_rounded : section == HardwareSection.battery ? Icons.battery_charging_full_rounded : Icons.thermostat_rounded,
                color: section == HardwareSection.cpu ? const Color(0xFF3B82F6) : section == HardwareSection.gpu ? const Color(0xFF14B8A6) : section == HardwareSection.battery ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                title: section == HardwareSection.cpu ? stats.cpu.model : section == HardwareSection.gpu ? stats.gpu.name : section == HardwareSection.battery ? 'Pin thiết bị' : 'Nhiệt độ thiết bị',
                value: section == HardwareSection.cpu ? '${stats.cpu.usagePercent.toStringAsFixed(1)}%' : section == HardwareSection.gpu ? (stats.gpu.usagePercent < 0 ? 'N/A' : '${stats.gpu.usagePercent.toStringAsFixed(1)}%') : section == HardwareSection.battery ? '${stats.battery.levelPercent}%' : Formatters.celsius(stats.cpu.temperatureCelsius),
                caption: section == HardwareSection.thermal ? 'Theo dõi nhiệt độ' : 'Mức sử dụng hiện tại',
              ),
              const SizedBox(height: 16),
              if (section == HardwareSection.cpu)
                _CpuDetails(stats: stats)
              else if (section == HardwareSection.gpu)
                _GpuDetails(stats: stats),
              if (section == HardwareSection.battery)
                _BatteryDetails(stats: stats),
              if (section == HardwareSection.thermal)
                _ThermalDetails(stats: stats),
            ],
          );
        },
      ),
    );
  }

  String get _title => switch (section) {
        HardwareSection.cpu => 'Chi tiết CPU',
        HardwareSection.gpu => 'Chi tiết GPU',
        HardwareSection.battery => 'Chi tiết pin',
        HardwareSection.thermal => 'Chi tiết nhiệt độ',
      };
}

enum HardwareSection { cpu, gpu, battery, thermal }

class _ThermalDetails extends StatelessWidget {
  const _ThermalDetails({required this.stats});

  final DeviceStats stats;

  @override
  Widget build(BuildContext context) {
    return _DetailsGroup(
      title: 'Cảm biến nhiệt độ',
      icon: Icons.thermostat_rounded,
      children: [
        _DetailRow(label: 'CPU / SoC', value: Formatters.celsius(stats.cpu.temperatureCelsius)),
        _DetailRow(label: 'GPU', value: stats.gpu.temperatureCelsius == null ? 'Không thể lấy trên thiết bị này' : Formatters.celsius(stats.gpu.temperatureCelsius)),
        _DetailRow(label: 'Pin', value: stats.battery.temperatureCelsius > 0 ? Formatters.celsius(stats.battery.temperatureCelsius) : 'Không thể lấy trên thiết bị này'),
        _DetailRow(label: 'Trạng thái CPU', value: stats.cpu.isHot ? 'Nóng' : stats.cpu.isWarm ? 'Ấm' : 'Bình thường'),
        _DetailRow(label: 'Trạng thái pin', value: stats.battery.isHot ? 'Nóng' : stats.battery.isWarm ? 'Ấm' : 'Bình thường'),
      ],
    );
  }
}

class _BatteryDetails extends StatelessWidget {
  const _BatteryDetails({required this.stats});

  final DeviceStats stats;

  @override
  Widget build(BuildContext context) {
    final battery = stats.battery;
    return _DetailsGroup(
      title: 'Thông số pin thực tế',
      icon: Icons.battery_charging_full_rounded,
      children: [
        _DetailRow(label: 'Mức pin hiện tại', value: '${battery.levelPercent}%'),
        _DetailRow(label: 'Trạng thái', value: battery.statusLabel),
        _DetailRow(label: 'Sức khỏe hệ thống', value: battery.health),
        _DetailRow(label: 'Độ chai ước tính', value: battery.wearPercent == null ? 'Cần đo thêm khi pin trên 80%' : '${battery.wearPercent!.toStringAsFixed(1)}%'),
        _DetailRow(label: 'Sức khỏe pin ước tính', value: battery.healthPercent == null ? 'Cần đo thêm khi pin trên 80%' : '${battery.healthPercent!.toStringAsFixed(1)}%'),
        _DetailRow(label: 'Dung lượng thiết kế', value: battery.designCapacityMah > 0 ? '${battery.designCapacityMah.round()} mAh' : 'Không thể lấy trên thiết bị này'),
        _DetailRow(label: 'Dung lượng thực tế đo được', value: battery.measuredCapacityMah > 0 ? '${battery.measuredCapacityMah.round()} mAh' : 'Không thể lấy trên thiết bị này'),
        _DetailRow(label: 'Dung lượng sạc đầy', value: battery.fullChargeCapacityMah > 0 ? '${battery.fullChargeCapacityMah.round()} mAh' : 'Không thể lấy trên thiết bị này'),
        _DetailRow(label: 'Mốc tham chiếu', value: battery.referenceCapacityMah > 0 ? '${battery.referenceCapacityMah.round()} mAh' : 'Sẽ ghi nhận khi pin trên 80%'),
        _DetailRow(label: 'Điện áp', value: battery.voltageMilliVolts > 0 ? '${battery.voltageMilliVolts} mV' : 'N/A'),
        _DetailRow(label: 'Dòng điện', value: battery.currentMilliAmps > 0 ? '${battery.currentMilliAmps.round()} mA' : 'N/A'),
        _DetailRow(label: 'Nhiệt độ', value: battery.temperatureCelsius > 0 ? Formatters.celsius(battery.temperatureCelsius) : 'Không thể lấy trên thiết bị này'),
        _DetailRow(label: 'Công nghệ', value: battery.technology),
      ],
    );
  }
}

class _CpuDetails extends StatelessWidget {
  const _CpuDetails({required this.stats});

  final DeviceStats stats;

  @override
  Widget build(BuildContext context) {
    final cpu = stats.cpu;
    return _DetailsGroup(
      title: 'Bộ xử lý',
      icon: Icons.memory_rounded,
      children: [
        _DetailRow(label: 'SoC / model', value: cpu.model),
        _DetailRow(label: 'Kiến trúc', value: cpu.architecture),
        _DetailRow(label: 'Số nhân logic', value: '${cpu.coreCount} nhân'),
        _DetailRow(label: 'Xung hiện tại', value: Formatters.frequency(cpu.currentFrequencyMhz)),
        _DetailRow(label: 'Xung tối đa', value: Formatters.frequency(cpu.maxFrequencyMhz)),
        _DetailRow(label: 'Nhiệt độ', value: Formatters.celsius(cpu.temperatureCelsius)),
        _DetailRow(label: 'Load average', value: cpu.loadAverage.toStringAsFixed(2)),
        _DetailRow(label: 'Load theo nhân', value: '${cpu.loadPercent.toStringAsFixed(1)}%'),
        _DetailRow(label: 'Tiến trình', value: '${cpu.processCount}'),
      ],
    );
  }
}

class _GpuDetails extends StatelessWidget {
  const _GpuDetails({required this.stats});

  final DeviceStats stats;

  @override
  Widget build(BuildContext context) {
    final gpu = stats.gpu;
    return _DetailsGroup(
      title: 'Đồ họa',
      icon: Icons.developer_board_rounded,
      children: [
        _DetailRow(label: 'GPU model', value: gpu.name),
        _DetailRow(label: 'Mức sử dụng', value: gpu.usagePercent < 0 ? 'Không thể lấy trên thiết bị này' : '${gpu.usagePercent.toStringAsFixed(1)}%'),
        _DetailRow(label: 'Xung hiện tại', value: gpu.currentFrequencyMhz > 0 ? Formatters.frequency(gpu.currentFrequencyMhz) : 'Không thể lấy trên thiết bị này'),
        _DetailRow(label: 'Nhiệt độ', value: gpu.temperatureCelsius == null ? 'Không thể lấy trên thiết bị này' : Formatters.celsius(gpu.temperatureCelsius)),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.icon, required this.color, required this.title, required this.value, required this.caption});

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 38),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.isEmpty ? 'N/A' : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ])),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _DetailsGroup extends StatelessWidget {
  const _DetailsGroup({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleMedium)])),
        ...children,
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      child: Row(children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(width: 12),
        Flexible(child: Text(value.isEmpty ? 'N/A' : value, textAlign: TextAlign.end, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
