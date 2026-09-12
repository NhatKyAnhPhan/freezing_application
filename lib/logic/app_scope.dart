import 'dart:async';

import 'package:flutter/widgets.dart';

import 'device_stats_provider.dart';
import 'freezer_provider.dart';
import 'ram_cleaner_provider.dart';

/// Provides the three long-lived providers to the widget tree.
///
/// The scope itself never rebuilds: providers are created once by
/// [AppScopeRoot] and screens listen to the specific provider they need with an
/// `AnimatedBuilder`. This keeps the 2-second telemetry tick from repainting
/// the whole app.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.freezer,
    required this.stats,
    required this.cleaner,
    required super.child,
    super.key,
  });

  final FreezerProvider freezer;
  final DeviceStatsProvider stats;
  final RamCleanerProvider cleaner;

  static AppScope of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      freezer != oldWidget.freezer ||
      stats != oldWidget.stats ||
      cleaner != oldWidget.cleaner;
}

extension AppScopeContext on BuildContext {
  AppScope get scope => AppScope.of(this);
  FreezerProvider get freezer => AppScope.of(this).freezer;
  DeviceStatsProvider get deviceStats => AppScope.of(this).stats;
  RamCleanerProvider get cleaner => AppScope.of(this).cleaner;
}

/// Creates the providers, starts telemetry polling and disposes everything on
/// teardown.
class AppScopeRoot extends StatefulWidget {
  const AppScopeRoot({required this.child, super.key});

  final Widget child;

  @override
  State<AppScopeRoot> createState() => _AppScopeRootState();
}

class _AppScopeRootState extends State<AppScopeRoot> with WidgetsBindingObserver {
  late final FreezerProvider _freezer = FreezerProvider();
  late final DeviceStatsProvider _stats = DeviceStatsProvider();
  late final RamCleanerProvider _cleaner = RamCleanerProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stats.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _stats.start();
      unawaited(_freezer.loadApps());
    } else if (state == AppLifecycleState.paused) {
      _stats.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stats.dispose();
    _freezer.dispose();
    _cleaner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      freezer: _freezer,
      stats: _stats,
      cleaner: _cleaner,
      child: widget.child,
    );
  }
}
