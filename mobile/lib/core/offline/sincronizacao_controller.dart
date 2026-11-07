import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_client.dart';
import 'acervo_repository.dart';
import 'acervo_service.dart';
import 'fila_sincronizacao.dart';
import 'local_database.dart';

enum StatusConexao { verificando, online, offline }

/// Estado do trabalho sem rede, observado pelas telas: conexão, fila e última sincronização.
///
/// "Online" significa que o servidor respondeu, não apenas que há Wi-Fi ou dados móveis.
/// Quando a conexão volta e há operações na fila, a sincronização começa sozinha.
class SincronizacaoController extends ChangeNotifier {
  SincronizacaoController._();

  static final instancia = SincronizacaoController._();

  StatusConexao status = StatusConexao.verificando;
  int aguardando = 0;
  DateTime? ultimaSincronizacao;
  bool sincronizando = false;
  ResumoSincronizacao? ultimoResumo;

  int? _usuarioId;
  final _pronto = Completer<void>();
  FilaSincronizacao? _fila;
  AcervoService? _acervo;
  StreamSubscription<List<ConnectivityResult>>? _rede;
  Timer? _verificacaoPeriodica;

  int? get usuarioId => _usuarioId;
  bool get online => status == StatusConexao.online;

  FilaSincronizacao get fila => _fila!;
  AcervoService get acervo => _acervo!;

  /// Conclui quando o banco local está aberto. As telas aguardam antes de usar [fila] e [acervo].
  Future<void> get pronto => _pronto.future;

  /// Chamado depois do login. Pode ser chamado de novo para outro usuário.
  Future<void> iniciar({required int usuarioId}) async {
    _usuarioId = usuarioId;
    final local = await LocalDatabase.instancia();
    _fila ??= FilaSincronizacao(
      local: local,
      enviarLote: (corpo) async => Map<String, dynamic>.from(await ApiClient.post('/sincronizacao/', corpo) as Map),
    );
    _acervo ??= AcervoService(
      repository: AcervoRepository(local),
      buscarAcervo: (setorId) => ApiClient.getMap('/acervo/setor/$setorId'),
      baixarFoto: ApiClient.baixarFoto,
      pastaBase: getApplicationDocumentsDirectory,
    );
    if (!_pronto.isCompleted) _pronto.complete();
    _rede ??= Connectivity().onConnectivityChanged.listen((_) => verificarConexao());
    // Sem rede, tenta de novo a cada 30 s para perceber a volta do servidor.
    _verificacaoPeriodica ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (!online) verificarConexao();
    });
    await atualizarContagem();
    await verificarConexao();
  }

  Future<void> verificarConexao() async {
    final antes = status;
    final redes = await Connectivity().checkConnectivity();
    final temRede = redes.any((r) => r != ConnectivityResult.none);
    status = temRede && await ApiClient.servidorAcessivel() ? StatusConexao.online : StatusConexao.offline;
    notifyListeners();
    if (antes != StatusConexao.online && online && aguardando > 0) {
      unawaited(sincronizar());
    }
  }

  Future<void> atualizarContagem() async {
    final usuario = _usuarioId;
    if (usuario == null || _fila == null) return;
    aguardando = await _fila!.contarAguardando(usuario);
    ultimaSincronizacao = await _fila!.ultimaSincronizacao();
    notifyListeners();
  }

  /// Registra a operação na fila e, se houver conexão, já tenta enviar.
  Future<OperacaoFila> registrar({
    required String tipo,
    required Map<String, dynamic> dados,
    required String resumo,
    int? bemId,
  }) async {
    final operacao = await fila.enfileirar(
      usuarioId: _usuarioId!,
      tipo: tipo,
      dados: dados,
      resumo: resumo,
      bemId: bemId,
    );
    await atualizarContagem();
    if (online) unawaited(sincronizar());
    return operacao;
  }

  Future<ResumoSincronizacao?> sincronizar() async {
    final usuario = _usuarioId;
    if (usuario == null || sincronizando) return null;
    sincronizando = true;
    notifyListeners();
    try {
      final resumo = await fila.sincronizar(usuario);
      ultimoResumo = resumo;
      if (resumo.falhaDeRede != null) status = StatusConexao.offline;
      return resumo;
    } finally {
      sincronizando = false;
      await atualizarContagem();
    }
  }

  /// Testes de widget: usa fila e acervo prontos (banco em memória) e um status fixo, sem plugins
  /// nativos de rede.
  @visibleForTesting
  Future<void> configurarParaTeste({
    required int usuarioId,
    required FilaSincronizacao fila,
    required AcervoService acervo,
    StatusConexao status = StatusConexao.offline,
  }) async {
    _usuarioId = usuarioId;
    _fila = fila;
    _acervo = acervo;
    this.status = status;
    if (!_pronto.isCompleted) _pronto.complete();
    await atualizarContagem();
  }

  /// No logout: para de observar a rede. A fila e o acervo continuam guardados no aparelho.
  void encerrar() {
    _rede?.cancel();
    _rede = null;
    _verificacaoPeriodica?.cancel();
    _verificacaoPeriodica = null;
    _usuarioId = null;
    aguardando = 0;
    status = StatusConexao.verificando;
    notifyListeners();
  }
}
