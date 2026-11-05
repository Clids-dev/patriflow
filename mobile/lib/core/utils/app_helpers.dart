import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Diálogo de confirmação padrão. Retorna `true` somente se o usuário confirmar.
Future<bool> confirmAction(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Confirmar'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

/// Mensagem curta no rodapé (SnackBar flutuante definido no tema).
void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
  );
}

String? requiredValidator(String? value) =>
    value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;

String? blankOrNull(String value) => value.trim().isEmpty ? null : value.trim();

String shortDate(dynamic value) =>
    value == null ? '—' : value.toString().split('T').first;

/// Situações válidas de um bem (mesma lista usada pela API e pelo web).
const assetStatuses = ['Disponível', 'Em Uso', 'Manutenção', 'Baixado'];

/// Cor semântica para o status de um bem.
Color assetStatusColor(String status) => switch (status) {
  'Em Uso' => AppColors.success,
  'Disponível' => AppColors.primary,
  'Em Manutenção' || 'Manutenção' => AppColors.warning,
  'Baixado' => AppColors.error,
  _ => AppColors.textSecondary,
};

/// Campo de texto padrão dos formulários de cadastro.
Widget formTextField(
  TextEditingController controller,
  String label, {
  bool required = false,
  bool number = false,
}) => Padding(
  padding: const EdgeInsets.only(bottom: AppSpacing.md),
  child: TextFormField(
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      if (required && (value == null || value.trim().isEmpty)) {
        return 'Campo obrigatório';
      }
      if (number &&
          value != null &&
          value.trim().isNotEmpty &&
          double.tryParse(value.replaceAll(',', '.')) == null) {
        return 'Informe um valor numérico';
      }
      return null;
    },
  ),
);

/// Perfis cadastráveis, na ordem de exibição.
const perfisDisponiveis = [
  'setor_patrimonio',
  'agente_campo',
  'responsavel_setor',
  'auditor',
];

String perfilLabel(String? perfil) => switch (perfil) {
  'setor_patrimonio' => 'Setor de Patrimônio',
  'agente_campo' => 'Agente de Campo',
  'responsavel_setor' => 'Responsável de Setor',
  'auditor' => 'Auditor',
  _ => 'Perfil não reconhecido',
};
