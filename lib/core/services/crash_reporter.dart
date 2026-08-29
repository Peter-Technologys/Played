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
import 'firebase_platform_service.dart';

class CrashReporter {
  CrashReporter._();
  static final CrashReporter instance = CrashReporter._();

  static const String _kPendingCrashes = 'otya_pending_crashes';
  static const int _maxStoredCrashes = 20;

  Future<void> init() async {
    debugPrint('[CrashReporter] Initialising error handlers…');
    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      recordCrash('FlutterError', details.summary.toString(), details.stack).ignore();
      if (previousFlutterHandler != null) {
        previousFlutterHandler(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordCrash('PlatformError', error.toString(), stack).ignore();
      if (previousPlatformHandler != null) {
        return previousPlatformHandler(error, stack);
      }
      return true;
    };

    debugPrint('[CrashReporter] Error handlers installed.');
    unawaited(_uploadPendingCrashes());
  }

  Future<void> recordCrash(
    String errorType,
    String description,
    StackTrace? stack,
  ) async {
    try {
      final deviceId = await DeviceService.instance.getDeviceId();
      final packageInfo = await PackageInfo.fromPlatform();
      final crash = <String, dynamic>{
        'device_id': deviceId,
        'app_version': packageInfo.version,
        'version_code': int.tryParse(packageInfo.buildNumber) ?? 0,
        'error_type': errorType,
        'description': description.length > 500
            ? description.substring(0, 500)
            : description,
        'stack_trace': stack != null
            ? (stack.toString().length > 1000
                ? stack.toString().substring(0, 1000)
                : stack.toString())
            : '',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _appendToPending(crash);
      unawaited(_uploadSingle(crash));
    } catch (e) {
      debugPrint('[CrashReporter] recordCrash internal error (non-fatal): $e');
    }
  }

  static Future<void> reportManual(String errorType, String description) async {
    await CrashReporter.instance.recordCrash(errorType, description, null);
  }

  void report(Object error, StackTrace stack) {
    recordCrash(error.runtimeType.toString(), error.toString(), stack).ignore();
  }

  Future<void> _appendToPending(Map<String, dynamic> crash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = _loadPendingFromPrefs(prefs)..add(crash);
      final trimmed = existing.length > _maxStoredCrashes
          ? existing.sublist(existing.length - _maxStoredCrashes)
          : existing;
      await prefs.setString(_kPendingCrashes, jsonEncode(trimmed));
    } catch (e) {
      debugPrint('[CrashReporter] _appendToPending error (non-fatal): $e');
    }
  }

  Future<void> _removeFromPending(Map<String, dynamic> crash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = _loadPendingFromPrefs(prefs);
      existing.removeWhere((c) => c['timestamp'] == crash['timestamp']);
      await prefs.setString(_kPendingCrashes, jsonEncode(existing));
    } catch (e) {
      debugPrint('[CrashReporter] _removeFromPending error (non-fatal): $e');
    }
  }

  List<Map<String, dynamic>> _loadPendingFromPrefs(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_kPendingCrashes);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _uploadSingle(Map<String, dynamic> crash) async {
    try {
      const path = '/api/crash-report';
      final deviceId = (crash['device_id'] as String?) ?? '';
      final headers = await FirebasePlatformService.instance.protectedHeaders(
        base: {
          ...ApiSigner.signedHeaders(
            method: 'POST',
            path: path,
            deviceId: deviceId,
          ),
          'Content-Type': 'application/json',
        },
      );
      final response = await http
          .post(
            Uri.parse('${Environment.workerUrl}$path'),
            headers: headers,
            body: jsonEncode(crash),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _removeFromPending(crash);
      }
    } catch (e) {
      debugPrint('[CrashReporter] _uploadSingle error (non-fatal): $e');
    }
  }

  Future<void> _uploadPendingCrashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = _loadPendingFromPrefs(prefs);
      for (final crash in pending) {
        await _uploadSingle(crash);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('[CrashReporter] _uploadPendingCrashes error (non-fatal): $e');
    }
  }
}
