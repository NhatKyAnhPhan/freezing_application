/// Small, dependency-free formatting helpers used by the dashboard widgets.
abstract final class Formatters {
  static const int _kilo = 1024;
  static const int _mega = 1024 * 1024;
  static const int _giga = 1024 * 1024 * 1024;

  /// Formats a byte count using binary units, e.g. `1.8 GB`, `512 MB`.
  static String bytes(num value, {int decimals = 1, String suffix = ''}) {
    final double amount = value.toDouble();
    if (amount <= 0) return '0 MB$suffix';
    if (amount >= _giga) {
      return '${(amount / _giga).toStringAsFixed(decimals)} GB$suffix';
    }
    if (amount >= _mega) {
      return '${(amount / _mega).toStringAsFixed(0)} MB$suffix';
    }
    if (amount >= _kilo) {
      return '${(amount / _kilo).toStringAsFixed(0)} KB$suffix';
    }
    return '${amount.toStringAsFixed(0)} B$suffix';
  }

  /// Converts a byte count to gigabytes as a plain number.
  static double toGiga(num value) => value.toDouble() / _giga;

  /// Converts a byte count to megabytes as a plain number.
  static double toMega(num value) => value.toDouble() / _mega;

  /// `2.40 GB` style label.
  static String gigabytes(num value, {int decimals = 2}) =>
      '${toGiga(value).toStringAsFixed(decimals)} GB';

  /// `512 MB` style label.
  static String megabytes(num value, {int decimals = 0}) =>
      '${toMega(value).toStringAsFixed(decimals)} MB';

  /// Rounded percentage such as `48%`.
  static String percent(double value, {int decimals = 0}) =>
      '${value.toStringAsFixed(decimals)}%';

  /// Percentage from a used/total pair, clamped to 0..100.
  static double ratioPercent(num used, num total) {
    if (total <= 0) return 0;
    final double percent = used / total * 100;
    if (percent.isNaN || percent.isInfinite) return 0;
    return percent.clamp(0, 100).toDouble();
  }

  /// Human readable duration such as `8.5 giờ` or `42 phút`.
  static String durationFromMinutes(int? minutes) {
    if (minutes == null || minutes <= 0) return '--';
    if (minutes >= 60) {
      return '${(minutes / 60).toStringAsFixed(1)} giờ';
    }
    return '$minutes phút';
  }

  /// Compact integer grouping for large counters, e.g. `1.024`.
  static String counter(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }

  /// Temperature such as `36.5°C`.
  static String celsius(double? value) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(1)}°C';
  }

  /// Temperature without the unit, used inside stat rows.
  static String celsiusValue(double? value) {
    if (value == null) return '--';
    return value.toStringAsFixed(1);
  }

  /// Milliamps, e.g. `320 mA`.
  static String milliAmps(double value) => '${value.round()} mA';

  /// Megahertz formatted as `2.40 GHz` when above 1000 MHz.
  static String frequency(int megahertz) {
    if (megahertz <= 0) return '--';
    if (megahertz >= 1000) {
      return '${(megahertz / 1000).toStringAsFixed(2)} GHz';
    }
    return '$megahertz MHz';
  }

  /// Estimates total saved memory from a per-app average.
  static String estimatedSavings(double perItemMb, int count) {
    final double total = perItemMb * count;
    if (total <= 0) return '0 MB';
    if (total >= 1024) return '${(total / 1024).toStringAsFixed(1)} GB';
    return '${total.round()} MB';
  }

  /// Signed label used by the "đã giải phóng" summary.
  static String freedLabel(num value) {
    if (value <= 0) return '0 MB';
    return bytes(value, decimals: 2);
  }
}
