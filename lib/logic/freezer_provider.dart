import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/constants.dart';
import '../data/models/app_model.dart';
import '../data/services/shizuku_service.dart';

/// Owns the installed-app catalogue, the freeze state of every package and the
/// Shizuku connection status.
class FreezerProvider extends ChangeNotifier {
  FreezerProvider({ShizukuService? service})
      : _service = service ?? const ShizukuService();

  final ShizukuService _service;

  List<AppModel> _apps = const <AppModel>[];
  final Set<String> _selectedPackages = <String>{};
  final Set<String> _runningPackages = <String>{};
  final Set<String> _processingPackages = <String>{};
  bool _isLoading = false;
  bool _isApplying = false;
  bool _isConnectingShizuku = false;
  int _connectionAttempt = 0;
  String? _errorMessage;
  String _shizukuStatus = ShizukuService.statusUnavailable;
  String _searchQuery = '';

  List<AppModel> get apps => List.unmodifiable(_apps);
  bool get isLoading => _isLoading;
  bool get isApplying => _isApplying;
  bool get isConnectingShizuku => _isConnectingShizuku;
  String? get errorMessage => _errorMessage;
  String get shizukuStatus => _shizukuStatus;
  String get searchQuery => _searchQuery;
  bool get isShizukuGranted => _shizukuStatus == ShizukuService.statusGranted;
  bool get isShizukuDenied => _shizukuStatus == ShizukuService.statusDenied;
  bool isProcessing(String packageName) => _processingPackages.contains(packageName);

  /// Apps currently disabled for the user.
  List<AppModel> get frozenApps =>
      _apps.where((AppModel app) => app.isFrozen).toList(growable: false);
  int get frozenCount => frozenApps.length;

  /// Apps that are enabled and hold a running process.
  List<AppModel> get runningApps =>
      _apps.where((AppModel app) => !app.isFrozen && _runningPackages.contains(app.packageName)).toList(growable: false);
  int get runningCount => runningApps.length;

  /// Apps that are enabled and freezable.
  List<AppModel> get freezableApps =>
      _apps.where((AppModel app) => !app.isFrozen).toList(growable: false);

  Set<String> get selectedPackages => Set.unmodifiable(_selectedPackages);
  int get selectedCount => _selectedPackages.length;
  bool isSelected(String packageName) => _selectedPackages.contains(packageName);

  /// RAM the frozen apps would have held if they were still enabled.
  double get estimatedSavedRamBytes =>
      frozenCount * AppConstants.estimatedRamPerFrozenAppMb * 1024 * 1024;

  /// Standby current saved by keeping those apps disabled.
  double get estimatedSavedMilliAmps =>
      frozenCount * AppConstants.estimatedMilliAmpPerFrozenApp;

  /// Percentage of the standby drain the freeze list currently offsets.
  double get estimatedSavedPercent => (frozenCount * 5).clamp(0, 100).toDouble();

  List<AppModel> get visibleApps {
    final String query = _searchQuery.trim().toLowerCase();
    final List<AppModel> source = query.isEmpty
        ? _apps
        : _apps
            .where((AppModel app) =>
                app.name.toLowerCase().contains(query) ||
                app.packageName.toLowerCase().contains(query))
            .toList(growable: false);
    return List.unmodifiable(source);
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void toggleSelection(String packageName) {
    if (_selectedPackages.contains(packageName)) {
      _selectedPackages.remove(packageName);
    } else {
      _selectedPackages.add(packageName);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedPackages.isEmpty) return;
    _selectedPackages.clear();
    notifyListeners();
  }

  void selectAllVisible() {
    for (final AppModel app in visibleApps) {
      if (!app.isFrozen) _selectedPackages.add(app.packageName);
    }
    notifyListeners();
  }

  Future<void> refreshShizukuStatus() async {
    _shizukuStatus = await _service.getStatus();
    notifyListeners();
  }

  Future<String> requestShizukuPermission() async {
    if (_isConnectingShizuku) return _shizukuStatus;
    final int attempt = ++_connectionAttempt;
    _isConnectingShizuku = true;
    notifyListeners();
    final String status = await _service.requestPermission();
    if (attempt != _connectionAttempt) return status;
    _shizukuStatus = status;
    _isConnectingShizuku = false;
    notifyListeners();
    return status;
  }

  void cancelShizukuConnection() {
    if (!_isConnectingShizuku) return;
    _connectionAttempt++;
    _isConnectingShizuku = false;
    notifyListeners();
  }

  /// Loads installed apps, the disabled set and the running processes.
  Future<void> loadApps() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _shizukuStatus = await _service.getStatus();
      notifyListeners();
      if (!isShizukuGranted) {
        _errorMessage = isShizukuDenied
            ? 'Cần cấp quyền Shizuku để điều khiển ứng dụng.'
            : 'Hãy cài đặt và khởi động Shizuku trước.';
        _apps = const <AppModel>[];
        return;
      }
      _apps = const <AppModel>[];
      notifyListeners();
      const int pageSize = 24;
      int offset = 0;
      bool firstPage = true;
      while (true) {
        final List<AppModel> page = await _service.getInstalledAppsPage(
          offset: offset,
          limit: pageSize,
          refresh: firstPage,
        );
        firstPage = false;
        if (page.isEmpty) break;
        _apps = <AppModel>[..._apps, ...page];
        offset += page.length;
        notifyListeners();
        if (page.length < pageSize) break;
      }
      final List<String> running = await _service.getRunningPackages();
      _runningPackages
        ..clear()
        ..addAll(running);
        _apps = _apps
          .map((AppModel app) =>
              app.copyWith(isRunning: _runningPackages.contains(app.packageName)))
          .toList(growable: false);
      _selectedPackages
          .removeWhere((String package) => !_apps.any((AppModel app) => app.packageName == package));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes only the running-process set, which changes far more often than
  /// the installed-app catalogue.
  Future<void> refreshRunningState() async {
    if (!isShizukuGranted) return;
    final List<String> running = await _service.getRunningPackages();
    _runningPackages
      ..clear()
      ..addAll(running);
    _apps = _apps
        .map((AppModel app) =>
            app.copyWith(isRunning: _runningPackages.contains(app.packageName)))
        .toList(growable: false);
    notifyListeners();
  }

  Future<bool> toggleFrozen(AppModel app) async {
    if (_processingPackages.contains(app.packageName)) return false;
    final bool target = !app.isFrozen;
    _processingPackages.add(app.packageName);
    _applyLocalState(<String>[app.packageName], frozen: target);
    notifyListeners();
    final bool success = await _service.setFrozen(app.packageName, frozen: target);
    _processingPackages.remove(app.packageName);
    if (!success) {
      _applyLocalState(<String>[app.packageName], frozen: !target);
      _errorMessage = 'Không thể ${target ? 'đóng băng' : 'rã đông'} ${app.name}.';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Freezes every package in [packageNames] in one pass and force-stops them so
  /// the memory is released immediately.
  Future<int> freezePackages(List<String> packageNames) async {
    final List<String> targets =
        packageNames.whereType<String>().where((String name) => name.isNotEmpty).toList();
    if (targets.isEmpty || _isApplying) return 0;
    _isApplying = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final List<String> updated = await _service.setFrozenBatch(targets, frozen: true);
      if (updated.isEmpty) {
        _errorMessage = 'Không thể đóng băng ứng dụng đã chọn.';
        return 0;
      }
      await _service.killBackgroundApps(updated);
      _applyLocalState(updated, frozen: true);
      _selectedPackages.removeAll(updated);
      return updated.length;
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  /// Re-enables the given packages (or every frozen app when omitted).
  Future<int> unfreezePackages([List<String>? packageNames]) async {
    final List<String> targets = packageNames ??
        frozenApps.map((AppModel app) => app.packageName).toList(growable: false);
    if (targets.isEmpty || _isApplying) return 0;
    _isApplying = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final List<String> updated = await _service.setFrozenBatch(targets, frozen: false);
      if (updated.isEmpty) {
        _errorMessage = 'Không thể rã đông ứng dụng đã chọn.';
        return 0;
      }
      _applyLocalState(updated, frozen: false);
      return updated.length;
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  /// Force-stops the running background apps without changing freeze state.
  Future<int> killRunningBackgroundApps() async {
    if (_isApplying) return 0;
    final List<String> targets =
        runningApps.map((AppModel app) => app.packageName).toList(growable: false);
    if (targets.isEmpty) return 0;
    _isApplying = true;
    notifyListeners();
    try {
      final int killed = await _service.killBackgroundApps(targets);
      await refreshRunningState();
      return killed;
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  void _applyLocalState(List<String> packages, {required bool frozen}) {
    final Set<String> targets = packages.toSet();
    _apps = _apps
        .map((AppModel app) => targets.contains(app.packageName)
            ? app.copyWith(isFrozen: frozen, isRunning: frozen ? false : app.isRunning)
            : app)
        .toList(growable: false);
    if (frozen) {
      for (final String package in packages) {
        _runningPackages.remove(package);
      }
    }
  }
}
