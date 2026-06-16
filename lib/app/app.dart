import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'router.dart';
import '../core/permissions/permission_gate_screen.dart';
import '../features/onboarding/onboarding_screen.dart';

class PlayedApp extends StatefulWidget {
  const PlayedApp({super.key});

  @override
  State<PlayedApp> createState() => _PlayedAppState();
}

class _PlayedAppState extends State<PlayedApp> {
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
          backgroundColor: Color(0xFF0A0F1E),
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00D4FF),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (!_onboardingDone) {
      return MaterialApp(
        title: 'PLAYED',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: OnboardingScreen(onDone: _completeOnboarding),
      );
    }

    return MaterialApp.router(
      title: 'PLAYED',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
      builder: (context, child) => PermissionGateScreen(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
