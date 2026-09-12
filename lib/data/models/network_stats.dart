import '../../core/json_utils.dart';

class NetworkStats {
  const NetworkStats({
    this.downloadMbps = 0,
    this.uploadMbps = 0,
    this.linkDownMbps = 0,
    this.linkUpMbps = 0,
  });

  final double downloadMbps;
  final double uploadMbps;
  final int linkDownMbps;
  final int linkUpMbps;

  factory NetworkStats.fromMap(Map<Object?, Object?> map) {
    return NetworkStats(
      downloadMbps: JsonUtils.toDouble(map['downloadMbps']),
      uploadMbps: JsonUtils.toDouble(map['uploadMbps']),
      linkDownMbps: JsonUtils.toInt(map['linkDownMbps']),
      linkUpMbps: JsonUtils.toInt(map['linkUpMbps']),
    );
  }
}
