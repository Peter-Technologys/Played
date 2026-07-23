import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../../app/theme/app_colors.dart';

/// Shows the remote announcement dialog from /configs/theme.
/// Only shown once per announcement ID — ThemeProvider tracks seen IDs.
///
/// Call [AnnouncementDialog.showIfPending] from app.dart after the first
/// frame so it never blocks startup.
class AnnouncementDialog extends StatelessWidget {
  final OtyaAnnouncement announcement;

  const AnnouncementDialog({super.key, required this.announcement});

  /// Checks ThemeProvider for a pending announcement and shows the dialog
  /// if one exists. Safe to call on every app foreground — the provider
  /// guards against showing the same ID twice.
  static Future<void> showIfPending(BuildContext context) async {
    final pending = await ThemeProvider.instance.pendingAnnouncement();
    if (pending == null) return;
    if (!context.mounted) return;

    await showDialog<void>(
      context:             context,
      barrierDismissible: false,
      builder: (_) => AnnouncementDialog(announcement: pending),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // force user to tap the button
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.accent.withValues(alpha: 0.3),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                announcement.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        content: Text(
          announcement.message,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontFamily: 'Inter',
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await ThemeProvider.instance
                  .markAnnouncementSeen(announcement.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(announcement.buttonText),
          ),
        ],
      ),
    );
  }
}
