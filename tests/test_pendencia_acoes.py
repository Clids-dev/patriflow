"""Ações guiadas da caixa de pendências (D6), num banco real.

Dados iniciais (schema.sql): bens 1 e 2 no TI (setor 1); setor 2 = Financeiro.
"""
from datetime import date

import pytest
from fastapi import HTTPException

from modules.bem import historico
from modules.inventario.schemas import InventarioCreate
from modules.inventario.service import InventarioService
from modules.pendencia.schemas import Resolucao
from modules.pendencia.service import PendenciaService

pytestmark = pytest.mark.integracao

TI, FIN = 1, 2
ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}


@pytest.fixture
def nao_localizado(banco):
    """Inventário do TI fechado sem ler nada: bens 1 e 2 viram pendências de não localizado."""
    inv = InventarioService().abrir(InventarioCreate(descricao="Inventário TI", inicio=date.today(), fim=date.today(),
                                                     setor_ids=[TI]), ADMIN)
    InventarioService().marcar_faltantes(inv.id, TI, ADMIN)
    InventarioService().fechar(inv.id, ADMIN)
    return next(p for p in PendenciaService().listar("abertas") if p.bem_id == 1)


def _erro(funcao, *args):
    with pytest.raises(HTTPException) as exc:
        funcao(*args)
    return exc.value


def test_acao_que_nao_e_do_tipo_e_recusada(nao_localizado):
    erro = _erro(PendenciaService().resolver, nao_localizado.id, Resolucao(acao="aplicar", resolucao="Teste"), ADMIN)
    assert erro.status_code == 400


def test_encontrado_registra_onde(nao_localizado):
    r = PendenciaService().resolver(nao_localizado.id, Resolucao(acao="encontrado", resolucao="Estava na sala de reuniões",
                                                                setor_id=FIN), ADMIN)
    assert r.resolucao.startswith("Foi encontrado: Encontrado em Financeiro.") and r.referencia_id == FIN


def test_baixa_por_extravio_exige_documento_e_baixa_o_bem(nao_localizado, sql):
    sem_doc = _erro(PendenciaService().resolver, nao_localizado.id,
                    Resolucao(acao="baixa_extravio", resolucao="Não apareceu"), ADMIN)
    assert sem_doc.status_code == 400 and PendenciaService().repo.buscar(nao_localizado.id).resolvida_em is None
    r = PendenciaService().resolver(nao_localizado.id, Resolucao(acao="baixa_extravio", resolucao="Não apareceu",
                                                                documento="BO 1234/2026"), ADMIN)
    assert r.acao == "baixa_extravio" and r.referencia_id
    motivo, documento = sql("SELECT motivo, documento_ref FROM baixas WHERE id = %s", (r.referencia_id,), um=True)
    assert (motivo, documento) == ("extravio", "BO 1234/2026")


def test_resolucao_aparece_na_linha_do_tempo(nao_localizado):
    PendenciaService().resolver(nao_localizado.id, Resolucao(acao="aguardar", resolucao="Próxima contagem"), ADMIN)
    evento = historico.linha_do_tempo(1)[0]
    assert evento["tipo"] == "pendencia_resolvida" and "Próxima contagem" in evento["detalhe"]
