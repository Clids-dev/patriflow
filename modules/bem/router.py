from fastapi import APIRouter, Depends
from api.v1.auth import current_user
from modules.auditoria.repository import AuditoriaRepository
from modules.bem.service import BemService
from modules.bem.schemas import BemCreate, BemUpdate

router = APIRouter(prefix="/bem", tags=["Bens"])

def get_service() -> BemService:
    return BemService()

@router.get("/")
def list_bens(service: BemService = Depends(get_service)):
    return service.get_bens()

@router.get("/stats/categoria")
def get_stats_categoria(service: BemService = Depends(get_service)):
    return service.get_stats_categoria()

@router.get("/stats/status")
def get_stats_status(service: BemService = Depends(get_service)):
    return service.get_stats_status()

@router.post("/")
def add_bem(bem: BemCreate, service: BemService = Depends(get_service), usuario=Depends(current_user)):
    return service.create_bem(bem, usuario)

@router.put("/{id}")
def update_bem(id: int, bem: BemUpdate, service: BemService = Depends(get_service), usuario=Depends(current_user)):
    return service.put_bem(id, bem, usuario)

@router.get("/buscar")
def buscar_por_codigo(codigo_tombamento: str, service: BemService = Depends(get_service)):
    return service.get_by_codTomb(codigo_tombamento)

@router.get("/setor/{setor_id}")
def get_bens_do_setor(setor_id: int, service: BemService = Depends(get_service)):
    return service.get_por_setor(setor_id)

@router.get("/{id}/detalhes")
def get_detalhes(id: int, service: BemService = Depends(get_service)):
    return service.get_bem_detalhes(id)

@router.get("/proximo-codigo/{id_categoria}")
def get_proximo_codigo(id_categoria: int, service: BemService = Depends(get_service)):
    return {"codigo": service.get_proximo_codigo(id_categoria)}

@router.post("/{id}/desativar")
def desativar_bem(id: int, service: BemService = Depends(get_service), usuario=Depends(current_user)):
    return service.desativar_bem(id, usuario)

@router.post("/{id}/reativar")
def reativar_bem(id: int, service: BemService = Depends(get_service), usuario=Depends(current_user)):
    return service.reativar_bem(id, usuario)

@router.get("/{id}/auditoria")
def historico_de_alteracoes(id: int):
    return AuditoriaRepository().listar("bem", id)
