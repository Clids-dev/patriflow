import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/widgets/app_components.dart';

/// Regras de transferência usadas por todas as telas do app. A API valida tudo;
/// aqui só coletamos os dados obrigatórios antes de enviar.
///
/// - Solicitar exige motivo.
/// - Autorizar exige a foto do recebimento (enviada antes da decisão).
/// - Recusar exige motivo, que fica visível para quem solicitou.

const _minimoMotivo = 3;

/// Diálogo com um campo de texto obrigatório. Retorna null se o usuário cancelar.
Future<String?> pedirMotivo(
  BuildContext context, {
  required String titulo,
  required String rotulo,
  required String confirmar,
  String? ajuda,
}) async {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  final texto = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: Text(titulo),
      content: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(labelText: rotulo, helperText: ajuda),
          validator: (value) => (value ?? '').trim().length < _minimoMotivo
              ? 'Escreva pelo menos $_minimoMotivo caracteres'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: Text(confirmar),
        ),
      ],
    ),
  );
  controller.dispose();
  return texto;
}

/// Pede ao usuário uma foto da câmera ou da galeria. Retorna null se cancelar.
Future<XFile?> _capturarFoto(BuildContext context) async {
  final origem = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (origem == null) return null;
  return ImagePicker().pickImage(
    source: origem,
    imageQuality: 85,
    maxWidth: 1920,
  );
}

/// Solicita a transferência de um bem do almoxarifado para o setor do usuário.
Future<bool> solicitarTransferencia(
  BuildContext context, {
  required int bemId,
  required int origemId,
  required int destinoId,
}) async {
  final motivo = await pedirMotivo(
    context,
    titulo: 'Motivo da solicitação',
    rotulo: 'Por que o seu setor precisa deste bem?',
    confirmar: 'Solicitar',
    ajuda: 'Quem decide no almoxarifado vê este motivo.',
  );
  if (motivo == null || !context.mounted) return false;
  try {
    await ApiClient.post('/movimentacao/', {
      'bem_id': bemId,
      'setor_origem_id': origemId,
      'setor_destino_id': destinoId,
      'justificativa': motivo,
    });
    if (context.mounted) {
      showAppMessage(context, 'Solicitação enviada ao almoxarifado.');
    }
    return true;
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
    return false;
  }
}

/// Autoriza a transferência. Envia a foto do recebimento antes de aprovar.
Future<bool> autorizarTransferencia(
  BuildContext context,
  Map<String, dynamic> mov,
) async {
  final foto = await _capturarFoto(context);
  if (foto == null || !context.mounted) {
    if (context.mounted) {
      showAppMessage(
        context,
        'A foto do recebimento é obrigatória para autorizar.',
      );
    }
    return false;
  }
  final confirmado = await confirmAction(
    context,
    'Autorizar a transferência de ${mov['bem_nome'] ?? 'este bem'}?',
  );
  if (!confirmado || !context.mounted) return false;
  try {
    await ApiClient.postMultipart(
      '/fotos/',
      fields: {
        'registro_tipo': 'aceite_transferencia',
        'registro_id': '${mov['id']}',
      },
      fileField: 'arquivo',
      filePath: foto.path,
    );
    await ApiClient.post('/movimentacao/${mov['id']}/aprovar', {});
    if (context.mounted) {
      showAppMessage(context, 'Transferência autorizada.');
    }
    return true;
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
    return false;
  }
}

/// Recusa a transferência. O motivo é obrigatório e fica com a solicitação.
Future<bool> recusarTransferencia(
  BuildContext context,
  Map<String, dynamic> mov,
) async {
  final motivo = await pedirMotivo(
    context,
    titulo: 'Motivo da recusa',
    rotulo: 'Por que a solicitação não será atendida?',
    confirmar: 'Recusar',
    ajuda: 'Quem solicitou vai ver este motivo.',
  );
  if (motivo == null || !context.mounted) return false;
  try {
    await ApiClient.post('/movimentacao/${mov['id']}/recusar', {
      'motivo': motivo,
    });
    if (context.mounted) showAppMessage(context, 'Solicitação recusada.');
    return true;
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
    return false;
  }
}

/// Estado exibido no cartão. Escalada tem prioridade sobre pendente.
({String label, Color color}) estadoTransferencia(Map<String, dynamic> mov) {
  final status = '${mov['status'] ?? 'aprovada'}';
  if (status == 'pendente') {
    return mov['escalada'] == true
        ? (label: 'Escalada', color: AppColors.error)
        : (label: 'Pendente', color: AppColors.warning);
  }
  if (status == 'recusada') {
    return (label: 'Recusada', color: AppColors.error);
  }
  return (label: 'Autorizada', color: AppColors.success);
}

/// Cartão de uma transferência, com o motivo da solicitação e, quando houver,
/// o motivo da recusa. Ações (autorizar/recusar) entram pelo parâmetro.
class TransferenciaCard extends StatelessWidget {
  const TransferenciaCard({super.key, required this.mov, this.acoes});

  final Map<String, dynamic> mov;
  final Widget? acoes;

  @override
  Widget build(BuildContext context) {
    final estado = estadoTransferencia(mov);
    final motivoDecisao = mov['motivo_decisao'];
    final decisor = mov['decisor_nome'];
    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${mov['bem_nome'] ?? ''}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              AppStatusChip(label: estado.label, color: estado.color),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${mov['codigo_tombamento'] ?? ''} • ${shortDate(mov['data_movimentacao'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${mov['setor_origem_nome'] ?? 'Almoxarifado'} → ${mov['setor_destino_nome'] ?? ''}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if ((mov['solicitante_nome'] ?? '').toString().isNotEmpty)
            Text(
              'Solicitado por ${mov['solicitante_nome']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if ((mov['justificativa'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Motivo: ${mov['justificativa']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (mov['status'] == 'recusada' &&
              (motivoDecisao ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Recusada${decisor != null ? ' por $decisor' : ''}: $motivoDecisao',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ],
          if (acoes != null) ...[
            const SizedBox(height: AppSpacing.md),
            acoes!,
          ],
        ],
      ),
    );
  }
}
