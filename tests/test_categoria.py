"""Categorias: cadastro, renomear, inativar e reativar, pela API e num banco real.

Dados iniciais (schema.sql): a categoria 1 (sigla INF) tem bens ativos.
"""
import pytest
from fastapi.testclient import TestClient

from api.v1.auth import jwt_secret
from core.security import create_access_token
from main import app

pytestmark = pytest.mark.integracao


@pytest.fixture
def api(banco):
    cliente = TestClient(app, raise_server_exceptions=False)
    cliente.headers["Authorization"] = f"Bearer {create_access_token({'id': 1}, jwt_secret(), 300)}"
    return cliente


def test_renomear_mantem_a_sigla(api):
    r = api.put("/api/v1/categoria/", params={"id": 1, "novo_nome": "  Informática e TI  "})
    assert r.status_code == 200
    assert r.json() == {"id": 1, "nome": "Informática e TI", "sigla": "INF", "ativo": True}


@pytest.mark.parametrize("metodo, caminho, params", [
    ("put", "/api/v1/categoria/", {"id": 999, "novo_nome": "Qualquer"}),
    ("delete", "/api/v1/categoria/", {"id": 999}),
    ("post", "/api/v1/categoria/999/reativar", None),
    ("get", "/api/v1/categoria/999/", None),
])
def test_categoria_inexistente_responde_404(api, metodo, caminho, params):
    assert getattr(api, metodo)(caminho, params=params).status_code == 404


def test_nome_vazio_na_edicao_e_recusado(api):
    assert api.put("/api/v1/categoria/", params={"id": 1, "novo_nome": "   "}).status_code == 400


@pytest.mark.parametrize("sigla", ["A", "A1B", "ABCD", "A-B", ""])
def test_sigla_precisa_ter_tres_letras(api, sigla):
    r = api.post("/api/v1/categoria/", json={"nome": "Ferramentas", "sigla": sigla})
    assert r.status_code == 422
    assert "3 letras" in r.text


def test_sigla_e_normalizada_e_unica(api):
    criada = api.post("/api/v1/categoria/", json={"nome": "  Ferramentas ", "sigla": " fér "})
    assert criada.status_code == 200
    assert criada.json()["sigla"] == "FER" and criada.json()["nome"] == "Ferramentas" and criada.json()["id"]
    repetida = api.post("/api/v1/categoria/", json={"nome": "Outra", "sigla": "inf"})
    assert repetida.status_code == 409


def test_inativar_tira_dos_formularios_e_reativar_devolve(api):
    assert api.delete("/api/v1/categoria/", params={"id": 1}).json()["ativo"] is False

    ativas = [c["id"] for c in api.get("/api/v1/categoria/").json()]
    todas = {c["id"]: c["ativo"] for c in api.get("/api/v1/categoria/", params={"incluir_inativas": True}).json()}
    assert 1 not in ativas and todas[1] is False
    assert api.get("/api/v1/categoria/1/").json()["ativo"] is False  # a ficha continua acessível
    assert api.get("/api/v1/bem/proximo-codigo/1").status_code == 404  # sem tombo novo em categoria inativa

    assert api.post("/api/v1/categoria/1/reativar").json()["ativo"] is True
    assert api.get("/api/v1/bem/proximo-codigo/1").status_code == 200


def test_listagem_completa_traz_ativas_primeiro(api):
    api.delete("/api/v1/categoria/", params={"id": 1})
    situacoes = [c["ativo"] for c in api.get("/api/v1/categoria/", params={"incluir_inativas": True}).json()]
    assert situacoes == sorted(situacoes, reverse=True)
