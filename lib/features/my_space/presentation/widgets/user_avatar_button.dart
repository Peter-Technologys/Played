import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/auth_provider.dart';

/// Small avatar shown in the My Space header when the user is signed in.
/// Tapping it navigates to Settings.
class UserAvatarButton extends ConsumerWidget {
  const UserAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoUrl = ref.watch(photoUrlProvider);
    final displayName = ref.watch(displayNameProvider);
    final isGoogle = ref.watch(isGoogleSignedInProvider);

    // Only show avatar when signed in with Google
    if (!isGoogle) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/settings'),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 2),
          color: AppColors.surface,
        ),
        child: ClipOval(
          child: photoUrl != null
              ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _Initials(name: displayName),
                  errorWidget: (_, __, ___) => _Initials(name: displayName),
                )
              : _Initials(name: displayName),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String? name;
  const _Initials({this.name});

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    return Container(
      color: AppColors.accentViolet.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
