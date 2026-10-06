# Mizan server

Django REST Framework + PostgreSQL. Design: `docs/ARCHITECTURE.md` §6 (sync) and §9 (apps).

| App | Responsibility |
|---|---|
| `accounts` | Users (email login), JWT auth, devices |
| `ledger` | Server copies of synced entities, `version`, `server_seq` (3.3) |
| `sync` | `/sync/push`, `/sync/pull`, applied-op log, conflict policy (3.4–3.5) |
| `groups` | Groups, members, invites (4.1) |
| `notifications` | FCM pushes (4.6) |

## API

| Endpoint | |
|---|---|
| `GET /health` | Liveness + database check. Public. |
| `POST /auth/signup` | `{email, password, displayName?, device?}` → 201 `{user, access, refresh}` |
| `POST /auth/login` | `{email, password, device?}` → `{user, access, refresh}`; 401 `invalid_credentials` |
| `POST /auth/refresh` | `{refresh}` → `{access, refresh}` (each refresh token works once); 401 `token_not_valid` |
| `POST /auth/logout` | `{refresh, deviceId?}` → 204, revokes the token and forgets the device |
| `GET /auth/me` | `Authorization: Bearer <access>` → `{id, email, displayName}` |

`device` is `{id: uuid, platform: "android" | "ios", name?}`. Errors are always
`{"code", "detail", "fields"?}`; see `mizan/errors.py` and ADR 0004.

## Run with Docker

```bash
cp .env.example .env       # optional; the defaults work
docker compose up          # Postgres 18 + API on http://localhost:8000
curl localhost:8000/health # {"status":"ok"}
```

If a local Postgres already uses port 5432, set `POSTGRES_PORT` in `.env` (e.g. 5433).

## Run the API on the host (no Docker)

Settings come only from environment variables. Without `DJANGO_SECRET_KEY`,
the server refuses to start unless `DJANGO_DEBUG=1` (which uses a dev-only key).

```powershell
# PowerShell, from server/ (the variable lasts for this terminal)
$env:DJANGO_DEBUG = "1"
.venv\Scripts\python manage.py migrate
.venv\Scripts\python manage.py runserver 0.0.0.0:8000
```

```bash
# bash
DJANGO_DEBUG=1 .venv/Scripts/python manage.py runserver 0.0.0.0:8000
```

The Android emulator reaches it at `http://10.0.2.2:8000`, which debug mode
allows by default. For a real phone on the same Wi-Fi, also allow your PC's
LAN IP, e.g. `$env:DJANGO_ALLOWED_HOSTS = "localhost,127.0.0.1,10.0.2.2,192.168.1.20"`,
and run the app with `--dart-define=MIZAN_API_URL=http://192.168.1.20:8000`.

## Run tests on the host

Postgres must be reachable with the `POSTGRES_*` settings: either `docker compose up -d db`, or a
local Postgres with a matching role (it needs `CREATEDB` so pytest can create its test database):

```sql
CREATE ROLE mizan LOGIN PASSWORD 'mizan' CREATEDB;
CREATE DATABASE mizan OWNER mizan;
```

```bash
python -m venv .venv
.venv/Scripts/activate      # Windows; `source .venv/bin/activate` elsewhere
pip install -r requirements-dev.txt
pytest                      # uses mizan.settings_test
DJANGO_DEBUG=1 python manage.py migrate
```

Configuration is environment variables only; see `.env.example`.
