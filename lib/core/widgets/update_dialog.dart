import 'package:flutter/material.dart';
import '../services/apk_downloader.dart';
import '../services/update_service.dart';
import 'rate_us_sheet.dart';
import 'report_problem_sheet.dart';

/// In-app update dialog with download progress, Rate Us, and Report Problem.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  static Future<void> checkAndShow(BuildContext context) async {
    final update = await UpdateService.instance.checkForUpdate();
    if (update == null) return;
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: update),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double? _progress;
  bool    _downloading = false;
  String? _error;

  @override
  void dispose() {
    if (_downloading) ApkDownloader.instance.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _progress = 0.0; _error = null; });
    await ApkDownloader.instance.downloadAndInstall(
      url:     widget.info.directUrl,
      version: widget.info.version,
      onProgress: (p) { if (mounted) setState(() => _progress = p); },
      onError: (msg) {
        if (mounted) setState(() {
          _downloading = false; _progress = null; _error = msg;
        });
      },
    );
    if (mounted && _downloading) Navigator.of(context).pop();
  }

  Future<void> _later() async {
    await UpdateService.instance.remindLater(widget.info.versionCode);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final changelog = widget.info.changelog.trim();
    const purple    = Color(0xFF8A2BE2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2BE2), Color(0xFF00BFFF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text('New version available! 🎉',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'OTYA Player v${widget.info.version} is ready.\n'
              'Tap "Update Now" — we will download the right file for your phone automatically.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),

            // Changelog
            if (changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("What's new",
                    style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Colors.grey[500])),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Text(changelog,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(height: 1.5, color: Colors.grey[700])),
                ),
              ),
            ],

            // Progress bar
            if (_downloading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: purple.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(purple),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _progress != null
                    ? 'Downloading… ${(_progress! * 100).toStringAsFixed(0)}%'
                    : 'Starting download…',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey[500]),
              ),
            ],

            // Error box with retry
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: theme.colorScheme.onErrorContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Download / Retry button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _startDownload,
                icon: _downloading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        _error != null
                            ? Icons.refresh_rounded
                            : Icons.download_rounded,
                        size: 18),
                label: Text(
                  _downloading
                      ? 'Downloading…'
                      : _error != null ? 'Retry' : 'Update Now',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Remind later
            if (!_downloading)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _later,
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: const Text('Remind me later'),
                ),
              ),

            const Divider(height: 24),

            // Rate Us / Report Problem
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => RateUsSheet.show(context),
                  icon: const Icon(Icons.star_rounded,
                      color: Color(0xFFFFC107), size: 18),
                  label: const Text('Rate Us',
                      style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter', fontSize: 13)),
                ),
                TextButton.icon(
                  onPressed: () => ReportProblemSheet.show(context),
                  icon: const Icon(Icons.bug_report_rounded,
                      color: Colors.redAccent, size: 18),
                  label: const Text('Report Problem',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter', fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
