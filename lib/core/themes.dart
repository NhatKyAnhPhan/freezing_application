import 'package:flutter/material.dart';

import 'constants.dart';

abstract final class AppTheme {
  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.primaryColor),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    );
  }
}