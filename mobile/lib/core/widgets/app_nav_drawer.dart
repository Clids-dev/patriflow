import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
}

/// Gaveta lateral única usada por todos os perfis. Recebe os módulos já
/// filtrados por perfil, então a lógica de acesso continua onde estava.
class AppNavDrawer extends StatelessWidget {
  const AppNavDrawer({
    super.key,
    required this.items,
    required this.onSettings,
    required this.onLogout,
    this.userName,
    this.footer,
  });

  final List<AppNavItem> items;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final String? userName;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 36,
                  width: 140,
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.contain,
                ),
                if (userName != null && userName!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    userName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: AppColors.navDivider, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              children: [
                for (final item in items) _NavTile(item: item),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: AppSpacing.sm,
                  ),
                  child: Divider(color: AppColors.navDivider),
                ),
                _ActionTile(
                  icon: AppIcons.settings,
                  label: 'Configurar servidor',
                  color: AppColors.navMuted,
                  onTap: onSettings,
                ),
                _ActionTile(
                  icon: AppIcons.logout,
                  label: 'Sair',
                  color: AppColors.error,
                  onTap: onLogout,
                ),
              ],
            ),
          ),
          if (footer != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.navDivider)),
              ),
              child: footer,
            ),
        ],
      ),
    ),
  );
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item});

  final AppNavItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.selected ? Colors.white : AppColors.navMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: item.selected ? AppColors.primary : Colors.transparent,
        borderRadius: AppRadius.controlBorder,
        child: InkWell(
          borderRadius: AppRadius.controlBorder,
          onTap: () {
            item.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(item.icon, color: color, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: item.selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: Colors.transparent,
      borderRadius: AppRadius.controlBorder,
      child: InkWell(
        borderRadius: AppRadius.controlBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppSpacing.md),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
