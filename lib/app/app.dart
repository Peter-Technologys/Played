import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'router.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_provider.dart';
import '../core/services/custom_theme_manager.dart';
import '../core/services/remote_control_service.dart';
import '../core/providers/theme_provider.dart';
import '../core/widgets/announcement_dialog.dart';
import '../core/widgets/update_dialog.dart';
import '../core/widgets/remote_control_gate.dart';

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
    _checkOnboarding();
    _loadVisualTheme();
    RemoteControlService.instance.init();
    _applyOverlayStyle(isDark: true);
    ThemeProvider.instance.initTheme();
    SchedulerBinding.instance.addPostFrameCallback((_) {
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

  Future<void> _loadVisualTheme() async {
    await CustomThemeManager.instance.load();
    await CustomThemeManager.instance.refreshSeasonalTheme();
  }

  void _applyOverlayStyle({required bool isDark}) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
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
    if (mounted) setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final locale = ref.watch(localeProvider);

    ref.listen<AppSettings>(settingsProvider, (prev, next) {
      if (prev?.themeMode != next.themeMode) {
        _applyOverlayStyle(isDark: next.themeMode != AppThemeMode.light);
      }
    });

    if (_checking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0F111A),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentViolet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.45),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 44),
                ),
                const SizedBox(height: 20),
                const Text(
                  'OTYA PLAYER',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
              ],
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        CustomThemeManager.instance,
        ThemeProvider.instance,
        RemoteControlService.instance,
      ]),
      builder: (context, _) {
        final remoteThemeData = ThemeProvider.instance.hasTheme
            ? ThemeProvider.instance.currentThemeData
            : null;
        final remoteIsDark =
            (ThemeProvider.instance.rawTheme?['is_dark_mode'] as bool?) ?? true;

        final effectiveLightTheme =
            (remoteThemeData != null && !remoteIsDark)
                ? remoteThemeData
                : AppTheme.light;
        final effectiveDarkTheme =
            (remoteThemeData != null && remoteIsDark)
                ? remoteThemeData
                : AppTheme.dark;

        return MaterialApp.router(
          title: 'OTYA Player',
          debugShowCheckedModeBanner: false,
          theme: effectiveLightTheme,
          darkTheme: effectiveDarkTheme,
          themeMode: switch (settings.themeMode) {
            AppThemeMode.dark => ThemeMode.dark,
            AppThemeMode.amoled => ThemeMode.dark,
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.system => ThemeMode.system,
          },
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('fr'), Locale('es'), Locale('sw')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: AppRouter.router,
          builder: (context, child) {
            final isAmoled = settings.themeMode == AppThemeMode.amoled;
            Widget wrappedChild = isAmoled
                ? Theme(
                    data: Theme.of(context).copyWith(
                      scaffoldBackgroundColor: Colors.black,
                      colorScheme: Theme.of(context).colorScheme.copyWith(surface: Colors.black),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  )
                : (child ?? const SizedBox.shrink());

            final wallpaperDecoration = CustomThemeManager.instance.wallpaperDecoration;
            if (wallpaperDecoration != null) {
              wrappedChild = Container(
                decoration: BoxDecoration(image: wallpaperDecoration),
                child: wrappedChild,
              );
            }

            return MediaQuery(
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
            );
          },
        );
      },
    );
  }
}
