#!/bin/bash
# Load environment variables from .env
set -a
. ./.env
set +a

# Paths and variables
BACKUP_PATH='$1'  # <- replace with your backup (pass as variable)
DB_CONTAINER="immich_postgres"

echo "⚠️  WARNING: This will delete all current Immich data!"
echo "$DB_DATA_LOCATION"
read -p "Do you want to continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborting."
    return 1 2>/dev/null || exit 1
fi

# Stop and remove containers and volumes (clean start)
docker compose down -v

# Reset Postgres data completely
rm -rf "$DB_DATA_LOCATION"

# Pull latest images (optional)
docker compose pull

# Create containers without starting them
docker compose create

# Start Postgres
docker start "$DB_CONTAINER"
echo "Waiting 10 seconds for Postgres to start..."
sleep 10

# Restore database from backup
echo "Restoring database from backup..."
gunzip --stdout "$BACKUP_PATH" \
| sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
| docker exec -i "$DB_CONTAINER" psql --dbname="$DB_DATABASE_NAME" --username="$DB_USERNAME"

echo "✅ Restore complete!"
