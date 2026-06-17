import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'router.dart';
import '../features/onboarding/onboarding_screen.dart';

class OtyaPlayerApp extends StatefulWidget {
  const OtyaPlayerApp({super.key});

  @override
  State<OtyaPlayerApp> createState() => _OtyaPlayerAppState();
}

class _OtyaPlayerAppState extends State<OtyaPlayerApp> {
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
      // If SharedPreferences fails, skip onboarding and go straight to app
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Show a dark splash while checking — never a white screen
    if (_checking) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF050810),
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF8A2BE2),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (!_onboardingDone) {
      return MaterialApp(
        title: 'OTYA Player',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: OnboardingScreen(onDone: _completeOnboarding),
      );
    }

    // No builder wrapper — permissions are requested contextually per feature.
    return MaterialApp.router(
      title: 'OTYA Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
    );
  }
}
