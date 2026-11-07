"""Inventário (abertura, lista congelada, conferência, fechamento) e caixa de pendências, num banco real.

Dados iniciais (schema.sql): bens 1 e 2 no TI (setor 1); bens 3 e 5 no almoxarifado (setor 3);
bem 4 no RH (setor 4). Os demais bens não têm localização.
"""
import threading
from datetime import date, timedelta

import psycopg2
import pytest
from fastapi import HTTPException

from core import config
from core.tombamento import format_tombo
from modules.bem import historico
from modules.emprestimo.schemas import EmprestimoCreate
from modules.emprestimo.service import EmprestimoService
from modules.foto.service import FotoService
from modules.inventario.schemas import Conferencia, InventarioCreate, NaoCadastrado
from modules.inventario.service import InventarioService
from modules.movimentacao.schemas import MovimentacaoCreate
from modules.movimentacao.service import MovimentacaoService
from modules.pendencia.service import PendenciaService

pytestmark = pytest.mark.integracao

TI, ALMOX, RH = 1, 3, 4
ADMIN = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 100
HOJE = date.today()


@pytest.fixture
def tombo(sql):
    codigos = dict(sql("SELECT id, codigo_tombamento FROM bens WHERE id <= 5"))
    return lambda bem_id: codigos[bem_id]


@pytest.fixture
def agente_ti(sql):
    uid = sql("""INSERT INTO usuarios (username, senha, tipo, ativo, nome, setor_id)
                 VALUES ('agente_ti', 'x', 'agente_campo', TRUE, 'Agente TI', %s) RETURNING id""", (TI,), um=True)[0]
    return {"id": uid, "perfil": "agente_campo", "setor_id": TI}


def _abrir(setores=(TI, ALMOX), inicio=HOJE):
    return InventarioService().abrir(
        InventarioCreate(descricao="Inventário anual", inicio=inicio, fim=inicio + timedelta(days=30),
                         setor_ids=list(setores)), ADMIN)


def _conferir(inv_id, codigo, setor, usuario=ADMIN, **extra):
    return InventarioService().conferir(inv_id, Conferencia(setor_id=setor, codigo_tombamento=codigo, **extra), usuario)


def _erro(funcao, *args):
    with pytest.raises(HTTPException) as exc:
        funcao(*args)
    return exc.value


# --- Abertura -----------------------------------------------------------------------------------

def test_abertura_congela_a_lista_esperada_de_cada_setor(banco):
    inv = _abrir()
    assert inv.status == "aberto" and inv.total_itens == 4 and inv.pendentes == 4
    por_setor = {s.setor_id: s.esperados for s in inv.setores}
    assert por_setor == {TI: 2, ALMOX: 2}

    # Mover o bem depois da abertura não muda o que o inventário espera.
    MovimentacaoService().add_movimentacao(
        MovimentacaoCreate(bem_id=1, setor_origem_id=TI, setor_destino_id=RH, justificativa="Remanejamento"), ADMIN)
    itens = InventarioService().itens(inv.id, TI, "todos")
    assert sorted(i.bem_id for i in itens) == [1, 2]


def test_setor_nao_pode_estar_em_dois_inventarios_abertos(banco):
    _abrir(setores=(TI,))
    erro = _erro(_abrir, (TI, RH))
    assert erro.status_code == 409 and "Departamento de Tecnologia" in erro.detail


def test_duas_aberturas_simultaneas_do_mesmo_setor_resultam_em_um_inventario(banco, sql):
    resultados, barreira = [], threading.Barrier(2)

    def abrir():
        barreira.wait()
        try:
            _abrir(setores=(TI,))
            resultados.append(201)
        except HTTPException as erro:
            resultados.append(erro.status_code)

    threads = [threading.Thread(target=abrir) for _ in range(2)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert sorted(resultados) == [201, 409]
    assert sql("SELECT count(*) FROM inventario_setores WHERE setor_id = %s AND aberto", (TI,), um=True)[0] == 1


def test_so_o_patrimonio_abre_inventario(banco, agente_ti):
    dados = InventarioCreate(descricao="Teste", inicio=HOJE, fim=HOJE, setor_ids=[TI])
    assert _erro(InventarioService().abrir, dados, agente_ti).status_code == 403


def test_setor_inexistente_e_recusado(banco):
    assert _erro(_abrir, (TI, 999)).status_code == 400


# --- Conferência --------------------------------------------------------------------------------

def test_conferencia_no_setor_esperado_localiza_e_releitura_nao_duplica(banco, tombo, sql):
    inv = _abrir()
    item = _conferir(inv.id, tombo(1), TI, estado_encontrado="bom")
    assert item.situacao == "localizado" and item.setor_encontrado == "Departamento de Tecnologia"
    _conferir(inv.id, tombo(1).lower(), TI)  # mesma etiqueta lida de novo, em minúsculas
    assert sql("SELECT count(*) FROM inventario_itens WHERE inventario_id = %s AND bem_id = 1", (inv.id,), um=True)[0] == 1


def test_bem_encontrado_em_outro_setor_do_inventario(banco, tombo):
    inv = _abrir()
    item = _conferir(inv.id, tombo(2), ALMOX)
    assert item.situacao == "outro_setor" and item.setor_esperado_id == TI and item.setor_encontrado_id == ALMOX


def test_bem_de_fora_da_lista_entra_como_encontrado_em_outro_setor(banco, tombo):
    inv = _abrir()
    item = _conferir(inv.id, tombo(4), TI)  # bem 4 é do RH, que não está no inventário
    assert item.situacao == "outro_setor" and item.setor_esperado_id == RH


def test_tombo_invalido_e_tombo_desconhecido(banco):
    inv = _abrir()
    assert _erro(_conferir, inv.id, "TMB-001-9", TI).status_code == 400  # dígito verificador errado
    assert _erro(_conferir, inv.id, format_tombo("ZZZ-999"), TI).status_code == 404


def test_colaborador_so_confere_no_proprio_setor(banco, tombo, agente_ti):
    inv = _abrir()
    assert _erro(_conferir, inv.id, tombo(3), ALMOX, agente_ti).status_code == 403
    assert _conferir(inv.id, tombo(1), TI, agente_ti).situacao == "localizado"


def test_inventario_que_ainda_nao_comecou_nao_aceita_conferencia(banco, tombo):
    inv = _abrir(inicio=HOJE + timedelta(days=2))
    assert _erro(_conferir, inv.id, tombo(1), TI).status_code == 409


def test_bem_nao_cadastrado_nao_aceita_tombo_existente(banco, tombo):
    inv = _abrir()
    servico = InventarioService()
    item = servico.registrar_nao_cadastrado(inv.id, NaoCadastrado(setor_id=TI, descricao="Cadeira sem etiqueta"), ADMIN)
    assert item.situacao == "nao_cadastrado" and item.bem_id is None
    duplicado = NaoCadastrado(setor_id=TI, descricao="Notebook", codigo_lido=tombo(1))
    assert _erro(servico.registrar_nao_cadastrado, inv.id, duplicado, ADMIN).status_code == 409


# --- Fechamento ---------------------------------------------------------------------------------

def test_nao_fecha_com_bem_sem_situacao(banco):
    inv = _abrir()
    erro = _erro(InventarioService().fechar, inv.id, ADMIN)
    assert erro.status_code == 409 and "4 bem(ns) sem situação" in erro.detail


def test_fechamento_completo_abre_transferencias_e_cria_pendencias(banco, tombo, sql):
    # Bem 3 emprestado antes da abertura: ausência justificada, sem pendência.
    EmprestimoService().registrar(EmprestimoCreate(bem_id=3, tomador="Ana Lima", matricula="M-1001", setor_destino_id=2, motivo="Evento",
                                                   devolucao_prevista=HOJE + timedelta(days=3)), ADMIN)
    inv = _abrir()
    servico = InventarioService()
    _conferir(inv.id, tombo(1), TI)            # localizado
    _conferir(inv.id, tombo(2), ALMOX)         # esperado no TI, achado no almoxarifado
    _conferir(inv.id, tombo(4), TI)            # bem do RH achado no TI
    servico.registrar_nao_cadastrado(inv.id, NaoCadastrado(setor_id=ALMOX, descricao="Monitor sem etiqueta"), ADMIN)
    assert servico.marcar_faltantes(inv.id, ALMOX, ADMIN) == {"marcados": 2}  # bens 3 e 5

    resumo = servico.fechar(inv.id, ADMIN)
    assert resumo == {
        "inventario_id": inv.id, "localizados": 1, "outro_setor": 2, "nao_localizados": 2,
        "ausencias_justificadas": 1, "nao_cadastrados": 1, "transferencias_abertas": 2,
        "transferencias_ignoradas": [], "pendencias_criadas": 2,
    }
    transferencias = sql("""SELECT bem_id, setor_origem_id, setor_destino_id, status, fluxo FROM movimentacoes
                            WHERE justificativa LIKE 'Inventário #%%' ORDER BY bem_id""")
    assert transferencias == [(2, TI, ALMOX, "pendente", "duplo"), (4, RH, TI, "pendente", "duplo")]
    tipos = sorted(p.tipo for p in PendenciaService().listar("abertas"))
    assert tipos == ["bem_nao_cadastrado", "bem_nao_localizado"]
    assert InventarioService().detalhar(inv.id).status == "fechado"


def test_divergencias_listam_so_o_que_nao_estava_no_lugar(banco, tombo):
    inv = _abrir()
    _conferir(inv.id, tombo(1), TI)
    _conferir(inv.id, tombo(2), ALMOX)
    divergencias = InventarioService().itens(inv.id, None, "divergencias")
    assert [i.bem_id for i in divergencias] == [2]


def test_inventario_fechado_fica_imutavel_e_libera_os_setores(banco, tombo, sql):
    inv = _abrir(setores=(TI,))
    InventarioService().marcar_faltantes(inv.id, TI, ADMIN)
    InventarioService().fechar(inv.id, ADMIN)

    assert _erro(_conferir, inv.id, tombo(1), TI).status_code == 409
    assert _erro(InventarioService().fechar, inv.id, ADMIN).status_code == 409
    with pytest.raises(psycopg2.Error):
        sql("UPDATE inventario_itens SET observacao = 'mudou' WHERE inventario_id = %s", (inv.id,))
    with pytest.raises(psycopg2.Error):
        sql("DELETE FROM inventarios WHERE id = %s", (inv.id,))
    assert _abrir(setores=(TI,)).status == "aberto"  # o setor ficou livre para outro inventário


# --- Pendências ---------------------------------------------------------------------------------

def test_pendencia_e_resolvida_uma_vez_e_so_pelo_patrimonio(banco, agente_ti):
    inv = _abrir(setores=(TI,))
    InventarioService().marcar_faltantes(inv.id, TI, ADMIN)
    InventarioService().fechar(inv.id, ADMIN)
    pendencia = PendenciaService().listar("abertas")[0]

    assert _erro(PendenciaService().resolver, pendencia.id, "Achado no depósito", agente_ti).status_code == 403
    resolvida = PendenciaService().resolver(pendencia.id, "Achado no depósito", ADMIN)
    assert resolvida.resolvida_em is not None and resolvida.resolucao == "Achado no depósito"
    assert _erro(PendenciaService().resolver, pendencia.id, "De novo", ADMIN).status_code == 409


# --- Fotos e linha do tempo ---------------------------------------------------------------------

def test_foto_precisa_de_um_registro_existente(banco, tombo, tmp_path, monkeypatch):
    monkeypatch.setattr(config, "FOTOS_DIR", str(tmp_path))
    inv = _abrir()
    item = _conferir(inv.id, tombo(1), TI)
    foto = FotoService().registrar(JPEG, "conferencia", item.id, ADMIN)
    assert foto["id"]
    assert _erro(FotoService().registrar, JPEG, "conferencia", 99999, ADMIN).status_code == 404
    # Nenhum arquivo órfão fica no disco quando o registro não existe.
    assert len(list(tmp_path.iterdir())) == 1


def test_conferencia_aparece_na_linha_do_tempo_com_a_foto(banco, tombo, tmp_path, monkeypatch):
    monkeypatch.setattr(config, "FOTOS_DIR", str(tmp_path))
    inv = _abrir()
    item = _conferir(inv.id, tombo(1), TI, estado_encontrado="regular")
    foto = FotoService().registrar(JPEG, "conferencia", item.id, ADMIN)
    evento = historico.linha_do_tempo(1)[0]
    assert evento["tipo"] == "conferencia_localizado" and evento["fotos"] == [foto["id"]]
    assert "estado: regular" in evento["detalhe"]
