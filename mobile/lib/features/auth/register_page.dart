import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  List<dynamic> _setores = const [];
  int? _setorId;
  bool _carregandoSetores = true;

  @override
  void initState() {
    super.initState();
    _carregarSetores();
  }

  Future<void> _carregarSetores() async {
    try {
      final setores = await ApiClient.get('/auth/setores-cadastro');
      if (mounted) setState(() => _setores = setores);
    } catch (_) {
      // Sem setores carregados, o formulário mostra o aviso e impede o envio.
    } finally {
      if (mounted) setState(() => _carregandoSetores = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? _required(String? value, String field) =>
      value == null || value.trim().isEmpty ? 'Informe $field.' : null;

  String? _usernameValidator(String? value) {
    final required = _required(value, 'o utilizador');
    if (required != null) return required;
    if (!RegExp(r'^[A-Za-z0-9_.-]{3,50}$').hasMatch(value!.trim())) {
      return 'Use 3 a 50 caracteres válidos: letras, números, ponto, hífen ou sublinhado.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Informe a senha.';
    if (value.length < 8) return 'A senha deve ter pelo menos 8 caracteres.';
    return null;
  }

  String? _confirmationValidator(String? value) {
    if (value == null || value.isEmpty) return 'Confirme a senha.';
    return value == _password.text ? null : 'As senhas não coincidem.';
  }

  String _errorMessage(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return 'Não foi possível conectar ao servidor. Verifique o endereço e tente novamente.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_setorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o setor ao qual você pertence.'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ApiClient.register(
        username: _username.text.trim().toLowerCase(),
        senha: _password.text,
        nome: _name.text.trim(),
        setorId: _setorId!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _visibilityToggle({
    required bool hidden,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: hidden ? 'Mostrar senha' : 'Ocultar senha',
    onPressed: onPressed,
    icon: Icon(
      hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Criar conta')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.md,
            AppSpacing.xxl,
            AppSpacing.xxxl,
          ),
          children: [
            Text(
              'Comece no PatriFlow',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Crie seu acesso para acompanhar os bens e as movimentações.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xxl),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => _required(value, 'o nome'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _setorId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Setor',
                helperText: _carregandoSetores
                    ? 'Carregando setores...'
                    : (_setores.isEmpty
                          ? 'Não foi possível carregar os setores'
                          : 'Seu acesso será liberado após aprovação'),
                prefixIcon: const Icon(Icons.business_outlined),
              ),
              items: [
                for (final s in _setores)
                  DropdownMenuItem<int>(
                    value: s['id'] as int,
                    child: Text(
                      '${s['nome']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _setorId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _username,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Utilizador',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: _usernameValidator,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Senha',
                helperText: 'Mínimo de 8 caracteres',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: _visibilityToggle(
                  hidden: _hidePassword,
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: _passwordValidator,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _confirmation,
              obscureText: _hideConfirmation,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Confirmar senha',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: _visibilityToggle(
                  hidden: _hideConfirmation,
                  onPressed: () =>
                      setState(() => _hideConfirmation = !_hideConfirmation),
                ),
              ),
              validator: _confirmationValidator,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Criar conta'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(),
              child: const Text('Já tenho uma conta'),
            ),
          ],
        ),
      ),
    ),
  );
}
