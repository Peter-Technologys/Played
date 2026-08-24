// lib/core/providers/backup_provider.dart
//
// Riverpod provider that tracks the last backup operation status so the
// Profile screen can show a subtle status indicator without polling.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the result of the most recent backup operation.
///
/// - `null`  → no backup has been attempted this session
/// - `AsyncLoading` → backup in progress
/// - `AsyncData(null)` → backup succeeded
/// - `AsyncError` → backup failed (error contains the reason)
///
/// Usage:
///   ref.read(backupStatusProvider.notifier).state = const AsyncLoading();
///   try {
///     await BackupService.instance.backup(...);
///     ref.read(backupStatusProvider.notifier).state = const AsyncData(null);
///   } catch (e) {
///     ref.read(backupStatusProvider.notifier).state = AsyncError(e, StackTrace.current);
///   }
final backupStatusProvider =
    StateProvider<AsyncValue<void>?>((ref) => null);
