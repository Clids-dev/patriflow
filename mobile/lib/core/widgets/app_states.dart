import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.label = 'Carregando...'});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(label),
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
    icon: Icons.error_outline,
    title: title,
    description: description,
    action: onRetry == null
        ? null
        : OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
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
    icon: Icons.inventory_2_outlined,
    title: title,
    description: description,
    action: action,
  );
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(description!, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
