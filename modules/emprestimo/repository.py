from core.database import DataBase
from modules.emprestimo.schemas import Emprestimo

# Atraso calculado no banco, com a data do servidor: aberto e prazo vencido.
_SELECT = """
    SELECT e.id, e.bem_id, b.nome, b.codigo_tombamento, e.tomador, e.motivo, e.saida_em,
           e.devolucao_prevista, ur.nome, e.devolvido_em, ud.nome, e.observacao_devolucao,
           (e.devolvido_em IS NULL AND e.devolucao_prevista < CURRENT_DATE) AS atrasado,
           CASE WHEN e.devolvido_em IS NULL AND e.devolucao_prevista < CURRENT_DATE
                THEN CURRENT_DATE - e.devolucao_prevista ELSE 0 END AS dias_atraso,
           e.matricula, e.setor_destino_id, sd.nome
    FROM emprestimos e
    JOIN bens b ON b.id = e.bem_id
    LEFT JOIN setores sd ON sd.id = e.setor_destino_id
    LEFT JOIN usuarios ur ON ur.id = e.registrado_por
    LEFT JOIN usuarios ud ON ud.id = e.recebido_por
"""

_FILTROS = {
    "abertos": "e.devolvido_em IS NULL",
    "atrasados": "e.devolvido_em IS NULL AND e.devolucao_prevista < CURRENT_DATE",
    "encerrados": "e.devolvido_em IS NOT NULL",
    "todos": "TRUE",
}


def _modelo(r) -> Emprestimo:
    return Emprestimo(id=r[0], bem_id=r[1], bem_nome=r[2], codigo_tombamento=r[3], tomador=r[4], motivo=r[5],
                      saida_em=r[6], devolucao_prevista=r[7], registrado_por=r[8], devolvido_em=r[9],
                      recebido_por=r[10], observacao_devolucao=r[11], atrasado=r[12], dias_atraso=r[13],
                      matricula=r[14], setor_destino_id=r[15], setor_destino=r[16])


class EmprestimoRepository:
    def buscar(self, emprestimo_id: int) -> Emprestimo | None:
        row = DataBase().execute(_SELECT + " WHERE e.id = %s", (emprestimo_id,), many=False)
        return _modelo(row) if row else None

    def listar(self, situacao: str, bem_id: int | None = None) -> list[Emprestimo]:
        condicao = _FILTROS[situacao]
        params: tuple = ()
        if bem_id is not None:
            condicao += " AND e.bem_id = %s"
            params = (bem_id,)
        # Abertos pelo prazo (o mais urgente primeiro); encerrados pela devolução mais recente.
        ordem = "e.devolucao_prevista, e.id" if situacao in ("abertos", "atrasados") else "e.saida_em DESC, e.id DESC"
        rows = DataBase().execute(f"{_SELECT} WHERE {condicao} ORDER BY {ordem}", params) or []
        return [_modelo(r) for r in rows]

    @staticmethod
    def inserir(cur, dados, usuario_id: int, quando=None) -> int:
        cur.execute(
            """INSERT INTO emprestimos (bem_id, tomador, matricula, setor_destino_id, motivo, devolucao_prevista,
                                        registrado_por, saida_em)
               VALUES (%s, %s, %s, %s, %s, %s, %s, COALESCE(%s, NOW())) RETURNING id""",
            (dados.bem_id, dados.tomador, dados.matricula, dados.setor_destino_id, dados.motivo,
             dados.devolucao_prevista, usuario_id, quando),
        )
        return cur.fetchone()[0]

    @staticmethod
    def travar_aberto(cur, emprestimo_id: int):
        """(bem_id, devolvido_em, saida_em) com o empréstimo travado, ou None."""
        cur.execute("SELECT bem_id, devolvido_em, saida_em FROM emprestimos WHERE id = %s FOR UPDATE", (emprestimo_id,))
        return cur.fetchone()

    @staticmethod
    def encerrar(cur, emprestimo_id: int, usuario_id: int, observacao: str | None, quando=None) -> None:
        cur.execute(
            """UPDATE emprestimos SET devolvido_em = COALESCE(%s, NOW()), recebido_por = %s, observacao_devolucao = %s
               WHERE id = %s""",
            (quando, usuario_id, observacao, emprestimo_id),
        )

    @staticmethod
    def existe_aberto(bem_id: int) -> bool:
        row = DataBase().execute(
            "SELECT 1 FROM emprestimos WHERE bem_id = %s AND devolvido_em IS NULL", (bem_id,), many=False)
        return row is not None
