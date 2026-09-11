import 'package:flutter/material.dart';

import '../../data/models/app_model.dart';

class AppTile extends StatelessWidget {
  const AppTile({required this.app, required this.onToggle, super.key});

  final AppModel app;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: const Icon(Icons.apps),
      ),
      title: Text(app.name),
      subtitle: Text(app.packageName),
      trailing: Switch(value: app.isFrozen, onChanged: (_) => onToggle()),
    );
  }
}