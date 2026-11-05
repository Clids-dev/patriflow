import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/api_client.dart';
import '../../core/utils/app_helpers.dart';

/// Gera o termo de responsabilidade do responsável pela API (HTML para impressão)
/// e compartilha o arquivo, para abrir e imprimir pelo aparelho.
Future<void> compartilharTermo(
  BuildContext context,
  Map<String, dynamic> responsavel,
) async {
  try {
    final id = responsavel['id'];
    final resposta = await ApiClient.getResponse('/termos/responsavel/$id');
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw Exception('Não foi possível gerar o termo (${resposta.statusCode}).');
    }
    final nome = 'termo_responsavel_$id.html';
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(resposta.bodyBytes),
          name: nome,
          mimeType: 'text/html',
        ),
      ],
      text: 'Termo de responsabilidade - ${responsavel['nome'] ?? ''}',
      fileNameOverrides: [nome],
    );
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
  }
}
