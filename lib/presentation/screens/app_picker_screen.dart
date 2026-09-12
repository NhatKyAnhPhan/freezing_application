import 'package:flutter/material.dart';

import '../../data/models/app_model.dart';
import '../widgets/app_tile.dart';

class AppPickerScreen extends StatelessWidget {
  const AppPickerScreen({required this.apps, super.key});

  final List<AppModel> apps;

  @override
  Widget build(BuildContext context) {
    final userApps = apps.where((app) => !app.isSystem).toList(growable: false);
    final systemApps = apps
        .where((app) => app.isSystem)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose an app')),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: 'Đã cài đặt (${userApps.length})'),
                Tab(text: 'Hệ thống (${systemApps.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _AppList(apps: userApps),
                  _AppList(apps: systemApps),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.apps});

  final List<AppModel> apps;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return const Center(child: Text('Không có ứng dụng trong nhóm này'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) =>
          AppTile(app: apps[index], onToggle: () {}),
    );
  }
}
