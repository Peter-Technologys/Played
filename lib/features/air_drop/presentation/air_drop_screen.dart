import 'package:flutter/material.dart';

import '../../transfer/presentation/transfer_screen.dart';

/// Compatibility wrapper for older code and deep links.
/// User-facing transfer now lives in the unified OTYA Transfer surface.
class AirDropScreen extends StatelessWidget {
  const AirDropScreen({super.key});

  @override
  Widget build(BuildContext context) => const TransferScreen();
}
