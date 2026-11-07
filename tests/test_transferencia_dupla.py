"""Transferência com dupla confirmação: origem e destino livres.

- Qualquer colaborador (agente ou responsável) solicita o bem para o próprio setor.
- O responsável do setor de origem libera (ou recusa) o bem.
- O responsável do setor de destino confirma o recebimento, com foto.
- O almoxarifado acompanha todas as transferências e pode intervir com motivo.
"""
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from modules.movimentacao import service as mov_service
from modules.movimentacao.schemas import MovimentacaoCreate
from modules.movimentacao.service import MovimentacaoService


@pytest.fixture(autouse=True)
def sem_emprestimo_aberto(monkeypatch):
    """Teste unitário: nenhum bem emprestado, sem consultar o banco."""
    repo = MagicMock()
    repo.existe_aberto.return_value = False
    monkeypatch.setattr("modules.movimentacao.service.EmprestimoRepository", lambda: repo)
    monkeypatch.setattr("modules.movimentacao.service.setores_em_inventario", lambda ids: [])
    return repo


ALMOX = 3
RH = 4
TI = 1
ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}
RESP_RH = {"id": 20, "perfil": "responsavel_setor", "setor_id": RH}
RESP_TI = {"id": 10, "perfil": "responsavel_setor", "setor_id": TI}
RESP_ALMOX = {"id": 11, "perfil": "responsavel_setor", "setor_id": ALMOX}
AGENTE_TI = {"id": 12, "perfil": "agente_campo", "setor_id": TI}
AUDITOR = {"id": 13, "perfil": "auditor", "setor_id": TI}


def _mov(status="pendente", origem=RH, destino=TI, solicitante=12):
    return MagicMock(id=7, status=status, bem_id=9, setor_origem_id=origem, setor_destino_id=destino,
                     solicitante_id=solicitante, fluxo="duplo")


@pytest.fixture
def repos():
    with patch.object(mov_service, "MovimentacaoRepository") as mov, \
         patch.object(mov_service, "SetorRepository") as setor, \
         patch.object(mov_service, "BemRepository") as bem, \
         patch.object(mov_service, "FotoRepository") as foto:
        setor.return_value.get_almoxarifado.return_value = MagicMock(id=ALMOX)
        setor.return_value.get_id.return_value = MagicMock()
        bem.return_value.get_by_id.return_value = MagicMock(ativo=True, status="Disponível")
        mov.return_value.get_localizacao_atual.return_value = RH
        mov.return_value.existe_aberta.return_value = False
        mov.return_value.get_id.return_value = _mov()
        mov.return_value.transicionar.return_value = ("ok", MagicMock())
        foto.return_value.contar.return_value = 1
        yield {"mov": mov.return_value, "foto": foto.return_value}


def _pedido(destino=TI):
    return MovimentacaoCreate(bem_id=9, setor_destino_id=destino, justificativa="Precisamos para o projeto")


# --- Solicitação --------------------------------------------------------------

def test_colaborador_solicita_bem_de_outro_setor_para_o_proprio_setor(repos):
    MovimentacaoService().add_movimentacao(_pedido(TI), AGENTE_TI)
    call = repos["mov"].save.call_args
    assert call.args[1] == RH and call.args[2] == "pendente"
    assert call.kwargs["fluxo"] == "duplo"


def test_solicitacao_para_outro_setor_e_bloqueada(repos):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_pedido(destino=ALMOX), AGENTE_TI)
    assert exc.value.status_code == 403


def test_auditor_nao_solicita(repos):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_pedido(TI), AUDITOR)
    assert exc.value.status_code == 403


def test_bem_ja_em_transferencia_aberta_nao_pode_ser_solicitado_de_novo(repos):
    repos["mov"].existe_aberta.return_value = True
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_pedido(TI), AGENTE_TI)
    assert exc.value.status_code == 409


def test_bem_ja_no_setor_do_solicitante_e_bloqueado(repos):
    repos["mov"].get_localizacao_atual.return_value = TI
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_pedido(TI), AGENTE_TI)
    assert exc.value.status_code == 400


def test_solicitacao_sem_motivo_e_bloqueada(repos):
    pedido = MovimentacaoCreate(bem_id=9, setor_destino_id=TI, justificativa="  ")
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(pedido, AGENTE_TI)
    assert exc.value.status_code == 400


# --- Etapa 1: liberação pelo setor de origem ----------------------------------

def test_responsavel_da_origem_libera_o_bem(repos):
    MovimentacaoService().decidir_movimentacao(7, RESP_RH, aprovar=True)
    args = repos["mov"].transicionar.call_args.args
    assert args[3] == ("pendente",) and args[4] == "liberada"


def test_responsavel_do_destino_nao_libera_antes_da_origem(repos):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_TI, aprovar=True)
    assert exc.value.status_code == 403


def test_recusa_da_origem_exige_motivo(repos):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_RH, aprovar=False)
    assert exc.value.status_code == 400


def test_recusa_da_origem_grava_o_motivo(repos):
    MovimentacaoService().decidir_movimentacao(7, RESP_RH, aprovar=False, motivo="Bem em uso no laboratório")
    args = repos["mov"].transicionar.call_args.args
    assert args[4] == "recusada" and args[7] == "Bem em uso no laboratório"


# --- Etapa 2: confirmação de recebimento pelo setor de destino ----------------

def _na_etapa_de_recebimento(repos):
    repos["mov"].get_id.return_value = _mov(status="liberada", origem=RH, destino=TI)


def test_responsavel_do_destino_confirma_com_foto(repos):
    _na_etapa_de_recebimento(repos)
    MovimentacaoService().decidir_movimentacao(7, RESP_TI, aprovar=True)
    args = repos["mov"].transicionar.call_args.args
    assert args[3] == ("liberada",) and args[4] == "aprovada"
    assert repos["mov"].transicionar.call_args.kwargs["verificar_local"] is True


def test_confirmacao_sem_foto_e_bloqueada(repos):
    _na_etapa_de_recebimento(repos)
    repos["foto"].contar.return_value = 0
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_TI, aprovar=True)
    assert exc.value.status_code == 400 and "foto" in exc.value.detail.lower()
    repos["mov"].transicionar.assert_not_called()


def test_responsavel_da_origem_nao_confirma_o_recebimento(repos):
    _na_etapa_de_recebimento(repos)
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_RH, aprovar=True)
    assert exc.value.status_code == 403


def test_recusa_do_destino_exige_motivo(repos):
    _na_etapa_de_recebimento(repos)
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_TI, aprovar=False)
    assert exc.value.status_code == 400


def test_solicitante_nao_decide_a_propria_solicitacao(repos):
    repos["mov"].get_id.return_value = _mov(solicitante=RESP_TI["id"])
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_TI, aprovar=True)
    assert exc.value.status_code == 403


# --- Intervenção do almoxarifado ----------------------------------------------

def test_almoxarifado_interv_com_motivo(repos):
    MovimentacaoService().intervir(7, RESP_ALMOX, "Transferência sem justificativa válida")
    args = repos["mov"].transicionar.call_args.args
    assert args[4] == "cancelada" and args[3] == ("pendente", "liberada")


def test_intervencao_exige_motivo(repos):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().intervir(7, RESP_ALMOX, "  ")
    assert exc.value.status_code == 400


def test_setor_comum_nao_interv(repos):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().intervir(7, AGENTE_TI, "Motivo qualquer")
    assert exc.value.status_code == 403


def test_intervencao_em_transferencia_ja_decidida_e_bloqueada(repos):
    repos["mov"].get_id.return_value = _mov(status="aprovada")
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().intervir(7, ADMIN, "Motivo qualquer")
    assert exc.value.status_code == 409


# --- Quem vê o que -----------------------------------------------------------

def test_fila_de_decisao_mostra_liberar_para_a_origem_e_receber_para_o_destino(repos):
    itens = [
        MagicMock(id=1, status="pendente", fluxo="duplo", setor_origem_id=RH, setor_destino_id=TI, escalada=False),
        MagicMock(id=2, status="liberada", fluxo="duplo", setor_origem_id=RH, setor_destino_id=TI, escalada=False),
    ]
    repos["mov"].get_em_andamento.return_value = itens
    fila_rh = MovimentacaoService().listar_pendentes(RESP_RH)
    fila_ti = MovimentacaoService().listar_pendentes(RESP_TI)
    assert [m.id for m in fila_rh] == [1]          # RH libera a pendente
    assert [m.id for m in fila_ti] == [2]          # TI recebe a liberada
    assert fila_rh[0].etapa == "liberar" and fila_ti[0].etapa == "receber"


def test_acompanhamento_e_so_do_almoxarifado_e_do_patrimonio(repos):
    repos["mov"].get_em_andamento.return_value = []
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().acompanhamento(AGENTE_TI)
    assert exc.value.status_code == 403
    MovimentacaoService().acompanhamento(RESP_ALMOX)
    MovimentacaoService().acompanhamento(ADMIN)


def test_bem_emprestado_nao_pode_ser_transferido(repos, sem_emprestimo_aberto):
    sem_emprestimo_aberto.existe_aberto.return_value = True
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_pedido(TI), AGENTE_TI)
    assert exc.value.status_code == 409 and "emprestado" in exc.value.detail
    repos["mov"].save.assert_not_called()
