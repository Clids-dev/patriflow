from fastapi import APIRouter, Request, Form
from fastapi.templating import Jinja2Templates
from fastapi.responses import RedirectResponse
from api.v1.auth import jwt_secret
from core import config
from core.security import create_access_token

from modules.usuario.repository import UsuarioRepository
from modules.usuario.service import UsuarioService

router = APIRouter()
templates = Jinja2Templates(directory="templates")


# GET - página de login
@router.get("/login")
def login_page(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})


@router.get("/criar-conta")
def register_page(request: Request):
    return templates.TemplateResponse("register.html", {"request": request})


@router.post("/criar-conta")
def register(
    request: Request,
    nome: str = Form(...),
    username: str = Form(...),
    senha: str = Form(...),
    confirmar_senha: str = Form(...),
    setor_id: int | None = Form(None),
):
    if senha != confirmar_senha:
        return templates.TemplateResponse("register.html", {
            "request": request, "erro": "As senhas não coincidem.",
            "nome": nome, "username": username,
        }, status_code=422)
    try:
        UsuarioService(UsuarioRepository()).criar_conta(username, senha, nome, setor_id)
    except ValueError as exc:
        status_code = 409 if "já está em uso" in str(exc) else 422
        return templates.TemplateResponse("register.html", {
            "request": request, "erro": str(exc), "nome": nome, "username": username,
        }, status_code=status_code)
    return templates.TemplateResponse("login.html", {
        "request": request, "sucesso": "Conta criada. Entre com o seu utilizador e senha.",
    }, status_code=201)


# POST - processar login
@router.post("/login")
def login(
    request: Request,
    login_usuario: str = Form(...),
    password_usuario: str = Form(...)
):
    repo = UsuarioRepository()
    service = UsuarioService(repo)

    user = service.login(login_usuario, password_usuario)

    if not user:
        return templates.TemplateResponse("login.html", {
            "request": request,
            "erro": "Login inválido"
        })
    response = RedirectResponse(url="/index", status_code=302)
    token = create_access_token({"id": user[0]}, jwt_secret(), config.JWT_EXPIRES_SECONDS)

    response.set_cookie(key="username", value=user[1])
    response.set_cookie(key="tipo", value=user[3])
    response.set_cookie(
        key="access_token", value=token, httponly=True,
        secure=request.url.scheme == "https", samesite="lax",
        max_age=config.JWT_EXPIRES_SECONDS
    )

    return response


@router.get("/logout")
def logout():
    response = RedirectResponse(url="/login", status_code=302)
    response.delete_cookie("access_token")
    response.delete_cookie("username")
    response.delete_cookie("tipo")
    return response
