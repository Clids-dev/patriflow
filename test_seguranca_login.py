"""REQ-EX-02: bloqueio após tentativas erradas e registro de acessos."""
from unittest.mock import MagicMock, patch

import pytest

from modules.usuario import seguranca
from modules.usuario.service import UsuarioService
from modules.usuario.seguranca import ContaBloqueada


def _usuario(user_id=5, ativo=True):
    return (user_id, "ana", "hash", "agente_campo", ativo, "Ana", None)


def test_senha_errada_registra_falha_e_nega():
    repo = MagicMock()
    repo.buscar_por_username.return_value = _usuario()
    with patch.object(seguranca, "estado", return_value=(0, 0)), \
         patch.object(seguranca, "registrar_falha", return_value=False) as falha, \
         patch("modules.usuario.service.verify_password", return_value=False):
        assert UsuarioService(repo).login("ana", "errada") is None
    falha.assert_called_once_with(5, "ana")


def test_conta_bloqueada_nao_verifica_senha_e_avisa_o_tempo():
    repo = MagicMock()
    repo.buscar_por_username.return_value = _usuario()
    with patch.object(seguranca, "estado", return_value=(0, 12)), \
         patch.object(seguranca, "registrar_acesso"), \
         patch("modules.usuario.service.verify_password") as verifica:
        with pytest.raises(ContaBloqueada) as exc:
            UsuarioService(repo).login("ana", "qualquer")
    assert exc.value.minutos_restantes == 12
    verifica.assert_not_called()


def test_login_correto_zera_as_falhas():
    repo = MagicMock()
    repo.buscar_por_username.return_value = _usuario()
    with patch.object(seguranca, "estado", return_value=(3, 0)), \
         patch.object(seguranca, "registrar_sucesso") as ok, \
         patch("modules.usuario.service.verify_password", return_value=True):
        assert UsuarioService(repo).login("ana", "certa") is not None
    ok.assert_called_once_with(5, "ana")


def test_limite_e_bloqueio_definidos():
    assert seguranca.LIMITE_TENTATIVAS == 5
    assert seguranca.BLOQUEIO_MINUTOS == 15


def test_registro_de_acesso_nunca_recebe_a_senha():
    import inspect
    assert "senha" not in inspect.signature(seguranca.registrar_acesso).parameters
