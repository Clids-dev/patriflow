from core.database import DataBase
from modules.inventario import queries as q
from modules.inventario.schemas import Inventario, Item, SetorResumo

_CONDICAO_INVENTARIOS = {"abertos": "i.status = 'aberto'", "fechados": "i.status = 'fechado'", "todos": "TRUE"}

_FILTROS_ITENS = {
    "todos": "",
    "pendentes": " AND it.situacao IS NULL",
    "localizado": " AND it.situacao = 'localizado'",
    "outro_setor": " AND it.situacao = 'outro_setor'",
    "nao_localizado": " AND it.situacao = 'nao_localizado'",
    "nao_cadastrado": " AND it.situacao = 'nao_cadastrado'",
    "baixado_encontrado": " AND it.situacao = 'baixado_encontrado'",
    # Relatório de divergências: tudo o que não foi encontrado no lugar esperado.
    "divergencias": " AND it.situacao IN ('outro_setor', 'nao_localizado', 'nao_cadastrado', 'baixado_encontrado')",
}


def _inventario(r, setores=None) -> Inventario:
    return Inventario(id=r[0], descricao=r[1], inicio=r[2], fim=r[3], status=r[4], aberto_por=r[5], aberto_em=r[6],
                      fechado_por=r[7], fechado_em=r[8], total_itens=r[9], pendentes=r[10], setores=setores or [])


def _item(r) -> Item:
    return Item(id=r[0], bem_id=r[1], codigo_tombamento=r[2], nome=r[3], setor_esperado_id=r[4], setor_esperado=r[5],
                estado_esperado=r[6], ausencia_justificada=r[7], situacao=r[8], setor_encontrado_id=r[9],
                setor_encontrado=r[10], estado_encontrado=r[11], observacao=r[12], conferido_por=r[13],
                conferido_em=r[14])


class InventarioRepository:
    def listar(self, situacao: str) -> list[Inventario]:
        rows = DataBase().execute(q.LISTAR.format(condicao=_CONDICAO_INVENTARIOS[situacao])) or []
        return [_inventario(r) for r in rows]

    def buscar(self, inventario_id: int) -> Inventario | None:
        row = DataBase().execute(q.BUSCAR, (inventario_id,), many=False)
        if row is None:
            return None
        setores = [
            SetorResumo(setor_id=s[0], setor_nome=s[1], esperados=s[2], conferidos=s[3], localizados=s[4],
                        outro_setor=s[5], nao_localizados=s[6], nao_cadastrados=s[7], pendentes=s[8])
            for s in DataBase().execute(q.RESUMO_SETORES, (inventario_id,)) or []
        ]
        return _inventario(row, setores)

    def itens(self, inventario_id: int, setor_id: int | None, filtro: str) -> list[Item]:
        filtros = _FILTROS_ITENS[filtro]
        params = {"inv": inventario_id}
        if setor_id is not None:
            # Itens do setor: os que eram esperados ali e os que foram encontrados ali.
            filtros += " AND (it.setor_esperado_id = %(setor)s OR it.setor_encontrado_id = %(setor)s)"
            params["setor"] = setor_id
        rows = DataBase().execute(q.ITENS.format(filtros=filtros), params) or []
        return [_item(r) for r in rows]

    def item(self, item_id: int) -> Item | None:
        row = DataBase().execute(q.ITEM, {"item": item_id}, many=False)
        return _item(row) if row else None
