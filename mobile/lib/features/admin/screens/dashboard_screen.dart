import 'package:flutter/material.dart';

import '../../../core/navigation/app_shell.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_states.dart';

/// Home do setor de patrimônio e do auditor, no mesmo padrão da home da web:
/// saudação, indicadores, "O que pede atenção" e distribuições.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.nome,
    this.somenteLeitura = false,
  });

  final String nome;

  /// Auditor: sem o atalho de cadastro e sem os alertas de decisão.
  final bool somenteLeitura;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_Painel> _future = _carregar();

  /// Um endpoint sem permissão para o perfil não derruba o painel: vira lista vazia.
  Future<List<dynamic>> _seguro(String endpoint) async {
    try {
      return await ApiClient.get(endpoint);
    } catch (_) {
      return const [];
    }
  }

  Future<_Painel> _carregar() async {
    final resultados = await Future.wait([
      ApiClient.get('/bem/'),
      ApiClient.get('/categoria/'),
      _seguro('/bem/alertas/garantias?dias=60'),
      _seguro('/movimentacao/pendentes'),
      _seguro('/movimentacao/escaladas'),
      _seguro('/bem/baixas/pendentes'),
    ]);
    return _Painel(
      bens: resultados[0],
      categorias: resultados[1],
      garantias: resultados[2],
      pendentes: resultados[3],
      escaladas: resultados[4],
      baixasPendentes: resultados[5],
    );
  }

  Future<void> _recarregar() async {
    setState(() => _future = _carregar());
    await _future;
  }

  void _ir(String label) =>
      context.findAncestorStateOfType<AppShellState>()?.selectLabel(label);

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _recarregar,
    child: FutureBuilder<_Painel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(label: 'Carregando painel...');
        }
        if (snapshot.hasError) {
          return ListView(
            children: [
              AppErrorState(
                title: 'Erro ao carregar painel',
                description: '${snapshot.error}',
                onRetry: _recarregar,
              ),
            ],
          );
        }
        final p = snapshot.data!;
        final ativos = p.bens.where((b) => b['ativo'] == true).length;
        final total = p.bens.length;
        final baixados = total - ativos;
        final nomesCategorias = {
          for (final c in p.categorias) '${c['id']}': '${c['nome']}',
        };
        final porCategoria = <String, int>{};
        final porStatus = <String, int>{};
        for (final b in p.bens) {
          final cat = nomesCategorias['${b['id_categoria']}'] ?? 'Sem categoria';
          porCategoria.update(cat, (n) => n + 1, ifAbsent: () => 1);
          final status = '${b['status'] ?? 'Sem status'}';
          porStatus.update(status, (n) => n + 1, ifAbsent: () => 1);
        }
        final recentes = p.bens.reversed.take(5).toList();
        final atencao = _itensDeAtencao(p);

        return ListView(
          padding: AppSpacing.screen,
          children: [
            _Cabecalho(
              nome: widget.nome,
              mostrarAcao: !widget.somenteLeitura,
              onNovo: () => _ir('Equipamentos'),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.05,
              children: [
                _Indicador(
                  destaque: true,
                  icone: Icons.trending_up,
                  rotulo: 'Patrimônio ativo',
                  valor: '$ativos',
                  sub: 'de $total itens cadastrados',
                  onTap: () => _ir('Equipamentos'),
                ),
                _Indicador(
                  icone: Icons.inventory_2_outlined,
                  rotulo: 'Total de itens',
                  valor: '$total',
                  sub: 'incluindo baixados',
                  onTap: () => _ir('Equipamentos'),
                ),
                _Indicador(
                  icone: Icons.cancel_outlined,
                  rotulo: 'Itens baixados',
                  valor: '$baixados',
                  sub: 'fora das listagens ativas',
                  onTap: () => _ir('Equipamentos'),
                ),
                _Indicador(
                  icone: Icons.verified_user_outlined,
                  rotulo: 'Garantias a vencer',
                  valor: '${p.garantias.length}',
                  sub: 'nos próximos 60 dias',
                  onTap: () => _ir('Equipamentos'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Atencao(itens: atencao, onTap: _ir),
            const SizedBox(height: AppSpacing.lg),
            _Distribuicao(titulo: 'Distribuição por categoria', contagem: porCategoria),
            const SizedBox(height: AppSpacing.md),
            _Distribuicao(titulo: 'Distribuição por status', contagem: porStatus),
            const SizedBox(height: AppSpacing.md),
            AppPanel(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Últimos registros',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (recentes.isEmpty)
                    Text(
                      'Nenhum bem cadastrado.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    for (final b in recentes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${b['nome'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            AppStatusChip(
                              label: '${b['codigo_tombamento'] ?? ''}',
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  List<_ItemAtencao> _itensDeAtencao(_Painel p) => [
    if (p.pendentes.isNotEmpty)
      _ItemAtencao(
        'Transferências aguardando decisão',
        p.pendentes.length,
        'Movimentações',
      ),
    if (p.escaladas.isNotEmpty)
      _ItemAtencao(
        'Transferências escaladas ao patrimônio',
        p.escaladas.length,
        'Movimentações',
      ),
    if (p.baixasPendentes.isNotEmpty)
      _ItemAtencao(
        'Baixas aguardando aprovação',
        p.baixasPendentes.length,
        'Equipamentos',
      ),
    if (p.garantias.isNotEmpty)
      _ItemAtencao(
        'Garantias vencidas ou a vencer',
        p.garantias.length,
        'Equipamentos',
      ),
  ];
}

class _Painel {
  const _Painel({
    required this.bens,
    required this.categorias,
    required this.garantias,
    required this.pendentes,
    required this.escaladas,
    required this.baixasPendentes,
  });

  final List<dynamic> bens;
  final List<dynamic> categorias;
  final List<dynamic> garantias;
  final List<dynamic> pendentes;
  final List<dynamic> escaladas;
  final List<dynamic> baixasPendentes;
}

/// Item de "O que pede atenção": texto, quantidade e para onde levar o usuário.
class _ItemAtencao {
  const _ItemAtencao(this.texto, this.quantidade, this.destino);

  final String texto;
  final int quantidade;
  final String destino;
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.nome,
    required this.mostrarAcao,
    required this.onNovo,
  });

  final String nome;
  final bool mostrarAcao;
  final VoidCallback onNovo;

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final data =
        '${hoje.day.toString().padLeft(2, '0')}/${hoje.month.toString().padLeft(2, '0')}/${hoje.year}';
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VISÃO GERAL DO PATRIMÔNIO',
          style: tema.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Olá, $nome', style: tema.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(data, style: tema.bodySmall),
            ),
            if (mostrarAcao)
              FilledButton.icon(
                onPressed: onNovo,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novo patrimônio'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador({
    required this.icone,
    required this.rotulo,
    required this.valor,
    required this.sub,
    required this.onTap,
    this.destaque = false,
  });

  final IconData icone;
  final String rotulo;
  final String valor;
  final String sub;
  final VoidCallback onTap;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Material(
      color: destaque ? AppColors.primary : AppColors.surface,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: destaque ? null : Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: destaque ? Colors.white24 : AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Icon(
                      icone,
                      size: 18,
                      color: destaque ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward,
                    size: 18,
                    color: destaque ? Colors.white70 : AppColors.textSecondary,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                valor,
                style: tema.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: destaque ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                rotulo,
                style: tema.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: destaque ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Text(
                sub,
                style: tema.bodySmall?.copyWith(
                  color: destaque ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Atencao extends StatelessWidget {
  const _Atencao({required this.itens, required this.onTap});

  final List<_ItemAtencao> itens;
  final void Function(String label) onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final total = itens.fold<int>(0, (soma, i) => soma + i.quantidade);
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOJE',
                      style: tema.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'O que pede atenção',
                      style: tema.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              AppStatusChip(
                label: '$total ${total == 1 ? 'ponto' : 'pontos'}',
                color: total > 0 ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (itens.isEmpty)
            Text(
              'Nada pede atenção agora.',
              style: tema.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else
            for (final item in itens)
              InkWell(
                onTap: () => onTap(item.destino),
                borderRadius: AppRadius.controlBorder,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(item.texto, style: tema.bodyMedium)),
                      Text(
                        '${item.quantidade}',
                        style: tema.titleSmall?.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Distribuição com barras proporcionais ao maior valor.
class _Distribuicao extends StatelessWidget {
  const _Distribuicao({required this.titulo, required this.contagem});

  final String titulo;
  final Map<String, int> contagem;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final ordenado = contagem.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maior = ordenado.isEmpty ? 1 : ordenado.first.value;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          if (ordenado.isEmpty)
            Text('Sem dados.', style: tema.bodySmall)
          else
            for (final e in ordenado)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(e.key, style: tema.bodyMedium)),
                        Text(
                          '${e.value}',
                          style: tema.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.value / maior,
                        minHeight: 6,
                        color: AppColors.primary,
                        backgroundColor: AppColors.primarySoft,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
