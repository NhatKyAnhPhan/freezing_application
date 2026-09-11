import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/models/app_model.dart';
import '../data/services/shizuku_service.dart';

class FreezerProvider extends ChangeNotifier {
  FreezerProvider({ShizukuService? service}) : _service = service ?? const ShizukuService();

  final ShizukuService _service;
  List<AppModel> _apps = const [];
  bool _isLoading = false;
  String? _errorMessage;
  String _shizukuStatus = 'unavailable';

  List<AppModel> get apps => List.unmodifiable(_apps);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get shizukuStatus => _shizukuStatus;
  bool get isShizukuGranted => _shizukuStatus == 'granted';

  Future<void> refreshShizukuStatus() async {
    try {
      _shizukuStatus = await _service.getStatus();
    } on MissingPluginException {
      _shizukuStatus = 'unavailable';
    } on PlatformException {
      _shizukuStatus = 'unavailable';
    }
    notifyListeners();
  }

  Future<void> requestShizukuPermission() async {
    try {
      _shizukuStatus = await _service.requestPermission();
    } on PlatformException {
      _shizukuStatus = 'unavailable';
    } on MissingPluginException {
      _shizukuStatus = 'unavailable';
    }
    notifyListeners();
  }

  Future<void> loadApps() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _shizukuStatus = await _service.getStatus();
      if (!isShizukuGranted) {
        _errorMessage = _shizukuStatus == 'denied'
            ? 'Shizuku permission is required.'
            : 'Install and start Shizuku first.';
        return;
      }
      _apps = await _service.getInstalledApps();
    } on PlatformException catch (error) {
      _errorMessage = error.message ?? 'Unable to connect to Shizuku.';
    } on MissingPluginException {
      _errorMessage = 'Native Shizuku service is not connected yet.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFrozen(AppModel app) async {
    final success = await _service.setFrozen(app.packageName, frozen: !app.isFrozen);
    if (!success) return;
    _apps = [
      for (final item in _apps)
        item.packageName == app.packageName ? item.copyWith(isFrozen: !app.isFrozen) : item,
    ];
    notifyListeners();
  }
}

class FreezerProviderScope extends StatefulWidget {
  const FreezerProviderScope({required this.child, super.key});

  final Widget child;

  static FreezerProvider of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<_FreezerInherited>();
    assert(inherited != null, 'FreezerProviderScope is missing above this context.');
    return inherited!.provider;
  }

  @override
  State<FreezerProviderScope> createState() => _FreezerProviderScopeState();
}

class _FreezerProviderScopeState extends State<FreezerProviderScope> {
  late final FreezerProvider provider = FreezerProvider();

  @override
  void dispose() {
    provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, child) => _FreezerInherited(provider: provider, child: child!),
      child: widget.child,
    );
  }
}

class _FreezerInherited extends InheritedWidget {
  const _FreezerInherited({required this.provider, required super.child});

  final FreezerProvider provider;

  @override
  bool updateShouldNotify(_FreezerInherited oldWidget) => provider != oldWidget.provider;
}