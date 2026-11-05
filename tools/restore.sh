#!/usr/bin/env bash
# Restauração de teste: copia um backup do banco para um banco NOVO, sem tocar no original.
# Uso: PGPASSWORD=... tools/restore.sh backups/banco-AAAAMMDD-HHMMSS.dump nome_do_banco_de_teste
# Para restaurar de verdade no banco de produção, faça isso manualmente, após conferir o teste.
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Uso: $0 <arquivo.dump> <banco_destino>" >&2
    exit 1
fi
ARQUIVO="$1"
DESTINO="$2"
HOST="${PATRIFLOW_DB_HOST:-127.0.0.1}"
PORTA="${PATRIFLOW_DB_PORT:-5433}"
USUARIO="${PATRIFLOW_DB_USER:-postgres}"

if [ "$DESTINO" = "${PATRIFLOW_DB_NAME:-sistema_tombamento}" ]; then
    echo "Recusado: o destino não pode ser o banco original." >&2
    exit 1
fi

createdb -h "$HOST" -p "$PORTA" -U "$USUARIO" "$DESTINO"
pg_restore -h "$HOST" -p "$PORTA" -U "$USUARIO" -d "$DESTINO" --no-owner "$ARQUIVO"
echo "Restaurado em ${DESTINO}. Confira as contagens e depois remova com: dropdb -h ${HOST} -p ${PORTA} -U ${USUARIO} ${DESTINO}"
