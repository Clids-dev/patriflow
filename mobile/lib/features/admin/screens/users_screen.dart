import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';

/// Aprovação e administração de contas: define perfil, setor e situação.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.adminId});

  final int adminId;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  int _refresh = 0;

  Future<List<dynamic>> _load() =>
      Future.wait([ApiClient.get('/usuarios/'), ApiClient.get('/setores/')]);

  Future<void> _editar(
    Map<String, dynamic> usuario,
    List<dynamic> setores,
  ) async {
    var perfil = '${usuario['perfil']}';
    if (!perfisDisponiveis.contains(perfil)) perfil = 'agente_campo';
    int? setorId = usuario['setor_id'] as int?;
    var ativo = usuario['ativo'] == true;
    final salvo = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          scrollable: true,
          title: Text('${usuario['nome'] ?? usuario['username']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DropdownButtonFormField<String>(
                  initialValue: perfil,
                  decoration: const InputDecoration(labelText: 'Perfil'),
                  items: [
                    for (final p in perfisDisponiveis)
                      DropdownMenuItem(value: p, child: Text(perfilLabel(p))),
                  ],
                  onChanged: (v) => refresh(() => perfil = v ?? perfil),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DropdownButtonFormField<int>(
                  initialValue: setorId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Setor'),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Nenhum'),
                    ),
                    for (final s in setores)
                      DropdownMenuItem<int>(
                        value: s['id'] as int,
                        child: Text(
                          '${s['nome']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => refresh(() => setorId = v),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Conta ativa'),
                subtitle: const Text('Desative para bloquear o acesso.'),
                value: ativo,
                onChanged: usuario['id'] == widget.adminId
                    ? null
                    : (v) => refresh(() => ativo = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ApiClient.patch('/usuarios/${usuario['id']}', {
                    'perfil': perfil,
                    'setor_id': setorId,
                    'ativo': ativo,
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) showAppMessage(ctx, '$e');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvo == true && mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    key: ValueKey(_refresh),
    future: _load(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AppLoading(label: 'Carregando usuários...');
      }
      if (snapshot.hasError) {
        return AppErrorState(
          title: 'Erro ao carregar usuários',
          description: '${snapshot.error}',
          onRetry: () => setState(() => _refresh++),
        );
      }
      final usuarios = snapshot.data![0] as List<dynamic>;
      final setores = snapshot.data![1] as List<dynamic>;
      final setorNomes = {
        for (final s in setores) '${s['id']}': '${s['nome']}',
      };
      if (usuarios.isEmpty) {
        return const AppEmptyState(title: 'Nenhum usuário cadastrado');
      }
      return ListView(
        padding: AppSpacing.screen,
        children: [
          for (final raw in usuarios)
            AppListCard(
              leading: const AppIconBadge(icon: Icons.person_outline),
              title: '${raw['nome'] ?? raw['username']}',
              subtitle:
                  '${perfilLabel('${raw['perfil']}')}'
                  '${raw['setor_id'] != null ? ' • ${setorNomes['${raw['setor_id']}'] ?? 'Setor ${raw['setor_id']}'}' : ''}',
              trailing: _statusChip(raw['ativo'] == true),
              onTap: () => _editar(Map<String, dynamic>.from(raw), setores),
            ),
        ],
      );
    },
  );

  Widget _statusChip(bool ativo) => ativo
      ? AppStatusChip(label: 'Ativo', color: AppColors.success)
      : AppStatusChip(label: 'Pendente', color: AppColors.warning);
}
