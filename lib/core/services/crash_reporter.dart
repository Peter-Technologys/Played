// lib/core/services/crash_reporter.dart
//
// CrashReporter — captures Flutter and platform errors, stores them locally
// when offline, and uploads them to /api/crash-report when online.
//
// Fire-and-forget safe: all errors are caught and logged, never thrown.

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/environment.dart';
import 'api_signer.dart';
import 'device_service.dart';

class CrashReporter {
  CrashReporter._();
  static final CrashReporter instance = CrashReporter._();

  static const String _kPendingCrashes = 'otya_pending_crashes';
  static const int _maxStoredCrashes = 20;

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Sets up Flutter and platform error handlers, then uploads any crashes
  /// that were stored while the device was offline.
  ///
  /// Call once from main.dart — safe to call multiple times (idempotent via
  /// the existing handler chain).
  Future<void> init() async {
    debugPrint('[CrashReporter] Initialising error handlers…');

    // ── Flutter framework errors ─────────────────────────────────────────────
    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Record the crash first (fire-and-forget).
      recordCrash(
        'FlutterError',
        details.summary.toString(),
        details.stack,
      ).ignore();
      // Then call the original handler (e.g. the debug crash overlay in main.dart).
      if (previousFlutterHandler != null) {
        previousFlutterHandler(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    // ── Platform / isolate errors ────────────────────────────────────────────
    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      // Record the crash first (fire-and-forget).
      recordCrash('PlatformError', error.toString(), stack).ignore();
      // Then call the original handler if one was set.
      if (previousPlatformHandler != null) {
        return previousPlatformHandler(error, stack);
      }
      return true; // mark as handled
    };

    debugPrint('[CrashReporter] Error handlers installed.');

    // Upload any crashes that were stored while offline.
    unawaited(_uploadPendingCrashes());
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Records a crash locally and attempts an immediate upload.
  ///
  /// [errorType]   Short category label, e.g. 'FlutterError', 'PlatformError'.
  /// [description] Human-readable error message.
  /// [stack]       Optional stack trace.
  Future<void> recordCrash(
    String errorType,
    String description,
    StackTrace? stack,
  ) async {
    try {
      debugPrint('[CrashReporter] Recording crash: $errorType');

      final deviceId = await DeviceService.instance.getDeviceId();
      final packageInfo = await PackageInfo.fromPlatform();

      final crash = <String, dynamic>{
        'device_id':    deviceId,
        'app_version':  packageInfo.version,
        'version_code': int.tryParse(packageInfo.buildNumber) ?? 0,
        'error_type':   errorType,
        // Cap description at 500 chars to keep SharedPreferences lean.
        'description':  description.length > 500
            ? description.substring(0, 500)
            : description,
        // Cap stack trace at 1000 chars.
        'stack_trace': stack != null
            ? (stack.toString().length > 1000
                ? stack.toString().substring(0, 1000)
                : stack.toString())
            : '',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Persist locally first so we never lose the crash even if upload fails.
      await _appendToPending(crash);

      // Attempt an immediate upload (fire-and-forget).
      unawaited(_uploadSingle(crash));
    } catch (e) {
      // recordCrash must never throw — swallow everything.
      debugPrint('[CrashReporter] recordCrash internal error (non-fatal): $e');
    }
  }

  /// Convenience method for manual crash reporting from anywhere in the app.
  ///
  /// Example:
  /// ```dart
  /// CrashReporter.reportManual('PaymentError', 'Stripe returned 402');
  /// ```
  static Future<void> reportManual(
    String errorType,
    String description,
  ) async {
    await CrashReporter.instance.recordCrash(errorType, description, null);
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  /// Appends [crash] to the pending list in SharedPreferences, capping at
  /// [_maxStoredCrashes] to avoid filling storage.
  Future<void> _appendToPending(Map<String, dynamic> crash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = _loadPendingFromPrefs(prefs);
      existing.add(crash);
      // Keep only the most recent crashes.
      final trimmed = existing.length > _maxStoredCrashes
          ? existing.sublist(existing.length - _maxStoredCrashes)
          : existing;
      await prefs.setString(_kPendingCrashes, jsonEncode(trimmed));
      debugPrint('[CrashReporter] Pending crashes stored: ${trimmed.length}');
    } catch (e) {
      debugPrint('[CrashReporter] _appendToPending error (non-fatal): $e');
    }
  }

  /// Removes [crash] from the pending list after a successful upload.
  Future<void> _removeFromPending(Map<String, dynamic> crash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = _loadPendingFromPrefs(prefs);
      // Match by timestamp — it is unique per crash.
      existing.removeWhere((c) => c['timestamp'] == crash['timestamp']);
      await prefs.setString(_kPendingCrashes, jsonEncode(existing));
    } catch (e) {
      debugPrint('[CrashReporter] _removeFromPending error (non-fatal): $e');
    }
  }

  /// Decodes the pending crash list from SharedPreferences.
  /// Returns an empty list on any parse failure.
  List<Map<String, dynamic>> _loadPendingFromPrefs(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_kPendingCrashes);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// POSTs a single crash to /api/crash-report.
  /// On success, removes it from the pending list.
  /// On failure, leaves it in the pending list for the next upload attempt.
  /// Never throws.
  Future<void> _uploadSingle(Map<String, dynamic> crash) async {
    try {
      const path = '/api/crash-report';
      final deviceId = (crash['device_id'] as String?) ?? '';

      final headers = {
        ...ApiSigner.signedHeaders(
          method: 'POST',
          path: path,
          deviceId: deviceId,
        ),
        'Content-Type': 'application/json',
      };

      debugPrint('[CrashReporter] Uploading crash (${crash['error_type']})…');

      final response = await http
          .post(
            Uri.parse('${Environment.workerUrl}$path'),
            headers: headers,
            body: jsonEncode(crash),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[CrashReporter] Crash uploaded successfully.');
        await _removeFromPending(crash);
      } else {
        debugPrint(
          '[CrashReporter] Upload returned ${response.statusCode} — '
          'keeping in pending list.',
        );
      }
    } catch (e) {
      // Network failure — crash stays in pending list for next attempt.
      debugPrint('[CrashReporter] _uploadSingle error (non-fatal): $e');
    }
  }

  /// Uploads all pending crashes sequentially with a 500 ms delay between
  /// each to avoid hammering the server.
  Future<void> _uploadPendingCrashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = _loadPendingFromPrefs(prefs);

      if (pending.isEmpty) {
        debugPrint('[CrashReporter] No pending crashes to upload.');
        return;
      }

      debugPrint('[CrashReporter] Uploading ${pending.length} pending crash(es)…');

      for (final crash in pending) {
        await _uploadSingle(crash);
        // Brief pause between uploads to be a good citizen.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      debugPrint('[CrashReporter] Pending crash upload pass complete.');
    } catch (e) {
      debugPrint('[CrashReporter] _uploadPendingCrashes error (non-fatal): $e');
    }
  }
}
