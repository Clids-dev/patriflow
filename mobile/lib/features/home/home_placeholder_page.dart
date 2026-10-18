import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../auth/login_page.dart';
import '../server_config/server_config_page.dart';

enum AppRole { admin, common }

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
  const HomePlaceholderPage({super.key, required this.role});

  static const adminRoute = '/area-admin';
  static const commonRoute = '/area-comum';
  final AppRole role;

  @override
  State<HomePlaceholderPage> createState() => _HomePlaceholderPageState();
}

class _HomePlaceholderPageState extends State<HomePlaceholderPage> {
  HomeTab _currentTab = HomeTab.bens;

  Future<List<dynamic>> _fetchBens() => ApiClient.get('/bem/');
  Future<List<dynamic>> _fetchCategorias() => ApiClient.get('/categoria/');
  Future<List<dynamic>> _fetchSetores() => ApiClient.get('/setor/');
  Future<List<dynamic>> _fetchResponsaveis() => ApiClient.get('/responsavel/');
  Future<List<dynamic>> _fetchMovimentacoes() => ApiClient.get('/movimentacao/detailed/');

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == AppRole.admin;
    
    final allowedTabs = isAdmin 
        ? HomeTab.values 
        : [HomeTab.bens, HomeTab.movimentacoes];

    if (!allowedTabs.contains(_currentTab)) {
      _currentTab = allowedTabs.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTab.label),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAdmin 
                  ? AppColors.primary.withOpacity(0.1) 
                  : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAdmin ? AppColors.primary : AppColors.success,
                width: 1,
              ),
            ),
            child: Text(
              isAdmin ? 'Administrador' : 'Consulta',
              style: TextStyle(
                color: isAdmin ? AppColors.primary : AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              currentAccountPicture: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.brand,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
              accountName: Text(
                isAdmin ? 'Administrador PatriFlow' : 'Operador de Consulta',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: Text(
                isAdmin ? 'admin@patriflow.com.br' : 'consulta@patriflow.com.br',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text(
                      'MÓDULOS DE GESTÃO (SERVIDOR)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  ...allowedTabs.map((tab) => ListTile(
                    leading: Icon(
                      tab.icon,
                      color: _currentTab == tab ? AppColors.primary : Colors.black87,
                    ),
                    title: Text(
                      tab.label,
                      style: TextStyle(
                        fontWeight: _currentTab == tab ? FontWeight.bold : FontWeight.normal,
                        color: _currentTab == tab ? AppColors.primary : Colors.black87,
                      ),
                    ),
                    selected: _currentTab == tab,
                    selectedTileColor: AppColors.primary.withOpacity(0.08),
                    onTap: () {
                      setState(() => _currentTab = tab);
                      Navigator.of(context).pop();
                    },
                  )),
                  const Divider(),
                  ListTile(
                    leading: const Icon(AppIcons.settings),
                    title: const Text('Configurar Servidor'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(ServerConfigPage.routeName);
                    },
                  ),
                  ListTile(
                    leading: const Icon(AppIcons.logout, color: AppColors.error),
                    title: const Text('Sair do Aplicativo', style: TextStyle(color: AppColors.error)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil(LoginPage.routeName, (_) => false);
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.grey.withOpacity(0.05),
              width: double.infinity,
              child: const Column(
                children: [
                  Text(
                    'PatriFlow v1.0.0 (API Conectada)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'José • Pedro • Guilherme',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _buildTabBody(isAdmin),
    );
  }

  Widget _buildTabBody(bool isAdmin) {
    switch (_currentTab) {
      case HomeTab.bens:
        return FutureBuilder<List<dynamic>>(
          future: _fetchBens(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading(label: 'Buscando bens do banco de dados...');
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
                final valor = (bem['valor'] ?? 0).toDouble();
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.sell_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Valor: R\$ ${valor.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                          ],
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
              return const AppLoading(label: 'Buscando categorias do servidor...');
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
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    title: Text(cat['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    leading: const Icon(Icons.business, color: AppColors.primary),
                    title: Text(set['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Responsável: ${set['responsavel_nome'] ?? 'Não definido'}'),
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
              return const AppLoading(label: 'Buscando responsáveis do servidor...');
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
                    title: Text(resp['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${resp['cargo'] ?? ''} • Matrícula: ${resp['matricula'] ?? ''}'),
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
              return const AppLoading(label: 'Buscando movimentações do servidor...');
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
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                            Text(
                              mov['data_movimentacao'] != null ? mov['data_movimentacao'].toString().substring(0, 10) : '',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(mov['bem_nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Origem: ${mov['setor_origem_nome'] ?? 'Depósito'} ➔ Destino: ${mov['setor_destino_nome'] ?? ''}'),
                        if (mov['justificativa'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Justificativa: ${mov['justificativa']}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
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
}
