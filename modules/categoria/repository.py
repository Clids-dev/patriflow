from core.database import DataBase
from modules.categoria.schemas import CategoriaCreate, Categoria
from . import queries


def _modelo(row) -> Categoria | None:
    return Categoria(id=row[0], nome=row[1], sigla=row[2], ativo=row[3]) if row else None


class CategoriaRepository:
    def get_all(self, incluir_inativas: bool = False) -> list[Categoria]:
        sql = queries.QUERY_CATEGORIAS_TODAS if incluir_inativas else queries.QUERY_CATEGORIAS
        return [_modelo(row) for row in DataBase().execute(sql) or []]

    def save(self, categoria: CategoriaCreate) -> Categoria:
        result = DataBase().commit(queries.QUERY_CREATE_CATEGORIA, (categoria.nome, categoria.sigla))
        return Categoria(id=result[0], nome=categoria.nome, sigla=categoria.sigla, ativo=True)

    def get_id(self, id: int, incluir_inativa: bool = False) -> Categoria | None:
        sql = queries.QUERY_CATEGORIA_ID_QUALQUER if incluir_inativa else queries.QUERY_CATEGORIA_ID
        return _modelo(DataBase().execute(sql, (id,), many=False))

    def renomear(self, id: int, novo_nome: str) -> Categoria | None:
        return _modelo(DataBase().commit(queries.QUERY_RENOMEAR_CATEGORIA, (novo_nome, id)))

    def delete(self, id: int) -> Categoria | None:
        return _modelo(DataBase().commit(queries.QUERY_DELETE_CATEGORIA, (id,)))

    def reativar(self, id: int) -> Categoria | None:
        return _modelo(DataBase().commit(queries.QUERY_REATIVAR_CATEGORIA, (id,)))
