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
import '../shared/widgets/otya_logo.dart';
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

    // Only local state is allowed to affect first paint. Network services begin
    // after Flutter has already produced a usable frame.
    _checkOnboarding();
    unawaited(_loadLocalVisualTheme());

    SchedulerBinding.instance.addPostFrameCallback((_) {
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

  Future<void> _loadLocalVisualTheme() async {
    try {
      await CustomThemeManager.instance.load();
    } catch (_) {}
  }

  Future<void> _startRemoteServicesAfterFirstFrame() async {
    try {
      await RemoteControlService.instance.init();
    } catch (_) {}
    unawaited(
      CustomThemeManager.instance.refreshSeasonalTheme().catchError((_) {}),
    );
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
        icon: const OtyaLogo(iconOnly: true, fontSize: 48),
        title: const Text('Enable OTYA notifications?'),
        content: const Text(
          'Notifications provide Now Playing controls, completed local-task alerts, account/security messages and OTYA update notices. You can change this later in Android settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enable'),
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
        appBarTheme: AppTheme.dark.appBarTheme.copyWith(
          backgroundColor: Colors.black,
        ),
      );
    }
    return AppTheme.dark;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    if (_checking) {
      // Keep the very first visible frame consistent with the persisted theme.
      // In particular, System must follow the device instead of being treated
      // as Dark while local onboarding state is loading.
      return MaterialApp(
        title: 'OTYA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: _darkTheme(settings.themeMode),
        themeMode: _materialThemeMode(settings.themeMode),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OtyaLogo(iconOnly: true, fontSize: 68),
                const SizedBox(height: 16),
                Text(
                  'OTYA',
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 26),
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: AppRouter.router,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            // Android 15+ enforces edge-to-edge. Keep both system bars
            // transparent and let each screen protect only its interactive
            // controls with MediaQuery/SafeArea insets. Painting an opaque
            // navigation bar here recreates a heavy footer and causes jarring
            // transitions between OTYA surfaces.
            final overlay = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarContrastEnforced: false,
            );

            Widget wrappedChild = child ?? const SizedBox.shrink();
            final wallpaperDecoration = themeManager.wallpaperDecoration;
            if (wallpaperDecoration != null) {
              wrappedChild = Container(
                decoration: BoxDecoration(image: wallpaperDecoration),
                child: wrappedChild,
              );
            }

            // Respect the user's platform text scale exactly. OTYA layouts must
            // adapt to accessibility settings rather than silently clamping
            // large text to a smaller value.
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: RemoteControlGate(
                child: Stack(
                  children: [
                    wrappedChild,
                    if (!_onboardingDone)
                      OnboardingOverlay(onDone: _completeOnboarding),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
