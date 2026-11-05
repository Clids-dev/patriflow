import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import 'transferencias.dart';

/// Qual lista de transferências a tela mostra.
enum ModoTransferencias {
  /// O que este usuário pode decidir agora (liberar ou confirmar recebimento).
  pendentes('/movimentacao/pendentes'),

  /// Solicitações feitas pelo próprio usuário, com o resultado e o motivo.
  minhas('/movimentacao/minhas'),

  /// Todas as transferências abertas do sistema (almoxarifado acompanha).
  acompanhamento('/movimentacao/acompanhamento'),

  /// Todas as movimentações, somente leitura.
  todas('/movimentacao/detailed/');

  const ModoTransferencias(this.endpoint);
  final String endpoint;
}

class TransferListPage extends StatefulWidget {
  const TransferListPage({
    super.key,
    required this.modo,
    this.podeDecidir = false,
    this.podeIntervir = false,
    this.setorId,
  });

  final ModoTransferencias modo;

  /// Responsável do setor de origem libera; do destino confirma o recebimento.
  final bool podeDecidir;

  /// Almoxarifado e setor de patrimônio podem cancelar uma transferência aberta.
  final bool podeIntervir;

  /// Setor do usuário, usado para solicitar bens (modo "minhas").
  final int? setorId;

  /// Contagem de transferências que o usuário pode decidir, para a barra inferior.
  static Future<int> contarPendentes() async {
    final lista = await ApiClient.get(ModoTransferencias.pendentes.endpoint);
    return lista.length;
  }

  @override
  State<TransferListPage> createState() => _TransferListPageState();
}

class _TransferListPageState extends State<TransferListPage> {
  late Future<List<dynamic>> _future = _carregar();

  Future<List<dynamic>> _carregar() => ApiClient.get(widget.modo.endpoint);

  Future<void> _recarregar() async {
    setState(() => _future = _carregar());
    await _future;
  }

  Future<void> _executar(Future<bool> acao) async {
    final ok = await acao;
    if (ok && mounted) _recarregar();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _recarregar,
    child: FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final cabecalho = widget.modo == ModoTransferencias.minhas && widget.setorId != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _executar(
                      escolherBemESolicitar(context, destinoId: widget.setorId!),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Solicitar bem'),
                  ),
                ),
              )
            : null;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading(label: 'Buscando transferências...');
        }
        if (snapshot.hasError) {
          return ListView(
            children: [
              AppErrorState(
                title: 'Erro ao carregar transferências',
                description: '${snapshot.error}',
                onRetry: _recarregar,
              ),
            ],
          );
        }
        final itens = (snapshot.data ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        return ListView(
          padding: AppSpacing.screen,
          children: [
            ?cabecalho,
            if (itens.isEmpty)
              AppEmptyState(
                title: _tituloVazio,
                description: _descricaoVazia,
              )
            else
              for (final mov in itens)
                TransferenciaCard(mov: mov, acoes: _acoes(mov)),
          ],
        );
      },
    ),
  );

  /// Ações por etapa. A etapa vem da API: "liberar" (origem), "receber" (destino)
  /// ou, no fluxo antigo, a confirmação com foto.
  Widget? _acoes(Map<String, dynamic> mov) {
    final aberta = mov['status'] == 'pendente' || mov['status'] == 'liberada';
    final decidivel = widget.podeDecidir && widget.modo == ModoTransferencias.pendentes && aberta;
    final intervivel = widget.podeIntervir && aberta;
    if (!decidivel && !intervivel) return null;

    final liberar = mov['etapa'] == 'liberar' && mov['fluxo'] != 'simples';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (decidivel)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _executar(recusarTransferencia(context, mov)),
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: () => _executar(autorizarTransferencia(context, mov)),
                  child: Text(liberar ? 'Liberar bem' : 'Confirmar com foto'),
                ),
              ),
            ],
          ),
        if (intervivel) ...[
          if (decidivel) const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _executar(intervirTransferencia(context, mov)),
            icon: const Icon(Icons.gpp_maybe_outlined),
            label: const Text('Intervir (cancelar)'),
          ),
        ],
      ],
    );
  }

  String get _tituloVazio => switch (widget.modo) {
    ModoTransferencias.pendentes => 'Nada aguardando sua decisão',
    ModoTransferencias.minhas => 'Nenhuma solicitação',
    ModoTransferencias.acompanhamento => 'Nenhuma transferência em andamento',
    ModoTransferencias.todas => 'Sem movimentações',
  };

  String get _descricaoVazia => switch (widget.modo) {
    ModoTransferencias.pendentes =>
      'Bens aguardando a liberação do seu setor, ou o recebimento, aparecem aqui.',
    ModoTransferencias.minhas =>
      'As solicitações que você fizer aparecem aqui, com a decisão e o motivo.',
    ModoTransferencias.acompanhamento =>
      'Todas as transferências abertas do sistema aparecem aqui para acompanhamento.',
    ModoTransferencias.todas => 'Nenhum registro de movimentação encontrado.',
  };
}
