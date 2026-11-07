from fastapi import APIRouter, Depends
from api.v1.auth import router as auth_router, require_api_access
from modules.bem.router import router as bem_router
from modules.categoria.router import router as categoria_router
from modules.movimentacao.router import router as movimentacao_router
from modules.responsavel.router import router as responsavel_router
from modules.setor.router import router as setor_router
from modules.localizacao.router import router as localizacao_router
from modules.relatorio.router import router as relatorio_router
from modules.usuario.router import router as usuario_router
from modules.foto.router import router as foto_router
from modules.etiqueta.router import router as etiqueta_router
from modules.termo.router import router as termo_router
from modules.emprestimo.router import router as emprestimo_router
from modules.manutencao.router import router as manutencao_router
from modules.inventario.router import router as inventario_router
from modules.pendencia.router import router as pendencia_router
from modules.sincronizacao.router import router as sincronizacao_router
from modules.acervo.router import router as acervo_router

api_router = APIRouter(dependencies=[Depends(require_api_access)])
api_router.include_router(auth_router)

api_router.include_router(bem_router)
api_router.include_router(categoria_router)
api_router.include_router(movimentacao_router)
api_router.include_router(responsavel_router)
api_router.include_router(setor_router)
api_router.include_router(localizacao_router)
api_router.include_router(relatorio_router)
api_router.include_router(usuario_router)
api_router.include_router(foto_router)
api_router.include_router(etiqueta_router)
api_router.include_router(termo_router)
api_router.include_router(emprestimo_router)
api_router.include_router(manutencao_router)
api_router.include_router(inventario_router)
api_router.include_router(pendencia_router)
api_router.include_router(sincronizacao_router)
api_router.include_router(acervo_router)
