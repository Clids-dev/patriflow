import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patriflow_app/core/offline/acervo_repository.dart';
import 'package:patriflow_app/core/offline/acervo_service.dart';
import 'package:patriflow_app/core/offline/fila_sincronizacao.dart';
import 'package:patriflow_app/core/offline/local_database.dart';
import 'package:patriflow_app/core/offline/sincronizacao_controller.dart';
import 'package:patriflow_app/features/offline/acervo_offline_page.dart';
import 'package:patriflow_app/features/offline/sincronizacao_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDatabase local;
  late FilaSincronizacao fila;
  late AcervoService acervo;
  late Directory pasta;
  final controller = SincronizacaoController.instancia;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    local = await LocalDatabase.abrir(databaseFactoryFfi, inMemoryDatabasePath);
    pasta = await Directory.systemTemp.createTemp('telas_offline_');
    fila = FilaSincronizacao(local: local, enviarLote: (_) async => {'resultados': []});
    acervo = AcervoService(
      repository: AcervoRepository(local),
      buscarAcervo: (_) async => {
        'setor': {'id': 1, 'nome': 'Departamento de Tecnologia'},
        'gerado_em': '2026-11-07T09:00:00',
        'bens': [
          {'id': 1, 'codigo_tombamento': 'NTB-0001-7', 'nome': 'Notebook Dell', 'setor_id': 1, 'status': 'Em Uso'},
          {
            'id': 2, 'codigo_tombamento': 'MON-0001-0', 'nome': 'Monitor LG', 'setor_id': 1, 'status': 'Em Uso',
            'emprestimo_aberto_id': 7, 'emprestado_para': 'Maria Souza', 'devolucao_prevista': '2026-11-10',
          },
        ],
        'categorias': [],
        'setores': [],
        'localizacoes': {'predios': [], 'andares': [], 'salas': []},
      },
      baixarFoto: (_) async => Uint8List(0),
      pastaBase: () async => pasta,
    );
  });

  tearDown(() async {
    await local.db.close();
    await pasta.delete(recursive: true);
  });

  /// Área de um celular em pé, para a tela inteira ser construída (a ListView só monta o que é visível).
  Future<void> telaDeCelular(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  /// O banco (ffi) responde fora do relógio simulado: deixa as consultas terminarem e redesenha.
  Future<void> esperarBanco(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
  }

  testWidgets('fila mostra a operação registrada sem rede como aguardando envio', (tester) async {
    await tester.runAsync(() => controller.configurarParaTeste(usuarioId: 1, fila: fila, acervo: acervo));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SincronizacaoPage())));
    await esperarBanco(tester);
    expect(find.text('Fila vazia'), findsOneWidget);
    expect(find.text('Nunca'), findsOneWidget);

    await tester.runAsync(() => controller.registrar(
          tipo: 'manutencao_enviar',
          dados: {'bem_id': 1, 'descricao': 'Tela piscando', 'destino': 'Assistência'},
          resumo: 'NTB-0001-7 · Notebook Dell',
          bemId: 1,
        ));
    await esperarBanco(tester);
    await esperarBanco(tester); // a lista é recarregada depois da notificação

    expect(find.text('Envio para manutenção'), findsOneWidget);
    expect(find.text('Aguardando envio'), findsWidgets);
    expect(find.textContaining('NTB-0001-7 · Notebook Dell'), findsOneWidget);
  });

  testWidgets('acervo baixado é consultado sem rede e a ação vai para a fila', (tester) async {
    await telaDeCelular(tester);
    await tester.runAsync(() async {
      await controller.configurarParaTeste(usuarioId: 1, fila: fila, acervo: acervo);
      await acervo.baixar(1);
    });
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AcervoOfflinePage(setorId: 1, podeEscolherSetor: false))));
    await esperarBanco(tester);

    expect(find.text('Departamento de Tecnologia'), findsOneWidget);
    expect(find.text('Notebook Dell'), findsOneWidget);
    expect(find.text('Emprestado'), findsOneWidget); // o monitor está emprestado
    expect(find.text('Sem conexão: o acervo do aparelho continua disponível.'), findsOneWidget);

    await tester.tap(find.text('Notebook Dell'));
    await tester.pumpAndSettle();
    await esperarBanco(tester);
    expect(find.text('Ficha do bem (offline)'), findsOneWidget);

    await tester.tap(find.text('Enviar para manutenção'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pump();
    expect(find.text('Informe ao menos 3 caracteres'), findsOneWidget); // valida antes de registrar

    await tester.enterText(find.widgetWithText(TextFormField, 'Problema'), 'Tela piscando');
    await tester.enterText(find.widgetWithText(TextFormField, 'Para onde vai'), 'Assistência Dell');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    await esperarBanco(tester);
    await esperarBanco(tester);

    expect(find.text('Na fila: Envio para manutenção (aguardando envio).'), findsOneWidget);
    expect(find.text('Emprestar'), findsNothing); // nada repetido enquanto a operação não é enviada
    final ops = await tester.runAsync(() => fila.listar(1));
    expect(ops!.single.dados, {'bem_id': 1, 'descricao': 'Tela piscando', 'destino': 'Assistência Dell'});
  });

  testWidgets('bem emprestado oferece a devolução, não um novo empréstimo', (tester) async {
    await telaDeCelular(tester);
    await tester.runAsync(() async {
      await controller.configurarParaTeste(usuarioId: 1, fila: fila, acervo: acervo);
      await acervo.baixar(1);
    });
    final bem = await tester.runAsync(() => acervo.repository.porId(2));
    await tester.pumpWidget(MaterialApp(home: FichaOfflinePage(bem: bem!, setorUsuario: 1)));
    await esperarBanco(tester);

    expect(find.text('Emprestado para Maria Souza até 10/11/2026.'), findsOneWidget);
    expect(find.text('Registrar devolução'), findsOneWidget);
    expect(find.text('Emprestar'), findsNothing);
  });

  testWidgets('colaborador de outro setor não vê ações de guarda', (tester) async {
    await telaDeCelular(tester);
    await tester.runAsync(() async {
      await controller.configurarParaTeste(usuarioId: 1, fila: fila, acervo: acervo);
      await acervo.baixar(1);
    });
    final bem = await tester.runAsync(() => acervo.repository.porId(1));
    await tester.pumpWidget(MaterialApp(home: FichaOfflinePage(bem: bem!, setorUsuario: 99)));
    await esperarBanco(tester);

    expect(find.text('Garantia até'), findsOneWidget); // a ficha inteira foi construída
    expect(find.text('Emprestar'), findsNothing);
    expect(find.text('Enviar para manutenção'), findsNothing);
  });
}
