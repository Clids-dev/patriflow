from core.database import DataBase
from modules.manutencao.schemas import Manutencao

_SELECT = """
    SELECT m.id, m.bem_id, b.nome, b.codigo_tombamento, m.descricao, m.destino, m.enviado_em, ue.nome,
           m.status_anterior, m.retorno_em, ur.nome, m.servico_realizado, m.estado_retorno,
           (COALESCE(m.retorno_em, NOW())::date - m.enviado_em::date) AS dias_fora
    FROM manutencoes m
    JOIN bens b ON b.id = m.bem_id
    LEFT JOIN usuarios ue ON ue.id = m.enviado_por
    LEFT JOIN usuarios ur ON ur.id = m.recebido_por
"""

_FILTROS = {
    "abertas": "m.retorno_em IS NULL",
    "encerradas": "m.retorno_em IS NOT NULL",
    "todas": "TRUE",
}


def _modelo(r) -> Manutencao:
    return Manutencao(id=r[0], bem_id=r[1], bem_nome=r[2], codigo_tombamento=r[3], descricao=r[4], destino=r[5],
                      enviado_em=r[6], enviado_por=r[7], status_anterior=r[8], retorno_em=r[9], recebido_por=r[10],
                      servico_realizado=r[11], estado_retorno=r[12], dias_fora=r[13])


class ManutencaoRepository:
    def buscar(self, manutencao_id: int) -> Manutencao | None:
        row = DataBase().execute(_SELECT + " WHERE m.id = %s", (manutencao_id,), many=False)
        return _modelo(row) if row else None

    def listar(self, situacao: str, bem_id: int | None = None) -> list[Manutencao]:
        condicao = _FILTROS[situacao]
        params: tuple = ()
        if bem_id is not None:
            condicao += " AND m.bem_id = %s"
            params = (bem_id,)
        # Abertas pela mais antiga (há mais tempo fora); encerradas pelo retorno mais recente.
        ordem = "m.enviado_em, m.id" if situacao == "abertas" else "m.enviado_em DESC, m.id DESC"
        rows = DataBase().execute(f"{_SELECT} WHERE {condicao} ORDER BY {ordem}", params) or []
        return [_modelo(r) for r in rows]

    @staticmethod
    def inserir(cur, dados, status_anterior: str, usuario_id: int) -> int:
        cur.execute(
            """INSERT INTO manutencoes (bem_id, descricao, destino, enviado_por, status_anterior)
               VALUES (%s, %s, %s, %s, %s) RETURNING id""",
            (dados.bem_id, dados.descricao, dados.destino, usuario_id, status_anterior),
        )
        return cur.fetchone()[0]

    @staticmethod
    def travar(cur, manutencao_id: int):
        """(bem_id, retorno_em, status_anterior) com a manutenção travada, ou None."""
        cur.execute("SELECT bem_id, retorno_em, status_anterior FROM manutencoes WHERE id = %s FOR UPDATE",
                    (manutencao_id,))
        return cur.fetchone()

    @staticmethod
    def encerrar(cur, manutencao_id: int, usuario_id: int, dados) -> None:
        cur.execute(
            """UPDATE manutencoes SET retorno_em = NOW(), recebido_por = %s, servico_realizado = %s,
                      estado_retorno = %s
               WHERE id = %s""",
            (usuario_id, dados.servico_realizado, dados.estado_retorno, manutencao_id),
        )

    @staticmethod
    def atualizar_bem(cur, bem_id: int, status: str, estado: str | None = None) -> None:
        if estado is None:
            cur.execute("UPDATE bens SET status = %s WHERE id = %s", (status, bem_id))
        else:
            cur.execute("UPDATE bens SET status = %s, estado_conservacao = %s WHERE id = %s", (status, estado, bem_id))
