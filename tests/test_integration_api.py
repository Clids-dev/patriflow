import pytest
from fastapi.testclient import TestClient
from api.v1.auth import jwt_secret
from core.security import create_access_token
from main import app

# As rotas da API exigem login. O usuário 1 é o administrador (setor de patrimônio).
_token = create_access_token({"id": 1}, jwt_secret(), 300)
client = TestClient(app, headers={"Authorization": f"Bearer {_token}"})

def test_api_list_bens():
    """Verifica se a listagem de bens retorna status 200."""
    response = client.get("/api/v1/bem/")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_api_report_excel():
    """Verifica se o endpoint de exportação Excel funciona."""
    response = client.get("/api/v1/relatorio/exportar?formato=xlsx")
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

def test_api_report_pdf():
    """Verifica se o endpoint de exportação PDF funciona."""
    response = client.get("/api/v1/relatorio/exportar?formato=pdf")
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"

def test_api_stats_categoria():
    """Verifica o formato das estatísticas por categoria."""
    response = client.get("/api/v1/bem/stats/categoria")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    if len(data) > 0:
        assert len(data[0]) == 2 # [nome, total]

def test_api_stats_status():
    """Verifica o formato das estatísticas por status."""
    response = client.get("/api/v1/bem/stats/status")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    if len(data) > 0:
        assert len(data[0]) == 2 # [status, total]
