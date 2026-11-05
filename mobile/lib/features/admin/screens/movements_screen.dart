import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';
import '../../movimentacao/transferencias.dart';

/// Filtros da tela. "Pendentes" e "Escaladas" são a fila de decisão do setor de patrimônio.
enum _Filtro {
  todas('Todas', '/movimentacao/detailed/'),
  pendentes('Pendentes', '/movimentacao/pendentes'),
  escaladas('Escaladas', '/movimentacao/escaladas');

  const _Filtro(this.label, this.endpoint);
  final String label;
  final String endpoint;
}

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  String _query = '';
  final _searchController = TextEditingController();
  _Filtro _filtro = _Filtro.todas;
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<List<dynamic>> _loadData() => Future.wait([
    ApiClient.get(_filtro.endpoint),
    ApiClient.get('/bem/'),
    ApiClient.get('/setores/'),
  ]);

  void _reloadData() => setState(() => _dataFuture = _loadData());

  void _trocarFiltro(_Filtro filtro) {
    setState(() {
      _filtro = filtro;
      _dataFuture = _loadData();
    });
  }

  Future<void> _executar(Future<bool> acao) async {
    final ok = await acao;
    if (ok && mounted) _reloadData();
  }

  /// Patrimônio decide qualquer etapa e pode intervir em transferências abertas.
  Widget _acoesDecisao(Map<String, dynamic> mov) {
    final aberta = mov['status'] == 'pendente' || mov['status'] == 'liberada';
    if (!aberta) return const SizedBox.shrink();
    final liberar = mov['etapa'] == 'liberar' && mov['fluxo'] != 'simples';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _executar(recusarTransferencia(context, mov)),
                child: const Text('Recusar'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: () => _executar(autorizarTransferencia(context, mov)),
                child: Text(liberar ? 'Liberar bem' : 'Confirmar com foto'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _executar(intervirTransferencia(context, mov)),
          icon: const Icon(Icons.gpp_maybe_outlined),
          label: const Text('Intervir (cancelar)'),
        ),
      ],
    );
  }

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
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final f in _Filtro.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: _filtro == f,
                  onSelected: (_) => _trocarFiltro(f),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (movements.isEmpty)
            AppEmptyState(
              title: _filtro == _Filtro.todas
                  ? 'Sem movimentações'
                  : _filtro == _Filtro.pendentes
                  ? 'Nenhuma transferência aguardando decisão'
                  : 'Nenhuma transferência escalada',
              description: _filtro == _Filtro.escaladas
                  ? 'Escaladas são solicitações sem resposta do almoxarifado além do prazo.'
                  : null,
            )
          else if (_filtro == _Filtro.todas)
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
              )
          else
            for (final raw in movements)
              TransferenciaCard(
                mov: Map<String, dynamic>.from(raw),
                acoes: _acoesDecisao(Map<String, dynamic>.from(raw)),
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
