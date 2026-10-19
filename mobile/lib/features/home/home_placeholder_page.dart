import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/services/session_manager.dart';
import 'admin_dashboard_page.dart';
import '../server_config/server_config_page.dart';

class HomeMenuItem {
  const HomeMenuItem(this.label, this.icon, this.contentTab);
  final String label;
  final IconData icon;
  final HomeTab contentTab;
}

enum HomeTab {
  bens('Bens', Icons.inventory_2_outlined),
  categorias('Categorias', Icons.category_outlined),
  setores('Setores', Icons.business_outlined),
  responsaveis('Responsáveis', Icons.people_outline),
  movimentacoes('Movimentações', Icons.swap_horiz_outlined),
  relatorios('Relatórios', Icons.analytics_outlined);

  const HomeTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class HomePlaceholderPage extends StatefulWidget {
  const HomePlaceholderPage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<HomePlaceholderPage> createState() => _HomePlaceholderPageState();
}

class _HomePlaceholderPageState extends State<HomePlaceholderPage> {
  HomeTab _currentTab = HomeTab.bens;
  int _currentMenuIndex = 0;

  Future<List<dynamic>> _fetchBens() => ApiClient.get('/bem/');
  Future<List<dynamic>> _fetchCategorias() => ApiClient.get('/categoria/');
  Future<List<dynamic>> _fetchSetores() => ApiClient.get('/setores/');
  Future<List<dynamic>> _fetchResponsaveis() => ApiClient.get('/responsavel/');
  Future<List<dynamic>> _fetchMovimentacoes() =>
      ApiClient.get('/movimentacao/detailed/');

  @override
  Widget build(BuildContext context) {
    final role = widget.profile['perfil']?.toString();
    if (role == 'setor_patrimonio') {
      return AdminDashboardPage(profile: widget.profile);
    }
    final isPatrimonio = role == 'setor_patrimonio';
    // A ocultação destes botões é apenas conveniência de UI. A API valida as
    // permissões e recusa acessos indevidos.
    final allowedTabs = switch (role) {
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
          'Transferências Pendentes',
          Icons.move_to_inbox_outlined,
          HomeTab.movimentacoes,
        ),
        HomeMenuItem(
          'Acervo sob sua guarda',
          Icons.inventory_2_outlined,
          HomeTab.bens,
        ),
      ],
      'setor_patrimonio' => const [
        HomeMenuItem('Consulta', Icons.search, HomeTab.bens),
        HomeMenuItem('Histórico', Icons.history, HomeTab.movimentacoes),
      ],
      _ => const <HomeMenuItem>[],
    };
    final selectedMenu = allowedTabs.isEmpty
        ? const HomeMenuItem(
            'Acesso indisponível',
            Icons.lock_outline,
            HomeTab.bens,
          )
        : allowedTabs[_currentMenuIndex.clamp(0, allowedTabs.length - 1)];
    _currentTab = selectedMenu.contentTab;

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedMenu.label),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPatrimonio
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPatrimonio ? AppColors.primary : AppColors.success,
                width: 1,
              ),
            ),
            child: Text(
              roleLabel(role),
              style: TextStyle(
                color: isPatrimonio ? AppColors.primary : AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.secondary,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 38,
                    width: 145,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.profile['nome']?.toString() ??
                          widget.profile['username']?.toString() ??
                          'Usuário',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                children: [
                  ...allowedTabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final selected = _currentMenuIndex == index;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          item.icon,
                          color: selected ? Colors.white : Colors.white60,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white60,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _currentMenuIndex = index;
                            _currentTab = item.contentTab;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Colors.white24),
                  ),
                  ListTile(
                    leading: const Icon(
                      AppIcons.settings,
                      color: Colors.white60,
                    ),
                    title: const Text(
                      'Configurar servidor',
                      style: TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, ServerConfigPage.routeName);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      AppIcons.logout,
                      color: Color(0xFFFF3B30),
                    ),
                    title: const Text(
                      'Sair',
                      style: TextStyle(
                        color: Color(0xFFFF3B30),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      await SessionManager.logout();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (_) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.white.withOpacity(0.05),
              width: double.infinity,
              child: const Column(
                children: [
                  Text(
                    'PatriFlow v1.0.0 (API Conectada)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white60,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'José • Pedro • Guilherme',
                    style: TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: allowedTabs.isEmpty
          ? const AppEmptyState(
              title: 'Perfil sem módulos',
              description: 'Solicite ao setor de patrimônio a revisão do seu perfil de acesso.',
            )
          : _buildTabBody(),
    );
  }

  Widget _buildTabBody() {
    switch (_currentTab) {
      case HomeTab.bens:
        return FutureBuilder<List<dynamic>>(
          future: _fetchBens(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading(
                label: 'Buscando bens do banco de dados...',
              );
            }
            if (snapshot.hasError) {
              return AppErrorState(
                title: 'Erro ao carregar bens',
                description: '${snapshot.error}',
                onRetry: () => setState(() {}),
              );
            }
            final bens = snapshot.data ?? [];
            if (bens.isEmpty) {
              return const AppEmptyState(
                title: 'Nenhum bem cadastrado',
                description: 'O banco de dados não retornou bens cadastrados.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bens.length,
              itemBuilder: (context, index) {
                final bem = bens[index];
                final codigo = bem['codigo_tombamento'] ?? 'N/D';
                final nome = bem['nome'] ?? 'Sem Nome';
                final valor = (bem['valor_aquisicao'] ?? bem['valor'] ?? 0)
                    .toDouble();
                final marcaModelo = [bem['marca'], bem['modelo']]
                    .where(
                      (value) => value != null && value.toString().isNotEmpty,
                    )
                    .join(' ');
                final numeroSerie = bem['numero_serie'];
                final conservacao = bem['estado_conservacao'] ?? 'novo';
                final status = bem['status'] ?? 'Em Uso';
                final statusColor = _getStatusColor(status);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                codigo,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          nome,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.sell_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Valor: R\$ ${valor.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        if (marcaModelo.isNotEmpty || numeroSerie != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            [
                              if (marcaModelo.isNotEmpty) marcaModelo,
                              if (numeroSerie != null &&
                                  numeroSerie.toString().isNotEmpty)
                                'Série: $numeroSerie',
                            ].join(' • '),
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'Conservação: $conservacao',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );

      case HomeTab.categorias:
        return FutureBuilder<List<dynamic>>(
          future: _fetchCategorias(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading(
                label: 'Buscando categorias do servidor...',
              );
            }
            if (snapshot.hasError) {
              return AppErrorState(
                title: 'Erro ao carregar categorias',
                description: '${snapshot.error}',
                onRetry: () => setState(() {}),
              );
            }
            final categorias = snapshot.data ?? [];
            if (categorias.isEmpty) {
              return const AppEmptyState(
                title: 'Nenhuma categoria',
                description: 'Nenhuma categoria encontrada no banco de dados.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categorias.length,
              itemBuilder: (context, index) {
                final cat = categorias[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        cat['sigla'] ?? 'CAT',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      cat['nome'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('ID: ${cat['id']}'),
                  ),
                );
              },
            );
          },
        );

      case HomeTab.setores:
        return FutureBuilder<List<dynamic>>(
          future: _fetchSetores(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading(label: 'Buscando setores do servidor...');
            }
            if (snapshot.hasError) {
              return AppErrorState(
                title: 'Erro ao carregar setores',
                description: '${snapshot.error}',
                onRetry: () => setState(() {}),
              );
            }
            final setores = snapshot.data ?? [];
            if (setores.isEmpty) {
              return const AppEmptyState(
                title: 'Nenhum setor',
                description: 'Nenhum setor encontrado no banco de dados.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: setores.length,
              itemBuilder: (context, index) {
                final set = setores[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.business,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      set['nome'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    isThreeLine: true,
                    subtitle: Text(
                      'Local: ${set['predio_nome'] ?? '—'} — ${set['andar_identificacao'] ?? '—'} — ${set['sala_nome'] ?? '—'}\n'
                      'Responsável: ${set['responsavel_nome'] ?? 'Não definido'}',
                    ),
                  ),
                );
              },
            );
          },
        );

      case HomeTab.responsaveis:
        return FutureBuilder<List<dynamic>>(
          future: _fetchResponsaveis(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading(
                label: 'Buscando responsáveis do servidor...',
              );
            }
            if (snapshot.hasError) {
              return AppErrorState(
                title: 'Erro ao carregar responsáveis',
                description: '${snapshot.error}',
                onRetry: () => setState(() {}),
              );
            }
            final responsaveis = snapshot.data ?? [];
            if (responsaveis.isEmpty) {
              return const AppEmptyState(
                title: 'Nenhum responsável',
                description: 'Nenhum responsável encontrado no banco de dados.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: responsaveis.length,
              itemBuilder: (context, index) {
                final resp = responsaveis[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.person, color: AppColors.primary),
                    title: Text(
                      resp['nome'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${resp['cargo'] ?? ''} • Matrícula: ${resp['matricula'] ?? ''}',
                    ),
                  ),
                );
              },
            );
          },
        );

      case HomeTab.movimentacoes:
        return FutureBuilder<List<dynamic>>(
          future: _fetchMovimentacoes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading(
                label: 'Buscando movimentações do servidor...',
              );
            }
            if (snapshot.hasError) {
              return AppErrorState(
                title: 'Erro ao carregar movimentações',
                description: '${snapshot.error}',
                onRetry: () => setState(() {}),
              );
            }
            final movimentacoes = snapshot.data ?? [];
            if (movimentacoes.isEmpty) {
              return const AppEmptyState(
                title: 'Nenhuma movimentação',
                description: 'Nenhum registro de movimentação encontrado.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: movimentacoes.length,
              itemBuilder: (context, index) {
                final mov = movimentacoes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              mov['codigo_tombamento'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              mov['data_movimentacao'] != null
                                  ? mov['data_movimentacao']
                                        .toString()
                                        .substring(0, 10)
                                  : '',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mov['bem_nome'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Origem: ${mov['setor_origem_nome'] ?? 'Depósito'} ➔ Destino: ${mov['setor_destino_nome'] ?? ''}',
                        ),
                        if (mov['justificativa'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Justificativa: ${mov['justificativa']}',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );

      case HomeTab.relatorios:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Módulo de Relatórios conectado ao Banco de Dados do Servidor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Em Uso':
        return AppColors.success;
      case 'Em Manutenção':
        return Colors.orange;
      case 'Baixado':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  String roleLabel(String? role) => switch (role) {
    'agente_campo' => 'Agente de Campo',
    'responsavel_setor' => 'Responsável de Setor',
    'setor_patrimonio' => 'Setor de Patrimônio',
    _ => 'Perfil não reconhecido',
  };
}
