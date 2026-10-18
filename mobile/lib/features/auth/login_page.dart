import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/storage/server_config_storage.dart';
import '../../core/storage/secure_token_storage.dart';
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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _server;

  @override
  void initState() {
    super.initState();
    ServerConfigStorage().getBaseUrl().then((value) {
      if (mounted) setState(() => _server = value);
    });
  }

  Future<void> _login() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe utilizador e senha.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final profile = await ApiClient.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => HomePlaceholderPage(profile: profile),
      ));
    } catch (error) {
      if (!mounted) return;
      // Login falhou: remove somente qualquer credencial anterior; a mensagem
      // exibida continua sendo exatamente o detalhe devolvido pela API.
      await SecureTokenStorage().clearToken();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('PatriFlow'),
          actions: [
            IconButton(
              tooltip: 'Alterar servidor',
              onPressed: () => Navigator.of(context).pushNamed(ServerConfigPage.routeName),
              icon: const Icon(AppIcons.settings),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(AppIcons.login, size: 60, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 20),
                    Text('Entrar no PatriFlow', textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Servidor: ${_server ?? 'carregando...'}', textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Utilizador', prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Senha', prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
