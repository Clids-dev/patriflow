"""Acervo do setor para uso sem rede no aplicativo (A03).

Uma única chamada entrega tudo o que o aparelho precisa para consultar o setor offline: a ficha
completa de cada bem (com a foto de referência mais recente e os empréstimos e manutenções abertos,
cujos ids permitem registrar devolução e retorno sem rede),
as categorias, os setores e a hierarquia de localização. Cada parte é uma consulta só, sem uma
consulta por bem.
"""
from datetime import datetime

from fastapi import HTTPException

from core.database import DataBase
from modules.bem import guarda

ADMIN = "setor_patrimonio"

_BENS = """
    WITH local AS (
        SELECT DISTINCT ON (bem_id) bem_id, setor_destino_id
        FROM movimentacoes
        WHERE ativo = TRUE AND status = 'aprovada'
        ORDER BY bem_id, COALESCE(data_decisao, data_movimentacao) DESC, id DESC
    )
    SELECT b.id, b.codigo_tombamento, b.nome, b.status, b.id_categoria, c.nome, b.marca, b.modelo, b.numero_serie,
           b.estado_conservacao, b.valor_aquisicao, b.nota_fiscal, b.data_entrada, b.garantia_fim,
           b.vida_util_meses, b.valor_residual, s.id, s.nome, r.nome, p.nome, a.identificacao, sa.identificacao,
           fr.id AS foto_referencia_id,
           (SELECT e.id FROM emprestimos e WHERE e.bem_id = b.id AND e.devolvido_em IS NULL) AS emprestimo_aberto_id,
           (SELECT e.tomador FROM emprestimos e WHERE e.bem_id = b.id AND e.devolvido_em IS NULL) AS emprestado_para,
           (SELECT e.devolucao_prevista FROM emprestimos e WHERE e.bem_id = b.id AND e.devolvido_em IS NULL)
               AS devolucao_prevista,
           (SELECT mt.id FROM manutencoes mt WHERE mt.bem_id = b.id AND mt.retorno_em IS NULL) AS manutencao_aberta_id
    FROM local l
    JOIN bens b ON b.id = l.bem_id AND b.ativo = TRUE
    JOIN setores s ON s.id = l.setor_destino_id
    LEFT JOIN categorias c ON c.id = b.id_categoria
    LEFT JOIN responsaveis r ON r.id = s.responsavel_id
    LEFT JOIN salas sa ON sa.id = s.sala_id
    LEFT JOIN andares a ON a.id = sa.andar_id
    LEFT JOIN predios p ON p.id = a.predio_id
    -- Foto de referência: a mais recente das conferências ou dos recebimentos do bem.
    LEFT JOIN LATERAL (
        SELECT f.id FROM fotos f
        WHERE (f.registro_tipo = 'conferencia'
               AND f.registro_id IN (SELECT it.id FROM inventario_itens it WHERE it.bem_id = b.id))
           OR (f.registro_tipo = 'aceite_transferencia'
               AND f.registro_id IN (SELECT mv.id FROM movimentacoes mv WHERE mv.bem_id = b.id))
        ORDER BY f.enviado_em DESC, f.id DESC
        LIMIT 1
    ) fr ON TRUE
    WHERE l.setor_destino_id = %s
    ORDER BY b.nome, b.id
"""

_CAMPOS_BEM = ("id", "codigo_tombamento", "nome", "status", "categoria_id", "categoria_nome", "marca", "modelo",
               "numero_serie", "estado_conservacao", "valor_aquisicao", "nota_fiscal", "data_entrada", "garantia_fim",
               "vida_util_meses", "valor_residual", "setor_id", "setor_nome", "responsavel_nome", "predio_nome",
               "andar_identificacao", "sala_identificacao", "foto_referencia_id", "emprestimo_aberto_id", "emprestado_para",
               "devolucao_prevista", "manutencao_aberta_id")


def _exigir_acesso(usuario: dict, setor_id: int) -> None:
    """Patrimônio e auditor baixam qualquer setor; colaboradores, o próprio e os designados (D1)."""
    if usuario["perfil"] in (ADMIN, "auditor"):
        return
    with DataBase().transacao() as cur:
        permitidos = guarda.setores_do_colaborador(cur, usuario)
    if setor_id not in permitidos:
        raise HTTPException(status_code=403, detail="Você só baixa o acervo do seu setor e dos setores designados a você.")


def acervo_do_setor(setor_id: int, usuario: dict) -> dict:
    _exigir_acesso(usuario, setor_id)
    db = DataBase()
    setor = db.execute("SELECT id, nome FROM setores WHERE id = %s AND ativo = TRUE", (setor_id,), many=False)
    if setor is None:
        raise HTTPException(status_code=404, detail=f"Setor {setor_id} não encontrado ou inativo.")
    # Uma transação de leitura: todas as partes refletem o mesmo instante do banco.
    with db.transacao() as cur:
        cur.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY")
        cur.execute(_BENS, (setor_id,))
        bens = [dict(zip(_CAMPOS_BEM, r)) for r in cur.fetchall()]
        cur.execute("SELECT id, nome, sigla FROM categorias WHERE ativo = TRUE ORDER BY nome")
        categorias = [{"id": r[0], "nome": r[1], "sigla": r[2]} for r in cur.fetchall()]
        cur.execute("SELECT id, nome, sala_id, flag_almoxarifado FROM setores WHERE ativo = TRUE ORDER BY nome")
        setores = [{"id": r[0], "nome": r[1], "sala_id": r[2], "almoxarifado": bool(r[3])} for r in cur.fetchall()]
        cur.execute("SELECT id, nome FROM predios ORDER BY nome")
        predios = [{"id": r[0], "nome": r[1]} for r in cur.fetchall()]
        cur.execute("SELECT id, predio_id, identificacao FROM andares ORDER BY predio_id, identificacao")
        andares = [{"id": r[0], "predio_id": r[1], "identificacao": r[2]} for r in cur.fetchall()]
        cur.execute("SELECT id, andar_id, identificacao FROM salas ORDER BY andar_id, identificacao")
        salas = [{"id": r[0], "andar_id": r[1], "identificacao": r[2]} for r in cur.fetchall()]
    return {
        "setor": {"id": setor[0], "nome": setor[1]},
        "gerado_em": datetime.now(),
        "bens": bens,
        "categorias": categorias,
        "setores": setores,
        "localizacoes": {"predios": predios, "andares": andares, "salas": salas},
    }


def setores_permitidos(usuario: dict) -> list[dict]:
    """Setores cujo acervo o usuário pode baixar: todos (patrimônio e auditor) ou o próprio e os designados."""
    with DataBase().transacao() as cur:
        cur.execute("SELECT id, nome FROM setores WHERE ativo = TRUE ORDER BY nome")
        todos = [{"id": r[0], "nome": r[1]} for r in cur.fetchall()]
        if usuario["perfil"] in (ADMIN, "auditor"):
            return todos
        permitidos = guarda.setores_do_colaborador(cur, usuario)
    return [s for s in todos if s["id"] in permitidos]
