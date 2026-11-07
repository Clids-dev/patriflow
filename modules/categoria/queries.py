_CAMPOS = "id, nome, sigla, ativo"

# Ativas: alimentam os formulários de bens e os relatórios.
QUERY_CATEGORIAS = f"SELECT {_CAMPOS} FROM categorias WHERE ativo = TRUE ORDER BY nome"
# Todas: tela de gestão de categorias (ativas primeiro).
QUERY_CATEGORIAS_TODAS = f"SELECT {_CAMPOS} FROM categorias ORDER BY ativo DESC, nome"

# Só ativa: usada ao gerar o próximo tombo, para não criar bem em categoria inativa.
QUERY_CATEGORIA_ID = f"SELECT {_CAMPOS} FROM categorias WHERE id = %s AND ativo = TRUE"
QUERY_CATEGORIA_ID_QUALQUER = f"SELECT {_CAMPOS} FROM categorias WHERE id = %s"

QUERY_CREATE_CATEGORIA = "INSERT INTO categorias (nome, sigla) VALUES (%s, %s) RETURNING id"

# A sigla não muda depois de criada: ela é o prefixo dos tombos já emitidos.
QUERY_RENOMEAR_CATEGORIA = f"UPDATE categorias SET nome = %s WHERE id = %s RETURNING {_CAMPOS}"
QUERY_DELETE_CATEGORIA = f"UPDATE categorias SET ativo = FALSE WHERE id = %s RETURNING {_CAMPOS}"
QUERY_REATIVAR_CATEGORIA = f"UPDATE categorias SET ativo = TRUE WHERE id = %s RETURNING {_CAMPOS}"
