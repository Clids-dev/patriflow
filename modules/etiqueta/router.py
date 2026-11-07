from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import HTMLResponse, Response

from api.v1.auth import current_user
from modules.etiqueta.service import etiqueta_do_bem, pagina_lote

router = APIRouter(prefix="/etiquetas", tags=["Etiquetas"])


@router.get("/lote", response_class=HTMLResponse)
def etiquetas_em_lote(ids: str = Query(..., description="Ids dos bens separados por vírgula"),
                      incorporado: bool = Query(False, description="Esconde a barra própria, para exibir dentro de um modal"),
                      usuario=Depends(current_user)):
    try:
        lista = [int(parte) for parte in ids.split(",") if parte.strip()]
    except ValueError:
        raise HTTPException(status_code=400, detail="Ids inválidos. Use números separados por vírgula.")
    return HTMLResponse(pagina_lote(lista, incorporado=incorporado))


@router.get("/{bem_id}")
def etiqueta_de_um_bem(bem_id: int, usuario=Depends(current_user)):
    return Response(content=etiqueta_do_bem(bem_id), media_type="image/svg+xml")
