/// Nome de cada tipo de operação da fila, como aparece nas telas.
const nomesOperacoes = {
  'conferencia': 'Conferência de inventário',
  'bem_nao_cadastrado': 'Bem sem cadastro',
  'transferencia_solicitar': 'Pedido de transferência',
  'transferencia_liberar': 'Liberação de transferência',
  'transferencia_receber': 'Recebimento de transferência',
  'transferencia_recusar': 'Recusa de transferência',
  'emprestimo_registrar': 'Empréstimo',
  'emprestimo_devolver': 'Devolução de empréstimo',
  'manutencao_enviar': 'Envio para manutenção',
  'manutencao_retorno': 'Retorno de manutenção',
};

String nomeDaOperacao(String tipo) => nomesOperacoes[tipo] ?? tipo;
