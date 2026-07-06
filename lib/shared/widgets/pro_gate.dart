// ADS DISABLED — ProGate passes straight through to child until Play Store launch.
// Original rewarded-ad paywall preserved in git history (chore/remove-ads-until-play-store).
// To re-enable: restore original file and uncomment google_mobile_ads in pubspec.yaml.
import 'package:flutter/material.dart';

/// Wraps any Pro-only feature.
/// While ads are disabled, all Pro features are freely accessible.
class ProGate extends StatelessWidget {
  final Widget child;
  final String featureName;
  final String? featureDescription;

  const ProGate({
    super.key,
    required this.child,
    required this.featureName,
    this.featureDescription,
  });

  @override
  Widget build(BuildContext context) => child;
}
