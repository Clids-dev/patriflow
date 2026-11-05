"""Importação de bens por CSV: validação por linha, simulação e gravação."""
from unittest.mock import MagicMock

import pytest
from fastapi import HTTPException

from core.tombamento import format_tombo
from modules.bem import importacao

USUARIO = {"id": 1, "perfil": "setor_patrimonio", "setor_id": None}
CABECALHO = "nome;id_categoria;status;estado_conservacao;valor_aquisicao;codigo_tombamento;data_entrada\n"


def _csv(*linhas):
    return (CABECALHO + "\n".join(linhas) + "\n").encode("utf-8")


def _servico():
    s = MagicMock()
    s.get_proximo_codigo.side_effect = lambda cat: format_tombo("INF-001")
    return s


def test_simulacao_valida_sem_gravar():
    dados = _csv("Notebook;1;Disponível;novo;1.500,00;" + format_tombo("INF-001") + ";2024-03-01")
    servico = _servico()
    rel = importacao.processar(dados, True, USUARIO, lambda: servico)
    assert rel["simulacao"] is True and rel["validas"] == 1 and rel["importados"] == 0
    servico.create_bem.assert_not_called()


def test_erro_informa_a_linha_e_nao_impede_as_outras():
    dados = _csv(
        "Notebook;1;Disponível;novo;100;" + format_tombo("INF-001") + ";",
        "Sem valor;1;Disponível;novo;;" + format_tombo("INF-002") + ";",
        "Tombo errado;1;Disponível;novo;50;INF-003-9;",
    )
    rel = importacao.processar(dados, True, USUARIO, _servico)
    assert rel["validas"] == 1
    linhas_com_erro = {e["linha"] for e in rel["erros"]}
    assert linhas_com_erro == {3, 4}


def test_importacao_grava_linha_a_linha_e_gera_tombo_quando_vazio():
    dados = (CABECALHO.replace(";codigo_tombamento", "") + "Cadeira;1;Disponível;bom;300;;\n").encode("utf-8")
    servico = _servico()
    rel = importacao.processar(dados, False, USUARIO, lambda: servico)
    assert rel["importados"] == 1
    bem = servico.create_bem.call_args.args[0]
    assert bem.codigo_tombamento == format_tombo("INF-001")


def test_coluna_obrigatoria_ausente_e_recusada():
    with pytest.raises(HTTPException) as exc:
        importacao.ler_csv("nome;status\nX;Y\n".encode("utf-8"))
    assert exc.value.status_code == 400 and "id_categoria" in exc.value.detail


def test_arquivo_grande_demais_e_recusado():
    with pytest.raises(HTTPException) as exc:
        importacao.ler_csv(b"x" * (importacao.LIMITE_BYTES + 1))
    assert exc.value.status_code == 413


def test_valor_com_separador_brasileiro():
    assert importacao._numero("1.234,56") == "1234.56"
    assert importacao._numero("99.90") == "99.90"
