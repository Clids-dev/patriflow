import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_nav_drawer.dart';
import 'shell_item.dart';

/// Casca única do app para todos os perfis: barra superior, menu lateral (igual à
/// web) e barra inferior com os módulos mais usados, no estilo do Instagram.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.items,
    required this.userName,
    required this.perfil,
    required this.onSettings,
    required this.onLogout,
    required this.onScan,
  });

  final List<ShellItem> items;
  final String userName;
  final String perfil;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  /// Atalho central da barra: abre a leitura de etiqueta pela câmera.
  final VoidCallback onScan;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  static const _maxBottomItems = 4;

  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final Map<int, int> _badges = {};

  @override
  void initState() {
    super.initState();
    _carregarBadges();
  }

  /// Troca de módulo pelo nome, usado por atalhos de outras telas (ex.: "Novo patrimônio").
  void selectLabel(String label) {
    final i = widget.items.indexWhere((item) => item.label == label);
    if (i >= 0) _select(i);
  }

  void _select(int i) {
    setState(() => _index = i);
    _carregarBadges();
  }

  /// Posição k da barra: um módulo, ou espaço vazio quando o perfil tem menos módulos.
  Widget _slot(List<int> naBarra, int k, List<ShellItem> items) {
    if (k >= naBarra.length) return const SizedBox.shrink();
    final i = naBarra[k];
    return _BottomIcon(
      item: items[i],
      selected: i == _index,
      badge: _badges[i] ?? 0,
      onTap: () => _select(i),
    );
  }

  /// Subitem do menu: abre a tela com barra superior própria, sem trocar o módulo atual.
  void _abrirSubitem(ShellItem sub) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(sub.label)),
          body: sub.page,
        ),
      ),
    );
  }

  Future<void> _carregarBadges() async {
    for (var i = 0; i < widget.items.length; i++) {
      final badge = widget.items[i].badge;
      if (badge == null) continue;
      try {
        final total = await badge();
        if (mounted) setState(() => _badges[i] = total);
      } catch (_) {
        // Sem contagem, o ícone aparece sem bolinha.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final atual = items[_index];
    final naBarra = [
      for (var i = 0; i < items.length; i++)
        if (items[i].bottomBar) i,
    ].take(_maxBottomItems).toList();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          atual.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          _AvatarMenu(
            userName: widget.userName,
            perfil: widget.perfil,
            onSettings: widget.onSettings,
            onLogout: widget.onLogout,
          ),
        ],
      ),
      drawer: AppNavDrawer(
        items: items,
        selectedIndex: _index,
        onSelect: _select,
        onSettings: widget.onSettings,
        onLogout: widget.onLogout,
        onOpenSub: _abrirSubitem,
      ),
      body: atual.page,
      bottomNavigationBar: _BottomBar(
        children: [
          // Metade dos módulos à esquerda, o atalho da câmera no centro e o resto à direita.
          for (var k = 0; k < 2; k++)
            _slot(naBarra, k, items),
          _BottomIcon(
            item: null,
            label: 'Ler etiqueta',
            icon: Icons.photo_camera_outlined,
            selectedIcon: Icons.photo_camera,
            selected: false,
            badge: 0,
            onTap: widget.onScan,
          ),
          for (var k = 2; k < 4; k++)
            _slot(naBarra, k, items),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [for (final child in children) Expanded(child: child)],
        ),
      ),
    ),
  );
}

/// Ícone da barra inferior: só ícone, preenchido quando ativo, com bolinha de contagem.
class _BottomIcon extends StatelessWidget {
  const _BottomIcon({
    required this.item,
    required this.selected,
    required this.badge,
    required this.onTap,
    this.label,
    this.icon,
    this.selectedIcon,
  });

  final ShellItem? item;
  final String? label;
  final IconData? icon;
  final IconData? selectedIcon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nome = item?.label ?? label ?? '';
    final iconeAtivo = selected
        ? (item?.selectedIcon ?? selectedIcon ?? Icons.menu)
        : (item?.icon ?? icon ?? Icons.menu);
    return Semantics(
      label: nome,
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                iconeAtivo,
                size: 28,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
              if (badge > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar com as iniciais no canto superior direito, com o menu da conta (igual à web).
class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.userName,
    required this.perfil,
    required this.onSettings,
    required this.onLogout,
  });

  final String userName;
  final String perfil;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  String get _iniciais {
    final partes = userName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.md),
    child: PopupMenuButton<String>(
      tooltip: 'Conta',
      position: PopupMenuPosition.under,
      onSelected: (valor) {
        if (valor == 'config') onSettings();
        if (valor == 'sair') onLogout();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                perfil,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'config',
          child: Text('Configurar servidor'),
        ),
        const PopupMenuItem<String>(
          value: 'sair',
          child: Text('Sair', style: TextStyle(color: AppColors.error)),
        ),
      ],
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primary,
        child: Text(
          _iniciais,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
