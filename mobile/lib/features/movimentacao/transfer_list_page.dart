import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/widgets/app_states.dart';
import 'transferencias.dart';

/// Qual lista de transferências a tela mostra.
enum ModoTransferencias {
  /// Aguardando decisão. Com [podeDecidir], mostra autorizar e recusar.
  pendentes('/movimentacao/pendentes'),

  /// Solicitações feitas pelo próprio usuário, com o motivo da decisão.
  minhas('/movimentacao/minhas'),

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
    this.almoxId,
    this.setorId,
  });

  final ModoTransferencias modo;

  /// Só o responsável do almoxarifado (e o setor de patrimônio) decide.
  final bool podeDecidir;

  /// Usados pelo botão de solicitar bem, no modo "minhas".
  final int? almoxId;
  final int? setorId;

  /// Contagem de transferências pendentes, usada pela barra inferior.
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

  Future<void> _decidir(Map<String, dynamic> mov, {required bool aprovar}) async {
    final ok = aprovar
        ? await autorizarTransferencia(context, mov)
        : await recusarTransferencia(context, mov);
    if (ok && mounted) _recarregar();
  }

  Future<void> _solicitar() async {
    final almox = widget.almoxId;
    final setor = widget.setorId;
    if (almox == null || setor == null) {
      showAppMessage(context, 'Seu setor ou o almoxarifado ainda não foi definido.');
      return;
    }
    final ok = await escolherBemESolicitar(context, almoxId: almox, setorId: setor);
    if (ok && mounted) _recarregar();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _recarregar,
    child: FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final cabecalho = widget.modo == ModoTransferencias.minhas &&
                widget.almoxId != null &&
                widget.setorId != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _solicitar,
                    icon: const Icon(Icons.add),
                    label: const Text('Solicitar bem do almoxarifado'),
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
                TransferenciaCard(
                  mov: mov,
                  acoes: widget.podeDecidir && widget.modo == ModoTransferencias.pendentes
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _decidir(mov, aprovar: false),
                                child: const Text('Recusar'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                ),
                                onPressed: () => _decidir(mov, aprovar: true),
                                child: const Text('Autorizar com foto'),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
          ],
        );
      },
    ),
  );

  String get _tituloVazio => switch (widget.modo) {
    ModoTransferencias.pendentes => 'Nenhuma autorização pendente',
    ModoTransferencias.minhas => 'Nenhuma solicitação',
    ModoTransferencias.todas => 'Sem movimentações',
  };

  String get _descricaoVazia => switch (widget.modo) {
    ModoTransferencias.pendentes =>
      'As solicitações que aguardam a decisão do almoxarifado aparecem aqui.',
    ModoTransferencias.minhas =>
      'As solicitações que você fizer aparecem aqui, com a decisão e o motivo.',
    ModoTransferencias.todas => 'Nenhum registro de movimentação encontrado.',
  };
}
