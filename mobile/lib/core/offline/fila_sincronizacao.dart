import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'identificador.dart';
import 'local_database.dart';

enum EstadoOperacao { pendente, enviando, aceita, recusada, conflito, erro }

/// Operação registrada no aparelho e ainda não confirmada (ou já respondida) pelo servidor.
class OperacaoFila {
  const OperacaoFila({
    required this.id,
    required this.usuarioId,
    required this.tipo,
    required this.criadaEm,
    required this.dados,
    required this.resumo,
    required this.estado,
    required this.tentativas,
    required this.atualizadaEm,
    this.bemId,
    this.mensagem,
  });

  final String id;
  final int usuarioId;
  final String tipo;
  final DateTime criadaEm;
  final Map<String, dynamic> dados;

  /// Texto curto para a tela (ex.: "NTB-0001-7 · Notebook Dell").
  final String resumo;
  final int? bemId;
  final EstadoOperacao estado;
  final String? mensagem;
  final int tentativas;
  final DateTime atualizadaEm;

  /// Ainda precisa ser enviada (ou reenviada).
  bool get aguardandoEnvio =>
      estado == EstadoOperacao.pendente || estado == EstadoOperacao.enviando || estado == EstadoOperacao.erro;

  static OperacaoFila _deLinha(Map<String, Object?> l) => OperacaoFila(
        id: l['id'] as String,
        usuarioId: l['usuario_id'] as int,
        tipo: l['tipo'] as String,
        criadaEm: DateTime.parse(l['criada_em'] as String),
        dados: Map<String, dynamic>.from(jsonDecode(l['dados'] as String) as Map),
        resumo: l['resumo'] as String,
        bemId: l['bem_id'] as int?,
        estado: EstadoOperacao.values.byName(l['estado'] as String),
        mensagem: l['mensagem'] as String?,
        tentativas: l['tentativas'] as int,
        atualizadaEm: DateTime.parse(l['atualizada_em'] as String),
      );
}

class ResumoSincronizacao {
  const ResumoSincronizacao({
    this.enviadas = 0,
    this.aceitas = 0,
    this.recusadas = 0,
    this.conflitos = 0,
    this.erros = 0,
    this.falhaDeRede,
  });

  final int enviadas;
  final int aceitas;
  final int recusadas;
  final int conflitos;
  final int erros;

  /// Preenchido quando a conexão caiu no meio: o que não foi confirmado volta a aguardar envio.
  final String? falhaDeRede;
}

/// Envia o corpo do lote para POST /sincronizacao e devolve a resposta.
typedef EnviarLote = Future<Map<String, dynamic>> Function(Map<String, dynamic> corpo);

/// Fila de operações feitas sem rede (A12).
///
/// - Operações são enviadas na ordem em que foram criadas, em lotes.
/// - Cada operação tem um id único gerado no aparelho; o servidor ignora reenvios (idempotência),
///   então uma queda de rede no meio do envio nunca duplica registros.
/// - A fila só remove o que o servidor confirmou. Recusadas e em conflito continuam visíveis.
/// - Cada usuário só envia as próprias operações, com a própria sessão.
class FilaSincronizacao {
  FilaSincronizacao({
    required this.local,
    required this.enviarLote,
    this.tamanhoLote = 100,
    DateTime Function()? agora,
  }) : _agora = agora ?? DateTime.now;

  final LocalDatabase local;
  final EnviarLote enviarLote;
  final int tamanhoLote;
  final DateTime Function() _agora;
  bool _sincronizando = false;

  static const _manterAceitas = Duration(days: 7);
  static const _manterRespondidas = Duration(days: 30);

  /// Identificador do aparelho, criado no primeiro uso e mantido para sempre.
  Future<String> dispositivoId() async {
    final atual = await local.lerMeta('dispositivo_id');
    if (atual != null) return atual;
    final novo = novoUuid();
    await local.gravarMeta('dispositivo_id', novo);
    return novo;
  }

  Future<DateTime?> ultimaSincronizacao() async {
    final valor = await local.lerMeta('ultima_sincronizacao');
    return valor == null ? null : DateTime.parse(valor);
  }

  Future<OperacaoFila> enfileirar({
    required int usuarioId,
    required String tipo,
    required Map<String, dynamic> dados,
    required String resumo,
    int? bemId,
  }) async {
    final agora = _agora();
    final linha = {
      'id': novoUuid(),
      'usuario_id': usuarioId,
      'tipo': tipo,
      'criada_em': agora.toIso8601String(),
      'dados': jsonEncode(dados),
      'resumo': resumo,
      'bem_id': bemId,
      'estado': EstadoOperacao.pendente.name,
      'tentativas': 0,
      'atualizada_em': agora.toIso8601String(),
    };
    await local.db.insert('fila_operacoes', linha);
    return OperacaoFila._deLinha(linha);
  }

  /// Todas as operações do usuário: as que aguardam envio primeiro, depois as respondidas.
  Future<List<OperacaoFila>> listar(int usuarioId) async {
    final linhas = await local.db.query(
      'fila_operacoes',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
      orderBy: "CASE WHEN estado IN ('pendente', 'enviando', 'erro') THEN 0 ELSE 1 END, criada_em DESC",
    );
    return linhas.map(OperacaoFila._deLinha).toList();
  }

  Future<int> contarAguardando(int usuarioId) async =>
      Sqflite.firstIntValue(await local.db.rawQuery(
        "SELECT count(*) FROM fila_operacoes WHERE usuario_id = ? AND estado IN ('pendente', 'enviando', 'erro')",
        [usuarioId],
      )) ??
      0;

  /// Operações do bem que ainda aguardam envio (para a tela não oferecer ações repetidas).
  Future<List<OperacaoFila>> aguardandoDoBem(int bemId, int usuarioId) async {
    final linhas = await local.db.query(
      'fila_operacoes',
      where: "bem_id = ? AND usuario_id = ? AND estado IN ('pendente', 'enviando', 'erro')",
      whereArgs: [bemId, usuarioId],
      orderBy: 'criada_em',
    );
    return linhas.map(OperacaoFila._deLinha).toList();
  }

  Future<ResumoSincronizacao> sincronizar(int usuarioId) async {
    if (_sincronizando) return const ResumoSincronizacao();
    _sincronizando = true;
    try {
      final linhas = await local.db.query(
        'fila_operacoes',
        where: "usuario_id = ? AND estado IN ('pendente', 'enviando', 'erro')",
        whereArgs: [usuarioId],
        orderBy: 'criada_em, id',
      );
      final operacoes = linhas.map(OperacaoFila._deLinha).toList();
      if (operacoes.isEmpty) return const ResumoSincronizacao();

      final dispositivo = await dispositivoId();
      final contagem = <EstadoOperacao, int>{};
      var enviadas = 0;
      for (var inicio = 0; inicio < operacoes.length; inicio += tamanhoLote) {
        final lote = operacoes.sublist(inicio, (inicio + tamanhoLote).clamp(0, operacoes.length));
        await _marcar(lote.map((o) => o.id), EstadoOperacao.enviando, incrementarTentativa: true);
        final Map<String, dynamic> resposta;
        try {
          resposta = await enviarLote({
            'dispositivo_id': dispositivo,
            'operacoes': [
              for (final o in lote)
                {'id': o.id, 'tipo': o.tipo, 'criada_em': o.criadaEm.toIso8601String(), 'dados': o.dados},
            ],
          });
        } catch (erro) {
          // Sem confirmação do servidor: tudo o que não foi confirmado volta a aguardar envio.
          await _marcar(operacoes.skip(inicio).map((o) => o.id), EstadoOperacao.pendente);
          return _resumo(contagem, enviadas, falha: erro.toString().replaceFirst('Exception: ', ''));
        }
        await _aplicarResultados(resposta, contagem);
        enviadas += lote.length;
      }
      await local.gravarMeta('ultima_sincronizacao', _agora().toIso8601String());
      await limparRespondidas();
      return _resumo(contagem, enviadas);
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> _aplicarResultados(Map<String, dynamic> resposta, Map<EstadoOperacao, int> contagem) async {
    final agora = _agora().toIso8601String();
    final lote = local.db.batch();
    for (final item in (resposta['resultados'] as List).cast<Map>()) {
      final status = item['status'] as String;
      // "processando": o servidor ainda não concluiu (ex.: tentativa anterior interrompida). Reenviar depois.
      final estado = status == 'processando' ? EstadoOperacao.pendente : EstadoOperacao.values.byName(status);
      contagem[estado] = (contagem[estado] ?? 0) + 1;
      lote.update(
        'fila_operacoes',
        {'estado': estado.name, 'mensagem': item['mensagem'], 'atualizada_em': agora},
        where: 'id = ?',
        whereArgs: [item['id']],
      );
    }
    await lote.commit(noResult: true);
  }

  Future<void> _marcar(Iterable<String> ids, EstadoOperacao estado, {bool incrementarTentativa = false}) async {
    final lista = ids.toList();
    if (lista.isEmpty) return;
    final marcadores = List.filled(lista.length, '?').join(', ');
    await local.db.rawUpdate(
      'UPDATE fila_operacoes SET estado = ?, atualizada_em = ?'
      '${incrementarTentativa ? ', tentativas = tentativas + 1' : ''} WHERE id IN ($marcadores)',
      [estado.name, _agora().toIso8601String(), ...lista],
    );
  }

  /// Apaga do aparelho o que já foi respondido há tempo: aceitas após 7 dias, recusadas e em
  /// conflito após 30 (o servidor guarda o registro de todas).
  Future<void> limparRespondidas() async {
    final agora = _agora();
    await local.db.delete(
      'fila_operacoes',
      where: "(estado = 'aceita' AND atualizada_em < ?) OR (estado IN ('recusada', 'conflito') AND atualizada_em < ?)",
      whereArgs: [
        agora.subtract(_manterAceitas).toIso8601String(),
        agora.subtract(_manterRespondidas).toIso8601String(),
      ],
    );
  }

  ResumoSincronizacao _resumo(Map<EstadoOperacao, int> c, int enviadas, {String? falha}) => ResumoSincronizacao(
        enviadas: enviadas,
        aceitas: c[EstadoOperacao.aceita] ?? 0,
        recusadas: c[EstadoOperacao.recusada] ?? 0,
        conflitos: c[EstadoOperacao.conflito] ?? 0,
        erros: c[EstadoOperacao.erro] ?? 0,
        falhaDeRede: falha,
      );
}
