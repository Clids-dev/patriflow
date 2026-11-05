from typing import Optional

from fastapi import APIRouter, Depends
from modules.categoria.schemas import Categoria
from modules.categoria.schemas import CategoriaCreate
from modules.categoria.service import CategoriaService

router = APIRouter(prefix="/categoria", tags=["Categoria"])

def get_service() -> CategoriaService:
    return CategoriaService()

@router.get("/", response_model=list[Categoria])
def list_categorias(service: CategoriaService = Depends(get_service)):
    return service.get_categorias()


@router.get("/{id}/", response_model=Optional[Categoria])
def get_categoria_by_id(id: int):
    service = CategoriaService()
    return service.get_categoria_id(id)


@router.post("/", response_model=CategoriaCreate)
def add_categoria(categoria: CategoriaCreate):
    service = CategoriaService()
    return service.create_categoria(categoria)


@router.put("/", response_model=CategoriaCreate)
def update_categoria(id: int, novo_nome: str):
    service = CategoriaService()
    return service.put_categoria(id, novo_nome)


@router.delete("/", response_model=Categoria)
def delete_categoria(id: int):
    service = CategoriaService()
    return service.delete_categoria(id)


@router.get("/{id}/bens")
def bens_da_categoria(id: int):
    """Bens ativos da categoria, mais recentes primeiro."""
    from core.database import DataBase
    rows = DataBase().execute(
        """SELECT b.id, b.codigo_tombamento, b.nome, b.status, b.estado_conservacao, b.valor_aquisicao
           FROM bens b WHERE b.id_categoria = %s AND b.ativo = TRUE ORDER BY b.id DESC""", (id,)) or []
    return [
        {"id": r[0], "codigo_tombamento": r[1], "nome": r[2], "status": r[3],
         "estado_conservacao": r[4], "valor_aquisicao": float(r[5] or 0)}
        for r in rows
    ]
