# Mizan server

Django REST Framework + PostgreSQL. Design: `docs/ARCHITECTURE.md` §6 (sync) and §9 (apps).

| App | Responsibility |
|---|---|
| `accounts` | Users, JWT auth, devices (task 3.2) |
| `ledger` | Server copies of synced entities, `version`, `server_seq` (3.3) |
| `sync` | `/sync/push`, `/sync/pull`, applied-op log, conflict policy (3.4–3.5) |
| `groups` | Groups, members, invites (4.1) |
| `notifications` | FCM pushes (4.6) |

## Run with Docker

```bash
cp .env.example .env       # optional; the defaults work
docker compose up          # Postgres 18 + API on http://localhost:8000
curl localhost:8000/health # {"status":"ok"}
```

If a local Postgres already uses port 5432, set `POSTGRES_PORT` in `.env` (e.g. 5433).

## Run tests on the host

Postgres must be reachable with the `POSTGRES_*` settings (e.g. `docker compose up -d db`).

```bash
python -m venv .venv
.venv/Scripts/activate      # Windows; `source .venv/bin/activate` elsewhere
pip install -r requirements-dev.txt
pytest                      # uses mizan.settings_test
DJANGO_DEBUG=1 python manage.py migrate
```

Configuration is environment variables only; see `.env.example`.
