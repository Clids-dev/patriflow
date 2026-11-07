"""Setores em inventário aberto (decisão D4).

Durante a contagem, o bem não se move: liberar, receber e a transferência direta do patrimônio esperam
o fechamento quando a origem ou o destino estiver em inventário aberto. Pedir, recusar e intervir
continuam livres, porque não mudam o bem de lugar.
"""
from core.database import DataBase


def setores_em_inventario(setor_ids) -> list[str]:
    """Nomes dos setores, entre os informados, que estão em inventário aberto."""
    ids = [i for i in set(setor_ids) if i is not None]
    if not ids:
        return []
    rows = DataBase().execute(
        """SELECT s.nome FROM inventario_setores i JOIN setores s ON s.id = i.setor_id
           WHERE i.aberto AND i.setor_id = ANY(%s) ORDER BY s.nome""", (ids,)) or []
    return [r[0] for r in rows]
