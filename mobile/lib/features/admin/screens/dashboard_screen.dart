import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: Future.wait([ApiClient.get('/bem/'), ApiClient.get('/categoria/')]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AppLoading(label: 'Carregando painel...');
      }
      if (snapshot.hasError) {
        return AppErrorState(
          title: 'Erro ao carregar painel',
          description: '${snapshot.error}',
        );
      }
      final assets = snapshot.data![0];
      final categoryNames = {
        for (final item in snapshot.data![1])
          '${item['id']}': '${item['nome']}',
      };
      final active = assets.where((item) => item['ativo'] == true).length;
      final inactive = assets.length - active;
      final categories = <String, int>{};
      final statuses = <String, int>{};
      for (final item in assets) {
        final key = categoryNames['${item['id_categoria']}'] ?? 'Sem categoria';
        categories.update(key, (n) => n + 1, ifAbsent: () => 1);
        final status = '${item['status'] ?? 'Sem status'}';
        statuses.update(status, (n) => n + 1, ifAbsent: () => 1);
      }
      final recent = assets.reversed.take(5).toList();

      return ListView(
        padding: AppSpacing.screen,
        children: [
          Text(
            'Visão geral do patrimônio',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.05,
            children: [
              AppMetricTile(
                label: 'Total de itens',
                value: '${assets.length}',
                icon: Icons.inventory_2_outlined,
              ),
              AppMetricTile(
                label: 'Itens ativos',
                value: '$active',
                icon: Icons.check_circle_outline,
              ),
              AppMetricTile(
                label: 'Itens inativos',
                value: '$inactive',
                icon: Icons.archive_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          CountPanel(title: 'Distribuição por categoria', counts: categories),
          const SizedBox(height: AppSpacing.md),
          CountPanel(title: 'Distribuição por status', counts: statuses),
          const AppSectionHeader(title: 'Últimos registros'),
          if (recent.isEmpty)
            const Text('Nenhum bem cadastrado ainda.')
          else
            for (final asset in recent)
              AppListCard(
                leading: const AppIconBadge(icon: Icons.inventory_2_outlined),
                title: '${asset['nome'] ?? 'Bem'}',
                subtitle: '${asset['codigo_tombamento'] ?? ''}',
                trailing: AppStatusChip(
                  label: '${asset['status'] ?? 'Sem status'}',
                  color: assetStatusColor('${asset['status'] ?? ''}'),
                ),
              ),
        ],
      );
    },
  );
}

/// Painel com contagens agrupadas (categoria ou status).
class CountPanel extends StatelessWidget {
  const CountPanel({super.key, required this.title, required this.counts});

  final String title;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) => AppPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        if (counts.isEmpty)
          Text('Sem dados', style: Theme.of(context).textTheme.bodySmall)
        else
          for (final entry in counts.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${entry.value}',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}
