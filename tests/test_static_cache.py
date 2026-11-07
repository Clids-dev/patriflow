"""Arquivos estáticos devem ser revalidados pelo navegador, para não rodar JS ou CSS antigos."""
from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_estaticos_pedem_revalidacao():
    resposta = client.get("/static/js/utils.js")
    assert resposta.status_code == 200
    assert resposta.headers["cache-control"] == "no-cache"
    assert resposta.headers.get("etag")


def test_estatico_sem_mudanca_responde_304():
    etag = client.get("/static/js/utils.js").headers["etag"]
    resposta = client.get("/static/js/utils.js", headers={"If-None-Match": etag})
    assert resposta.status_code == 304
