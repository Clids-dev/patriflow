from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from api.v1.auth import current_user
from modules.auditoria.repository import AuditoriaRepository
from modules.bem.service import BemService
from modules.bem import historico
from modules.bem.schemas import BemCreate, BemUpdate, BaixaCreate, DecisaoRecusa, EventoHistorico

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
def desativar_bem(id: int, dados: BaixaCreate, usuario=Depends(current_user)):
    """Baixa com motivo e documento. Acima da alçada, fica aguardando aprovação de outro servidor."""
    from modules.bem import baixa
    return baixa.solicitar(id, dados, usuario)


@router.get("/baixas/pendentes")
def baixas_pendentes(usuario=Depends(current_user)):
    from modules.bem import baixa
    return baixa.pendentes(usuario)


@router.post("/baixas/{baixa_id}/aprovar")
def aprovar_baixa(baixa_id: int, usuario=Depends(current_user)):
    from modules.bem import baixa
    return baixa.decidir(baixa_id, True, None, usuario)


@router.post("/baixas/{baixa_id}/recusar")
def recusar_baixa(baixa_id: int, decisao: DecisaoRecusa, usuario=Depends(current_user)):
    from modules.bem import baixa
    return baixa.decidir(baixa_id, False, decisao.motivo, usuario)

@router.post("/{id}/reativar")
def reativar_bem(id: int, service: BemService = Depends(get_service), usuario=Depends(current_user)):
    return service.reativar_bem(id, usuario)

@router.post("/importar")
def importar_bens(arquivo: UploadFile = File(...), simular: bool = Form(True), usuario=Depends(current_user)):
    from modules.bem.importacao import LIMITE_BYTES, processar
    dados = arquivo.file.read(LIMITE_BYTES + 1)
    return processar(dados, simular, usuario, BemService)

@router.get("/alertas/garantias")
def alertas_garantias(dias: int = 60, service: BemService = Depends(get_service)):
    return service.alertas_garantia(dias)

@router.get("/{id}/auditoria")
def historico_de_alteracoes(id: int):
    return AuditoriaRepository().listar("bem", id)


@router.get("/{id}/historico", response_model=list[EventoHistorico])
def linha_do_tempo(id: int, limite: int = Query(200, ge=1, le=1000)):
    """Todos os eventos do bem, do mais recente para o mais antigo."""
    return historico.linha_do_tempo(id, limite)
