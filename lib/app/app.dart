import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'router.dart';
import '../core/permissions/permission_gate_screen.dart';

class PlayedApp extends StatelessWidget {
  const PlayedApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        // navigationBarColor removed — not a valid SystemUiOverlayStyle parameter in Flutter 3.x
      ),
    );

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
