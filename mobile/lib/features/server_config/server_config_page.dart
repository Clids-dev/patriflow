import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/storage/server_config_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
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
  bool _testing = false;
  bool? _connectionReached;

  @override
  void initState() {
    super.initState();
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddress() async {
    final value = await ServerConfigStorage().getBaseUrl();
    if (mounted && value != null) _controller.text = value;
  }

  Future<bool> _runConnectionTest() async {
    final address = _controller.text.trim();
    if (address.isEmpty) return false;

    try {
      final normalized = ServerConfigStorage.normalize(address);
      final uri = Uri.parse(normalized);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(uri);
      final response = await request.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _testing = true;
      _connectionReached = null;
    });

    final success = await _runConnectionTest();

    if (mounted) {
      setState(() {
        _testing = false;
        _connectionReached = success;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Conexão estabelecida com sucesso!'
                : 'Não foi possível alcançar o servidor.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Testa a conexão antes de salvar.
    final reached = await _runConnectionTest();
    setState(() {
      _connectionReached = reached;
      _saving = false;
    });

    if (!mounted) return;

    if (!reached) {
      // Pergunta se deve salvar mesmo sem resposta do servidor.
      final saveAnyway = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Row(
            children: [
              Icon(AppIcons.error, color: AppColors.error),
              SizedBox(width: AppSpacing.sm),
              Text('Servidor inalcançável'),
            ],
          ),
          content: const Text(
            'O endereço configurado não respondeu ao teste de conexão.\n\nDeseja salvar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar e corrigir'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Salvar assim mesmo'),
            ),
          ],
        ),
      );

      if (saveAnyway != true) return;
    }

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

  Widget _statusBanner() {
    final ok = _connectionReached == true;
    final color = ok ? AppColors.success : AppColors.error;
    final soft = ok ? AppColors.successSoft : AppColors.errorSoft;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : AppIcons.error, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              ok ? 'Servidor alcançado com sucesso!' : 'Inalcançável. Verifique se o servidor está rodando ou digite outro endereço.',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Servidor PatriFlow')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          const AppIconBadge(icon: AppIcons.server, size: 64),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Conecte o aplicativo ao seu servidor',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Este endereço fica guardado somente neste aparelho. Você poderá alterá-lo depois.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Endereço do servidor',
                hintText: 'http://192.168.0.10:8000',
                prefixIcon: Icon(AppIcons.link),
              ),
              validator: _validateAddress,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Em emulador Android, a API local do computador costuma ser http://10.0.2.2:8000.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_testing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Testando conexão com o servidor...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else if (_connectionReached != null)
            _statusBanner(),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: _testing || _saving ? null : _testConnection,
            icon: const Icon(AppIcons.retry),
            label: const Text('Testar conexão'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: _saving || _testing ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(AppIcons.save),
            label: Text(_saving ? 'Salvando...' : 'Salvar e continuar'),
          ),
        ],
      ),
    ),
  );
}
