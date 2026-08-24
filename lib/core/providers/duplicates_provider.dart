// lib/core/providers/duplicates_provider.dart
//
// Riverpod provider that exposes duplicate media groups detected by
// DuplicateDetectorService after each media scan.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the groups of duplicate track IDs found by the last scan.
///
/// Each inner list contains 2+ track IDs that are considered duplicates.
/// Empty list means no duplicates were found (or no scan has run yet).
///
/// Updated by MediaScannerService after each successful scan.
final duplicatesProvider =
    StateProvider<List<List<String>>>((ref) => const []);
