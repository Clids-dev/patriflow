import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'acervo_repository.dart';

/// Busca o acervo do setor na API (lança exceção se não conseguir).
typedef BuscarAcervo = Future<Map<String, dynamic>> Function(int setorId);

/// Baixa a foto. Devolve null se a foto não existe mais no servidor; lança exceção em falha de rede.
typedef BaixarFoto = Future<Uint8List?> Function(int fotoId);

class ResultadoDownload {
  const ResultadoDownload({required this.totalBens, required this.fotosBaixadas, required this.fotosComFalha});

  final int totalBens;
  final int fotosBaixadas;

  /// Fotos que não existem mais no servidor. O acervo foi gravado mesmo assim.
  final int fotosComFalha;
}

/// Download do acervo do setor para uso sem rede (A03).
///
/// Garantias:
/// - Falha ao buscar os dados ou queda de rede durante as fotos: nada muda; o acervo anterior fica.
/// - As fotos vão para uma pasta nova a cada download. O banco só passa a apontar para ela depois
///   de gravado, e as pastas antigas são apagadas em seguida. Dados e fotos trocam juntos.
/// - A fila de sincronização nunca é tocada (ver [AcervoRepository.substituir]).
class AcervoService {
  AcervoService({
    required this.repository,
    required this.buscarAcervo,
    required this.baixarFoto,
    required this.pastaBase,
    DateTime Function()? agora,
  }) : _agora = agora ?? DateTime.now;

  final AcervoRepository repository;
  final BuscarAcervo buscarAcervo;
  final BaixarFoto baixarFoto;
  final Future<Directory> Function() pastaBase;
  final DateTime Function() _agora;

  static const _prefixoPasta = 'acervo_fotos_';

  Future<ResultadoDownload> baixar(int setorId, {void Function(int feitas, int total)? progresso}) async {
    final acervo = await buscarAcervo(setorId);
    final bens = (acervo['bens'] as List).cast<Map>();
    final comFoto = bens.where((b) => b['foto_referencia_id'] != null).toList();

    final base = await pastaBase();
    final nomePasta = '$_prefixoPasta${_agora().microsecondsSinceEpoch}';
    final pasta = Directory(p.join(base.path, nomePasta));
    final fotos = <int, String>{};
    var falhas = 0;
    try {
      if (comFoto.isNotEmpty) await pasta.create(recursive: true);
      for (var i = 0; i < comFoto.length; i++) {
        final bem = comFoto[i];
        final bytes = await baixarFoto(bem['foto_referencia_id'] as int);
        if (bytes == null) {
          falhas++;
        } else {
          final arquivo = 'bem_${bem['id']}.img';
          await File(p.join(pasta.path, arquivo)).writeAsBytes(bytes, flush: true);
          fotos[bem['id'] as int] = arquivo;
        }
        progresso?.call(i + 1, comFoto.length);
      }
      await repository.substituir(
        acervo: acervo,
        fotos: fotos,
        pastaFotos: comFoto.isEmpty ? null : nomePasta,
        fotosComFalha: falhas,
        baixadoEm: _agora(),
      );
    } catch (_) {
      if (await pasta.exists()) await pasta.delete(recursive: true);
      rethrow;
    }
    await _apagarPastasAntigas(base, manter: nomePasta);
    return ResultadoDownload(totalBens: bens.length, fotosBaixadas: fotos.length, fotosComFalha: falhas);
  }

  /// Arquivo local da foto de referência do bem, se houver.
  Future<File?> fotoDoBem(BemOffline bem) async {
    final meta = await repository.meta();
    if (bem.fotoArquivo == null || meta?.pastaFotos == null) return null;
    final arquivo = File(p.join((await pastaBase()).path, meta!.pastaFotos!, bem.fotoArquivo!));
    return await arquivo.exists() ? arquivo : null;
  }

  Future<void> _apagarPastasAntigas(Directory base, {required String manter}) async {
    if (!await base.exists()) return;
    await for (final item in base.list()) {
      final nome = p.basename(item.path);
      if (item is Directory && nome.startsWith(_prefixoPasta) && nome != manter) {
        await item.delete(recursive: true);
      }
    }
  }
}
