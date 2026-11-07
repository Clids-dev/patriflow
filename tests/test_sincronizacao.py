"""Sincronização em lote: ordem, idempotência, conflitos, recusas e erros, num banco real.

Dados iniciais (schema.sql): bens 1 e 2 no TI (setor 1); bem 3 no almoxarifado (setor 3); bem 4 no RH (setor 4).
"""
import threading
from datetime import date, datetime, timedelta
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from api.v1.auth import jwt_secret
from core.security import create_access_token
from main import app
from modules.inventario.schemas import InventarioCreate
from modules.inventario.service import InventarioService
from modules.movimentacao.schemas import MovimentacaoCreate
from modules.movimentacao.service import MovimentacaoService
from modules.sincronizacao import service as sync_service
from modules.sincronizacao.schemas import Lote
from modules.sincronizacao.service import SincronizacaoService

pytestmark = pytest.mark.integracao

TI, ALMOX, RH = 1, 3, 4
ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}
APARELHO = "aparelho-teste-0001"
AGORA = datetime(2026, 11, 7, 9, 0, 0)


@pytest.fixture
def pessoas(sql):
    def criar(username, tipo, setor):
        uid = sql("""INSERT INTO usuarios (username, senha, tipo, ativo, nome, setor_id)
                     VALUES (%s, 'x', %s, TRUE, %s, %s) RETURNING id""", (username, tipo, username, setor), um=True)[0]
        return {"id": uid, "perfil": tipo, "setor_id": setor}
    return {"agente_ti": criar("agente_ti", "agente_campo", TI),
            "resp_ti": criar("resp_ti", "responsavel_setor", TI),
            "resp_rh": criar("resp_rh", "responsavel_setor", RH)}


@pytest.fixture
def tombo(sql):
    codigos = dict(sql("SELECT id, codigo_tombamento FROM bens WHERE id <= 5"))
    return lambda bem_id: codigos[bem_id]


def op(id_, tipo, dados, minutos=0):
    return {"id": id_, "tipo": tipo, "criada_em": (AGORA + timedelta(minutes=minutos)).isoformat(), "dados": dados}


def sincronizar(operacoes, usuario=ADMIN, aparelho=APARELHO):
    return SincronizacaoService().sincronizar(Lote(dispositivo_id=aparelho, operacoes=operacoes), usuario)


def status(resposta):
    return [(r.id, r.status) for r in resposta["resultados"]]


def _emprestimo(bem_id=1, tomador="Maria Souza"):
    return {"bem_id": bem_id, "tomador": tomador, "motivo": "Evento externo",
            "devolucao_prevista": (date.today() + timedelta(days=3)).isoformat()}


# --- Aplicação e ordem --------------------------------------------------------------------------

def test_operacoes_sao_aplicadas_na_ordem_de_criacao(banco, sql):
    # Enviadas fora de ordem: a devolução foi criada depois do empréstimo, mas vem primeiro no lote.
    emprestar = op("op-emprestar-1", "emprestimo_registrar", _emprestimo(), minutos=0)
    resposta = sincronizar([
        op("op-manutencao-1", "manutencao_enviar", {"bem_id": 1, "descricao": "Tela piscando", "destino": "Assistência"},
           minutos=5),
        emprestar,
    ])
    # O empréstimo (criado antes) foi aplicado primeiro; a manutenção encontra o bem emprestado: conflito.
    assert status(resposta) == [("op-manutencao-1", "conflito"), ("op-emprestar-1", "aceita")]
    assert resposta["resultados"][1].resultado["emprestimo_id"] > 0


def test_reenvio_do_mesmo_lote_nao_grava_duas_vezes(banco, sql):
    lote = [op("op-repetida-1", "emprestimo_registrar", _emprestimo())]
    primeira = sincronizar(lote)
    segunda = sincronizar(lote)
    assert primeira["resultados"][0].status == "aceita" and not primeira["resultados"][0].repetida
    assert segunda["resultados"][0].status == "aceita" and segunda["resultados"][0].repetida
    assert segunda["resultados"][0].resultado == primeira["resultados"][0].resultado
    assert sql("SELECT count(*) FROM emprestimos", um=True)[0] == 1


def test_reenvio_simultaneo_aplica_uma_vez(banco, sql):
    """Dois envios do mesmo lote ao mesmo tempo (ex.: o app repetiu por timeout): um aplica, o outro repete."""
    lote = [op("op-simultanea-1", "emprestimo_registrar", _emprestimo())]
    respostas, barreira = [], threading.Barrier(2)

    def enviar():
        barreira.wait()
        respostas.append(sincronizar(lote)["resultados"][0])

    threads = [threading.Thread(target=enviar) for _ in range(2)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert sorted(r.repetida for r in respostas) == [False, True]
    assert sql("SELECT count(*) FROM emprestimos", um=True)[0] == 1


def test_mesmo_id_em_outro_aparelho_e_outra_operacao(banco, sql):
    sincronizar([op("op-compartilhada", "emprestimo_registrar", _emprestimo(bem_id=1))], aparelho="aparelho-a-0001")
    resposta = sincronizar([op("op-compartilhada", "emprestimo_registrar", _emprestimo(bem_id=2))],
                           aparelho="aparelho-b-0001")
    assert resposta["resultados"][0].status == "aceita" and not resposta["resultados"][0].repetida
    assert sql("SELECT count(*) FROM emprestimos", um=True)[0] == 2


# --- Recusas, conflitos e erros -----------------------------------------------------------------

def test_dados_invalidos_e_tipo_desconhecido_sao_recusados_com_motivo(banco):
    resposta = sincronizar([
        op("op-invalida-1", "emprestimo_registrar", {"bem_id": 1, "tomador": "Jo"}),
        op("op-desconhecida", "teletransporte", {}),
    ])
    assert status(resposta) == [("op-invalida-1", "recusada"), ("op-desconhecida", "recusada")]
    assert "Dados inválidos" in resposta["resultados"][0].mensagem
    assert "desconhecido" in resposta["resultados"][1].mensagem


def test_sem_permissao_e_recusado_e_nao_vira_pendencia(banco, pessoas, sql):
    resposta = sincronizar([op("op-sem-permissao", "emprestimo_registrar", _emprestimo(bem_id=4))], pessoas["agente_ti"])
    assert resposta["resultados"][0].status == "recusada"
    assert sql("SELECT count(*) FROM pendencias", um=True)[0] == 0


def test_conflito_fica_registrado_e_vai_para_a_caixa_de_pendencias(banco, sql):
    sincronizar([op("op-primeiro", "emprestimo_registrar", _emprestimo())], aparelho="aparelho-a-0001")
    resposta = sincronizar([op("op-segundo", "emprestimo_registrar", _emprestimo(tomador="João Lima"))],
                           aparelho="aparelho-b-0001")
    assert resposta["resultados"][0].status == "conflito"
    pendencia = sql("""SELECT p.tipo, p.descricao, o.status FROM pendencias p
                       JOIN sync_operacoes o ON o.id = p.sync_operacao_id""", um=True)
    assert pendencia[0] == "conflito_sincronizacao" and pendencia[2] == "conflito"
    assert pendencia[1].startswith("Empréstimo (operação feita sem rede em") and "emprestado" in pendencia[1]


def test_liberacao_feita_offline_vira_conflito_se_a_transferencia_ja_avancou(banco, pessoas, sql):
    """O responsável do TI liberou sem rede, mas o patrimônio já tinha liberado: não pode virar recebimento."""
    pedido = MovimentacaoService().add_movimentacao(
        MovimentacaoCreate(bem_id=1, setor_destino_id=RH, justificativa="Uso no RH"), pessoas["resp_rh"])
    MovimentacaoService().decidir_movimentacao(pedido.id, ADMIN, aprovar=True)  # liberada pelo patrimônio
    resposta = sincronizar([op("op-liberar-1", "transferencia_liberar", {"movimentacao_id": pedido.id})],
                           pessoas["resp_ti"])
    assert resposta["resultados"][0].status == "conflito"
    assert sql("SELECT status FROM movimentacoes WHERE id = %s", (pedido.id,), um=True)[0] == "liberada"


def test_erro_inesperado_e_registrado_e_pode_ser_reenviado(banco, sql):
    lote = [op("op-com-erro-1", "emprestimo_registrar", _emprestimo())]
    original = sync_service.OPERACOES["emprestimo_registrar"]
    with patch.dict(sync_service.OPERACOES, {"emprestimo_registrar": (original[0], lambda d, u: 1 / 0)}):
        falha = sincronizar(lote)
    assert falha["resultados"][0].status == "erro"
    assert sql("SELECT status FROM sync_operacoes WHERE operacao_id = 'op-com-erro-1'", um=True)[0] == "erro"

    nova = sincronizar(lote)  # depois do problema corrigido, o reenvio é processado de novo
    assert nova["resultados"][0].status == "aceita" and not nova["resultados"][0].repetida
    assert sql("SELECT count(*) FROM emprestimos", um=True)[0] == 1


def test_operacao_concluida_nao_pode_ser_alterada(banco, sql):
    import psycopg2
    sincronizar([op("op-imutavel-1", "emprestimo_registrar", _emprestimo())])
    with pytest.raises(psycopg2.Error):
        sql("UPDATE sync_operacoes SET status = 'recusada' WHERE operacao_id = 'op-imutavel-1'")


# --- Inventário pela sincronização ---------------------------------------------------------------

def test_conferencias_de_inventario_chegam_pela_sincronizacao(banco, tombo):
    inv = InventarioService().abrir(InventarioCreate(descricao="Inventário do TI", inicio=date.today(),
                                                     fim=date.today(), setor_ids=[TI]), ADMIN)
    resposta = sincronizar([
        op("op-conf-1", "conferencia", {"inventario_id": inv.id, "setor_id": TI, "codigo_tombamento": tombo(1)}),
        op("op-conf-2", "bem_nao_cadastrado", {"inventario_id": inv.id, "setor_id": TI, "descricao": "Cadeira"}, 1),
    ])
    assert status(resposta) == [("op-conf-1", "aceita"), ("op-conf-2", "aceita")]
    assert resposta["resultados"][0].resultado["situacao"] == "localizado"


# --- Registro da sincronização e API ------------------------------------------------------------

def test_cada_sincronizacao_fica_registrada_com_a_contagem(banco):
    sincronizar([op("op-a-0001", "emprestimo_registrar", _emprestimo()),
                 op("op-b-0001", "teletransporte", {}, 1)])
    sincronizar([op("op-a-0001", "emprestimo_registrar", _emprestimo())])
    ultima = SincronizacaoService().ultima(APARELHO, ADMIN)
    assert (ultima.total, ultima.aceitas, ultima.repetidas) == (1, 0, 1)
    assert ultima.concluida_em is not None


def test_api_exige_identificadores_validos_e_limita_o_lote(banco):
    cliente = TestClient(app)
    token = create_access_token({"id": 1}, jwt_secret(), 300)
    cabecalho = {"Authorization": f"Bearer {token}"}
    invalido = cliente.post("/api/v1/sincronizacao/", headers=cabecalho,
                            json={"dispositivo_id": "x", "operacoes": [op("op-ok-0001", "conferencia", {})]})
    assert invalido.status_code == 422
    grande = [op(f"op-grande-{i:04d}", "conferencia", {}) for i in range(501)]
    assert cliente.post("/api/v1/sincronizacao/", headers=cabecalho,
                        json={"dispositivo_id": APARELHO, "operacoes": grande}).status_code == 422
    ok = cliente.post("/api/v1/sincronizacao/", headers=cabecalho,
                      json={"dispositivo_id": APARELHO, "operacoes": [op("op-api-0001", "emprestimo_registrar", _emprestimo())]})
    assert ok.status_code == 200 and ok.json()["resultados"][0]["status"] == "aceita"
