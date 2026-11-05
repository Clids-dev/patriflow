from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse

from api.v1.auth import current_user
from modules.termo.service import termo_html

router = APIRouter(prefix="/termos", tags=["Termos"])


@router.get("/responsavel/{responsavel_id}", response_class=HTMLResponse)
def termo_do_responsavel(responsavel_id: int, usuario=Depends(current_user)):
    return HTMLResponse(termo_html(responsavel_id))
