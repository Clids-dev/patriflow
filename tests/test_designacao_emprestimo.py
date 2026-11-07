"""Decisões D1 (agentes com setores designados e imprevistos) e D9 (empréstimo interno, até 30 dias).

Dados iniciais (schema.sql): bens 1 e 2 no TI (setor 1), bem 4 no RH (setor 4); setor 2 = Financeiro.
"""
from datetime import date, timedelta

import pytest
from fastapi import HTTPException

from modules.acervo.service import acervo_do_setor
from modules.emprestimo.schemas import EmprestimoCreate
from modules.emprestimo.service import EmprestimoService
from modules.inventario.schemas import Conferencia, InventarioCreate
from modules.inventario.service import InventarioService
from modules.setor import designacao

pytestmark = pytest.mark.integracao

TI, FIN, RH = 1, 2, 4
ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}


@pytest.fixture
def agente(sql):
    """Agente do Financeiro, sem designações."""
    uid = sql("""INSERT INTO usuarios (username, senha, tipo, ativo, nome, setor_id)
                 VALUES ('agente_fin', 'x', 'agente_campo', TRUE, 'Agente Fin', %s) RETURNING id""", (FIN,), um=True)[0]
    return {"id": uid, "perfil": "agente_campo", "setor_id": FIN}


def _emprestimo(bem_id=1, prazo=7, destino=FIN, **extra):
    return EmprestimoCreate(bem_id=bem_id, tomador="Maria Souza", matricula="M-2024", setor_destino_id=destino,
                            motivo="Apresentação", devolucao_prevista=date.today() + timedelta(days=prazo), **extra)


def _erro(funcao, *args):
    with pytest.raises(HTTPException) as exc:
        funcao(*args)
    return exc.value


# --- D9 ------------------------------------------------------------------------------------------

def test_emprestimo_guarda_matricula_e_setor_de_destino(banco):
    emp = EmprestimoService().registrar(_emprestimo(), ADMIN)
    assert emp.matricula == "M-2024" and emp.setor_destino == "Financeiro"


def test_prazo_maximo_de_30_dias(banco):
    assert EmprestimoService().registrar(_emprestimo(prazo=30), ADMIN).id
    erro = _erro(EmprestimoService().registrar, _emprestimo(bem_id=2, prazo=31), ADMIN)
    assert erro.status_code == 400 and "30 dias" in erro.detail


def test_setor_de_destino_precisa_existir(banco):
    assert _erro(EmprestimoService().registrar, _emprestimo(destino=999), ADMIN).status_code == 400


def test_matricula_e_destino_sao_obrigatorios():
    with pytest.raises(Exception):
        EmprestimoCreate(bem_id=1, tomador="Maria", motivo="x" * 5, devolucao_prevista=date.today())


# --- D1 ------------------------------------------------------------------------------------------

def test_agente_opera_nos_setores_designados(banco, agente):
    assert _erro(EmprestimoService().registrar, _emprestimo(), agente).status_code == 403
    designacao.designar(TI, [agente["id"]], ADMIN)
    assert EmprestimoService().registrar(_emprestimo(), agente).id
    assert sorted(b["id"] for b in acervo_do_setor(TI, agente)["bens"]) == [1, 2]


def test_imprevisto_permite_e_avisa_o_patrimonio(banco, agente, sql):
    curto = _erro(EmprestimoService().registrar, _emprestimo(imprevisto="urgente"), agente)
    assert curto.status_code == 403 and "imprevisto" in curto.detail
    emp = EmprestimoService().registrar(_emprestimo(imprevisto="Reunião externa remarcada às pressas"), agente)
    assert emp.id
    tipo, descricao = sql("SELECT tipo, descricao FROM pendencias", um=True)
    assert tipo == "operacao_imprevista" and "Reunião externa" in descricao


def test_responsavel_nao_usa_imprevisto(banco, sql):
    uid = sql("""INSERT INTO usuarios (username, senha, tipo, ativo, nome, setor_id)
                 VALUES ('resp_rh', 'x', 'responsavel_setor', TRUE, 'Resp RH', %s) RETURNING id""", (RH,), um=True)[0]
    resp = {"id": uid, "perfil": "responsavel_setor", "setor_id": RH}
    erro = _erro(EmprestimoService().registrar, _emprestimo(imprevisto="Motivo longo o bastante"), resp)
    assert erro.status_code == 403


def test_agente_confere_no_setor_designado(banco, agente, sql):
    inv = InventarioService().abrir(InventarioCreate(descricao="Inventário TI", inicio=date.today(),
                                                     fim=date.today(), setor_ids=[TI]), ADMIN)
    codigo = sql("SELECT codigo_tombamento FROM bens WHERE id = 1", um=True)[0]
    conferencia = Conferencia(setor_id=TI, codigo_tombamento=codigo)
    assert _erro(InventarioService().conferir, inv.id, conferencia, agente).status_code == 403
    designacao.designar(TI, [agente["id"]], ADMIN)
    assert InventarioService().conferir(inv.id, conferencia, agente).situacao == "localizado"


def test_designacao_so_pelo_patrimonio_e_so_de_agentes(banco, agente):
    assert _erro(designacao.designar, TI, [agente["id"]], agente).status_code == 403
    assert _erro(designacao.designar, TI, [1], ADMIN).status_code == 400  # o admin não é agente
    lista = designacao.designar(TI, [agente["id"]], ADMIN)
    assert [a["designado"] for a in lista if a["id"] == agente["id"]] == [True]
    assert designacao.designar(TI, [], ADMIN)[0]["designado"] is False  # lista vazia remove


def test_setores_do_acervo_incluem_os_designados(banco, agente):
    from modules.acervo.service import setores_permitidos
    assert [s["id"] for s in setores_permitidos(agente)] == [FIN]
    designacao.designar(TI, [agente["id"]], ADMIN)
    assert sorted(s["id"] for s in setores_permitidos(agente)) == [TI, FIN]
