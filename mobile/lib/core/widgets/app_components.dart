import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logo oficial dentro do bloco escuro da marca. A imagem já contém o nome
/// do sistema, então nunca se escreve "PatriFlow" ao lado dela.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.width = 190,
    this.height = 52,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  final double width;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: const BoxDecoration(
      color: AppColors.secondary,
      borderRadius: BorderRadius.all(Radius.circular(18)),
      boxShadow: AppShadows.brand,
    ),
    child: Image.asset(
      'assets/logo.png',
      height: height,
      width: width,
      fit: BoxFit.contain,
    ),
  );
}

/// Superfície padrão para blocos de conteúdo. Toca com feedback quando
/// recebe `onTap`.
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    ),
  );
}

/// Título de seção com ação opcional à direita.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    ),
  );
}

/// Ícone dentro de um quadrado suave em tom primário. Usado como avatar
/// em listas e métricas.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: Icon(icon, color: color, size: size * 0.5),
  );
}

/// Linha de lista padronizada: avatar, título, subtítulo e ação final.
class AppListCard extends StatelessWidget {
  const AppListCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selo colorido para status, tombo ou qualquer rótulo curto.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.sm + 2),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: -0.1,
      ),
    ),
  );
}

/// Indicador numérico para painéis.
class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => AppPanel(
    padding: const EdgeInsets.all(AppSpacing.md + 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconBadge(icon: icon, size: 34),
        const SizedBox(height: AppSpacing.md),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

/// Linha "rótulo — valor" usada em detalhes.
class AppDetailLine extends StatelessWidget {
  const AppDetailLine({super.key, required this.label, required this.value});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final text = value == null || '$value'.isEmpty ? '—' : '$value';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Campo de busca com ícone e cantos do sistema.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textInputAction: TextInputAction.search,
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
      hintText: hint,
    ),
  );
}

/// Sigla da categoria dentro de um selo quadrado.
class SiglaBadge extends StatelessWidget {
  const SiglaBadge(this.sigla, {super.key});

  final String sigla;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    child: Text(
      sigla.isEmpty ? 'CAT' : sigla,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
