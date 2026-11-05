import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';

class ResponsibleScreen extends StatefulWidget {
  const ResponsibleScreen({super.key});

  @override
  State<ResponsibleScreen> createState() => _ResponsibleScreenState();
}

class _ResponsibleScreenState extends State<ResponsibleScreen> {
  int _refresh = 0;

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: '${row?['nome'] ?? ''}');
    final job = TextEditingController(text: '${row?['cargo'] ?? ''}');
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(row == null ? 'Novo responsável' : 'Editar responsável'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              formTextField(name, 'Nome', required: true),
              formTextField(job, 'Cargo', required: true),
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
                if (row == null) {
                  await ApiClient.post('/responsavel/', {
                    'nome': name.text.trim(),
                    'cargo': job.text.trim(),
                  });
                } else {
                  await ApiClient.put(
                    '/responsavel/',
                    body: {'nome': name.text.trim(), 'cargo': job.text.trim()},
                    queryParameters: {'id': '${row['id']}'},
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
    job.dispose();
    if (result == true && mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    key: ValueKey(_refresh),
    future: ApiClient.get('/responsavel/'),
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
              label: const Text('Novo responsável'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final raw in rows)
            AppListCard(
              leading: const AppIconBadge(icon: Icons.person_outline),
              title: '${raw['nome']}',
              subtitle: '${raw['cargo']}',
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  final row = Map<String, dynamic>.from(raw);
                  if (v == 'edit') await _edit(row);
                  if (v == 'disable' &&
                      await confirmAction(
                        context,
                        'Desativar ${row['nome']}?',
                      )) {
                    try {
                      await ApiClient.delete(
                        '/responsavel/',
                        queryParameters: {'id': '${row['id']}'},
                      );
                      if (mounted) setState(() => _refresh++);
                    } catch (e) {
                      if (mounted) showAppMessage(context, '$e');
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'disable', child: Text('Desativar')),
                ],
              ),
            ),
        ],
      );
    },
  );
}
