from typing import Optional

from fastapi import APIRouter

from core.database import DataBase
from modules.responsavel.schemas import Responsavel
from modules.responsavel.schemas import ResponsavelCreate
from modules.responsavel.service import ResponsavelService

router = APIRouter(prefix="/responsavel", tags=["Responsavel"])

@router.get("/", response_model=list[Responsavel])
def get_responsaveis():
    service = ResponsavelService()
    return service.get_responsaveis()

@router.get("/{id}/", response_model=Responsavel)
def get_responsavel_by_id(id: int):
    service = ResponsavelService()
    return service.get_responsavel_by_id(id)

@router.post("/", response_model=ResponsavelCreate)
def add_responsavel(responsavel: ResponsavelCreate):
    service = ResponsavelService()
    return service.create_responsavel(responsavel)

@router.put("/", response_model=ResponsavelCreate)
def put_responsavel(id: int, dados: ResponsavelCreate):
    service = ResponsavelService()
    return service.put_responsavel(id, dados.nome, dados.cargo)

@router.delete("/", response_model=Responsavel)
def delete_responsavel(id: int):
    service = ResponsavelService()
    return service.delete_responsavel(id)


QUERY_BENS_DO_RESPONSAVEL = """
    SELECT b.id, b.codigo_tombamento, b.nome, b.status, b.estado_conservacao, b.valor_aquisicao, s.nome AS setor
    FROM bens b
    JOIN (
        SELECT DISTINCT ON (bem_id) bem_id, setor_destino_id
        FROM movimentacoes
        WHERE ativo = TRUE AND status = 'aprovada'
        ORDER BY bem_id, COALESCE(data_decisao, data_movimentacao) DESC, id DESC
    ) m ON m.bem_id = b.id
    JOIN setores s ON s.id = m.setor_destino_id
    WHERE s.responsavel_id = %s AND b.ativo = TRUE
    ORDER BY b.codigo_tombamento
"""


@router.get("/{id}/bens")
def bens_do_responsavel(id: int):
    """Bens sob a guarda do responsável (setor atual pela última movimentação aprovada)."""
    rows = DataBase().execute(QUERY_BENS_DO_RESPONSAVEL, (id,)) or []
    return [
        {"id": r[0], "codigo_tombamento": r[1], "nome": r[2], "status": r[3],
         "estado_conservacao": r[4], "valor_aquisicao": float(r[5] or 0), "setor": r[6]}
        for r in rows
    ]
