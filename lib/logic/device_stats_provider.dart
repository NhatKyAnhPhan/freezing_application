import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/constants.dart';
import '../data/models/device_stats.dart';
import '../data/services/device_stats_service.dart';

/// Polls CPU / RAM / battery telemetry and keeps a short rolling history that
/// the dashboard charts render.
class DeviceStatsProvider extends ChangeNotifier {
  DeviceStatsProvider({DeviceStatsService? service})
      : _service = service ?? const DeviceStatsService();

  final DeviceStatsService _service;

  Timer? _timer;
  DeviceStats _stats = DeviceStats.empty;
  final List<double> _cpuHistory = <double>[];
  final List<double> _ramHistory = <double>[];
  final List<double> _batteryHistory = <double>[];
  bool _isAvailable = false;
  bool _isRefreshing = false;
  bool _disposed = false;

  DeviceStats get stats => _stats;
  List<double> get cpuHistory => List<double>.unmodifiable(_cpuHistory);
  List<double> get ramHistory => List<double>.unmodifiable(_ramHistory);
  List<double> get batteryHistory => List<double>.unmodifiable(_batteryHistory);
  bool get isAvailable => _isAvailable;
  bool get isRefreshing => _isRefreshing;
  double get cpuUsage => _stats.cpu.usagePercent;
  double get ramPercent => _stats.ram.percent;
  int get batteryLevel => _stats.battery.levelPercent;

  /// Starts periodic polling. Safe to call more than once.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(AppConstants.statsPollInterval, (_) => refresh());
    unawaited(refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (_disposed || _isRefreshing) return;
    _isRefreshing = true;
    final DeviceStats next = await _service.fetchStats();
    if (_disposed) return;
    _isRefreshing = false;
    _isAvailable = next.ram.totalBytes > 0 || next.cpu.coreCount > 0;
    if (_isAvailable) {
      _stats = next;
      _push(_cpuHistory, next.cpu.usagePercent);
      _push(_ramHistory, next.ram.percent);
      _push(_batteryHistory, next.battery.levelPercent.toDouble());
    }
    notifyListeners();
  }

  void _push(List<double> target, double value) {
    target.add(value);
    while (target.length > AppConstants.historyLength) {
      target.removeAt(0);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
