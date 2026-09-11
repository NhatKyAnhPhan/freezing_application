import 'package:flutter/material.dart';

import '../../data/models/app_model.dart';
import '../widgets/app_tile.dart';

class AppPickerScreen extends StatelessWidget {
  const AppPickerScreen({required this.apps, super.key});

  final List<AppModel> apps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose an app')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: apps.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => AppTile(app: apps[index], onToggle: () {}),
      ),
    );
  }
}