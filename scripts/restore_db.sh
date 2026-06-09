#!/bin/sh
# Restore an immich pg_dumpall backup (.sql.gz) produced by backup_db.sh.
#
# The dump (pg_dumpall --clean --if-exists) DROPs+recreates the roles AND the immich database
# itself, so we feed it into the maintenance DB 'postgres'. We intentionally do NOT set
# ON_ERROR_STOP: re-creating the bootstrap superuser role emits a harmless "already exists"
# notice that must not abort the restore (this matches immich's documented procedure).
#
# Usage: restore_db.sh <backup_file.sql.gz>    (FORCE=1 or --force to skip confirmation)
# Portable across the immich image (Debian/dash) and alpine sidecars: no `pipefail`.
# The gunzip|psql pipe is safe because we `gzip -t` the archive up front (so gunzip can't
# fail mid-stream on a good file), and psql runs without ON_ERROR_STOP by design (see below).
set -eu

BACKUP_FILE="${1:-}"
FORCE="${FORCE:-0}"
[ "${2:-}" = "--force" ] && FORCE=1

PGHOST="${POSTGRES_HOST:-database}"
PGPORT="${POSTGRES_PORT:-5432}"
PGUSER="${POSTGRES_USER:-postgres}"
PGDATABASE="${POSTGRES_DB:-immich}"
export PGPASSWORD="${POSTGRES_PASSWORD:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    ls -lh "${BACKUP_DIR:-/backups}/${SERVICE_NAME:-immich}_db_"*.sql.gz 2>/dev/null || echo "  (no backups found)"
    exit 1
fi
[ -f "$BACKUP_FILE" ] || { echo "ERROR: not found: $BACKUP_FILE"; exit 1; }

# Fail fast on a corrupt/truncated archive BEFORE we drop anything.
gzip -t "$BACKUP_FILE" || { echo "ERROR: '$BACKUP_FILE' is not a valid gzip archive."; exit 1; }

echo "=========================================="
echo " RESTORE immich cluster @ ${PGHOST}:${PGPORT}"
echo " from   ${BACKUP_FILE}"
echo "=========================================="
echo "IMPORTANT: immich-server / machine-learning must be STOPPED during restore"
echo "           (only the database should be running)."
if [ "$FORCE" != "1" ]; then
    printf "Type 'yes' to proceed (this REPLACES the immich database): "
    read -r CONFIRM
    [ "$CONFIRM" = "yes" ] || { echo "Cancelled."; exit 0; }
fi

log "Terminating active connections to '${PGDATABASE}'..."
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -v ON_ERROR_STOP=1 \
     -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${PGDATABASE}' AND pid <> pg_backend_pid();" >/dev/null

log "Restoring (pg_dumpall stream into maintenance DB 'postgres')..."
gunzip -c "$BACKUP_FILE" | psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres >/dev/null

log "Restore complete. Start immich-server + machine-learning again."
