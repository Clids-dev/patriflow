import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/navigation/app_navigation.dart';
import 'features/auth/login_page.dart';
import 'features/server_config/server_config_page.dart';
import 'features/splash/splash_page.dart';

class PatriFlowApp extends StatelessWidget {
  const PatriFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'PatriFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashPage(),
      routes: {
        ServerConfigPage.routeName: (_) => const ServerConfigPage(),
        LoginPage.routeName: (_) => const LoginPage(),
      },
    );
  }
}
