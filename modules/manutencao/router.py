from typing import Optional

from fastapi import APIRouter, Depends, Query, status

from api.v1.auth import current_user
from modules.manutencao.schemas import Manutencao, ManutencaoCreate, Retorno, Situacao
from modules.manutencao.service import ManutencaoService

router = APIRouter(prefix="/manutencoes", tags=["Manutenções"])


@router.get("/", response_model=list[Manutencao])
def listar(situacao: Situacao = Query("abertas"), bem_id: Optional[int] = Query(None, gt=0)):
    """Manutenções por situação. Abertas vêm pela mais antiga (há mais tempo fora)."""
    return ManutencaoService().listar(situacao, bem_id)


@router.get("/{manutencao_id}", response_model=Manutencao)
def buscar(manutencao_id: int):
    return ManutencaoService().buscar(manutencao_id)


@router.post("/", response_model=Manutencao, status_code=status.HTTP_201_CREATED)
def enviar(dados: ManutencaoCreate, usuario=Depends(current_user)):
    return ManutencaoService().enviar(dados, usuario)


@router.post("/{manutencao_id}/retorno", response_model=Manutencao)
def registrar_retorno(manutencao_id: int, dados: Retorno, usuario=Depends(current_user)):
    return ManutencaoService().registrar_retorno(manutencao_id, dados, usuario)
