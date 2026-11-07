import 'package:flutter/material.dart';

import '../../core/offline/fila_sincronizacao.dart';
import '../../core/offline/nomes_operacoes.dart';
import '../../core/offline/sincronizacao_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/app_states.dart';

/// Fila de sincronização (A12): status da conexão, operações feitas sem rede e o desfecho de cada uma.
class SincronizacaoPage extends StatefulWidget {
  const SincronizacaoPage({super.key});

  @override
  State<SincronizacaoPage> createState() => _SincronizacaoPageState();
}

class _SincronizacaoPageState extends State<SincronizacaoPage> {
  final _controller = SincronizacaoController.instancia;
  late Future<List<OperacaoFila>> _operacoes;

  @override
  void initState() {
    super.initState();
    _operacoes = _carregar();
    _controller.addListener(_recarregar);
  }

  @override
  void dispose() {
    _controller.removeListener(_recarregar);
    super.dispose();
  }

  Future<List<OperacaoFila>> _carregar() async {
    await _controller.pronto;
    final usuario = _controller.usuarioId;
    return usuario == null ? const [] : _controller.fila.listar(usuario);
  }

  void _recarregar() {
    if (!mounted) return;
    setState(() {
      _operacoes = _carregar();
    });
  }

  Future<void> _sincronizar() async {
    await _controller.verificarConexao();
    if (!_controller.online) {
      _avisar('Sem conexão com o servidor. As operações continuam guardadas no aparelho.');
      return;
    }
    final resumo = await _controller.sincronizar();
    if (resumo == null || !mounted) return;
    if (resumo.falhaDeRede != null) {
      _avisar('A conexão caiu durante o envio. O que não foi confirmado será reenviado.');
    } else if (resumo.enviadas == 0) {
      _avisar('Nada para enviar.');
    } else {
      _avisar('${resumo.aceitas} enviada(s), ${resumo.recusadas} recusada(s), ${resumo.conflitos} em conflito.');
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _sincronizar,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ListenableBuilder(listenable: _controller, builder: (context, _) => _Cabecalho(onSincronizar: _sincronizar)),
            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader(title: 'Operações deste aparelho'),
            FutureBuilder<List<OperacaoFila>>(
              future: _operacoes,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const AppLoading(label: 'Carregando a fila...');
                final operacoes = snapshot.data!;
                if (operacoes.isEmpty) {
                  return const AppEmptyState(
                    title: 'Fila vazia',
                    description: 'O que você registrar sem rede aparece aqui até o servidor confirmar.',
                  );
                }
                return Column(children: [for (final op in operacoes) _ItemFila(operacao: op)]);
              },
            ),
          ],
        ),
      );
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.onSincronizar});

  final VoidCallback onSincronizar;

  @override
  Widget build(BuildContext context) {
    final c = SincronizacaoController.instancia;
    final online = c.online;
    final ultima = c.ultimaSincronizacao;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: online ? AppColors.success : AppColors.error),
              const SizedBox(width: AppSpacing.sm),
              Text(
                switch (c.status) {
                  StatusConexao.online => 'Conectado ao servidor',
                  StatusConexao.offline => 'Sem conexão com o servidor',
                  StatusConexao.verificando => 'Verificando a conexão...',
                },
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppDetailLine(label: 'Aguardando envio', value: '${c.aguardando}'),
          AppDetailLine(label: 'Última sincronização', value: ultima == null ? 'Nunca' : _dataHora(ultima)),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: c.sincronizando ? null : onSincronizar,
              icon: c.sincronizando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: Text(c.sincronizando ? 'Sincronizando...' : 'Sincronizar agora'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemFila extends StatelessWidget {
  const _ItemFila({required this.operacao});

  final OperacaoFila operacao;

  @override
  Widget build(BuildContext context) {
    final (rotulo, cor, icone) = switch (operacao.estado) {
      EstadoOperacao.pendente || EstadoOperacao.enviando => ('Aguardando envio', AppColors.warning, Icons.schedule),
      EstadoOperacao.erro => ('Será reenviada', AppColors.warning, Icons.refresh),
      EstadoOperacao.aceita => ('Enviada', AppColors.success, Icons.check_circle_outline),
      EstadoOperacao.recusada => ('Recusada', AppColors.error, Icons.block),
      EstadoOperacao.conflito => ('Em conflito', AppColors.error, Icons.call_split),
    };
    return AppListCard(
      leading: Icon(icone, color: cor),
      title: nomeDaOperacao(operacao.tipo),
      subtitle: [
        operacao.resumo,
        'Feita em ${_dataHora(operacao.criadaEm)}',
        if (operacao.mensagem != null) operacao.mensagem!,
      ].join('\n'),
      trailing: AppStatusChip(label: rotulo, color: cor),
    );
  }
}

String _dataHora(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  final l = d.toLocal();
  return '${dois(l.day)}/${dois(l.month)}/${l.year} ${dois(l.hour)}:${dois(l.minute)}';
}
