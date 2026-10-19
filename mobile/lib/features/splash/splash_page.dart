import 'package:flutter/material.dart';

import '../../core/storage/server_config_storage.dart';
import '../../core/storage/secure_token_storage.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../auth/login_page.dart';
import '../server_config/server_config_page.dart';
import '../home/home_placeholder_page.dart';

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
    if (baseUrl == null || baseUrl.isEmpty) {
      Navigator.of(context).pushReplacementNamed(ServerConfigPage.routeName);
      return;
    }
    final token = await SecureTokenStorage().readToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
      return;
    }
    try {
      // A API valida o token e devolve o perfil atualizado para o auto-login.
      final profile = await ApiClient.getMap('/auth/me');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePlaceholderPage(profile: profile),
        ),
      );
    } catch (_) {
      // Em 401 o cliente já encerra a sessão e redireciona para o login.
      // Em falhas de rede, preserva-se o token para nova tentativa no próximo uso.
      if (!mounted) return;
      final tokenStillPresent = await SecureTokenStorage().readToken() != null;
      if (!mounted || !tokenStillPresent) return;
      Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 220,
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: .18),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 20),
          Text('PatriFlow', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Gestão patrimonial simplificada'),
          const SizedBox(height: 36),
          const AppLoading(label: 'Preparando o aplicativo...'),
        ],
      ),
    ),
  );
}
