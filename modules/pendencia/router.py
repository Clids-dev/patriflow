from fastapi import APIRouter, Depends, Query

from api.v1.auth import current_user
from modules.pendencia.schemas import Pendencia, Resolucao, Situacao
from modules.pendencia.service import PendenciaService

router = APIRouter(prefix="/pendencias", tags=["Pendências"])


@router.get("/", response_model=list[Pendencia])
def listar(situacao: Situacao = Query("abertas")):
    """Caixa de pendências. Abertas vêm da mais antiga para a mais nova."""
    return PendenciaService().listar(situacao)


@router.post("/{pendencia_id}/resolver", response_model=Pendencia)
def resolver(pendencia_id: int, dados: Resolucao, usuario=Depends(current_user)):
    return PendenciaService().resolver(pendencia_id, dados.resolucao, usuario)
