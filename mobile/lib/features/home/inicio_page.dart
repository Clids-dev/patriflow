import 'package:flutter/material.dart';

import '../../core/navigation/app_shell.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/widgets/app_components.dart';
import '../movimentacao/transferencias.dart';

/// Início dos perfis de campo: atalhos para as ações do dia.
class InicioPage extends StatelessWidget {
  const InicioPage({
    super.key,
    required this.nome,
    required this.perfil,
    this.setorId,
  });

  final String nome;
  final String perfil;
  final int? setorId;

  void _ir(BuildContext context, String label) =>
      context.findAncestorStateOfType<AppShellState>()?.selectLabel(label);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final responsavel = perfil == 'responsavel_setor';
    return ListView(
      padding: AppSpacing.screen,
      children: [
        Text(
          'VISÃO GERAL',
          style: tema.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Olá, $nome',
          style: tema.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          perfilLabel(perfil),
          style: tema.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (responsavel) ...[
          _Atalho(
            icone: Icons.move_to_inbox_outlined,
            titulo: 'Autorizações pendentes',
            descricao: 'Solicitações que aguardam a decisão do almoxarifado.',
            onTap: () => _ir(context, 'Autorizações'),
          ),
          _Atalho(
            icone: Icons.outbox_outlined,
            titulo: 'Minhas solicitações',
            descricao: 'Acompanhe o resultado e o motivo de cada pedido.',
            onTap: () => _ir(context, 'Minhas solicitações'),
          ),
          _Atalho(
            icone: Icons.inventory_2_outlined,
            titulo: 'Acervo sob sua guarda',
            descricao: 'Consulte os bens do seu setor.',
            onTap: () => _ir(context, 'Acervo'),
          ),
        ] else ...[
          _Atalho(
            icone: Icons.add_box_outlined,
            titulo: 'Solicitar um bem',
            descricao: 'Escolha um bem de qualquer setor e informe o motivo.',
            onTap: () {
              if (setorId == null) {
                showAppMessage(context, 'Seu usuário ainda não está vinculado a um setor.');
                return;
              }
              escolherBemESolicitar(context, destinoId: setorId!);
            },
          ),
          _Atalho(
            icone: Icons.outbox_outlined,
            titulo: 'Minhas solicitações',
            descricao: 'Veja o estado de cada pedido e a resposta.',
            onTap: () => _ir(context, 'Minhas solicitações'),
          ),
          _Atalho(
            icone: Icons.swap_horiz_outlined,
            titulo: 'Movimentações',
            descricao: 'Histórico de transferências dos bens.',
            onTap: () => _ir(context, 'Movimentações'),
          ),
        ],
      ],
    );
  }
}

class _Atalho extends StatelessWidget {
  const _Atalho({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppListCard(
      leading: AppIconBadge(icon: icone),
      title: titulo,
      subtitle: descricao,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    ),
  );
}

/// Pilha de rota simples para telas de cadastro abertas a partir do hub.
class PaginaSimples extends StatelessWidget {
  const PaginaSimples({super.key, required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titulo)),
    body: child,
  );
}
