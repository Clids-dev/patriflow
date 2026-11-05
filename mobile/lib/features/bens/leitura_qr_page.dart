import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';
import 'ficha_bem_page.dart';

/// Leitura da etiqueta pela câmera (QR Code com o tombo) e busca por digitação.
/// Só lê QR Code, e detecta sem repetir o mesmo código, para ficar leve no aparelho.
class LeituraQrPage extends StatefulWidget {
  const LeituraQrPage({super.key});

  @override
  State<LeituraQrPage> createState() => _LeituraQrPageState();
}

class _LeituraQrPageState extends State<LeituraQrPage> {
  final _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  final _digitado = TextEditingController();
  bool _ocupado = false;

  @override
  void dispose() {
    _scanner.dispose();
    _digitado.dispose();
    super.dispose();
  }

  void _aoDetectar(BarcodeCapture captura) {
    if (_ocupado) return;
    final valor = captura.barcodes.firstOrNull?.rawValue;
    if (valor == null || valor.trim().isEmpty) return;
    _buscar(valor);
  }

  /// Busca o bem pelo tombo. A API valida o dígito verificador e responde com a
  /// mensagem certa se o código for inválido ou não existir.
  Future<void> _buscar(String codigo) async {
    if (_ocupado) return;
    final tombo = codigo.trim().toUpperCase();
    setState(() => _ocupado = true);
    await _scanner.stop();
    try {
      final bem = await ApiClient.getMap(
        '/bem/buscar?codigo_tombamento=${Uri.encodeQueryComponent(tombo)}',
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FichaBemPage(bemId: bem['id'] as int)),
      );
    } catch (e) {
      if (mounted) showAppMessage(context, '$e');
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
        await _scanner.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Ler etiqueta'),
    ),
    body: Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _scanner,
                onDetect: _aoDetectar,
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: AppSpacing.screen,
                    child: Text(
                      'Não foi possível usar a câmera. Verifique a permissão do aplicativo ou digite o tombo abaixo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: AppRadius.cardBorder,
                  ),
                ),
              ),
              if (_ocupado)
                const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
        Container(
          color: AppColors.surface,
          padding: AppSpacing.screen,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _digitado,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Tombo (ex.: TMB-011-1)',
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _buscar(v);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _ocupado
                      ? null
                      : () {
                          if (_digitado.text.trim().isNotEmpty) {
                            _buscar(_digitado.text);
                          }
                        },
                  child: const Text('Buscar'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
