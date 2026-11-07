"""Infraestrutura de banco: transação única e controle de migrations."""
import pytest

import migrar

pytestmark = pytest.mark.integracao


def test_transacao_confirma_tudo_junto(banco, sql):
    with banco.transacao() as cur:
        cur.execute("INSERT INTO categorias (nome, sigla) VALUES ('Teste A', 'TSA')")
        cur.execute("INSERT INTO categorias (nome, sigla) VALUES ('Teste B', 'TSB')")
    assert sql("SELECT count(*) FROM categorias WHERE sigla IN ('TSA', 'TSB')", um=True)[0] == 2


def test_transacao_desfaz_tudo_se_algo_falha(banco, sql):
    with pytest.raises(RuntimeError):
        with banco.transacao() as cur:
            cur.execute("INSERT INTO categorias (nome, sigla) VALUES ('Teste C', 'TSC')")
            raise RuntimeError("falha no meio da operação")
    assert sql("SELECT count(*) FROM categorias WHERE sigla = 'TSC'", um=True)[0] == 0


def test_banco_do_zero_fica_sem_migrations_pendentes(banco):
    conn = migrar.conectar()
    try:
        with conn.cursor() as cur:
            assert migrar.pendentes(cur) == []
        assert migrar.migrar(conn) == []  # rodar de novo não aplica nada
    finally:
        conn.close()


def test_todas_as_migrations_ficam_registradas_com_checksum(banco, sql):
    registradas = dict(sql("SELECT nome, checksum FROM schema_migrations"))
    for arquivo in migrar.arquivos():
        assert registradas[arquivo.name] == migrar._checksum(arquivo)
