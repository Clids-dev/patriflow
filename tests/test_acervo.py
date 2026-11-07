"""Acervo do setor para uso offline no aplicativo, num banco real.

Dados iniciais (schema.sql): bens 1 e 2 no TI (setor 1); bem 3 no almoxarifado (setor 3).
"""
from datetime import date, timedelta

import pytest
from fastapi import HTTPException

from core import config
from modules.acervo.service import acervo_do_setor
from modules.emprestimo.schemas import EmprestimoCreate
from modules.emprestimo.service import EmprestimoService
from modules.foto.service import FotoService
from modules.inventario.schemas import Conferencia, InventarioCreate
from modules.inventario.service import InventarioService

pytestmark = pytest.mark.integracao

TI, ALMOX = 1, 3
ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}
AGENTE_TI = {"id": 2, "perfil": "agente_campo", "setor_id": TI}
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 100


def test_acervo_traz_a_ficha_completa_dos_bens_do_setor(banco):
    acervo = acervo_do_setor(TI, AGENTE_TI)
    assert acervo["setor"] == {"id": TI, "nome": "Departamento de Tecnologia"}
    assert sorted(b["id"] for b in acervo["bens"]) == [1, 2]
    bem = next(b for b in acervo["bens"] if b["id"] == 1)
    assert bem["codigo_tombamento"] and bem["categoria_nome"] and bem["setor_nome"] == "Departamento de Tecnologia"
    assert bem["emprestimo_aberto_id"] is None and bem["manutencao_aberta_id"] is None
    assert bem["foto_referencia_id"] is None
    assert acervo["categorias"] and acervo["setores"]
    assert set(acervo["localizacoes"]) == {"predios", "andares", "salas"}


def test_colaborador_so_baixa_o_proprio_setor(banco):
    with pytest.raises(HTTPException) as exc:
        acervo_do_setor(ALMOX, AGENTE_TI)
    assert exc.value.status_code == 403
    assert acervo_do_setor(ALMOX, ADMIN)["setor"]["id"] == ALMOX


def test_setor_inexistente_responde_404(banco):
    with pytest.raises(HTTPException) as exc:
        acervo_do_setor(999, ADMIN)
    assert exc.value.status_code == 404


def test_situacao_e_foto_de_referencia_vem_no_acervo(banco, tmp_path, monkeypatch):
    monkeypatch.setattr(config, "FOTOS_DIR", str(tmp_path))
    emprestimo = EmprestimoService().registrar(EmprestimoCreate(bem_id=2, tomador="Maria Souza", motivo="Evento",
                                                                devolucao_prevista=date.today() + timedelta(days=2)), ADMIN)
    inv = InventarioService().abrir(InventarioCreate(descricao="Inventário", inicio=date.today(), fim=date.today(),
                                                     setor_ids=[TI]), ADMIN)
    codigo = next(b["codigo_tombamento"] for b in acervo_do_setor(TI, ADMIN)["bens"] if b["id"] == 1)
    item = InventarioService().conferir(inv.id, Conferencia(setor_id=TI, codigo_tombamento=codigo), ADMIN)
    foto = FotoService().registrar(JPEG, "conferencia", item.id, ADMIN)

    bens = {b["id"]: b for b in acervo_do_setor(TI, ADMIN)["bens"]}
    assert bens[1]["foto_referencia_id"] == foto["id"]
    assert bens[2]["emprestimo_aberto_id"] == emprestimo.id and bens[2]["emprestado_para"] == "Maria Souza"
