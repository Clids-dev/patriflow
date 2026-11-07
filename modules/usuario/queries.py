QUERY_BUSCAR_POR_USERNAME = "SELECT id, username, senha, tipo, ativo, nome, setor_id FROM usuarios WHERE username = %s"
QUERY_BUSCAR_POR_ID = "SELECT id, username, senha, tipo, ativo, nome, setor_id FROM usuarios WHERE id = %s"
QUERY_CRIAR_USUARIO = """INSERT INTO usuarios (username, senha, tipo, ativo, nome, setor_id)
VALUES (%s, %s, 'agente_campo', FALSE, %s, %s)
RETURNING id, username, senha, tipo, ativo, nome, setor_id"""

# Aguardando aprovação primeiro (é o que pede ação), depois ativos, desativados e recusados.
QUERY_LISTAR_USUARIOS = """SELECT u.id, u.username, u.nome, u.tipo, u.ativo, u.setor_id, s.nome, u.situacao,
       ud.nome, u.decidido_em
FROM usuarios u
LEFT JOIN setores s ON s.id = u.setor_id
LEFT JOIN usuarios ud ON ud.id = u.decidido_por
WHERE (%(situacao)s::text IS NULL OR u.situacao = %(situacao)s)
ORDER BY array_position(ARRAY['aguardando', 'ativo', 'desativado', 'recusado'], u.situacao::text),
         u.nome NULLS LAST, u.username"""

QUERY_SITUACAO = "SELECT situacao FROM usuarios WHERE id = %s"

# Quem decidiu e quando só muda quando a situação muda.
QUERY_ATUALIZAR_USUARIO = """UPDATE usuarios SET tipo = %(tipo)s, setor_id = %(setor)s, situacao = %(situacao)s,
    decidido_por = CASE WHEN situacao IS DISTINCT FROM %(situacao)s THEN %(admin)s ELSE decidido_por END,
    decidido_em = CASE WHEN situacao IS DISTINCT FROM %(situacao)s THEN NOW() ELSE decidido_em END
WHERE id = %(id)s
RETURNING id, username, nome, tipo, ativo, setor_id, situacao"""

