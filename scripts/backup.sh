#!/bin/sh
# Immich backup orchestrator. immich's photos live on the NAS (immich_upload NFS volume) and
# the ML model-cache is reproducible, so the only LOCAL non-reproducible datastore is the
# Postgres DB (bind-mounted at DB_DATA_LOCATION). Single store, so this just delegates to the
# DB worker, which uses pg_dumpall for immich's VectorChord / pgvecto.rs extensions.
# Kept as a separate file so the entrypoint/cron line stays identical across services.
set -eu
exec /scripts/backup_db.sh
