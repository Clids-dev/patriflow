import json

from core.database import DataBase


class AuditoriaRepository(DataBase):
    def registrar(self, entidade: str, registro_id: int, acao: str, usuario_id: int | None,
                  antes: dict | None, depois: dict | None) -> None:
        self.commit(
            """INSERT INTO auditoria (entidade, registro_id, acao, usuario_id, antes, depois)
               VALUES (%s, %s, %s, %s, %s::jsonb, %s::jsonb)""",
            (entidade, registro_id, acao, usuario_id,
             json.dumps(antes, default=str) if antes is not None else None,
             json.dumps(depois, default=str) if depois is not None else None),
        )

    def listar(self, entidade: str, registro_id: int) -> list[dict]:
        rows = self.execute(
            """SELECT a.id, a.acao, a.em, u.nome, a.antes, a.depois
               FROM auditoria a LEFT JOIN usuarios u ON u.id = a.usuario_id
               WHERE a.entidade = %s AND a.registro_id = %s
               ORDER BY a.em DESC, a.id DESC""",
            (entidade, registro_id),
        ) or []
        return [
            {"id": r[0], "acao": r[1], "em": r[2], "usuario": r[3], "antes": r[4], "depois": r[5]}
            for r in rows
        ]
