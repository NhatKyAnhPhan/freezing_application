/// Defensive converters for the loosely typed maps that cross the platform
/// channel boundary. The native side may hand back `int`, `double`, `String`
/// or `null`, so every model reads its fields through these helpers.
abstract final class JsonUtils {
  static double toDouble(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static double? toNullableDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int toInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? toNullableInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool toBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String normalised = value.toLowerCase();
      return normalised == 'true' || normalised == '1';
    }
    return fallback;
  }

  static String toStringValue(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  /// Casts an arbitrary list crossing the channel into a list of maps.
  static List<Map<Object?, Object?>> toMapList(Object? value) {
    if (value is! List) return const <Map<Object?, Object?>>[];
    return value.whereType<Map<Object?, Object?>>().toList();
  }

  /// Casts an arbitrary list crossing the channel into a list of strings.
  static List<String> toStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<Object>().map((Object item) => item.toString()).toList();
  }

  /// Reads a nested map, returning an empty map when absent.
  static Map<Object?, Object?> toMap(Object? value) {
    if (value is Map<Object?, Object?>) return value;
    return const <Object?, Object?>{};
  }
}
