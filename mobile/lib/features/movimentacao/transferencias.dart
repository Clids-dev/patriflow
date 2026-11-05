import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/app_states.dart';

/// Regras de transferência do app. A API valida tudo; aqui só coletamos os dados
/// obrigatórios e mostramos a ação certa para cada etapa.
///
/// Dupla confirmação (regra definida com o professor):
/// - "liberar": o responsável do setor de ORIGEM libera (ou recusa) o bem;
/// - "receber": o responsável do setor de DESTINO confirma o recebimento, com foto;
/// - "intervir": o almoxarifado (ou o patrimônio) cancela com motivo, quando há algo errado.
/// Transferências antigas (fluxo "simples") seguem a regra anterior: confirmação com foto.

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

/// Solicita o bem para o setor informado. A origem é o local atual do bem, definido pela API.
Future<bool> solicitarTransferencia(
  BuildContext context, {
  required int bemId,
  required int destinoId,
}) async {
  final motivo = await pedirMotivo(
    context,
    titulo: 'Motivo da solicitação',
    rotulo: 'Por que o seu setor precisa deste bem?',
    confirmar: 'Solicitar',
    ajuda: 'O responsável do setor onde o bem está vai ver este motivo.',
  );
  if (motivo == null || !context.mounted) return false;
  try {
    await ApiClient.post('/movimentacao/', {
      'bem_id': bemId,
      'setor_destino_id': destinoId,
      'justificativa': motivo,
    });
    if (context.mounted) {
      showAppMessage(context, 'Solicitação enviada ao responsável do setor.');
    }
    return true;
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
    return false;
  }
}

/// Libera (etapa "liberar") ou confirma o recebimento (etapa "receber", ou fluxo antigo).
/// Só a confirmação pede foto. A API valida quem pode decidir.
Future<bool> autorizarTransferencia(
  BuildContext context,
  Map<String, dynamic> mov,
) async {
  final precisaFoto = mov['etapa'] == 'receber' || mov['fluxo'] == 'simples';
  if (!precisaFoto) {
    final liberar = await confirmAction(
      context,
      'Liberar ${mov['bem_nome'] ?? 'este bem'} para ${mov['setor_destino_nome'] ?? 'o setor solicitante'}?',
    );
    if (!liberar || !context.mounted) return false;
    try {
      await ApiClient.post('/movimentacao/${mov['id']}/aprovar', {});
      if (context.mounted) showAppMessage(context, 'Bem liberado. Aguarda o recebimento no destino.');
      return true;
    } catch (e) {
      if (context.mounted) showAppMessage(context, '$e');
      return false;
    }
  }

  final foto = await _capturarFoto(context);
  if (foto == null || !context.mounted) {
    if (context.mounted) {
      showAppMessage(context, 'A foto do recebimento é obrigatória para confirmar.');
    }
    return false;
  }
  final confirmado = await confirmAction(
    context,
    'Confirmar o recebimento de ${mov['bem_nome'] ?? 'este bem'}?',
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
    if (context.mounted) showAppMessage(context, 'Recebimento confirmado.');
    return true;
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
    return false;
  }
}

/// Recusa a transferência em qualquer etapa. O motivo é obrigatório e fica com a solicitação.
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
    await ApiClient.post('/movimentacao/${mov['id']}/recusar', {'motivo': motivo});
    if (context.mounted) showAppMessage(context, 'Solicitação recusada.');
    return true;
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
    return false;
  }
}

/// Intervenção do almoxarifado: cancela a transferência aberta, com motivo.
Future<bool> intervirTransferencia(
  BuildContext context,
  Map<String, dynamic> mov,
) async {
  final motivo = await pedirMotivo(
    context,
    titulo: 'Intervir na transferência',
    rotulo: 'O que está fora dos conformes?',
    confirmar: 'Cancelar transferência',
    ajuda: 'Quem solicitou e os dois setores vão ver este motivo.',
  );
  if (motivo == null || !context.mounted) return false;
  try {
    await ApiClient.post('/movimentacao/${mov['id']}/intervir', {'motivo': motivo});
    if (context.mounted) showAppMessage(context, 'Transferência cancelada.');
    return true;
  } catch (e) {
    if (context.mounted) showAppMessage(context, '$e');
    return false;
  }
}

/// Estado exibido no cartão. A etapa aberta vem antes do resultado.
({String label, Color color}) estadoTransferencia(Map<String, dynamic> mov) {
  final status = '${mov['status'] ?? 'aprovada'}';
  return switch (status) {
    'pendente' => mov['escalada'] == true
        ? (label: 'Escalada', color: AppColors.error)
        : (label: 'Aguarda liberação', color: AppColors.warning),
    'liberada' => mov['escalada'] == true
        ? (label: 'Escalada', color: AppColors.error)
        : (label: 'Aguarda recebimento', color: AppColors.primary),
    'recusada' => (label: 'Recusada', color: AppColors.error),
    'cancelada' => (label: 'Cancelada', color: AppColors.textSecondary),
    _ => (label: 'Concluída', color: AppColors.success),
  };
}

/// Cartão de uma transferência, com o motivo da solicitação e o motivo da decisão.
/// As ações (liberar, confirmar, recusar, intervir) entram pelo parâmetro.
class TransferenciaCard extends StatelessWidget {
  const TransferenciaCard({super.key, required this.mov, this.acoes});

  final Map<String, dynamic> mov;
  final Widget? acoes;

  @override
  Widget build(BuildContext context) {
    final estado = estadoTransferencia(mov);
    final motivoDecisao = mov['motivo_decisao'];
    final decisor = mov['decisor_nome'];
    final encerrada = mov['status'] == 'recusada' || mov['status'] == 'cancelada';
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
            '${mov['setor_origem_nome'] ?? 'Sem origem'} → ${mov['setor_destino_nome'] ?? ''}',
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
          if (encerrada && (motivoDecisao ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${mov['status'] == 'cancelada' ? 'Cancelada' : 'Recusada'}${decisor != null ? ' por $decisor' : ''}: $motivoDecisao',
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

/// Escolhe um bem (de qualquer setor) e envia a solicitação para o setor do usuário.
Future<bool> escolherBemESolicitar(
  BuildContext context, {
  required int destinoId,
}) async {
  final bem = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _EscolhaBemSheet(),
  );
  if (bem == null || !context.mounted) return false;
  return solicitarTransferencia(context, bemId: bem['id'] as int, destinoId: destinoId);
}

class _EscolhaBemSheet extends StatefulWidget {
  @override
  State<_EscolhaBemSheet> createState() => _EscolhaBemSheetState();
}

class _EscolhaBemSheetState extends State<_EscolhaBemSheet> {
  late final Future<List<dynamic>> _bens = ApiClient.get('/bem/');
  String _busca = '';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: FutureBuilder<List<dynamic>>(
        future: _bens,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading(label: 'Buscando bens...');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'Erro ao carregar bens',
              description: '${snapshot.error}',
            );
          }
          final termo = _busca.toLowerCase();
          final bens = (snapshot.data ?? [])
              .where((b) => b['ativo'] == true)
              .where((b) => '${b['nome']} ${b['codigo_tombamento']}'.toLowerCase().contains(termo))
              .toList();
          return Column(
            children: [
              Padding(
                padding: AppSpacing.screen,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nome ou tombo',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _busca = v.trim()),
                ),
              ),
              Expanded(
                child: bens.isEmpty
                    ? const AppEmptyState(
                        title: 'Nenhum bem encontrado',
                        description: 'Tente outro nome ou tombo.',
                      )
                    : ListView(
                        padding: AppSpacing.screen,
                        children: [
                          for (final raw in bens)
                            AppListCard(
                              leading: const AppIconBadge(
                                icon: Icons.inventory_2_outlined,
                              ),
                              title: '${raw['nome'] ?? ''}',
                              subtitle: '${raw['codigo_tombamento'] ?? ''}',
                              onTap: () => Navigator.pop(
                                context,
                                Map<String, dynamic>.from(raw),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
