"""Auditoria de alterações de bens: só o que mudou é registrado; nada é editado nem apagado."""
from unittest.mock import MagicMock, patch

from modules.auditoria import service as aud
from modules.auditoria.service import diferencas
from modules.bem.schemas import Bem, BemUpdate
from modules.bem.service import BemService

ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}


def _bem(**kw):
    base = dict(id=8, nome="Switch", tipo="Equipamento", codigo_tombamento="EQP-008-1",
                valor=2100.0, status="Disponível", ativo=True, id_categoria=1)
    base.update(kw)
    return Bem(**base)


def test_diferencas_mostra_so_campos_alterados():
    de, para = diferencas({"nome": "A", "valor": 1, "marca": "X"}, {"nome": "B", "valor": 1, "marca": "X"})
    assert de == {"nome": "A"} and para == {"nome": "B"}


def test_sem_mudanca_nao_registra(monkeypatch):
    repo = MagicMock()
    monkeypatch.setattr(aud, "AuditoriaRepository", lambda: repo)
    aud.registrar_alteracao("bem", 8, ADMIN, {"nome": "A"}, {"nome": "A"})
    repo.registrar.assert_not_called()


def test_edicao_registra_antes_e_depois_dos_campos_alterados(monkeypatch):
    repo = MagicMock()
    monkeypatch.setattr(aud, "AuditoriaRepository", lambda: repo)
    aud.registrar_alteracao("bem", 8, ADMIN, {"nome": "A", "valor": 1}, {"nome": "B", "valor": 1})
    args = repo.registrar.call_args.args
    assert args == ("bem", 8, "editar", 1, {"nome": "A"}, {"nome": "B"})


def test_put_bem_registra_auditoria_da_edicao():
    with patch("modules.bem.service.BemRepository") as repo_cls, \
         patch("modules.bem.service.registrar_alteracao") as audit:
        repo = repo_cls.return_value
        repo.get_by_id.return_value = _bem()
        repo.put.return_value = _bem(nome="Switch novo")
        BemService().put_bem(8, BemUpdate(nome="Switch novo"), ADMIN)
    audit.assert_called_once()
    assert audit.call_args.args[0] == "bem" and audit.call_args.args[1] == 8


def test_desativar_registra_baixa_com_usuario():
    with patch("modules.bem.service.BemRepository") as repo_cls, \
         patch("modules.bem.service.registrar_acao") as acao:
        repo_cls.return_value.get_by_id.return_value = _bem()
        BemService().desativar_bem(8, ADMIN)
    acao.assert_called_once_with("bem", 8, "baixar", ADMIN, {"ativo": True}, {"ativo": False})


def test_reativar_registra_com_usuario():
    with patch("modules.bem.service.BemRepository") as repo_cls, \
         patch("modules.bem.service.registrar_acao") as acao:
        repo_cls.return_value.get_by_id.return_value = _bem(ativo=False)
        BemService().reativar_bem(8, ADMIN)
    acao.assert_called_once_with("bem", 8, "reativar", ADMIN, {"ativo": False}, {"ativo": True})
