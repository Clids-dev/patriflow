"""SQL do inventário. Todas as consultas filtram por inventário e usam os índices da migration 20261112."""

# Local atual de cada bem = destino da última transferência aprovada (mesma regra do restante do sistema).
_LOCAL_ATUAL = """
    SELECT DISTINCT ON (bem_id) bem_id, setor_destino_id AS setor_id
    FROM movimentacoes
    WHERE ativo = TRUE AND status = 'aprovada'
    ORDER BY bem_id, COALESCE(data_decisao, data_movimentacao) DESC, id DESC
"""

SETORES_INVALIDOS = """
    SELECT s.id FROM unnest(%(setores)s::int[]) AS s(id)
    LEFT JOIN setores st ON st.id = s.id AND st.ativo = TRUE
    WHERE st.id IS NULL
"""

SETORES_EM_INVENTARIO_ABERTO = """
    SELECT st.nome FROM inventario_setores i JOIN setores st ON st.id = i.setor_id
    WHERE i.aberto AND i.setor_id = ANY(%(setores)s)
    ORDER BY st.nome
"""

INSERIR_INVENTARIO = """
    INSERT INTO inventarios (descricao, inicio, fim, aberto_por) VALUES (%s, %s, %s, %s) RETURNING id
"""

INSERIR_SETORES = """
    INSERT INTO inventario_setores (inventario_id, setor_id)
    SELECT %(inv)s, unnest(%(setores)s::int[])
"""

# Congela a lista esperada: cópia dos bens ativos que estão em cada setor no momento da abertura.
CONGELAR_LISTA = f"""
    WITH local AS ({_LOCAL_ATUAL})
    INSERT INTO inventario_itens
        (inventario_id, setor_esperado_id, bem_id, codigo_tombamento, nome, estado_esperado, ausencia_justificada)
    SELECT %(inv)s, l.setor_id, b.id, b.codigo_tombamento, b.nome, b.estado_conservacao,
           CASE WHEN EXISTS (SELECT 1 FROM emprestimos e WHERE e.bem_id = b.id AND e.devolvido_em IS NULL)
                     THEN 'emprestado'
                WHEN EXISTS (SELECT 1 FROM manutencoes m WHERE m.bem_id = b.id AND m.retorno_em IS NULL)
                     THEN 'manutencao' END
    FROM local l JOIN bens b ON b.id = l.bem_id
    WHERE b.ativo = TRUE AND l.setor_id = ANY(%(setores)s)
"""

TRAVAR_INVENTARIO = "SELECT id, status, inicio FROM inventarios WHERE id = %s FOR {modo}"

SETOR_NO_INVENTARIO = "SELECT 1 FROM inventario_setores WHERE inventario_id = %s AND setor_id = %s"

BEM_PELO_TOMBO = "SELECT id, ativo FROM bens WHERE upper(codigo_tombamento) = %s"

ITEM_DO_BEM = """
    SELECT id, setor_esperado_id, situacao FROM inventario_itens
    WHERE inventario_id = %s AND bem_id = %s FOR UPDATE
"""

LOCAL_DO_BEM = """
    SELECT setor_destino_id FROM movimentacoes
    WHERE bem_id = %s AND ativo = TRUE AND status = 'aprovada'
    ORDER BY COALESCE(data_decisao, data_movimentacao) DESC, id DESC LIMIT 1
"""

REGISTRAR_CONFERENCIA = """
    UPDATE inventario_itens
    SET situacao = %(situacao)s, setor_encontrado_id = %(setor)s, estado_encontrado = %(estado)s,
        observacao = %(obs)s, conferido_por = %(usuario)s, conferido_em = NOW()
    WHERE id = %(item)s
"""

# Bem encontrado que não estava na lista congelada (veio de setor fora do inventário).
INSERIR_EXCEDENTE = """
    INSERT INTO inventario_itens
        (inventario_id, setor_esperado_id, bem_id, codigo_tombamento, nome, estado_esperado,
         situacao, setor_encontrado_id, estado_encontrado, observacao, conferido_por, conferido_em)
    SELECT %(inv)s, %(setor_atual)s, b.id, b.codigo_tombamento, b.nome, b.estado_conservacao,
           'outro_setor', %(setor)s, %(estado)s, %(obs)s, %(usuario)s, NOW()
    FROM bens b WHERE b.id = %(bem)s
    RETURNING id
"""

INSERIR_NAO_CADASTRADO = """
    INSERT INTO inventario_itens
        (inventario_id, codigo_tombamento, nome, situacao, setor_encontrado_id, observacao, conferido_por, conferido_em)
    VALUES (%(inv)s, %(codigo)s, %(descricao)s, 'nao_cadastrado', %(setor)s, %(obs)s, %(usuario)s, NOW())
    RETURNING id
"""

MARCAR_ITEM_NAO_LOCALIZADO = """
    UPDATE inventario_itens SET situacao = 'nao_localizado', conferido_por = %s, conferido_em = NOW()
    WHERE id = %s AND inventario_id = %s AND situacao IS NULL AND bem_id IS NOT NULL
    RETURNING id
"""

MARCAR_FALTANTES_DO_SETOR = """
    UPDATE inventario_itens SET situacao = 'nao_localizado', conferido_por = %s, conferido_em = NOW()
    WHERE inventario_id = %s AND setor_esperado_id = %s AND situacao IS NULL
"""

CONTAR_SEM_SITUACAO = "SELECT count(*) FROM inventario_itens WHERE inventario_id = %s AND situacao IS NULL"

ITENS_PARA_FECHAMENTO = """
    SELECT id, bem_id, codigo_tombamento, nome, situacao, setor_esperado_id, setor_encontrado_id, ausencia_justificada
    FROM inventario_itens WHERE inventario_id = %s ORDER BY id
"""

EXISTE_TRANSFERENCIA_ABERTA = """
    SELECT 1 FROM movimentacoes WHERE bem_id = %s AND ativo = TRUE AND status IN ('pendente', 'liberada') LIMIT 1
"""

ABRIR_TRANSFERENCIA = """
    INSERT INTO movimentacoes
        (bem_id, setor_origem_id, setor_destino_id, data_movimentacao, justificativa, ativo, status, solicitante_id, fluxo)
    VALUES (%s, %s, %s, NOW(), %s, TRUE, 'pendente', %s, 'duplo')
"""

INSERIR_PENDENCIA = """
    INSERT INTO pendencias (tipo, inventario_item_id, bem_id, setor_id, descricao, criada_por)
    VALUES (%s, %s, %s, %s, %s, %s)
"""

FECHAR = "UPDATE inventarios SET status = 'fechado', fechado_por = %s, fechado_em = NOW() WHERE id = %s"
LIBERAR_SETORES = "UPDATE inventario_setores SET aberto = FALSE WHERE inventario_id = %s"

# --- Leitura -----------------------------------------------------------------------------------

_CABECALHO = """
    SELECT i.id, i.descricao, i.inicio, i.fim, i.status, ua.nome, i.aberto_em, uf.nome, i.fechado_em,
           COALESCE(c.total, 0), COALESCE(c.pendentes, 0)
    FROM inventarios i
    LEFT JOIN usuarios ua ON ua.id = i.aberto_por
    LEFT JOIN usuarios uf ON uf.id = i.fechado_por
    LEFT JOIN (SELECT inventario_id, count(*) AS total, count(*) FILTER (WHERE situacao IS NULL) AS pendentes
               FROM inventario_itens GROUP BY inventario_id) c ON c.inventario_id = i.id
"""

LISTAR = _CABECALHO + " WHERE {condicao} ORDER BY i.aberto_em DESC, i.id DESC"
BUSCAR = _CABECALHO + " WHERE i.id = %s"

# Por setor do inventário: o que era esperado ali e o que foi encontrado ali.
RESUMO_SETORES = """
    SELECT s.id, s.nome,
           count(it.id) FILTER (WHERE it.setor_esperado_id = s.id),
           count(it.id) FILTER (WHERE it.setor_esperado_id = s.id AND it.situacao IS NOT NULL),
           count(it.id) FILTER (WHERE it.setor_esperado_id = s.id AND it.situacao = 'localizado'),
           count(it.id) FILTER (WHERE it.setor_esperado_id = s.id AND it.situacao = 'outro_setor'),
           count(it.id) FILTER (WHERE it.setor_esperado_id = s.id AND it.situacao = 'nao_localizado'),
           count(it.id) FILTER (WHERE it.setor_encontrado_id = s.id AND it.situacao = 'nao_cadastrado'),
           count(it.id) FILTER (WHERE it.setor_esperado_id = s.id AND it.situacao IS NULL)
    FROM inventario_setores isr
    JOIN setores s ON s.id = isr.setor_id
    LEFT JOIN inventario_itens it ON it.inventario_id = isr.inventario_id
         AND (it.setor_esperado_id = s.id OR it.setor_encontrado_id = s.id)
    WHERE isr.inventario_id = %s
    GROUP BY s.id, s.nome
    ORDER BY s.nome
"""

ITENS = """
    SELECT it.id, it.bem_id, it.codigo_tombamento, it.nome, it.setor_esperado_id, se.nome, it.estado_esperado,
           it.ausencia_justificada, it.situacao, it.setor_encontrado_id, sf.nome, it.estado_encontrado,
           it.observacao, u.nome, it.conferido_em
    FROM inventario_itens it
    LEFT JOIN setores se ON se.id = it.setor_esperado_id
    LEFT JOIN setores sf ON sf.id = it.setor_encontrado_id
    LEFT JOIN usuarios u ON u.id = it.conferido_por
    WHERE it.inventario_id = %(inv)s {filtros}
    ORDER BY it.situacao NULLS FIRST, it.nome, it.id
"""

ITEM = ITENS.replace("WHERE it.inventario_id = %(inv)s {filtros}", "WHERE it.id = %(item)s")
