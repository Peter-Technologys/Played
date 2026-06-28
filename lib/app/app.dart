import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'router.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_provider.dart';

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
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF050810),
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00D4FF),
              strokeWidth: 2,
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
