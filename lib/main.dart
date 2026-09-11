import 'package:flutter/material.dart';

import 'core/themes.dart';
import 'logic/freezer_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  runApp(const FreezingApp());
}

class FreezingApp extends StatelessWidget {
  const FreezingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freezing App',
      theme: AppTheme.light,
      home: FreezerProviderScope(child: const HomeScreen()),
    );
  }
}