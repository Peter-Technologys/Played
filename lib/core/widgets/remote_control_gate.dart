import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openUpdate() async {
    final url = RemoteControlService.instance.link(
      'download',
      'https://petersmartlink.com/download/otya-player',
    );
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final remote = RemoteControlService.instance;
    final version = _version;

    // Offline playback is intentionally preserved when maintenance is for
    // backend services only. A full blocking maintenance page is used only
    // when the remotely supplied policy explicitly disallows offline use.
    if (remote.maintenanceEnabled && !remote.allowOfflinePlayback) {
      return _BlockingPage(
        icon: Icons.construction_rounded,
        title: remote.maintenance['title']?.toString() ?? 'Maintenance',
        message: remote.maintenance['message']?.toString() ??
            'Please try again shortly.',
      );
    }

    if (version?.forceUpdate == true) {
      return _BlockingPage(
        icon: Icons.system_update_alt_rounded,
        title: 'Update required',
        message:
            'This OTYA version is no longer compatible with online services. Update to continue securely.',
        actionLabel: 'Update OTYA',
        onAction: _openUpdate,
      );
    }

    return widget.child;
  }
}

class _BlockingPage extends StatelessWidget {
  const _BlockingPage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
