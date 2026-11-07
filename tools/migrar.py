"""Aplica as migrations de database/migrations/ em ordem e registra o que já foi aplicado.

Uso (na raiz do projeto, com o venv):
    venv/bin/python tools/migrar.py               aplica as pendentes
    venv/bin/python tools/migrar.py --status      lista aplicadas e pendentes
    venv/bin/python tools/migrar.py --baseline    marca todas as existentes como aplicadas, sem executar
                                                  (para um banco montado antes deste controle)
    venv/bin/python tools/migrar.py --do-zero     executa database/schema.sql e depois todas as migrations
                                                  (APAGA as tabelas do banco indicado; use só em banco novo)

O banco vem das mesmas variáveis da aplicação (PATRIFLOW_DB_NAME etc., ver core/config.py).
Cada migration roda com autocommit, porque os arquivos já trazem o próprio BEGIN/COMMIT.
O registro guarda o SHA-256 do arquivo: se uma migration aplicada for alterada depois, o status avisa.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ))

import psycopg2  # noqa: E402

from core import config  # noqa: E402

PASTA = RAIZ / "database" / "migrations"
SCHEMA = RAIZ / "database" / "schema.sql"
# Migrations cujo conteúdo já está em schema.sql (o esquema base foi atualizado depois delas).
# Num banco criado do zero elas são registradas como aplicadas, sem executar: rodá-las de novo
# falharia (ex.: alterar o tipo de uma coluna que já tem trigger).
INCLUIDAS_NO_SCHEMA = ("20261018_auth.sql", "20261018_assets_locations_tombo.sql")

_CRIAR_CONTROLE = """
CREATE TABLE IF NOT EXISTS schema_migrations (
    nome        VARCHAR(255) PRIMARY KEY,
    checksum    CHAR(64) NOT NULL,
    aplicada_em TIMESTAMP NOT NULL DEFAULT NOW()
)"""


def conectar(dbname: str | None = None):
    conn = psycopg2.connect(host=config.DB_HOST, port=config.DB_PORT, user=config.DB_USER,
                            password=config.DB_PASSWORD, dbname=dbname or config.DB_NAME)
    conn.autocommit = True
    return conn


def _checksum(arquivo: Path) -> str:
    return hashlib.sha256(arquivo.read_bytes()).hexdigest()


def arquivos() -> list[Path]:
    return sorted(PASTA.glob("*.sql"))


def aplicadas(cur) -> dict[str, str]:
    cur.execute(_CRIAR_CONTROLE)
    cur.execute("SELECT nome, checksum FROM schema_migrations")
    return dict(cur.fetchall())


def pendentes(cur) -> list[Path]:
    feitas = aplicadas(cur)
    return [a for a in arquivos() if a.name not in feitas]


def aplicar(cur, arquivo: Path) -> None:
    cur.execute(arquivo.read_text(encoding="utf-8"))
    cur.execute("INSERT INTO schema_migrations (nome, checksum) VALUES (%s, %s)",
                (arquivo.name, _checksum(arquivo)))


def migrar(conn) -> list[str]:
    """Aplica as pendentes em ordem. Para na primeira falha (as seguintes podem depender dela)."""
    nomes = []
    with conn.cursor() as cur:
        for arquivo in pendentes(cur):
            aplicar(cur, arquivo)
            nomes.append(arquivo.name)
    return nomes


def do_zero(conn) -> list[str]:
    with conn.cursor() as cur:
        cur.execute(SCHEMA.read_text(encoding="utf-8"))
        cur.execute("DROP TABLE IF EXISTS schema_migrations")
        aplicadas(cur)  # cria a tabela de controle
        for nome in INCLUIDAS_NO_SCHEMA:
            cur.execute("INSERT INTO schema_migrations (nome, checksum) VALUES (%s, %s)",
                        (nome, _checksum(PASTA / nome)))
    return migrar(conn)


def baseline(conn) -> list[str]:
    nomes = []
    with conn.cursor() as cur:
        for arquivo in pendentes(cur):
            cur.execute("INSERT INTO schema_migrations (nome, checksum) VALUES (%s, %s)",
                        (arquivo.name, _checksum(arquivo)))
            nomes.append(arquivo.name)
    return nomes


def status(conn) -> None:
    with conn.cursor() as cur:
        feitas = aplicadas(cur)
    for arquivo in arquivos():
        if arquivo.name not in feitas:
            print(f"  pendente   {arquivo.name}")
        elif feitas[arquivo.name] != _checksum(arquivo):
            print(f"  ALTERADA   {arquivo.name}  (o arquivo mudou depois de aplicado)")
        else:
            print(f"  aplicada   {arquivo.name}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    grupo = parser.add_mutually_exclusive_group()
    grupo.add_argument("--status", action="store_true")
    grupo.add_argument("--baseline", action="store_true")
    grupo.add_argument("--do-zero", action="store_true")
    args = parser.parse_args()

    conn = conectar()
    try:
        print(f"Banco: {config.DB_NAME} em {config.DB_HOST}:{config.DB_PORT}")
        if args.status:
            status(conn)
            return 0
        if args.baseline:
            nomes = baseline(conn)
            print(f"Marcadas como aplicadas: {len(nomes)}")
        elif args.do_zero:
            nomes = do_zero(conn)
            print(f"Esquema criado; migrations aplicadas: {len(nomes)}")
        else:
            nomes = migrar(conn)
            print(f"Migrations aplicadas: {len(nomes)}" if nomes else "Nenhuma migration pendente.")
        for nome in nomes:
            print(f"  {nome}")
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
