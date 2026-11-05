"""Regressões: atualização de valores do bem e regras de status (manutenção)."""
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

from modules.bem import queries
from modules.bem.repository import BemRepository
from modules.bem.schemas import Bem, BemCreate, BemUpdate
from modules.bem.service import BemService

AGENTE = {"id": 12, "perfil": "agente_campo", "setor_id": 1}
ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}


def _bem(status="Manutenção"):
    return Bem(id=8, nome="Switch", tipo="Equipamento", codigo_tombamento="EQP-008-1",
               valor=2100.0, status=status, ativo=True, id_categoria=1)


def test_update_nao_mistura_valor_com_valor_aquisicao():
    """Alterar só o valor não pode sobrescrever o valor de aquisição, e vice-versa."""
    assert "valor = COALESCE(%s, valor)" in queries.QUERY_PUT_BEM
    assert "valor_aquisicao = COALESCE(%s, valor_aquisicao)" in queries.QUERY_PUT_BEM
    assert "COALESCE(%s, %s" not in queries.QUERY_PUT_BEM


def test_update_envia_um_parametro_por_placeholder():
    """A ordem e a quantidade dos parâmetros batem com o SQL."""
    update = BemUpdate(valor=999.0)
    with patch("modules.bem.repository.DataBase") as db:
        db.return_value.commit.return_value = None
        BemRepository().put(8, update)
    sql, params = db.return_value.commit.call_args.args
    assert sql.count("%s") == len(params) == 11
    # Só o valor foi informado: valor_aquisicao (posição 7) deve ser None.
    assert params[1] == 999.0
    assert params[6] is None


@pytest.mark.parametrize("status", ["manutencao", "Quebrado", "", "Em uso"])
def test_status_fora_da_lista_e_rejeitado(status):
    with pytest.raises(ValidationError):
        BemUpdate(status=status)


def test_agente_nao_tira_bem_da_manutencao():
    with patch("modules.bem.service.BemRepository") as repo_cls:
        repo_cls.return_value.get_by_id.return_value = _bem("Manutenção")
        with pytest.raises(HTTPException) as exc:
            BemService().put_bem(8, BemUpdate(status="Disponível"), AGENTE)
    assert exc.value.status_code == 403
    repo_cls.return_value.put.assert_not_called()


def test_admin_tira_bem_da_manutencao():
    with patch("modules.bem.service.BemRepository") as repo_cls:
        repo_cls.return_value.get_by_id.return_value = _bem("Manutenção")
        repo_cls.return_value.put.return_value = _bem("Disponível")
        BemService().put_bem(8, BemUpdate(status="Disponível"), ADMIN)
    repo_cls.return_value.put.assert_called_once()


def test_agente_pode_editar_bem_que_nao_esta_em_manutencao():
    with patch("modules.bem.service.BemRepository") as repo_cls:
        repo_cls.return_value.get_by_id.return_value = _bem("Em Uso")
        repo_cls.return_value.put.return_value = _bem("Em Uso")
        BemService().put_bem(8, BemUpdate(status="Baixado"), AGENTE)
    repo_cls.return_value.put.assert_called_once()


def test_create_rejeita_status_invalido():
    with pytest.raises(ValidationError):
        BemCreate(nome="X", codigo_tombamento="X-001-0", status="inexistente", id_categoria=1,
                  estado_conservacao="novo", valor=10.0)


def test_tombo_duplicado_devolve_409_claro():
    """Tombo já existente (inclusive de bem baixado) vira 409, não erro 500."""
    from psycopg2 import errors as pg_errors

    bem = BemCreate(nome="Switch", tipo="Equipamento", codigo_tombamento="EQP-008-1",
                    valor=100.0, status="Disponível", id_categoria=1, estado_conservacao="novo")
    with patch("modules.bem.service.SetorRepository") as setor_cls, \
         patch("modules.bem.service.BemRepository") as repo_cls:
        setor_cls.return_value.get_almoxarifado.return_value = MagicMock(id=1)
        repo_cls.return_value.save.side_effect = pg_errors.UniqueViolation()
        with pytest.raises(HTTPException) as exc:
            BemService().create_bem(bem, ADMIN)
    assert exc.value.status_code == 409
    assert "EQP-008-1" in exc.value.detail
    assert "não são reaproveitados" in exc.value.detail
