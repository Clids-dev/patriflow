"""Empréstimo, manutenção, linha do tempo do bem e trilha imutável, contra um banco PostgreSQL real.

Dados iniciais (schema.sql): bens 1 e 2 no setor 1 (TI); bem 5 marcado como "Manutenção" sem registro.
"""
import threading
from datetime import date, timedelta

import psycopg2
import pytest
from fastapi import HTTPException

from modules.bem import historico
from modules.emprestimo.schemas import EmprestimoCreate
from modules.emprestimo.service import EmprestimoService
from modules.manutencao.schemas import ManutencaoCreate, Retorno
from modules.manutencao.service import ManutencaoService
from modules.movimentacao.schemas import MovimentacaoCreate
from modules.movimentacao.service import MovimentacaoService

pytestmark = pytest.mark.integracao

TI, FINANCEIRO = 1, 2
ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}
AMANHA = date.today() + timedelta(days=1)


@pytest.fixture
def pessoas(sql):
    """Agente do TI (guarda dos bens 1 e 2) e agente do Financeiro (sem guarda deles)."""
    agente_ti = sql("""INSERT INTO usuarios (username, senha, tipo, ativo, nome, setor_id)
                       VALUES ('agente_ti', 'x', 'agente_campo', TRUE, 'Agente TI', %s) RETURNING id""", (TI,), um=True)[0]
    agente_fin = sql("""INSERT INTO usuarios (username, senha, tipo, ativo, nome, setor_id)
                        VALUES ('agente_fin', 'x', 'agente_campo', TRUE, 'Agente Fin', %s) RETURNING id""",
                     (FINANCEIRO,), um=True)[0]
    return {"ti": {"id": agente_ti, "perfil": "agente_campo", "setor_id": TI},
            "fin": {"id": agente_fin, "perfil": "agente_campo", "setor_id": FINANCEIRO}}


def _emprestimo(bem_id=1, prazo=AMANHA):
    return EmprestimoCreate(bem_id=bem_id, tomador="Maria Souza", matricula="M-1001", setor_destino_id=2, motivo="Apresentação externa", devolucao_prevista=prazo)


def _erro(funcao, *args):
    with pytest.raises(HTTPException) as exc:
        funcao(*args)
    return exc.value


# --- Empréstimo ---------------------------------------------------------------------------------

def test_emprestimo_aberto_aparece_na_lista_e_no_historico(banco):
    emp = EmprestimoService().registrar(_emprestimo(), ADMIN)
    assert emp.devolvido_em is None and not emp.atrasado and emp.registrado_por

    abertos = EmprestimoService().listar("abertos", None)
    assert [e.id for e in abertos] == [emp.id]
    eventos = historico.linha_do_tempo(1)
    assert eventos[0]["tipo"] == "emprestimo_saida" and "Maria Souza" in eventos[0]["detalhe"]


def test_bem_so_tem_um_emprestimo_aberto(banco):
    EmprestimoService().registrar(_emprestimo(), ADMIN)
    assert _erro(EmprestimoService().registrar, _emprestimo(), ADMIN).status_code == 409


def test_devolucao_prevista_no_passado_e_recusada(banco):
    erro = _erro(EmprestimoService().registrar, _emprestimo(prazo=date.today() - timedelta(days=1)), ADMIN)
    assert erro.status_code == 400


def test_colaborador_so_empresta_bem_do_proprio_setor(banco, pessoas):
    assert _erro(EmprestimoService().registrar, _emprestimo(), pessoas["fin"]).status_code == 403
    assert EmprestimoService().registrar(_emprestimo(), pessoas["ti"]).id


def test_bem_emprestado_nao_pode_ser_transferido(banco, pessoas):
    EmprestimoService().registrar(_emprestimo(), ADMIN)
    pedido = MovimentacaoCreate(bem_id=1, setor_destino_id=FINANCEIRO, justificativa="Uso no financeiro")
    erro = _erro(MovimentacaoService().add_movimentacao, pedido, pessoas["fin"])
    assert erro.status_code == 409 and "emprestado" in erro.detail


def test_devolucao_encerra_uma_vez_e_entra_no_historico(banco):
    emp = EmprestimoService().registrar(_emprestimo(), ADMIN)
    devolvido = EmprestimoService().devolver(emp.id, "Voltou com a capa", ADMIN)
    assert devolvido.devolvido_em is not None and devolvido.recebido_por
    assert _erro(EmprestimoService().devolver, emp.id, None, ADMIN).status_code == 409
    assert EmprestimoService().listar("abertos", None) == []
    assert historico.linha_do_tempo(1)[0]["titulo"] == "Devolução do empréstimo"


def test_emprestimo_vencido_aparece_como_atrasado(banco, sql):
    sql("""INSERT INTO emprestimos (bem_id, tomador, motivo, saida_em, devolucao_prevista, registrado_por)
           VALUES (2, 'João Lima', 'Evento', NOW() - INTERVAL '10 days', CURRENT_DATE - 3, 1)""")
    atrasados = EmprestimoService().listar("atrasados", None)
    assert len(atrasados) == 1 and atrasados[0].atrasado and atrasados[0].dias_atraso == 3


def test_dois_pedidos_simultaneos_resultam_em_um_emprestimo(banco, sql):
    """FOR UPDATE no bem serializa os pedidos: um vence, o outro recebe 409 (sem erro de banco)."""
    resultados, barreira = [], threading.Barrier(2)

    def pedir():
        barreira.wait()
        try:
            EmprestimoService().registrar(_emprestimo(), ADMIN)
            resultados.append(201)
        except HTTPException as erro:
            resultados.append(erro.status_code)

    threads = [threading.Thread(target=pedir) for _ in range(2)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert sorted(resultados) == [201, 409]
    assert sql("SELECT count(*) FROM emprestimos WHERE bem_id = 1", um=True)[0] == 1


# --- Manutenção ---------------------------------------------------------------------------------

def _manutencao(bem_id=1):
    return ManutencaoCreate(bem_id=bem_id, descricao="Tela piscando", destino="Assistência Dell")


def test_envio_e_retorno_da_manutencao(banco, sql):
    enviada = ManutencaoService().enviar(_manutencao(), ADMIN)
    assert enviada.status_anterior == "Em Uso"
    assert sql("SELECT status FROM bens WHERE id = 1", um=True)[0] == "Manutenção"

    # Fora para manutenção, o bem não pode ser emprestado.
    assert _erro(EmprestimoService().registrar, _emprestimo(), ADMIN).status_code == 409

    retorno = ManutencaoService().registrar_retorno(
        enviada.id, Retorno(servico_realizado="Troca do painel", estado_retorno="bom"), ADMIN)
    assert retorno.retorno_em is not None and retorno.estado_retorno == "bom"
    assert sql("SELECT status, estado_conservacao FROM bens WHERE id = 1", um=True) == ("Em Uso", "bom")

    acoes = [r[0] for r in sql("SELECT acao FROM auditoria WHERE entidade = 'bem' AND registro_id = 1 ORDER BY id")]
    assert acoes[-2:] == ["enviar_manutencao", "retorno_manutencao"]
    tipos = [e["tipo"] for e in historico.linha_do_tempo(1)]
    assert tipos[:2] == ["manutencao_retorno", "manutencao_envio"]


def test_retorno_so_pode_ser_registrado_uma_vez(banco):
    enviada = ManutencaoService().enviar(_manutencao(), ADMIN)
    dados = Retorno(servico_realizado="Limpeza interna", estado_retorno="regular")
    ManutencaoService().registrar_retorno(enviada.id, dados, ADMIN)
    assert _erro(ManutencaoService().registrar_retorno, enviada.id, dados, ADMIN).status_code == 409


def test_bem_marcado_em_manutencao_sem_registro_pode_ser_registrado(banco):
    """Bem 5 ficou "Manutenção" pela edição antiga. Registrar agora volta para "Disponível" no retorno."""
    enviada = ManutencaoService().enviar(_manutencao(bem_id=5), ADMIN)
    assert enviada.status_anterior == "Disponível"


def test_bem_inexistente_responde_404(banco):
    assert _erro(ManutencaoService().enviar, _manutencao(bem_id=9999), ADMIN).status_code == 404
    assert _erro(historico.linha_do_tempo, 9999).status_code == 404


# --- Trilha imutável ----------------------------------------------------------------------------

@pytest.mark.parametrize("comando", [
    "DELETE FROM emprestimos",
    "DELETE FROM manutencoes",
    "DELETE FROM movimentacoes",
    "UPDATE auditoria SET acao = 'outra'",
    "DELETE FROM auditoria",
])
def test_eventos_nao_podem_ser_apagados_nem_alterados(banco, sql, comando):
    emp = EmprestimoService().registrar(_emprestimo(), ADMIN)
    ManutencaoService().enviar(_manutencao(bem_id=2), ADMIN)  # também gera auditoria
    assert emp.id
    with pytest.raises(psycopg2.Error):
        sql(comando)


def test_emprestimo_encerrado_nao_pode_ser_alterado(banco, sql):
    emp = EmprestimoService().registrar(_emprestimo(), ADMIN)
    EmprestimoService().devolver(emp.id, None, ADMIN)
    with pytest.raises(psycopg2.Error):
        sql("UPDATE emprestimos SET observacao_devolucao = 'mudou' WHERE id = %s", (emp.id,))


def test_dados_de_saida_do_emprestimo_aberto_sao_fixos(banco, sql):
    emp = EmprestimoService().registrar(_emprestimo(), ADMIN)
    with pytest.raises(psycopg2.Error):
        sql("UPDATE emprestimos SET tomador = 'Outra pessoa' WHERE id = %s", (emp.id,))


# --- Linha do tempo -----------------------------------------------------------------------------

def test_transferencia_direta_do_patrimonio_e_um_evento_so(banco):
    movimento = MovimentacaoCreate(bem_id=3, setor_origem_id=3, setor_destino_id=FINANCEIRO, justificativa="Distribuição")
    MovimentacaoService().add_movimentacao(movimento, ADMIN)
    eventos = historico.linha_do_tempo(3)
    assert eventos[0]["tipo"] == "transferencia_aprovada"
    assert not any(e["tipo"] == "transferencia_solicitada" for e in eventos)


def test_linha_do_tempo_vem_do_mais_recente_para_o_mais_antigo(banco):
    emp = EmprestimoService().registrar(_emprestimo(), ADMIN)
    EmprestimoService().devolver(emp.id, None, ADMIN)
    datas = [e["em"] for e in historico.linha_do_tempo(1)]
    assert datas == sorted(datas, reverse=True)
    # Bens antigos, sem auditoria de criação, ainda mostram o cadastro (pela data_cadastro).
    assert any(e["tipo"] == "cadastro" for e in historico.linha_do_tempo(1))
