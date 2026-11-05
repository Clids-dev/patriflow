QUERY_REPORT_BENS = """
    SELECT 
        b.id,
        b.nome,
        b.codigo_tombamento,
        c.nome as categoria,
        s.nome as setor_atual,
        b.valor,
        b.status,
        CASE WHEN b.ativo THEN 'Ativo' ELSE 'Inativo' END as situacao
    FROM bens b
    LEFT JOIN categorias c ON b.id_categoria = c.id
    LEFT JOIN movimentacoes m ON m.id = (
        SELECT id FROM movimentacoes 
        WHERE bem_id = b.id AND ativo = TRUE AND status = 'aprovada'
        ORDER BY COALESCE(data_decisao, data_movimentacao) DESC, id DESC LIMIT 1
    )
    LEFT JOIN setores s ON m.setor_destino_id = s.id
    WHERE 1=1
"""
