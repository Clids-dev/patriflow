import 'package:flutter/material.dart';

import '../offline/sincronizacao_controller.dart';
import '../theme/app_theme.dart';

/// Indicador de conexão e fila na barra superior, presente em todas as telas da casca.
/// Toque abre a tela de sincronização.
class StatusConexaoAcao extends StatelessWidget {
  const StatusConexaoAcao({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = SincronizacaoController.instancia;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final (icone, cor, texto) = switch (controller.status) {
          _ when controller.sincronizando => (Icons.cloud_sync_outlined, AppColors.primary, 'Sincronizando'),
          StatusConexao.online => (Icons.cloud_done_outlined, AppColors.success, 'Online'),
          StatusConexao.offline => (Icons.cloud_off_outlined, AppColors.error, 'Sem conexão'),
          StatusConexao.verificando => (Icons.cloud_queue_outlined, AppColors.textSecondary, 'Verificando'),
        };
        final fila = controller.aguardando;
        final descricao = fila == 0 ? texto : '$texto, $fila na fila';
        return Semantics(
          button: true,
          label: '$descricao. Abrir sincronização',
          child: Tooltip(
            message: descricao,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icone, color: cor, size: 22),
                    if (fila > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$fila',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
