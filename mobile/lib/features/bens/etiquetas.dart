import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/widgets/app_states.dart';

/// Etiqueta de um bem: QR Code com o tombo e o número em texto, gerada pela API.
/// O app mostra a prévia e compartilha o SVG (para imprimir pelo aparelho).
Future<void> mostrarEtiqueta(BuildContext context, Map<String, dynamic> bem) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: _EtiquetaSheet(bem: bem),
    ),
  );
}

class _EtiquetaSheet extends StatefulWidget {
  const _EtiquetaSheet({required this.bem});

  final Map<String, dynamic> bem;

  @override
  State<_EtiquetaSheet> createState() => _EtiquetaSheetState();
}

class _EtiquetaSheetState extends State<_EtiquetaSheet> {
  late final Future<Uint8List> _svg = _carregar();

  Future<Uint8List> _carregar() async {
    final resposta = await ApiClient.getResponse('/etiquetas/${widget.bem['id']}');
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw Exception('Não foi possível gerar a etiqueta (${resposta.statusCode}).');
    }
    return Uint8List.fromList(resposta.bodyBytes);
  }

  Future<void> _compartilhar(Uint8List svg) async {
    final tombo = '${widget.bem['codigo_tombamento'] ?? 'bem'}';
    final nome = 'etiqueta_$tombo.svg';
    await Share.shareXFiles(
      [XFile.fromData(svg, name: nome, mimeType: 'image/svg+xml')],
      text: 'Etiqueta do tombo $tombo',
      fileNameOverrides: [nome],
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: AppSpacing.screen,
    child: FutureBuilder<Uint8List>(
      future: _svg,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 260,
            child: AppLoading(label: 'Gerando etiqueta...'),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 240,
            child: AppErrorState(
              title: 'Erro ao gerar etiqueta',
              description: '${snapshot.error}',
            ),
          );
        }
        final svg = snapshot.data!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.bem['nome'] ?? ''}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.border),
              ),
              child: SvgPicture.memory(svg, height: 220),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => _compartilhar(svg),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartilhar para imprimir'),
            ),
          ],
        );
      },
    ),
  );
}

/// Escolhe vários bens e gera uma folha com as etiquetas, pronta para impressão.
Future<void> gerarEtiquetasLote(
  BuildContext context,
  List<Map<String, dynamic>> bens,
) async {
  final ativos = bens.where((b) => b['ativo'] == true).toList();
  if (ativos.isEmpty) {
    showAppMessage(context, 'Nenhum bem ativo para gerar etiquetas.');
    return;
  }
  final selecionados = await showDialog<List<Map<String, dynamic>>>(
    context: context,
    builder: (ctx) => _SelecaoLoteDialog(bens: ativos),
  );
  if (selecionados == null || selecionados.isEmpty || !context.mounted) return;
  try {
    final ids = selecionados.map((b) => '${b['id']}').join(',');
    final resposta = await ApiClient.getResponse('/etiquetas/lote?ids=$ids');
    if (resposta.statusCode < 200 || resposta.statusCode >= 300) {
      throw Exception('Não foi possível gerar as etiquetas (${resposta.statusCode}).');
    }
    const nome = 'etiquetas_patriflow.html';
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(resposta.bodyBytes),
          name: nome,
          mimeType: 'text/html',
        ),
      ],
      text: 'Etiquetas do patrimônio PatriFlow',
      fileNameOverrides: [nome],
    );
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
  }
}

class _SelecaoLoteDialog extends StatefulWidget {
  const _SelecaoLoteDialog({required this.bens});

  final List<Map<String, dynamic>> bens;

  @override
  State<_SelecaoLoteDialog> createState() => _SelecaoLoteDialogState();
}

class _SelecaoLoteDialogState extends State<_SelecaoLoteDialog> {
  final Set<int> _marcados = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Etiquetas em lote'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final bem in widget.bens)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _marcados.contains(bem['id']),
              title: Text('${bem['nome'] ?? ''}'),
              subtitle: Text('${bem['codigo_tombamento'] ?? ''}'),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _marcados.add(bem['id'] as int);
                } else {
                  _marcados.remove(bem['id']);
                }
              }),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _marcados.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                widget.bens.where((b) => _marcados.contains(b['id'])).toList(),
              ),
        child: Text('Gerar (${_marcados.length})'),
      ),
    ],
  );
}
