from fastapi import APIRouter, Depends, Query

from api.v1.auth import current_user
from modules.sincronizacao.schemas import Lote, RespostaLote, UltimaSincronizacao
from modules.sincronizacao.service import OPERACOES, SincronizacaoService

router = APIRouter(prefix="/sincronizacao", tags=["Sincronização"])


@router.post("/", response_model=RespostaLote)
def sincronizar(lote: Lote, usuario=Depends(current_user)):
    """Recebe um lote de operações feitas sem rede e devolve o desfecho de cada uma.

    Tipos aceitos: conferencia, bem_nao_cadastrado, transferencia_solicitar, transferencia_liberar,
    transferencia_receber, transferencia_recusar, emprestimo_registrar, emprestimo_devolver,
    manutencao_enviar e manutencao_retorno. Reenviar o mesmo lote é seguro (idempotente).
    """
    return SincronizacaoService().sincronizar(lote, usuario)


@router.get("/tipos")
def tipos():
    """Tipos de operação aceitos, para o aplicativo conferir compatibilidade."""
    return sorted(OPERACOES)


@router.get("/ultima", response_model=UltimaSincronizacao)
def ultima(dispositivo_id: str = Query(min_length=8, max_length=64), usuario=Depends(current_user)):
    """Data e resultado da última sincronização deste aparelho e usuário."""
    return SincronizacaoService().ultima(dispositivo_id, usuario)
