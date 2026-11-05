from typing import Optional

from fastapi import APIRouter, Depends
from api.v1.auth import current_user
from modules.movimentacao.schemas import Movimentacao
from modules.movimentacao.schemas import MovimentacaoCreate, MovimentacaoDetailed
from modules.movimentacao.repository import MovimentacaoRepository
from modules.movimentacao.service import MovimentacaoService
from modules.movimentacao import schemas

router = APIRouter(prefix="/movimentacao", tags=["Movimentacao"])


@router.get("/", response_model=list[Movimentacao])
def get_movimentacoes():
    return MovimentacaoService().get_movimentacoes()


@router.get("/detailed/", response_model=list[MovimentacaoDetailed])
def get_detailed_movimentacoes():
    return MovimentacaoService().get_detailed_movimentacoes()


@router.get("/pendentes", response_model=list[MovimentacaoDetailed])
def listar_pendentes():
    return MovimentacaoService().listar_pendentes()


@router.get("/bem/{codigo}", response_model=list[MovimentacaoDetailed])
def get_movimentacoes_por_bem(codigo: str):
    return MovimentacaoService().get_movimentacoes_por_bem(codigo)


@router.get("/{id}/", response_model=Optional[schemas.Movimentacao])
def get_movimentacao_by_id(id: int):
    return MovimentacaoService().get_movimentacao_by_id(id)


@router.post("/", response_model=schemas.Movimentacao)
def add_movimentacao(movimentacao: MovimentacaoCreate, usuario=Depends(current_user)):
    return MovimentacaoService().add_movimentacao(movimentacao, usuario)


@router.post("/{id}/aprovar", response_model=schemas.Movimentacao)
def aprovar_movimentacao(id: int, usuario=Depends(current_user)):
    return MovimentacaoService().decidir_movimentacao(id, usuario, aprovar=True)


@router.post("/{id}/recusar", response_model=schemas.Movimentacao)
def recusar_movimentacao(id: int, decisao: schemas.DecisaoRecusa, usuario=Depends(current_user)):
    return MovimentacaoService().decidir_movimentacao(id, usuario, aprovar=False, motivo=decisao.motivo)


@router.get("/minhas")
def minhas_solicitacoes(usuario=Depends(current_user)):
    return MovimentacaoRepository().listar_minhas_solicitacoes(usuario["id"])
