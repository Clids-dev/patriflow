import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';
import '../dialogs/asset_form_dialog.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  String _query = '';
  final _searchController = TextEditingController();
  String? _statusFilter;
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<List<dynamic>> _loadData() =>
      Future.wait([ApiClient.get('/bem/'), ApiClient.get('/categoria/')]);

  void _reloadData() => setState(() => _dataFuture = _loadData());

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editAsset(
    List<dynamic> categories, [
    Map<String, dynamic>? asset,
  ]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AssetFormDialog(categories: categories, asset: asset),
    );
    if (saved == true && mounted) _reloadData();
  }

  Future<void> _toggleActive(Map<String, dynamic> asset) async {
    final active = asset['ativo'] == true;
    final confirmed = await confirmAction(
      context,
      active ? 'Dar baixa neste bem?' : 'Reativar este bem?',
    );
    if (!mounted || !confirmed) return;
    try {
      await ApiClient.post(
        '/bem/${asset['id']}/${active ? 'desativar' : 'reativar'}',
        {},
      );
      if (mounted) _reloadData();
    } catch (e) {
      if (mounted) showAppMessage(context, '$e');
    }
  }

  Future<void> _showDetails(Map<String, dynamic> asset) async {
    try {
      final details = await ApiClient.getMap('/bem/${asset['id']}/detalhes');
      final history = await ApiClient.get(
        '/movimentacao/bem/${Uri.encodeComponent('${asset['codigo_tombamento']}')}',
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .78,
            builder: (ctx, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  '${details['nome']}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    AppStatusChip(
                      label: 'Tombo ${details['codigo_tombamento']}',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppStatusChip(
                      label: '${details['status']}',
                      color: assetStatusColor('${details['status']}'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppPanel(
                  child: Column(
                    children: [
                      AppDetailLine(
                        label: 'Categoria',
                        value: details['categoria_nome'],
                      ),
                      AppDetailLine(
                        label: 'Marca / modelo',
                        value:
                            '${details['marca'] ?? '—'} ${details['modelo'] ?? ''}',
                      ),
                      AppDetailLine(
                        label: 'Número de série',
                        value: details['numero_serie'],
                      ),
                      AppDetailLine(
                        label: 'Valor de aquisição',
                        value:
                            'R\$ ${details['valor_aquisicao'] ?? details['valor'] ?? '—'}',
                      ),
                      AppDetailLine(
                        label: 'Nota fiscal',
                        value: details['nota_fiscal'],
                      ),
                      AppDetailLine(
                        label: 'Data de entrada',
                        value: shortDate(details['data_entrada']),
                      ),
                      AppDetailLine(
                        label: 'Conservação',
                        value: details['estado_conservacao'],
                      ),
                      AppDetailLine(
                        label: 'Local atual',
                        value:
                            '${details['predio_nome'] ?? '—'} • ${details['andar_identificacao'] ?? '—'} • ${details['sala_nome'] ?? '—'}',
                      ),
                    ],
                  ),
                ),
                const AppSectionHeader(title: 'Histórico de movimentações'),
                if (history.isEmpty)
                  Text(
                    'Sem movimentações registradas.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                for (final raw in history)
                  AppListCard(
                    leading: const AppIconBadge(
                      icon: Icons.swap_horiz,
                      size: 36,
                    ),
                    title:
                        '${raw['setor_origem_nome'] ?? 'Origem inicial'} → ${raw['setor_destino_nome'] ?? ''}',
                    subtitle:
                        '${shortDate(raw['data_movimentacao'])} • ${raw['justificativa'] ?? ''}',
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) showAppMessage(context, '$e');
    }
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
        return const AppLoading(label: 'Carregando bens...');
      }
      if (snapshot.hasError) {
        return AppErrorState(
          title: 'Erro ao carregar bens',
          description: '${snapshot.error}',
          onRetry: _reloadData,
        );
      }
      final assets = snapshot.data![0];
      final categories = snapshot.data![1];
      final term = _query.toLowerCase();
      final filtered = assets.where((item) {
        final matchesText =
            '${item['nome']} ${item['codigo_tombamento']} ${item['marca'] ?? ''}'
                .toLowerCase()
                .contains(term);
        final matchesStatus =
            _statusFilter == null || item['status'] == _statusFilter;
        return matchesText && matchesStatus;
      }).toList();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchController,
                    hint: 'Buscar nome ou tombo',
                    onSubmitted: (_) => _applySearch(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  tooltip: 'Novo bem',
                  onPressed: () => _editAsset(categories),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Filtrar por status',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos os status'),
                ),
                for (final status in assetStatuses)
                  DropdownMenuItem<String>(value: status, child: Text(status)),
              ],
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const AppEmptyState(title: 'Nenhum bem encontrado')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final asset = Map<String, dynamic>.from(filtered[index]);
                      final value =
                          asset['valor_aquisicao'] ?? asset['valor'] ?? 0;
                      final status = '${asset['status'] ?? ''}';
                      return AppListCard(
                        leading: const AppIconBadge(
                          icon: Icons.inventory_2_outlined,
                        ),
                        title: '${asset['nome'] ?? ''}',
                        subtitle:
                            '${asset['codigo_tombamento']} • ${asset['marca'] ?? ''} ${asset['modelo'] ?? ''}\nR\$ $value',
                        onTap: () => _showDetails(asset),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppStatusChip(
                              label: status,
                              color: assetStatusColor(status),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _editAsset(categories, asset);
                                }
                                if (action == 'toggle') _toggleActive(asset);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    asset['ativo'] == true
                                        ? 'Dar baixa'
                                        : 'Reativar',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}
