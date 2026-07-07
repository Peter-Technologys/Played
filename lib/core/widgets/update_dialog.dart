import 'package:flutter/material.dart';
import '../services/apk_downloader.dart';
import '../services/feedback_service.dart';
import '../services/update_service.dart';

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
              'Tap “Update Now” — we will download the right file for your phone automatically.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
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
            if (_downloading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: purple.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(purple),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _progress != null
                    ? 'Downloading… ${(_progress! * 100).toStringAsFixed(0)}%'
                    : 'Preparing…',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _startDownload,
                icon: _downloading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(_downloading ? 'Downloading…' : 'Update Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _FeedbackButton(
                  icon: Icons.star_rounded,
                  label: 'Rate Us',
                  color: const Color(0xFFFFC107),
                  onTap: () => FeedbackService.instance.rateApp(),
                ),
                _FeedbackButton(
                  icon: Icons.bug_report_rounded,
                  label: 'Report Problem',
                  color: Colors.redAccent,
                  onTap: () => _showReportSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ReportSheet(),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _FeedbackButton({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report a Problem',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Describe what went wrong. We will reply on WhatsApp.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'e.g. The app crashes when I open a video…',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : () async {
                if (_controller.text.trim().isEmpty) return;
                setState(() => _sending = true);
                await FeedbackService.instance.submitReport(
                  description: _controller.text.trim(),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send via WhatsApp'),
            ),
          ),
        ],
      ),
    );
  }
}
