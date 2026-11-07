from typing import Optional

from fastapi import APIRouter, Depends, Query
from modules.categoria.schemas import Categoria, CategoriaCreate
from modules.categoria.service import CategoriaService

router = APIRouter(prefix="/categoria", tags=["Categoria"])

def get_service() -> CategoriaService:
    return CategoriaService()

@router.get("/", response_model=list[Categoria])
def list_categorias(incluir_inativas: bool = Query(False, description="Inclui as inativas (tela de gestão)"),
                    service: CategoriaService = Depends(get_service)):
    """Categorias ativas por nome. Com `incluir_inativas=true`, todas, ativas primeiro."""
    return service.get_categorias(incluir_inativas)


@router.get("/{id}/", response_model=Optional[Categoria])
def get_categoria_by_id(id: int):
    service = CategoriaService()
    return service.get_categoria_id(id)


@router.post("/", response_model=Categoria)
def add_categoria(categoria: CategoriaCreate):
    return CategoriaService().create_categoria(categoria)


@router.put("/", response_model=Categoria)
def update_categoria(id: int, novo_nome: str):
    """Renomeia a categoria. A sigla não muda: ela é o prefixo dos tombos já emitidos."""
    return CategoriaService().renomear(id, novo_nome)


@router.delete("/", response_model=Categoria)
def delete_categoria(id: int):
    """Inativa a categoria (nada é apagado)."""
    return CategoriaService().delete_categoria(id)


@router.post("/{id}/reativar", response_model=Categoria)
def reativar_categoria(id: int):
    return CategoriaService().reativar(id)


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
