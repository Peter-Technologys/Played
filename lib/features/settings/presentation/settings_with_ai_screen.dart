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
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 18,
          child: SafeArea(
            top: false,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/ai'),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF11D7FF), Color(0xFF7544FF), Color(0xFFFF2CAA)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: .22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 7),
                      Text(
                        'Ask OTYA',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
