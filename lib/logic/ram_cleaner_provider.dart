import 'package:flutter/widgets.dart';

import '../data/models/clean_result.dart';
import '../data/services/ram_cleaner_service.dart';

/// Lifecycle of a single RAM cleaning cycle.
enum CleanPhase { idle, running, finished, failed }

/// Owns the cleaning state machine and the results shown by the dashboard.
class RamCleanerProvider extends ChangeNotifier {
  RamCleanerProvider({RamCleanerService? service})
      : _service = service ?? const RamCleanerService();

  final RamCleanerService _service;

  CleanPhase _phase = CleanPhase.idle;
  CleanResult? _lastResult;
  String? _errorMessage;
  double _beforeUsedBytes = 0;
  double _afterUsedBytes = 0;
  double _sessionFreedBytes = 0;
  int _cleanCount = 0;

  CleanPhase get phase => _phase;
  CleanResult? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;
  double get beforeUsedBytes => _beforeUsedBytes;
  double get afterUsedBytes => _afterUsedBytes;
  double get sessionFreedBytes => _sessionFreedBytes;
  int get cleanCount => _cleanCount;
  bool get isCleaning => _phase == CleanPhase.running;
  bool get hasRun => _cleanCount > 0 && _lastResult != null;

  /// Runs one cycle.
  ///
  /// [beforeUsedBytes] seeds the animated countdown on the cleaning screen so
  /// the number starts from the reading the user is already looking at.
  Future<CleanResult> clean({
    required double beforeUsedBytes,
    List<String> excludePackages = const <String>[],
    bool aggressive = true,
  }) async {
    if (isCleaning) return _lastResult ?? CleanResult.unavailable;
    _beforeUsedBytes = beforeUsedBytes;
    _afterUsedBytes = beforeUsedBytes;
    _errorMessage = null;
    _phase = CleanPhase.running;
    notifyListeners();

    final CleanResult result = await _service.cleanRam(
      excludePackages: excludePackages,
      aggressive: aggressive,
    );

    _lastResult = result;
    _afterUsedBytes = result.afterUsedBytes > 0 ? result.afterUsedBytes : beforeUsedBytes;
    if (result.succeeded) {
      _phase = CleanPhase.finished;
      _cleanCount += 1;
      _sessionFreedBytes += result.freedBytes;
    } else {
      _phase = CleanPhase.failed;
      _errorMessage = 'Không thể dọn RAM. Hãy kiểm tra quyền Shizuku.';
    }
    notifyListeners();
    return result;
  }

  /// Keeps the animation in sync while the native call is still running.
  void reportLiveUsage(double usedBytes) {
    if (!isCleaning) return;
    _afterUsedBytes = usedBytes;
  }

  void reset() {
    _phase = CleanPhase.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Rough estimate of how much can be released, used to pre-load the bar.
  double estimateTarget(double totalBytes, double usedBytes) {
    if (totalBytes <= 0) return usedBytes;
    final double target = usedBytes - totalBytes * 0.14;
    final double floor = totalBytes * 0.35;
    return target.clamp(floor, usedBytes).toDouble();
  }

  double get averageFreedBytes =>
      _cleanCount == 0 ? 0 : _sessionFreedBytes / _cleanCount;

  /// Roughly how much of the used memory an aggressive cycle can reclaim.
  static const double aggressiveRamRatio = 0.14;

  /// Never pretend less than this share of RAM is in use.
  static const double minimumUsedRatio = 0.35;
}
