from fastapi import APIRouter, Depends
from api.v1.auth import current_user
from modules.usuario.repository import UsuarioRepository
from modules.usuario.schemas import UsuarioAtualizacao
from modules.usuario.service import UsuarioService

router = APIRouter(prefix="/usuarios", tags=["Usuários"])


@router.get("/")
def listar_usuarios():
    return UsuarioService(UsuarioRepository()).listar()


@router.patch("/{id}")
def atualizar_usuario(id: int, data: UsuarioAtualizacao, admin=Depends(current_user)):
    return UsuarioService(UsuarioRepository()).atualizar(id, admin, data.perfil, data.setor_id, data.ativo)
