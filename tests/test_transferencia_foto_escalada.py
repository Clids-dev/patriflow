"""W06: autorizar exige foto do recebimento; transferências sem resposta no prazo são escaladas."""
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from modules.movimentacao import service as mov_service
from modules.movimentacao.repository import _detailed
from modules.movimentacao.service import MovimentacaoService


@pytest.fixture(autouse=True)
def sem_inventario_aberto(monkeypatch):
    """Teste unitário: nenhum setor em inventário, sem consultar o banco."""
    monkeypatch.setattr("modules.movimentacao.service.setores_em_inventario", lambda ids: [])


ALMOX = MagicMock(id=3)
PATRIMONIO = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}


def _mov():
    return MagicMock(status="pendente", bem_id=9, setor_origem_id=3, solicitante_id=12, fluxo="simples")


def test_autorizar_sem_foto_e_bloqueado():
    repo = MagicMock()
    repo.get_id.return_value = _mov()
    foto = MagicMock()
    foto.contar.return_value = 0
    with patch.object(mov_service, "MovimentacaoRepository", return_value=repo), \
         patch.object(mov_service, "FotoRepository", return_value=foto), \
         patch.object(mov_service, "SetorRepository") as setores:
        setores.return_value.get_almoxarifado.return_value = ALMOX
        with pytest.raises(HTTPException) as exc:
            MovimentacaoService().decidir_movimentacao(7, PATRIMONIO, aprovar=True)
    assert exc.value.status_code == 400 and "foto" in exc.value.detail.lower()
    repo.decidir.assert_not_called()


def test_foto_da_transferencia_e_consultada_pelo_id_da_movimentacao():
    repo = MagicMock()
    repo.get_id.return_value = _mov()
    repo.decidir.return_value = ("ok", MagicMock())
    foto = MagicMock()
    foto.contar.return_value = 1
    with patch.object(mov_service, "MovimentacaoRepository", return_value=repo), \
         patch.object(mov_service, "FotoRepository", return_value=foto), \
         patch.object(mov_service, "SetorRepository") as setores:
        setores.return_value.get_almoxarifado.return_value = ALMOX
        MovimentacaoService().decidir_movimentacao(7, PATRIMONIO, aprovar=True)
    foto.contar.assert_called_once_with("aceite_transferencia", 7)


def _linha(escalada):
    return (1, "Cadeira", "MOB-001-0", None, "Financeiro", datetime(2026, 11, 1), None, True, "pendente", "Ana", escalada)


def test_pendente_mostra_se_esta_escalada():
    assert _detailed(_linha(True)).escalada is True
    assert _detailed(_linha(False)).escalada is False


def test_prazo_de_escalada_e_configuravel(monkeypatch):
    from core import config
    assert isinstance(config.PRAZO_TRANSFERENCIA_DIAS, int) and config.PRAZO_TRANSFERENCIA_DIAS >= 1


def test_listagem_usa_o_prazo_configurado(monkeypatch):
    from core import config
    monkeypatch.setattr(config, "PRAZO_TRANSFERENCIA_DIAS", 5)
    repo = MagicMock()
    repo.get_em_andamento.return_value = []
    with patch.object(mov_service, "MovimentacaoRepository", return_value=repo), \
         patch.object(mov_service, "SetorRepository"):
        MovimentacaoService().listar_pendentes(PATRIMONIO)
    repo.get_em_andamento.assert_called_once_with(5)
