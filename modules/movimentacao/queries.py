QUERY_MOVIMENTACOES = """SELECT id, bem_id, setor_origem_id, setor_destino_id, data_movimentacao, ativo, status
                      FROM movimentacoes WHERE ativo = TRUE"""

QUERY_MOVIMENTACOES_DETALHADAS = """
    SELECT
        m.id,
        b.nome as bem_nome,
        b.codigo_tombamento,
        s1.nome as setor_origem_nome,
        s2.nome as setor_destino_nome,
        m.data_movimentacao,
        m.justificativa,
        m.ativo,
        m.status
    FROM movimentacoes m
    JOIN bens b ON m.bem_id = b.id
    LEFT JOIN setores s1 ON m.setor_origem_id = s1.id
    JOIN setores s2 ON m.setor_destino_id = s2.id
    WHERE m.ativo = TRUE
    ORDER BY m.data_movimentacao DESC
"""

QUERY_MOVIMENTACOES_POR_BEM_CODIGO = """
    SELECT
        m.id,
        b.nome as bem_nome,
        b.codigo_tombamento,
        s1.nome as setor_origem_nome,
        s2.nome as setor_destino_nome,
        m.data_movimentacao,
        m.justificativa,
        m.ativo,
        m.status
    FROM movimentacoes m
    JOIN bens b ON m.bem_id = b.id
    LEFT JOIN setores s1 ON m.setor_origem_id = s1.id
    JOIN setores s2 ON m.setor_destino_id = s2.id
    WHERE b.codigo_tombamento = %s AND m.ativo = TRUE
    ORDER BY m.data_movimentacao DESC
"""

QUERY_MOVIMENTACOES_PENDENTES = """
    SELECT
        m.id,
        b.nome as bem_nome,
        b.codigo_tombamento,
        s1.nome as setor_origem_nome,
        s2.nome as setor_destino_nome,
        m.data_movimentacao,
        m.justificativa,
        m.ativo,
        m.status,
        u.nome AS solicitante_nome,
        (m.data_movimentacao < NOW() - make_interval(days => %s)) AS escalada
    FROM movimentacoes m
    JOIN bens b ON m.bem_id = b.id
    LEFT JOIN setores s1 ON m.setor_origem_id = s1.id
    JOIN setores s2 ON m.setor_destino_id = s2.id
    LEFT JOIN usuarios u ON u.id = m.solicitante_id
    WHERE m.ativo = TRUE AND m.status = 'pendente'
    ORDER BY m.data_movimentacao ASC
"""

QUERY_MOVIMENTACOES_ID = """SELECT id, bem_id, setor_origem_id, setor_destino_id, data_movimentacao, ativo, status, solicitante_id
                            FROM movimentacoes WHERE id = %s"""

# Localização atual de um bem: destino da última movimentação aprovada e ativa.
QUERY_LOCALIZACAO_ATUAL = """
    SELECT setor_destino_id FROM movimentacoes
    WHERE bem_id = %s AND ativo = TRUE AND status = 'aprovada'
    ORDER BY COALESCE(data_decisao, data_movimentacao) DESC, id DESC
    LIMIT 1
"""

QUERY_CREATE_MOVIMENTACOES = """INSERT INTO movimentacoes
    (bem_id, setor_origem_id, setor_destino_id, data_movimentacao, justificativa,
     ativo, status, solicitante_id, decisor_id, data_decisao)
    VALUES (%s, %s, %s, %s, %s, TRUE, %s, %s, %s, %s)
    RETURNING id, bem_id, setor_origem_id, setor_destino_id, data_movimentacao, ativo, status;"""

# Decisão só é aplicada se a movimentação ainda estiver pendente (evita dupla decisão).
QUERY_DECIDIR_MOVIMENTACAO = """
    UPDATE movimentacoes
    SET status = %s, decisor_id = %s, data_decisao = %s, motivo_decisao = %s
    WHERE id = %s AND ativo = TRUE AND status = 'pendente'
    RETURNING id, bem_id, setor_origem_id, setor_destino_id, data_movimentacao, ativo, status;
"""

# Solicitações feitas pelo usuário (inclui o resultado e o motivo da decisão).
# Movimentações diretas do setor de patrimônio ficam de fora (solicitante = decisor).
QUERY_MINHAS_SOLICITACOES = """
    SELECT m.id, b.nome, b.codigo_tombamento, s1.nome, s2.nome, m.data_movimentacao,
           m.justificativa, m.status, m.motivo_decisao, d.nome, m.data_decisao
    FROM movimentacoes m
    JOIN bens b ON b.id = m.bem_id
    LEFT JOIN setores s1 ON s1.id = m.setor_origem_id
    JOIN setores s2 ON s2.id = m.setor_destino_id
    LEFT JOIN usuarios d ON d.id = m.decisor_id
    WHERE m.solicitante_id = %s AND m.ativo = TRUE
      AND (m.status = 'pendente' OR m.decisor_id IS DISTINCT FROM m.solicitante_id)
    ORDER BY m.data_movimentacao DESC
"""
