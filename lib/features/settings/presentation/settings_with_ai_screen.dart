import 'package:flutter/material.dart';

import 'settings_detail_screen.dart';

/// Compatibility route wrapper. Settings owns its own support entry now, so
/// this wrapper no longer layers another floating control over the screen.
class SettingsWithAiScreen extends StatelessWidget {
  const SettingsWithAiScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsDetailScreen();
}
