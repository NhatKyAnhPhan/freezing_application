import '../../core/json_utils.dart';

/// Outcome of one RAM cleaning cycle, produced by the native layer.
class CleanResult {
  const CleanResult({
    this.freedBytes = 0,
    this.killedApps = 0,
    this.trimmedProcesses = 0,
    this.beforeUsedBytes = 0,
    this.afterUsedBytes = 0,
    this.durationMs = 0,
    this.method = 'none',
    this.succeeded = false,
  });

  /// Bytes reclaimed between the start and the end of the cycle.
  final double freedBytes;

  /// Number of background applications that were force-stopped.
  final int killedApps;

  /// Number of processes whose memory was trimmed (`am trim-memory`).
  final int trimmedProcesses;

  final double beforeUsedBytes;
  final double afterUsedBytes;
  final int durationMs;

  /// `shizuku`, `local` or `none`.
  final String method;

  final bool succeeded;

  bool get didFreeMemory => freedBytes > 0;

  String get methodLabel {
    switch (method) {
      case 'shizuku':
        return 'Trợ lý Shizuku';
      case 'local':
        return 'Bộ nhớ nội bộ';
      default:
        return 'Không xác định';
    }
  }

  factory CleanResult.fromMap(Map<Object?, Object?> map) {
    return CleanResult(
      freedBytes: JsonUtils.toDouble(map['freedBytes']),
      killedApps: JsonUtils.toInt(map['killedApps']),
      trimmedProcesses: JsonUtils.toInt(map['trimmedProcesses']),
      beforeUsedBytes: JsonUtils.toDouble(map['beforeUsedBytes']),
      afterUsedBytes: JsonUtils.toDouble(map['afterUsedBytes']),
      durationMs: JsonUtils.toInt(map['durationMs']),
      method: JsonUtils.toStringValue(map['method'], fallback: 'none'),
      succeeded: JsonUtils.toBool(map['succeeded'], fallback: true),
    );
  }

  /// Used when the platform channel is unavailable, e.g. on desktop or iOS.
  static const CleanResult unavailable = CleanResult(
    method: 'none',
    succeeded: false,
  );
}
