"""Fila de escaladas do setor de patrimônio (W06)."""
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from modules.movimentacao import service as mov_service
from modules.movimentacao.schemas import MovimentacaoDetailed
from modules.movimentacao.service import MovimentacaoService


def _item(i, escalada):
    return MovimentacaoDetailed(id=i, bem_nome="X", codigo_tombamento="MOB-001-0", setor_destino_nome="Y",
                                data_movimentacao=datetime(2026, 10, 1), ativo=True, status="pendente", escalada=escalada)


def test_fila_mostra_so_as_escaladas_para_o_patrimonio():
    repo = MagicMock()
    repo.get_pendentes.return_value = [_item(1, True), _item(2, False), _item(3, True)]
    with patch.object(mov_service, "MovimentacaoRepository", return_value=repo):
        fila = MovimentacaoService().listar_escaladas({"id": 1, "perfil": "setor_patrimonio"})
    assert [m.id for m in fila] == [1, 3]


@pytest.mark.parametrize("perfil", ["responsavel_setor", "agente_campo", "auditor"])
def test_outros_perfis_nao_veem_a_fila(perfil):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().listar_escaladas({"id": 2, "perfil": perfil})
    assert exc.value.status_code == 403
