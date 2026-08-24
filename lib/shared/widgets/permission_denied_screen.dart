import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/theme/app_colors.dart';

/// Full-screen recovery UI shown when storage permission is denied.
///
/// Displays a large storage icon, an explanation, and a gradient button
/// that opens the app's system settings page so the user can grant access.
class PermissionDeniedScreen extends StatelessWidget {
  /// Optional callback invoked after the user returns from settings.
  /// Typically used to trigger a library refresh.
  final VoidCallback? onRetry;

  const PermissionDeniedScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Storage icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storage_rounded,
                color: AppColors.accent,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Storage Access Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            // Explanation
            const Text(
              'OTYA Player needs access to your device storage to find and play '
              'your music and videos. Please grant storage permission in '
              'Settings to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            // Grant Permission button
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentViolet],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await openAppSettings();
                    onRetry?.call();
                  },
                  icon: const Icon(Icons.settings_rounded,
                      color: Colors.black, size: 18),
                  label: const Text(
                    'Grant Permission',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'Inter',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
