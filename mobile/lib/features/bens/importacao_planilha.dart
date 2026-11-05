import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';

/// Importação de bens por planilha CSV, no mesmo fluxo da web: primeiro simula
/// (valida tudo sem gravar) e só depois grava. Uma linha inválida não impede as demais.
Future<void> abrirImportacaoPlanilha(
  BuildContext context, {
  required VoidCallback onImported,
}) async {
  const tipoCsv = XTypeGroup(label: 'CSV', extensions: ['csv']);
  final arquivo = await openFile(acceptedTypeGroups: const [tipoCsv]);
  if (arquivo == null) return;
  if (!context.mounted) return;

  final bytes = await arquivo.readAsBytes();
  final nome = arquivo.name;
  try {
    final simulacao = await _enviar(bytes, nome, simular: true);
    if (!context.mounted) return;
    final validas = simulacao['validas'] as int? ?? 0;
    final importar = await showDialog<bool>(
      context: context,
      builder: (ctx) => _RelatorioDialog(
        titulo: 'Simulação da planilha',
        relatorio: simulacao,
        confirmar: validas > 0 ? 'Importar $validas' : null,
      ),
    );
    if (importar != true || !context.mounted) return;

    final resultado = await _enviar(bytes, nome, simular: false);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _RelatorioDialog(
        titulo: 'Importação concluída',
        relatorio: resultado,
      ),
    );
    onImported();
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
  }
}

Future<Map<String, dynamic>> _enviar(
  List<int> bytes,
  String nome, {
  required bool simular,
}) async {
  final resposta = await ApiClient.postMultipart(
    '/bem/importar',
    fields: {'simular': simular ? 'true' : 'false'},
    fileField: 'arquivo',
    fileBytes: Uint8List.fromList(bytes),
    fileName: nome,
  );
  return Map<String, dynamic>.from(resposta as Map);
}

class _RelatorioDialog extends StatelessWidget {
  const _RelatorioDialog({
    required this.titulo,
    required this.relatorio,
    this.confirmar,
  });

  final String titulo;
  final Map<String, dynamic> relatorio;
  final String? confirmar;

  @override
  Widget build(BuildContext context) {
    final erros = (relatorio['erros'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final simulacao = relatorio['simulacao'] == true;
    return AlertDialog(
      scrollable: true,
      title: Text(titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Linhas lidas: ${relatorio['total'] ?? 0}'),
          Text('Válidas: ${relatorio['validas'] ?? 0}'),
          if (!simulacao) Text('Importados: ${relatorio['importados'] ?? 0}'),
          const SizedBox(height: AppSpacing.md),
          if (erros.isEmpty)
            Text(
              'Nenhum erro encontrado.',
              style: TextStyle(color: AppColors.success),
            )
          else ...[
            Text(
              'Erros (${erros.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final e in erros)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('Linha ${e['linha']}: ${e['erro']}'),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(confirmar == null ? 'Fechar' : 'Cancelar'),
        ),
        if (confirmar != null)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmar!),
          ),
      ],
    );
  }
}
