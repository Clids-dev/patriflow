import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/offline/acervo_repository.dart';
import '../../core/offline/fila_sincronizacao.dart';
import '../../core/offline/nomes_operacoes.dart';
import '../../core/offline/sincronizacao_controller.dart';
import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/app_states.dart';

String _dois(int n) => n.toString().padLeft(2, '0');
String _dataHora(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}/${d.year} ${_dois(d.hour)}:${_dois(d.minute)}';
String _data(String? iso) {
  if (iso == null) return '—';
  final p = iso.split('T').first.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

/// Acervo do setor no aparelho (A03): baixar, ver quando foi baixado e consultar sem rede.
class AcervoOfflinePage extends StatefulWidget {
  const AcervoOfflinePage({super.key, required this.setorId, required this.podeEscolherSetor});

  /// Setor do usuário. Colaboradores só baixam o próprio setor.
  final int? setorId;

  /// O setor de patrimônio escolhe qualquer setor.
  final bool podeEscolherSetor;

  @override
  State<AcervoOfflinePage> createState() => _AcervoOfflinePageState();
}

class _AcervoOfflinePageState extends State<AcervoOfflinePage> {
  final _controller = SincronizacaoController.instancia;
  final _busca = TextEditingController();
  AcervoMeta? _meta;
  List<BemOffline> _bens = const [];
  List<Map<String, dynamic>> _setores = const [];
  int? _setorEscolhido;
  bool _carregando = true;
  String? _progresso;

  AcervoRepository get _repo => _controller.acervo.repository;

  @override
  void initState() {
    super.initState();
    _setorEscolhido = widget.setorId;
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    await _controller.pronto;
    final meta = await _repo.meta();
    final bens = await _repo.buscar(_busca.text);
    if (widget.podeEscolherSetor && _setores.isEmpty) {
      try {
        _setores = (await ApiClient.get('/setores/')).cast<Map>().map(Map<String, dynamic>.from).toList();
        _setorEscolhido ??= meta?.setorId ?? (_setores.isEmpty ? null : _setores.first['id'] as int);
      } catch (_) {
        // Sem rede: escolhe pelo acervo já baixado.
        _setorEscolhido ??= meta?.setorId;
      }
    }
    if (!mounted) return;
    setState(() {
      _meta = meta;
      _bens = bens;
      _carregando = false;
    });
  }

  Future<void> _baixar() async {
    final setor = _setorEscolhido;
    if (setor == null) return;
    setState(() => _progresso = 'Baixando o acervo...');
    try {
      final r = await _controller.acervo.baixar(
        setor,
        progresso: (feitas, total) {
          if (mounted) setState(() => _progresso = 'Baixando fotos: $feitas de $total');
        },
      );
      _avisar(r.fotosComFalha == 0
          ? 'Acervo baixado: ${r.totalBens} bens.'
          : 'Acervo baixado: ${r.totalBens} bens. ${r.fotosComFalha} foto(s) não estavam disponíveis no servidor.');
    } catch (erro) {
      _avisar('Não foi possível baixar o acervo (${erro.toString().replaceFirst('Exception: ', '')}). '
          'O acervo anterior foi mantido.');
      await _controller.verificarConexao();
    } finally {
      if (mounted) setState(() => _progresso = null);
      await _carregar();
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.podeEscolherSetor && widget.setorId == null) {
      return const AppEmptyState(
        title: 'Usuário sem setor',
        description: 'Peça ao setor de patrimônio para vincular seu usuário a um setor.',
      );
    }
    if (_carregando) return const AppLoading(label: 'Abrindo o acervo do aparelho...');
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ListenableBuilder(listenable: _controller, builder: (context, _) => _painelDownload(context)),
          const SizedBox(height: AppSpacing.lg),
          if (_meta != null) ...[
            AppSearchField(controller: _busca, hint: 'Buscar por nome ou tombo', onSubmitted: (_) => _carregar()),
            const SizedBox(height: AppSpacing.md),
            if (_bens.isEmpty)
              const AppEmptyState(title: 'Nenhum bem encontrado', description: 'Tente outro nome ou tombo.')
            else
              for (final bem in _bens) _itemBem(bem),
          ],
        ],
      ),
    );
  }

  Widget _painelDownload(BuildContext context) {
    final meta = _meta;
    final online = _controller.online;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta == null ? 'Nenhum acervo no aparelho' : meta.setorNome,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (meta != null) ...[
            AppDetailLine(label: 'Baixado em', value: _dataHora(meta.baixadoEm)),
            AppDetailLine(label: 'Bens', value: '${meta.totalBens}'),
            if (meta.fotosComFalha > 0)
              AppDetailLine(label: 'Fotos indisponíveis', value: '${meta.fotosComFalha}'),
          ] else
            const Text('Baixe o acervo para consultar os bens do setor sem internet.'),
          if (widget.podeEscolherSetor && _setores.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _setorEscolhido,
              decoration: const InputDecoration(labelText: 'Setor'),
              items: [
                for (final s in _setores) DropdownMenuItem(value: s['id'] as int, child: Text(s['nome'].toString())),
              ],
              onChanged: (v) => setState(() => _setorEscolhido = v),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_progresso != null) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            Text(_progresso!, style: Theme.of(context).textTheme.bodySmall),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: online && _setorEscolhido != null ? _baixar : null,
                icon: const Icon(Icons.download_outlined),
                label: Text(meta == null ? 'Baixar acervo' : 'Atualizar acervo'),
              ),
            ),
          if (!online && _progresso == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                meta == null ? 'Sem conexão: conecte-se para baixar o acervo.' : 'Sem conexão: o acervo do aparelho continua disponível.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _itemBem(BemOffline bem) {
    final situacao = bem.emprestimoAbertoId != null
        ? const AppStatusChip(label: 'Emprestado', color: AppColors.warning)
        : bem.manutencaoAbertaId != null
            ? const AppStatusChip(label: 'Manutenção', color: AppColors.warning)
            : null;
    return AppListCard(
      title: bem.nome,
      subtitle: '${bem.codigoTombamento} · ${bem.ficha['status'] ?? ''}',
      trailing: situacao,
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => FichaOfflinePage(bem: bem, setorUsuario: widget.setorId)));
        await _carregar();
      },
    );
  }
}

/// Ficha do bem a partir do acervo do aparelho, com as ações de guarda que entram na fila.
class FichaOfflinePage extends StatefulWidget {
  const FichaOfflinePage({super.key, required this.bem, required this.setorUsuario});

  final BemOffline bem;
  final int? setorUsuario;

  @override
  State<FichaOfflinePage> createState() => _FichaOfflinePageState();
}

class _FichaOfflinePageState extends State<FichaOfflinePage> {
  final _controller = SincronizacaoController.instancia;
  List<OperacaoFila> _naFila = const [];
  // Lida uma vez: o arquivo da foto não muda enquanto a ficha está aberta.
  late final Future<File?> _foto = _controller.acervo.fotoDoBem(widget.bem);

  BemOffline get _bem => widget.bem;
  Map<String, dynamic> get _f => _bem.ficha;

  @override
  void initState() {
    super.initState();
    _atualizarFila();
  }

  Future<void> _atualizarFila() async {
    await _controller.pronto;
    final usuario = _controller.usuarioId;
    if (usuario == null) return;
    final ops = await _controller.fila.aguardandoDoBem(_bem.id, usuario);
    if (mounted) setState(() => _naFila = ops);
  }

  /// O setor de patrimônio opera qualquer bem; colaboradores, os do próprio setor (a API confere).
  bool get _temGuarda => widget.setorUsuario == null || widget.setorUsuario == _bem.setorId;

  Future<void> _registrar(String tipo, Map<String, dynamic> dados) async {
    await _controller.registrar(
      tipo: tipo,
      dados: dados,
      resumo: '${_bem.codigoTombamento} · ${_bem.nome}',
      bemId: _bem.id,
    );
    await _atualizarFila();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_controller.online
          ? '${nomeDaOperacao(tipo)} registrado. Enviando ao servidor...'
          : '${nomeDaOperacao(tipo)} registrado no aparelho. Será enviado quando houver conexão.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final localizacao = [_f['predio_nome'], _f['andar_identificacao'], _f['sala_identificacao']]
        .whereType<String>()
        .join(' — ');
    return Scaffold(
      appBar: AppBar(title: const Text('Ficha do bem (offline)')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          FutureBuilder<File?>(
            future: _foto,
            builder: (context, snapshot) => snapshot.data == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(snapshot.data!, height: 200, fit: BoxFit.cover,
                          semanticLabel: 'Foto de referência de ${_bem.nome}'),
                    ),
                  ),
          ),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_bem.nome, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                AppDetailLine(label: 'Tombo', value: _bem.codigoTombamento),
                AppDetailLine(label: 'Situação', value: '${_f['status'] ?? '—'}'),
                AppDetailLine(label: 'Categoria', value: '${_f['categoria_nome'] ?? '—'}'),
                AppDetailLine(label: 'Marca / modelo', value: '${_f['marca'] ?? '—'} / ${_f['modelo'] ?? '—'}'),
                AppDetailLine(label: 'Nº de série', value: '${_f['numero_serie'] ?? '—'}'),
                AppDetailLine(label: 'Conservação', value: '${_f['estado_conservacao'] ?? '—'}'),
                AppDetailLine(label: 'Setor', value: '${_f['setor_nome'] ?? '—'}'),
                AppDetailLine(label: 'Localização', value: localizacao.isEmpty ? '—' : localizacao),
                AppDetailLine(label: 'Responsável', value: '${_f['responsavel_nome'] ?? '—'}'),
                AppDetailLine(label: 'Garantia até', value: _data(_f['garantia_fim'] as String?)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_bem.emprestimoAbertoId != null)
            _aviso('Emprestado para ${_f['emprestado_para']} até ${_data(_f['devolucao_prevista'] as String?)}.'),
          if (_bem.manutencaoAbertaId != null) _aviso('Em manutenção.'),
          for (final op in _naFila) _aviso('Na fila: ${nomeDaOperacao(op.tipo)} (aguardando envio).'),
          if (_temGuarda) ..._acoes(),
        ],
      ),
    );
  }

  Widget _aviso(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppPanel(child: Row(children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(texto)),
        ])),
      );

  /// Ações possíveis com o que o aparelho sabe. Com uma operação do bem já na fila, nenhuma outra
  /// é oferecida até o envio, para não registrar duas vezes a mesma coisa sem rede.
  List<Widget> _acoes() {
    if (_naFila.isNotEmpty) return const [];
    final botoes = <Widget>[
      if (_bem.emprestimoAbertoId != null)
        FilledButton.icon(onPressed: _devolver, icon: const Icon(Icons.assignment_return_outlined), label: const Text('Registrar devolução')),
      if (_bem.manutencaoAbertaId != null)
        FilledButton.icon(onPressed: _retorno, icon: const Icon(Icons.build_circle_outlined), label: const Text('Registrar retorno')),
      if (_bem.emprestimoAbertoId == null && _bem.manutencaoAbertaId == null) ...[
        FilledButton.icon(onPressed: _emprestar, icon: const Icon(Icons.outbox_outlined), label: const Text('Emprestar')),
        OutlinedButton.icon(onPressed: _enviarManutencao, icon: const Icon(Icons.build_outlined), label: const Text('Enviar para manutenção')),
      ],
    ];
    return [
      for (final b in botoes) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: SizedBox(width: double.infinity, child: b)),
    ];
  }

  Future<void> _emprestar() async {
    final valores = await _formulario('Emprestar', [
      const _Campo('tomador', 'Quem vai levar', minimo: 3, maximo: 120),
      const _Campo('motivo', 'Motivo', minimo: 3, maximo: 500),
      const _Campo('devolucao_prevista', 'Devolução prevista', data: true),
    ]);
    if (valores != null) await _registrar('emprestimo_registrar', {'bem_id': _bem.id, ...valores});
  }

  Future<void> _devolver() async {
    final valores = await _formulario('Registrar devolução', [
      const _Campo('observacao', 'Observação (opcional)', minimo: 0, maximo: 500),
    ]);
    if (valores != null) {
      await _registrar('emprestimo_devolver', {
        'emprestimo_id': _bem.emprestimoAbertoId,
        'observacao': (valores['observacao'] as String).isEmpty ? null : valores['observacao'],
      });
    }
  }

  Future<void> _enviarManutencao() async {
    final valores = await _formulario('Enviar para manutenção', [
      const _Campo('descricao', 'Problema', minimo: 3, maximo: 500),
      const _Campo('destino', 'Para onde vai', minimo: 2, maximo: 160),
    ]);
    if (valores != null) await _registrar('manutencao_enviar', {'bem_id': _bem.id, ...valores});
  }

  Future<void> _retorno() async {
    final valores = await _formulario('Registrar retorno', [
      const _Campo('servico_realizado', 'Serviço realizado', minimo: 3, maximo: 500),
      const _Campo('estado_retorno', 'Estado de conservação', opcoes: {
        'novo': 'Novo', 'bom': 'Bom', 'regular': 'Regular', 'ruim': 'Ruim', 'inservivel': 'Inservível',
      }),
    ]);
    if (valores != null) {
      await _registrar('manutencao_retorno', {'manutencao_id': _bem.manutencaoAbertaId, ...valores});
    }
  }

  /// Formulário curto numa folha inferior. Valida com as mesmas regras da API.
  Future<Map<String, dynamic>?> _formulario(String titulo, List<_Campo> campos) =>
      showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _FormularioAcao(titulo: titulo, campos: campos),
      );
}

class _Campo {
  const _Campo(this.chave, this.rotulo, {this.minimo = 1, this.maximo = 500, this.data = false, this.opcoes});

  final String chave;
  final String rotulo;
  final int minimo;
  final int maximo;
  final bool data;
  final Map<String, String>? opcoes;
}

class _FormularioAcao extends StatefulWidget {
  const _FormularioAcao({required this.titulo, required this.campos});

  final String titulo;
  final List<_Campo> campos;

  @override
  State<_FormularioAcao> createState() => _FormularioAcaoState();
}

class _FormularioAcaoState extends State<_FormularioAcao> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _textos = {
    for (final c in widget.campos)
      if (!c.data && c.opcoes == null) c.chave: TextEditingController(),
  };
  final Map<String, Object?> _outros = {};

  @override
  void dispose() {
    for (final t in _textos.values) {
      t.dispose();
    }
    super.dispose();
  }

  Widget _campo(_Campo c) {
    if (c.opcoes != null) {
      return DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: c.rotulo),
        items: [for (final e in c.opcoes!.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => _outros[c.chave] = v,
        validator: (v) => v == null ? 'Escolha uma opção' : null,
      );
    }
    if (c.data) {
      final escolhida = _outros[c.chave] as DateTime?;
      return FormField<DateTime>(
        validator: (_) => _outros[c.chave] == null ? 'Escolha a data' : null,
        builder: (estado) => InputDecorator(
          decoration: InputDecoration(labelText: c.rotulo, errorText: estado.errorText),
          child: InkWell(
            onTap: () async {
              final hoje = DateTime.now();
              final data = await showDatePicker(
                context: context,
                firstDate: DateTime(hoje.year, hoje.month, hoje.day),
                lastDate: hoje.add(const Duration(days: 365)),
              );
              if (data != null) setState(() => _outros[c.chave] = data);
            },
            child: Text(escolhida == null ? 'Toque para escolher' : '${_dois(escolhida.day)}/${_dois(escolhida.month)}/${escolhida.year}'),
          ),
        ),
      );
    }
    return TextFormField(
      controller: _textos[c.chave],
      decoration: InputDecoration(labelText: c.rotulo),
      maxLength: c.maximo,
      validator: (v) {
        final texto = (v ?? '').trim();
        if (c.minimo > 0 && texto.length < c.minimo) return 'Informe ao menos ${c.minimo} caracteres';
        return null;
      },
    );
  }

  void _confirmar() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(context, {
      for (final e in _textos.entries) e.key: e.value.text.trim(),
      for (final e in _outros.entries)
        e.key: e.value is DateTime
            ? '${(e.value as DateTime).year}-${_dois((e.value as DateTime).month)}-${_dois((e.value as DateTime).day)}'
            : e.value,
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titulo, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              for (final c in widget.campos)
                Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: _campo(c)),
              FilledButton(onPressed: _confirmar, child: const Text('Registrar')),
            ],
          ),
        ),
      );
}
