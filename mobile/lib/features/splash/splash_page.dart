import 'package:flutter/material.dart';

import '../../core/storage/server_config_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../auth/login_page.dart';
import '../server_config/server_config_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _continueFlow();
  }

  Future<void> _continueFlow() async {
    final baseUrl = await ServerConfigStorage().getBaseUrl();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      baseUrl == null || baseUrl.isEmpty
          ? ServerConfigPage.routeName
          : LoginPage.routeName,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'PatriFlow',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Gestão patrimonial simplificada'),
          const SizedBox(height: 36),
          const AppLoading(label: 'Preparando o aplicativo...'),
        ],
      ),
    ),
  );
}
