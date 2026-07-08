import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'router.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_provider.dart';
import '../core/widgets/update_dialog.dart';

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
    // Check for updates after the first frame is drawn so it never
    // delays the app startup. Shows a friendly dialog if a new version
    // is available — max once per day.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateDialog.checkAndShow(context);
    });
  }

  Future<void> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_done') ?? false;
      if (mounted) setState(() { _onboardingDone = done; _checking = false; });
    } catch (_) {
      if (mounted) setState(() { _onboardingDone = true; _checking = false; });
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
    // Watch settings so the theme rebuilds whenever the user changes it
    final settings = ref.watch(settingsProvider);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    if (_checking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF020408),
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
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 44,
                  ),
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

    return MaterialApp.router(
      title: 'OTYA Player',
      debugShowCheckedModeBanner: false,
      // theme / darkTheme / themeMode work together:
      //   Light  → ThemeMode.light  → AppTheme.light
      //   Dark   → ThemeMode.dark   → AppTheme.dark
      //   AMOLED → ThemeMode.dark   → AppTheme.dark + pure-black override in builder
      theme:     AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (settings.themeMode) {
        AppThemeMode.dark   => ThemeMode.dark,
        AppThemeMode.amoled => ThemeMode.dark,
        AppThemeMode.light  => ThemeMode.light,
      },
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final isAmoled = settings.themeMode == AppThemeMode.amoled;
        // AMOLED: override scaffold + surface to pure black
        final wrappedChild = isAmoled
            ? Theme(
                data: Theme.of(context).copyWith(
                  scaffoldBackgroundColor: Colors.black,
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    surface: Colors.black,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              )
            : (child ?? const SizedBox.shrink());

        return Stack(
          children: [
            wrappedChild,
            if (!_onboardingDone)
              OnboardingOverlay(onDone: _completeOnboarding),
          ],
        );
      },
    );
  }
}
