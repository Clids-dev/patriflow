QUERY_BUSCAR_POR_USERNAME = "SELECT id, username, senha, tipo, ativo, nome, setor_id FROM usuarios WHERE username = %s"
QUERY_BUSCAR_POR_ID = "SELECT id, username, senha, tipo, ativo, nome, setor_id FROM usuarios WHERE id = %s"
QUERY_CRIAR_USUARIO = """INSERT INTO usuarios (username, senha, tipo, ativo, nome, setor_id)
VALUES (%s, %s, 'agente_campo', TRUE, %s, %s)
RETURNING id, username, senha, tipo, ativo, nome, setor_id"""
