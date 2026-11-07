from core.database import DataBase
from modules.pendencia.schemas import Pendencia

# Fotos do registro de origem: conferência (bem não localizado não tem foto) ou bem não cadastrado.
_SELECT = """
    SELECT p.id, p.tipo, p.descricao, p.bem_id, b.codigo_tombamento, p.setor_id, s.nome, it.inventario_id,
           p.inventario_item_id, uc.nome, p.criada_em, ur.nome, p.resolvida_em, p.resolucao, p.sync_operacao_id,
           p.acao, p.referencia_id,
           (SELECT COALESCE(array_agg(f.id ORDER BY f.id), '{}') FROM fotos f
            WHERE f.registro_tipo IN ('conferencia', 'bem_nao_cadastrado') AND f.registro_id = p.inventario_item_id)
    FROM pendencias p
    LEFT JOIN bens b ON b.id = p.bem_id
    LEFT JOIN setores s ON s.id = p.setor_id
    LEFT JOIN inventario_itens it ON it.id = p.inventario_item_id
    LEFT JOIN usuarios uc ON uc.id = p.criada_por
    LEFT JOIN usuarios ur ON ur.id = p.resolvida_por
"""

_FILTROS = {"abertas": "p.resolvida_em IS NULL", "resolvidas": "p.resolvida_em IS NOT NULL", "todas": "TRUE"}


def _modelo(r) -> Pendencia:
    return Pendencia(id=r[0], tipo=r[1], descricao=r[2], bem_id=r[3], codigo_tombamento=r[4], setor_id=r[5],
                     setor_nome=r[6], inventario_id=r[7], inventario_item_id=r[8], criada_por=r[9], criada_em=r[10],
                     resolvida_por=r[11], resolvida_em=r[12], resolucao=r[13], sync_operacao_id=r[14],
                     acao=r[15], referencia_id=r[16], fotos=list(r[17] or []))


class PendenciaRepository:
    def listar(self, situacao: str) -> list[Pendencia]:
        ordem = "p.criada_em, p.id" if situacao == "abertas" else "p.criada_em DESC, p.id DESC"
        rows = DataBase().execute(f"{_SELECT} WHERE {_FILTROS[situacao]} ORDER BY {ordem}") or []
        return [_modelo(r) for r in rows]

    def buscar(self, pendencia_id: int) -> Pendencia | None:
        row = DataBase().execute(_SELECT + " WHERE p.id = %s", (pendencia_id,), many=False)
        return _modelo(row) if row else None

    def resolver(self, pendencia_id: int, usuario_id: int, resolucao: str, acao: str | None = None,
                 referencia_id: int | None = None) -> bool:
        """Resolve se ainda estiver aberta. Devolve False se já estava resolvida (ou não existe)."""
        row = DataBase().commit(
            """UPDATE pendencias SET resolvida_por = %s, resolvida_em = NOW(), resolucao = %s, acao = %s,
                                     referencia_id = %s
               WHERE id = %s AND resolvida_em IS NULL RETURNING id""",
            (usuario_id, resolucao, acao, referencia_id, pendencia_id),
        )
        return row is not None
