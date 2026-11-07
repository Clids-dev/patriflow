"""Situação do cadastro (D3) e setor obrigatório do responsável (D2), pela API e num banco real."""
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


def _cadastrar(api, username="novo_agente"):
    r = api.post("/api/v1/auth/register", json={"username": username, "senha": "senha-forte-1", "nome": "Novo Agente",
                                               "setor_id": 1})
    assert r.status_code == 201
    return r.json()["id"]


def _login(api, username):
    return TestClient(app).post("/api/v1/auth/login", json={"username": username, "senha": "senha-forte-1"})


def test_cadastro_publico_nasce_aguardando_e_aparece_primeiro(api):
    uid = _cadastrar(api)
    lista = api.get("/api/v1/usuarios/").json()
    assert lista[0]["id"] == uid and lista[0]["situacao"] == "aguardando"
    assert [u["id"] for u in api.get("/api/v1/usuarios/", params={"situacao": "aguardando"}).json()] == [uid]
    r = _login(api, "novo_agente")
    assert r.status_code == 403 and "aguardando aprovação" in r.json()["detail"]


def test_recusado_fica_registrado_com_quem_decidiu(api):
    uid = _cadastrar(api)
    r = api.patch(f"/api/v1/usuarios/{uid}", json={"perfil": "agente_campo", "setor_id": 1, "situacao": "recusado"})
    assert r.status_code == 200 and r.json()["situacao"] == "recusado" and r.json()["ativo"] is False
    registro = next(u for u in api.get("/api/v1/usuarios/").json() if u["id"] == uid)
    assert registro["decidido_por"] and registro["decidido_em"]
    assert "recusado" in _login(api, "novo_agente").json()["detail"]


def test_so_cadastro_aguardando_pode_ser_recusado(api):
    uid = _cadastrar(api)
    api.patch(f"/api/v1/usuarios/{uid}", json={"perfil": "agente_campo", "setor_id": 1, "situacao": "ativo"})
    r = api.patch(f"/api/v1/usuarios/{uid}", json={"perfil": "agente_campo", "setor_id": 1, "situacao": "recusado"})
    assert r.status_code == 409


def test_aprovar_desativar_e_cliente_antigo_com_ativo(api):
    uid = _cadastrar(api)
    assert api.patch(f"/api/v1/usuarios/{uid}", json={"perfil": "agente_campo", "setor_id": 1, "ativo": True}).json()["situacao"] == "ativo"
    assert _login(api, "novo_agente").status_code == 200
    assert api.patch(f"/api/v1/usuarios/{uid}", json={"perfil": "agente_campo", "setor_id": 1, "ativo": False}).json()["situacao"] == "desativado"
    assert "desativada" in _login(api, "novo_agente").json()["detail"]


def test_responsavel_so_e_ativado_com_setor(api):
    uid = _cadastrar(api)
    r = api.patch(f"/api/v1/usuarios/{uid}", json={"perfil": "responsavel_setor", "setor_id": None, "situacao": "ativo"})
    assert r.status_code == 400


def test_senha_errada_nao_revela_a_situacao(api):
    _cadastrar(api)
    r = TestClient(app).post("/api/v1/auth/login", json={"username": "novo_agente", "senha": "errada-123"})
    assert r.status_code == 401
