from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse

from api.v1.auth import current_user
from core import config
from modules.foto.schemas import FotoOut, RegistroTipo
from modules.foto.service import FotoService

router = APIRouter(prefix="/fotos", tags=["Fotos"])


@router.post("/", status_code=201, response_model=FotoOut)
def enviar_foto(
    arquivo: UploadFile = File(...),
    registro_tipo: RegistroTipo = Form(...),
    registro_id: int = Form(..., gt=0),
    usuario=Depends(current_user),
):
    # Lê só até o limite + 1 byte: basta para saber se estourou, sem carregar arquivos enormes.
    dados = arquivo.file.read(config.FOTO_MAX_BYTES + 1)
    return FotoService().registrar(dados, registro_tipo, registro_id, usuario)


@router.get("/", response_model=list[FotoOut])
def listar_fotos(registro_tipo: RegistroTipo, registro_id: int, usuario=Depends(current_user)):
    return FotoService().listar(registro_tipo, registro_id)


@router.get("/{foto_id}")
def obter_foto(foto_id: int, usuario=Depends(current_user)):
    foto, caminho = FotoService().arquivo_da_foto(foto_id)
    return FileResponse(caminho, media_type=foto["content_type"])
