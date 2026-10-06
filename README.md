# Mizan

An offline-first student finance app: track spending, get warned **before** you run out of money, and split shared expenses with roommates. Works fully offline and syncs through a Django server when online.

> Work in progress. The full README (demo, metrics, architecture diagram) comes in task 6.6.

## Repository layout

| Path | What |
|---|---|
| `app/` | Flutter app (Riverpod, go_router, freezed, drift), clean architecture per feature |
| `server/` | Django REST Framework + PostgreSQL, Docker Compose |
| `docs/` | `ARCHITECTURE.md`, `METRICS.md`, `decisions/` (ADRs) |
| `TASKS.md` | The 6-week task plan |

## Run the app

```bash
cd app
flutter pub get
dart run build_runner build --force-jit
flutter analyze
flutter test
flutter run
```

Requires Flutter 3.38+ (Dart 3.10).

## Run the server

```bash
cd server
docker compose up          # Postgres + API on http://localhost:8000/health
```

See [server/README.md](server/README.md) for running tests on the host.
