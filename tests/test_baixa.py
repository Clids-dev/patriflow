"""REQ-EX-01: baixa com motivo e alçada por valor; quem pediu não aprova a própria baixa."""
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

from core import config
from modules.bem import baixa
from modules.bem.schemas import BaixaCreate, Bem

PATRIMONIO = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}
OUTRO = {"id": 2, "perfil": "setor_patrimonio", "setor_id": None}
DADOS = BaixaCreate(motivo="inservivel", justificativa="Danificado sem conserto", documento_ref="LAUDO-12")


def _bem(valor):
    return Bem(id=8, nome="Switch", tipo="E", codigo_tombamento="EQP-008-1", valor=valor, status="Disponível",
               ativo=True, id_categoria=1, valor_aquisicao=valor)


def test_motivo_fora_da_lista_e_recusado():
    with pytest.raises(ValidationError):
        BaixaCreate(motivo="sumiu", justificativa="abc", documento_ref="BO-1")


def test_documento_obrigatorio():
    with pytest.raises(ValidationError):
        BaixaCreate(motivo="venda", justificativa="abc", documento_ref="")


def test_abaixo_da_alcada_baixa_na_hora(monkeypatch):
    monkeypatch.setattr(config, "ALCADA_BAIXA_VALOR", 5000.0)
    with patch.object(baixa, "BemRepository") as repo, patch.object(baixa, "DataBase") as db, \
         patch.object(baixa, "registrar_acao") as audit:
        repo.return_value.get_by_id.return_value = _bem(1200.0)
        db.return_value.commit.return_value = (10,)
        res = baixa.solicitar(8, DADOS, PATRIMONIO)
    assert res["status"] == "aprovada"
    repo.return_value.desativar.assert_called_once_with(8)
    audit.assert_called_once()


def test_acima_da_alcada_fica_pendente(monkeypatch):
    monkeypatch.setattr(config, "ALCADA_BAIXA_VALOR", 5000.0)
    with patch.object(baixa, "BemRepository") as repo, patch.object(baixa, "DataBase") as db:
        repo.return_value.get_by_id.return_value = _bem(9000.0)
        db.return_value.commit.return_value = (11,)
        res = baixa.solicitar(8, DADOS, PATRIMONIO)
    assert res["status"] == "pendente"
    repo.return_value.desativar.assert_not_called()


def test_outro_perfil_nao_da_baixa():
    with pytest.raises(HTTPException) as exc:
        baixa.solicitar(8, DADOS, {"id": 3, "perfil": "agente_campo", "setor_id": None})
    assert exc.value.status_code == 403


def test_quem_pediu_nao_aprova_a_propria_baixa():
    with patch.object(baixa, "DataBase") as db:
        db.return_value.execute.return_value = [(8, "venda", "BO-1", 1, "pendente")]
        with pytest.raises(HTTPException) as exc:
            baixa.decidir(11, True, None, PATRIMONIO)
    assert exc.value.status_code == 403


def test_outro_servidor_aprova_e_a_baixa_acontece():
    with patch.object(baixa, "DataBase") as db, patch.object(baixa, "BemRepository") as repo, \
         patch.object(baixa, "registrar_acao"):
        db.return_value.execute.return_value = [(8, "venda", "BO-1", 1, "pendente")]
        res = baixa.decidir(11, True, None, OUTRO)
    assert res["status"] == "aprovada"
    repo.return_value.desativar.assert_called_once_with(8)


def test_recusa_exige_motivo():
    with patch.object(baixa, "DataBase") as db:
        db.return_value.execute.return_value = [(8, "venda", "BO-1", 1, "pendente")]
        with pytest.raises(HTTPException) as exc:
            baixa.decidir(11, False, "  ", OUTRO)
    assert exc.value.status_code == 400
