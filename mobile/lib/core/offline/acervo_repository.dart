import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

class AcervoMeta {
  const AcervoMeta({
    required this.setorId,
    required this.setorNome,
    required this.baixadoEm,
    required this.geradoEm,
    required this.totalBens,
    required this.fotosBaixadas,
    required this.fotosComFalha,
    this.pastaFotos,
  });

  final int setorId;
  final String setorNome;
  final DateTime baixadoEm;
  final DateTime geradoEm;
  final int totalBens;
  final int fotosBaixadas;
  final int fotosComFalha;

  /// Pasta das fotos deste download (relativa à pasta de documentos do app).
  final String? pastaFotos;
}

/// Bem do acervo baixado. `ficha` traz todos os campos enviados pela API.
class BemOffline {
  const BemOffline({
    required this.id,
    required this.codigoTombamento,
    required this.nome,
    required this.ficha,
    this.fotoArquivo,
  });

  final int id;
  final String codigoTombamento;
  final String nome;
  final Map<String, dynamic> ficha;
  final String? fotoArquivo;

  int? get setorId => ficha['setor_id'] as int?;
  int? get emprestimoAbertoId => ficha['emprestimo_aberto_id'] as int?;
  int? get manutencaoAbertaId => ficha['manutencao_aberta_id'] as int?;

  static BemOffline _deLinha(Map<String, Object?> linha) => BemOffline(
        id: linha['id'] as int,
        codigoTombamento: linha['codigo_tombamento'] as String,
        nome: linha['nome'] as String,
        ficha: Map<String, dynamic>.from(jsonDecode(linha['ficha'] as String) as Map),
        fotoArquivo: linha['foto_arquivo'] as String?,
      );
}

class AcervoRepository {
  AcervoRepository(this.local);

  final LocalDatabase local;

  Future<AcervoMeta?> meta() async {
    final linhas = await local.db.query('acervo_meta', limit: 1);
    if (linhas.isEmpty) return null;
    final m = linhas.first;
    return AcervoMeta(
      setorId: m['setor_id'] as int,
      setorNome: m['setor_nome'] as String,
      baixadoEm: DateTime.parse(m['baixado_em'] as String),
      geradoEm: DateTime.parse(m['gerado_em'] as String),
      totalBens: m['total_bens'] as int,
      fotosBaixadas: m['fotos_baixadas'] as int,
      fotosComFalha: m['fotos_com_falha'] as int,
      pastaFotos: m['pasta_fotos'] as String?,
    );
  }

  /// Troca o acervo inteiro numa única transação: ou entra o novo completo, ou fica o anterior.
  /// Só mexe nas tabelas `acervo_*`; a fila de sincronização não é tocada.
  Future<void> substituir({
    required Map<String, dynamic> acervo,
    required Map<int, String> fotos,
    required String? pastaFotos,
    required int fotosComFalha,
    required DateTime baixadoEm,
  }) async {
    final bens = (acervo['bens'] as List).cast<Map>();
    final setor = Map<String, dynamic>.from(acervo['setor'] as Map);
    await local.db.transaction((txn) async {
      await txn.delete('acervo_bens');
      await txn.delete('acervo_referencias');
      await txn.delete('acervo_meta');
      final lote = txn.batch();
      for (final bem in bens) {
        final id = bem['id'] as int;
        lote.insert('acervo_bens', {
          'id': id,
          'codigo_tombamento': bem['codigo_tombamento'],
          'nome': bem['nome'],
          'ficha': jsonEncode(bem),
          'foto_arquivo': fotos[id],
        });
      }
      for (final chave in const ['categorias', 'setores', 'localizacoes']) {
        lote.insert('acervo_referencias', {'chave': chave, 'dados': jsonEncode(acervo[chave])});
      }
      lote.insert('acervo_meta', {
        'id': 1,
        'setor_id': setor['id'],
        'setor_nome': setor['nome'],
        'baixado_em': baixadoEm.toIso8601String(),
        'gerado_em': acervo['gerado_em'].toString(),
        'total_bens': bens.length,
        'fotos_baixadas': fotos.length,
        'fotos_com_falha': fotosComFalha,
        'pasta_fotos': pastaFotos,
      });
      await lote.commit(noResult: true);
    });
  }

  /// Busca por nome ou tombo, sem diferenciar maiúsculas e minúsculas.
  Future<List<BemOffline>> buscar(String termo, {int limite = 300}) async {
    final filtro = termo.trim();
    final linhas = filtro.isEmpty
        ? await local.db.query('acervo_bens', orderBy: 'nome COLLATE NOCASE', limit: limite)
        : await local.db.query(
            'acervo_bens',
            where: 'nome LIKE ? COLLATE NOCASE OR codigo_tombamento LIKE ? COLLATE NOCASE',
            whereArgs: ['%$filtro%', '%$filtro%'],
            orderBy: 'nome COLLATE NOCASE',
            limit: limite,
          );
    return linhas.map(BemOffline._deLinha).toList();
  }

  Future<BemOffline?> porTombo(String codigo) async {
    final linhas = await local.db.query(
      'acervo_bens',
      where: 'codigo_tombamento = ? COLLATE NOCASE',
      whereArgs: [codigo.trim()],
      limit: 1,
    );
    return linhas.isEmpty ? null : BemOffline._deLinha(linhas.first);
  }

  Future<BemOffline?> porId(int id) async {
    final linhas = await local.db.query('acervo_bens', where: 'id = ?', whereArgs: [id], limit: 1);
    return linhas.isEmpty ? null : BemOffline._deLinha(linhas.first);
  }

  Future<List<Map<String, dynamic>>> referencias(String chave) async {
    final linhas = await local.db.query('acervo_referencias', where: 'chave = ?', whereArgs: [chave], limit: 1);
    if (linhas.isEmpty) return const [];
    final dados = jsonDecode(linhas.first['dados'] as String);
    return dados is List ? dados.map((e) => Map<String, dynamic>.from(e as Map)).toList() : const [];
  }

  Future<int> contar() async =>
      Sqflite.firstIntValue(await local.db.rawQuery('SELECT count(*) FROM acervo_bens')) ?? 0;
}
