import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../services/remote_control_service.dart';
import '../../app/theme/app_colors.dart';

class AnnouncementDialog extends StatelessWidget {
  final String id;
  final String title;
  final String message;
  final String buttonText;
  final bool remoteControl;

  const AnnouncementDialog({
    super.key,
    required this.id,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.remoteControl,
  });

  static Future<void> showIfPending(BuildContext context) async {
    final remote = await RemoteControlService.instance.pendingAnnouncement();
    if (remote != null && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AnnouncementDialog(
          id: remote['id']?.toString() ?? 'remote',
          title: remote['title']?.toString() ?? 'OTYA',
          message: remote['message']?.toString() ?? '',
          buttonText: remote['buttonText']?.toString() ?? 'Got it',
          remoteControl: true,
        ),
      );
      return;
    }

    final legacy = await ThemeProvider.instance.pendingAnnouncement();
    if (legacy == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AnnouncementDialog(
        id: legacy.id,
        title: legacy.title,
        message: legacy.message,
        buttonText: legacy.buttonText,
        remoteControl: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Inter')),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Inter', height: 1.5)),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (remoteControl) {
                await RemoteControlService.instance.markAnnouncementSeen(id);
              } else {
                await ThemeProvider.instance.markAnnouncementSeen(id);
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
