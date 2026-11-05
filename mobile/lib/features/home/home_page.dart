import 'package:flutter/material.dart';

import '../../core/navigation/app_shell.dart';
import '../../core/navigation/shell_item.dart';
import '../../core/services/api_client.dart';
import '../../core/services/session_manager.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/widgets/app_states.dart';
import '../admin/screens/assets_screen.dart';
import '../admin/screens/dashboard_screen.dart';
import '../admin/screens/estrutura_hub_page.dart';
import '../admin/screens/movements_screen.dart';
import '../admin/screens/reports_screen.dart';
import '../auth/login_page.dart';
import '../bens/bens_leitura_page.dart';
import '../bens/leitura_qr_page.dart';
import '../movimentacao/transfer_list_page.dart';
import '../server_config/server_config_page.dart';
import 'inicio_page.dart';

/// Entrada do aplicativo depois do login. Monta a casca (menu lateral e barra
/// inferior) com os módulos do perfil. A API valida cada operação; o menu só
/// esconde o que o perfil não usa.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<int?> _almoxarifado = _carregarAlmoxarifado();

  /// Id do almoxarifado único, usado nas solicitações de bens.
  Future<int?> _carregarAlmoxarifado() async {
    try {
      final setores = await ApiClient.get('/setores/');
      for (final s in setores) {
        if (s is Map && s['flag_almoxarifado'] == true) return s['id'] as int;
      }
    } catch (_) {
      // Sem o almoxarifado, as solicitações ficam indisponíveis.
    }
    return null;
  }

  Future<void> _sair() async {
    await SessionManager.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(LoginPage.routeName, (_) => false);
  }

  void _configurarServidor() =>
      Navigator.pushNamed(context, ServerConfigPage.routeName);

  String get _nome =>
      widget.profile['nome']?.toString() ??
      widget.profile['username']?.toString() ??
      'Usuário';

  List<ShellItem> _itens(int? almoxId) {
    final perfil = widget.profile['perfil']?.toString();
    final setorId = widget.profile['setor_id'] as int?;
    final podeDecidir = almoxId != null && setorId == almoxId;
    final adminId = widget.profile['id'] as int? ?? 0;

    return switch (perfil) {
      'setor_patrimonio' => [
        ShellItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          page: DashboardScreen(nome: _nome),
          bottomBar: true,
        ),
        ShellItem(
          label: 'Equipamentos',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          page: const AssetsScreen(),
          bottomBar: true,
        ),
        ShellItem(
          label: 'Estrutura',
          icon: Icons.folder_outlined,
          selectedIcon: Icons.folder,
          page: EstruturaHubPage(adminId: adminId),
          bottomBar: true,
        ),
        ShellItem(
          label: 'Movimentações',
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz,
          page: const MovementsScreen(),
          bottomBar: true,
          badge: TransferListPage.contarPendentes,
        ),
        ShellItem(
          label: 'Relatórios',
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          page: const ReportsScreen(),
        ),
      ],
      'agente_campo' => [
        ShellItem(
          label: 'Início',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          page: InicioPage(
            nome: _nome,
            perfil: perfil!,
            almoxId: almoxId,
            setorId: setorId,
          ),
          bottomBar: true,
        ),
        ShellItem(
          label: 'Minhas solicitações',
          icon: Icons.outbox_outlined,
          selectedIcon: Icons.outbox,
          page: TransferListPage(
            modo: ModoTransferencias.minhas,
            almoxId: almoxId,
            setorId: setorId,
          ),
          bottomBar: true,
        ),
        ShellItem(
          label: 'Movimentações',
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz,
          page: const TransferListPage(modo: ModoTransferencias.todas),
          bottomBar: true,
        ),
      ],
      'responsavel_setor' => [
        ShellItem(
          label: 'Início',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          page: InicioPage(
            nome: _nome,
            perfil: perfil!,
            almoxId: almoxId,
            setorId: setorId,
          ),
          bottomBar: true,
        ),
        ShellItem(
          label: 'Autorizações',
          icon: Icons.move_to_inbox_outlined,
          selectedIcon: Icons.move_to_inbox,
          page: TransferListPage(
            modo: ModoTransferencias.pendentes,
            podeDecidir: podeDecidir,
          ),
          bottomBar: true,
          badge: TransferListPage.contarPendentes,
        ),
        ShellItem(
          label: 'Minhas solicitações',
          icon: Icons.outbox_outlined,
          selectedIcon: Icons.outbox,
          page: TransferListPage(
            modo: ModoTransferencias.minhas,
            almoxId: almoxId,
            setorId: setorId,
          ),
          bottomBar: true,
        ),
        ShellItem(
          label: 'Acervo',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          page: const BensLeituraPage(),
          bottomBar: true,
        ),
      ],
      'auditor' => [
        ShellItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          page: DashboardScreen(nome: _nome, somenteLeitura: true),
          bottomBar: true,
        ),
        ShellItem(
          label: 'Movimentações',
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz,
          page: const TransferListPage(modo: ModoTransferencias.todas),
          bottomBar: true,
        ),
        ShellItem(
          label: 'Relatórios',
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          page: const ReportsScreen(),
          bottomBar: true,
        ),
      ],
      _ => const <ShellItem>[],
    };
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<int?>(
    future: _almoxarifado,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: AppLoading(label: 'Preparando o aplicativo...'),
        );
      }
      final itens = _itens(snapshot.data);
      if (itens.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('Acesso indisponível')),
          body: const AppEmptyState(
            title: 'Perfil sem módulos',
            description: 'Solicite ao setor de patrimônio a revisão do seu perfil de acesso.',
          ),
        );
      }
      return AppShell(
        items: itens,
        userName: _nome,
        perfil: perfilLabel(widget.profile['perfil']?.toString()),
        onSettings: _configurarServidor,
        onLogout: _sair,
        onScan: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeituraQrPage()),
        ),
      );
    },
  );
}
