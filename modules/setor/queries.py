QUERY_SETORES = """SELECT s.id, s.nome, s.responsavel_id,
                        r.nome AS responsavel_nome, r.cargo AS cargo_responsavel,
                        s.flag_almoxarifado, s.ativo, s.sala_id, sa.identificacao,
                        a.identificacao, p.nome
                    FROM setores s
                    LEFT JOIN responsaveis r ON s.responsavel_id = r.id
                    JOIN salas sa ON sa.id = s.sala_id
                    JOIN andares a ON a.id = sa.andar_id
                    JOIN predios p ON p.id = a.predio_id
                    WHERE s.ativo = TRUE"""

QUERY_SETOR_BY_ID = """SELECT s.id, s.nome, s.responsavel_id,
                        r.nome AS responsavel_nome, r.cargo AS cargo_responsavel,
                        s.flag_almoxarifado, s.ativo, s.sala_id, sa.identificacao,
                        a.identificacao, p.nome
                       FROM setores s
                       LEFT JOIN responsaveis r ON s.responsavel_id = r.id
                       JOIN salas sa ON sa.id = s.sala_id
                       JOIN andares a ON a.id = sa.andar_id
                       JOIN predios p ON p.id = a.predio_id
                       WHERE s.id = %s AND s.ativo = TRUE"""

QUERY_CREATE_SETOR = """INSERT INTO setores (nome, responsavel_id, flag_almoxarifado, sala_id)
                         VALUES (%s, %s, %s, %s) RETURNING id"""

QUERY_PUT_SETOR = """UPDATE setores SET nome = %s, responsavel_id = %s, flag_almoxarifado = %s,
                    sala_id = COALESCE(%s, sala_id) WHERE id = %s RETURNING id"""

QUERY_DELETE_SETOR = "UPDATE setores SET ativo = FALSE WHERE id = %s RETURNING id"
