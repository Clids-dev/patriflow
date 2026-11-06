"""Termo de responsabilidade: conteúdo, escape e permissões."""
from unittest.mock import patch

import pytest
from fastapi import HTTPException

from api.v1.auth import ROLE_PERMISSIONS
from modules.termo import service as termo


def _db(resp, bens):
    db = type("DB", (), {})()
    def execute(sql, params=None, many=True):
        return resp if "FROM responsaveis" in sql else bens
    db.execute = execute
    return db


def test_termo_lista_bens_e_totais():
    bens = [("INF-001-0", "Notebook", "bom", 1500.0, "Financeiro"), ("INF-002-8", "Monitor", "novo", 800.0, "Financeiro")]
    with patch.object(termo, "DataBase", lambda: _db([(1, "Ana", "Gerente")], bens)):
        html = termo.termo_html(1)
    assert "INF-001-0" in html and "INF-002-8" in html
    assert "2 itens" in html and "2.300,00" in html
    assert "Ana" in html and "Gerente" in html


def test_termo_escapa_nomes():
    with patch.object(termo, "DataBase", lambda: _db([(1, "<img onerror=x>", "Chefe")], [])):
        html = termo.termo_html(1)
    assert "<img onerror" not in html and "&lt;img onerror" in html


def test_termo_responsavel_inexistente():
    with patch.object(termo, "DataBase", lambda: _db([], [])):
        with pytest.raises(HTTPException) as exc:
            termo.termo_html(99)
    assert exc.value.status_code == 404


def test_permissoes_do_termo():
    assert "termos:*" in ROLE_PERMISSIONS["setor_patrimonio"]
    assert "termos:read" in ROLE_PERMISSIONS["responsavel_setor"]
    assert "termos:read" not in ROLE_PERMISSIONS["agente_campo"]
