import 'package:flutter/material.dart';

import '../../core/storage/server_config_storage.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_placeholder_page.dart';
import '../server_config/server_config_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _server;

  @override
  void initState() {
    super.initState();
    ServerConfigStorage().getBaseUrl().then((value) {
      if (mounted) setState(() => _server = value);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PatriFlow'),
      actions: [
        IconButton(
          tooltip: 'Alterar servidor',
          onPressed: () =>
              Navigator.of(context).pushNamed(ServerConfigPage.routeName),
          icon: const Icon(AppIcons.settings),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(
              AppIcons.login,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Login será conectado em breve',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Servidor configurado: ${_server ?? 'carregando...'}',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            const Text(
              'Navegação de demonstração',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pushReplacementNamed(HomePlaceholderPage.adminRoute),
              child: const Text('Visualizar área administrativa'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pushReplacementNamed(HomePlaceholderPage.commonRoute),
              child: const Text('Visualizar área de consulta'),
            ),
          ],
        ),
      ),
    ),
  );
}
