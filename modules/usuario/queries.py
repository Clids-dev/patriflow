QUERY_BUSCAR_POR_USERNAME = "SELECT id, username, senha, tipo, ativo, nome, setor_id FROM usuarios WHERE username = %s"
QUERY_BUSCAR_POR_ID = "SELECT id, username, senha, tipo, ativo, nome, setor_id FROM usuarios WHERE id = %s"
QUERY_CRIAR_USUARIO = """INSERT INTO usuarios (username, senha, tipo, ativo, nome, setor_id)
VALUES (%s, %s, 'agente_campo', FALSE, %s, %s)
RETURNING id, username, senha, tipo, ativo, nome, setor_id"""

QUERY_LISTAR_USUARIOS = """SELECT u.id, u.username, u.nome, u.tipo, u.ativo, u.setor_id, s.nome
FROM usuarios u
LEFT JOIN setores s ON s.id = u.setor_id
ORDER BY u.ativo ASC, u.nome NULLS LAST, u.username"""

QUERY_ATUALIZAR_USUARIO = """UPDATE usuarios SET tipo = %s, setor_id = %s, ativo = %s
WHERE id = %s
RETURNING id, username, nome, tipo, ativo, setor_id"""

