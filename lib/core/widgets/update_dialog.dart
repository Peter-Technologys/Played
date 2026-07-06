import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

/// Shows a friendly update dialog in plain language.
/// No technical terms — any user can understand it.
class UpdateDialog extends StatelessWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  /// Call this from your app startup to show the dialog if an update exists.
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
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2BE2), Color(0xFF00BFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'New version available! 🎉',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Plain-language message
            Text(
              'A newer version of OTYA Player (v${info.latestVersion}) '
              'is ready for you.\n\n'
              'Tap "Update Now" and we will open the download page. '
              'Your phone will automatically get the right file — '
              'you do not need to choose anything.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            if (info.releaseDate.isNotEmpty) ...[  
              const SizedBox(height: 8),
              Text(
                'Released: ${info.releaseDate}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],

            const SizedBox(height: 24),

            // Update button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final uri = Uri.parse(info.downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A2BE2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Update Now',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Remind later button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await UpdateService.instance
                      .remindLater(info.latestVersion);
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Remind me later',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
