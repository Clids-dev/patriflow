import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_components.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label = 'Carregando...'});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(strokeWidth: 2.5),
        const SizedBox(height: AppSpacing.lg),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Não foi possível concluir esta ação',
    this.description,
    this.onRetry,
  });

  final String title;
  final String? description;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _StateLayout(
    icon: AppIcons.error,
    color: AppColors.error,
    title: title,
    description: description,
    action: onRetry == null
        ? null
        : OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.retry, size: 18),
            label: const Text('Tentar novamente'),
          ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.title = 'Nada para mostrar',
    this.description,
    this.action,
  });

  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _StateLayout(
    icon: AppIcons.empty,
    color: AppColors.primary,
    title: title,
    description: description,
    action: action,
  );
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.color,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconBadge(icon: icon, color: color, size: 64),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.xl),
            action!,
          ],
        ],
      ),
    ),
  );
}
