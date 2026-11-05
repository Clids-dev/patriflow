import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/app_states.dart';

/// Acervo em modo leitura (sem cadastro, edição ou baixa).
class BensLeituraPage extends StatefulWidget {
  const BensLeituraPage({super.key});

  @override
  State<BensLeituraPage> createState() => _BensLeituraPageState();
}

class _BensLeituraPageState extends State<BensLeituraPage> {
  late Future<List<dynamic>> _future = ApiClient.get('/bem/');

  Future<void> _recarregar() async {
    setState(() => _future = ApiClient.get('/bem/'));
    await _future;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _recarregar,
    child: FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(label: 'Buscando bens...');
        }
        if (snapshot.hasError) {
          return ListView(
            children: [
              AppErrorState(
                title: 'Erro ao carregar bens',
                description: '${snapshot.error}',
                onRetry: _recarregar,
              ),
            ],
          );
        }
        final bens = snapshot.data ?? [];
        if (bens.isEmpty) {
          return ListView(
            children: const [
              AppEmptyState(
                title: 'Nenhum bem cadastrado',
                description: 'O acervo aparece aqui quando houver bens cadastrados.',
              ),
            ],
          );
        }
        return ListView.builder(
          padding: AppSpacing.screen,
          itemCount: bens.length,
          itemBuilder: (context, index) =>
              BemCard(bem: Map<String, dynamic>.from(bens[index] as Map)),
        );
      },
    ),
  );
}

/// Cartão de um bem: tombo, status, nome, valor e dados de identificação.
class BemCard extends StatelessWidget {
  const BemCard({super.key, required this.bem});

  final Map<String, dynamic> bem;

  @override
  Widget build(BuildContext context) {
    final codigo = bem['codigo_tombamento'] ?? 'N/D';
    final nome = bem['nome'] ?? 'Sem Nome';
    final valor = (bem['valor_aquisicao'] ?? bem['valor'] ?? 0).toDouble();
    final marcaModelo = [
      bem['marca'],
      bem['modelo'],
    ].where((value) => value != null && value.toString().isNotEmpty).join(' ');
    final numeroSerie = bem['numero_serie'];
    final conservacao = bem['estado_conservacao'] ?? 'novo';
    final status = '${bem['status'] ?? 'Em Uso'}';

    final details = [
      if (marcaModelo.isNotEmpty) marcaModelo,
      if (numeroSerie != null && numeroSerie.toString().isNotEmpty)
        'Série: $numeroSerie',
    ].join(' • ');

    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusChip(label: '$codigo', color: AppColors.primary),
              const Spacer(),
              AppStatusChip(label: status, color: assetStatusColor(status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('$nome', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'R\$ ${valor.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: AppColors.primary),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(details, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Conservação: $conservacao',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
