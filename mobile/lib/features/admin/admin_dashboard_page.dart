import 'package:flutter/material.dart';

import '../../core/services/session_manager.dart';
import '../../core/widgets/app_nav_drawer.dart';
import '../server_config/server_config_page.dart';
import 'screens/assets_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/movements_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/responsibles_screen.dart';
import 'screens/sectors_screen.dart';
import 'screens/users_screen.dart';

enum AdminSection {
  dashboard('Dashboard', Icons.dashboard_outlined),
  bens('Bens', Icons.inventory_2_outlined),
  categorias('Categorias', Icons.category_outlined),
  setores('Setores e localização', Icons.business_outlined),
  responsaveis('Responsáveis', Icons.people_outline),
  movimentacoes('Movimentações', Icons.swap_horiz_outlined),
  relatorios('Relatórios', Icons.analytics_outlined),
  usuarios('Usuários', Icons.manage_accounts_outlined);

  const AdminSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Shell do perfil Setor de Patrimônio: barra superior, gaveta e o módulo
/// selecionado. Cada módulo fica em `screens/`.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminSection _section = AdminSection.dashboard;
  int _refresh = 0;

  void _reload() => setState(() => _refresh++);

  Future<void> _logout() async {
    await SessionManager.logout();
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_section.label),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    drawer: AppNavDrawer(
      userName:
          widget.profile['nome']?.toString() ??
          widget.profile['username']?.toString(),
      items: [
        for (final item in AdminSection.values)
          AppNavItem(
            label: item.label,
            icon: item.icon,
            selected: _section == item,
            onTap: () {
              Navigator.pop(context);
              setState(() => _section = item);
            },
          ),
      ],
      onSettings: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, ServerConfigPage.routeName);
      },
      onLogout: _logout,
    ),
    body: KeyedSubtree(
      key: ValueKey('${_section.name}-$_refresh'),
      child: switch (_section) {
        AdminSection.dashboard => const DashboardScreen(),
        AdminSection.bens => const AssetsScreen(),
        AdminSection.categorias => const CategoriesScreen(),
        AdminSection.setores => const SectorsScreen(),
        AdminSection.responsaveis => const ResponsibleScreen(),
        AdminSection.movimentacoes => const MovementsScreen(),
        AdminSection.relatorios => const ReportsScreen(),
        AdminSection.usuarios => UsersScreen(
          adminId: widget.profile['id'] as int,
        ),
      },
    ),
  );
}
