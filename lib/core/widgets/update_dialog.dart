import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/otya_logo.dart';
import '../config/environment.dart';
import '../services/update_service.dart';

/// Single-purpose Otya update dialog.
///
/// Otya intentionally does not install APKs itself. Google Play restricts the
/// REQUEST_INSTALL_PACKAGES permission for self-update use, and local playback
/// must not depend on a privileged installer path. The app checks canonical
/// release metadata, explains the update, and hands the user to the official
/// HTTPS update destination in their browser.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info});
  final UpdateInfo info;

  static bool _showing = false;

  static Future<void> checkAndShow(
    BuildContext context, {
    bool forceCheck = false,
  }) async {
    if (_showing) return;

    final update = await UpdateService.instance.checkForUpdate(force: forceCheck);
    if (update == null || !context.mounted) {
      if (forceCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Otya is up to date, or the update service is unavailable.',
            ),
          ),
        );
      }
      return;
    }

    if (_showing || !context.mounted) return;
    _showing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !updateIsMandatory(update),
        builder: (_) => UpdateDialog(info: update),
      );
    } finally {
      _showing = false;
    }
  }

  // Minimum-version policy is enforced at online-service boundaries. Otya
  // never blocks a user's local media library behind an internet update.
  static bool updateIsMandatory(UpdateInfo info) => false;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  static const _officialHosts = <String>{
    'petersmartlink.com',
    'www.petersmartlink.com',
  };

  bool _opening = false;
  String? _error;

  Future<void> _openOfficialUpdate() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });

    final raw = widget.info.downloadUrl.isNotEmpty
        ? widget.info.downloadUrl
        : widget.info.directUrl.isNotEmpty
            ? widget.info.directUrl
            : Environment.downloadUrl;
    final uri = Uri.tryParse(raw);

    if (uri == null ||
        uri.scheme != 'https' ||
        !_officialHosts.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty) {
      if (mounted) {
        setState(() {
          _opening = false;
          _error = 'Otya could not verify the official update address.';
        });
      }
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() => _error = 'Could not open the official Otya update page.');
      }
      if (opened && mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the official Otya update page.');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _later() async {
    await UpdateService.instance.remindLater(widget.info.versionCode);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notes = widget.info.changelog.trim();

    return AlertDialog(
      icon: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const OtyaMark(size: 46),
      ),
      title: Text('Otya ${widget.info.version} is available'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Installed build ${widget.info.installedCode} · available build ${widget.info.versionCode}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                "What's new",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(notes, style: const TextStyle(height: 1.45)),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Otya will open the official PeterSmart Link update destination. '
              'The app does not silently install packages or require installer permission.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _opening ? null : _later,
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: _opening ? null : _openOfficialUpdate,
          icon: _opening
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.open_in_new_rounded),
          label: Text(_opening ? 'Opening…' : 'Update'),
        ),
      ],
    );
  }
}
