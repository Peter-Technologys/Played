import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'router.dart';

class PlayedApp extends StatelessWidget {
  const PlayedApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Force dark status bar icons
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        navigationBarColor: Colors.transparent,
      ),
    );

    return MaterialApp.router(
      title: 'PLAYED',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
    );
  }
}
