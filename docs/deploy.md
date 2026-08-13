# Deploying OneSQLx

Runbook for a self-hosted production deployment with Docker Compose. The same
environment variables apply to any other platform (Fly.io, a bare release,
Kubernetes) — only the orchestration changes.

## Quick start

```bash
git clone https://github.com/aalvaropc/onesqlx.git
cd onesqlx

# 1. Create the environment file
cat > .env <<EOF
SECRET_KEY_BASE=$(docker run --rm hexpm/elixir:1.19.5-erlang-28.5.0.2-debian-bookworm-20260623-slim \
  sh -c "mix local.hex --force >/dev/null 2>&1; elixir -e 'IO.puts(:crypto.strong_rand_bytes(48) |> Base.encode64())'")
POSTGRES_PASSWORD=$(openssl rand -hex 24)
PHX_HOST=onesqlx.yourdomain.com
MAIL_FROM=noreply@yourdomain.com
SMTP_HOST=smtp.yourprovider.com
SMTP_USERNAME=...
SMTP_PASSWORD=...
EOF
# (with a local Elixir install, `mix phx.gen.secret` is the simpler way
# to generate SECRET_KEY_BASE)

# 2. Build and start (runs migrations automatically before the app)
docker compose -f docker-compose.prod.yml up -d --build

# 3. Verify
curl -fsS http://localhost:4000/health
```

The `migrate` one-shot service applies pending Ecto migrations on every
`up`, so upgrades are: `git pull && docker compose -f docker-compose.prod.yml up -d --build`.

## Environment variables

### Required

| Variable | Purpose |
|---|---|
| `SECRET_KEY_BASE` | Signs/encrypts cookies and secrets. Generate with `mix phx.gen.secret`. **Also derives the data-source credential encryption key — changing it invalidates saved data source passwords.** |
| `POSTGRES_PASSWORD` | Database password (compose builds `DATABASE_URL` from it). On other platforms set `DATABASE_URL` directly. |

### Mailer (strongly recommended)

Magic-link login and scheduled-query emails **are not delivered** until one of
these is configured; the app logs a warning at startup when unconfigured.

| Variable | Purpose |
|---|---|
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `SMTP_TLS` | Any SMTP provider. Port defaults to 587 with STARTTLS; `SMTP_TLS=false` only for local relays. |
| `RESEND_API_KEY` | Alternative: [Resend](https://resend.com). Ignored if `SMTP_HOST` is set. |
| `MAIL_FROM` / `MAIL_FROM_NAME` | Sender for all outgoing email, e.g. `noreply@yourdomain.com`. |

### Optional

| Variable | Purpose |
|---|---|
| `PHX_HOST` | Public hostname (used in generated URLs). |
| `METRICS_TOKEN` | Enables Prometheus `/metrics` with `Authorization: Bearer <token>`. Unset → the endpoint answers 404. |
| `DATABASE_SSL` | `true` → TLS to the internal database (system CA store). For managed/external Postgres. |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Enables "Sign in with Google". |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | Enables "Sign in with GitHub". |
| `POOL_SIZE` | Internal DB pool (default 10). |
| `PORT` | HTTP port (default 4000). |

## TLS / HTTPS

TLS terminates at a reverse proxy, not in the app (Phoenix's `force_ssl` is
compile-time config, so redirect and HSTS belong to the proxy). The compose
file ships a commented Caddy service that obtains certificates automatically:

1. Point your domain's DNS at the server and set `PHX_HOST` in `.env`.
2. Uncomment the `proxy` service in `docker-compose.prod.yml`.
3. Remove the `ports` mapping from the `app` service so only the proxy is exposed.

Any other proxy (Traefik, nginx + certbot) works the same way: forward to
`app:4000` and preserve `X-Forwarded-*` headers.

## Prometheus scraping

```yaml
scrape_configs:
  - job_name: onesqlx
    authorization:
      credentials: <METRICS_TOKEN>
    static_configs:
      - targets: ["onesqlx.yourdomain.com"]
```

## Backups

All application state lives in the `onesqlx_prod_pg_data` volume:

```bash
docker exec onesqlx_prod_db pg_dump -U postgres onesqlx_prod | gzip > onesqlx-$(date +%F).sql.gz
```

Restore with `gunzip -c dump.sql.gz | docker exec -i onesqlx_prod_db psql -U postgres onesqlx_prod`.

## Health & observability

- `GET /health` — liveness (also wired as the image's `HEALTHCHECK`)
- `GET /ready` — readiness (checks the database)
- `GET /metrics` — Prometheus (requires `METRICS_TOKEN`)
- Emails: with no mailer configured the app boots but logs
  `No production mailer configured…` — treat that warning as a deploy error.

## Upgrading

```bash
git pull
docker compose -f docker-compose.prod.yml up -d --build   # migrations run first
```

Rollback of a migration (rarely needed): `docker exec onesqlx_app /app/bin/onesqlx eval 'Onesqlx.Release.rollback(Onesqlx.Repo, <version>)'`.
