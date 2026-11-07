"""Fixtures compartilhadas.

Testes de integração (marcados com @pytest.mark.integracao) rodam contra um banco PostgreSQL
separado, recriado do zero (schema.sql + migrations) antes de CADA teste. Recriar leva cerca de
0,2 s, e garante que nenhum teste dependa do que outro deixou no banco.

O nome do banco vem de PATRIFLOW_TEST_DB_NAME (padrão: patriflow_test). Ele nunca pode ser o banco
de desenvolvimento: a recriação apaga todas as tabelas. Se o PostgreSQL não estiver acessível,
esses testes são pulados, e os testes unitários continuam rodando normalmente.
"""
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

import migrar  # noqa: E402

from core import config  # noqa: E402
from core.database import DataBase  # noqa: E402

BANCO_TESTE = os.getenv("PATRIFLOW_TEST_DB_NAME", "patriflow_test")


def _trocar_banco(nome: str) -> None:
    """Aponta a aplicação para outro banco e descarta o pool de conexões atual."""
    if DataBase._pool is not None:
        DataBase._pool.closeall()
        DataBase._pool = None
    config.DB_NAME = nome


@pytest.fixture(scope="session")
def _banco_de_teste_existe():
    if BANCO_TESTE == config.DB_NAME:
        pytest.exit(f"PATRIFLOW_TEST_DB_NAME não pode ser o banco da aplicação ({config.DB_NAME}).")
    try:
        conn = migrar.conectar("postgres")
    except Exception as erro:  # PostgreSQL fora do ar ou sem credenciais
        pytest.skip(f"PostgreSQL indisponível para testes de integração: {erro}")
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (BANCO_TESTE,))
            if cur.fetchone() is None:
                cur.execute(f'CREATE DATABASE "{BANCO_TESTE}"')
    finally:
        conn.close()
    original = config.DB_NAME
    yield
    _trocar_banco(original)


@pytest.fixture
def banco(_banco_de_teste_existe):
    """Banco de teste limpo, já com os dados iniciais do schema.sql (admin, agente, setores, bens)."""
    _trocar_banco(BANCO_TESTE)
    conn = migrar.conectar(BANCO_TESTE)
    try:
        migrar.do_zero(conn)
    finally:
        conn.close()
    yield DataBase()
    _trocar_banco(BANCO_TESTE)


@pytest.fixture
def sql(banco):
    """Atalho para preparar dados e conferir resultados direto no banco de teste."""
    def executar(comando: str, params=None, um=False):
        with banco.transacao() as cur:
            cur.execute(comando, params)
            if cur.description is None:
                return None
            return cur.fetchone() if um else cur.fetchall()
    return executar
