"""Depreciação linear, valor contábil e alerta de garantia."""
from datetime import date
from unittest.mock import MagicMock, patch

import pytest
from pydantic import ValidationError

from modules.bem import depreciacao
from modules.bem.schemas import BemCreate, BemUpdate
from modules.bem.service import BemService


def test_meses_completos_entre_entrada_e_hoje():
    assert depreciacao.meses_decorridos(date(2024, 1, 15), date(2024, 3, 14)) == 1
    assert depreciacao.meses_decorridos(date(2024, 1, 15), date(2024, 3, 15)) == 2
    assert depreciacao.meses_decorridos(date(2024, 5, 1), date(2024, 1, 1)) == 0


def test_depreciacao_linear_com_residual():
    r = depreciacao.calcular(1200.0, 200.0, 10, date(2024, 1, 1), date(2024, 4, 1))
    assert r == {"depreciacao_mensal": 100.0, "depreciacao_acumulada": 300.0, "valor_contabil": 900.0}


def test_valor_contabil_nao_fica_abaixo_do_residual():
    r = depreciacao.calcular(1200.0, 200.0, 10, date(2020, 1, 1), date(2030, 1, 1))
    assert r["valor_contabil"] == 200.0
    assert r["depreciacao_acumulada"] == 1000.0  # só até a vida útil


def test_sem_vida_util_ou_sem_data_nao_deprecia():
    r = depreciacao.calcular(500.0, 0, None, date(2024, 1, 1), date(2025, 1, 1))
    assert r == {"depreciacao_mensal": None, "depreciacao_acumulada": None, "valor_contabil": 500.0}


def test_sem_valor_de_aquisicao_devolve_vazio():
    assert depreciacao.calcular(None, 0, 12, date(2024, 1, 1), date(2025, 1, 1))["valor_contabil"] is None


def test_vida_util_deve_ser_positiva():
    with pytest.raises(ValidationError):
        BemCreate(nome="X", codigo_tombamento="INF-001-0", valor=10, status="Disponível",
                  id_categoria=1, estado_conservacao="novo", vida_util_meses=0)
    with pytest.raises(ValidationError):
        BemUpdate(valor_residual=-1)


def test_ficha_do_bem_recebe_valor_contabil():
    from modules.bem.schemas import BemDetalhes
    bem = BemDetalhes(id=1, nome="X", tipo="E", codigo_tombamento="INF-001-0", valor=1200.0, status="Disponível",
                      ativo=True, valor_aquisicao=1200.0, valor_residual=200.0, vida_util_meses=10,
                      data_entrada=date(2024, 1, 1))
    with patch("modules.bem.service.BemRepository") as repo_cls:
        repo_cls.return_value.get_detalhes.return_value = bem
        ficha = BemService().get_bem_detalhes(1)
    assert ficha.valor_contabil is not None and ficha.valor_contabil >= 200.0


def test_alerta_de_garantia_consulta_com_dias_informados():
    repo = MagicMock()
    repo.garantias_a_vencer.return_value = [{"id": 1, "vencida": False}]
    with patch("modules.bem.service.BemRepository", return_value=repo):
        assert BemService().alertas_garantia(30) == [{"id": 1, "vencida": False}]
    repo.garantias_a_vencer.assert_called_once_with(30)
