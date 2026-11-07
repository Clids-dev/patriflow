from fastapi import APIRouter, Depends, Query

from api.v1.auth import current_user
from modules.pendencia.schemas import Pendencia, Resolucao, Situacao
from modules.pendencia.service import PendenciaService

router = APIRouter(prefix="/pendencias", tags=["Pendências"])


@router.get("/", response_model=list[Pendencia])
def listar(situacao: Situacao = Query("abertas")):
    """Caixa de pendências. Abertas vêm da mais antiga para a mais nova."""
    return PendenciaService().listar(situacao)


@router.get("/acoes")
def acoes_por_tipo():
    """Ações guiadas disponíveis para cada tipo de pendência."""
    from modules.pendencia.acoes import ACOES
    return ACOES


@router.post("/{pendencia_id}/resolver", response_model=Pendencia)
def resolver(pendencia_id: int, dados: Resolucao, usuario=Depends(current_user)):
    """Resolve com uma ação do tipo da pendência; algumas executam algo (ex.: abrir a baixa por extravio)."""
    return PendenciaService().resolver(pendencia_id, dados, usuario)
