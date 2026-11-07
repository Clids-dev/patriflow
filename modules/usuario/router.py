from typing import Literal, Optional

from fastapi import APIRouter, Depends, Query
from api.v1.auth import current_user
from modules.usuario.repository import UsuarioRepository
from modules.usuario.schemas import UsuarioAtualizacao
from modules.usuario.service import UsuarioService

router = APIRouter(prefix="/usuarios", tags=["Usuários"])


@router.get("/")
def listar_usuarios(situacao: Optional[Literal["aguardando", "ativo", "desativado", "recusado"]] = Query(None)):
    """Usuários, os que aguardam aprovação primeiro. `situacao` filtra (D3)."""
    return UsuarioService(UsuarioRepository()).listar(situacao)


@router.patch("/{id}")
def atualizar_usuario(id: int, data: UsuarioAtualizacao, admin=Depends(current_user)):
    """Perfil, setor e situação. Recusar só vale para cadastro aguardando; responsável precisa de setor (D2)."""
    return UsuarioService(UsuarioRepository()).atualizar(id, admin, data.perfil, data.setor_id, data.ativo,
                                                         data.situacao)
