import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/theme/app_colors.dart';

/// Recovery UI shown when Android media permission is denied.
class PermissionDeniedScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const PermissionDeniedScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.video_library_rounded,
                  color: AppColors.accent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Allow media access',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'OTYA needs Android media permission to discover songs and videos on this phone. Your local files are not uploaded just to build your library.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () async {
                    await openAppSettings();
                    onRetry?.call();
                  },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Open app settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
