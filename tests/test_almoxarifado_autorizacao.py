"""Regras de almoxarifado e autorização de movimentações (W04)."""
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from modules.bem.schemas import Bem
from modules.movimentacao.schemas import Movimentacao, MovimentacaoCreate
from modules.movimentacao import service as mov_service
from modules.movimentacao.service import MovimentacaoService


@pytest.fixture(autouse=True)
def sem_emprestimo_aberto(monkeypatch):
    """Teste unitário: nenhum bem emprestado, sem consultar o banco."""
    repo = MagicMock()
    repo.existe_aberto.return_value = False
    monkeypatch.setattr("modules.movimentacao.service.EmprestimoRepository", lambda: repo)
    return repo


@pytest.fixture(autouse=True)
def foto_do_recebimento(monkeypatch):
    # Autorização exige foto do recebimento (W06); estes testes cobrem outras regras, então a foto existe.
    repo = MagicMock()
    repo.contar.return_value = 1
    monkeypatch.setattr(mov_service, "FotoRepository", lambda: repo)

ALMOX = 3
ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}
RESP_TI = {"id": 10, "perfil": "responsavel_setor", "setor_id": 1}
RESP_ALMOX = {"id": 11, "perfil": "responsavel_setor", "setor_id": ALMOX}
AGENTE_SEM_SETOR = {"id": 12, "perfil": "agente_campo", "setor_id": None}


def _bem():
    return Bem(id=1, nome="Notebook", tipo="Notebook", codigo_tombamento="NTB-001-7",
               valor=1000.0, status="Em Uso", ativo=True, id_categoria=1)


def _mov(status="pendente", origem=ALMOX, destino=1, solicitante=10, bem_id=1):
    return Movimentacao(id=7, bem_id=bem_id, setor_origem_id=origem, setor_destino_id=destino,
                        data=datetime.now(), ativo=True, status=status, solicitante_id=solicitante)


@pytest.fixture
def repos():
    """Substitui os repositórios usados pelo serviço e devolve os mocks."""
    with patch("modules.movimentacao.service.BemRepository") as bem_repo, \
         patch("modules.movimentacao.service.SetorRepository") as setor_repo, \
         patch("modules.movimentacao.service.MovimentacaoRepository") as mov_repo:
        bem_repo.return_value.get_by_id.return_value = _bem()
        setor_repo.return_value.get_id.return_value = MagicMock()
        setor_repo.return_value.get_almoxarifado.return_value = MagicMock(id=ALMOX)
        mov_repo.return_value.get_localizacao_atual.return_value = ALMOX
        mov_repo.return_value.existe_aberta.return_value = False
        yield {"bem": bem_repo, "setor": setor_repo, "mov": mov_repo}


def _create(origem=None, destino=1):
    return MovimentacaoCreate(bem_id=1, setor_origem_id=origem, setor_destino_id=destino, justificativa="Motivo informado")


# --- Solicitação de movimentação ---------------------------------------------

def test_responsavel_solicita_saida_do_almoxarifado_para_o_proprio_setor(repos):
    service = MovimentacaoService()
    service.add_movimentacao(_create(origem=ALMOX, destino=1), RESP_TI)

    save = repos["mov"].return_value.save
    args = save.call_args.args
    assert args[1] == ALMOX          # origem = local atual
    assert args[2] == "pendente"     # aguarda autorização
    assert args[3] == RESP_TI["id"]  # solicitante


def test_solicitacao_entre_setores_quaisquer_passa_sem_o_almoxarifado(repos):
    # Regra nova: origem e destino livres. O bem está no RH e o TI solicita para si.
    repos["mov"].return_value.get_localizacao_atual.return_value = 4
    MovimentacaoService().add_movimentacao(_create(destino=1), RESP_TI)
    args = repos["mov"].return_value.save.call_args.args
    assert args[1] == 4                      # origem = RH
    assert args[2] == "pendente"             # aguarda a liberação do RH
    assert repos["mov"].return_value.save.call_args.kwargs["fluxo"] == "duplo"


def test_responsavel_nao_pode_solicitar_para_outro_setor(repos):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_create(origem=ALMOX, destino=4), RESP_TI)
    assert exc.value.status_code == 403


def test_usuario_sem_setor_nao_solicita(repos):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_create(origem=ALMOX, destino=1), AGENTE_SEM_SETOR)
    assert exc.value.status_code == 403


def test_admin_movimenta_diretamente_como_aprovada(repos):
    MovimentacaoService().add_movimentacao(_create(origem=ALMOX, destino=4), ADMIN)
    args = repos["mov"].return_value.save.call_args.args
    assert args[2] == "aprovada"


def test_origem_informada_precisa_ser_o_local_atual(repos):
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_create(origem=4, destino=1), ADMIN)
    assert exc.value.status_code == 400


def test_bem_sem_localizacao_so_entra_pelo_almoxarifado(repos):
    repos["mov"].return_value.get_localizacao_atual.return_value = None
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_create(destino=1), ADMIN)
    assert exc.value.status_code == 400


def test_entrada_sem_localizacao_por_nao_admin_e_bloqueada(repos):
    repos["mov"].return_value.get_localizacao_atual.return_value = None
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_create(destino=ALMOX), RESP_TI)
    assert exc.value.status_code == 403


def test_sem_almoxarifado_cadastrado_bloqueia_movimentacao(repos):
    repos["setor"].return_value.get_almoxarifado.return_value = None
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().add_movimentacao(_create(origem=ALMOX, destino=1), ADMIN)
    assert exc.value.status_code == 400


# --- Decisão da solicitação ---------------------------------------------------

def test_responsavel_do_almoxarifado_aprova(repos):
    repos["mov"].return_value.get_id.return_value = _mov()
    repos["mov"].return_value.decidir.return_value = ("ok", _mov(status="aprovada"))

    result = MovimentacaoService().decidir_movimentacao(7, RESP_ALMOX, aprovar=True)

    assert result.status == "aprovada"
    args = repos["mov"].return_value.decidir.call_args.args
    assert args[1] == _mov().bem_id and args[2] == ALMOX and args[3] is True


def test_responsavel_de_outro_setor_nao_decide(repos):
    repos["mov"].return_value.get_id.return_value = _mov()
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_TI, aprovar=True)
    assert exc.value.status_code == 403


def test_admin_pode_decidir(repos):
    repos["mov"].return_value.get_id.return_value = _mov()
    repos["mov"].return_value.decidir.return_value = ("ok", _mov(status="recusada"))
    result = MovimentacaoService().decidir_movimentacao(7, ADMIN, aprovar=False, motivo="Bem já alocado")
    assert result.status == "recusada"


def test_solicitante_nao_aprova_a_propria_solicitacao(repos):
    repos["mov"].return_value.get_id.return_value = _mov(solicitante=RESP_ALMOX["id"])
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_ALMOX, aprovar=True)
    assert exc.value.status_code == 403


def test_movimentacao_ja_decidida_nao_muda(repos):
    repos["mov"].return_value.get_id.return_value = _mov(status="aprovada")
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_ALMOX, aprovar=True)
    assert exc.value.status_code == 409


def test_aprovacao_falha_se_bem_mudou_de_local(repos):
    repos["mov"].return_value.get_id.return_value = _mov(origem=ALMOX)
    repos["mov"].return_value.decidir.return_value = ("local_mudou", None)
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_ALMOX, aprovar=True)
    assert exc.value.status_code == 409


def test_aprovacao_falha_se_bem_foi_baixado(repos):
    repos["mov"].return_value.get_id.return_value = _mov()
    repos["mov"].return_value.decidir.return_value = ("bem_inativo", None)
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_ALMOX, aprovar=True)
    assert exc.value.status_code == 400


def test_decisao_concorrente_retorna_conflito(repos):
    repos["mov"].return_value.get_id.return_value = _mov()
    repos["mov"].return_value.decidir.return_value = ("ja_decidida", None)
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, RESP_ALMOX, aprovar=True)
    assert exc.value.status_code == 409
