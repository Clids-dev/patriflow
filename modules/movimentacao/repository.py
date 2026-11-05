from datetime import datetime
from typing import Optional
from core.database import DataBase
from modules.movimentacao.schemas import MovimentacaoCreate, Movimentacao
from . import queries, schemas


def _detailed(row) -> schemas.MovimentacaoDetailed:
    return schemas.MovimentacaoDetailed(
        id=row[0],
        bem_nome=row[1],
        codigo_tombamento=row[2],
        setor_origem_nome=row[3],
        setor_destino_nome=row[4],
        data_movimentacao=row[5],
        justificativa=row[6],
        ativo=bool(row[7]),
        status=row[8],
        solicitante_nome=row[9] if len(row) > 9 else None,
        escalada=bool(row[10]) if len(row) > 10 else False,
    )


def _model(row) -> Movimentacao:
    return Movimentacao(
        id=row[0],
        bem_id=row[1],
        setor_origem_id=row[2],
        setor_destino_id=row[3],
        data=row[4],
        ativo=bool(row[5]),
        status=row[6],
    )


class MovimentacaoRepository:
    def get_all(self):
        rows = DataBase().execute(queries.QUERY_MOVIMENTACOES)
        return [_model(row) for row in rows or []]

    def get_detailed(self):
        rows = DataBase().execute(queries.QUERY_MOVIMENTACOES_DETALHADAS)
        return [_detailed(row) for row in rows or []]

    def get_pendentes(self, prazo_dias: int = 3):
        rows = DataBase().execute(queries.QUERY_MOVIMENTACOES_PENDENTES, (prazo_dias,))
        return [_detailed(row) for row in rows or []]

    def get_by_bem_codigo(self, codigo: str):
        rows = DataBase().execute(queries.QUERY_MOVIMENTACOES_POR_BEM_CODIGO, (codigo,))
        return [_detailed(row) for row in rows or []]

    def get_id(self, id: int):
        rows = DataBase().execute(queries.QUERY_MOVIMENTACOES_ID, (id,))
        if not rows:
            return None
        model = _model(rows[0])
        model.solicitante_id = rows[0][7]
        return model

    def get_localizacao_atual(self, bem_id: int) -> Optional[int]:
        rows = DataBase().execute(queries.QUERY_LOCALIZACAO_ATUAL, (bem_id,), many=False)
        return rows[0] if rows else None

    def save(
        self,
        movimentacao: MovimentacaoCreate,
        origem_id: Optional[int],
        status: str,
        solicitante_id: int,
        decisor_id: Optional[int] = None,
        data_decisao: Optional[datetime] = None,
    ) -> Movimentacao:
        result = DataBase().commit(queries.QUERY_CREATE_MOVIMENTACOES, (
            movimentacao.bem_id, origem_id, movimentacao.setor_destino_id,
            datetime.now(), movimentacao.justificativa, status,
            solicitante_id, decisor_id, data_decisao,
        ))
        return _model(result)

    def decidir(
        self,
        id: int,
        bem_id: int,
        origem_esperada: Optional[int],
        aprovar: bool,
        decisor_id: int,
        data_decisao: datetime,
        motivo: Optional[str] = None,
    ) -> tuple[str, Optional[Movimentacao]]:
        """Aplica a decisão numa única transação com o bem travado (FOR UPDATE).

        Retorna (resultado, movimentação). Resultados possíveis: 'ok',
        'bem_inativo', 'ja_decidida', 'local_mudou'.
        """
        status = "aprovada" if aprovar else "recusada"
        conn = DataBase().get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT ativo FROM bens WHERE id = %s FOR UPDATE", (bem_id,))
                bem = cur.fetchone()
                if aprovar and (bem is None or not bem[0]):
                    conn.rollback()
                    return "bem_inativo", None

                cur.execute("SELECT status FROM movimentacoes WHERE id = %s FOR UPDATE", (id,))
                mov = cur.fetchone()
                if mov is None or mov[0] != "pendente":
                    conn.rollback()
                    return "ja_decidida", None

                if aprovar:
                    cur.execute(queries.QUERY_LOCALIZACAO_ATUAL, (bem_id,))
                    row = cur.fetchone()
                    atual = row[0] if row else None
                    if atual != origem_esperada:
                        conn.rollback()
                        return "local_mudou", None

                cur.execute(queries.QUERY_DECIDIR_MOVIMENTACAO, (status, decisor_id, data_decisao, motivo, id))
                result = cur.fetchone()
            conn.commit()
            return "ok", _model(result)
        except Exception:
            conn.rollback()
            raise
        finally:
            DataBase().put_conn(conn)

    def listar_minhas_solicitacoes(self, usuario_id: int) -> list[dict]:
        rows = DataBase().execute(queries.QUERY_MINHAS_SOLICITACOES, (usuario_id,)) or []
        return [
            {"id": r[0], "bem_nome": r[1], "codigo_tombamento": r[2], "setor_origem_nome": r[3],
             "setor_destino_nome": r[4], "data_movimentacao": r[5], "justificativa": r[6],
             "status": r[7], "motivo_decisao": r[8], "decisor_nome": r[9], "data_decisao": r[10]}
            for r in rows
        ]
