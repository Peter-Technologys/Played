import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../config/environment.dart';
import 'api_signer.dart';
import 'apk_downloader.dart';
import 'push_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OtyaService
//
// Single-responsibility service that bridges the Flutter app with the
// Cloudflare Worker backend at petersmartlink.com.
//
// Three responsibilities:
//   1. fetchOtaTheme()              — ETag-aware remote theme with local fallback
//   2. checkAppUpdate()             — build-number comparison + update modal
//   3. registerDevicePushToken()    — FCM token registration
//
// All network calls are fire-and-forget safe: every error is caught, logged
// with debugPrint, and the app continues with a sensible default.
// ─────────────────────────────────────────────────────────────────────────────
class OtyaService {
  OtyaService._();
  static final OtyaService instance = OtyaService._();

  // ── SharedPreferences keys ────────────────────────────────────────────────
  static const String _keyThemeJson  = 'otya_remote_theme_json';
  static const String _keyThemeEtag  = 'otya_remote_theme_etag';
  static const String _keyLastUpdate = 'otya_update_last_check';

  // ── Worker endpoints ──────────────────────────────────────────────────────
  static String get _themeUrl        => '${Environment.workerUrl}/api/theme';
  static String get _checkUpdateUrl  => '${Environment.workerUrl}/check-update';
  static String get _registerUrl     => '${Environment.workerUrl}/register-device';

  // ── Concurrency guards ────────────────────────────────────────────────────
  bool _themeFetchInProgress  = false;
  bool _updateCheckInProgress = false;

  // ── Resolved dynamic theme (null = use static AppTheme) ──────────────────
  OtyaRemoteTheme? _activeRemoteTheme;
  OtyaRemoteTheme? get activeRemoteTheme => _activeRemoteTheme;

  // PERFORMANCE 2: Use LinkedHashSet to prevent duplicate listener
  // registrations — a plain List grows unboundedly if addThemeListener is
  // called multiple times with the same callback (e.g. on hot-restart or
  // widget rebuild without a matching removeThemeListener call).
  final _themeListeners = LinkedHashSet<VoidCallback>();
  void addThemeListener(VoidCallback cb)    => _themeListeners.add(cb);
  void removeThemeListener(VoidCallback cb) => _themeListeners.remove(cb);
  void _notifyThemeListeners() {
    for (final cb in _themeListeners) {
      cb();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. fetchOtaTheme
  //
  // Sends the stored ETag so the Worker can return 304 Not Modified when
  // nothing has changed — saving bandwidth and avoiding unnecessary repaints.
  //
  // Flow:
  //   • 304  → decode cached JSON, apply, notify listeners
  //   • 200  → store new ETag + JSON, apply, notify listeners
  //   • any error → silently apply cached JSON (or built-in fallback)
  //
  // Safe to call on app startup — never throws.
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> fetchOtaTheme() async {
    if (_themeFetchInProgress) return;
    _themeFetchInProgress = true;
    try {
      await _doFetchOtaTheme();
    } catch (e) {
      debugPrint('[OtyaService] fetchOtaTheme unexpected error: $e');
      await _applyFallbackTheme();
    } finally {
      _themeFetchInProgress = false;
    }
  }

  Future<void> _doFetchOtaTheme() async {
    final prefs   = await SharedPreferences.getInstance();
    final etag    = prefs.getString(_keyThemeEtag);
    final cached  = prefs.getString(_keyThemeJson);

    final url = Uri.parse(_themeUrl);
    final signedPath = '/api/theme';
    final headers = <String, String>{
      ...ApiSigner.signedHeaders(method: 'GET', path: signedPath),
      if (etag != null) 'If-None-Match': etag,
    };

    http.Response? response;
    try {
      response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[OtyaService] Theme network error: $e — using cached/fallback.');
      await _applyThemeFromJson(cached);
      return;
    }

    if (response.statusCode == 304) {
      // Server confirmed nothing changed — use what we already have.
      debugPrint('[OtyaService] Theme 304 Not Modified — using cache.');
      await _applyThemeFromJson(cached);
      return;
    }

    if (response.statusCode == 200) {
      final newEtag = response.headers['etag'];
      final body    = response.body;

      // Validate JSON before persisting.
      try {
        jsonDecode(body); // throws if malformed
      } catch (_) {
        debugPrint('[OtyaService] Theme response is not valid JSON — ignoring.');
        await _applyThemeFromJson(cached);
        return;
      }

      await prefs.setString(_keyThemeJson, body);
      if (newEtag != null) await prefs.setString(_keyThemeEtag, newEtag);

      debugPrint('[OtyaService] Theme updated (ETag: $newEtag).');
      await _applyThemeFromJson(body);
      return;
    }

    // Any other status (4xx / 5xx) — fall back gracefully.
    debugPrint('[OtyaService] Theme fetch returned ${response.statusCode} — using fallback.');
    await _applyThemeFromJson(cached);
  }

  /// Parses [json] into [OtyaRemoteTheme] and notifies listeners.
  /// Falls back to [_applyFallbackTheme] if [json] is null or unparseable.
  Future<void> _applyThemeFromJson(String? json) async {
    if (json == null) {
      await _applyFallbackTheme();
      return;
    }
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      _activeRemoteTheme = OtyaRemoteTheme.fromJson(map);
      _notifyThemeListeners();
      debugPrint('[OtyaService] Remote theme applied: ${_activeRemoteTheme!.label}');
    } catch (e) {
      debugPrint('[OtyaService] Theme parse error: $e — using fallback.');
      await _applyFallbackTheme();
    }
  }

  /// Applies the built-in AppColors palette as the safe fallback theme.
  Future<void> _applyFallbackTheme() async {
    _activeRemoteTheme = OtyaRemoteTheme.fallback();
    _notifyThemeListeners();
    debugPrint('[OtyaService] Fallback theme applied.');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. checkAppUpdate
  //
  // Compares the installed build number (from package_info_plus) against
  // the Worker's `build_number` field.
  //
  // If an update is available, shows a branded AlertDialog:
  //   • force_update = true  → barrierDismissible: false, no "Later" button
  //   • force_update = false → user can dismiss
  //
  // The download button opens `download_url` via url_launcher.
  // Throttled to once per 24 h unless [force] is true.
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> checkAppUpdate(
    BuildContext context, {
    bool force = false,
  }) async {
    if (_updateCheckInProgress) return;
    _updateCheckInProgress = true;
    try {
      await _doCheckAppUpdate(context, force: force);
    } catch (e) {
      debugPrint('[OtyaService] checkAppUpdate unexpected error: $e');
    } finally {
      _updateCheckInProgress = false;
    }
  }

  Future<void> _doCheckAppUpdate(
    BuildContext context, {
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Throttle — skip if checked within the last 24 h and not forced.
    if (!force) {
      final lastCheck = prefs.getInt(_keyLastUpdate) ?? 0;
      final elapsed   = DateTime.now().millisecondsSinceEpoch - lastCheck;
      if (elapsed < const Duration(hours: 24).inMilliseconds) {
        debugPrint('[OtyaService] Update check skipped — within 24 h window.');
        return;
      }
    }

    final checkUpdateUri = Uri.parse(_checkUpdateUrl);
    final checkUpdateHeaders = ApiSigner.signedHeaders(
      method: 'GET',
      path: checkUpdateUri.path,
    );
    http.Response? response;
    try {
      response = await http
          .get(checkUpdateUri, headers: checkUpdateHeaders)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[OtyaService] Update check network error: $e');
      return;
    }

    if (response.statusCode != 200) {
      debugPrint('[OtyaService] Update check returned ${response.statusCode}.');
      return;
    }

    // Record the time we successfully checked.
    await prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('[OtyaService] Update response is not valid JSON.');
      return;
    }

    final remoteBuild  = (data['build_number'] as num?)?.toInt() ?? 0;
    final forceUpdate  = (data['force_update']  as bool?) ?? false;
    final releaseNotes = (data['release_notes'] as String?) ?? 'Bug fixes and improvements.';
    final downloadUrl  = (data['download_url']  as String?) ?? Environment.downloadUrl;

    if (remoteBuild == 0) {
      debugPrint('[OtyaService] Remote build_number missing or zero — skipping.');
      return;
    }

    final packageInfo    = await PackageInfo.fromPlatform();
    final installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    debugPrint('[OtyaService] Installed build: $installedBuild  Remote: $remoteBuild');

    if (remoteBuild <= installedBuild) {
      debugPrint('[OtyaService] App is up to date.');
      return;
    }

    // Guard: context may have been disposed while we awaited network.
    if (!context.mounted) return;

    _showUpdateDialog(
      context,
      releaseNotes: releaseNotes,
      downloadUrl:  downloadUrl,
      forceUpdate:  forceUpdate,
      remoteBuild:  remoteBuild,
    );
  }

  void _showUpdateDialog(
    BuildContext context, {
    required String releaseNotes,
    required String downloadUrl,
    required bool   forceUpdate,
    required int    remoteBuild,
  }) {
    showDialog<void>(
      context:             context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => _UpdateDialog(
        releaseNotes: releaseNotes,
        downloadUrl:  downloadUrl,
        forceUpdate:  forceUpdate,
        remoteBuild:  remoteBuild,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. registerDevicePushToken
  //
  // POSTs { deviceId, fcmToken } to /register-device.
  // Non-blocking — failures are logged but never surfaced to the user.
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> registerDevicePushToken({
    required String deviceId,
    required String fcmToken,
  }) async {
    try {
      final registerUri = Uri.parse(_registerUrl);
      final registerHeaders = {
        ...ApiSigner.signedHeaders(
          method: 'POST',
          path: registerUri.path,
          deviceId: deviceId,
        ),
        'Content-Type': 'application/json',
      };
      final response = await http
          .post(
            registerUri,
            headers: registerHeaders,
            body: jsonEncode({
              'deviceId': deviceId,
              'fcmToken': fcmToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[OtyaService] Push token registered for device $deviceId.');
      } else {
        debugPrint(
          '[OtyaService] registerDevicePushToken returned '
          '${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      // Non-fatal — push notifications degrade gracefully.
      debugPrint('[OtyaService] registerDevicePushToken failed (non-fatal): $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OtyaRemoteTheme
//
// Parsed representation of the Worker's /configs/theme response.
// Every field has a safe default drawn from AppColors so the app never
// renders with missing colours even if the Worker omits a field.
//
// Expected Worker JSON shape:
// {
//   "label":           "Midnight Cyan",
//   "accent":          "#00E5FF",
//   "accentSecondary": "#8B5CF6",
//   "background":      "#0F1117",
//   "surface":         "#161B27",
//   "textPrimary":     "#F0F6FF",
//   "textSecondary":   "#8BA3C7",
//   "cardRadius":      24.0,
//   "buttonRadius":    14.0
// }
// ─────────────────────────────────────────────────────────────────────────────
class OtyaRemoteTheme {
  final String label;
  final Color  accent;
  final Color  accentSecondary;
  final Color  background;
  final Color  surface;
  final Color  textPrimary;
  final Color  textSecondary;
  final double cardRadius;
  final double buttonRadius;

  const OtyaRemoteTheme({
    required this.label,
    required this.accent,
    required this.accentSecondary,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardRadius,
    required this.buttonRadius,
  });

  /// Parses a Worker JSON map. Supports both the V2 schema (nested `colors`
  /// object with snake_case keys) and the legacy flat schema for backwards
  /// compatibility. Any missing / malformed field falls back to the
  /// corresponding AppColors constant so the app always has valid colours.
  factory OtyaRemoteTheme.fromJson(Map<String, dynamic> json) {
    final colors = (json['colors'] as Map<String, dynamic>?) ?? {};
    return OtyaRemoteTheme(
      label:           (json['theme_identity'] as String?) ?? (json['label'] as String?) ?? 'Remote Theme',
      accent:          _parseColor(colors['primary'] ?? json['accent'], AppColors.accent),
      accentSecondary: _parseColor(colors['secondary'] ?? json['accentSecondary'], AppColors.accentViolet),
      background:      _parseColor(colors['scaffold_background'] ?? json['background'], AppColors.background),
      surface:         _parseColor(colors['surface'] ?? json['surface'], AppColors.surface),
      textPrimary:     _parseColor(colors['text_primary'] ?? json['textPrimary'], AppColors.textPrimary),
      textSecondary:   _parseColor(colors['text_secondary'] ?? json['textSecondary'], AppColors.textSecondary),
      cardRadius:      (json['card_border_radius'] as num?)?.toDouble() ?? (json['cardRadius'] as num?)?.toDouble() ?? 24.0,
      buttonRadius:    (json['button_padding'] as num?)?.toDouble() ?? (json['buttonRadius'] as num?)?.toDouble() ?? 14.0,
    );
  }

  /// Returns a theme that exactly mirrors the static AppColors palette.
  /// Used when the network is unavailable and no cache exists.
  factory OtyaRemoteTheme.fallback() {
    return const OtyaRemoteTheme(
      label:           'Default',
      accent:          AppColors.accent,
      accentSecondary: AppColors.accentViolet,
      background:      AppColors.background,
      surface:         AppColors.surface,
      textPrimary:     AppColors.textPrimary,
      textSecondary:   AppColors.textSecondary,
      cardRadius:      24.0,
      buttonRadius:    14.0,
    );
  }

  /// Converts this remote theme into a full [ThemeData] that can be passed
  /// directly to [MaterialApp.theme]. Inherits all component shapes from
  /// AppTheme.dark and overrides only the dynamic fields.
  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness:   Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.dark(
        primary:   accent,
        secondary: accentSecondary,
        surface:   surface,
        error:     AppColors.error,
        onPrimary:   Colors.black,
        onSecondary: Colors.white,
        onSurface:   textPrimary,
        surfaceContainerHighest: surface,
      ),
      // Preserve all branded component themes from AppTheme.dark.
      sliderTheme: SliderThemeData(
        trackHeight:        4,
        activeTrackColor:   accent,
        inactiveTrackColor: AppColors.border,
        thumbColor:         accent,
        overlayColor:       accent.withValues(alpha: 0.2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      cardTheme: CardThemeData(
        color:     surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border, thickness: 1, space: 0,
      ),
      splashColor:    accent.withValues(alpha: 0.06),
      highlightColor: accent.withValues(alpha: 0.04),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Parses a CSS hex colour string (#RRGGBB or #AARRGGBB).
  /// Returns [fallback] on any parse failure.
  static Color _parseColor(dynamic raw, Color fallback) {
    if (raw is! String) return fallback;
    final hex = raw.trim().replaceFirst('#', '');
    try {
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
      if (hex.length == 8) return Color(int.parse(hex,       radix: 16));
    } catch (_) {}
    return fallback;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UpdateDialog
//
// Branded update modal that matches AppTheme.dark exactly.
// force_update = true  → no dismiss gesture, no "Later" button.
// force_update = false → barrierDismissible + "Later" button.
//
// The Download button triggers ApkDownloader.downloadAndInstall() and shows
// progress via PushNotificationService rather than opening a browser.
// ─────────────────────────────────────────────────────────────────────────────
class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.releaseNotes,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.remoteBuild,
  });

  final String releaseNotes;
  final String downloadUrl;
  final bool   forceUpdate;
  final int    remoteBuild;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back-button dismissal when force update is required.
      canPop: !widget.forceUpdate,
      child: AlertDialog(
        // Shape and background come from AppTheme.dark's dialogTheme.
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Update Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.forceUpdate) ..._forceUpdateBanner(),
            const SizedBox(height: 12),
            const Text(
              "What's new",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.releaseNotes,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
                height: 1.5,
              ),
            ),
            if (_downloading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text(
                'Downloading… check the notification bar for progress.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ],
        ),
        actions: [
          // "Later" is hidden for force updates or while downloading.
          if (!widget.forceUpdate && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Later',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: _downloading ? null : () => _launchDownload(context),
            icon: _downloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(_downloading ? 'Downloading…' : 'Download'),
          ),
        ],
      ),
    );
  }

  List<Widget> _forceUpdateBanner() {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'This update is required to continue using Otya Player.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _launchDownload(BuildContext context) async {
    if (widget.downloadUrl.isEmpty) {
      debugPrint('[OtyaService] Download URL is empty — cannot start download.');
      return;
    }

    setState(() => _downloading = true);

    // Show an immediate progress notification so the user sees feedback even
    // if they dismiss the dialog.
    await PushNotificationService.instance.showDownloadProgress(percent: 0);

    final version = widget.remoteBuild.toString();

    await ApkDownloader.instance.downloadAndInstall(
      url:     widget.downloadUrl,
      version: version,
      onProgress: (progress) {
        PushNotificationService.instance
            .showDownloadProgress(percent: (progress * 100).round())
            .ignore();
      },
      onError: (err) {
        debugPrint('[OtyaService] Download error: $err');
        PushNotificationService.instance.dismissDownload().ignore();
        if (mounted) {
          setState(() => _downloading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $err')),
          );
        }
      },
    );

    // downloadAndInstall completes after the installer is launched (or on
    // error). Show the "complete" notification and close the dialog.
    await PushNotificationService.instance.showDownloadComplete();

    if (mounted) {
      setState(() => _downloading = false);
      // Only pop if not a force update — user must complete the install.
      if (!widget.forceUpdate) {
        Navigator.of(context).pop();
      }
    }
  }
}
