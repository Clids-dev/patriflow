from fastapi import APIRouter, Depends

from api.v1.auth import current_user
from modules.setor import designacao
from modules.setor.schemas import SetorFlat, SetorCreate
from modules.setor.service import SetorService

router = APIRouter(prefix="/setores", tags=["Setores"])

@router.get("/", response_model=list[SetorFlat])
def get_setores():
    service = SetorService()
    return service.get_setores()

@router.get("/{id}/", response_model=SetorFlat)
def get_setor_by_id(id: int):
    service = SetorService()
    return service.get_setor_by_id(id)

@router.post("/", response_model=SetorFlat)
def add_setor(setor: SetorCreate):
    service = SetorService()
    return service.add_setor(setor, setor.responsavel_id)

@router.put("/{id}")
def update_setor(id: int, novo_nome: str, novo_responsavel_id: int, novo_sala_id: int | None = None):
    service = SetorService()
    return service.put_setor(id, novo_nome, novo_responsavel_id, novo_sala_id)

@router.delete("/", response_model=SetorFlat)
def delete_setor(id: int):
    service = SetorService()
    return service.delete_setor(id)


@router.get("/{id}/agentes")
def agentes_do_setor(id: int):
    """Agentes de campo ativos, com a marcação dos designados a este setor (D1)."""
    return designacao.agentes_do_setor(id)


@router.put("/{id}/agentes")
def designar_agentes(id: int, dados: designacao.Designacao, usuario=Depends(current_user)):
    """Define a lista completa de agentes designados ao setor (os que ficarem de fora deixam de ser)."""
    return designacao.designar(id, dados.usuario_ids, usuario)
