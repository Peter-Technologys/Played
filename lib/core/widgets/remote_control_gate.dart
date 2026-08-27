import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../services/remote_control_service.dart';

class RemoteControlGate extends StatefulWidget {
  const RemoteControlGate({super.key, required this.child});
  final Widget child;

  @override
  State<RemoteControlGate> createState() => _RemoteControlGateState();
}

class _RemoteControlGateState extends State<RemoteControlGate> {
  RemoteVersionState? _version;

  @override
  void initState() {
    super.initState();
    RemoteControlService.instance.addListener(_changed);
    _refreshVersion();
  }

  @override
  void dispose() {
    RemoteControlService.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() => _refreshVersion();

  Future<void> _refreshVersion() async {
    final value = await RemoteControlService.instance.versionState();
    if (mounted) setState(() => _version = value);
  }

  @override
  Widget build(BuildContext context) {
    final remote = RemoteControlService.instance;
    final version = _version;

    if (remote.maintenanceEnabled && !remote.allowOfflinePlayback) {
      return _BlockingPage(
        icon: Icons.construction_rounded,
        title: remote.maintenance['title']?.toString() ?? 'Maintenance',
        message: remote.maintenance['message']?.toString() ?? 'Please try again shortly.',
      );
    }

    if (version?.forceUpdate == true) {
      return const _BlockingPage(
        icon: Icons.system_update_alt_rounded,
        title: 'Update required',
        message: 'This version of OTYA is no longer compatible with online services. Update OTYA to continue.',
      );
    }

    return widget.child;
  }
}

class _BlockingPage extends StatelessWidget {
  const _BlockingPage({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF08080B),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: AppColors.accent),
                const SizedBox(height: 18),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
