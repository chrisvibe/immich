#!/bin/sh
# Immich Postgres backup -> gzipped pg_dumpall (cluster-wide plain SQL).
#
# Why pg_dumpall (not the custom-format pg_dump used elsewhere): immich's DB relies on the
# VectorChord / pgvecto.rs extensions. immich's documented backup procedure uses pg_dumpall,
# which captures roles + the database and emits the CREATE EXTENSION statements so the vector
# types/indexes restore cleanly. A custom-format dump does not round-trip these reliably.
#
# Portable across the immich image (Debian/dash) and the alpine sidecars: no `pipefail`.
# pg_dumpall writes to a temp file first (so `set -e` catches a failed dump directly, with no
# pipe hiding the exit status), then we gzip it.
set -eu

BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
SERVICE_NAME="${SERVICE_NAME:-immich}"
PGHOST="${POSTGRES_HOST:-database}"
PGPORT="${POSTGRES_PORT:-5432}"
PGUSER="${POSTGRES_USER:-postgres}"   # immich DB_USERNAME (superuser)
export PGPASSWORD="${POSTGRES_PASSWORD:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="${BACKUP_DIR}/${SERVICE_NAME}_db_${TIMESTAMP}.sql.gz"
TMP_SQL="${BACKUP_FILE}.rawtmp"

# Clean up any partial temp files however we exit (failure, signal, success).
trap 'rm -f "$TMP_SQL" "${BACKUP_FILE}.tmp"' EXIT

log "pg_dumpall '${PGHOST}:${PGPORT}' as ${PGUSER} -> ${BACKUP_FILE}"
pg_dumpall -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" --clean --if-exists > "$TMP_SQL"
gzip -c "$TMP_SQL" > "${BACKUP_FILE}.tmp"
gzip -t "${BACKUP_FILE}.tmp"            # verify the gzip stream is complete
mv "${BACKUP_FILE}.tmp" "$BACKUP_FILE"  # atomic publish of a known-good backup
rm -f "$TMP_SQL"

log "Backup OK: ${BACKUP_FILE} ($(du -h "$BACKUP_FILE" | cut -f1))"

DELETED=$(find "$BACKUP_DIR" -name "${SERVICE_NAME}_db_*.sql.gz" -type f -mtime "+${RETENTION_DAYS}" -print -delete | wc -l)
REMAINING=$(find "$BACKUP_DIR" -name "${SERVICE_NAME}_db_*.sql.gz" -type f | wc -l)
log "Retention ${RETENTION_DAYS}d: pruned ${DELETED}, ${REMAINING} backup(s) remain"
