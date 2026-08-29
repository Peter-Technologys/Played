import 'package:flutter/material.dart';

import '../config/environment.dart';
import '../services/apk_downloader.dart';
import '../services/update_service.dart';

/// Single-purpose OTYA update dialog.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info});
  final UpdateInfo info;

  static bool _showing = false;

  static Future<void> checkAndShow(
    BuildContext context, {
    bool forceCheck = false,
  }) async {
    // OTYA has more than one legitimate update trigger (startup, Settings,
    // notification taps). Never let two triggers stack dialogs or race the APK
    // downloader. A manual force-check while a dialog is already visible is a
    // no-op because the visible dialog is already the actionable result.
    if (_showing) return;

    final update = await UpdateService.instance.checkForUpdate(force: forceCheck);
    if (update == null || !context.mounted) {
      if (forceCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'OTYA is up to date, or the update service is unavailable.',
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

  // OTYA does not currently hard-block the whole offline app. Minimum-version
  // policy is enforced at online-service boundaries so local media stays
  // usable. Keep this false until a separate offline-safe forced-update UX is
  // explicitly implemented.
  static bool updateIsMandatory(UpdateInfo info) => false;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double? _progress;
  bool _downloading = false;
  String? _error;

  @override
  void dispose() {
    if (_downloading) ApkDownloader.instance.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    final url = widget.info.directUrl.isNotEmpty
        ? widget.info.directUrl
        : widget.info.downloadUrl.isNotEmpty
            ? widget.info.downloadUrl
            : Environment.downloadUrl;

    await ApkDownloader.instance.downloadAndInstall(
      url: url,
      version: widget.info.version,
      onProgress: (value) {
        if (mounted) setState(() => _progress = value.clamp(0.0, 1.0));
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _progress = null;
          _error = message;
        });
      },
    );

    if (mounted && _downloading) {
      setState(() => _downloading = false);
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
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF7544FF), Color(0xFF11D7FF)],
          ),
        ),
        child: const Icon(
          Icons.system_update_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
      title: Text('OTYA ${widget.info.version} is available'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Installed build ${widget.info.installedCode} · new build ${widget.info.versionCode}',
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
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 7),
              Text(
                _progress == null
                    ? 'Preparing download…'
                    : 'Downloading ${(_progress! * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
          onPressed: _downloading ? null : _later,
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: _downloading ? null : _download,
          icon: Icon(
            _error == null ? Icons.download_rounded : Icons.refresh_rounded,
          ),
          label: Text(_error == null ? 'Update now' : 'Retry'),
        ),
      ],
    );
  }
}
