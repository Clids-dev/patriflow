import os
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from core import config
from core.security import create_access_token, decode_access_token
from modules.usuario.repository import UsuarioRepository
from modules.usuario.service import UsuarioService

router = APIRouter(prefix="/auth", tags=["Autenticação"])
bearer = HTTPBearer(auto_error=False)


class LoginRequest(BaseModel):
    username: str
    senha: str


class RegisterRequest(BaseModel):
    model_config = {"extra": "forbid"}
    username: str
    senha: str
    nome: str
    setor_id: int | None = None


def jwt_secret() -> str:
    secret = config.JWT_SECRET or os.getenv("PATRIFLOW_JWT_SECRET", "")
    if not secret:
        raise HTTPException(status_code=503, detail="Autenticação não configurada: defina PATRIFLOW_JWT_SECRET")
    return secret


def user_payload(row):
    raw_profile = str(row[3]).strip().lower().replace(" ", "_").replace("á", "a")
    profile = {"admin": "setor_patrimonio", "comum": "agente_campo"}.get(raw_profile, raw_profile)
    return {"id": row[0], "username": row[1], "password_hash": row[2], "perfil": profile, "ativo": row[4], "nome": row[5], "setor_id": row[6]}


@router.post("/login")
def login(data: LoginRequest):
    row = UsuarioService(UsuarioRepository()).login(data.username, data.senha)
    if not row:
        raise HTTPException(status_code=401, detail="Credenciais inválidas")
    user = user_payload(row)
    token = create_access_token(user, jwt_secret(), config.JWT_EXPIRES_SECONDS)
    return {"access_token": token, "token_type": "bearer", "expires_in": config.JWT_EXPIRES_SECONDS}


@router.post("/register", status_code=201)
def register(data: RegisterRequest):
    try:
        row = UsuarioService(UsuarioRepository()).criar_conta(
            data.username, data.senha, data.nome, data.setor_id
        )
    except ValueError as exc:
        raise HTTPException(status_code=409 if "já está em uso" in str(exc) else 422, detail=str(exc)) from exc
    return {"id": row[0], "username": row[1], "nome": row[5], "perfil": row[3], "setor_id": row[6]}


def current_user(request: Request, credentials: HTTPAuthorizationCredentials = Depends(bearer)):
    if request.url.path.endswith(("/auth/login", "/auth/register")):
        return None
    token = credentials.credentials if credentials else request.cookies.get("access_token")
    if not token:
        raise HTTPException(status_code=401, detail="Token de acesso obrigatório", headers={"WWW-Authenticate": "Bearer"})
    try:
        claims = decode_access_token(token, jwt_secret())
        row = UsuarioRepository().buscar_por_id(int(claims["sub"]))
    except (ValueError, KeyError):
        row = None
    if not row or not row[4]:
        raise HTTPException(status_code=401, detail="Token inválido ou utilizador inativo", headers={"WWW-Authenticate": "Bearer"})
    return user_payload(row)


@router.get("/me")
def me(user=Depends(current_user)):
    return {"id": user["id"], "username": user["username"], "nome": user["nome"], "perfil": user["perfil"], "setor_id": user["setor_id"]}


ROLE_PERMISSIONS = {
    "setor_patrimonio": {"bem:read", "bem:create", "bem:update", "bem:delete", "categoria:*", "setores:*", "localizacao:*", "relatorio:read", "responsavel:*", "movimentacao:*"},
    "agente_campo": {"bem:read", "bem:update", "localizacao:read", "movimentacao:read", "movimentacao:create", "movimentacao:update"},
    "responsavel_setor": {"bem:read", "localizacao:read", "movimentacao:read", "movimentacao:accept"},
}


def action_for(method: str, path: str) -> str:
    parts = path.strip("/").split("/")
    resource = parts[0] if parts else ""
    action = {"GET": "read", "HEAD": "read", "OPTIONS": "read", "POST": "create", "PUT": "update", "PATCH": "update", "DELETE": "delete"}.get(method, "")
    if resource == "bem" and len(parts) > 1 and parts[1] in {"stats", "buscar", "proximo-codigo"}:
        action = "read"
    if resource == "movimentacao" and method == "POST":
        action = "create"
    if resource == "movimentacao" and method == "PUT":
        action = "accept"
    return f"{resource}:{action}"


def require_api_access(request: Request, user=Depends(current_user)):
    if request.url.path.endswith(("/auth/login", "/auth/register")):
        return None
    # Todo usuário autenticado pode consultar o próprio perfil. O endpoint é
    # necessário para completar o login e validar o auto-login do aplicativo.
    if request.url.path.endswith("/auth/me"):
        return user
    action = action_for(request.method, request.url.path.removeprefix("/api/v1/"))
    profile = user["perfil"]
    permissions = ROLE_PERMISSIONS.get(profile, set())
    if action not in permissions and f"{action.split(':')[0]}:*" not in permissions:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permissão negada para esta ação")
    return user
