import 'package:flutter/material.dart';

import '../../core/storage/server_config_storage.dart';
import '../auth/login_page.dart';

class ServerConfigPage extends StatefulWidget {
  const ServerConfigPage({super.key});
  static const routeName = '/configuracao-servidor';

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAddress();
  }

  Future<void> _loadSavedAddress() async {
    final value = await ServerConfigStorage().getBaseUrl();
    if (mounted && value != null) _controller.text = value;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ServerConfigStorage().saveBaseUrl(_controller.text);
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(LoginPage.routeName, (_) => false);
  }

  String? _validateAddress(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Informe uma URL HTTP ou HTTPS válida.';
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Servidor PatriFlow')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.dns_outlined,
            size: 54,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Conecte o aplicativo ao seu servidor',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Este endereço fica guardado somente neste aparelho. Você poderá alterá-lo depois.',
          ),
          const SizedBox(height: 32),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Endereço do servidor',
                hintText: 'http://192.168.0.10:8000',
                prefixIcon: Icon(Icons.link),
              ),
              validator: _validateAddress,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Em emulador Android, a API local do computador costuma ser http://10.0.2.2:8000.',
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvando...' : 'Salvar e continuar'),
          ),
        ],
      ),
    ),
  );
}
