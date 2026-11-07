from typing import Literal, Optional

from pydantic import BaseModel

class UsuarioLogin(BaseModel):
    username: str
    senha: str

class UsuarioResponse(BaseModel):
    id: int
    username: str
    tipo: str
    ativo: bool


class UsuarioAtualizacao(BaseModel):
    perfil: str
    setor_id: int | None = None
    # "situacao" (D3) é o jeito novo; "ativo" continua aceito para os clientes antigos.
    situacao: Optional[Literal["ativo", "desativado", "recusado"]] = None
    ativo: Optional[bool] = None

