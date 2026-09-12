import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/models/app_model.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../logic/app_scope.dart';
import '../../logic/freezer_provider.dart';
import '../widgets/app_tile.dart';
import 'app_picker_screen.dart';
import 'hardware_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _startupRetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(context.freezer.loadApps());
      _startupRetry = Timer(const Duration(milliseconds: 900), () {
        if (mounted && !context.freezer.isShizukuGranted) {
          unawaited(context.freezer.loadApps());
        }
      });
    });
  }

  @override
  void dispose() {
    _startupRetry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.freezer;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.ac_unit_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppConstants.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: provider.loadApps,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới',
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: provider,
        builder: (context, _) => SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _ShizukuStatusCard(provider: provider),
              const SizedBox(height: 12),
              const _DeviceStatsCard(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Danh sách ứng dụng',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (provider.apps.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${provider.apps.length} ứng dụng',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(provider)),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          elevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AppPickerScreen(apps: provider.apps),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Thêm ứng dụng',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(FreezerProvider provider) {
    if (provider.isLoading && provider.apps.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }
    if (provider.apps.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.ac_unit_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                provider.errorMessage ?? 'Chưa có ứng dụng nào được chọn',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface
                      .withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: provider.loadApps,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tải lại'),
              ),
            ],
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          if (provider.isLoading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              tabs: [
                Tab(text: 'Đã cài đặt (${provider.userApps.length})'),
                Tab(text: 'Hệ thống (${provider.systemApps.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAppList(provider, provider.userApps),
                _buildAppList(provider, provider.systemApps),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppList(FreezerProvider provider, List<AppModel> apps) {
    if (apps.isEmpty) {
      return const Center(child: Text('Không có ứng dụng trong nhóm này'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppTile(
            app: app,
            onToggle: () => provider.toggleFrozen(app),
            isProcessing: provider.isProcessing(app.packageName),
          ),
        );
      },
    );
  }
}

class _DeviceStatsCard extends StatelessWidget {
  const _DeviceStatsCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: context.deviceStats,
      builder: (context, _) {
        final stats = context.deviceStats.stats;
        final battery = stats.battery;
        final capacity = battery.capacityMah > 0
            ? '${battery.capacityMah.round()} mAh'
            : 'N/A';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'CPU',
                        value: '${stats.cpu.usagePercent.toStringAsFixed(1)}%',
                        icon: Icons.memory_rounded,
                        color: const Color(0xFF3B82F6),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HardwareDetailScreen(
                              section: HardwareSection.cpu,
                              provider: context.deviceStats,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _MetricTile(
                        label: 'RAM',
                        value: '${stats.ram.percent.round()}%',
                        icon: Icons.dns_rounded,
                        color: const Color(0xFF8B5CF6),
                        onTap: () =>
                            _showRamBoostDialog(context, stats.ram.usedBytes),
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _MetricTile(
                        label: 'Pin',
                        value: '${battery.levelPercent}%',
                        icon: Icons.battery_charging_full_rounded,
                        color: const Color(0xFF10B981),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HardwareDetailScreen(
                              section: HardwareSection.battery,
                              provider: context.deviceStats,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _MetricTile(
                        label: 'Dung lượng',
                        value: capacity,
                        icon: Icons.electric_bolt_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'GPU',
                        value: stats.gpu.usagePercent < 0
                            ? 'Không thể lấy'
                            : '${stats.gpu.usagePercent.toStringAsFixed(1)}%',
                        icon: Icons.developer_board_rounded,
                        color: const Color(0xFF14B8A6),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HardwareDetailScreen(
                              section: HardwareSection.gpu,
                              provider: context.deviceStats,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _MetricTile(
                        label: 'Nhiệt độ',
                        value: Formatters.celsius(
                          stats.gpu.temperatureCelsius ??
                              stats.cpu.temperatureCelsius,
                        ),
                        icon: Icons.thermostat_rounded,
                        color: const Color(0xFFEF4444),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HardwareDetailScreen(
                              section: HardwareSection.thermal,
                              provider: context.deviceStats,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildDivider(isDark),
                    Expanded(
                      child: _MetricTile(
                        label: 'Mạng',
                        value:
                            '${stats.network.downloadMbps.toStringAsFixed(1)} ↓  ${stats.network.uploadMbps.toStringAsFixed(1)} ↑ Mbps',
                        icon: Icons.swap_vert_rounded,
                        color: const Color(0xFF0EA5E9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 32,
      width: 1,
      color: isDark
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.06),
    );
  }

  Future<void> _showRamBoostDialog(
    BuildContext context,
    double usedBytes,
  ) async {
    final cleaner = context.cleaner;
    final Future<void> clean = cleaner
        .clean(beforeUsedBytes: usedBytes)
        .then((_) {});
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AnimatedBuilder(
        animation: cleaner,
        builder: (context, _) {
          final finished = !cleaner.isCleaning;
          if (finished) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(dialogContext).canPop())
                Navigator.of(dialogContext).pop();
            });
          }
          return AlertDialog(
            icon: Icon(
              finished ? Icons.check_circle_rounded : Icons.speed_rounded,
              color: finished ? Colors.green : const Color(0xFF8B5CF6),
              size: 38,
            ),
            title: Text(finished ? 'Đã tăng tốc RAM' : 'Đang tăng tốc RAM'),
            content: finished
                ? const Text('Bộ nhớ đã được tối ưu hóa.')
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Đang giải phóng bộ nhớ nền...'),
                    ],
                  ),
            actions: [
              if (finished)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Đóng'),
                ),
            ],
          );
        },
      ),
    );
    await clean;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: -0.2,
            ),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShizukuStatusCard extends StatelessWidget {
  const _ShizukuStatusCard({required this.provider});

  final FreezerProvider provider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final granted = provider.shizukuStatus == 'granted';
    final denied = provider.shizukuStatus == 'denied';

    final Color statusColor = granted
        ? const Color(0xFF10B981)
        : denied
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    final String title = granted
        ? 'Đã kết nối Shizuku'
        : denied
        ? 'Cần cấp quyền Shizuku'
        : 'Shizuku chưa hoạt động';

    final String description = granted
        ? 'Quyền kiểm soát ứng dụng đã sẵn sàng.'
        : denied
        ? 'Vui lòng cấp quyền truy cập trong bảng thông báo Shizuku.'
        : 'Hãy khởi chạy dịch vụ Shizuku và bấm làm mới.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  granted
                      ? Icons.verified_user_rounded
                      : denied
                      ? Icons.gpp_maybe_rounded
                      : Icons.power_settings_new_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface
                            .withOpacity(0.6),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!granted) ...[
                const SizedBox(width: 8),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: statusColor.withOpacity(0.15),
                    foregroundColor: statusColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      _showShizukuConnectionDialog(context, provider),
                  child: Text(
                    denied ? 'Cấp quyền' : 'Kết nối',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showShizukuConnectionDialog(
    BuildContext context,
    FreezerProvider provider,
  ) async {
    final Future<String> connection = provider.requestShizukuPermission();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return FutureBuilder<String>(
          future: connection,
          builder: (context, snapshot) {
            final bool finished =
                snapshot.connectionState == ConnectionState.done;
            final bool granted = snapshot.data == 'granted';
            if (finished) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(dialogContext).canPop())
                  Navigator.of(dialogContext).pop();
              });
            }
            return AlertDialog(
              icon: Icon(
                granted ? Icons.check_circle_rounded : Icons.sync_rounded,
                color: granted
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
                size: 34,
              ),
              title: Text(finished ? 'Đã kết nối' : 'Đang kết nối Shizuku'),
              content: finished
                  ? const Text('Đang tải danh sách ứng dụng...')
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Vui lòng xác nhận quyền trong Shizuku.'),
                      ],
                    ),
              actions: [
                if (!finished)
                  TextButton(
                    onPressed: () {
                      provider.cancelShizukuConnection();
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Hủy'),
                  ),
              ],
            );
          },
        );
      },
    );
    if (provider.isShizukuGranted) await provider.loadApps();
  }
}
