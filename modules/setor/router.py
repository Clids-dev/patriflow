from fastapi import APIRouter
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
