import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import 'settings_detail_screen.dart';

/// Keeps OTYA Player media-first while making AI an optional helper from Settings.
class SettingsWithAiScreen extends StatelessWidget {
  const SettingsWithAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const SettingsDetailScreen(),
        Positioned(
          right: 14,
          bottom: MediaQuery.paddingOf(context).bottom + 14,
          child: SafeArea(
            top: false,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.borderOf(context)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/ai'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_outlined,
                        color: AppColors.accent,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'OTYA AI',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
