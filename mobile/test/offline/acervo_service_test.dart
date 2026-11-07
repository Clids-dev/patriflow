import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:patriflow_app/core/offline/acervo_repository.dart';
import 'package:patriflow_app/core/offline/acervo_service.dart';
import 'package:patriflow_app/core/offline/fila_sincronizacao.dart';
import 'package:patriflow_app/core/offline/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> acervoDoServidor({List<Map<String, dynamic>>? bens}) => {
      'setor': {'id': 1, 'nome': 'Departamento de Tecnologia'},
      'gerado_em': '2026-11-07T09:00:00',
      'bens': bens ??
          [
            {'id': 1, 'codigo_tombamento': 'NTB-0001-7', 'nome': 'Notebook Dell', 'setor_id': 1, 'foto_referencia_id': 10},
            {'id': 2, 'codigo_tombamento': 'MON-0001-0', 'nome': 'Monitor LG', 'setor_id': 1, 'foto_referencia_id': null},
          ],
      'categorias': [
        {'id': 1, 'nome': 'Informática', 'sigla': 'INF'},
      ],
      'setores': [
        {'id': 1, 'nome': 'Departamento de Tecnologia'},
      ],
      'localizacoes': {'predios': [], 'andares': [], 'salas': []},
    };

void main() {
  late LocalDatabase local;
  late AcervoRepository repo;
  late Directory pasta;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    local = await LocalDatabase.abrir(databaseFactoryFfi, inMemoryDatabasePath);
    repo = AcervoRepository(local);
    pasta = await Directory.systemTemp.createTemp('acervo_teste_');
  });

  tearDown(() async {
    await local.db.close();
    await pasta.delete(recursive: true);
  });

  AcervoService servico({
    Future<Map<String, dynamic>> Function(int)? buscar,
    Future<Uint8List?> Function(int)? foto,
  }) =>
      AcervoService(
        repository: repo,
        buscarAcervo: buscar ?? (_) async => acervoDoServidor(),
        baixarFoto: foto ?? (_) async => Uint8List.fromList([1, 2, 3]),
        pastaBase: () async => pasta,
      );

  test('baixa o acervo, guarda as fotos e permite consultar sem rede', () async {
    final resultado = await servico().baixar(1);

    expect(resultado.totalBens, 2);
    expect(resultado.fotosBaixadas, 1);
    final meta = await repo.meta();
    expect(meta!.setorNome, 'Departamento de Tecnologia');
    expect(meta.totalBens, 2);
    expect((await repo.buscar('note')).single.codigoTombamento, 'NTB-0001-7');
    expect((await repo.porTombo('mon-0001-0'))!.nome, 'Monitor LG'); // sem diferenciar maiúsculas
    final bem = await repo.porId(1);
    expect(await (await servico().fotoDoBem(bem!))!.readAsBytes(), [1, 2, 3]);
    expect((await repo.referencias('categorias')).single['sigla'], 'INF');
  });

  test('falha ao buscar os dados mantém o acervo anterior', () async {
    await servico().baixar(1);
    await expectLater(
      servico(buscar: (_) async => throw Exception('Sem conexão')).baixar(1),
      throwsException,
    );
    expect(await repo.contar(), 2);
    expect((await repo.meta())!.totalBens, 2);
  });

  test('queda de rede durante as fotos mantém o acervo anterior e não deixa pasta órfã', () async {
    await servico().baixar(1);
    final pastasAntes = pasta.listSync().length;
    await expectLater(
      servico(
        buscar: (_) async => acervoDoServidor(bens: [
          {'id': 9, 'codigo_tombamento': 'CAD-0001-1', 'nome': 'Cadeira', 'foto_referencia_id': 99},
        ]),
        foto: (_) async => throw Exception('Conexão perdida'),
      ).baixar(1),
      throwsException,
    );
    expect((await repo.buscar('')).map((b) => b.id), unorderedEquals([1, 2])); // o acervo anterior continua
    expect(pasta.listSync().length, pastasAntes);
  });

  test('foto que não existe mais no servidor não impede o download', () async {
    final resultado = await servico(foto: (_) async => null).baixar(1);
    expect(resultado.fotosComFalha, 1);
    expect((await repo.meta())!.fotosComFalha, 1);
    expect(await repo.contar(), 2);
  });

  test('baixar de novo não apaga a fila de sincronização', () async {
    final fila = FilaSincronizacao(local: local, enviarLote: (_) async => {'resultados': []});
    await fila.enfileirar(usuarioId: 1, tipo: 'emprestimo_registrar', dados: {}, resumo: 'Bem 1', bemId: 1);

    await servico().baixar(1);
    await servico().baixar(1);

    expect(await fila.contarAguardando(1), 1);
  });

  test('cada download troca a pasta de fotos e apaga a anterior', () async {
    await servico().baixar(1);
    final primeira = (await repo.meta())!.pastaFotos;
    await servico().baixar(1);
    final segunda = (await repo.meta())!.pastaFotos;
    expect(segunda, isNot(primeira));
    expect(pasta.listSync().map((e) => e.path.split(Platform.pathSeparator).last), [segunda]);
  });
}
