import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Non-blocking banner ad slot. Renders a clean placeholder area.
/// Replace [adWidget] with a real AdWidget from google_mobile_ads.
class AdBannerSlot extends StatelessWidget {
  /// Pass a real AdWidget here in production.
  final Widget? adWidget;
  final double height;

  const AdBannerSlot({
    super.key,
    this.adWidget,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: adWidget ??
          const Center(
            child: Text(
              'Ad space — non-intrusive',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
          ),
    );
  }
}
