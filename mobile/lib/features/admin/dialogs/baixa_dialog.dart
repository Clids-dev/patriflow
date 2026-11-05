import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';
import '../../movimentacao/transferencias.dart';

/// Motivos fechados da baixa. Mesmos valores aceitos pela API.
const motivosBaixa = {
  'doacao': 'Doação',
  'inservivel': 'Inservível',
  'extravio': 'Extravio',
  'venda': 'Venda',
  'sinistro': 'Sinistro',
  'descarte': 'Descarte',
};

/// Formulário da baixa: motivo, justificativa e documento de referência são obrigatórios.
/// Retorna os dados para a API, ou null se o usuário cancelar.
Future<Map<String, dynamic>?> pedirBaixa(
  BuildContext context,
  Map<String, dynamic> bem,
) async {
  final justificativa = TextEditingController();
  final documento = TextEditingController();
  String? motivo;
  final form = GlobalKey<FormState>();
  final dados = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, refresh) => AlertDialog(
        scrollable: true,
        title: const Text('Dar baixa no bem'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${bem['codigo_tombamento'] ?? ''} • ${bem['nome'] ?? ''}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: motivo,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                  items: [
                    for (final e in motivosBaixa.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  validator: (v) => v == null ? 'Escolha o motivo' : null,
                  onChanged: (v) => refresh(() => motivo = v),
                ),
              ),
              formTextField(justificativa, 'Justificativa', required: true),
              formTextField(
                documento,
                'Documento de referência (ex.: nº do BO, da ata)',
                required: true,
              ),
              Text(
                'Baixas acima do valor de alçada aguardam a aprovação de outro servidor do patrimônio.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(ctx, {
                'motivo': motivo,
                'justificativa': justificativa.text.trim(),
                'documento_ref': documento.text.trim(),
              });
            },
            child: const Text('Confirmar baixa'),
          ),
        ],
      ),
    ),
  );
  justificativa.dispose();
  documento.dispose();
  return dados;
}

/// Lista as baixas aguardando aprovação. Aprovar ou recusar fica com outro servidor
/// do patrimônio, a API bloqueia quem solicitou.
Future<void> abrirBaixasPendentes(
  BuildContext context, {
  required VoidCallback onChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _BaixasPendentesSheet(onChanged: onChanged),
  );
}

class _BaixasPendentesSheet extends StatefulWidget {
  const _BaixasPendentesSheet({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_BaixasPendentesSheet> createState() => _BaixasPendentesSheetState();
}

class _BaixasPendentesSheetState extends State<_BaixasPendentesSheet> {
  late Future<List<dynamic>> _future = ApiClient.get('/bem/baixas/pendentes');

  void _recarregar() => setState(() {
    _future = ApiClient.get('/bem/baixas/pendentes');
  });

  Future<void> _decidir(Map<String, dynamic> baixa, {required bool aprovar}) async {
    try {
      if (aprovar) {
        final confirmado = await confirmAction(
          context,
          'Aprovar a baixa de ${baixa['bem_nome'] ?? 'este bem'}?',
        );
        if (!confirmado || !mounted) return;
        await ApiClient.post('/bem/baixas/${baixa['id']}/aprovar', {});
      } else {
        final motivo = await pedirMotivo(
          context,
          titulo: 'Motivo da recusa',
          rotulo: 'Por que a baixa não será aprovada?',
          confirmar: 'Recusar',
          ajuda: 'Quem solicitou vai ver este motivo.',
        );
        if (motivo == null || !mounted) return;
        await ApiClient.post('/bem/baixas/${baixa['id']}/recusar', {
          'motivo': motivo,
        });
      }
      if (!mounted) return;
      showAppMessage(context, aprovar ? 'Baixa aprovada.' : 'Baixa recusada.');
      widget.onChanged();
      _recarregar();
    } catch (e) {
      if (mounted) showAppMessage(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: AppLoading(label: 'Buscando baixas...'),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 240,
            child: AppErrorState(
              title: 'Erro ao carregar baixas',
              description: '${snapshot.error}',
              onRetry: _recarregar,
            ),
          );
        }
        final baixas = snapshot.data ?? [];
        if (baixas.isEmpty) {
          return const SizedBox(
            height: 240,
            child: AppEmptyState(
              title: 'Nenhuma baixa aguardando aprovação',
            ),
          );
        }
        return ListView(
          shrinkWrap: true,
          padding: AppSpacing.screen,
          children: [
            const AppSectionHeader(title: 'Baixas aguardando aprovação'),
            for (final raw in baixas)
              _BaixaCard(
                baixa: Map<String, dynamic>.from(raw),
                onAprovar: () =>
                    _decidir(Map<String, dynamic>.from(raw), aprovar: true),
                onRecusar: () =>
                    _decidir(Map<String, dynamic>.from(raw), aprovar: false),
              ),
          ],
        );
      },
    ),
  );
}

class _BaixaCard extends StatelessWidget {
  const _BaixaCard({
    required this.baixa,
    required this.onAprovar,
    required this.onRecusar,
  });

  final Map<String, dynamic> baixa;
  final VoidCallback onAprovar;
  final VoidCallback onRecusar;

  @override
  Widget build(BuildContext context) {
    final motivo = motivosBaixa['${baixa['motivo']}'] ?? '${baixa['motivo']}';
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${baixa['bem_nome'] ?? ''}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${baixa['codigo_tombamento'] ?? ''} • R\$ ${baixa['valor'] ?? '—'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Motivo: $motivo • Documento: ${baixa['documento_ref'] ?? '—'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Justificativa: ${baixa['justificativa'] ?? '—'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Solicitado por ${baixa['solicitante'] ?? '—'} em ${shortDate(baixa['criada_em'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRecusar,
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: onAprovar,
                  child: const Text('Aprovar baixa'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
