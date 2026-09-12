import 'package:flutter/material.dart';

import '../../data/models/app_model.dart';

class AppTile extends StatelessWidget {
  const AppTile({required this.app, required this.onToggle, this.isProcessing = false, super.key});

  final AppModel app;
  final VoidCallback onToggle;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage: app.iconBytes == null ? null : MemoryImage(app.iconBytes!),
        child: app.iconBytes == null ? const Icon(Icons.apps) : null,
      ),
      title: Text(app.name),
      subtitle: Text(app.packageName),
        trailing: isProcessing
          ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
          : _FreezeButton(app: app, onPressed: onToggle),
    );
  }
}

class _FreezeButton extends StatelessWidget {
  const _FreezeButton({required this.app, required this.onPressed});

  final AppModel app;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color active = const Color(0xFF9A7415);
    return Semantics(
      button: true,
      label: app.isFrozen ? 'Rã đông ứng dụng' : 'Đóng băng ứng dụng',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 72,
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: app.isFrozen ? active : const Color(0xFFECE9DF),
            borderRadius: BorderRadius.circular(22),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: app.isFrozen ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}