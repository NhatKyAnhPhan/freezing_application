import 'package:flutter/material.dart';

import '../../logic/freezer_provider.dart';
import '../widgets/app_tile.dart';
import 'app_picker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FreezerProviderScope.of(context).loadApps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = FreezerProviderScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freezing App'),
        actions: [
          IconButton(onPressed: provider.loadApps, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          _ShizukuStatusCard(provider: provider),
          Expanded(child: _buildBody(provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AppPickerScreen(apps: provider.apps)),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add app'),
      ),
    );
  }

  Widget _buildBody(FreezerProvider provider) {
    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    if (provider.apps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ac_unit, size: 64),
              const SizedBox(height: 16),
              Text(provider.errorMessage ?? 'No apps available', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: provider.loadApps, icon: const Icon(Icons.refresh), label: const Text('Reload')),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: provider.apps.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final app = provider.apps[index];
        return AppTile(app: app, onToggle: () => provider.toggleFrozen(app));
      },
    );
  }
}

class _ShizukuStatusCard extends StatelessWidget {
  const _ShizukuStatusCard({required this.provider});

  final FreezerProvider provider;

  @override
  Widget build(BuildContext context) {
    final granted = provider.shizukuStatus == 'granted';
    final denied = provider.shizukuStatus == 'denied';
    final title = granted
        ? 'Shizuku connected'
        : denied
            ? 'Shizuku permission needed'
            : 'Shizuku is not running';
    final description = granted
      ? 'Package control is available. Frozen apps may stop push notifications.'
        : denied
            ? 'Grant this app permission in the Shizuku prompt.'
            : 'Install and start Shizuku, then tap refresh.';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ListTile(
        leading: Icon(granted ? Icons.link : Icons.link_off),
        title: Text(title),
        subtitle: Text(description),
        trailing: granted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(
                onPressed: denied
                    ? provider.requestShizukuPermission
                    : provider.refreshShizukuStatus,
                child: Text(denied ? 'Grant' : 'Refresh'),
              ),
      ),
    );
  }
}