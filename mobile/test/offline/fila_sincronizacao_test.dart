import 'package:flutter_test/flutter_test.dart';
import 'package:patriflow_app/core/offline/fila_sincronizacao.dart';
import 'package:patriflow_app/core/offline/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Servidor simulado: guarda os lotes recebidos e responde com o status escolhido por operação.
class ServidorFalso {
  final lotes = <Map<String, dynamic>>[];
  final idsRecebidos = <String>{};
  String Function(Map<String, dynamic> op) statusPara = (_) => 'aceita';
  int falharNoLote = -1;

  Future<Map<String, dynamic>> enviar(Map<String, dynamic> corpo) async {
    if (lotes.length == falharNoLote) {
      lotes.add(corpo);
      throw Exception('Sem conexão com o servidor');
    }
    lotes.add(corpo);
    final ops = (corpo['operacoes'] as List).cast<Map<String, dynamic>>();
    return {
      'resultados': [
        for (final op in ops)
          {
            'id': op['id'],
            'status': statusPara(op),
            'mensagem': statusPara(op) == 'aceita' ? null : 'motivo do servidor',
            'repetida': !idsRecebidos.add(op['id'] as String),
          },
      ],
    };
  }
}

void main() {
  late LocalDatabase local;
  late ServidorFalso servidor;
  late FilaSincronizacao fila;
  var relogio = DateTime(2026, 11, 7, 9);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    local = await LocalDatabase.abrir(databaseFactoryFfi, inMemoryDatabasePath);
    servidor = ServidorFalso();
    relogio = DateTime(2026, 11, 7, 9);
    fila = FilaSincronizacao(local: local, enviarLote: servidor.enviar, tamanhoLote: 2, agora: () => relogio);
  });

  tearDown(() => local.db.close());

  Future<OperacaoFila> registrar(String tipo, {int usuario = 1, int minutos = 0}) {
    relogio = DateTime(2026, 11, 7, 9).add(Duration(minutes: minutos));
    return fila.enfileirar(usuarioId: usuario, tipo: tipo, dados: {'bem_id': 1}, resumo: 'Bem 1', bemId: 1);
  }

  test('envia na ordem de criação, em lotes, e esvazia só o que foi aceito', () async {
    final c = await registrar('c', minutos: 3);
    final a = await registrar('a', minutos: 1);
    final b = await registrar('b', minutos: 2);
    servidor.statusPara = (op) => op['tipo'] == 'b' ? 'conflito' : 'aceita';

    final resumo = await fila.sincronizar(1);

    final enviados = [for (final l in servidor.lotes) ...(l['operacoes'] as List).map((o) => o['id'])];
    expect(enviados, [a.id, b.id, c.id]);
    expect(servidor.lotes, hasLength(2)); // tamanhoLote = 2
    expect(resumo.aceitas, 2);
    expect(resumo.conflitos, 1);
    expect(await fila.contarAguardando(1), 0);
    final estados = {for (final o in await fila.listar(1)) o.id: o.estado};
    expect(estados[b.id], EstadoOperacao.conflito); // conflito continua visível
    expect(await fila.ultimaSincronizacao(), isNotNull);
  });

  test('queda de rede no meio devolve o restante à fila, e o reenvio não duplica', () async {
    for (var i = 0; i < 4; i++) {
      await registrar('op$i', minutos: i);
    }
    servidor.falharNoLote = 1; // o segundo lote falha

    final primeira = await fila.sincronizar(1);
    expect(primeira.falhaDeRede, contains('Sem conexão'));
    expect(primeira.aceitas, 2);
    expect(await fila.contarAguardando(1), 2);
    final pendentes = (await fila.listar(1)).where((o) => o.aguardandoEnvio);
    expect(pendentes.every((o) => o.estado == EstadoOperacao.pendente), isTrue);

    servidor.falharNoLote = -1;
    final segunda = await fila.sincronizar(1);
    expect(segunda.aceitas, 2);
    expect(await fila.contarAguardando(1), 0);
    // O lote que falhou foi reenviado com os mesmos ids: o servidor reconhece pela identidade.
    expect(servidor.lotes.last['operacoes'], servidor.lotes[1]['operacoes']);
  });

  test('cada usuário só envia as próprias operações', () async {
    await registrar('do_usuario_1', usuario: 1);
    await registrar('do_usuario_2', usuario: 2);

    await fila.sincronizar(2);

    final tipos = [for (final l in servidor.lotes) ...(l['operacoes'] as List).map((o) => o['tipo'])];
    expect(tipos, ['do_usuario_2']);
    expect(await fila.contarAguardando(1), 1);
  });

  test('erro do servidor fica aguardando e é reenviado na próxima vez', () async {
    final op = await registrar('instavel');
    servidor.statusPara = (_) => 'erro';
    await fila.sincronizar(1);
    expect(await fila.contarAguardando(1), 1);

    servidor.statusPara = (_) => 'aceita';
    await fila.sincronizar(1);
    final final_ = (await fila.listar(1)).single;
    expect(final_.id, op.id);
    expect(final_.estado, EstadoOperacao.aceita);
    expect(final_.tentativas, 2);
  });

  test('identificador do aparelho é criado uma vez e reaproveitado', () async {
    final primeiro = await fila.dispositivoId();
    expect(await fila.dispositivoId(), primeiro);
    expect(primeiro, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
  });

  test('respondidas antigas são limpas; recusadas ficam por 30 dias', () async {
    await registrar('aceita_antiga');
    await registrar('recusada_recente', minutos: 1);
    servidor.statusPara = (op) => op['tipo'] == 'aceita_antiga' ? 'aceita' : 'recusada';
    await fila.sincronizar(1);

    relogio = relogio.add(const Duration(days: 8));
    await fila.limparRespondidas();

    expect((await fila.listar(1)).map((o) => o.tipo), ['recusada_recente']);
  });
}
