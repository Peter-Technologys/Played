import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/app_colors.dart';
import '../../core/permissions/permission_helper.dart';

/// Recovery UI shown when Android media permission is unavailable.
///
/// The scanner itself never requests permission because it also runs from
/// background refreshes. This surface keeps the request contextual and
/// user-driven.
class PermissionDeniedScreen extends StatefulWidget {
  final VoidCallback? onRetry;

  const PermissionDeniedScreen({super.key, this.onRetry});

  @override
  State<PermissionDeniedScreen> createState() => _PermissionDeniedScreenState();
}

class _PermissionDeniedScreenState extends State<PermissionDeniedScreen> {
  bool _requesting = false;

  Future<void> _requestMediaAccess() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final granted = await PermissionHelper.showMediaPermissionRationale(context);
      if (!mounted || !granted) return;
      widget.onRetry?.call();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

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
                'Show your media library',
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
                'Otya needs Android media access to discover songs and videos on this phone. You can allow only the media categories you want, and local files are not uploaded just to build your library.',
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
                  onPressed: _requesting ? null : _requestMediaAccess,
                  icon: _requesting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(_requesting ? 'Requesting access…' : 'Allow media access'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _requesting
                    ? null
                    : () {
                        // Do not retry immediately: openAppSettings returns as
                        // Android opens Settings, before the user can change
                        // anything. Music/Video lifecycle refresh runs when the
                        // user comes back to Otya.
                        openAppSettings();
                      },
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Open app settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
