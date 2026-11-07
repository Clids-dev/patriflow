"""Registros de cadastro: bens ligados a responsável e a categoria."""
from unittest.mock import patch

from fastapi.testclient import TestClient
from fastapi import FastAPI

from api.v1.auth import current_user
from modules.categoria import router as categoria_router
from modules.responsavel import router as responsavel_router

USUARIO = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}


def _app():
    app = FastAPI()
    app.include_router(responsavel_router.router, prefix="/api/v1")
    app.include_router(categoria_router.router, prefix="/api/v1")
    app.dependency_overrides[current_user] = lambda: USUARIO
    return app


def test_bens_do_responsavel_devolvem_lista_e_valor():
    linhas = [(5, "INF-001-0", "Notebook", "Em Uso", "bom", 1500, "Financeiro")]
    with patch.object(responsavel_router, "DataBase") as db:
        db.return_value.execute.return_value = linhas
        r = TestClient(_app()).get("/api/v1/responsavel/1/bens")
    assert r.status_code == 200
    assert r.json()[0]["codigo_tombamento"] == "INF-001-0" and r.json()[0]["valor_aquisicao"] == 1500.0


def test_bens_da_categoria_vazio():
    with patch("core.database.DataBase") as db:
        db.return_value.execute.return_value = []
        r = TestClient(_app()).get("/api/v1/categoria/9/bens")
    assert r.status_code == 200 and r.json() == []
