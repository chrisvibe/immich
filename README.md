# Immich Setup Guide

Quick guide for integrating Immich with your self-hosting infrastructure.

## Setup Steps

### 1. Copy files to your infrastructure

```bash
# From your self-hosting root directory
cp /path/to/immich.override.yaml overrides/
cp /path/to/setup_immich.sh scripts/
chmod +x scripts/setup_immich.sh
```

### 2. Run the setup script

```bash
./scripts/setup_immich.sh
```

### 3. Configure Immich .env

Edit `services/immich/.env` and add/update:

```bash
# CRITICAL: Set this to your external domain
IMMICH_SERVER_URL=https://photos.yourdomain.com

# Other existing settings...
UPLOAD_LOCATION=./library
DB_PASSWORD=your_secure_password
# etc.
```

### 4. Restart Immich

```bash
cd services/immich
docker compose down
docker compose up -d
```

### 5. Configure Cloudflare Tunnel Route

In Cloudflare Dashboard → Zero Trust → Networks → Tunnels → [Your Tunnel] → Public Hostname:

**Add new public hostname:**
- **Subdomain**: `photos` (or your preference)
- **Domain**: `yourdomain.com`
- **Service**: `http://immich-server:2283`

### 6. Access Immich

- **External**: `https://photos.yourdomain.com`
- **Local**: `http://192.168.1.42:2283` (use IP, not hostname)

## Why use IP for local access?

Immich validates the `Host` header against `IMMICH_SERVER_URL`. Using `server.local` won't work because:
1. It doesn't match your configured external URL
2. Immich's security checks reject mismatched hosts

Using the IP address bypasses this validation.

## Troubleshooting

### Can't access externally
1. Check tunnel is running: `docker compose ps` (in root directory)
2. Verify Cloudflare route is configured
3. Check Immich logs: `cd services/immich && docker compose logs immich-server`
4. Verify container is on `web` network: `docker network inspect web`

### Can't access locally
- Use `http://192.168.1.123:2283` instead of `server.local:2283`
- Or temporarily add the external domain to your `/etc/hosts`:
  ```
  192.168.1.123    photos.yourdomain.com
  ```

### "Invalid Host header" error
- Verify `IMMICH_SERVER_URL` in `.env` matches your Cloudflare domain
- Restart Immich after changing `.env`

## Network Architecture

```
Internet → Cloudflare Tunnel → web network → immich-server:2283
                                  ↓
                            default network → redis, postgres, ML
```

The override file connects `immich-server` to both:
- `default` network: for internal Immich services (DB, Redis, ML)
- `web` network: for Cloudflare Tunnel access
