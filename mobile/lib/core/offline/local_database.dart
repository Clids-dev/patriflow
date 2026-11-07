import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Banco local do aparelho (SQLite): acervo baixado do setor e fila de sincronização.
///
/// O acervo e a fila ficam em tabelas separadas. Baixar o acervo de novo substitui só as
/// tabelas `acervo_*`; a fila nunca é apagada por um download nem por fim de sessão.
class LocalDatabase {
  LocalDatabase._(this.db);

  final Database db;

  static const versao = 1;
  static const _arquivo = 'patriflow_offline.db';
  static Future<LocalDatabase>? _aberto;

  /// Banco do aplicativo, aberto uma única vez.
  static Future<LocalDatabase> instancia() => _aberto ??= _abrirPadrao();

  static Future<LocalDatabase> _abrirPadrao() async {
    final caminho = p.join(await getDatabasesPath(), _arquivo);
    return abrir(databaseFactory, caminho);
  }

  /// Abre (ou cria) o banco. Nos testes, use `databaseFactoryFfi` e `inMemoryDatabasePath`.
  static Future<LocalDatabase> abrir(DatabaseFactory fabrica, String caminho) async {
    final db = await fabrica.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: versao,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _criar(db),
      ),
    );
    return LocalDatabase._(db);
  }

  static Future<void> _criar(Database db) async {
    final lote = db.batch()
      // Um acervo por vez (o do setor baixado por último).
      ..execute('''
        CREATE TABLE acervo_meta (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          setor_id INTEGER NOT NULL,
          setor_nome TEXT NOT NULL,
          baixado_em TEXT NOT NULL,
          gerado_em TEXT NOT NULL,
          total_bens INTEGER NOT NULL,
          fotos_baixadas INTEGER NOT NULL,
          fotos_com_falha INTEGER NOT NULL,
          pasta_fotos TEXT
        )''')
      ..execute('''
        CREATE TABLE acervo_bens (
          id INTEGER PRIMARY KEY,
          codigo_tombamento TEXT NOT NULL,
          nome TEXT NOT NULL,
          ficha TEXT NOT NULL,
          foto_arquivo TEXT
        )''')
      ..execute('CREATE INDEX acervo_bens_codigo ON acervo_bens (codigo_tombamento COLLATE NOCASE)')
      ..execute('CREATE INDEX acervo_bens_nome ON acervo_bens (nome COLLATE NOCASE)')
      // Categorias, setores e localizações, guardados como JSON por chave.
      ..execute('CREATE TABLE acervo_referencias (chave TEXT PRIMARY KEY, dados TEXT NOT NULL)')
      ..execute('''
        CREATE TABLE fila_operacoes (
          id TEXT PRIMARY KEY,
          usuario_id INTEGER NOT NULL,
          tipo TEXT NOT NULL,
          criada_em TEXT NOT NULL,
          dados TEXT NOT NULL,
          resumo TEXT NOT NULL,
          bem_id INTEGER,
          estado TEXT NOT NULL DEFAULT 'pendente'
            CHECK (estado IN ('pendente', 'enviando', 'aceita', 'recusada', 'conflito', 'erro')),
          mensagem TEXT,
          tentativas INTEGER NOT NULL DEFAULT 0,
          atualizada_em TEXT NOT NULL
        )''')
      ..execute('CREATE INDEX fila_por_estado ON fila_operacoes (usuario_id, estado, criada_em)')
      ..execute('CREATE INDEX fila_por_bem ON fila_operacoes (bem_id, estado)')
      ..execute('CREATE TABLE sync_meta (chave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
    await lote.commit(noResult: true);
  }

  Future<String?> lerMeta(String chave) async {
    final linhas = await db.query('sync_meta', where: 'chave = ?', whereArgs: [chave], limit: 1);
    return linhas.isEmpty ? null : linhas.first['valor'] as String;
  }

  Future<void> gravarMeta(String chave, String valor) => db.insert(
        'sync_meta',
        {'chave': chave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
