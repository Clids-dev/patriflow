"""W06: solicitação e recusa de transferência exigem motivo; quem pediu vê o resultado."""
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from modules.movimentacao import service as mov_service
from modules.movimentacao.schemas import DecisaoRecusa, MovimentacaoCreate
from modules.movimentacao.service import MovimentacaoService


@pytest.fixture(autouse=True)
def sem_emprestimo_aberto(monkeypatch):
    """Teste unitário: nenhum bem emprestado, sem consultar o banco."""
    repo = MagicMock()
    repo.existe_aberto.return_value = False
    monkeypatch.setattr("modules.movimentacao.service.EmprestimoRepository", lambda: repo)
    monkeypatch.setattr("modules.movimentacao.service.setores_em_inventario", lambda ids: [])
    return repo


RESPONSAVEL = {"id": 12, "perfil": "responsavel_setor", "setor_id": 5}
ALMOX = MagicMock(id=3)


def _servico(atual=3):
    repo = MagicMock()
    repo.get_localizacao_atual.return_value = atual
    repo.get_id.return_value = None
    return repo


def test_solicitacao_sem_motivo_e_recusada():
    repo = _servico(atual=3)
    bem = MagicMock(ativo=True, status="Disponível")
    with patch.object(mov_service, "BemRepository") as bem_repo, \
         patch.object(mov_service, "SetorRepository") as set_repo, \
         patch.object(mov_service, "MovimentacaoRepository", return_value=repo):
        bem_repo.return_value.get_by_id.return_value = bem
        set_repo.return_value.get_id.return_value = MagicMock()
        set_repo.return_value.get_almoxarifado.return_value = ALMOX
        with pytest.raises(HTTPException) as exc:
            MovimentacaoService().add_movimentacao(
                MovimentacaoCreate(bem_id=1, setor_destino_id=5, justificativa="   "), RESPONSAVEL)
    assert exc.value.status_code == 400 and "motivo" in exc.value.detail.lower()
    repo.save.assert_not_called()


def test_recusa_sem_motivo_e_bloqueada():
    with pytest.raises(HTTPException) as exc:
        MovimentacaoService().decidir_movimentacao(7, {"id": 1, "perfil": "setor_patrimonio"}, aprovar=False, motivo=" ")
    assert exc.value.status_code == 400


def test_motivo_da_recusa_minimo_tres_caracteres():
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        DecisaoRecusa(motivo="ok")
    assert DecisaoRecusa(motivo="Bem em uso no setor").motivo == "Bem em uso no setor"


def test_recusa_grava_o_motivo_no_repositorio():
    mov = MagicMock(status="pendente", bem_id=9, setor_origem_id=3, solicitante_id=12, fluxo="simples")
    repo = MagicMock()
    repo.get_id.return_value = mov
    repo.decidir.return_value = ("ok", MagicMock())
    with patch.object(mov_service, "MovimentacaoRepository", return_value=repo), \
         patch.object(mov_service, "SetorRepository") as set_repo:
        set_repo.return_value.get_almoxarifado.return_value = ALMOX
        MovimentacaoService().decidir_movimentacao(7, {"id": 1, "perfil": "setor_patrimonio", "setor_id": None},
                                                   aprovar=False, motivo="Equipamento em uso no laboratório")
    assert repo.decidir.call_args.args[-1] == "Equipamento em uso no laboratório"
