import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/custom_theme_manager.dart';
import '../core/services/notification_service.dart';
import '../core/services/remote_control_service.dart';
import '../core/widgets/announcement_dialog.dart';
import '../core/widgets/remote_control_gate.dart';
import '../core/widgets/update_dialog.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_provider.dart';
import 'router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class OtyaPlayerApp extends ConsumerStatefulWidget {
  const OtyaPlayerApp({super.key});

  @override
  ConsumerState<OtyaPlayerApp> createState() => _OtyaPlayerAppState();
}

class _OtyaPlayerAppState extends ConsumerState<OtyaPlayerApp> {
  bool _onboardingDone = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();

    // FIRST-PAINT RULE:
    // Only local state is read before the app becomes usable. No Firebase,
    // Cloudflare, auth, AI, update, announcement, or online-theme request is
    // allowed to control startup. OTYA must open with airplane mode enabled.
    _checkOnboarding();
    unawaited(_loadLocalVisualTheme());

    SchedulerBinding.instance.addPostFrameCallback((_) {
      // All online/remote work starts only after Flutter has produced a frame.
      // Every task is fire-and-forget and owns its own failure handling.
      unawaited(_startRemoteServicesAfterFirstFrame());

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        try {
          AnnouncementDialog.showIfPending(context);
        } catch (_) {}
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        try {
          UpdateDialog.checkAndShow(context);
        } catch (_) {}
      });
    });
  }

  /// Loads only app-owned/local theme data. This method never needs internet.
  Future<void> _loadLocalVisualTheme() async {
    try {
      await CustomThemeManager.instance.load();
    } catch (_) {
      // Theme failure must never prevent Video/Music/Me from opening.
    }
  }

  /// Remote work is deliberately kept out of the critical startup path.
  Future<void> _startRemoteServicesAfterFirstFrame() async {
    try {
      await RemoteControlService.instance.init();
    } catch (_) {
      // Cached/default configuration remains valid while offline.
    }

    // Seasonal themes are optional decoration. They must never delay startup,
    // playback, media scanning, transfer, or local file access.
    unawaited(CustomThemeManager.instance.refreshSeasonalTheme().catchError((_) {}));
  }

  Future<void> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') ?? false;
      if (mounted) {
        setState(() {
          _onboardingDone = done;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _onboardingDone = true;
          _checking = false;
        });
      }
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_done', true);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _onboardingDone = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _offerNotificationPermission();
    });
  }

  Future<void> _offerNotificationPermission() async {
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF11D7FF), Color(0xFF7544FF), Color(0xFFFF2CAA)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: .25),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(Icons.notifications_active_rounded,
              color: Colors.white, size: 29),
        ),
        title: const Text('Stay in the loop'),
        content: const Text(
          'Allow notifications for Now Playing controls, completed downloads, important account alerts and new OTYA updates. You can change this later in Android settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enable notifications'),
          ),
        ],
      ),
    );
    if (enable == true) {
      await NotificationService.instance.requestPermission();
    }
  }

  ThemeMode _materialThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.dark || AppThemeMode.amoled => ThemeMode.dark,
      };

  ThemeData _darkTheme(AppThemeMode mode) {
    if (mode == AppThemeMode.amoled) {
      return AppTheme.dark.copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme:
            AppTheme.dark.appBarTheme.copyWith(backgroundColor: Colors.black),
      );
    }
    return AppTheme.dark;
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final settings = ref.watch(settingsProvider);

    if (_checking) {
      final startupTheme = settings.themeMode == AppThemeMode.light
          ? AppTheme.light
          : _darkTheme(settings.themeMode);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: startupTheme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.28),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'OTYA',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        CustomThemeManager.instance,
        RemoteControlService.instance,
      ]),
      builder: (context, _) {
        final themeManager = CustomThemeManager.instance;
        final hasArtwork =
            themeManager.hasImageWallpaper || themeManager.storyTheme != null;

        final baseLight = AppTheme.light;
        final baseDark = _darkTheme(settings.themeMode);
        final lightTheme = hasArtwork
            ? baseLight.copyWith(scaffoldBackgroundColor: Colors.transparent)
            : baseLight;
        final darkTheme = hasArtwork
            ? baseDark.copyWith(scaffoldBackgroundColor: Colors.transparent)
            : baseDark;

        return MaterialApp.router(
          title: 'OTYA',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: _materialThemeMode(settings.themeMode),
          locale: locale,
          supportedLocales: const [
            Locale('en'),
            Locale('fr'),
            Locale('es'),
            Locale('sw'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: AppRouter.router,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final overlay = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor:
                  Theme.of(context).scaffoldBackgroundColor,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            );

            Widget wrappedChild = child ?? const SizedBox.shrink();
            final wallpaperDecoration = themeManager.wallpaperDecoration;
            if (wallpaperDecoration != null) {
              wrappedChild = Container(
                decoration: BoxDecoration(image: wallpaperDecoration),
                child: wrappedChild,
              );
            }

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.of(context).textScaler.clamp(
                        minScaleFactor: 0.85,
                        maxScaleFactor: 1.2,
                      ),
                ),
                child: RemoteControlGate(
                  child: Stack(
                    children: [
                      wrappedChild,
                      if (!_onboardingDone)
                        OnboardingOverlay(onDone: _completeOnboarding),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
