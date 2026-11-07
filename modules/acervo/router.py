from fastapi import APIRouter, Depends

from api.v1.auth import current_user
from modules.acervo.service import acervo_do_setor

router = APIRouter(prefix="/acervo", tags=["Acervo offline"])


@router.get("/setor/{setor_id}")
def baixar_acervo(setor_id: int, usuario=Depends(current_user)):
    """Acervo do setor para consulta sem rede: fichas completas, categorias, setores e localizações."""
    return acervo_do_setor(setor_id, usuario)
