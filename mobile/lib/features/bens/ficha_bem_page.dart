import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/app_states.dart';
import '../movimentacao/transferencias.dart';

/// Ficha do bem: dados, depreciação, movimentações e histórico de alterações.
/// Somente leitura. Os dados vêm da API, que aplica as permissões.
class FichaBemPage extends StatefulWidget {
  const FichaBemPage({super.key, required this.bemId});

  final int bemId;

  @override
  State<FichaBemPage> createState() => _FichaBemPageState();
}

class _FichaBemPageState extends State<FichaBemPage> {
  late Future<_Ficha> _future = _carregar();

  Future<_Ficha> _carregar() async {
    final detalhes = await ApiClient.getMap('/bem/${widget.bemId}/detalhes');
    final codigo = '${detalhes['codigo_tombamento']}';
    final resultados = await Future.wait([
      ApiClient.get('/movimentacao/bem/${Uri.encodeComponent(codigo)}'),
      ApiClient.get('/bem/${widget.bemId}/auditoria'),
    ]);
    return _Ficha(
      detalhes: detalhes,
      movimentacoes: resultados[0].map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      alteracoes: resultados[1].map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  Future<void> _recarregar() async {
    setState(() => _future = _carregar());
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ficha do bem')),
    body: RefreshIndicator(
      onRefresh: _recarregar,
      child: FutureBuilder<_Ficha>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading(label: 'Carregando ficha...');
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                AppErrorState(
                  title: 'Erro ao carregar a ficha',
                  description: '${snapshot.error}',
                  onRetry: _recarregar,
                ),
              ],
            );
          }
          return _corpo(context, snapshot.data!);
        },
      ),
    ),
  );

  Widget _corpo(BuildContext context, _Ficha f) {
    final d = f.detalhes;
    final tema = Theme.of(context).textTheme;
    final status = '${d['status'] ?? ''}';
    final ativo = d['ativo'] == true;
    return ListView(
      padding: AppSpacing.screen,
      children: [
        AppPanel(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppStatusChip(
                    label: '${d['codigo_tombamento'] ?? ''}',
                    color: AppColors.primary,
                  ),
                  const Spacer(),
                  AppStatusChip(
                    label: ativo ? status : 'Baixado',
                    color: ativo ? assetStatusColor(status) : AppColors.error,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('${d['nome'] ?? ''}', style: tema.titleLarge),
              if ((d['categoria_nome'] ?? '').toString().isNotEmpty)
                Text(
                  '${d['categoria_nome']}',
                  style: tema.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const AppSectionHeader(title: 'Dados'),
        AppPanel(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              AppDetailLine(label: 'Marca / modelo', value: _juntar([d['marca'], d['modelo']])),
              AppDetailLine(label: 'Número de série', value: d['numero_serie']),
              AppDetailLine(label: 'Nota fiscal', value: d['nota_fiscal']),
              AppDetailLine(label: 'Data de entrada', value: shortDate(d['data_entrada'])),
              AppDetailLine(label: 'Conservação', value: d['estado_conservacao']),
              AppDetailLine(label: 'Garantia até', value: shortDate(d['garantia_fim'])),
              AppDetailLine(label: 'Valor de aquisição', value: _moeda(d['valor_aquisicao'] ?? d['valor'])),
              AppDetailLine(label: 'Valor residual', value: _moeda(d['valor_residual'])),
              AppDetailLine(label: 'Vida útil', value: d['vida_util_meses'] == null ? null : '${d['vida_util_meses']} meses'),
              AppDetailLine(label: 'Depreciação mensal', value: _moeda(d['depreciacao_mensal'])),
              AppDetailLine(label: 'Depreciação acumulada', value: _moeda(d['depreciacao_acumulada'])),
              AppDetailLine(label: 'Valor contábil', value: _moeda(d['valor_contabil'])),
            ],
          ),
        ),
        const AppSectionHeader(title: 'Localização e responsável'),
        AppPanel(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              AppDetailLine(label: 'Setor atual', value: d['setor_atual']),
              AppDetailLine(
                label: 'Local',
                value: _juntar([d['predio_nome'], d['andar_identificacao'], d['sala_nome']], separador: ' • '),
              ),
              AppDetailLine(label: 'Responsável', value: d['responsavel_nome']),
              AppDetailLine(label: 'Cargo', value: d['responsavel_cargo']),
            ],
          ),
        ),
        const AppSectionHeader(title: 'Movimentações'),
        if (f.movimentacoes.isEmpty)
          Text('Nenhuma movimentação registrada.', style: tema.bodySmall)
        else
          for (final mov in f.movimentacoes)
            TransferenciaCard(mov: mov),
        const AppSectionHeader(title: 'Histórico de alterações'),
        if (f.alteracoes.isEmpty)
          Text('Nenhuma alteração registrada.', style: tema.bodySmall)
        else
          for (final evento in f.alteracoes)
            _EventoAuditoria(evento: evento),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  static String? _juntar(List<dynamic> partes, {String separador = ' '}) {
    final texto = partes
        .where((p) => p != null && '$p'.trim().isNotEmpty)
        .map((p) => '$p')
        .join(separador);
    return texto.isEmpty ? null : texto;
  }

  static String? _moeda(dynamic valor) => valor == null ? null : 'R\$ ${(valor as num).toStringAsFixed(2)}';
}

class _Ficha {
  const _Ficha({
    required this.detalhes,
    required this.movimentacoes,
    required this.alteracoes,
  });

  final Map<String, dynamic> detalhes;
  final List<Map<String, dynamic>> movimentacoes;
  final List<Map<String, dynamic>> alteracoes;
}

/// Um evento do histórico de alterações: quem fez, quando e o que mudou.
class _EventoAuditoria extends StatelessWidget {
  const _EventoAuditoria({required this.evento});

  final Map<String, dynamic> evento;

  static const _acoes = {
    'criar': 'Cadastro',
    'editar': 'Edição',
    'baixar': 'Baixa',
    'reativar': 'Reativação',
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final antes = evento['antes'] is Map ? Map<String, dynamic>.from(evento['antes'] as Map) : <String, dynamic>{};
    final depois = evento['depois'] is Map ? Map<String, dynamic>.from(evento['depois'] as Map) : <String, dynamic>{};
    final mudancas = [
      for (final campo in depois.keys)
        if ('${antes[campo]}' != '${depois[campo]}')
          '$campo: ${antes[campo] ?? '—'} → ${depois[campo]}',
    ];
    final acao = '${evento['acao'] ?? ''}';
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_acoes[acao] ?? acao} • ${shortDate(evento['em'])}',
            style: tema.titleSmall,
          ),
          Text(
            'Por ${evento['usuario'] ?? 'sistema'}',
            style: tema.bodySmall,
          ),
          for (final linha in mudancas.take(5))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(linha, style: tema.bodySmall),
            ),
        ],
      ),
    );
  }
}
