import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/auth_provider.dart';

/// Profile avatar shown in the My Space header top-right.
/// - Signed in: purple/blue gradient circle with initials.
/// - Signed out: grey person icon.
/// Tapping always opens Settings.
class UserAvatarButton extends ConsumerWidget {
  const UserAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final displayName = ref.watch(displayNameProvider);
    final initials = _initials(isSignedIn ? displayName : null);
    final tooltip = isSignedIn && displayName.trim().isNotEmpty
        ? 'Open settings for $displayName'
        : 'Open settings';

    return IconButton(
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: const EdgeInsets.all(5),
      onPressed: () => context.push('/settings'),
      icon: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isSignedIn
              ? const LinearGradient(
                  colors: [Color(0xFF8A2BE2), Color(0xFF00BFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSignedIn ? null : AppColors.surface,
          border: Border.all(
            color: isSignedIn ? const Color(0xFF8A2BE2) : AppColors.border,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: isSignedIn && initials.isNotEmpty
            ? Text(
                initials,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.person_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
