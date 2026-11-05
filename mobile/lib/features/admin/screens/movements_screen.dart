import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  String _query = '';
  final _searchController = TextEditingController();
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<List<dynamic>> _loadData() => Future.wait([
    ApiClient.get('/movimentacao/detailed/'),
    ApiClient.get('/bem/'),
    ApiClient.get('/setores/'),
  ]);

  void _reloadData() => setState(() => _dataFuture = _loadData());

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _create(List<dynamic> assets, List<dynamic> sectors) async {
    final reason = TextEditingController();
    int? selectedAsset;
    int? destination;
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          scrollable: true,
          title: const Text('Nova transferência'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Bem'),
                    items: assets
                        .where((r) => r['ativo'] == true)
                        .map(
                          (r) => DropdownMenuItem<int>(
                            value: r['id'] as int,
                            child: Text(
                              '${r['codigo_tombamento']} • ${r['nome']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => refresh(() => selectedAsset = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Setor de destino',
                    ),
                    items: sectors
                        .map(
                          (r) => DropdownMenuItem<int>(
                            value: r['id'] as int,
                            child: Text('${r['nome']}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => refresh(() => destination = v),
                  ),
                ),
                formTextField(reason, 'Justificativa', required: true),
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
                if (!form.currentState!.validate() ||
                    selectedAsset == null ||
                    destination == null) {
                  showAppMessage(ctx, 'Selecione o bem e o setor de destino.');
                  return;
                }
                try {
                  await ApiClient.post('/movimentacao/', {
                    'bem_id': selectedAsset,
                    'setor_destino_id': destination,
                    'justificativa': reason.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) showAppMessage(ctx, '$e');
                }
              },
              child: const Text('Transferir'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (result == true && mounted) _reloadData();
  }

  void _applySearch() {
    FocusScope.of(context).unfocus();
    setState(() => _query = _searchController.text.trim());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: _dataFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AppLoading(label: 'Carregando movimentações...');
      }
      if (snapshot.hasError) {
        return AppErrorState(
          description: '${snapshot.error}',
          onRetry: _reloadData,
        );
      }
      final allMovements = snapshot.data![0];
      final assets = snapshot.data![1];
      final sectors = snapshot.data![2];
      final term = _query.toLowerCase();
      final movements = allMovements
          .where(
            (m) =>
                '${m['bem_nome']} ${m['codigo_tombamento']} ${m['setor_origem_nome'] ?? ''} ${m['setor_destino_nome']}'
                    .toLowerCase()
                    .contains(term),
          )
          .toList();

      return ListView(
        padding: AppSpacing.screen,
        children: [
          Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: _searchController,
                  hint: 'Buscar por tombo, bem ou setor',
                  onSubmitted: (_) => _applySearch(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                tooltip: 'Nova transferência',
                onPressed: () => _create(assets, sectors),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (movements.isEmpty)
            const AppEmptyState(title: 'Sem movimentações')
          else
            for (final raw in movements)
              AppListCard(
                leading: const AppIconBadge(icon: Icons.swap_horiz),
                trailing: AppStatusChip(
                  label: _statusLabel('${raw['status'] ?? 'aprovada'}'),
                  color: _statusColor('${raw['status'] ?? 'aprovada'}'),
                ),
                title: '${raw['bem_nome']}',
                subtitle:
                    '${raw['codigo_tombamento']}\n${raw['setor_origem_nome'] ?? 'Origem não informada'} → ${raw['setor_destino_nome']} • ${shortDate(raw['data_movimentacao'])}\n${raw['justificativa'] ?? ''}',
              ),
        ],
      );
    },
  );
}

String _statusLabel(String status) => switch (status) {
  'pendente' => 'Pendente',
  'recusada' => 'Recusada',
  _ => 'Aprovada',
};

Color _statusColor(String status) => switch (status) {
  'pendente' => AppColors.warning,
  'recusada' => AppColors.error,
  _ => AppColors.success,
};
