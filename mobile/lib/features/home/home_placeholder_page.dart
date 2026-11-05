import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/services/session_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/app_nav_drawer.dart';
import '../../core/widgets/app_states.dart';
import '../admin/admin_dashboard_page.dart';
import '../server_config/server_config_page.dart';

enum HomeTab {
  pendentes,
  bens,
  categorias,
  setores,
  responsaveis,
  movimentacoes,
  relatorios,
}

class HomeMenuItem {
  const HomeMenuItem(this.label, this.icon, this.contentTab);

  final String label;
  final IconData icon;
  final HomeTab contentTab;
}

/// Módulos liberados por perfil. A ocultação é só conveniência de interface:
/// a API valida as permissões e recusa acessos indevidos.
List<HomeMenuItem> menuForRole(String? role) => switch (role) {
  'agente_campo' => const [
    HomeMenuItem('Leitura', Icons.qr_code_scanner, HomeTab.bens),
    HomeMenuItem('Conferência', Icons.fact_check_outlined, HomeTab.bens),
    HomeMenuItem(
      'Movimentação',
      Icons.swap_horiz_outlined,
      HomeTab.movimentacoes,
    ),
    HomeMenuItem('Inventário', Icons.inventory_2_outlined, HomeTab.bens),
    HomeMenuItem('Sincronização', Icons.sync, HomeTab.relatorios),
  ],
  'responsavel_setor' => const [
    HomeMenuItem(
      'Autorizações pendentes',
      Icons.move_to_inbox_outlined,
      HomeTab.pendentes,
    ),
    HomeMenuItem(
      'Acervo sob sua guarda',
      Icons.inventory_2_outlined,
      HomeTab.bens,
    ),
  ],
  'auditor' => const [
    HomeMenuItem('Bens', Icons.inventory_2_outlined, HomeTab.bens),
    HomeMenuItem('Categorias', Icons.category_outlined, HomeTab.categorias),
    HomeMenuItem('Setores', Icons.business_outlined, HomeTab.setores),
    HomeMenuItem('Responsáveis', Icons.people_outline, HomeTab.responsaveis),
    HomeMenuItem(
      'Movimentações',
      Icons.swap_horiz_outlined,
      HomeTab.movimentacoes,
    ),
  ],
  _ => const <HomeMenuItem>[],
};

String roleLabel(String? role) => perfilLabel(role);

class HomePlaceholderPage extends StatefulWidget {
  const HomePlaceholderPage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<HomePlaceholderPage> createState() => _HomePlaceholderPageState();
}

class _HomePlaceholderPageState extends State<HomePlaceholderPage> {
  int _currentMenuIndex = 0;

  Future<List<dynamic>> _fetchBens() => ApiClient.get('/bem/');
  Future<List<dynamic>> _fetchCategorias() => ApiClient.get('/categoria/');
  Future<List<dynamic>> _fetchSetores() => ApiClient.get('/setores/');
  Future<List<dynamic>> _fetchResponsaveis() => ApiClient.get('/responsavel/');
  Future<List<dynamic>> _fetchMovimentacoes() =>
      ApiClient.get('/movimentacao/detailed/');
  Future<List<dynamic>> _fetchPendentes() =>
      ApiClient.get('/movimentacao/pendentes');

  /// Aprovação ou recusa de uma solicitação. A API valida a autorização:
  /// esta tela só mostra o resultado devolvido pelo servidor.
  Future<void> _decidir(int id, {required bool aprovar}) async {
    final confirmado = await confirmAction(
      context,
      aprovar
          ? 'Autorizar esta movimentação do almoxarifado?'
          : 'Recusar esta solicitação?',
    );
    if (!confirmado || !mounted) return;
    try {
      await ApiClient.post(
        '/movimentacao/$id/${aprovar ? 'aprovar' : 'recusar'}',
        {},
      );
      if (mounted)
        showAppMessage(
          context,
          aprovar ? 'Movimentação autorizada.' : 'Solicitação recusada.',
        );
    } catch (e) {
      if (mounted) showAppMessage(context, '$e');
    }
    if (mounted) _retry();
  }

  void _retry() => setState(() {});

  int? _almoxId;

  @override
  void initState() {
    super.initState();
    _carregarAlmoxarifado();
  }

  Future<void> _carregarAlmoxarifado() async {
    try {
      final setores = await ApiClient.get('/setores/');
      final almox = setores.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['flag_almoxarifado'] == true,
        orElse: () => <String, dynamic>{},
      );
      if (mounted && almox['id'] != null) {
        setState(() => _almoxId = almox['id'] as int);
      }
    } catch (_) {
      // Sem o almoxarifado carregado, as ações de decisão ficam indisponíveis.
    }
  }

  bool get _podeDecidir =>
      _almoxId != null && widget.profile['setor_id'] == _almoxId;

  Future<void> _abrirSolicitacao() async {
    final setorUsuario = widget.profile['setor_id'] as int?;
    if (_almoxId == null || setorUsuario == null) {
      showAppMessage(
        context,
        'Seu setor ou o almoxarifado ainda não foi definido.',
      );
      return;
    }
    final bem = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: ApiClient.get('/bem/setor/$_almoxId'),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: AppLoading(label: 'Buscando bens do almoxarifado...'),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 240,
                child: AppErrorState(
                  title: 'Erro ao carregar bens',
                  description: '${snapshot.error}',
                ),
              );
            }
            final bens = snapshot.data ?? [];
            if (bens.isEmpty) {
              return const SizedBox(
                height: 240,
                child: AppEmptyState(
                  title: 'Nenhum bem no almoxarifado',
                  description: 'Não há bens disponíveis para solicitar.',
                ),
              );
            }
            return ListView(
              shrinkWrap: true,
              padding: AppSpacing.screen,
              children: [
                const AppSectionHeader(title: 'Escolha o bem para o seu setor'),
                for (final raw in bens)
                  AppListCard(
                    leading: const AppIconBadge(
                      icon: Icons.inventory_2_outlined,
                    ),
                    title: '${raw['nome'] ?? ''}',
                    subtitle: '${raw['codigo_tombamento'] ?? ''}',
                    onTap: () =>
                        Navigator.pop(ctx, Map<String, dynamic>.from(raw)),
                  ),
              ],
            );
          },
        ),
      ),
    );
    if (bem == null || !mounted) return;
    try {
      await ApiClient.post('/movimentacao/', {
        'bem_id': bem['id'],
        'setor_origem_id': _almoxId,
        'setor_destino_id': setorUsuario,
      });
      if (mounted)
        showAppMessage(context, 'Solicitação enviada ao almoxarifado.');
    } catch (e) {
      if (mounted) showAppMessage(context, '$e');
    }
    if (mounted) _retry();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.profile['perfil']?.toString();
    if (role == 'setor_patrimonio') {
      return AdminDashboardPage(profile: widget.profile);
    }

    final items = menuForRole(role);
    final hasItems = items.isNotEmpty;
    final index = hasItems ? _currentMenuIndex.clamp(0, items.length - 1) : 0;
    final title = hasItems ? items[index].label : 'Acesso indisponível';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: AppStatusChip(
                label: roleLabel(role),
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
      drawer: AppNavDrawer(
        userName:
            widget.profile['nome']?.toString() ??
            widget.profile['username']?.toString() ??
            'Usuário',
        items: [
          for (var i = 0; i < items.length; i++)
            AppNavItem(
              label: items[i].label,
              icon: items[i].icon,
              selected: index == i,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentMenuIndex = i);
              },
            ),
        ],
        onSettings: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, ServerConfigPage.routeName);
        },
        onLogout: () async {
          await SessionManager.logout();
          if (!context.mounted) return;
          Navigator.pop(context);
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        },
        footer: const Column(
          children: [
            Text(
              'PatriFlow v1.0.0 (API Conectada)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.navMuted,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'José • Pedro • Guilherme',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.navFaint),
            ),
          ],
        ),
      ),
      body: hasItems
          ? _buildTab(items[index].contentTab)
          : const AppEmptyState(
              title: 'Perfil sem módulos',
              description: 'Solicite ao setor de patrimônio a revisão do seu perfil de acesso.',
            ),
    );
  }

  Widget _buildTab(HomeTab tab) => switch (tab) {
    HomeTab.pendentes => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _abrirSolicitacao,
              icon: const Icon(Icons.add),
              label: const Text('Solicitar bem do almoxarifado'),
            ),
          ),
        ),
        Expanded(
          child: _ListTab(
            load: _fetchPendentes,
            loadingLabel: 'Buscando solicitações...',
            errorTitle: 'Erro ao carregar solicitações',
            emptyTitle: 'Nenhuma autorização pendente',
            emptyDescription: 'As solicitações do seu setor e as que aguardam o almoxarifado aparecem aqui.',
            onRetry: _retry,
            itemBuilder: _pendingCard,
          ),
        ),
      ],
    ),
    HomeTab.bens => _ListTab(
      load: _fetchBens,
      loadingLabel: 'Buscando bens do banco de dados...',
      errorTitle: 'Erro ao carregar bens',
      emptyTitle: 'Nenhum bem cadastrado',
      emptyDescription: 'O banco de dados não retornou bens cadastrados.',
      onRetry: _retry,
      itemBuilder: _assetCard,
    ),
    HomeTab.categorias => _ListTab(
      load: _fetchCategorias,
      loadingLabel: 'Buscando categorias do servidor...',
      errorTitle: 'Erro ao carregar categorias',
      emptyTitle: 'Nenhuma categoria',
      emptyDescription: 'Nenhuma categoria encontrada no banco de dados.',
      onRetry: _retry,
      itemBuilder: (cat) => AppListCard(
        leading: SiglaBadge('${cat['sigla'] ?? 'CAT'}'),
        title: '${cat['nome'] ?? ''}',
        subtitle: 'ID ${cat['id']}',
      ),
    ),
    HomeTab.setores => _ListTab(
      load: _fetchSetores,
      loadingLabel: 'Buscando setores do servidor...',
      errorTitle: 'Erro ao carregar setores',
      emptyTitle: 'Nenhum setor',
      emptyDescription: 'Nenhum setor encontrado no banco de dados.',
      onRetry: _retry,
      itemBuilder: (set) => AppListCard(
        leading: const AppIconBadge(icon: Icons.business_outlined),
        title: '${set['nome'] ?? ''}',
        subtitle:
            'Local: ${set['predio_nome'] ?? '—'} — ${set['andar_identificacao'] ?? '—'} — ${set['sala_nome'] ?? '—'}\nResponsável: ${set['responsavel_nome'] ?? 'Não definido'}',
      ),
    ),
    HomeTab.responsaveis => _ListTab(
      load: _fetchResponsaveis,
      loadingLabel: 'Buscando responsáveis do servidor...',
      errorTitle: 'Erro ao carregar responsáveis',
      emptyTitle: 'Nenhum responsável',
      emptyDescription: 'Nenhum responsável encontrado no banco de dados.',
      onRetry: _retry,
      itemBuilder: (resp) => AppListCard(
        leading: const AppIconBadge(icon: Icons.person_outline),
        title: '${resp['nome'] ?? ''}',
        subtitle:
            '${resp['cargo'] ?? ''} • Matrícula: ${resp['matricula'] ?? ''}',
      ),
    ),
    HomeTab.movimentacoes => _ListTab(
      load: _fetchMovimentacoes,
      loadingLabel: 'Buscando movimentações do servidor...',
      errorTitle: 'Erro ao carregar movimentações',
      emptyTitle: 'Nenhuma movimentação',
      emptyDescription: 'Nenhum registro de movimentação encontrado.',
      onRetry: _retry,
      itemBuilder: _movementCard,
    ),
    HomeTab.relatorios => const AppEmptyState(
      title: 'Relatórios',
      description:
          'Módulo de Relatórios conectado ao Banco de Dados do Servidor.',
    ),
  };

  Widget _assetCard(Map<String, dynamic> bem) {
    final codigo = bem['codigo_tombamento'] ?? 'N/D';
    final nome = bem['nome'] ?? 'Sem Nome';
    final valor = (bem['valor_aquisicao'] ?? bem['valor'] ?? 0).toDouble();
    final marcaModelo = [
      bem['marca'],
      bem['modelo'],
    ].where((value) => value != null && value.toString().isNotEmpty).join(' ');
    final numeroSerie = bem['numero_serie'];
    final conservacao = bem['estado_conservacao'] ?? 'novo';
    final status = '${bem['status'] ?? 'Em Uso'}';

    final details = [
      if (marcaModelo.isNotEmpty) marcaModelo,
      if (numeroSerie != null && numeroSerie.toString().isNotEmpty)
        'Série: $numeroSerie',
    ].join(' • ');

    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusChip(label: '$codigo', color: AppColors.primary),
              const Spacer(),
              AppStatusChip(label: status, color: assetStatusColor(status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('$nome', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'R\$ ${valor.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: AppColors.primary),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(details, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Conservação: $conservacao',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> mov) {
    final id = mov['id'] as int;
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${mov['bem_nome'] ?? ''}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              AppStatusChip(label: 'Pendente', color: AppColors.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${mov['codigo_tombamento'] ?? ''} • ${shortDate(mov['data_movimentacao'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${mov['setor_origem_nome'] ?? 'Origem não informada'} → ${mov['setor_destino_nome'] ?? ''}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (!_podeDecidir)
            Text(
              'Aguardando a autorização do responsável do almoxarifado.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decidir(id, aprovar: false),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => _decidir(id, aprovar: true),
                    child: const Text('Autorizar'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _movementCard(Map<String, dynamic> mov) => AppListCard(
    leading: const AppIconBadge(icon: Icons.swap_horiz_outlined),
    title: '${mov['bem_nome'] ?? ''}',
    subtitle:
        '${mov['codigo_tombamento'] ?? ''} • ${shortDate(mov['data_movimentacao'])}\n'
        'Origem: ${mov['setor_origem_nome'] ?? 'Depósito'} → Destino: ${mov['setor_destino_nome'] ?? ''}'
        '${mov['justificativa'] != null ? '\nJustificativa: ${mov['justificativa']}' : ''}',
  );
}

/// Lista genérica com carregamento, erro e estado vazio padronizados.
class _ListTab extends StatelessWidget {
  const _ListTab({
    required this.load,
    required this.loadingLabel,
    required this.errorTitle,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onRetry,
    required this.itemBuilder,
  });

  final Future<List<dynamic>> Function() load;
  final String loadingLabel;
  final String errorTitle;
  final String emptyTitle;
  final String emptyDescription;
  final VoidCallback onRetry;
  final Widget Function(Map<String, dynamic> item) itemBuilder;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: load(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return AppLoading(label: loadingLabel);
      }
      if (snapshot.hasError) {
        return AppErrorState(
          title: errorTitle,
          description: '${snapshot.error}',
          onRetry: onRetry,
        );
      }
      final items = snapshot.data ?? [];
      if (items.isEmpty) {
        return AppEmptyState(title: emptyTitle, description: emptyDescription);
      }
      return ListView.builder(
        padding: AppSpacing.screen,
        itemCount: items.length,
        itemBuilder: (context, index) =>
            itemBuilder(Map<String, dynamic>.from(items[index])),
      );
    },
  );
}
