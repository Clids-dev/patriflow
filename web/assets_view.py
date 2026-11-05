from fastapi import APIRouter, Request
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates

router = APIRouter()
templates = Jinja2Templates(directory="templates")

@router.get("/bens")
def tela_bens(request: Request):
    nome = request.cookies.get("username")
    tipo = request.cookies.get("tipo")
    return templates.TemplateResponse("bens.html", {
        "request": request,
        "username": nome,
        "tipo": tipo,
        "active_page": "bens"
    })

@router.get("/movimentacao")
def tela_movimentacao(request: Request):
    nome = request.cookies.get("username")
    tipo = request.cookies.get("tipo")
    return templates.TemplateResponse("movimentacao.html", {
        "request": request,
        "username": nome,
        "tipo": tipo,
        "active_page": "movimentacao"
    })

@router.get("/categoria")
def tela_categoria(request: Request):
    nome = request.cookies.get("username")
    tipo = request.cookies.get("tipo")
    return templates.TemplateResponse("categoria.html", {
        "request": request,
        "username": nome,
        "tipo": tipo,
        "active_page": "categoria"
    })

@router.get("/setores")
def tela_setores(request: Request):
    nome = request.cookies.get("username")
    tipo = request.cookies.get("tipo")
    return templates.TemplateResponse("setores.html", {
        "request": request,
        "username": nome,
        "tipo": tipo,
        "active_page": "setores"
    })

@router.get("/responsaveis")
def tela_responsaveis(request: Request):
    nome = request.cookies.get("username")
    tipo = request.cookies.get("tipo")
    return templates.TemplateResponse("responsaveis.html", {
        "request": request,
        "username": nome,
        "tipo": tipo,
        "active_page": "responsaveis"
    })

@router.get("/relatorios")
def tela_relatorios(request: Request):
    nome = request.cookies.get("username")
    tipo = request.cookies.get("tipo")
    return templates.TemplateResponse("relatorios.html", {
        "request": request,
        "username": nome,
        "tipo": tipo,
        "active_page": "relatorios"
    })

def _contexto(request: Request, active_page: str, **extra) -> dict:
    return {
        "request": request,
        "username": request.cookies.get("username"),
        "tipo": request.cookies.get("tipo"),
        "active_page": active_page,
        **extra,
    }


@router.get("/estrutura")
def tela_estrutura(request: Request):
    return templates.TemplateResponse("estrutura.html", _contexto(request, "estrutura"))


@router.get("/cadastros")
def redireciona_cadastros():
    # Endereço antigo do painel: mantido para links salvos.
    return RedirectResponse(url="/estrutura", status_code=301)


# Registro de um cadastro, com abas (dados, bens ligados e ação específica).
# A entidade vai no caminho: /categoria/{id}, /setores/{id}, /responsaveis/{id}.
@router.get("/categoria/{registro_id}")
def registro_categoria(registro_id: int, request: Request):
    return templates.TemplateResponse("registro.html", _contexto(
        request, "categoria", entidade="categoria", registro_id=registro_id))


@router.get("/setores/{registro_id}")
def registro_setor(registro_id: int, request: Request):
    return templates.TemplateResponse("registro.html", _contexto(
        request, "setores", entidade="setor", registro_id=registro_id))


@router.get("/responsaveis/{registro_id}")
def registro_responsavel(registro_id: int, request: Request):
    return templates.TemplateResponse("registro.html", _contexto(
        request, "responsaveis", entidade="responsavel", registro_id=registro_id))


@router.get("/localizacoes")
def tela_localizacoes(request: Request):
    return templates.TemplateResponse("localizacoes.html", _contexto(request, "localizacoes"))
