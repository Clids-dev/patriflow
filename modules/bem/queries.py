_BEM_FIELDS = "id, nome, tipo, codigo_tombamento, valor, status, ativo, id_categoria, marca, modelo, numero_serie, valor_aquisicao, nota_fiscal, data_entrada, estado_conservacao"
QUERY_BENS = f"SELECT {_BEM_FIELDS} FROM bens"

QUERY_BEM_ID = f"SELECT {_BEM_FIELDS} FROM bens WHERE id = %s"

QUERY_BEM_DETALHES = """
    SELECT 
        b.id, b.nome, b.tipo, b.codigo_tombamento, b.valor, b.status, b.ativo,
        s.nome as setor_atual,
        m.data_movimentacao as data_ultima_movimentacao,
        m.justificativa,
        s.id as id_setor_atual,
        b.id_categoria,
        c.nome as categoria_nome,
        b.marca, b.modelo, b.numero_serie, b.valor_aquisicao, b.nota_fiscal, b.data_entrada, b.estado_conservacao,
        p.nome AS predio_nome, a.identificacao AS andar_identificacao, sa.identificacao AS sala_nome
    FROM bens b
    LEFT JOIN (
        SELECT DISTINCT ON (bem_id) bem_id, setor_destino_id, data_movimentacao, justificativa
        FROM movimentacoes 
        WHERE ativo = TRUE 
        ORDER BY bem_id, data_movimentacao DESC
    ) m ON m.bem_id = b.id
    LEFT JOIN setores s ON s.id = m.setor_destino_id
    LEFT JOIN salas sa ON sa.id = s.sala_id
    LEFT JOIN andares a ON a.id = sa.andar_id
    LEFT JOIN predios p ON p.id = a.predio_id
    LEFT JOIN categorias c ON c.id = b.id_categoria
    WHERE b.id = %s
"""

QUERY_CREATE_BEM = """INSERT INTO bens
    (nome, tipo, codigo_tombamento, valor, status, ativo, id_categoria, marca, modelo,
     numero_serie, valor_aquisicao, nota_fiscal, data_entrada, estado_conservacao)
    VALUES (%s, %s, %s, %s, %s, TRUE, %s, %s, %s, %s, %s, %s, %s, %s)
    RETURNING id"""

QUERY_PUT_BEM = ("UPDATE bens SET nome = COALESCE(%s, nome), valor = COALESCE(%s, %s, valor), status = COALESCE(%s, status), "
                 "marca = COALESCE(%s, marca), modelo = COALESCE(%s, modelo), numero_serie = COALESCE(%s, numero_serie), "
                 "valor_aquisicao = COALESCE(%s, %s, valor_aquisicao), nota_fiscal = COALESCE(%s, nota_fiscal), "
                 "data_entrada = COALESCE(%s, data_entrada), estado_conservacao = COALESCE(%s, estado_conservacao) "
                 "WHERE bens.id = %s AND ativo = TRUE "
                 f"RETURNING {_BEM_FIELDS}")

QUERY_DELETE_BEM = """UPDATE bens SET ativo = FALSE 
                      WHERE bens.id = (%s) 
                      RETURNING id, nome, tipo, codigo_tombamento, valor, status, ativo, id_categoria, marca, modelo, numero_serie, valor_aquisicao, nota_fiscal, data_entrada, estado_conservacao"""

QUERY_BEM_CODTOMB = (f"SELECT {_BEM_FIELDS} "
                     "FROM bens "
                     "WHERE codigo_tombamento = %s")

QUERY_HISTORICO = """SELECT id, bem_id, setor_origem_id, setor_destino_id, data_movimentacao, ativo 
                     FROM movimentacoes WHERE bem_id = %s 
                     ORDER BY data_movimentacao DESC"""

QUERY_BENS_POR_SETOR = """
                       SELECT b.id, b.nome, b.tipo, b.codigo_tombamento, b.valor, b.status, b.ativo, b.id_categoria,
                              b.marca, b.modelo, b.numero_serie, b.valor_aquisicao, b.nota_fiscal, b.data_entrada, b.estado_conservacao
                       FROM bens b
                       JOIN (SELECT DISTINCT ON (bem_id) bem_id, setor_destino_id 
                             FROM movimentacoes WHERE ativo = TRUE 
                             ORDER BY bem_id, data_movimentacao DESC) m ON m.bem_id = b.id
                       WHERE m.setor_destino_id = %s
                         AND b.ativo = TRUE"""

QUERY_DESATIVAR = "UPDATE bens SET ativo = false WHERE id = %s RETURNING id"

QUERY_REATIVAR = "UPDATE bens SET ativo = true  WHERE id = %s RETURNING id"

QUERY_COUNT_BY_CATEGORIA = "SELECT COUNT(*) FROM bens WHERE id_categoria = %s"

QUERY_RELATORIO_ATIVOS = """
        SELECT status, COUNT(*) AS quantidade
        FROM bens
        WHERE ativo = TRUE
        GROUP BY status;
    """

QUERY_QUANTIDADE_BENS = """SELECT COUNT (*) FROM bens;"""

QUERY_QUANTIDADE_BENS_ATIVOS = """SELECT COUNT (*) FROM bens 
                                  WHERE ativo = TRUE;"""

QUERY_QUANTIDADE_BENS_INATIVOS = """SELECT COUNT (*) FROM bens 
                                    WHERE ativo = FALSE;"""

QUERY_RECENTES = """SELECT id, nome, tipo, codigo_tombamento, valor, status, ativo, data_cadastro, id_categoria
                    FROM bens 
                    ORDER BY data_cadastro 
                    DESC LIMIT 3;"""
