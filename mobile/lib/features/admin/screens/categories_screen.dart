import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _refresh = 0;

  Future<void> _edit([Map<String, dynamic>? category]) async {
    final name = TextEditingController(text: '${category?['nome'] ?? ''}');
    final acronym = TextEditingController(text: '${category?['sigla'] ?? ''}');
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(category == null ? 'Nova categoria' : 'Editar categoria'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              formTextField(name, 'Nome', required: true),
              if (category == null)
                TextFormField(
                  controller: acronym,
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Sigla (3 caracteres)',
                  ),
                  validator: requiredValidator,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                if (category == null) {
                  await ApiClient.post('/categoria/', {
                    'nome': name.text.trim(),
                    'sigla': acronym.text.trim().toUpperCase(),
                  });
                } else {
                  await ApiClient.put(
                    '/categoria/',
                    queryParameters: {
                      'id': '${category['id']}',
                      'novo_nome': name.text.trim(),
                    },
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) showAppMessage(ctx, '$e');
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    name.dispose();
    acronym.dispose();
    if (saved == true && mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    key: ValueKey(_refresh),
    future: ApiClient.get('/categoria/'),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AppLoading();
      }
      if (snapshot.hasError) {
        return AppErrorState(
          description: '${snapshot.error}',
          onRetry: () => setState(() => _refresh++),
        );
      }
      final rows = snapshot.data ?? [];
      return ListView(
        padding: AppSpacing.screen,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Nova categoria'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final raw in rows)
            AppListCard(
              leading: SiglaBadge('${raw['sigla'] ?? ''}'),
              title: '${raw['nome'] ?? ''}',
              subtitle: 'ID ${raw['id']}',
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  final row = Map<String, dynamic>.from(raw);
                  if (v == 'edit') await _edit(row);
                  if (v == 'disable' &&
                      await confirmAction(
                        context,
                        'Desativar categoria ${row['nome']}?',
                      )) {
                    try {
                      await ApiClient.delete(
                        '/categoria/',
                        queryParameters: {'id': '${row['id']}'},
                      );
                      if (mounted) setState(() => _refresh++);
                    } catch (e) {
                      if (mounted) showAppMessage(context, '$e');
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar nome')),
                  PopupMenuItem(value: 'disable', child: Text('Desativar')),
                ],
              ),
            ),
        ],
      );
    },
  );
}
