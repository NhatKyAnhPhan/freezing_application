import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/themes.dart';
import 'logic/app_scope.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  runApp(const FreezingApp());
}

class FreezingApp extends StatelessWidget {
  const FreezingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: AppScopeRoot(child: const HomeScreen()),
    );
  }
}