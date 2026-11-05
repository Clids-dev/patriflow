"""W05: validação e guarda de fotos. Repositório simulado, pasta temporária."""
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from api.v1.auth import action_for, current_user
from core import config
from modules.foto import router as foto_router_module
from modules.foto.service import FotoService, detectar_formato

JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 100
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 100
WEBP = b"RIFF" + b"\x00\x00\x00\x00" + b"WEBP" + b"\x00" * 100
USUARIO = {"id": 7, "perfil": "agente_campo", "setor_id": 1}


@pytest.fixture
def pasta(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "FOTOS_DIR", str(tmp_path))
    return tmp_path


def _repo(retorno=None):
    repo = MagicMock()
    repo.inserir.return_value = retorno or {"id": 1, "registro_tipo": "conferencia", "registro_id": 3,
                                            "content_type": "image/jpeg", "tamanho_bytes": 104, "enviado_por": 7,
                                            "enviado_em": "2026-11-05T10:00:00", "url": "/api/v1/fotos/1"}
    return repo


@pytest.mark.parametrize("dados, esperado", [(JPEG, "image/jpeg"), (PNG, "image/png"), (WEBP, "image/webp"),
                                             (b"GIF89a...", None), (b"", None), (b"%PDF-1.4", None)])
def test_detecta_formato_pelo_conteudo(dados, esperado):
    assert detectar_formato(dados) == esperado


def test_arquivo_vazio_e_recusado(pasta):
    with pytest.raises(HTTPException) as exc:
        FotoService(_repo()).registrar(b"", "conferencia", 3, USUARIO)
    assert exc.value.status_code == 400


def test_foto_grande_demais_e_recusada(pasta, monkeypatch):
    monkeypatch.setattr(config, "FOTO_MAX_BYTES", 50)
    with pytest.raises(HTTPException) as exc:
        FotoService(_repo()).registrar(JPEG, "conferencia", 3, USUARIO)
    assert exc.value.status_code == 413
    assert "limite" in exc.value.detail.lower()
    assert list(pasta.iterdir()) == []


def test_formato_nao_suportado_e_recusado(pasta):
    with pytest.raises(HTTPException) as exc:
        FotoService(_repo()).registrar(b"GIF89a" + b"\x00" * 20, "conferencia", 3, USUARIO)
    assert exc.value.status_code == 415
    assert "JPEG, PNG ou WebP" in exc.value.detail


def test_grava_arquivo_com_nome_do_servidor(pasta):
    repo = _repo()
    FotoService(repo).registrar(PNG, "conferencia", 3, USUARIO)
    arquivos = list(pasta.iterdir())
    assert len(arquivos) == 1 and arquivos[0].suffix == ".png"
    args = repo.inserir.call_args.args
    assert args[0] == "conferencia" and args[1] == 3
    assert args[2] == arquivos[0].name  # nome gerado pelo servidor, não o do cliente
    assert args[3] == "image/png" and args[5] == 7


def test_remove_arquivo_se_o_banco_falhar(pasta):
    repo = _repo()
    repo.inserir.side_effect = RuntimeError("banco indisponível")
    with pytest.raises(RuntimeError):
        FotoService(repo).registrar(JPEG, "conferencia", 3, USUARIO)
    assert list(pasta.iterdir()) == []


def _app():
    app = FastAPI()
    app.include_router(foto_router_module.router, prefix="/api/v1")
    app.dependency_overrides[current_user] = lambda: USUARIO
    return app


def test_endpoint_envia_foto(pasta, monkeypatch):
    repo = _repo()
    monkeypatch.setattr(foto_router_module, "FotoService", lambda: FotoService(repo))
    client = TestClient(_app())
    r = client.post("/api/v1/fotos/", data={"registro_tipo": "conferencia", "registro_id": "3"},
                    files={"arquivo": ("foto.jpg", JPEG, "image/jpeg")})
    assert r.status_code == 201
    assert r.json()["url"] == "/api/v1/fotos/1"


def test_endpoint_recusa_tipo_de_registro_invalido(pasta):
    client = TestClient(_app())
    r = client.post("/api/v1/fotos/", data={"registro_tipo": "qualquer", "registro_id": "3"},
                    files={"arquivo": ("foto.jpg", JPEG, "image/jpeg")})
    assert r.status_code == 422


def test_endpoint_nao_aceita_alteracao_nem_exclusao(pasta):
    client = TestClient(_app())
    assert client.put("/api/v1/fotos/1").status_code in (404, 405)
    assert client.delete("/api/v1/fotos/1").status_code in (404, 405)


def test_permissoes_de_fotos():
    assert action_for("POST", "fotos/") == "fotos:create"
    assert action_for("GET", "fotos/9") == "fotos:read"


def test_auditor_so_consulta_fotos():
    from api.v1.auth import ROLE_PERMISSIONS
    permissoes = ROLE_PERMISSIONS["auditor"]
    assert "fotos:read" in permissoes
    assert "fotos:create" not in permissoes and "fotos:*" not in permissoes
