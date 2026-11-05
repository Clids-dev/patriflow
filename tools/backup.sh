#!/usr/bin/env bash
# Backup do PatriFlow: banco (formato custom do pg_dump) e pasta de fotos.
# Uso: PGPASSWORD=... tools/backup.sh
# Variáveis opcionais: PATRIFLOW_BACKUP_DIR (padrão: backups/), PATRIFLOW_BACKUP_RETENCAO_DIAS (padrão: 14),
# PATRIFLOW_DB_HOST, PATRIFLOW_DB_PORT, PATRIFLOW_DB_USER, PATRIFLOW_DB_NAME.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DESTINO="${PATRIFLOW_BACKUP_DIR:-$RAIZ/backups}"
RETENCAO="${PATRIFLOW_BACKUP_RETENCAO_DIAS:-14}"
HOST="${PATRIFLOW_DB_HOST:-127.0.0.1}"
PORTA="${PATRIFLOW_DB_PORT:-5433}"
USUARIO="${PATRIFLOW_DB_USER:-postgres}"
BANCO="${PATRIFLOW_DB_NAME:-sistema_tombamento}"
FOTOS="${PATRIFLOW_FOTOS_DIR:-$RAIZ/uploads/fotos}"
CARIMBO="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$DESTINO"

echo "[1/3] Banco ${BANCO} -> ${DESTINO}/banco-${CARIMBO}.dump"
pg_dump -h "$HOST" -p "$PORTA" -U "$USUARIO" -d "$BANCO" -Fc -f "$DESTINO/banco-${CARIMBO}.dump"

echo "[2/3] Fotos -> ${DESTINO}/fotos-${CARIMBO}.tar.gz"
if [ -d "$FOTOS" ]; then
    tar -czf "$DESTINO/fotos-${CARIMBO}.tar.gz" -C "$(dirname "$FOTOS")" "$(basename "$FOTOS")"
else
    echo "    (sem pasta de fotos em ${FOTOS}; nada a copiar)"
fi

echo "[3/3] Removendo backups com mais de ${RETENCAO} dias"
find "$DESTINO" -maxdepth 1 \( -name 'banco-*.dump' -o -name 'fotos-*.tar.gz' \) -mtime +"$RETENCAO" -print -delete

echo "Backup concluído: ${CARIMBO}"
