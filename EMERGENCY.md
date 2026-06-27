# Immich — Emergency Runbook

**Current versions:** immich-server:v2.7.5 · immich-machine-learning:v2.7.5 · Postgres 14 (vectorchord)  
**Previous versions:** v2.5.2 (both server and ML)

> Server and ML versions must always match — upgrade/rollback both together.  
> Version is hardcoded in compose, not in `.env` (`.env` IMMICH_VERSION is cosmetic only).

---

## Quick check

```bash
docker compose ps
curl -sf http://localhost:2283/api/server/ping && echo OK
docker compose logs --tail=30 immich-server
```

Healthy containers: `immich_server` · `immich_machine_learning` · `immich_postgres` · `immich_redis`

---

## Rollback (bad upgrade)

```bash
git log --oneline -5 docker-compose.yaml

# Revert both (must match):
sed -i 's|immich-server:v2.7.5|immich-server:v2.5.2|' docker-compose.yaml
sed -i 's|immich-machine-learning:v2.7.5|immich-machine-learning:v2.5.2|' docker-compose.yaml

docker compose pull immich-server immich-machine-learning
docker compose up -d immich-server immich-machine-learning
watch docker compose ps
```

---

## Restore from backup (data corruption)

```bash
# List backups:
docker compose exec backup ls -lh /backups/

# Stop server and ML first:
docker compose stop immich-server immich-machine-learning

# Restore DB (pg_dumpall format — uses psql, not pg_restore):
docker compose exec backup /scripts/restore_db.sh /backups/immich_db_YYYY-MM-DD_HH-MM-SS.sql.gz

docker compose start immich-server immich-machine-learning
```

> Photos live on NAS (`immich_upload` volume) — not in the DB backup. DB covers metadata, faces, albums only.

---

## Verify

```bash
docker inspect --format='{{.State.Health.Status}}' immich_server
curl -sf http://localhost:2283/api/server/ping && echo OK
```
