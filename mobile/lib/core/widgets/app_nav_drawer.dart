import 'package:flutter/material.dart';

import '../navigation/shell_item.dart';
import '../theme/app_theme.dart';

/// Menu lateral no mesmo padrão da barra lateral da web: fundo roxo escuro,
/// logo centralizada com o subtítulo, seção "Menu" e item ativo em roxo.
class AppNavDrawer extends StatelessWidget {
  const AppNavDrawer({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSettings,
    required this.onLogout,
    required this.onOpenSub,
  });

  final List<ShellItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  /// Abre um subitem (ex.: Categorias) direto, sem passar pela tela do item pai.
  final ValueChanged<ShellItem> onOpenSub;

  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: AppColors.secondary,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Image.asset(
              'assets/logo.png',
              width: 144,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Sistema de Tombamento',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.navMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.navDivider, height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text(
              'MENU',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.navFaint,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                for (var i = 0; i < items.length; i++)
                  _NavTile(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(i);
                    },
                    onOpenSub: (sub) {
                      Navigator.pop(context);
                      onOpenSub(sub);
                    },
                  ),
              ],
            ),
          ),
          const Divider(color: AppColors.navDivider, height: 1),
          _ActionTile(
            icon: Icons.settings_outlined,
            label: 'Configurar servidor',
            color: AppColors.navMuted,
            onTap: () {
              Navigator.pop(context);
              onSettings();
            },
          ),
          _ActionTile(
            icon: Icons.logout,
            label: 'Sair',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onOpenSub,
  });

  final ShellItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<ShellItem> onOpenSub;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = widget.selected;
    final temSubitens = item.subitens.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Material(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadius.controlBorder,
            child: InkWell(
              borderRadius: AppRadius.controlBorder,
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.xs,
                  top: AppSpacing.md,
                  bottom: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      color: selected ? Colors.white : AppColors.navMuted,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? Colors.white : AppColors.navMuted,
                        ),
                      ),
                    ),
                    if (temSubitens)
                      IconButton(
                        tooltip: _expandido ? 'Recolher' : 'Expandir',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _expandido = !_expandido),
                        icon: AnimatedRotation(
                          turns: _expandido ? .5 : 0,
                          duration: AppMotion.fast,
                          child: Icon(
                            Icons.expand_more,
                            color: selected ? Colors.white : AppColors.navMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (temSubitens && _expandido)
          for (final sub in item.subitens)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xxl,
                bottom: AppSpacing.xs,
              ),
              child: InkWell(
                borderRadius: AppRadius.controlBorder,
                onTap: () => widget.onOpenSub(sub),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(sub.icon, color: AppColors.navMuted, size: 18),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          sub.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.navMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    ),
  );
}
