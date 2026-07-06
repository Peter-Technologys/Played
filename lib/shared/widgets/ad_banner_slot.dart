// ADS DISABLED — re-enable when listed on Play Store.
// Original implementation preserved below as comments.
import 'package:flutter/material.dart';

/// No-op ad banner slot — collapses to nothing while ads are disabled.
/// To re-enable: uncomment google_mobile_ads in pubspec.yaml and restore
/// the original implementation from git history (chore/remove-ads-until-play-store).
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
