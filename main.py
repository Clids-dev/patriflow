from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from api.v1.router import api_router
from web.router import web_router

app = FastAPI(
    title="Sistema de Tombamento",
    description="API e Interface Web para gestão de patrimônio",
    version="1.0.0"
)


class StaticSemCacheVelho(StaticFiles):
    """Arquivos estáticos que o navegador sempre revalida antes de usar.

    Sem Cache-Control, o navegador reaproveita JS e CSS antigos por conta própria, inclusive módulos
    importados (como utils.js), que não recebem "?v=" no HTML. Com "no-cache" o arquivo continua
    guardado, mas a cada carregamento o navegador pergunta ao servidor; se nada mudou, a resposta é
    um 304 vazio (via ETag), então o custo é pequeno.
    """

    def file_response(self, *args, **kwargs):
        resposta = super().file_response(*args, **kwargs)
        resposta.headers["Cache-Control"] = "no-cache"
        return resposta


# Arquivos Estáticos
app.mount("/static", StaticSemCacheVelho(directory="static"), name="static")

# Rotas Web (Templates)
app.include_router(web_router)

# Rotas API (JSON)
app.include_router(api_router, prefix="/api/v1")

@app.get("/")
async def root():
    return {"message": "Bem-vindo ao Sistema de Tombamento. Acesse /index para a interface web ou /docs para a API."}
