"""Agentes de campo designados a cada setor (decisão D1). Só o setor de patrimônio designa."""
from fastapi import HTTPException
from pydantic import BaseModel, Field

from core.database import DataBase

ADMIN = "setor_patrimonio"


class Designacao(BaseModel):
    usuario_ids: list[int] = Field(default_factory=list, max_length=500)


def agentes_do_setor(setor_id: int) -> list[dict]:
    """Todos os agentes ativos, marcando os designados a este setor (o próprio setor do agente também conta)."""
    rows = DataBase().execute(
        """SELECT u.id, u.nome, u.username, s.nome, (d.usuario_id IS NOT NULL) AS designado
           FROM usuarios u
           LEFT JOIN setores s ON s.id = u.setor_id
           LEFT JOIN agente_setores d ON d.usuario_id = u.id AND d.setor_id = %s
           WHERE u.tipo = 'agente_campo' AND u.ativo = TRUE
           ORDER BY u.nome NULLS LAST, u.username""", (setor_id,)) or []
    return [{"id": r[0], "nome": r[1] or r[2], "setor_proprio": r[3], "designado": r[4]} for r in rows]


def designar(setor_id: int, usuario_ids: list[int], usuario: dict) -> list[dict]:
    if usuario["perfil"] != ADMIN:
        raise HTTPException(status_code=403, detail="Somente o setor de patrimônio designa agentes.")
    ids = sorted(set(usuario_ids))
    with DataBase().transacao() as cur:
        cur.execute("SELECT 1 FROM setores WHERE id = %s AND ativo = TRUE", (setor_id,))
        if cur.fetchone() is None:
            raise HTTPException(status_code=404, detail=f"Setor {setor_id} não encontrado ou inativo.")
        if ids:
            cur.execute("SELECT id FROM usuarios WHERE id = ANY(%s) AND tipo = 'agente_campo' AND ativo = TRUE", (ids,))
            validos = {r[0] for r in cur.fetchall()}
            invalidos = [i for i in ids if i not in validos]
            if invalidos:
                raise HTTPException(status_code=400, detail=f"Não são agentes de campo ativos: {invalidos}")
        cur.execute("DELETE FROM agente_setores WHERE setor_id = %s AND NOT (usuario_id = ANY(%s))", (setor_id, ids))
        cur.execute(
            """INSERT INTO agente_setores (usuario_id, setor_id, designado_por)
               SELECT unnest(%s::int[]), %s, %s
               ON CONFLICT (usuario_id, setor_id) DO NOTHING""", (ids, setor_id, usuario["id"]))
    return agentes_do_setor(setor_id)
